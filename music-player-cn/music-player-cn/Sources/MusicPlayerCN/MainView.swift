import SwiftUI
import AppKit

struct MainView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var ui = ui
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if ui.sidebarVisible {
                        SidebarView().frame(width: 220)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Divider().opacity(ui.sidebarVisible ? 1 : 0)
                    VStack(spacing: 0) {
                        TopBar()
                        DetailRouter()
                    }
                }
                PlayerBar()
            }
            if ui.queueVisible {
                HStack(spacing: 0) {
                    Spacer()
                    UpNextPanel()
                        .frame(width: 320)
                        .background(FrostedGlass(material: .sidebar, blending: .withinWindow))
                        .transition(.move(edge: .trailing))
                        .padding(.bottom, 86)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            if library.isPreparing { PreparingOverlay(progress: library.preparingProgress) }
        }
        .background(WindowAccessor { w in ui.mainWindow = w })
        .task {
            await library.bootstrap()
            await runAutotest()
        }
    }

    private func runAutotest() async {
        guard Autotest.enabled else { return }
        switch Autotest.value(for: "--section") {
        case "albums": ui.select(.albums)
        case "artists": ui.select(.artists)
        case "songs": ui.select(.songs)
        case "favorites": ui.select(.favorites)
        case "playlist": if let p = library.playlists.first { ui.select(.playlist(p.id)) }
        default: ui.select(.home)
        }
        if let first = library.tracks.first {
            player.play(first, in: library.tracks)
            if library.tracks.count > 1 { player.playNext(library.tracks[1]) }
            if library.tracks.count > 2 { player.addToQueue(library.tracks[2]) }
            library.toggleFavorite(first)
        }
        if Autotest.has("--collapse") { ui.toggleSidebar() }
        if Autotest.has("--queue") { ui.toggleQueue() }
        if Autotest.has("--mini") { openWindow(id: "mini") }
        try? await Task.sleep(for: .seconds(1.2))
        if let w = ui.mainWindow { print("MAIN_WINDOW_ID=\(w.windowNumber)") }
        print("AUTOTEST_DONE windows=\(NSApp.windows.filter(\.isVisible).count)")
        Autotest.snapshotAll()
        fflush(stdout)
    }
}

struct PreparingOverlay: View {
    var progress: Double
    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.001)).background(FrostedGlass(material: .fullScreenUI, blending: .withinWindow))
            VStack(spacing: 16) {
                AppMark(size: 52)
                Text("正在生成示范音源…").font(Theme.font(15, .semibold))
                ProgressView(value: progress).frame(width: 220).tint(Theme.accent)
            }
        }
        .ignoresSafeArea()
    }
}

struct TopBar: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        HStack(spacing: 14) {
            GlyphButton(glyph: .sidebar, size: 16, active: ui.sidebarVisible, help: "展开/折叠侧边栏 (⌃⌘S)") { ui.toggleSidebar() }
            if !ui.history.isEmpty {
                GlyphButton(glyph: .back, size: 14, help: "返回") { ui.back() }
            }
            Text(ui.route.title).font(Theme.font(16, .bold))
            Spacer()
            SearchField()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(FrostedGlass(material: .headerView, blending: .withinWindow))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1) }
    }
}

struct SearchField: View {
    @Environment(UIState.self) private var ui
    var body: some View {
        HStack(spacing: 6) {
            Icon(glyph: .search, size: 12).foregroundStyle(.secondary)
            TextField("搜索歌曲、专辑或艺术家", text: Bindable(ui).searchText)
                .textFieldStyle(.plain)
                .font(Theme.font(13))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .frame(width: 240)
    }
}

struct SidebarView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                AppMark(size: 24)
                Text("悦听").font(Theme.font(17, .bold))
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sidebarSection("浏览") {
                        row("精选", .home, .home)
                        row("歌曲", .songs, .songs)
                        row("专辑", .albums, .albums)
                        row("艺术家", .artists, .artists)
                        row("我的收藏", .favorites, .favorites)
                    }
                    sidebarSection("推荐歌单") {
                        ForEach(library.playlists) { p in
                            row(p.name, .playlist(p.id), .playlist(p.id), glyph: .playlist)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            Spacer(minLength: 0)
        }
        .background(FrostedGlass(material: .sidebar, blending: .withinWindow))
    }

    @ViewBuilder
    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.font(11, .bold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 4)
            content()
        }
    }

    private func row(_ title: String, _ match: Route, _ target: Route, glyph: Glyph? = nil) -> some View {
        let icon: Glyph = glyph ?? {
            switch match { case .home: .home; case .songs: .note; case .albums: .album; case .artists: .artist; case .favorites: .heartFill; default: .note }
        }()
        let selected = ui.route == match
        return Button { ui.select(target) } label: {
            HStack(spacing: 10) {
                Icon(glyph: icon, size: 14)
                    .foregroundStyle(selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.secondary))
                Text(title).font(Theme.font(13, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.82))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.accent.opacity(0.14) : .clear))
        }
        .buttonStyle(.plain)
    }
}

struct DetailRouter: View {
    @Environment(LibraryStore.self) private var library
    @Environment(UIState.self) private var ui

    var body: some View {
        Group {
            switch ui.route {
            case .home: HomeView()
            case .albums: AlbumsView()
            case .artists: ArtistsView()
            case .songs: SongsView(title: "歌曲", tracks: library.tracks)
            case .favorites: SongsView(title: "我的收藏", tracks: library.favoriteTracks)
            case .search: SongsView(title: "搜索结果", tracks: library.tracks)
            case .album(let id): AlbumDetailView(albumID: id)
            case .artist(let name): ArtistDetailView(name: name)
            case .playlist(let id): PlaylistDetailView(playlistID: id)
            }
        }
        .id(ui.route)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
