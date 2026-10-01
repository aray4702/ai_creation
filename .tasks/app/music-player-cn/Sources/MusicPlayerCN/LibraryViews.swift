import SwiftUI
import AppKit

extension Array where Element == Track {
    func matching(_ q: String) -> [Track] {
        let q = q.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return self }
        return filter { $0.title.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q) || $0.album.localizedCaseInsensitiveContains(q) }
    }
}

struct PillButton: View {
    var title: String
    var glyph: Glyph
    var filled: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon(glyph: glyph, size: 12)
                Text(title).font(Theme.font(13, .semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .foregroundStyle(filled ? Color.white : Theme.accent)
            .background(
                Group {
                    if filled { Capsule().fill(Theme.gradient) }
                    else { Capsule().fill(Theme.accent.opacity(0.12)) }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlayShuffleRow: View {
    var tracks: [Track]
    @Environment(PlayerEngine.self) private var player
    var body: some View {
        HStack(spacing: 10) {
            PillButton(title: "播放", glyph: .play, filled: true) { player.playAll(tracks) }
            PillButton(title: "随机播放", glyph: .shuffle, filled: false) { player.playAll(tracks, shuffled: true) }
        }
        .disabled(tracks.isEmpty)
    }
}

struct TrackRow: View {
    var track: Track
    var list: [Track]
    var index: Int?
    var showAlbum = true
    @Environment(PlayerEngine.self) private var player
    @Environment(LibraryStore.self) private var library
    @State private var hovering = false

    var body: some View {
        let isCurrent = player.current?.id == track.id
        HStack(spacing: 12) {
            ZStack {
                if let index {
                    Text("\(index)").font(Theme.font(12).monospacedDigit()).foregroundStyle(.secondary)
                        .opacity(hovering || isCurrent ? 0 : 1)
                    if hovering && !isCurrent {
                        Icon(glyph: .play, size: 11).foregroundStyle(Theme.accent)
                    }
                    if isCurrent { EqualizerBars(animating: player.isPlaying) }
                }
                .frame(width: 22)
            }
            if index == nil {
                ArtworkView(seed: track.artSeed, cornerRadius: 4).frame(width: 32, height: 32)
                    .overlay { if isCurrent { RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.4)); EqualizerBars(animating: player.isPlaying).foregroundStyle(.white) } }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(Theme.font(13, isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Theme.accent : Color.primary).lineLimit(1)
                if showAlbum {
                    Text("\(track.artist) · \(track.album)").font(Theme.font(11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            HeartButton(track: track, size: 13, alwaysVisible: hovering)
            Text(track.durationText).font(Theme.font(11).monospacedDigit()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.06) : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { player.play(track, in: list) }
        .contextMenu {
            Button("播放") { player.play(track, in: list) }
            Button("下一首播放") { player.playNext(track) }
            Button("添加到播放队列") { player.addToQueue(track) }
            Divider()
            Button(library.isFavorite(track) ? "取消收藏" : "收藏") { library.toggleFavorite(track) }
            Divider()
            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([track.url]) }
        }
    }
}

func summaryHeader(_ title: String, _ tracks: [Track]) -> some View {
    HStack(alignment: .bottom) {
        Text(title).font(Theme.font(26, .bold))
        Spacer()
    }
}

// MARK: - 首页（精选）

struct HomeView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                section("精选专辑", "albums") {
                    LazyHGrid(rows: [GridItem(.fixed(190))], spacing: 18) {
                        ForEach(library.albums.prefix(8)) { album in
                            FeaturedAlbumCard(album: album).frame(width: 150)
                                .onTapGesture { ui.go(.album(album.id)) }
                        }
                    }
                }
                section("推荐歌单", nil) {
                    LazyHGrid(rows: [GridItem(.fixed(210))], spacing: 18) {
                        ForEach(library.playlists) { p in
                            FeaturedPlaylistCard(playlist: p).frame(width: 190)
                                .onTapGesture { ui.go(.playlist(p.id)) }
                        }
                    }
                }
                section("发现艺术家", "artists") {
                    LazyHGrid(rows: [GridItem(.fixed(150))], spacing: 22) {
                        ForEach(library.artists) { a in
                            FeaturedArtistCard(artist: a).frame(width: 110)
                                .onTapGesture { ui.go(.artist(a.name)) }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting).font(Theme.font(13, .semibold)).foregroundStyle(.secondary)
            Text("为你精选").font(Theme.font(30, .bold))
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "早上好" : (h < 18 ? "下午好" : "晚上好")
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, _ route: String?, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(Theme.font(20, .bold))
                Spacer()
                if route == "albums" { Button("查看全部") { ui.go(.albums) }.buttonStyle(.plain).font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent) }
                if route == "artists" { Button("查看全部") { ui.go(.artists) }.buttonStyle(.plain).font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent) }
            }
            ScrollView(.horizontal, showsIndicators: false) { content() }
        }
    }
}

struct FeaturedAlbumCard: View {
    var album: Album
    @Environment(PlayerEngine.self) private var player
    @State private var hovering = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(seed: album.artSeed, cornerRadius: 10, title: album.title)
                .frame(width: 150, height: 150)
                .shadow(color: .black.opacity(hovering ? 0.28 : 0.14), radius: hovering ? 10 : 4, y: 3)
                .overlay(alignment: .bottomTrailing) {
                    if hovering {
                        Button { player.playAll(album.tracks) } label: {
                            Icon(glyph: .play, size: 13).foregroundStyle(.white)
                                .frame(width: 30, height: 30).background(Circle().fill(Theme.gradient)).shadow(radius: 4)
                        }
                        .buttonStyle(.plain).padding(8)
                    }
                }
            Text(album.title).font(Theme.font(13, .semibold)).lineLimit(1)
            Text(album.artist).font(Theme.font(11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct FeaturedPlaylistCard: View {
    var playlist: Playlist
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var player
    @State private var hovering = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hue: Double(playlist.artSeed % 100) / 100, saturation: 0.55, brightness: 0.5),
                                                   Color(hue: Double((playlist.artSeed % 100) / 100) + 0.15, saturation: 0.6, brightness: 0.3)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 6) {
                    Icon(glyph: .playlist, size: 22).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(playlist.name).font(Theme.font(15, .bold)).foregroundStyle(.white).lineLimit(2)
                    Text(playlist.blurb).font(Theme.font(10)).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if hovering {
                    Button { player.playAll(library.tracks(in: playlist)) } label: {
                        Icon(glyph: .play, size: 13).foregroundStyle(Theme.accent)
                            .frame(width: 30, height: 30).background(Circle().fill(.white)).shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)
                }
            }
            .frame(width: 190, height: 170)
            .shadow(color: .black.opacity(hovering ? 0.25 : 0.12), radius: hovering ? 10 : 4, y: 3)
            Text("\(library.tracks(in: playlist).count) 首歌曲").font(Theme.font(11)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct FeaturedArtistCard: View {
    var artist: Artist
    var body: some View {
        VStack(spacing: 8) {
            ArtworkView(seed: artist.artSeed, cornerRadius: 55).frame(width: 110, height: 110).clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            Text(artist.name).font(Theme.font(12, .semibold)).lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - 专辑

struct AlbumsView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui
    var body: some View {
        let albums = library.albums.filter { ui.searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(ui.searchText) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("专辑").font(Theme.font(26, .bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 22)], alignment: .leading, spacing: 26) {
                    ForEach(albums) { album in
                        FeaturedAlbumCard(album: album).onTapGesture { ui.go(.album(album.id)) }
                    }
                }
            }
            .padding(24)
        }
    }
}

struct AlbumDetailView: View {
    var albumID: String
    @Environment(LibraryStore.self) private var library
    var body: some View {
        if let album = library.album(albumID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 22) {
                        ArtworkView(seed: album.artSeed, cornerRadius: 12, title: album.title)
                            .frame(width: 190, height: 190).shadow(color: .black.opacity(0.22), radius: 10, y: 5)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("专辑").font(Theme.font(12, .semibold)).foregroundStyle(.secondary)
                            Text(album.title).font(Theme.font(28, .bold))
                            Text("\(album.artist) · \(album.year)").font(Theme.font(15, .medium)).foregroundStyle(Theme.accent)
                            Text(summary(album.tracks)).font(Theme.font(12)).foregroundStyle(.secondary)
                            Spacer().frame(height: 8)
                            PlayShuffleRow(tracks: album.tracks)
                        }
                        Spacer()
                    }
                    .padding(24)
                    VStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { i, t in
                            TrackRow(track: t, list: album.tracks, index: i + 1, showAlbum: false)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
        } else {
            emptyState("找不到该专辑", .album)
        }
    }
}

// MARK: - 艺术家

struct ArtistsView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui
    var body: some View {
        let artists = library.artists.filter { ui.searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.searchText) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("艺术家").font(Theme.font(26, .bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 24)], spacing: 26) {
                    ForEach(artists) { a in
                        FeaturedArtistCard(artist: a).onTapGesture { ui.go(.artist(a.name)) }
                    }
                }
            }
            .padding(24)
        }
    }
}

struct ArtistDetailView: View {
    var name: String
    @Environment(LibraryStore.self) private var library
    var body: some View {
        if let artist = library.artist(name) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 20) {
                        ArtworkView(seed: artist.artSeed, cornerRadius: 70).frame(width: 140, height: 140).clipShape(Circle())
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(artist.name).font(Theme.font(30, .bold))
                            Text(summary(artist.tracks)).font(Theme.font(13)).foregroundStyle(.secondary)
                            PlayShuffleRow(tracks: artist.tracks)
                        }
                    }
                    Text("专辑").font(Theme.font(19, .bold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 18)], spacing: 20) {
                        ForEach(artist.albums) { FeaturedAlbumCard(album: $0) }
                    }
                    Text("歌曲").font(Theme.font(19, .bold))
                    VStack(spacing: 0) {
                        ForEach(artist.tracks) { t in TrackRow(track: t, list: artist.tracks, index: nil) }
                    }
                }
                .padding(24)
            }
        } else { emptyState("找不到该艺术家", .artist) }
    }
}

// MARK: - 歌曲 / 收藏

struct SongsView: View {
    var title: String
    var tracks: [Track]
    @Environment(UIState.self) private var ui
    var body: some View {
        let shown = tracks.matching(ui.searchText)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(Theme.font(26, .bold))
                        Text(summary(shown)).font(Theme.font(12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PlayShuffleRow(tracks: shown)
                }
                if shown.isEmpty {
                    emptyState("没有找到相关内容", .search)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { i, t in
                            TrackRow(track: t, list: shown, index: i + 1)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - 歌单详情

struct PlaylistDetailView: View {
    var playlistID: String
    @Environment(LibraryStore.self) private var library
    var body: some View {
        if let p = library.playlist(playlistID) {
            let tracks = library.tracks(in: p)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 22) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hue: Double(p.artSeed % 100) / 100, saturation: 0.55, brightness: 0.5),
                                                           Color(hue: Double((p.artSeed % 100) / 100) + 0.15, saturation: 0.6, brightness: 0.3)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Icon(glyph: .playlist, size: 40).foregroundStyle(.white.opacity(0.85)))
                            .frame(width: 190, height: 190)
                            .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("歌单").font(Theme.font(12, .semibold)).foregroundStyle(.secondary)
                            Text(p.name).font(Theme.font(28, .bold))
                            Text(p.blurb).font(Theme.font(13)).foregroundStyle(.secondary)
                            Text(summary(tracks)).font(Theme.font(12)).foregroundStyle(.secondary)
                            Spacer().frame(height: 8)
                            PlayShuffleRow(tracks: tracks)
                        }
                        Spacer()
                    }
                    .padding(24)
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { i, t in
                            TrackRow(track: t, list: tracks, index: i + 1)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
        } else { emptyState("找不到该歌单", .playlist) }
    }
}

@ViewBuilder
func emptyState(_ text: String, _ glyph: Glyph) -> some View {
    VStack(spacing: 10) {
        Icon(glyph: glyph, size: 34).foregroundStyle(.tertiary)
        Text(text).font(Theme.font(14, .medium)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
