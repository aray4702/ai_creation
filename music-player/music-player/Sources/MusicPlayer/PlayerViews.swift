import SwiftUI
import AppKit

/// Thin Apple Music–style scrubber that thickens on hover. Reports fraction and whether the drag ended.
struct ScrubBar: View {
    var fraction: Double
    var tint: Color = .primary
    var onScrub: (Double, Bool) -> Void
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let f = min(max(fraction, 0), 1)
            let active = hovering || dragging
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.15))
                Capsule().fill(tint.opacity(active ? 0.9 : 0.6)).frame(width: w * f)
                if active {
                    Circle().fill(Color.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .frame(width: 11, height: 11)
                        .offset(x: w * f - 5.5)
                }
            }
            .frame(height: active ? 6 : 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragging = true
                        onScrub(min(max(v.location.x / w, 0), 1), false)
                    }
                    .onEnded { v in
                        dragging = false
                        onScrub(min(max(v.location.x / w, 0), 1), true)
                    }
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: active)
        }
        .frame(height: 16)
    }
}

struct ProgressScrubber: View {
    @Environment(PlayerEngine.self) private var player
    var compact = false

    var body: some View {
        let total = max(player.duration, 0.01)
        VStack(spacing: 0) {
            ScrubBar(fraction: player.currentTime / total) { f, ended in
                player.isScrubbing = !ended
                player.currentTime = f * total
                if ended { player.seek(to: f * total) }
            }
            .disabled(player.current == nil)
            HStack {
                Text(formatTime(player.currentTime))
                Spacer()
                Text("-" + formatTime(max(0, player.duration - player.currentTime)))
            }
            .font(.system(size: compact ? 9 : 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

struct TransportControls: View {
    @Environment(PlayerEngine.self) private var player
    var size: CGFloat = 1
    var showModes = true
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 20 * size) {
            if showModes {
                Button { player.toggleShuffle() } label: {
                    Image(systemName: "shuffle").font(.system(size: 12 * size, weight: .semibold))
                        .foregroundStyle(player.shuffle ? Color.musicRed : color.opacity(0.6))
                }
                .help("Shuffle")
            }
            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.system(size: 17 * size))
            }
            .help("Previous (⌘←)")
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26 * size))
                    .frame(width: 30 * size, height: 30 * size)
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Play/Pause (Space)")
            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 17 * size))
            }
            .help("Next (⌘→)")
            if showModes {
                Button { player.cycleRepeat() } label: {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 12 * size, weight: .semibold))
                        .foregroundStyle(player.repeatMode == .off ? color.opacity(0.6) : Color.musicRed)
                }
                .help("Repeat")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .disabled(player.queue.isEmpty)
    }
}

struct VolumeControl: View {
    @Environment(PlayerEngine.self) private var player
    var width: CGFloat = 100

    var body: some View {
        HStack(spacing: 6) {
            Button { player.volume = player.volume > 0 ? 0 : 0.8 } label: {
                Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 11)).frame(width: 14)
            }
            .buttonStyle(.plain)
            ScrubBar(fraction: Double(player.volume)) { f, _ in player.volume = Float(f) }
                .frame(width: width)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .help("Volume (⌘↑ / ⌘↓)")
    }
}

// MARK: - Bottom Now Playing bar

struct NowPlayingBar: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showQueue = false

    var body: some View {
        HStack(spacing: 18) {
            // Track info
            HStack(spacing: 12) {
                Group {
                    if let t = player.current {
                        ArtworkView(seed: t.artSeed, cornerRadius: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08))
                            .overlay(Image(systemName: "music.note").foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.current?.title ?? "Not Playing")
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(player.current.map { "\($0.artist) — \($0.album)" } ?? "Choose a song to start")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 260, alignment: .leading)

            Spacer(minLength: 0)

            // Transport + progress
            VStack(spacing: 4) {
                TransportControls()
                ProgressScrubber().frame(width: 380)
            }

            Spacer(minLength: 0)

            // Volume, queue, mini player
            HStack(spacing: 14) {
                VolumeControl()
                Button { showQueue.toggle() } label: {
                    Image(systemName: "list.bullet").font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(showQueue ? Color.musicRed : .secondary)
                .help("Up Next")
                .popover(isPresented: $showQueue, arrowEdge: .top) { UpNextPopover() }
                Button { ui.toggleMini(open: openWindow, dismiss: dismissWindow) } label: {
                    Image(systemName: "pip.enter").font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ui.miniVisible ? Color.musicRed : .secondary)
                .help("Mini Player (⌥⌘M)")
            }
            .frame(width: 260, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(height: 80)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

struct UpNextPopover: View {
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Playing Next").font(.headline)
            if player.upNext.isEmpty {
                Text("Nothing queued.").foregroundStyle(.secondary).padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(player.upNext.enumerated()), id: \.offset) { _, t in
                            HStack(spacing: 10) {
                                ArtworkView(seed: t.artSeed, cornerRadius: 3).frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.title).lineLimit(1)
                                    Text(t.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(t.durationText).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .padding(4)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

// MARK: - Mini Player window

struct MiniPlayerView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let t = player.current {
                    ArtworkView(seed: t.artSeed, cornerRadius: 0, title: t.album)
                } else {
                    Rectangle().fill(Color.primary.opacity(0.08))
                        .overlay(Image(systemName: "music.note").font(.system(size: 48)).foregroundStyle(.tertiary))
                }
                if hovering {
                    LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.15), .black.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                    VStack {
                        HStack {
                            Button {
                                dismissWindow(id: "mini")
                                ui.showMainWindow()
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(7).background(Circle().fill(.ultraThinMaterial))
                            }
                            .buttonStyle(.plain)
                            .help("Return to full window")
                            Spacer()
                            VolumeControl(width: 70).foregroundStyle(.white)
                        }
                        Spacer()
                        TransportControls(size: 1.25, showModes: true, color: .white)
                        Spacer()
                    }
                    .padding(12)
                    .transition(.opacity)
                }
            }
            .frame(width: 300, height: 300)
            .clipped()

            VStack(spacing: 6) {
                VStack(spacing: 1) {
                    Text(player.current?.title ?? "Not Playing")
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(player.current?.artist ?? "Music")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                ProgressScrubber(compact: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 300)
        }
        .background(VisualEffectBackground(material: .hudWindow).ignoresSafeArea())
        .ignoresSafeArea()
        .onHover { h in withAnimation(.easeInOut(duration: 0.18)) { hovering = h } }
        .background(WindowAccessor { w in
            ui.miniWindow = w
            w.level = .floating
            w.isMovableByWindowBackground = true
            w.titlebarAppearsTransparent = true
            w.collectionBehavior.insert(.canJoinAllSpaces)
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
        })
        .onAppear {
            ui.miniVisible = true
            if Autotest.has("--hover") { hovering = true }
        }
        .onDisappear { ui.miniVisible = false }
    }
}
