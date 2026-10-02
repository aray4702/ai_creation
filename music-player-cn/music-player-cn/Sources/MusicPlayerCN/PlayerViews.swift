import SwiftUI
import AppKit

/// Plain icon button with hover feedback.
struct GlyphButton: View {
    var glyph: Glyph
    var size: CGFloat = 16
    var active = false
    var help: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Icon(glyph: glyph, size: size)
                .foregroundStyle(active ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.primary.opacity(hovering ? 0.95 : 0.7)))
                .padding(6)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// Animated favourite toggle.
struct HeartButton: View {
    var track: Track?
    var size: CGFloat = 16
    var alwaysVisible = true
    @Environment(LibraryStore.self) private var library
    @State private var pop = false

    var body: some View {
        let on = library.isFavorite(track)
        Button {
            library.toggleFavorite(track)
            pop = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { pop = false }
        } label: {
            Icon(glyph: on ? .heartFill : .heart, size: size)
                .foregroundStyle(on ? AnyShapeStyle(Theme.accent2) : AnyShapeStyle(Color.primary.opacity(0.6)))
                .scaleEffect(pop ? 1.35 : 1)
                .padding(4)
        }
        .buttonStyle(.plain)
        .disabled(track == nil)
        .opacity(alwaysVisible || on ? 1 : 0)
        .help(on ? "取消收藏" : "收藏")
    }
}

struct ScrubBar: View {
    var fraction: Double
    var onScrub: (Double, Bool) -> Void
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let f = min(max(fraction, 0), 1)
            let active = hovering || dragging
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.14))
                Capsule().fill(Theme.gradient).frame(width: max(0, w * f))
                if active {
                    Circle().fill(Color.white)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: w * f - 6)
                }
            }
            .frame(height: active ? 6 : 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in dragging = true; onScrub(min(max(v.location.x / w, 0), 1), false) }
                .onEnded { v in dragging = false; onScrub(min(max(v.location.x / w, 0), 1), true) })
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: active)
        }
        .frame(height: 16)
    }
}

struct ProgressRow: View {
    @Environment(PlayerEngine.self) private var player
    var fontSize: CGFloat = 11

    var body: some View {
        let total = max(player.duration, 0.01)
        HStack(spacing: 10) {
            Text(formatTime(player.currentTime)).frame(width: 36, alignment: .trailing)
            ScrubBar(fraction: player.currentTime / total) { f, ended in
                player.isScrubbing = !ended
                player.currentTime = f * total
                if ended { player.seek(to: f * total) }
            }
            .disabled(player.current == nil)
            Text(formatTime(player.duration)).frame(width: 36, alignment: .leading)
        }
        .font(Theme.font(fontSize, .medium).monospacedDigit())
        .foregroundStyle(.secondary)
    }
}

struct Transport: View {
    @Environment(PlayerEngine.self) private var player
    var scale: CGFloat = 1
    var showModes = true

    var body: some View {
        HStack(spacing: 14 * scale) {
            if showModes {
                GlyphButton(glyph: .shuffle, size: 14 * scale, active: player.shuffle, help: "随机播放") { player.toggleShuffle() }
            }
            GlyphButton(glyph: .previous, size: 16 * scale, help: "上一首 (⌘←)") { player.previous() }
            Button { player.togglePlayPause() } label: {
                ZStack {
                    Circle().fill(Theme.gradient)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 6, y: 2)
                    Icon(glyph: player.isPlaying ? .pause : .play, size: 15 * scale)
                        .foregroundStyle(.white)
                        .offset(x: player.isPlaying ? 0 : 1.5 * scale)
                }
                .frame(width: 38 * scale, height: 38 * scale)
            }
            .buttonStyle(.plain)
            .help(player.isPlaying ? "暂停 (空格)" : "播放 (空格)")
            GlyphButton(glyph: .next, size: 16 * scale, help: "下一首 (⌘→)") { player.next() }
            if showModes {
                GlyphButton(glyph: player.repeatMode == .one ? .repeatOne : .repeatAll, size: 14 * scale,
                            active: player.repeatMode != .off,
                            help: ["不循环", "列表循环", "单曲循环"][RepeatMode.allCases.firstIndex(of: player.repeatMode)!]) {
                    player.cycleRepeat()
                }
            }
        }
        .disabled(player.queue.isEmpty)
    }
}

struct VolumeControl: View {
    @Environment(PlayerEngine.self) private var player
    var width: CGFloat = 96

    var body: some View {
        HStack(spacing: 4) {
            GlyphButton(glyph: player.volume == 0 ? .mute : (player.volume < 0.5 ? .volumeLow : .volumeHigh),
                        size: 15, help: "静音") {
                player.volume = player.volume > 0 ? 0 : 0.8
            }
            ScrubBar(fraction: Double(player.volume)) { f, _ in player.volume = Float(f) }
                .frame(width: width)
        }
        .help("音量 (⌘↑ / ⌘↓)")
    }
}

// MARK: - 底部播放控制栏

struct PlayerBar: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Group {
                    if let t = player.current { ArtworkView(seed: t.artSeed, cornerRadius: 8) }
                    else {
                        RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08))
                            .overlay(Icon(glyph: .note, size: 20).foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.current?.title ?? "未在播放").font(Theme.font(14, .semibold)).lineLimit(1)
                    Text(player.current?.artist ?? "选择一首歌开始聆听").font(Theme.font(12)).foregroundStyle(.secondary).lineLimit(1)
                }
                HeartButton(track: player.current)
                Spacer(minLength: 0)
            }
            .frame(width: 290, alignment: .leading)

            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Transport()
                ProgressRow().frame(width: 440)
            }
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                GlyphButton(glyph: .queue, size: 16, active: ui.queueVisible, help: "接下来播放 (⌥⌘U)") { ui.toggleQueue() }
                GlyphButton(glyph: .mini, size: 16, active: ui.miniMode, help: "迷你播放器 (⌥⌘M)") {
                    ui.toggleMiniMode(open: openWindow, dismiss: dismissWindow)
                }
                VolumeControl()
            }
            .frame(width: 290)
        }
        .padding(.horizontal, 18)
        .frame(height: 86)
        .background(FrostedGlass(material: .headerView, blending: .withinWindow))
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
    }
}

// MARK: - 接下来播放 (Up Next) 面板

struct UpNextPanel: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("播放队列").font(Theme.font(18, .bold))
                Spacer()
                GlyphButton(glyph: .close, size: 12, help: "关闭") { ui.toggleQueue() }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

            if let cur = player.current {
                Text("正在播放").font(Theme.font(12, .semibold)).foregroundStyle(.secondary).padding(.horizontal, 16)
                HStack(spacing: 10) {
                    ArtworkView(seed: cur.artSeed, cornerRadius: 6).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cur.title).font(Theme.font(13, .semibold)).foregroundStyle(Theme.accent).lineLimit(1)
                        Text(cur.artist).font(Theme.font(11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    EqualizerBars(animating: player.isPlaying)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.1)))
                .padding(.horizontal, 10).padding(.vertical, 6)
            }

            HStack {
                Text("接下来播放").font(Theme.font(12, .semibold)).foregroundStyle(.secondary)
                Text("\(player.upNext.count)").font(Theme.font(11, .bold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).background(Capsule().fill(Color.primary.opacity(0.08)))
                Spacer()
                if !player.upNext.isEmpty {
                    Button("清空") { withAnimation { player.clearUpNext() } }
                        .buttonStyle(.plain).font(Theme.font(12, .semibold)).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)

            if player.upNext.isEmpty {
                VStack(spacing: 8) {
                    Icon(glyph: .queue, size: 30).foregroundStyle(.tertiary)
                    Text("队列为空").font(Theme.font(13, .semibold))
                    Text("右键任意歌曲，选择“下一首播放”或“添加到播放队列”。")
                        .font(Theme.font(11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(player.upNext) { item in
                        QueueRow(item: item)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { player.moveUpNext(from: $0, to: $1) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct QueueRow: View {
    var item: QueueItem
    @Environment(PlayerEngine.self) private var player
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(seed: item.track.artSeed, cornerRadius: 5).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.track.title).font(Theme.font(13, .medium)).lineLimit(1)
                Text(item.track.artist).font(Theme.font(11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if hovering {
                GlyphButton(glyph: .close, size: 10, help: "从队列移除") { withAnimation { player.removeFromUpNext(item) } }
            } else {
                Text(item.track.durationText).font(Theme.font(11).monospacedDigit()).foregroundStyle(.secondary)
            }
            Icon(glyph: .grip, size: 12).foregroundStyle(.tertiary).help("拖动以调整顺序")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { player.jump(to: item) }
        .contextMenu {
            Button("立即播放") { player.jump(to: item) }
            Button("从队列移除") { player.removeFromUpNext(item) }
        }
    }
}

struct EqualizerBars: View {
    var animating: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !animating)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let v = animating ? 0.3 + 0.7 * abs(sin(t * (2.6 + Double(i) * 0.9) + Double(i))) : 0.35
                    Capsule().frame(width: 3, height: 14 * v)
                }
            }
            .frame(width: 20, height: 14, alignment: .bottom)
            .foregroundStyle(Theme.gradient)
        }
    }
}

// MARK: - 迷你播放器窗口

struct MiniPlayerView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(UIState.self) private var ui
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let t = player.current { ArtworkView(seed: t.artSeed, cornerRadius: 10) }
                else { RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.1)) }
            }
            .frame(width: 104, height: 104)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.current?.title ?? "未在播放").font(Theme.font(15, .bold)).lineLimit(1)
                        Text(player.current?.artist ?? "悦听").font(Theme.font(12)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    GlyphButton(glyph: .expand, size: 12, help: "返回完整窗口") {
                        dismissWindow(id: "mini")
                    }
                }
                HStack(spacing: 4) {
                    Transport(scale: 0.9, showModes: false)
                    Spacer()
                    HeartButton(track: player.current, size: 15)
                }
                ProgressRow(fontSize: 9)
            }
        }
        .padding(14)
        .frame(width: 380, height: 132)
        .background(FrostedGlass(material: .hudWindow).ignoresSafeArea())
        .ignoresSafeArea()
        .background(WindowAccessor { w in
            ui.miniWindow = w
            w.level = .floating
            w.isMovableByWindowBackground = true
            w.titlebarAppearsTransparent = true
            w.collectionBehavior.insert(.canJoinAllSpaces)
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
        })
        .onAppear { ui.miniMode = true }
        .onDisappear {
            ui.miniMode = false
            ui.restoreMain()
        }
    }
}
