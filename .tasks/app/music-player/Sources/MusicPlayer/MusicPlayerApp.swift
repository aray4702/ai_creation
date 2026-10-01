import SwiftUI
import AppKit

extension Color {
    /// Apple Music–style accent red.
    static let musicRed = Color(red: 0.98, green: 0.18, blue: 0.29)
}

@Observable
@MainActor
final class UIState {
    var selection: SidebarItem? = .songs
    var searchText = ""
    var miniVisible = false
    var showNewPlaylistSheet = false
    var pendingPlaylistTracks: [UUID] = []
    var renaming: Playlist?
    var addSongsTo: Playlist?
    @ObservationIgnored weak var mainWindow: NSWindow?
    @ObservationIgnored weak var miniWindow: NSWindow?

    func newPlaylist(with tracks: [UUID] = []) {
        pendingPlaylistTracks = tracks
        showNewPlaylistSheet = true
    }

    func toggleMini(open: OpenWindowAction, dismiss: DismissWindowAction) {
        if miniVisible { dismiss(id: "mini") } else { open(id: "mini") }
    }

    func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Running as a bare SwiftPM executable: become a regular foreground app with a Dock icon.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let secs = Autotest.value(for: "--quit-after").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + secs) { NSApp.terminate(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MusicPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = LibraryStore()
    @State private var player = PlayerEngine()
    @State private var ui = UIState()

    var body: some Scene {
        Window("Music", id: "main") {
            ContentView()
                .environment(library)
                .environment(player)
                .environment(ui)
                .tint(.musicRed)
                .frame(minWidth: 920, minHeight: 580)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified)
        .commands { PlayerCommands(library: library, player: player, ui: ui) }

        Window("Mini Player", id: "mini") {
            MiniPlayerView()
                .environment(library)
                .environment(player)
                .environment(ui)
                .tint(.musicRed)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}

struct PlayerCommands: Commands {
    let library: LibraryStore
    let player: PlayerEngine
    let ui: UIState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Playlist") { ui.newPlaylist() }
                .keyboardShortcut("n")
            Button("Import Audio Files…") { library.presentImportPanel() }
                .keyboardShortcut("o")
        }
        CommandMenu("Controls") {
            Button(player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Next") { player.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Previous") { player.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Divider()
            Button("Increase Volume") { player.volume = min(1, player.volume + 0.1) }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("Decrease Volume") { player.volume = max(0, player.volume - 0.1) }
                .keyboardShortcut(.downArrow, modifiers: .command)
            Divider()
            Toggle("Shuffle", isOn: Binding(get: { player.shuffle }, set: { _ in player.toggleShuffle() }))
            Button("Repeat: \(repeatLabel)") { player.cycleRepeat() }
            Divider()
            Button(ui.miniVisible ? "Close Mini Player" : "Open Mini Player") {
                ui.toggleMini(open: openWindow, dismiss: dismissWindow)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }

    private var repeatLabel: String {
        switch player.repeatMode { case .off: "Off"; case .all: "All"; case .one: "One" }
    }
}

/// Command-line hooks for automated verification (harmless in normal use).
enum Autotest {
    static var enabled: Bool { CommandLine.arguments.contains("--autotest") }
    static func has(_ flag: String) -> Bool { CommandLine.arguments.contains(flag) }
    static func value(for flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

/// Gives SwiftUI views access to their hosting NSWindow.
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

/// AppKit vibrancy for true macOS translucency.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
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
