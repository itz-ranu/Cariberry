import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let pet: Pet
    private let controller: PetController
    private let monitor: ActivityMonitor
    private var item: NSStatusItem!
    private var refresh: Timer?

    init(pet: Pet, controller: PetController, monitor: ActivityMonitor) {
        self.pet = pet
        self.controller = controller
        self.monitor = monitor
        super.init()

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = pet.species.emoji
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateTitle() }
        }
        RunLoop.main.add(t, forMode: .common)
        refresh = t
        updateTitle()
    }

    private func updateTitle() {
        // the neutral mood emoji is a dog face: swap it for whatever species she is,
        // every other mood emoji (😊💗😤 …) already reads fine regardless of species
        var title = pet.emotion == .neutral ? pet.species.emoji : pet.emotion.emoji
        if let left = pet.timerRemaining {
            let m = Int(left) / 60, s = Int(left) % 60
            title += pet.onBreak ? " ☕️\(m):\(String(format: "%02d", s))"
                                  : " ⏱\(m):\(String(format: "%02d", s))"
        } else if pet.lastVerdict == .work && pet.focusSeconds > 60 {
            title += " \(Int(pet.focusSeconds / 60))m"
        } else if pet.lastVerdict == .distraction && pet.distractSeconds > 15 {
            title += " 👀"
        }
        item.button?.title = title
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu)
    }

    /// A fresh menu for right-clicking the pup itself.
    func contextMenu() -> NSMenu {
        let m = NSMenu()
        populate(m)
        return m
    }

    private func populate(_ menu: NSMenu) {
        let moodEmoji = pet.emotion == .neutral ? pet.species.emoji : pet.emotion.emoji
        header(menu, "\(pet.name) is \(pet.emotion.label) \(moodEmoji)")
        levelLine(menu)

        add(menu, "Feed a meal", "🍖", #selector(feed), key: "")
        add(menu, "Give a treat", "🦴", #selector(treat), key: "")
        add(menu, "Play (zoomies!)", "🎾", #selector(play), key: "")
        add(menu, "Pet \(pet.name)", "🫶", #selector(petIt), key: "")
        add(menu, "Come here!", "📣", #selector(come), key: "")
        add(menu, pet.act == .sleep ? "Wake up" : "Nap time", "😴", #selector(nap), key: "")

        menu.addItem(.separator())
        header(menu, "Vitals")
        stat(menu, "Belly", pet.hunger)
        stat(menu, "Happy", pet.happiness)
        stat(menu, "Energy", pet.energy)
        stat(menu, "Love ", pet.affection)

        menu.addItem(.separator())
        header(menu, "Timer")
        if let left = pet.timerRemaining {
            let m = Int(left) / 60, s = Int(left) % 60
            info(menu, (pet.onBreak ? "☕️ break — " : "⏱ focus — ") + "\(m):\(String(format: "%02d", s)) left")
            let stop = NSMenuItem(title: "Stop timer", action: #selector(stopTimer), keyEquivalent: "")
            stop.target = self
            menu.addItem(stop)
        } else {
            for mins in [15, 25, 45, 60] {
                let i = NSMenuItem(title: "Start \(mins)-minute focus", action: #selector(startTimer(_:)), keyEquivalent: "")
                i.target = self
                i.tag = mins
                menu.addItem(i)
            }
            let custom = NSMenuItem(title: "Custom…", action: #selector(startCustomTimer), keyEquivalent: "")
            custom.target = self
            menu.addItem(custom)
        }

        menu.addItem(.separator())
        header(menu, "Focus")
        let streak = Int(pet.focusSeconds / 60)
        let today = Int(pet.totalFocusMinutes)
        info(menu, "Current streak: \(streak) min")
        info(menu, "Lifetime focus: \(today) min")
        info(menu, "Barks given: \(pet.barksGiven)  ·  Treats: \(pet.treatsEaten)")
        let verdictIcon = pet.lastVerdict == .work ? "💗" : (pet.lastVerdict == .distraction ? "😤" : "😐")
        info(menu, "Watching: \(verdictIcon) \(pet.currentActivity)")
        if !Prefs.browserAwareness {
            let warn = NSMenuItem(title: "⚠︎ Turn on browser awareness to catch Reels",
                                  action: #selector(toggleBrowser), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }
        if monitor.automationDenied {
            info(menu, "⚠︎ macOS denied browser access — allow it in")
            info(menu, "   Settings ▸ Privacy ▸ Automation")
        }
        add(menu, "View stats", "📊", #selector(showStats), key: "")

        menu.addItem(.separator())

        let settings = NSMenu()
        check(settings, "Focus coaching", Prefs.focusCoaching, #selector(toggleCoaching))
        check(settings, "Browser awareness (Reels detection)", Prefs.browserAwareness, #selector(toggleBrowser))
        check(settings, "Sounds", Prefs.sounds, #selector(toggleSounds))
        check(settings, "Stay above fullscreen apps", Prefs.aboveFullscreen, #selector(toggleFullscreen))
        check(settings, "Roam around the screen", Prefs.roams, #selector(toggleRoams))
        check(settings, "Launch at login", LaunchAtLogin.isEnabled, #selector(toggleLaunchAtLogin))

        settings.addItem(.separator())
        let quietTitle = "Quiet hours (\(clockLabel(Prefs.quietHoursStart))–\(clockLabel(Prefs.quietHoursEnd)))"
        check(settings, quietTitle, Prefs.quietHoursEnabled, #selector(toggleQuietHours))
        let setQuiet = NSMenuItem(title: "Set quiet hours…", action: #selector(setQuietHours), keyEquivalent: "")
        setQuiet.target = self
        settings.addItem(setQuiet)

        settings.addItem(.separator())
        let rename = NSMenuItem(title: "Rename \(pet.name)…", action: #selector(rename), keyEquivalent: "")
        rename.target = self
        settings.addItem(rename)

        let species = NSMenu()
        for kind in Species.allCases {
            let item = NSMenuItem(title: "\(kind.emoji)  \(kind.displayName)",
                                  action: #selector(chooseSpecies(_:)), keyEquivalent: "")
            item.target = self
            item.state = pet.species == kind ? .on : .off
            item.representedObject = kind.rawValue
            species.addItem(item)
        }
        let speciesItem = NSMenuItem(title: "Choose pet", action: nil, keyEquivalent: "")
        speciesItem.submenu = species
        settings.addItem(speciesItem)

        let block = NSMenuItem(title: "Block a site or app…", action: #selector(blockSite), keyEquivalent: "")
        block.target = self
        settings.addItem(block)
        let edit = NSMenuItem(title: "Edit focus rules…", action: #selector(editRules), keyEquivalent: "")
        edit.target = self
        settings.addItem(edit)
        let reload = NSMenuItem(title: "Reload rules", action: #selector(reloadRules), keyEquivalent: "")
        reload.target = self
        settings.addItem(reload)
        let reset = NSMenuItem(title: "Reset rules to defaults", action: #selector(resetRules), keyEquivalent: "")
        reset.target = self
        settings.addItem(reset)

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settings
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        info(menu, "made with 💗 by Ranu")
        let quit = NSMenuItem(title: "Quit \(pet.name)", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: item helpers

    private func header(_ menu: NSMenu, _ text: String) {
        let i = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        i.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        i.isEnabled = false
        menu.addItem(i)
    }

    /// Level, title and a tiny text progress bar: the same information as the stats
    /// window's card, condensed enough to read at a glance without opening anything.
    private func levelLine(_ menu: NSMenu) {
        let filled = Int((pet.levelProgress * 10).rounded(.down))
        let bar = String(repeating: "▮", count: max(0, min(10, filled)))
            + String(repeating: "▯", count: max(0, 10 - filled))
        let text = "Lv \(pet.level) · \(pet.levelTitle)   \(bar)"
        let i = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        i.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor
        ])
        i.isEnabled = false
        menu.addItem(i)
    }

    private func info(_ menu: NSMenu, _ text: String) {
        let i = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        i.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        ])
        i.isEnabled = false
        menu.addItem(i)
    }

    private func stat(_ menu: NSMenu, _ label: String, _ value: Double) {
        let filled = Int((value * 10).rounded())
        let bar = String(repeating: "▰", count: max(0, min(10, filled)))
              + String(repeating: "▱", count: max(0, 10 - max(0, min(10, filled))))
        info(menu, "\(label)  \(bar)  \(Int(value * 100))%")
    }

    private func add(_ menu: NSMenu, _ title: String, _ emoji: String, _ sel: Selector, key: String) {
        let i = NSMenuItem(title: "\(emoji)  \(title)", action: sel, keyEquivalent: key)
        i.target = self
        menu.addItem(i)
    }

    private func clockLabel(_ hour: Int) -> String {
        let h = hour % 24
        let suffix = h < 12 ? "am" : "pm"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12)\(suffix)"
    }

    private func check(_ menu: NSMenu, _ title: String, _ on: Bool, _ sel: Selector) {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        i.state = on ? .on : .off
        i.target = self
        menu.addItem(i)
    }

    // MARK: actions

    private var statsWindow: NSWindow?

    @objc private func showStats() {
        if let existing = statsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 780),
                           styleMask: [.titled, .closable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "\(pet.name)'s Stats"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        // We keep our own strong reference in `statsWindow` to reopen it later. Without
        // this, closing the window (the red button) makes AppKit over-release it on top
        // of that, deallocating it out from under us: the next "View stats" click then
        // retains a dangling pointer and crashes.
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: StatsView(pet: pet))
        win.center()

        // Belt and suspenders: forget the reference the moment it closes, so there is no
        // path left that could ever reuse a stale window: worst case we just build a new
        // one next time, which is cheap.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                               object: win, queue: .main) { [weak self] _ in
            self?.statsWindow = nil
        }

        statsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func feed()  { pet.feed() }
    @objc private func treat() { pet.feed(treat: true) }
    @objc private func play()  { pet.play() }
    @objc private func petIt() { pet.petMe(); pet.petMe() }
    @objc private func come()  { controller.callPetToCursor() }
    @objc private func nap() {
        if pet.act == .sleep { pet.humanIsAway(false) } else { pet.nap() }
    }

    @objc private func startTimer(_ sender: NSMenuItem) {
        pet.startTimer(minutes: Double(sender.tag))
    }
    @objc private func stopTimer() { pet.stopTimer() }
    @objc private func startCustomTimer() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Focus for how many minutes?"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.stringValue = "30"
        field.alignment = .center
        alert.accessoryView = field
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let mins = Double(field.stringValue.trimmingCharacters(in: .whitespaces)), mins > 0 {
            pet.startTimer(minutes: min(mins, 240))
        }
    }

    @objc private func toggleCoaching() { Prefs.focusCoaching.toggle() }
    @objc private func toggleSounds()   { Prefs.sounds.toggle(); if Prefs.sounds { SoundKit.shared.yip(species: pet.species) } }
    @objc private func toggleFullscreen() {
        Prefs.aboveFullscreen.toggle()
        controller.applyLevel()
    }
    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }
    @objc private func toggleRoams() {
        Prefs.roams.toggle()
        if Prefs.roams {
            pet.say("time to explore again! 🐕", .happy, 3)
        } else {
            pet.stayPut()
            pet.say("okay, staying right here 🐾", .neutral, 3)
        }
    }
    @objc private func toggleBrowser() {
        Prefs.browserAwareness.toggle()
        if Prefs.browserAwareness {
            pet.say("sniffing your tabs now 👃 (say yes to the macOS prompt)", .alert, 6)
        } else {
            pet.say("ok, tabs are private 🙈", .neutral, 3)
        }
    }

    @objc private func toggleQuietHours() {
        Prefs.quietHoursEnabled.toggle()
        if Prefs.quietHoursEnabled {
            pet.say("quiet hours on 🌙 I'll stay soft \(clockLabel(Prefs.quietHoursStart))–\(clockLabel(Prefs.quietHoursEnd))", .neutral, 4)
        } else {
            pet.say("quiet hours off, back to full volume 🐾", .neutral, 3)
        }
    }

    @objc private func setQuietHours() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Quiet hours"
        alert.informativeText = "No barking between these hours (0–23). Use e.g. 22 and 8 for an overnight window."
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        let startField = NSTextField(frame: NSRect(x: 0, y: 0, width: 55, height: 24))
        startField.stringValue = String(Prefs.quietHoursStart)
        startField.alignment = .center
        let toLabel = NSTextField(labelWithString: "to")
        toLabel.frame = NSRect(x: 65, y: 4, width: 20, height: 20)
        let endField = NSTextField(frame: NSRect(x: 95, y: 0, width: 55, height: 24))
        endField.stringValue = String(Prefs.quietHoursEnd)
        endField.alignment = .center
        container.addSubview(startField)
        container.addSubview(toLabel)
        container.addSubview(endField)
        alert.accessoryView = container
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let s = Int(startField.stringValue.trimmingCharacters(in: .whitespaces)),
           let e = Int(endField.stringValue.trimmingCharacters(in: .whitespaces)),
           (0...23).contains(s), (0...23).contains(e) {
            Prefs.quietHoursStart = s
            Prefs.quietHoursEnd = e
            Prefs.quietHoursEnabled = true
            pet.say("quiet hours set: \(clockLabel(s))–\(clockLabel(e)) 🌙", .neutral, 3)
        }
    }

    @objc private func blockSite() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Block a site or app"
        alert.informativeText = "e.g. \"twitter.com\", \"tiktok\", or an app name — I'll bark the moment I see it."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "twitter.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "Block it")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let term = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !term.isEmpty {
                RuleStore.shared.addBlock(term)
                pet.say("\(term) is BANNED now 😤 don't test me", .angry, 4)
                pet.onBark?()
            }
        }
    }

    @objc private func editRules() {
        RuleStore.shared.save()
        NSWorkspace.shared.open(RuleStore.shared.url)
        pet.say("edit the file, then hit Reload rules 📝", .alert, 5)
    }
    @objc private func reloadRules() {
        RuleStore.shared.load()
        pet.say("new rules learned! 🐾", .excited, 3)
        SoundKit.shared.happy(species: pet.species)
    }
    @objc private func resetRules() {
        RuleStore.shared.writeDefaults()
        pet.say("back to my default instincts 🐕", .neutral, 3)
    }

    @objc private func rename() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "What should I be called?"
        alert.informativeText = "Give your pup a name."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = pet.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let n = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty {
                pet.name = n
                Prefs.petName = n
                pet.say("I'm \(n)! 🐶", .excited, 3)
                controller.persist()
            }
        }
    }

    @objc private func chooseSpecies(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = Species(rawValue: raw) else { return }
        guard kind != pet.species else { return }
        pet.species = kind
        Prefs.species = kind
        let line: String
        switch kind {
        case .dog: line = "woof! back to being a dog 🐶"
        case .cat: line = "meow~ I'm a cat now 🐱"
        }
        pet.say(line, .excited, 3)
        pet.onYip?()
    }

    @objc private func quit() {
        controller.persist()
        NSApp.terminate(nil)
    }
}
