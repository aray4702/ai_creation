import Foundation

struct Track: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var title: String
    var artist: String
    var album: String
    var trackNumber: Int
    var duration: TimeInterval
    var url: URL

    var artSeed: UInt64 { stableHash(album + "|" + artist) }
    var durationText: String { formatTime(duration) }
}

/// 推荐歌单
struct Playlist: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var blurb: String
    var trackIDs: [UUID]
    var artSeed: UInt64 { stableHash("playlist:" + id) }
}

struct Album: Identifiable, Hashable {
    var id: String { artist + "|" + title }
    var title: String
    var artist: String
    var year: Int
    var tracks: [Track]
    var artSeed: UInt64 { stableHash(title + "|" + artist) }
    var totalDuration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }
}

struct Artist: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var albums: [Album]
    var tracks: [Track] { albums.flatMap(\.tracks) }
    var artSeed: UInt64 { stableHash("artist:" + name) }
}

/// 页面路由
enum Route: Hashable {
    case home, albums, artists, songs, favorites, search
    case album(String)
    case artist(String)
    case playlist(String)

    var title: String {
        switch self {
        case .home: "精选"
        case .albums: "专辑"
        case .artists: "艺术家"
        case .songs: "歌曲"
        case .favorites: "我的收藏"
        case .search: "搜索"
        case .album: "专辑"
        case .artist: "艺术家"
        case .playlist: "歌单"
        }
    }
}

func stableHash(_ s: String) -> UInt64 {
    var h: UInt64 = 5381
    for b in s.utf8 { h = (h &<< 5) &+ h &+ UInt64(b) }
    return h
}

func formatTime(_ t: TimeInterval) -> String {
    guard t.isFinite, t >= 0 else { return "--:--" }
    let s = Int(t.rounded(.down))
    return String(format: "%d:%02d", s / 60, s % 60)
}

func summary(_ tracks: [Track]) -> String {
    let mins = max(1, Int((tracks.reduce(0) { $0 + $1.duration } / 60).rounded()))
    return "\(tracks.count) 首歌曲 · \(mins) 分钟"
}
