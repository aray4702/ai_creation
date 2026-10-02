import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var keyMonitor: Any?

    var body: some View {
        @Bindable var ui = ui
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
            } detail: {
                DetailRouter()
                    .id(ui.selection)
            }
            .searchable(text: $ui.searchText, placement: .sidebar, prompt: "Search")
            NowPlayingBar()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { library.presentImportPanel() } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import MP3, M4A or WAV files")
                Button { ui.toggleMini(open: openWindow, dismiss: dismissWindow) } label: {
                    Label("Mini Player", systemImage: ui.miniVisible ? "rectangle.inset.filled.and.person.filled" : "pip.enter")
                }
                .help("Toggle Mini Player (⌥⌘M)")
            }
        }
        .overlay { if library.isPreparing { PreparingOverlay(progress: library.preparingProgress) } }
        .sheet(isPresented: $ui.showNewPlaylistSheet) {
            NameSheet(title: "New Playlist", initial: "", confirm: "Create") { name in
                let p = library.createPlaylist(name: name, with: ui.pendingPlaylistTracks)
                ui.selection = .playlist(p.id)
            }
        }
        .sheet(item: $ui.renaming) { p in
            NameSheet(title: "Rename Playlist", initial: p.name, confirm: "Rename") { name in
                library.renamePlaylist(p.id, to: name)
            }
        }
        .sheet(item: $ui.addSongsTo) { p in
            AddSongsSheet(playlist: p)
        }
        .alert("Import", isPresented: Binding(get: { library.lastError != nil }, set: { if !$0 { library.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(library.lastError ?? "") }
        .background(WindowAccessor { w in ui.mainWindow = w })
        .onChange(of: library.tracks.map(\.id)) { _, ids in player.prune(validIDs: Set(ids)) }
        .task {
            installSpaceBarMonitor()
            await library.bootstrap()
            await runAutotest()
        }
    }

    /// Space toggles playback unless a text field is being edited.
    private func installSpaceBarMonitor() {
        guard keyMonitor == nil else { return }
        let player = player
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 49,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else { return event }
            let editing = NSApp.keyWindow?.firstResponder is NSText
            if editing { return event }
            MainActor.assumeIsolated { player.togglePlayPause() }
            return nil
        }
    }

    private func runAutotest() async {
        guard Autotest.enabled else { return }
        switch Autotest.value(for: "--section") {
        case "albums": ui.selection = .albums
        case "artists": ui.selection = .artists
        case "recent": ui.selection = .recentlyAdded
        case "playlist": ui.selection = library.playlists.first.map { .playlist($0.id) }
        default: ui.selection = .songs
        }
        if let first = library.tracks.first { player.play(first, in: library.tracks) }
        if Autotest.has("--mini") { openWindow(id: "mini") }
        try? await Task.sleep(for: .seconds(1.5))
        if let w = ui.mainWindow { print("MAIN_WINDOW_ID=\(w.windowNumber)") }
        if let w = ui.miniWindow { print("MINI_WINDOW_ID=\(w.windowNumber)") }
        print("AUTOTEST_DONE windows=\(NSApp.windows.filter(\.isVisible).count)")
        Autotest.snapshotAll()
        fflush(stdout)
    }
}

struct PreparingOverlay: View {
    var progress: Double
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 14) {
                Image(systemName: "waveform").font(.system(size: 40)).foregroundStyle(Color.musicRed)
                    .symbolEffect(.variableColor.iterative)
                Text("Synthesizing sample library…").font(.headline)
                ProgressView(value: progress).frame(width: 240)
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        List(selection: $ui.selection) {
            Section("Library") {
                Label("Recently Added", systemImage: "clock").tag(SidebarItem.recentlyAdded)
                Label("Artists", systemImage: "music.mic").tag(SidebarItem.artists)
                Label("Albums", systemImage: "square.stack").tag(SidebarItem.albums)
                Label("Songs", systemImage: "music.note").tag(SidebarItem.songs)
            }
            Section("Playlists") {
                ForEach(library.playlists) { p in
                    Label(p.name, systemImage: "music.note.list")
                        .tag(SidebarItem.playlist(p.id))
                        .contextMenu {
                            Button("Rename…") { ui.renaming = p }
                            Button("Add Songs…") { ui.addSongsTo = p }
                            Divider()
                            Button("Delete Playlist", role: .destructive) {
                                if ui.selection == .playlist(p.id) { ui.selection = .songs }
                                library.deletePlaylist(p.id)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button { ui.newPlaylist() } label: {
                Label("New Playlist", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Detail routing

struct DetailRouter: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui

    var body: some View {
        switch ui.selection {
        case .albums: AlbumsView()
        case .artists: ArtistsView()
        case .recentlyAdded:
            SongsView(title: "Recently Added",
                      tracks: library.tracks.sorted { $0.dateAdded > $1.dateAdded })
        case .playlist(let id):
            if let p = library.playlist(id) { PlaylistView(playlist: p) }
            else { ContentUnavailableView("Playlist not found", systemImage: "music.note.list") }
        case .songs, .none:
            SongsView(title: "Songs", tracks: library.tracks)
        }
    }
}

extension Array where Element == Track {
    func matching(_ query: String) -> [Track] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return self }
        return filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q)
                || $0.album.localizedCaseInsensitiveContains(q)
        }
    }
}

// MARK: - Sheets

struct NameSheet: View {
    var title: String
    var initial: String
    var confirm: String
    var onConfirm: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            TextField("Playlist name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit(commit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(confirm, action: commit).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear { name = initial }
    }

    private func commit() {
        onConfirm(name)
        dismiss()
    }
}

struct AddSongsSheet: View {
    var playlist: Playlist
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var chosen = Set<UUID>()
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Songs to “\(playlist.name)”").font(.headline)
            TextField("Filter", text: $query).textFieldStyle(.roundedBorder)
            List(library.tracks.matching(query)) { t in
                let already = playlist.trackIDs.contains(t.id)
                Toggle(isOn: Binding(get: { already || chosen.contains(t.id) },
                                     set: { on in if on { chosen.insert(t.id) } else { chosen.remove(t.id) } })) {
                    HStack {
                        ArtworkView(seed: t.artSeed, cornerRadius: 3).frame(width: 26, height: 26)
                        VStack(alignment: .leading) {
                            Text(t.title)
                            Text("\(t.artist) — \(t.album)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(already)
            }
            .frame(width: 440, height: 320)
            HStack {
                Text("\(chosen.count) selected").foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    library.add(library.tracks.map(\.id).filter(chosen.contains), to: playlist.id)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty)
            }
        }
        .padding(20)
    }
}
