import AVFoundation
import Foundation

/// Tiny synthesiser so every species has its own voice without shipping audio files.
final class SoundKit {
    static let shared = SoundKit()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let fmt: AVAudioFormat?
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var started = false

    private init() {
        fmt = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = 0.45
    }

    private func ensureRunning() {
        guard !started else { return }
        do { try engine.start(); player.play(); started = true } catch { started = false }
    }

    private func play(_ key: String, _ make: () -> [Float]) {
        guard Prefs.sounds else { return }
        guard let fmt else { return }
        ensureRunning()
        guard started else { return }
        let buf: AVAudioPCMBuffer
        if let cached = cache[key] {
            buf = cached
        } else {
            let samples = make()
            guard let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(samples.count)),
                  let ch = b.floatChannelData else { return }
            b.frameLength = AVAudioFrameCount(samples.count)
            for i in 0..<samples.count { ch[0][i] = samples[i] }
            cache[key] = b
            buf = b
        }
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
    }

    // MARK: - Voices
    // Each call picks a per-species synthesis path. A dog barks, a cat hisses:
    // same emotional beat, a genuinely different sound.

    /// The loud "you're distracted" sound.
    func bark(species: Species, times: Int = 2) {
        switch species {
        case .dog:
            play("bark_dog\(times)") {
                var out: [Float] = []
                for i in 0..<times {
                    out += Synth.woof(f0: 470 - Double(i) * 30, drop: 0.46, dur: 0.17, gain: 0.9)
                    out += Synth.silence(0.075)
                }
                return out
            }
        case .cat:
            play("bark_cat") { Synth.hiss(dur: 0.34, gain: 0.55) }
        }
    }

    /// A short, upbeat chirp: used for most everyday interactions (petted, played
    /// with, called over).
    func yip(species: Species) {
        switch species {
        case .dog:
            play("yip_dog") { Synth.woof(f0: 820, drop: 0.62, dur: 0.10, gain: 0.65, noise: 0.10) }
        case .cat:
            play("yip_cat") { Synth.meow(f0Start: 700, f0Peak: 1050, f0End: 850, dur: 0.16, gain: 0.55) }
        }
    }

    /// The soft, sad "I'm hungry / neglected" sound.
    func whine(species: Species) {
        switch species {
        case .dog:
            play("whine_dog") { Synth.whine() }
        case .cat:
            play("whine_cat") { Synth.meow(f0Start: 520, f0Peak: 760, f0End: 420, dur: 0.55, gain: 0.4) }
        }
    }

    /// Eating: a bowl of kibble sounds nothing like a cat's quick, dainty bites.
    func munch(species: Species) {
        switch species {
        case .dog:
            play("munch_dog") {
                var out: [Float] = []
                for i in 0..<4 {
                    out += Synth.crunch(dur: 0.06, gain: 0.5 - Double(i) * 0.05)
                    out += Synth.silence(0.07)
                }
                return out
            }
        case .cat:
            play("munch_cat") {
                var out: [Float] = []
                for i in 0..<5 {
                    out += Synth.crunch(dur: 0.045, gain: (0.32 - Double(i) * 0.03), pitch: 1.6)
                    out += Synth.silence(0.055)
                }
                return out
            }
        }
    }

    /// The celebratory sound: entrance greeting, milestones, waking up happy.
    func happy(species: Species) {
        switch species {
        case .dog:
            play("happy_dog") {
                Synth.woof(f0: 620, drop: 1.9, dur: 0.09, gain: 0.45, noise: 0.05)
                + Synth.silence(0.03)
                + Synth.woof(f0: 880, drop: 2.0, dur: 0.10, gain: 0.45, noise: 0.05)
            }
        case .cat:
            play("happy_cat") { Synth.purr(dur: 0.65, gain: 0.5) }
        }
    }
}

private enum Synth {
    static let sr = 44_100.0

    static func silence(_ dur: Double) -> [Float] {
        [Float](repeating: 0, count: Int(dur * sr))
    }

    /// A single bark syllable: harmonic stack whose pitch drops, plus a noise transient.
    static func woof(f0: Double, drop: Double, dur: Double, gain: Double, noise: Double = 0.22) -> [Float] {
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            let u = t / dur
            let f = f0 * pow(drop, u) * (1 + sin(t * 42) * 0.02)
            phase += f / sr
            var s = 0.0
            for k in 1...7 {
                s += sin(2 * .pi * phase * Double(k)) / Double(k)
            }
            s *= 0.55
            s += Double.random(in: -1...1) * noise * exp(-u * 9)
            // soft low-pass gives it a chesty, doggy body
            lp += (s - lp) * 0.42
            let attack = min(1, t / 0.006)
            let env = attack * exp(-u * 4.2) * (1 - u * 0.15)
            out[i] = Float(lp * env * gain * 0.7)
        }
        return out
    }

    /// Rising-falling nasal whine.
    static func whine() -> [Float] {
        let dur = 0.55
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            let u = t / dur
            let f = 480 + sin(u * .pi) * 380 + sin(t * 15) * 22
            phase += f / sr
            var s = sin(2 * .pi * phase) * 0.7 + sin(4 * .pi * phase) * 0.22
            s += Double.random(in: -1...1) * 0.03
            lp += (s - lp) * 0.5
            let env = min(1, t / 0.05) * min(1, (dur - t) / 0.18)
            out[i] = Float(lp * env * 0.30)
        }
        return out
    }

    /// Kibble crunch: `pitch` scales the noise's low-pass cutoff, higher = lighter/dryer.
    static func crunch(dur: Double, gain: Double, pitch: Double = 1.0) -> [Float] {
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var lp = 0.0
        let coeff = min(0.95, 0.75 * pitch)
        for i in 0..<n {
            let u = Double(i) / Double(n)
            let s = Double.random(in: -1...1)
            lp += (s - lp) * coeff
            out[i] = Float(lp * exp(-u * 6) * gain * 0.5)
        }
        return out
    }

    /// Sustained bandpass-ish noise: a cat's hiss. No pitch, just an angry hot texture.
    static func hiss(dur: Double, gain: Double) -> [Float] {
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var lp1 = 0.0, lp2 = 0.0
        for i in 0..<n {
            let t = Double(i) / sr, u = t / dur
            let s = Double.random(in: -1...1)
            lp1 += (s - lp1) * 0.5      // low-pass...
            lp2 += (lp1 - lp2) * 0.06   // ...minus a slower low-pass = a bandpass-y hiss
            let band = lp1 - lp2
            let attack = min(1, t / 0.02)
            let env = attack * (1 - u * 0.3)
            out[i] = Float(band * env * gain)
        }
        return out
    }

    /// A meow: a formant-ish sweep from `f0Start` up to `f0Peak` and back down to
    /// `f0End`, exactly the "mrrreow" contour a real cat makes.
    static func meow(f0Start: Double, f0Peak: Double, f0End: Double, dur: Double, gain: Double) -> [Float] {
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0, lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            let u = t / dur
            // rises in the first third, eases down for the rest: cats front-load the pitch
            let f: Double = u < 0.35
                ? f0Start + (f0Peak - f0Start) * (u / 0.35)
                : f0Peak + (f0End - f0Peak) * ((u - 0.35) / 0.65)
            phase += f / sr
            var s = sin(2 * .pi * phase) + sin(4 * .pi * phase) * 0.45 + sin(6 * .pi * phase) * 0.15
            s += Double.random(in: -1...1) * 0.02
            lp += (s - lp) * 0.6
            let env = min(1, t / 0.03) * min(1, (dur - t) / 0.12)
            out[i] = Float(lp * env * gain * 0.5)
        }
        return out
    }

    /// A warm, buzzy purr: a low tone whose amplitude is modulated ~28 times a
    /// second, the same trick a real purr uses (laryngeal muscle twitching).
    static func purr(dur: Double, gain: Double) -> [Float] {
        let n = Int(dur * sr)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0, modPhase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            phase += 95.0 / sr
            modPhase += 27.0 / sr
            let carrier = sin(2 * .pi * phase) + sin(4 * .pi * phase) * 0.3
            let mod = 0.55 + 0.45 * sin(2 * .pi * modPhase)
            let attack = min(1, t / 0.08)
            let release = min(1, (dur - t) / 0.15)
            out[i] = Float(carrier * mod * attack * release * gain * 0.5)
        }
        return out
    }

}
