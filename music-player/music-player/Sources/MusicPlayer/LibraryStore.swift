import Foundation
import AVFoundation
import AppKit
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class LibraryStore {
    var tracks: [Track] = []
    var playlists: [Playlist] = []
    var isPreparing = true
    var preparingProgress: Double = 0
    var lastError: String?

    private var didBootstrap = false

    // MARK: - Storage locations

    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MusicPlayerDemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static var samplesDir: URL {
        let dir = supportDir.appendingPathComponent("Samples-v1", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static var stateURL: URL { supportDir.appendingPathComponent("library.json") }

    private struct SavedState: Codable {
        var imported: [Track]
        var playlists: [Playlist]
    }

    // MARK: - Demo content

    static let demoRecipes: [SongRecipe] = [
        SongRecipe(key: "neon-01", title: "Midnight Signals", artist: "Neon Harbor", album: "Midnight Signals",
                   trackNumber: 1, bpm: 112, root: 57, scale: ToneSynth.minor, progression: [0, 5, 2, 6],
                   lead: .saw, pad: .triangle, drums: true, seconds: 52, seed: 11),
        SongRecipe(key: "neon-02", title: "Harbor Lights", artist: "Neon Harbor", album: "Midnight Signals",
                   trackNumber: 2, bpm: 96, root: 55, scale: ToneSynth.dorian, progression: [0, 3, 0, 4],
                   lead: .square, pad: .triangle, drums: true, seconds: 48, seed: 12),
        SongRecipe(key: "neon-03", title: "Static Bloom", artist: "Neon Harbor", album: "Midnight Signals",
                   trackNumber: 3, bpm: 124, root: 52, scale: ToneSynth.minor, progression: [0, 0, 5, 4],
                   lead: .saw, pad: .saw, drums: true, seconds: 45, seed: 13),
        SongRecipe(key: "aurora-01", title: "Glass Meadows", artist: "Aurora Fields", album: "Glass Meadows",
                   trackNumber: 1, bpm: 78, root: 60, scale: ToneSynth.major, progression: [0, 4, 5, 3],
                   lead: .sine, pad: .triangle, drums: false, seconds: 50, seed: 21),
        SongRecipe(key: "aurora-02", title: "Morning Dew", artist: "Aurora Fields", album: "Glass Meadows",
                   trackNumber: 2, bpm: 84, root: 62, scale: ToneSynth.major, progression: [0, 3, 4, 0],
                   lead: .triangle, pad: .sine, drums: false, seconds: 44, seed: 22),
        SongRecipe(key: "engines-01", title: "Clockwork Tides", artist: "The Quiet Engines", album: "Clockwork Tides",
                   trackNumber: 1, bpm: 104, root: 53, scale: ToneSynth.mixolydian, progression: [0, 6, 3, 0],
                   lead: .square, pad: .triangle, drums: true, seconds: 47, seed: 31),
        SongRecipe(key: "engines-02", title: "Brass Compass", artist: "The Quiet Engines", album: "Clockwork Tides",
                   trackNumber: 2, bpm: 118, root: 58, scale: ToneSynth.major, progression: [0, 4, 1, 3],
                   lead: .triangle, pad: .square, drums: true, seconds: 42, seed: 32),
        SongRecipe(key: "luma-01", title: "Paper Satellites", artist: "Luma Vale", album: "Paper Satellites",
                   trackNumber: 1, bpm: 90, root: 59, scale: ToneSynth.minor, progression: [0, 2, 5, 4],
                   lead: .triangle, pad: .sine, drums: true, seconds: 49, seed: 41),
        SongRecipe(key: "luma-02", title: "Low Orbit Lullaby", artist: "Luma Vale", album: "Paper Satellites",
                   trackNumber: 2, bpm: 70, root: 64, scale: ToneSynth.major, progression: [0, 5, 3, 4],
                   lead: .sine, pad: .triangle, drums: false, seconds: 46, seed: 42),
        SongRecipe(key: "neon-ep-01", title: "Afterglow", artist: "Neon Harbor", album: "Afterglow EP",
                   trackNumber: 1, bpm: 100, root: 56, scale: ToneSynth.dorian, progression: [0, 3, 6, 4],
                   lead: .saw, pad: .triangle, drums: true, seconds: 50, seed: 51),
    ]

    static func demoID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "D3E00000-0000-4000-8000-%012d", index))!
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let dir = Self.samplesDir
        var demo: [Track] = []
        for (i, recipe) in Self.demoRecipes.enumerated() {
            let url = dir.appendingPathComponent(recipe.key + ".wav")
            if !FileManager.default.fileExists(atPath: url.path) {
                // Heavy DSP happens off the main actor.
                let data = await Task.detached(priority: .userInitiated) {
                    ToneSynth.wavData(ToneSynth.render(recipe))
                }.value
                try? data.write(to: url, options: .atomic)
            }
            let bars = floor(recipe.seconds / (240 / recipe.bpm))
            let dur = (try? AVAudioPlayer(contentsOf: url).duration) ?? bars * 240 / recipe.bpm
            demo.append(Track(id: Self.demoID(i), title: recipe.title, artist: recipe.artist, album: recipe.album,
                              trackNumber: recipe.trackNumber, duration: dur, url: url, isDemo: true,
                              dateAdded: Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 86_400)))
            preparingProgress = Double(i + 1) / Double(Self.demoRecipes.count)
        }

        var imported: [Track] = []
        var lists: [Playlist] = []
        if let data = try? Data(contentsOf: Self.stateURL),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            imported = saved.imported.filter { FileManager.default.fileExists(atPath: $0.url.path) }
            lists = saved.playlists
        } else {
            lists = [
                Playlist(id: UUID(), name: "Late Night Drive", trackIDs: [0, 2, 9, 5].map(Self.demoID)),
                Playlist(id: UUID(), name: "Calm Focus", trackIDs: [3, 4, 8, 7].map(Self.demoID)),
            ]
        }
        tracks = demo + imported
        let known = Set(tracks.map(\.id))
        playlists = lists.map { var p = $0; p.trackIDs = p.trackIDs.filter(known.contains); return p }
        isPreparing = false
        save()
    }

    func save() {
        let state = SavedState(imported: tracks.filter { !$0.isDemo }, playlists: playlists)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: Self.stateURL, options: .atomic)
        }
    }

    // MARK: - Derived collections

    var albums: [Album] {
        let groups = Dictionary(grouping: tracks) { $0.album + "|" + $0.artist }
        return groups.values.map { ts in
            let sorted = ts.sorted { ($0.trackNumber, $0.title) < ($1.trackNumber, $1.title) }
            return Album(title: sorted[0].album, artist: sorted[0].artist, tracks: sorted)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var artists: [Artist] {
        let byArtist = Dictionary(grouping: albums, by: \.artist)
        return byArtist.map { Artist(name: $0.key, albums: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func track(_ id: UUID) -> Track? { tracks.first { $0.id == id } }

    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIDs.compactMap { track($0) }
    }

    func playlist(_ id: UUID) -> Playlist? { playlists.first { $0.id == id } }

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(name: String, with trackIDs: [UUID] = []) -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let p = Playlist(id: UUID(), name: trimmed.isEmpty ? "Untitled Playlist" : trimmed, trackIDs: trackIDs)
        playlists.append(p)
        save()
        return p
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { playlists[i].name = trimmed; save() }
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func add(_ trackIDs: [UUID], to playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        for t in trackIDs where !playlists[i].trackIDs.contains(t) { playlists[i].trackIDs.append(t) }
        save()
    }

    func remove(_ trackIDs: Set<UUID>, from playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[i].trackIDs.removeAll { trackIDs.contains($0) }
        save()
    }

    func removeFromLibrary(_ ids: Set<UUID>) {
        tracks.removeAll { ids.contains($0.id) && !$0.isDemo }
        for i in playlists.indices { playlists[i].trackIDs.removeAll { ids.contains($0) && track($0) == nil } }
        save()
    }

    // MARK: - Import

    func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Add to Library"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        var types: [UTType] = [.mp3, .mpeg4Audio, .wav, .aiff]
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        panel.allowedContentTypes = types
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await importFiles(urls) }
    }

    func importFiles(_ urls: [URL]) async {
        var added = 0
        for url in urls {
            if tracks.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) { continue }
            if let t = await Self.makeTrack(from: url) {
                tracks.append(t)
                added += 1
            }
        }
        if added == 0 && !urls.isEmpty { lastError = "No new playable audio files were imported." }
        save()
    }

    static func makeTrack(from url: URL) async -> Track? {
        guard (try? AVAudioPlayer(contentsOf: url)) != nil else { return nil }
        let asset = AVURLAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var duration: TimeInterval = 0
        if let d = try? await asset.load(.duration) { duration = d.seconds }
        if let items = try? await asset.load(.commonMetadata) {
            func string(_ id: AVMetadataIdentifier) async -> String? {
                guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first else { return nil }
                return try? await item.load(.stringValue)
            }
            if let v = await string(.commonIdentifierTitle), !v.isEmpty { title = v }
            if let v = await string(.commonIdentifierArtist), !v.isEmpty { artist = v }
            if let v = await string(.commonIdentifierAlbumName), !v.isEmpty { album = v }
        }
        if duration <= 0 || !duration.isFinite {
            duration = (try? AVAudioPlayer(contentsOf: url).duration) ?? 0
        }
        return Track(id: UUID(), title: title, artist: artist, album: album, trackNumber: 0,
                     duration: duration, url: url, isDemo: false, dateAdded: Date())
    }
}
