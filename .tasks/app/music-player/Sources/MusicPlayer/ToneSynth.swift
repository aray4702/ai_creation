import Foundation

/// Oscillator shapes used by the built-in synthesizer.
enum Wave: Sendable {
    case sine, triangle, square, saw

    @inline(__always)
    func sample(_ phase: Double) -> Double {
        let p = phase - floor(phase)
        switch self {
        case .sine: return sin(2 * .pi * p)
        case .triangle: return 4 * abs(p - 0.5) - 1
        case .square: return p < 0.5 ? 0.6 : -0.6
        case .saw: return (2 * p - 1) * 0.7
        }
    }
}

/// A small, deterministic description of a demo song. Rendering it always produces the same audio.
struct SongRecipe: Sendable {
    let key: String          // stable identifier / file name stem
    let title: String
    let artist: String
    let album: String
    let trackNumber: Int
    let bpm: Double
    let root: Int            // MIDI note number of the tonic
    let scale: [Int]         // semitone offsets
    let progression: [Int]   // scale degrees, one per bar
    let lead: Wave
    let pad: Wave
    let drums: Bool
    let seconds: Double
    let seed: UInt64
}

/// Tiny deterministic PRNG so demo tracks are identical on every launch.
struct LCG {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 11
    }
    mutating func unit() -> Double { Double(next() % 1_000_000) / 1_000_000 }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound + 1))
    }
}

enum ToneSynth {
    static let sampleRate = 44_100.0

    static let major = [0, 2, 4, 5, 7, 9, 11]
    static let minor = [0, 2, 3, 5, 7, 8, 10]
    static let dorian = [0, 2, 3, 5, 7, 9, 10]
    static let mixolydian = [0, 2, 4, 5, 7, 9, 10]

    static func midiToHz(_ m: Double) -> Double { 440 * pow(2, (m - 69) / 12) }

    static func scaleNote(_ degree: Int, _ scale: [Int]) -> Int {
        let n = scale.count
        let octave = Int(floor(Double(degree) / Double(n)))
        let idx = ((degree % n) + n) % n
        return scale[idx] + 12 * octave
    }

    /// Renders a full song as mono Float samples in [-1, 1].
    static func render(_ r: SongRecipe) -> [Float] {
        let sr = sampleRate
        let total = Int(r.seconds * sr)
        var buf = [Double](repeating: 0, count: total)
        var rng = LCG(r.seed)
        let beat = 60.0 / r.bpm
        let bar = beat * 4
        let bars = Int(r.seconds / bar)

        func addTone(start: Double, dur: Double, hz: Double, wave: Wave, amp: Double,
                     attack: Double, release: Double, vibrato: Double = 0) {
            let s0 = Int(start * sr)
            let len = Int((dur + release) * sr)
            guard s0 < total else { return }
            let end = min(total, s0 + len)
            let decayRate = 1.2 / max(dur, 0.05)
            var i = s0
            while i < end {
                let t = Double(i - s0) / sr
                var env: Double
                if t < attack { env = t / attack }
                else if t < dur { env = exp(-(t - attack) * decayRate * 0.5) }
                else {
                    let sus = exp(-(dur - attack) * decayRate * 0.5)
                    env = sus * max(0, 1 - (t - dur) / release)
                }
                let vib = vibrato > 0 ? vibrato * sin(2 * .pi * 5.2 * t) : 0
                buf[i] += amp * env * wave.sample(hz * (1 + vib) * t)
                i += 1
            }
        }

        func addKick(at start: Double) {
            let s0 = Int(start * sr), len = Int(0.32 * sr)
            var phase = 0.0
            for i in 0..<len where s0 + i < total {
                let t = Double(i) / sr
                let f = 45 + 95 * exp(-t * 28)
                phase += f / sr
                buf[s0 + i] += 0.55 * exp(-t * 11) * sin(2 * .pi * phase)
            }
        }

        func addNoise(at start: Double, decay: Double, amp: Double, tone: Double = 0) {
            let s0 = Int(start * sr), len = Int(decay * 6 * sr)
            var prev = 0.0
            for i in 0..<len where s0 + i < total {
                let t = Double(i) / sr
                let white = rng.unit() * 2 - 1
                let hp = white - prev   // crude high-pass for crisp hats
                prev = white
                var v = hp * amp * exp(-t / decay)
                if tone > 0 { v += 0.6 * amp * exp(-t / (decay * 0.8)) * sin(2 * .pi * tone * t) }
                buf[s0 + i] += v
            }
        }

        var leadDegree = 7
        for b in 0..<bars {
            let t0 = Double(b) * bar
            let deg = r.progression[b % r.progression.count]
            // Pad chord (triad on the scale degree)
            for k in [0, 2, 4] {
                let m = Double(r.root + 12 + scaleNote(deg + k, r.scale))
                addTone(start: t0, dur: bar * 0.95, hz: midiToHz(m), wave: r.pad, amp: 0.055,
                        attack: 0.25, release: 0.5, vibrato: 0.002)
            }
            // Bass line
            let bassMidi = Double(r.root - 12 + scaleNote(deg, r.scale))
            let pattern: [Double] = r.drums ? [0, 1.5, 2, 3] : [0, 2]
            for (j, p) in pattern.enumerated() {
                let m = j == 3 ? bassMidi + 7 : bassMidi
                addTone(start: t0 + p * beat, dur: beat * 0.8, hz: midiToHz(m), wave: .sine,
                        amp: 0.2, attack: 0.01, release: 0.08)
            }
            // Lead melody after a two-bar intro, leaving the last bar as an outro
            if b >= 2 && b < bars - 1 {
                var step = 0.0
                while step < 4 {
                    let len = rng.unit() < 0.3 ? 1.0 : 0.5
                    if rng.unit() > 0.18 {
                        leadDegree += rng.int(-2...2)
                        leadDegree = min(max(leadDegree, 3), 13)
                        // Gravitate to chord tones on strong beats
                        if step == 0 { leadDegree = deg + 7 + [0, 2, 4][rng.int(0...2)] }
                        let m = Double(r.root + 12 + scaleNote(leadDegree, r.scale))
                        addTone(start: t0 + step * beat, dur: len * beat * 0.9, hz: midiToHz(m),
                                wave: r.lead, amp: 0.085, attack: 0.012, release: 0.12, vibrato: 0.004)
                    }
                    step += len
                }
            }
            // Drums
            if r.drums && b >= 1 {
                for q in 0..<8 {
                    let t = t0 + Double(q) * beat / 2
                    if q == 0 || q == 4 || (q == 5 && b % 2 == 1) { addKick(at: t) }
                    if q == 2 || q == 6 { addNoise(at: t, decay: 0.05, amp: 0.22, tone: 185) }
                    addNoise(at: t, decay: 0.012, amp: q % 2 == 0 ? 0.09 : 0.05)
                }
            }
        }

        // Fade in/out, normalize, soft clip
        let fadeIn = Int(0.4 * sr), fadeOut = Int(2.5 * sr)
        var peak = 1e-9
        for i in 0..<total { peak = max(peak, abs(buf[i])) }
        let gain = 0.95 / peak
        var out = [Float](repeating: 0, count: total)
        for i in 0..<total {
            var v = tanh(buf[i] * gain * 1.1)
            if i < fadeIn { v *= Double(i) / Double(fadeIn) }
            if i > total - fadeOut { v *= Double(total - i) / Double(fadeOut) }
            out[i] = Float(v)
        }
        return out
    }

    /// Encodes mono float samples as a 16-bit PCM WAV file.
    static func wavData(_ samples: [Float], sampleRate: Int = 44_100) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let dataBytes = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + dataBytes)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(dataBytes)
        var pcm = [Int16](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            pcm[i] = Int16(max(-1, min(1, samples[i])) * 32_767)
        }
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }
}
