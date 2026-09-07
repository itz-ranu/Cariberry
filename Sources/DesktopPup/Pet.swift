import AppKit
import SwiftUI

// MARK: - Scene geometry

/// The window is bigger than the pup so speech bubbles and particles have room.
enum Stage {
    static let size = CGSize(width: 280, height: 268)
    static let dogScale: CGFloat = 0.70
    static var dogOrigin: CGPoint {
        CGPoint(x: (size.width - Design.width * dogScale) / 2,
                y: size.height - Design.height * dogScale)
    }
    /// Convert a point in the pup's design space to scene (view) coordinates.
    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: dogOrigin.x + x * dogScale, y: dogOrigin.y + y * dogScale)
    }
    static var head: CGPoint { p(122, 50) }
    /// Where mood particles are born: just above the ears, clear of the face.
    static var aura: CGPoint { p(124, -14) }
    static var body: CGPoint { p(86, 110) }
    static var mouth: CGPoint { p(150, 84) }
    /// How far the paws sit above the bottom edge of the window.
    static var pawInset: CGFloat { size.height - (dogOrigin.y + Design.ground * dogScale) }
    /// Region of the window that swallows clicks: everything else falls through
    /// to whatever is underneath. In AppKit coordinates (origin bottom-left).
    static var hitRect: CGRect {
        let pad: CGFloat = 8
        let left = dogOrigin.x + 4 * dogScale - pad
        let right = dogOrigin.x + 174 * dogScale + pad
        let topDown = dogOrigin.y + 4 * dogScale            // top of the ears
        let bottomDown = dogOrigin.y + Design.ground * dogScale
        return CGRect(x: left,
                      y: size.height - bottomDown - pad,
                      width: right - left,
                      height: (bottomDown - topDown) + pad * 2)
    }
}

// MARK: - Particles

struct Particle: Identifiable {
    enum Kind { case heart, zzz, sparkle, crumb, anger, star, note, sweat, bubble }
    let id = UUID()
    var kind: Kind
    var pos: CGPoint
    var vel: CGVector
    var life: Double
    var maxLife: Double
    var size: Double
    var rot: Double = 0
    var spin: Double = 0
}

// MARK: - Activity verdicts (produced by ActivityMonitor)

enum ActivityKind { case work, distraction, neutral }

struct Verdict {
    var kind: ActivityKind
    var label: String          // "Instagram Reels", "Xcode", ... (page title when there is one)
    var siteKey: String        // stable grouping key for stats: domain, or app name
    var ruleName: String
    var delay: Double          // seconds of tolerance before the pup reacts
    var lines: [String]
    var severity: Int          // 1 = gentle nudge, 2 = full bark
}

// MARK: - The pup's brain

@MainActor
final class Pet: ObservableObject {

    enum Act: Equatable {
        case idle, walk, sit, sleep, eat, bark, love, zoom, carried, fall, scratch
        case stretch, sniff
        case groom    // cat's signature move
    }

    // Vital stats, all 0...1
    @Published var hunger: Double = 0.85       // 1 = full belly
    @Published var happiness: Double = 0.8
    @Published var energy: Double = 0.9
    @Published var affection: Double = 0.5

    @Published var name: String = "Cariberry"
    @Published var species: Species = .dog
    @Published private(set) var act: Act = .idle
    private(set) var phase: Double = 0
    @Published var facing: Double = 1
    var position: CGPoint = .zero              // paw centre, screen coords (y up)
    @Published var squash: Double = 0
    @Published var petting: Double = 0
    @Published var look: CGVector = .zero
    var nearCursor: Bool = false               // your cursor is right next to her
    @Published var particles: [Particle] = []
    @Published var bubbleText: String? = nil
    @Published var bowl: Double = 0            // 0 = no bowl, else fullness

    // focus coaching
    @Published private(set) var focusSeconds: Double = 0
    @Published private(set) var distractSeconds: Double = 0
    @Published var totalFocusMinutes: Double = 0
    @Published var currentActivity: String = "…"
    @Published var lastVerdict: ActivityKind = .neutral
    @Published var treatsEaten: Int = 0
    @Published var barksGiven: Int = 0
    /// Lifetime XP. `level` is derived from it, never stored separately, so the two
    /// can't drift apart.
    @Published var xp: Double = 0
    var lastXPDay: Date = .distantPast
    @Published var born: Date = Date()
    @Published var siteTime: [String: Double] = [:]   // domain/app -> seconds spent, lifetime
    @Published var dailyFocus: [Date: Double] = [:]   // start-of-day -> minutes focused
    @Published var categoryTime: [String: Double] = [:]   // rule name -> seconds, every kind included
    /// start-of-day -> domain/app -> seconds spent, *every* app she's watched you in,
    /// distraction or work or neither. This is the one that actually answers "what
    /// did I do all day": `siteTime` above only ever counted apps a rule recognised,
    /// so anything neutral (Finder, Mail, an app with no rule) was invisible.
    @Published var dailyAppTime: [Date: [String: Double]] = [:]

    // focus timer (pomodoro)
    @Published var timerEndsAt: Date?
    @Published var timerIsBreak = false
    private var timerTotal: TimeInterval = 0
    private var lastTimerNudge: Date = .distantPast

    var moodOverride: (Emotion, Date)?
    private var bubbleUntil: Date = .distantPast
    private var actUntil: Date = .distantPast
    private var actStartedAt: Date = .distantPast
    private var walkTarget: CGFloat?
    private var velocity: CGVector = .zero
    private var nextScold: Date = .distantPast
    private var scoldCount = 0
    private var lastPraise: Date = .distantPast
    private var nextMilestone: Double = 10 * 60
    private var wasDistracted = false
    private var speedMultiplier: Double = 1
    private var lastInteraction: Date = Date()
    private var calledOver = false

    var onBark: (() -> Void)?
    var onYip: (() -> Void)?
    var onMunch: (() -> Void)?
    var onWhine: (() -> Void)?

    // MARK: Derived

    var emotion: Emotion {
        if let (e, until) = moodOverride, until > Date() { return e }
        switch act {
        case .carried: return .dizzy
        case .sleep:   return .sleepy
        case .eat:     return .eating
        case .bark:    return .angry
        case .zoom:    return .playful
        case .love:    return .love
        default: break
        }
        if petting > 0.15 { return .love }

        // everything lined up at once: rare, and worth celebrating
        if hunger > 0.92 && happiness > 0.92 && energy > 0.85 && affection > 0.8
            && (act == .idle || act == .sit) {
            return .blissful
        }

        // properly neglected: worse than plain hungry or sad on their own
        if hunger < 0.12 && happiness < 0.25 { return .worried }

        if hunger < 0.25 { return .hungry }
        if energy < 0.2 { return .sleepy }
        if happiness < 0.3 { return .sad }

        // your cursor parked right next to her while she's just sitting there
        if nearCursor && (act == .idle || act == .sit) { return .curious }

        // ignored for a long stretch while awake and not thrilled about it
        if act == .idle && happiness < 0.7 && Date().timeIntervalSince(lastInteraction) > 200 {
            return .bored
        }

        if happiness > 0.82 && affection > 0.6 { return .happy }
        if happiness > 0.6 { return .happy }
        return .neutral
    }

    var level: Int { Progression.resolve(totalXP: xp).level }
    var levelTitle: String { Progression.title(level: level, species: species) }
    /// 0...1 through the current level.
    var levelProgress: Double {
        let r = Progression.resolve(totalXP: xp)
        return r.needed > 0 ? min(1, r.into / r.needed) : 0
    }
    var xpIntoLevel: Double { Progression.resolve(totalXP: xp).into }
    var xpForThisLevel: Double { Progression.resolve(totalXP: xp).needed }
    var collarTier: Int { Progression.collarTier(level: level) }

    /// Seconds since the current act began: used to ease animations in/out cleanly
    /// instead of them starting or stopping mid-cycle at full speed.
    private var actElapsed: Double { Date().timeIntervalSince(actStartedAt) }

    var pose: DogPose {
        DogPose(emotion: emotion,
                phase: phase,
                walk: (act == .walk ? 1 : (act == .zoom ? 1 : 0)),
                facing: facing,
                squash: squash,
                dangling: act == .carried,
                look: look,
                sit: act == .sit || act == .sleep || act == .groom,
                petting: petting,
                stretching: act == .stretch,
                sniffing: act == .sniff,
                grooming: act == .groom,
                collarTier: collarTier)
    }

    // sleeping barely moves, so it doesn't need 30fps
    var desiredFrameInterval: Double {
        let busy = !particles.isEmpty || bubbleText != nil || petting > 0
        if busy { return 1.0 / 30 }
        switch act {
        case .sleep:            return 1.0 / 8      // barely moves
        case .idle, .sit, .scratch: return 1.0 / 12 // breathing and blinking only
        default:                return 1.0 / 30     // walking, zoomies, barking
        }
    }

    var timerRemaining: TimeInterval? {
        timerEndsAt.map { max(0, $0.timeIntervalSinceNow) }
    }
    var focusTimerRunning: Bool { timerEndsAt != nil && !timerIsBreak }
    var onBreak: Bool { timerEndsAt != nil && timerIsBreak }

    var ageDays: Int { max(0, Calendar.current.dateComponents([.day], from: born, to: Date()).day ?? 0) }

    var statusLine: String {
        if let b = bubbleText, bubbleUntil > Date() { return b }
        return "\(name) is \(emotion.label)"
    }

    // MARK: Screen helpers

    var screen: NSScreen {
        NSScreen.screens.first { $0.frame.contains(position) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    var groundY: CGFloat { screen.visibleFrame.minY + 2 }
    var minX: CGFloat { screen.visibleFrame.minX + 30 }
    var maxX: CGFloat { screen.visibleFrame.maxX - 30 }

    func placeAtStart() {
        let s = NSScreen.main ?? NSScreen.screens[0]
        position = CGPoint(x: s.visibleFrame.midX, y: s.visibleFrame.minY + 2)
    }

    // MARK: Main loop

    func tick(_ dt: Double) {
        phase += dt
        decayStats(dt)
        updateAct(dt)
        updatePhysics(dt)
        updateParticles(dt)

        updateTimer()
        petting = max(0, petting - dt * 0.55)
        squash += (0 - squash) * min(1, dt * 9)
        if bubbleUntil < Date() { bubbleText = nil }
        if let (_, until) = moodOverride, until < Date() { moodOverride = nil }
    }

    private func decayStats(_ dt: Double) {
        let h = dt / (60 * 90)           // empty belly in ~90 min of use
        hunger = max(0, hunger - h)
        energy = act == .sleep ? min(1, energy + dt / (60 * 6)) : max(0, energy - dt / (60 * 150))
        if act == .zoom { energy = max(0, energy - dt / 120) }
        var target = 0.55 + affection * 0.25
        if hunger < 0.2 { target -= 0.35 }
        if energy < 0.15 { target -= 0.15 }
        happiness += (target - happiness) * min(1, dt / 240)
        affection = max(0, affection - dt / (60 * 60 * 8))
        happiness = min(1, max(0, happiness))
    }

    private func updateAct(_ dt: Double) {
        guard act != .carried, act != .fall else { return }

        if let t = walkTarget {
            let dx = t - position.x
            if abs(dx) < 6 {
                walkTarget = nil
                if act == .walk {
                    if calledOver {
                        calledOver = false
                        say(Dialogue.shy.randomElement()!, nil, 2.4)
                        moodOverride = (.shy, Date().addingTimeInterval(2.2))
                    }
                    setAct(.idle, for: Double.random(in: 1.5...4))
                }
            } else {
                facing = dx > 0 ? 1 : -1
                let speed = (act == .zoom ? 420.0 : 78.0) * speedMultiplier
                position.x += CGFloat(speed * dt) * CGFloat(facing)
            }
        }

        guard Date() > actUntil else { return }

        switch act {
        case .bark, .love, .eat, .zoom, .scratch, .stretch, .sniff, .groom:
            bowl = 0
            setAct(.idle, for: Double.random(in: 1...3))
            return
        default: break
        }

        // Autonomous choices
        if energy < 0.16 {
            setAct(.sleep, for: Double.random(in: 25...60))
            say(Dialogue.sleepy.randomElement()!, .sleepy, 4)
            return
        }
        if act == .sleep && energy > 0.6 {
            setAct(.idle, for: 2)
            say(Dialogue.wokeUp.randomElement()!, .happy, 3)
            return
        }
        if act == .sleep { actUntil = Date().addingTimeInterval(20); return }

        if hunger < 0.12 && happiness < 0.25 && Double.random(in: 0...1) < 0.4 {
            say(Dialogue.worried.randomElement()!, .worried, 5)
            onWhine?()
            setAct(.idle, for: 6)
            return
        }
        if hunger < 0.22 && Double.random(in: 0...1) < 0.35 {
            say(Dialogue.hungry(for: species).randomElement()!, .hungry, 5)
            onWhine?()
            setAct(.idle, for: 6)
            return
        }

        if focusTimerRunning && Double.random(in: 0...1) < 0.75 {
            setAct(.sit, for: Double.random(in: 6...14))
            return
        }

        let roll = Double.random(in: 0...1)
        switch roll {
        case ..<0.40:
            if Prefs.roams {
                wander()
            } else {
                setAct(.sit, for: Double.random(in: 4...10))
            }
        case ..<0.56:
            setAct(.sit, for: Double.random(in: 4...10))
        case ..<0.64:
            setAct(.scratch, for: 2.0)
        case ..<0.70:
            setAct(.stretch, for: 2.6)
            say(Dialogue.stretch.randomElement()!, .happy, 2.4)
        case ..<0.75:
            // only the cat has a signature move now; the dog just sniffs around
            // instead, same as the bucket right below this one
            if species == .cat {
                performSignatureMove()
            } else {
                setAct(.sniff, for: 2.2)
                say(Dialogue.sniff.randomElement()!, .curious, 2.0)
            }
        case ..<0.80:
            setAct(.sniff, for: 2.2)
            say(Dialogue.sniff.randomElement()!, .curious, 2.0)
        case ..<0.88:
            setAct(.idle, for: 3)
            let pool: [String]
            switch emotion {
            case .bored:    pool = Dialogue.bored
            case .blissful: pool = Dialogue.blissful
            case .curious:  pool = Dialogue.curious
            default:        pool = Dialogue.timeFlavoredChatter()
            }
            say(pool.randomElement()!, emotion, 3.5)
        default:
            setAct(.idle, for: Double.random(in: 2...6))
        }
    }

    private func updatePhysics(_ dt: Double) {
        switch act {
        case .fall:
            velocity.dy -= 2600 * dt
            position.y += velocity.dy * dt
            position.x += velocity.dx * dt
            if position.y <= groundY {
                position.y = groundY
                let impact = min(1, abs(velocity.dy) / 1400)
                squash = impact
                velocity = .zero
                setAct(.idle, for: 1.2)
                if impact > 0.35 {
                    emit(.star, count: 5, at: Stage.p(94, Design.ground), spread: 40)
                    onYip?()
                    say(Dialogue.landed.randomElement()!, .dizzy, 2)
                    moodOverride = (.dizzy, Date().addingTimeInterval(1.4))
                }
            }
        case .carried:
            break
        default:
            position.y = groundY
        }
        if act != .carried {
            position.x = min(max(position.x, minX), maxX)
        }
    }

    private func updateParticles(_ dt: Double) {
        guard !particles.isEmpty else { return }
        for i in particles.indices {
            particles[i].life -= dt
            particles[i].pos.x += particles[i].vel.dx * dt
            particles[i].pos.y += particles[i].vel.dy * dt
            particles[i].rot += particles[i].spin * dt
            if particles[i].kind == .crumb { particles[i].vel.dy += 420 * dt }
            if particles[i].kind == .heart { particles[i].vel.dx = sin(particles[i].life * 5) * 18 }
            if particles[i].kind == .bubble { particles[i].vel.dx = sin(particles[i].life * 7) * 14 }
        }
        particles.removeAll { $0.life <= 0 }
    }

    // MARK: Acts

    private func setAct(_ a: Act, for seconds: Double) {
        act = a
        actUntil = Date().addingTimeInterval(seconds)
        actStartedAt = Date()
        if a != .walk && a != .zoom { walkTarget = nil }
        if a == .sleep { emitZzzSoon() }
    }

    private func wander() {
        let target = CGFloat.random(in: minX...maxX)
        walkTarget = target
        speedMultiplier = Double.random(in: 0.75...1.3)
        setAct(.walk, for: 30)
    }

    /// The cat's signature move: only called for `.cat`, see the call site.
    private func performSignatureMove() {
        setAct(.groom, for: 3.2)
        say(Dialogue.groom.randomElement()!, .happy, 2.8)
    }

    /// Every XP award goes through here so levelling up is caught in exactly one
    /// place, no matter what earned it.
    func addXP(_ amount: Double) {
        guard amount > 0 else { return }
        let before = level
        xp += amount
        let after = level
        if after > before { celebrateLevelUp(to: after) }
    }

    private func celebrateLevelUp(to newLevel: Int) {
        setAct(.love, for: 4)
        say(Progression.levelUpLine(level: newLevel, species: species), nil, 5)
        moodOverride = (.proud, Date().addingTimeInterval(4))
        emit(.star, count: 10, at: Stage.aura, spread: 70)
        emit(.sparkle, count: 10, at: Stage.aura, spread: 60)
        emit(.heart, count: 6, at: Stage.aura, spread: 40)
        happiness = min(1, happiness + 0.2)
        onYip?()

        // a new collar is a bigger deal than a plain level, so it gets its own beat
        if Progression.collarLevels.contains(newLevel) {
            let tier = Progression.collarTier(level: newLevel)
            let name = Progression.collarName(tier: tier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.say("look!! a \(name) 😻✨", .blissful, 5)
                    self.emit(.sparkle, count: 12, at: Stage.head, spread: 50)
                    self.onYip?()
                }
            }
        }
    }

    /// Cuts short a wander already in progress: used when "roam around" gets
    /// switched off, so staying put takes effect immediately instead of waiting
    /// for whatever walk she's mid-stride on to finish on its own.
    func stayPut() {
        guard act == .walk, !calledOver else { return }
        walkTarget = nil
        setAct(.idle, for: Double.random(in: 2...5))
    }

    func say(_ text: String, _ mood: Emotion? = nil, _ seconds: Double = 3.5) {
        bubbleText = text
        bubbleUntil = Date().addingTimeInterval(seconds)
        if let m = mood { moodOverride = (m, Date().addingTimeInterval(seconds)) }
    }

    func emit(_ kind: Particle.Kind, count: Int, at p: CGPoint, spread: Double = 24) {
        for _ in 0..<count {
            let vx = Double.random(in: -spread...spread)
            let vy: Double
            var life = Double.random(in: 0.9...1.7)
            var size = Double.random(in: 12...20)
            switch kind {
            case .heart:  vy = Double.random(in: -70 ... -34); size = Double.random(in: 13...23)
            case .zzz:    vy = -26; life = 2.6; size = Double.random(in: 15...22)
            case .sparkle: vy = Double.random(in: -60 ... -10); size = Double.random(in: 9...16)
            case .crumb:  vy = Double.random(in: -160 ... -70); size = Double.random(in: 4...7); life = 1.1
            case .anger:  vy = Double.random(in: -50 ... -20); size = Double.random(in: 14...20); life = 0.9
            case .star:   vy = Double.random(in: -90 ... -30); size = Double.random(in: 10...16); life = 0.8
            case .note:   vy = Double.random(in: -60 ... -30); size = Double.random(in: 14...20)
            case .sweat:  vy = Double.random(in: -40 ... -10); size = 12; life = 0.8
            case .bubble: vy = Double.random(in: -50 ... -22); size = Double.random(in: 6...13); life = 1.4
            }
            size *= 0.82
            particles.append(Particle(kind: kind,
                                      pos: CGPoint(x: p.x + Double.random(in: -34...34),
                                                   y: p.y + Double.random(in: -14...4)),
                                      vel: CGVector(dx: vx, dy: vy),
                                      life: life, maxLife: life, size: size,
                                      rot: Double.random(in: -0.3...0.3),
                                      spin: Double.random(in: -1.4...1.4)))
        }
    }

    private func emitZzzSoon() {
        emit(.zzz, count: 1, at: Stage.aura, spread: 6)
    }

    // MARK: Interactions

    func petMe() {
        lastInteraction = Date()
        petting = min(1, petting + 0.55)
        happiness = min(1, happiness + 0.045)
        affection = min(1, affection + 0.03)
        energy = min(1, energy + 0.004)
        emit(.heart, count: 3, at: Stage.aura, spread: 26)
        if act == .sleep { setAct(.idle, for: 2) }
        if Double.random(in: 0...1) < 0.32 {
            addXP(Progression.Award.petted)
            say(Dialogue.petted.randomElement()!, .love, 2.4)
            onYip?()
        }
        moodOverride = (.love, Date().addingTimeInterval(1.6))
    }

    /// She has a real ceiling: once she's full, feeding again does nothing but make
    /// her groan. Stops "feed" from being a free, unlimited happiness/affection button.
    func feed(treat: Bool = false) {
        guard act != .carried else { return }
        lastInteraction = Date()
        if hunger >= 0.95 {
            say(Dialogue.full(for: species).randomElement()!, .bored, 2.5)
            return
        }
        treatsEaten += 1
        addXP(treat ? Progression.Award.treat : Progression.Award.fed)
        bowl = 1
        setAct(.eat, for: treat ? 3.0 : 5.5)
        hunger = min(1, hunger + (treat ? 0.22 : 0.5))
        happiness = min(1, happiness + 0.12)
        affection = min(1, affection + 0.05)
        energy = min(1, energy + 0.08)
        let pool = treat ? Dialogue.treat(for: species) : Dialogue.fed(for: species)
        say(pool.randomElement()!, .eating, 3)
        onMunch?()
        emit(.crumb, count: 8, at: Stage.mouth, spread: 60)
        emit(.heart, count: 2, at: Stage.aura, spread: 20)
    }

    func play() {
        guard act != .carried else { return }
        lastInteraction = Date()
        setAct(.zoom, for: 7)
        walkTarget = CGFloat.random(in: minX...maxX)
        speedMultiplier = 1
        happiness = min(1, happiness + 0.2)
        affection = min(1, affection + 0.05)
        addXP(Progression.Award.played)
        say(Dialogue.play.randomElement()!, .playful, 3)
        emit(.sparkle, count: 10, at: Stage.body, spread: 70)
        onYip?()
    }

    func nap() {
        setAct(.sleep, for: 60)
        say(Dialogue.sleepy.randomElement()!, .sleepy, 3)
    }

    func comeHere(to x: CGFloat) {
        guard act != .carried else { return }
        lastInteraction = Date()
        calledOver = true
        walkTarget = min(max(x, minX), maxX)
        speedMultiplier = 2.6
        setAct(.walk, for: 20)
        say(Dialogue.comeHere.randomElement()!, .excited, 2.5)
        onYip?()
    }

    func beginCarry() {
        lastInteraction = Date()
        setAct(.carried, for: 999)
        say(Dialogue.picked.randomElement()!, .dizzy, 1.6)
        onYip?()
    }

    func carry(to p: CGPoint, velocity v: CGVector) {
        position = p
        velocity = v
        act = .carried
    }

    func drop(velocity v: CGVector) {
        velocity = CGVector(dx: max(-500, min(500, v.dx)), dy: max(-900, min(500, v.dy)))
        setAct(.fall, for: 99)
        happiness = max(0, happiness - 0.01)
    }

    // MARK: Focus timer

    func startTimer(minutes: Double, isBreak: Bool = false) {
        timerTotal = minutes * 60
        timerEndsAt = Date().addingTimeInterval(timerTotal)
        timerIsBreak = isBreak
        lastTimerNudge = Date()
        if isBreak {
            say("break time! \(Int(minutes)) min — go stretch 🧋", .playful, 5)
            setAct(.zoom, for: 5)
        } else {
            resetFocusStreak()
            say("\(Int(minutes)) min lock-in 💪 I'm watching 👀", .alert, 5)
            setAct(.sit, for: 20)
        }
        onYip?()
    }

    func stopTimer() {
        guard timerEndsAt != nil else { return }
        let wasBreak = timerIsBreak
        timerEndsAt = nil
        timerIsBreak = false
        say(wasBreak ? "break's over 🐾" : "timer stopped… we'll go again soon 🥺",
            wasBreak ? .happy : .sad, 3)
    }

    private func updateTimer() {
        guard let end = timerEndsAt else { return }
        let left = end.timeIntervalSinceNow
        if left <= 0 { finishTimer(); return }
        // a quiet check-in every 5 minutes so she isn't silent the whole session
        if !timerIsBreak, left > 70, Date().timeIntervalSince(lastTimerNudge) > 300 {
            lastTimerNudge = Date()
            say("\(Int(ceil(left / 60))) min left — still with me? 💗", .love, 4)
            emit(.heart, count: 3, at: Stage.aura, spread: 22)
        }
    }

    private func finishTimer() {
        let wasBreak = timerIsBreak
        let minutes = Int(timerTotal / 60)
        timerEndsAt = nil
        timerIsBreak = false

        if wasBreak {
            say("break's over! back to it 💪", .excited, 5)
            setAct(.idle, for: 2)
            onYip?()
            return
        }

        happiness = min(1, happiness + 0.25)
        affection = min(1, affection + 0.15)
        addXP(Progression.Award.timerFinished)
        setAct(.love, for: 6)
        say("DONE!! \(minutes) minutes 🎉 I'm so proud of you 💗", nil, 7)
        moodOverride = (.proud, Date().addingTimeInterval(3.5))   // proud first, melts into love after
        emit(.heart, count: 12, at: Stage.aura, spread: 60)
        emit(.sparkle, count: 8, at: Stage.aura, spread: 70)
        onYip?()

        // roll straight into a short break so the rhythm keeps going
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.timerEndsAt == nil else { return }
                self.startTimer(minutes: 5, isBreak: true)
            }
        }
    }

    // MARK: Focus coaching

    func observe(_ v: Verdict, dt: Double) {
        currentActivity = v.label
        lastVerdict = v.kind
        if v.kind != .neutral && !v.siteKey.isEmpty {
            siteTime[v.siteKey, default: 0] += dt
        }
        // unlike siteTime this includes neutral time too, under "Other": the focus/
        // distraction ratio needs the full picture, not just the flagged categories
        categoryTime[v.ruleName == "—" ? "Other" : v.ruleName, default: 0] += dt

        // every app she's watched you in today, distraction or work or neither. This
        // is what a "what did I actually do today" report needs: siteTime above only
        // ever recorded apps a rule flagged, so Finder, Mail, anything with no rule
        // at all was invisible in "Where your time went" no matter how long it ran.
        if !v.siteKey.isEmpty {
            let today = Calendar.current.startOfDay(for: Date())
            dailyAppTime[today, default: [:]][v.siteKey, default: 0] += dt
        }

        switch v.kind {
        case .distraction:
            focusSeconds = 0
            if onBreak {          // she earned you this break, so no barking
                distractSeconds = 0
                return
            }
            if Prefs.inQuietHours {   // quiet hours: she notices, but stays quiet
                distractSeconds = 0
                return
            }
            distractSeconds += dt
            wasDistracted = true
            // during a focus timer her patience is much shorter
            var rule = v
            if focusTimerRunning {
                rule.delay = max(6, v.delay * 0.4)
                rule.severity = max(2, v.severity)
            }
            if distractSeconds > rule.delay && Date() >= nextScold {
                scold(rule)
            }

        case .work:
            if wasDistracted && distractSeconds > 12 {
                say(Dialogue.backToWork.randomElement()!, .happy, 4)
                emit(.sparkle, count: 8, at: Stage.aura, spread: 40)
                happiness = min(1, happiness + 0.08)
                onYip?()
            }
            wasDistracted = false
            distractSeconds = 0
            scoldCount = 0
            nextScold = .distantPast
            focusSeconds += dt
            totalFocusMinutes += dt / 60
            dailyFocus[Calendar.current.startOfDay(for: Date()), default: 0] += dt / 60
            affection = min(1, affection + dt / 3600)

            // a small bonus for showing up at all today, then a steady drip per minute
            let today = Calendar.current.startOfDay(for: Date())
            if lastXPDay != today {
                lastXPDay = today
                addXP(Progression.Award.dailyFirstFocus)
            }
            addXP(Progression.Award.focusMinute * dt / 60)

            if focusSeconds >= nextMilestone {
                adore(minutes: Int(nextMilestone / 60), lines: v.lines)
                nextMilestone += (nextMilestone < 1800 ? 900 : 1800)
            } else if Date().timeIntervalSince(lastPraise) > 210 && act == .idle {
                lastPraise = Date()
                say(v.lines.randomElement() ?? Dialogue.working.randomElement()!, .love, 4)
                emit(.heart, count: 3, at: Stage.aura, spread: 22)
            }

        case .neutral:
            distractSeconds = max(0, distractSeconds - dt * 0.7)
            focusSeconds = max(0, focusSeconds - dt * 0.25)
        }
    }

    private func scold(_ v: Verdict) {
        barksGiven += 1
        scoldCount += 1
        setAct(.bark, for: v.severity >= 2 ? 3.4 : 2.4)
        walkTarget = nil
        happiness = max(0, happiness - 0.03)

        let pool = v.lines.isEmpty ? Dialogue.scold : v.lines
        var line = pool[min(pool.count - 1, (scoldCount - 1) % pool.count)]
        if scoldCount >= 3 { line = Dialogue.scoldHard.randomElement()! }
        say(line, .angry, v.severity >= 2 ? 5 : 4)
        emit(.anger, count: v.severity >= 2 ? 6 : 3, at: Stage.aura, spread: 45)
        if v.severity >= 2 { onBark?() } else { onWhine?() }

        // escalate: 45s, then 35s, then every 25s until they behave
        let gap = max(25.0, 55.0 - Double(scoldCount) * 10)
        nextScold = Date().addingTimeInterval(gap)
    }

    private func adore(minutes: Int, lines: [String]) {
        setAct(.love, for: 5)
        happiness = min(1, happiness + 0.15)
        affection = min(1, affection + 0.12)
        say(Dialogue.milestone(minutes: minutes), .love, 6)
        emit(.heart, count: 10, at: Stage.aura, spread: 55)
        emit(.sparkle, count: 6, at: Stage.body, spread: 60)
        onYip?()
    }

    func resetFocusStreak() {
        focusSeconds = 0
        nextMilestone = 10 * 60
    }

    func humanIsAway(_ away: Bool) {
        if away && act != .sleep && act != .carried {
            setAct(.sleep, for: 300)
        } else if !away && act == .sleep && energy > 0.35 {
            setAct(.idle, for: 2)
            say(Dialogue.wokeUp.randomElement()!, .excited, 3)
        }
    }
}
