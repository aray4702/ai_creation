import Foundation
import AVFoundation
import Observation

/// A queue entry: the same song may be queued more than once, so entries get their own identity.
struct QueueItem: Identifiable, Hashable {
    let id = UUID()
    let track: Track
}

enum RepeatMode: CaseIterable { case off, all, one }

@Observable
@MainActor
final class PlayerEngine: NSObject, AVAudioPlayerDelegate {
    private(set) var queue: [QueueItem] = []
    private(set) var index = 0
    private(set) var isPlaying = false
    var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var isScrubbing = false
    private(set) var shuffle = false
    var repeatMode: RepeatMode = .all
    var volume: Float = 0.8 {
        didSet { player?.volume = volume; UserDefaults.standard.set(volume, forKey: "volume") }
    }

    var current: Track? { queue.indices.contains(index) ? queue[index].track : nil }
    var upNext: [QueueItem] { queue.indices.contains(index) ? Array(queue[(index + 1)...]) : [] }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?

    override init() {
        super.init()
        if UserDefaults.standard.object(forKey: "volume") != nil {
            volume = UserDefaults.standard.float(forKey: "volume")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let p = self.player, !self.isScrubbing else { return }
                self.currentTime = p.currentTime
            }
        }
    }

    // MARK: - Starting playback

    func play(_ track: Track, in list: [Track]) {
        var ordered = list
        if shuffle {
            ordered.removeAll { $0.id == track.id }
            ordered.shuffle()
            ordered.insert(track, at: 0)
        }
        queue = ordered.map { QueueItem(track: $0) }
        index = ordered.firstIndex(of: track) ?? 0
        load(andPlay: true)
    }

    func playAll(_ list: [Track], shuffled: Bool = false) {
        guard !list.isEmpty else { return }
        shuffle = shuffled
        play(shuffled ? list.randomElement()! : list[0], in: list)
    }

    // MARK: - Up Next management

    func playNext(_ track: Track) {
        if queue.isEmpty { play(track, in: [track]); return }
        queue.insert(QueueItem(track: track), at: index + 1)
    }

    func addToQueue(_ track: Track) {
        if queue.isEmpty { play(track, in: [track]); return }
        queue.append(QueueItem(track: track))
    }

    func removeFromUpNext(_ item: QueueItem) {
        guard let i = queue.firstIndex(of: item), i > index else { return }
        queue.remove(at: i)
    }

    /// Reorders the "up next" section. Offsets are relative to `upNext`.
    func moveUpNext(from source: IndexSet, to destination: Int) {
        var up = upNext
        up.move(fromOffsets: source, toOffset: destination)
        queue = Array(queue[...index]) + up
    }

    func clearUpNext() {
        guard queue.indices.contains(index) else { return }
        queue = Array(queue[...index])
    }

    func jump(to item: QueueItem) {
        guard let i = queue.firstIndex(of: item) else { return }
        index = i
        load(andPlay: true)
    }

    func toggleShuffle() {
        shuffle.toggle()
        if shuffle, queue.indices.contains(index) {
            var rest = upNext
            rest.shuffle()
            queue = Array(queue[...index]) + rest
        }
    }

    func cycleRepeat() {
        let all = RepeatMode.allCases
        repeatMode = all[(all.firstIndex(of: repeatMode)! + 1) % all.count]
    }

    // MARK: - Transport

    func togglePlayPause() {
        guard let p = player else {
            if !queue.isEmpty { load(andPlay: true) }
            return
        }
        if p.isPlaying { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
    }

    func next() { advance(auto: false) }

    func previous() {
        if currentTime > 3 { seek(to: 0); return }
        guard !queue.isEmpty else { return }
        index = index > 0 ? index - 1 : queue.count - 1
        load(andPlay: true)
    }

    func seek(to t: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(t, p.duration))
        currentTime = p.currentTime
    }

    private func advance(auto: Bool) {
        guard !queue.isEmpty else { return }
        if auto && repeatMode == .one { seek(to: 0); player?.play(); isPlaying = true; return }
        if index + 1 < queue.count {
            index += 1
        } else if repeatMode == .all || !auto {
            index = 0
        } else {
            player?.stop(); isPlaying = false; seek(to: 0)
            return
        }
        load(andPlay: true)
    }

    private func load(andPlay: Bool) {
        guard let track = current else { return }
        player?.stop()
        do {
            let p = try AVAudioPlayer(contentsOf: track.url)
            p.delegate = self
            p.volume = volume
            p.prepareToPlay()
            player = p
            duration = p.duration
            currentTime = 0
            if andPlay { p.play() }
            isPlaying = andPlay
        } catch {
            player = nil
            isPlaying = false
            NSLog("无法播放 \(track.url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.advance(auto: true) }
    }
}
