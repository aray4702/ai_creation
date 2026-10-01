import Foundation

struct Track: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var title: String
    var artist: String
    var album: String
    var trackNumber: Int
    var duration: TimeInterval
    var url: URL
    var isDemo: Bool
    var dateAdded: Date

    /// Stable seed for procedural artwork: every track of an album shares the same cover.
    var artSeed: UInt64 { stableHash(album + "|" + artist) }
    var durationText: String { formatTime(duration) }
}

struct Playlist: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var trackIDs: [UUID]
}

struct Album: Identifiable, Hashable {
    var id: String { artist + "|" + title }
    var title: String
    var artist: String
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

enum SidebarItem: Hashable {
    case songs, albums, artists, recentlyAdded
    case playlist(UUID)
}

/// djb2 — unlike `hashValue`, stable across launches.
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
