import Foundation
import AVFoundation
import Observation

enum RepeatMode: CaseIterable {
    case off, all, one
}

/// AVFoundation-backed playback engine with a simple queue.
@Observable
@MainActor
final class PlayerEngine: NSObject, AVAudioPlayerDelegate {
    private(set) var queue: [Track] = []
    private(set) var index: Int = 0
    private(set) var isPlaying = false
    var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var isScrubbing = false
    var shuffle = false
    var repeatMode: RepeatMode = .off
    var volume: Float = 0.8 {
        didSet { player?.volume = volume; UserDefaults.standard.set(volume, forKey: "volume") }
    }

    var current: Track? { queue.indices.contains(index) ? queue[index] : nil }
    var upNext: [Track] { queue.indices.contains(index) ? Array(queue[(index + 1)...]) : [] }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var originalQueue: [Track] = []

    override init() {
        super.init()
        if UserDefaults.standard.object(forKey: "volume") != nil {
            volume = UserDefaults.standard.float(forKey: "volume")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard let p = player, !isScrubbing else { return }
        currentTime = p.currentTime
    }

    // MARK: - Queue control

    func play(_ track: Track, in list: [Track]) {
        originalQueue = list
        if shuffle {
            var rest = list.filter { $0.id != track.id }
            rest.shuffle()
            queue = [track] + rest
            index = 0
        } else {
            queue = list
            index = list.firstIndex(of: track) ?? 0
        }
        load(andPlay: true)
    }

    func playAll(_ list: [Track], shuffled: Bool = false) {
        guard !list.isEmpty else { return }
        shuffle = shuffled
        let first = shuffled ? list.randomElement()! : list[0]
        play(first, in: list)
    }

    func playNext(_ track: Track) {
        if queue.isEmpty { play(track, in: [track]); return }
        queue.insert(track, at: index + 1)
    }

    func addToQueue(_ track: Track) {
        if queue.isEmpty { play(track, in: [track]); return }
        queue.append(track)
    }

    func toggleShuffle() {
        shuffle.toggle()
        guard let cur = current else { return }
        if shuffle {
            var rest = queue.filter { $0.id != cur.id }
            rest.shuffle()
            queue = [cur] + rest
            index = 0
        } else if !originalQueue.isEmpty {
            queue = originalQueue
            index = originalQueue.firstIndex(of: cur) ?? 0
        }
    }

    func cycleRepeat() {
        let all = RepeatMode.allCases
        repeatMode = all[(all.firstIndex(of: repeatMode)! + 1) % all.count]
    }

    /// Drop tracks that no longer exist (e.g. removed from library).
    func prune(validIDs: Set<UUID>) {
        guard let cur = current else { return }
        queue.removeAll { !validIDs.contains($0.id) && $0.id != cur.id }
        index = queue.firstIndex(of: cur) ?? 0
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
        index = index > 0 ? index - 1 : (repeatMode == .all ? queue.count - 1 : 0)
        load(andPlay: isPlaying || player == nil)
    }

    func seek(to time: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(time, p.duration))
        currentTime = p.currentTime
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
    }

    private func advance(auto: Bool) {
        guard !queue.isEmpty else { return }
        if auto && repeatMode == .one { seek(to: 0); player?.play(); isPlaying = true; return }
        if index + 1 < queue.count {
            index += 1
        } else if repeatMode == .all || !auto {
            index = 0
        } else {
            stop()
            index = 0
            load(andPlay: false)
            return
        }
        load(andPlay: auto ? true : (isPlaying || player == nil))
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
            duration = track.duration
            NSLog("Could not play \(track.url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.advance(auto: true) }
    }
}
