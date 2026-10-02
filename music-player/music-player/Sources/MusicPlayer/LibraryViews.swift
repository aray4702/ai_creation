import SwiftUI
import AppKit

// MARK: - Shared pieces

struct PlayShuffleButtons: View {
    var tracks: [Track]
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        HStack(spacing: 10) {
            Button { player.playAll(tracks) } label: {
                Label("Play", systemImage: "play.fill").frame(minWidth: 70)
            }
            .buttonStyle(AccentCapsuleStyle(filled: true))
            Button { player.playAll(tracks, shuffled: true) } label: {
                Label("Shuffle", systemImage: "shuffle").frame(minWidth: 70)
            }
            .buttonStyle(AccentCapsuleStyle(filled: false))
        }
        .disabled(tracks.isEmpty)
    }
}

struct AccentCapsuleStyle: ButtonStyle {
    var filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 7)
            .foregroundStyle(filled ? Color.white : Color.musicRed)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(filled ? Color.musicRed : Color.primary.opacity(0.07))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Animated equalizer bars shown next to the playing track.
struct PlayingIndicator: View {
    var animating: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !animating)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<3, id: \.self) { i in
                    let h = animating ? 0.35 + 0.65 * abs(sin(t * (3 + Double(i)) + Double(i))) : 0.4
                    Capsule().frame(width: 2.5, height: 12 * h)
                }
            }
            .frame(width: 12, height: 12, alignment: .bottom)
            .foregroundStyle(Color.musicRed)
        }
    }
}

struct TrackContextMenu: View {
    var ids: Set<UUID>
    var playlistID: UUID?
    var list: [Track]
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui

    var body: some View {
        let selected = list.filter { ids.contains($0.id) }
        Button("Play") { if let f = selected.first { player.play(f, in: list) } }
        Button("Play Next") { for t in selected.reversed() { player.playNext(t) } }
        Button("Play Later") { for t in selected { player.addToQueue(t) } }
        Divider()
        Menu("Add to Playlist") {
            Button("New Playlist…") { ui.newPlaylist(with: selected.map(\.id)) }
            if !library.playlists.isEmpty { Divider() }
            ForEach(library.playlists) { p in
                Button(p.name) { library.add(selected.map(\.id), to: p.id) }
            }
        }
        if let playlistID {
            Button("Remove from Playlist") { library.remove(ids, from: playlistID) }
        }
        Divider()
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting(selected.map(\.url))
        }
        if selected.contains(where: { !$0.isDemo }) {
            Button("Remove from Library", role: .destructive) { library.removeFromLibrary(ids) }
        }
    }
}

/// Apple Music–style song table: artwork, title, artist, album, duration.
struct TrackTable: View {
    var tracks: [Track]
    var playlistID: UUID? = nil
    var showAlbum = true
    var numbered = false
    @Environment(PlayerEngine.self) private var player
    @State private var selection = Set<UUID>()
    @State private var sortOrder: [KeyPathComparator<Track>] = []

    private var rows: [Track] { sortOrder.isEmpty ? tracks : tracks.sorted(using: sortOrder) }

    var body: some View {
        let rows = rows
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Title", value: \.title) { t in
                titleCell(t, number: numbered ? (rows.firstIndex(of: t) ?? 0) + 1 : nil)
            }
            .width(min: 180, ideal: 280)
            TableColumn("Artist", value: \.artist) { t in
                Text(t.artist).foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 170)
            TableColumn("Album", value: \.album) { t in
                Text(t.album).foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 190)
            TableColumn("Time", value: \.duration) { t in
                Text(t.durationText).monospacedDigit().foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 60, max: 80)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            TrackContextMenu(ids: ids, playlistID: playlistID, list: rows)
        } primaryAction: { ids in
            if let t = rows.first(where: { ids.contains($0.id) }) { player.play(t, in: rows) }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    @ViewBuilder
    private func titleCell(_ t: Track, number: Int?) -> some View {
        let isCurrent = player.current?.id == t.id
        HStack(spacing: 10) {
            if let number {
                ZStack {
                    if isCurrent { PlayingIndicator(animating: player.isPlaying) }
                    else { Text("\(number)").foregroundStyle(.secondary).monospacedDigit() }
                }
                .frame(width: 20)
            } else {
                ArtworkView(seed: t.artSeed, cornerRadius: 3)
                    .frame(width: 26, height: 26)
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.45))
                            PlayingIndicator(animating: player.isPlaying).foregroundStyle(.white)
                        }
                    }
            }
            Text(t.title)
                .fontWeight(isCurrent ? .semibold : .regular)
                .foregroundStyle(isCurrent ? Color.musicRed : Color.primary)
                .lineLimit(1)
        }
    }
}

struct PageHeader: View {
    var title: String
    var subtitle: String
    var tracks: [Track]
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 28, weight: .bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            PlayShuffleButtons(tracks: tracks)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

func summary(_ tracks: [Track]) -> String {
    let mins = Int(tracks.reduce(0) { $0 + $1.duration } / 60)
    return "\(tracks.count) song\(tracks.count == 1 ? "" : "s"), \(mins) minute\(mins == 1 ? "" : "s")"
}

// MARK: - Songs

struct SongsView: View {
    var title: String
    var tracks: [Track]
    @Environment(UIState.self) private var ui

    var body: some View {
        let shown = tracks.matching(ui.searchText)
        VStack(spacing: 0) {
            PageHeader(title: title, subtitle: summary(shown), tracks: shown)
            if shown.isEmpty {
                ContentUnavailableView.search(text: ui.searchText)
            } else {
                TrackTable(tracks: shown)
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Albums

struct AlbumsView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui

    var body: some View {
        let q = ui.searchText
        let albums = library.albums.filter {
            q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q)
        }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Albums").font(.system(size: 28, weight: .bold))
                        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 230), spacing: 22)],
                              alignment: .leading, spacing: 28) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) { AlbumCard(album: album) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Albums")
            .navigationDestination(for: Album.self) { AlbumDetailView(albumID: $0.id, fallback: $0) }
        }
    }
}

struct AlbumCard: View {
    var album: Album
    @Environment(PlayerEngine.self) private var player
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(seed: album.artSeed, cornerRadius: 8, title: album.title)
                .shadow(color: .black.opacity(hovering ? 0.3 : 0.15), radius: hovering ? 10 : 4, y: 3)
                .overlay(alignment: .bottomTrailing) {
                    if hovering {
                        Button { player.playAll(album.tracks) } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.musicRed))
                                .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            Text(album.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Text(album.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }
}

struct AlbumDetailView: View {
    var albumID: String
    var fallback: Album
    @Environment(LibraryStore.self) private var library

    var body: some View {
        let album = library.albums.first { $0.id == albumID } ?? fallback
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 24) {
                ArtworkView(seed: album.artSeed, cornerRadius: 10, title: album.title)
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ALBUM").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(album.title).font(.system(size: 30, weight: .bold)).lineLimit(2)
                    Text(album.artist).font(.title3.weight(.medium)).foregroundStyle(Color.musicRed)
                    Text(summary(album.tracks)).font(.subheadline).foregroundStyle(.secondary)
                    Spacer().frame(height: 8)
                    PlayShuffleButtons(tracks: album.tracks)
                }
                Spacer()
            }
            .padding(24)
            TrackTable(tracks: album.tracks, numbered: true)
        }
        .navigationTitle(album.title)
    }
}

// MARK: - Artists

struct ArtistsView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui
    @State private var selected: String?

    var body: some View {
        let q = ui.searchText
        let artists = library.artists.filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }
        let groups = Dictionary(grouping: artists) { String($0.name.prefix(1)).uppercased() }
        let letters = groups.keys.sorted()
        HStack(spacing: 0) {
            List(selection: $selected) {
                ForEach(letters, id: \.self) { letter in
                    Section(letter) {
                        ForEach(groups[letter] ?? []) { a in
                            HStack(spacing: 10) {
                                ArtworkView(seed: a.artSeed, cornerRadius: 16).frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.name)
                                    Text("\(a.albums.count) album\(a.albums.count == 1 ? "" : "s") · \(a.tracks.count) songs")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            .tag(a.name)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(width: 250)
            Divider()
            if let a = artists.first(where: { $0.name == selected }) ?? artists.first {
                ArtistDetailView(artist: a)
            } else {
                ContentUnavailableView("No Artists", systemImage: "music.mic")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Artists")
        .onAppear { if selected == nil { selected = artists.first?.name } }
    }
}

struct ArtistDetailView: View {
    var artist: Artist
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 20) {
                    ArtworkView(seed: artist.artSeed, cornerRadius: 70)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(artist.name).font(.system(size: 32, weight: .bold))
                        Text(summary(artist.tracks)).foregroundStyle(.secondary)
                        PlayShuffleButtons(tracks: artist.tracks)
                    }
                }
                Text("Albums").font(.title2.weight(.bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 18)],
                          alignment: .leading, spacing: 20) {
                    ForEach(artist.albums) { AlbumCard(album: $0) }
                }
                Text("Songs").font(.title2.weight(.bold))
                VStack(spacing: 0) {
                    ForEach(Array(artist.tracks.enumerated()), id: \.element.id) { i, t in
                        SongRow(track: t, list: artist.tracks, striped: i % 2 == 1)
                    }
                }
            }
            .padding(24)
        }
    }
}

/// Lightweight row for use inside scroll views (double-click or play button to start).
struct SongRow: View {
    var track: Track
    var list: [Track]
    var striped: Bool
    @Environment(PlayerEngine.self) private var player
    @State private var hovering = false

    var body: some View {
        let isCurrent = player.current?.id == track.id
        HStack(spacing: 12) {
            ZStack {
                ArtworkView(seed: track.artSeed, cornerRadius: 4).frame(width: 34, height: 34)
                if hovering || isCurrent {
                    RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.45)).frame(width: 34, height: 34)
                    if isCurrent && !hovering { PlayingIndicator(animating: player.isPlaying) }
                    else { Image(systemName: "play.fill").foregroundStyle(.white) }
                }
            }
            .onTapGesture { player.play(track, in: list) }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).foregroundStyle(isCurrent ? Color.musicRed : .primary)
                Text(track.album).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(track.durationText).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.07) :
                                                            (striped ? Color.primary.opacity(0.03) : .clear)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { player.play(track, in: list) }
        .contextMenu { TrackContextMenu(ids: [track.id], playlistID: nil, list: list) }
    }
}

// MARK: - Playlist

struct PlaylistView: View {
    var playlist: Playlist
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui

    var body: some View {
        let tracks = library.tracks(in: playlist)
        let shown = tracks.matching(ui.searchText)
        var seeds: [UInt64] = []
        for t in tracks where !seeds.contains(t.artSeed) { seeds.append(t.artSeed) }
        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 24) {
                MosaicArtworkView(seeds: Array(seeds.prefix(4)), fallbackSeed: stableHash(playlist.name), cornerRadius: 10)
                    .frame(width: 180, height: 180)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("PLAYLIST").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(playlist.name).font(.system(size: 30, weight: .bold)).lineLimit(2)
                    Text(summary(tracks)).font(.subheadline).foregroundStyle(.secondary)
                    Spacer().frame(height: 8)
                    HStack(spacing: 10) {
                        PlayShuffleButtons(tracks: tracks)
                        Button { ui.addSongsTo = playlist } label: { Label("Add Songs", systemImage: "plus") }
                            .buttonStyle(AccentCapsuleStyle(filled: false))
                        Menu {
                            Button("Rename…") { ui.renaming = playlist }
                            Button("Delete Playlist", role: .destructive) {
                                ui.selection = .songs
                                library.deletePlaylist(playlist.id)
                            }
                        } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .frame(width: 30)
                    }
                }
                Spacer()
            }
            .padding(24)
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("This playlist is empty", systemImage: "music.note.list")
                } description: {
                    Text("Add songs with the Add Songs button, or right-click any song and choose Add to Playlist.")
                } actions: {
                    Button("Add Songs…") { ui.addSongsTo = playlist }
                }
            } else {
                TrackTable(tracks: shown, playlistID: playlist.id)
            }
        }
        .navigationTitle(playlist.name)
    }
}
