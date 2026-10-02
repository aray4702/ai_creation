import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class LibraryStore {
    var tracks: [Track] = []
    var playlists: [Playlist] = []
    var favorites: Set<UUID> = [] {
        didSet { UserDefaults.standard.set(favorites.map(\.uuidString), forKey: "favorites") }
    }
    var isPreparing = true
    var preparingProgress: Double = 0

    @ObservationIgnored private var didBootstrap = false

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "favorites") ?? []
        favorites = Set(saved.compactMap(UUID.init(uuidString:)))
    }

    static var samplesDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("YueTingPlayer/Samples-v1", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 本地合成的示范音源（不依赖任何外部文件）。
    static let recipes: [(SongRecipe, year: Int)] = [
        (SongRecipe(key: "cn-neon-01", title: "午夜信号", artist: "霓虹港湾", album: "午夜信号", trackNumber: 1,
                    bpm: 112, root: 57, scale: ToneSynth.minor, progression: [0, 5, 2, 6],
                    lead: .saw, pad: .triangle, drums: true, seconds: 52, seed: 11), 2024),
        (SongRecipe(key: "cn-neon-02", title: "港湾灯火", artist: "霓虹港湾", album: "午夜信号", trackNumber: 2,
                    bpm: 96, root: 55, scale: ToneSynth.dorian, progression: [0, 3, 0, 4],
                    lead: .square, pad: .triangle, drums: true, seconds: 48, seed: 12), 2024),
        (SongRecipe(key: "cn-neon-03", title: "静电花开", artist: "霓虹港湾", album: "午夜信号", trackNumber: 3,
                    bpm: 124, root: 52, scale: ToneSynth.minor, progression: [0, 0, 5, 4],
                    lead: .saw, pad: .saw, drums: true, seconds: 45, seed: 13), 2024),
        (SongRecipe(key: "cn-aurora-01", title: "玻璃草原", artist: "极光原野", album: "玻璃草原", trackNumber: 1,
                    bpm: 78, root: 60, scale: ToneSynth.major, progression: [0, 4, 5, 3],
                    lead: .sine, pad: .triangle, drums: false, seconds: 50, seed: 21), 2023),
        (SongRecipe(key: "cn-aurora-02", title: "晨露", artist: "极光原野", album: "玻璃草原", trackNumber: 2,
                    bpm: 84, root: 62, scale: ToneSynth.major, progression: [0, 3, 4, 0],
                    lead: .triangle, pad: .sine, drums: false, seconds: 44, seed: 22), 2023),
        (SongRecipe(key: "cn-engine-01", title: "发条潮汐", artist: "静默引擎", album: "发条潮汐", trackNumber: 1,
                    bpm: 104, root: 53, scale: ToneSynth.mixolydian, progression: [0, 6, 3, 0],
                    lead: .square, pad: .triangle, drums: true, seconds: 47, seed: 31), 2022),
        (SongRecipe(key: "cn-engine-02", title: "黄铜罗盘", artist: "静默引擎", album: "发条潮汐", trackNumber: 2,
                    bpm: 118, root: 58, scale: ToneSynth.major, progression: [0, 4, 1, 3],
                    lead: .triangle, pad: .square, drums: true, seconds: 42, seed: 32), 2022),
        (SongRecipe(key: "cn-moon-01", title: "纸飞卫星", artist: "月谷", album: "纸飞卫星", trackNumber: 1,
                    bpm: 90, root: 59, scale: ToneSynth.minor, progression: [0, 2, 5, 4],
                    lead: .triangle, pad: .sine, drums: true, seconds: 49, seed: 41), 2025),
        (SongRecipe(key: "cn-moon-02", title: "低轨摇篮曲", artist: "月谷", album: "纸飞卫星", trackNumber: 2,
                    bpm: 70, root: 64, scale: ToneSynth.major, progression: [0, 5, 3, 4],
                    lead: .sine, pad: .triangle, drums: false, seconds: 46, seed: 42), 2025),
        (SongRecipe(key: "cn-neon-ep-01", title: "余晖", artist: "霓虹港湾", album: "余晖 EP", trackNumber: 1,
                    bpm: 100, root: 56, scale: ToneSynth.dorian, progression: [0, 3, 6, 4],
                    lead: .saw, pad: .triangle, drums: true, seconds: 50, seed: 51), 2025),
        (SongRecipe(key: "cn-lime-01", title: "夏日汽水", artist: "青柠乐队", album: "夏日汽水", trackNumber: 1,
                    bpm: 128, root: 60, scale: ToneSynth.major, progression: [0, 4, 5, 3],
                    lead: .square, pad: .triangle, drums: true, seconds: 44, seed: 61), 2025),
        (SongRecipe(key: "cn-lime-02", title: "云端漫步", artist: "青柠乐队", album: "夏日汽水", trackNumber: 2,
                    bpm: 108, root: 65, scale: ToneSynth.mixolydian, progression: [0, 3, 4, 0],
                    lead: .triangle, pad: .sine, drums: true, seconds: 46, seed: 62), 2025),
    ]

    static func trackID(_ i: Int) -> UUID {
        UUID(uuidString: String(format: "C0FFEE00-0000-4000-8000-%012d", i))!
    }

    private var years: [String: Int] = [:]

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let dir = Self.samplesDir
        var list: [Track] = []
        for (i, entry) in Self.recipes.enumerated() {
            let recipe = entry.0
            years[recipe.album] = entry.year
            let url = dir.appendingPathComponent(recipe.key + ".wav")
            if !FileManager.default.fileExists(atPath: url.path) {
                let data = await Task.detached(priority: .userInitiated) {
                    ToneSynth.wavData(ToneSynth.render(recipe))
                }.value
                try? data.write(to: url, options: .atomic)
            }
            let dur = (try? AVAudioPlayer(contentsOf: url).duration) ?? recipe.seconds
            list.append(Track(id: Self.trackID(i), title: recipe.title, artist: recipe.artist, album: recipe.album,
                              trackNumber: recipe.trackNumber, duration: dur, url: url))
            preparingProgress = Double(i + 1) / Double(Self.recipes.count)
        }
        tracks = list
        let ids = (0..<list.count).map(Self.trackID)
        playlists = [
            Playlist(id: "night", name: "深夜电台", blurb: "霓虹与低音，陪你穿过城市的夜",
                     trackIDs: [ids[0], ids[2], ids[9], ids[5]]),
            Playlist(id: "focus", name: "专注时刻", blurb: "柔和的合成器铺底，适合阅读与工作",
                     trackIDs: [ids[3], ids[4], ids[8], ids[7]]),
            Playlist(id: "morning", name: "清晨咖啡", blurb: "明亮的大调旋律，开启美好一天",
                     trackIDs: [ids[10], ids[4], ids[11], ids[6]]),
            Playlist(id: "groove", name: "律动节拍", blurb: "鼓点与贝斯，让身体动起来",
                     trackIDs: [ids[1], ids[10], ids[5], ids[2], ids[6]]),
        ]
        isPreparing = false
    }

    // MARK: - Derived

    var albums: [Album] {
        let groups = Dictionary(grouping: tracks) { $0.album + "|" + $0.artist }
        return groups.values.map { ts in
            let sorted = ts.sorted { $0.trackNumber < $1.trackNumber }
            return Album(title: sorted[0].album, artist: sorted[0].artist,
                         year: years[sorted[0].album] ?? 2025, tracks: sorted)
        }
        .sorted { ($0.year, $0.title) > ($1.year, $1.title) }
    }

    var artists: [Artist] {
        Dictionary(grouping: albums, by: \.artist)
            .map { Artist(name: $0.key, albums: $0.value) }
            .sorted { $0.name < $1.name }
    }

    var favoriteTracks: [Track] { tracks.filter { favorites.contains($0.id) } }

    func album(_ id: String) -> Album? { albums.first { $0.id == id } }
    func artist(_ name: String) -> Artist? { artists.first { $0.name == name } }
    func playlist(_ id: String) -> Playlist? { playlists.first { $0.id == id } }
    func tracks(in p: Playlist) -> [Track] { p.trackIDs.compactMap { id in tracks.first { $0.id == id } } }

    func isFavorite(_ t: Track?) -> Bool { t.map { favorites.contains($0.id) } ?? false }

    func toggleFavorite(_ t: Track?) {
        guard let t else { return }
        if favorites.contains(t.id) { favorites.remove(t.id) } else { favorites.insert(t.id) }
    }
}
