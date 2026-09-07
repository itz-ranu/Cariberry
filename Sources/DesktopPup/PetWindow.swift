import AppKit
import SwiftUI

// MARK: - Panel

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Container view (hit testing + mouse)

final class PetContainerView: NSView {
    var onPress: ((NSPoint) -> Void)?
    var onDragMove: ((NSPoint, NSPoint) -> Void)?      // current, delta
    var onRelease: ((NSPoint, CGVector) -> Void)?
    var onScrub: ((CGFloat) -> Void)?                  // accumulated wiggle distance
    var onRightClick: ((NSEvent) -> Void)?

    private var pressOrigin: NSPoint = .zero
    private var lastPoint: NSPoint = .zero
    private var lastTime: TimeInterval = 0
    private var travelled: CGFloat = 0
    private var scrubBudget: CGFloat = 0
    private var carrying = false

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return Stage.hitRect.contains(local) ? self : nil
    }

    override func resetCursorRects() {
        addCursorRect(Stage.hitRect, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        pressOrigin = event.locationInWindow
        lastPoint = pressOrigin
        lastTime = event.timestamp
        travelled = 0
        scrubBudget = 0
        carrying = false
        onPress?(pressOrigin)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = event.locationInWindow
        let d = CGVector(dx: p.x - lastPoint.x, dy: p.y - lastPoint.y)
        let step = hypot(d.dx, d.dy)
        travelled += step

        if !carrying && hypot(p.x - pressOrigin.x, p.y - pressOrigin.y) > 46 {
            carrying = true
            NSCursor.closedHand.push()
        }

        if carrying {
            onDragMove?(p, NSPoint(x: d.dx, y: d.dy))
        } else {
            scrubBudget += step
            if scrubBudget > 18 { scrubBudget = 0; onScrub?(travelled) }
        }
        lastPoint = p
        lastTime = event.timestamp
    }

    override func mouseUp(with event: NSEvent) {
        let p = event.locationInWindow
        if carrying {
            NSCursor.pop()
            let dt = max(0.008, event.timestamp - lastTime)
            let v = CGVector(dx: (p.x - lastPoint.x) / dt, dy: (p.y - lastPoint.y) / dt)
            onRelease?(p, v)
        } else {
            onScrub?(0)
        }
        carrying = false
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

// MARK: - Controller

@MainActor
final class PetController {
    let pet: Pet
    private var panel: PetPanel!
    private var container: PetContainerView!
    private var timer: Timer?
    private var saveTimer: Timer?
    private var lastFrame = CACurrentMediaTime()
    private var carryGrabOffset: CGSize = .zero
    private var wasAway = false
    var contextMenuProvider: (() -> NSMenu)?

    init(pet: Pet) {
        self.pet = pet
    }

    func start() {
        buildWindow()
        pet.placeAtStart()
        syncWindow(force: true)
        panel.orderFrontRegardless()

        pet.onBark  = { [weak pet] in SoundKit.shared.bark(species: pet?.species ?? .dog, times: Int.random(in: 2...3)) }
        pet.onYip   = { [weak pet] in SoundKit.shared.yip(species: pet?.species ?? .dog) }
        pet.onMunch = { [weak pet] in SoundKit.shared.munch(species: pet?.species ?? .dog) }
        pet.onWhine = { [weak pet] in SoundKit.shared.whine(species: pet?.species ?? .dog) }

        scheduleTimer(pet.desiredFrameInterval)

        let s = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.persist() }
        }
        RunLoop.main.add(s, forMode: .common)
        saveTimer = s

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pet.position.x = min(max(self.pet.position.x, self.pet.minX), self.pet.maxX)
                    self.pet.position.y = self.pet.groundY
                }
            }

        // entrance: greeting matches the time of day
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            let hour = Calendar.current.component(.hour, from: Date())
            let greeting: String
            switch hour {
            case 23, 0...4: greeting = "hi, night owl 🌙 I'm \(self.pet.name) — let's focus quietly"
            case 5...9:     greeting = "good morning!! ☀️ I'm \(self.pet.name), let's get stuff done"
            default:        greeting = "hi!! I'm \(self.pet.name) \(self.pet.species.emoji) I'll keep you focused today"
            }
            self.pet.say(greeting, .excited, 5)
            self.pet.emit(.sparkle, count: 8, at: Stage.head, spread: 50)
            SoundKit.shared.happy(species: self.pet.species)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) { [weak self] in
            self?.pet.say("made with 💗 by Ranu", nil, 2.6)
        }
    }

    private func buildWindow() {
        let rect = NSRect(origin: .zero, size: Stage.size)
        panel = PetPanel(contentRect: rect,
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        applyLevel()

        container = PetContainerView(frame: rect)
        container.autoresizingMask = [.width, .height]

        let host = NSHostingView(rootView: SceneView(pet: pet))
        host.frame = rect
        host.autoresizingMask = [.width, .height]
        host.layer?.backgroundColor = .clear
        container.addSubview(host)
        panel.contentView = container

        container.onPress = { [weak self] p in
            guard let self else { return }
            self.carryGrabOffset = CGSize(width: p.x - Stage.size.width / 2,
                                          height: p.y - Stage.pawInset)
        }
        container.onScrub = { [weak self] _ in self?.pet.petMe() }
        container.onDragMove = { [weak self] p, _ in
            guard let self else { return }
            if self.pet.act != .carried { self.pet.beginCarry() }
            let mouse = NSEvent.mouseLocation
            let newPos = CGPoint(x: mouse.x - self.carryGrabOffset.width,
                                 y: mouse.y - self.carryGrabOffset.height)
            self.pet.carry(to: newPos, velocity: .zero)
            _ = p
        }
        container.onRelease = { [weak self] _, v in
            self?.pet.drop(velocity: v)
        }
        container.onRightClick = { [weak self] event in
            guard let self, let menu = self.contextMenuProvider?() else { return }
            menu.popUp(positioning: nil,
                       at: NSPoint(x: event.locationInWindow.x, y: event.locationInWindow.y),
                       in: self.container)
        }
    }

    func applyLevel() {
        panel.level = Prefs.aboveFullscreen ? .screenSaver : .floating
    }

    // MARK: Frame loop

    private var timerInterval: Double = 0

    private func scheduleTimer(_ interval: Double) {
        timer?.invalidate()
        timerInterval = interval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.frame() }
        }
        t.tolerance = interval * 0.15
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private var awayCheckedAt: CFTimeInterval = 0

    private func frame() {
        let now = CACurrentMediaTime()
        let dt = now - lastFrame
        guard dt >= pet.desiredFrameInterval else { return }
        lastFrame = now

        if now - awayCheckedAt > 1 {
            awayCheckedAt = now
            checkAway()
        }
        updateLook()
        pet.tick(min(0.25, dt))
        syncWindow(force: false)

        let wanted = pet.desiredFrameInterval
        if wanted != timerInterval { scheduleTimer(wanted) }
    }

    private func updateLook() {
        let mouse = NSEvent.mouseLocation
        let origin = panel.frame.origin
        let headScreen = CGPoint(x: origin.x + Stage.head.x,
                                 y: origin.y + (Stage.size.height - Stage.head.y))
        let dx = max(-1, min(1, (mouse.x - headScreen.x) / 260))
        let dy = max(-1, min(1, (headScreen.y - mouse.y) / 220))
        if abs(dx - pet.look.dx) > 0.04 || abs(dy - pet.look.dy) > 0.04 {
            pet.look = CGVector(dx: dx, dy: dy)
        }
        pet.nearCursor = hypot(mouse.x - headScreen.x, mouse.y - headScreen.y) < 130

        // turn to face the human's cursor while loafing
        if pet.act == .idle || pet.act == .sit {
            if abs(mouse.x - headScreen.x) > 90 {
                pet.facing = mouse.x > headScreen.x ? 1 : -1
            }
        }
    }

    private func checkAway() {
        let types: [CGEventType] = [.mouseMoved, .keyDown, .leftMouseDown, .scrollWheel, .rightMouseDown]
        let idle = types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
        let away = idle > 240
        if away != wasAway {
            wasAway = away
            pet.humanIsAway(away)
        }
    }

    private var lastOrigin: CGPoint = .init(x: -99999, y: -99999)

    private func syncWindow(force: Bool) {
        let o = CGPoint(x: pet.position.x - Stage.size.width / 2,
                        y: pet.position.y - Stage.pawInset)
        if force || abs(o.x - lastOrigin.x) > 0.25 || abs(o.y - lastOrigin.y) > 0.25 {
            panel.setFrameOrigin(o)
            lastOrigin = o
        }
    }

    // MARK: Persistence

    func persist() {
        Store.save(PetSave(name: pet.name,
                           hunger: pet.hunger,
                           happiness: pet.happiness,
                           energy: pet.energy,
                           affection: pet.affection,
                           totalFocusMinutes: pet.totalFocusMinutes,
                           treatsEaten: pet.treatsEaten,
                           barksGiven: pet.barksGiven,
                           born: pet.born,
                           siteTime: pet.siteTime,
                           dailyFocus: pet.dailyFocus,
                           categoryTime: pet.categoryTime,
                           xp: pet.xp,
                           lastXPDay: pet.lastXPDay,
                           dailyAppTime: pet.dailyAppTime))
    }

    func callPetToCursor() {
        let mouse = NSEvent.mouseLocation
        pet.comeHere(to: mouse.x)
    }
}
