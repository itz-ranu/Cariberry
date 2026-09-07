import AppKit
import ServiceManagement
import SwiftUI

@main
struct DesktopPupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let pet = Pet()
    let monitor = ActivityMonitor()
    var controller: PetController!
    var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ note: Notification) {
        // Dev helper: render the pup's expression sheet to a PNG and quit.
        if let idx = CommandLine.arguments.firstIndex(of: "--render-sheet") {
            let path = CommandLine.arguments.count > idx + 1
                ? CommandLine.arguments[idx + 1]
                : NSTemporaryDirectory() + "pup-sheet.png"
            RenderSheet.run(path: path)
            NSApp.terminate(nil)
            return
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--render-scene") {
            let path = CommandLine.arguments.count > idx + 1
                ? CommandLine.arguments[idx + 1]
                : NSTemporaryDirectory() + "pup-scene.png"
            RenderSheet.runScene(path: path)
            NSApp.terminate(nil)
            return
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--render-species-zoom") {
            let path = CommandLine.arguments.count > idx + 1
                ? CommandLine.arguments[idx + 1]
                : NSTemporaryDirectory() + "pup-species-zoom.png"
            RenderSheet.runSpeciesZoom(path: path)
            NSApp.terminate(nil)
            return
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--render-species") {
            let path = CommandLine.arguments.count > idx + 1
                ? CommandLine.arguments[idx + 1]
                : NSTemporaryDirectory() + "pup-species.png"
            RenderSheet.runSpecies(path: path)
            NSApp.terminate(nil)
            return
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--render-stats") {
            let path = CommandLine.arguments.count > idx + 1
                ? CommandLine.arguments[idx + 1]
                : NSTemporaryDirectory() + "pup-stats.png"
            RenderSheet.runStats(path: path)
            NSApp.terminate(nil)
            return
        }

        // Dev helper: play every species' voice in turn, so a sound change can be
        // checked by ear without launching the whole pet.
        if CommandLine.arguments.contains("--test-sounds") {
            var delay = 0.0
            for species in Species.allCases {
                for voice: (Species) -> Void in
                    [{ SoundKit.shared.bark(species: $0) },
                     { SoundKit.shared.yip(species: $0) },
                     { SoundKit.shared.whine(species: $0) },
                     { SoundKit.shared.munch(species: $0) },
                     { SoundKit.shared.happy(species: $0) }] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { voice(species) }
                    delay += 0.9
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1) { NSApp.terminate(nil) }
            return
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--render-icon") {
            let path = CommandLine.arguments.count > idx + 1
                ? CommandLine.arguments[idx + 1]
                : NSTemporaryDirectory() + "pup-icon.png"
            RenderSheet.runIcon(path: path)
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let saved = Store.load()
        pet.name = Prefs.petName
        pet.species = Prefs.species
        pet.hunger = saved.hunger
        pet.happiness = saved.happiness
        pet.energy = saved.energy
        pet.affection = saved.affection
        pet.totalFocusMinutes = saved.totalFocusMinutes
        pet.treatsEaten = saved.treatsEaten
        pet.barksGiven = saved.barksGiven
        pet.born = saved.born
        pet.siteTime = saved.siteTime
        pet.dailyFocus = saved.dailyFocus
        pet.categoryTime = saved.categoryTime
        pet.xp = saved.xp
        pet.lastXPDay = saved.lastXPDay
        pet.dailyAppTime = saved.dailyAppTime

        _ = RuleStore.shared

        controller = PetController(pet: pet)
        controller.start()

        menuBar = MenuBarController(pet: pet, controller: controller, monitor: monitor)
        controller.contextMenuProvider = { [weak self] in
            self?.menuBar.contextMenu() ?? NSMenu()
        }

        monitor.onVerdict = { [weak self] verdict, dt in
            self?.pet.observe(verdict, dt: dt)
        }
        monitor.start()

        LaunchAtLogin.syncToStoredPreference()
    }

    func applicationWillTerminate(_ note: Notification) {
        controller?.persist()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
}
