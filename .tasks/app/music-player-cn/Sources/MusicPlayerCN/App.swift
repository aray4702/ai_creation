import SwiftUI
import AppKit

/// Visual identity: coral/rose accent, Avenir Next for Latin text (CJK falls back to the system CJK face).
enum Theme {
    static let accent = Color(red: 1.0, green: 0.36, blue: 0.30)
    static let accent2 = Color(red: 0.93, green: 0.20, blue: 0.52)
    static let gradient = LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Avenir Next", size: size).weight(weight)
    }
}

@Observable
@MainActor
final class UIState {
    var route: Route = .home
    var history: [Route] = []
    var sidebarVisible = true
    var queueVisible = false
    var searchText = ""
    var miniMode = false
    @ObservationIgnored weak var mainWindow: NSWindow?
    @ObservationIgnored weak var miniWindow: NSWindow?

    func go(_ r: Route) {
        guard r != route else { return }
        history.append(route)
        route = r
    }

    func select(_ r: Route) {
        history.removeAll()
        route = r
    }

    func back() {
        if let last = history.popLast() { route = last }
    }

    func toggleSidebar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { sidebarVisible.toggle() }
    }

    func toggleQueue() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { queueVisible.toggle() }
    }

    /// 一键切换迷你模式：隐藏主窗口并打开浮动迷你窗口（再次切换则恢复）。
    func toggleMiniMode(open: OpenWindowAction, dismiss: DismissWindowAction) {
        if miniMode {
            dismiss(id: "mini")
            restoreMain()
        } else {
            open(id: "mini")
            mainWindow?.orderOut(nil)
        }
    }

    func restoreMain() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let secs = Autotest.value(for: "--quit-after").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + secs) { NSApp.terminate(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct YueTingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = LibraryStore()
    @State private var player = PlayerEngine()
    @State private var ui = UIState()

    var body: some Scene {
        Window("悦听", id: "main") {
            MainView()
                .environment(library)
                .environment(player)
                .environment(ui)
                .tint(Theme.accent)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 780)
        .commands { AppCommands(library: library, player: player, ui: ui) }

        Window("迷你播放器", id: "mini") {
            MiniPlayerView()
                .environment(library)
                .environment(player)
                .environment(ui)
                .tint(Theme.accent)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}

struct AppCommands: Commands {
    let library: LibraryStore
    let player: PlayerEngine
    let ui: UIState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(before: .sidebar) {
            Button(ui.sidebarVisible ? "隐藏侧边栏" : "显示侧边栏") { ui.toggleSidebar() }
                .keyboardShortcut("s", modifiers: [.command, .control])
            Button(ui.queueVisible ? "隐藏播放队列" : "显示播放队列") { ui.toggleQueue() }
                .keyboardShortcut("u", modifiers: [.command, .option])
            Divider()
        }
        CommandMenu("播放控制") {
            Button(player.isPlaying ? "暂停" : "播放") { player.togglePlayPause() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("下一首") { player.next() }.keyboardShortcut(.rightArrow, modifiers: .command)
            Button("上一首") { player.previous() }.keyboardShortcut(.leftArrow, modifiers: .command)
            Divider()
            Button("增大音量") { player.volume = min(1, player.volume + 0.1) }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("减小音量") { player.volume = max(0, player.volume - 0.1) }.keyboardShortcut(.downArrow, modifiers: .command)
            Divider()
            Button(library.isFavorite(player.current) ? "取消收藏当前歌曲" : "收藏当前歌曲") {
                library.toggleFavorite(player.current)
            }
            .keyboardShortcut("l", modifiers: .command)
            Button(ui.miniMode ? "退出迷你模式" : "切换到迷你模式") {
                ui.toggleMiniMode(open: openWindow, dismiss: dismissWindow)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }
}

enum Autotest {
    static var enabled: Bool { CommandLine.arguments.contains("--autotest") }
    static func has(_ flag: String) -> Bool { CommandLine.arguments.contains(flag) }
    static func value(for flag: String) -> String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count else { return nil }
        return a[i + 1]
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void

    final class Probe: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let w = window { onWindow?(w) }
        }
    }

    func makeNSView(context: Context) -> Probe {
        let v = Probe()
        v.onWindow = onWindow
        return v
    }

    func updateNSView(_ nsView: Probe, context: Context) {}
}

/// Native AppKit frosted glass (NSVisualEffectView).
struct FrostedGlass: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
