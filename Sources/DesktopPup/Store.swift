import Foundation
import OSLog

private let storeLogger = Logger(subsystem: "com.desktoppup.cariberry", category: "storage")

struct PetSave: Codable {
    var name = "Cariberry"
    var hunger = 0.85
    var happiness = 0.8
    var energy = 0.9
    var affection = 0.5
    var totalFocusMinutes = 0.0
    var treatsEaten = 0
    var barksGiven = 0
    var born = Date()
    var lastSeen = Date()
    var siteTime: [String: Double] = [:]
    var dailyFocus: [Date: Double] = [:]   // start-of-day -> minutes focused that day
    var categoryTime: [String: Double] = [:]   // rule name -> seconds, every kind included
    var xp = 0.0                               // lifetime XP; level is derived from it
    var lastXPDay = Date.distantPast           // so the daily bonus lands once a day
    /// start-of-day -> domain/app -> seconds spent, every app, every kind included:
    /// see the comment on `Pet.dailyAppTime` for why this exists alongside siteTime.
    var dailyAppTime: [Date: [String: Double]] = [:]
    // a running focus timer used to just vanish on quit/relaunch with no trace it
    // ever existed. persisting these three lets Store.load() resume it if it's
    // still genuinely in progress, or quietly drop it if time has already run out.
    var timerEndsAt: Date? = nil
    var timerIsBreak = false
    var timerTotal: Double = 0

    init(name: String = "Cariberry", hunger: Double = 0.85, happiness: Double = 0.8,
         energy: Double = 0.9, affection: Double = 0.5, totalFocusMinutes: Double = 0,
         treatsEaten: Int = 0, barksGiven: Int = 0, born: Date = Date(), lastSeen: Date = Date(),
         siteTime: [String: Double] = [:], dailyFocus: [Date: Double] = [:],
         categoryTime: [String: Double] = [:], xp: Double = 0,
         lastXPDay: Date = .distantPast, dailyAppTime: [Date: [String: Double]] = [:],
         timerEndsAt: Date? = nil, timerIsBreak: Bool = false, timerTotal: Double = 0) {
        self.name = name
        self.hunger = hunger
        self.happiness = happiness
        self.energy = energy
        self.affection = affection
        self.totalFocusMinutes = totalFocusMinutes
        self.treatsEaten = treatsEaten
        self.barksGiven = barksGiven
        self.born = born
        self.lastSeen = lastSeen
        self.siteTime = siteTime
        self.dailyFocus = dailyFocus
        self.categoryTime = categoryTime
        self.xp = xp
        self.lastXPDay = lastXPDay
        self.dailyAppTime = dailyAppTime
        self.timerEndsAt = timerEndsAt
        self.timerIsBreak = timerIsBreak
        self.timerTotal = timerTotal
    }

    // A plain `Codable` struct fails to decode its *entire* save the moment one field
    // is missing: which happens every time a new field is added, wiping everything
    // back to defaults. Decode each field on its own instead, so adding a field later
    // never costs anyone their save again.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Cariberry"
        hunger = try c.decodeIfPresent(Double.self, forKey: .hunger) ?? 0.85
        happiness = try c.decodeIfPresent(Double.self, forKey: .happiness) ?? 0.8
        energy = try c.decodeIfPresent(Double.self, forKey: .energy) ?? 0.9
        affection = try c.decodeIfPresent(Double.self, forKey: .affection) ?? 0.5
        totalFocusMinutes = try c.decodeIfPresent(Double.self, forKey: .totalFocusMinutes) ?? 0
        treatsEaten = try c.decodeIfPresent(Int.self, forKey: .treatsEaten) ?? 0
        barksGiven = try c.decodeIfPresent(Int.self, forKey: .barksGiven) ?? 0
        born = try c.decodeIfPresent(Date.self, forKey: .born) ?? Date()
        lastSeen = try c.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
        siteTime = try c.decodeIfPresent([String: Double].self, forKey: .siteTime) ?? [:]
        dailyFocus = try c.decodeIfPresent([Date: Double].self, forKey: .dailyFocus) ?? [:]
        categoryTime = try c.decodeIfPresent([String: Double].self, forKey: .categoryTime) ?? [:]
        xp = try c.decodeIfPresent(Double.self, forKey: .xp) ?? 0
        lastXPDay = try c.decodeIfPresent(Date.self, forKey: .lastXPDay) ?? .distantPast
        dailyAppTime = try c.decodeIfPresent([Date: [String: Double]].self, forKey: .dailyAppTime) ?? [:]
        timerEndsAt = try c.decodeIfPresent(Date.self, forKey: .timerEndsAt)
        timerIsBreak = try c.decodeIfPresent(Bool.self, forKey: .timerIsBreak) ?? false
        timerTotal = try c.decodeIfPresent(Double.self, forKey: .timerTotal) ?? 0
    }
}

enum Store {
    static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("DesktopPup", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static var saveURL: URL { dir.appendingPathComponent("pet.json") }

    static func load() -> PetSave {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return PetSave() }
        do {
            let data = try Data(contentsOf: saveURL)
            var s = try JSONDecoder().decode(PetSave.self, from: data)
            // The pup keeps living while the app is closed: it gets hungrier, but rests.
            let away = Date().timeIntervalSince(s.lastSeen)
            s.hunger = max(0, s.hunger - away / (60 * 60 * 6))
            s.energy = min(1, s.energy + away / (60 * 60 * 3))
            s.happiness = max(0.15, s.happiness - away / (60 * 60 * 24))

            // no need to keep more than a month of daily history around
            if let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) {
                s.dailyFocus = s.dailyFocus.filter { $0.key >= cutoff }
                s.dailyAppTime = s.dailyAppTime.filter { $0.key >= cutoff }
            }

            // a timer that would already be over by now doesn't get resumed or
            // retroactively "finished" (that would fire its celebration/break-chaining
            // the moment the app opens, using nudge timing from a session that's long
            // gone) — it just quietly wasn't running
            if let end = s.timerEndsAt, end <= Date() {
                s.timerEndsAt = nil
                s.timerIsBreak = false
                s.timerTotal = 0
            }
            return s
        } catch {
            storeLogger.error("Could not load save file: \(error.localizedDescription, privacy: .public)")
            return PetSave()
        }
    }

    static func save(_ s: PetSave) {
        var s = s
        s.lastSeen = Date()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try enc.encode(s)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            storeLogger.error("Could not save pet data: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Simple UserDefaults-backed toggles.
enum Prefs {
    private static let d = UserDefaults.standard

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) == nil ? fallback : d.bool(forKey: key)
    }

    static var focusCoaching: Bool {
        get { bool("focusCoaching", true) }
        set { d.set(newValue, forKey: "focusCoaching") }
    }
    static var browserAwareness: Bool {
        get { bool("browserAwareness", false) }
        set { d.set(newValue, forKey: "browserAwareness") }
    }
    static var sounds: Bool {
        get { bool("sounds", true) }
        set { d.set(newValue, forKey: "sounds") }
    }
    static var aboveFullscreen: Bool {
        get { bool("aboveFullscreen", false) }
        set { d.set(newValue, forKey: "aboveFullscreen") }
    }
    static var roams: Bool {
        get { bool("roams", true) }
        set { d.set(newValue, forKey: "roams") }
    }
    static var petName: String {
        get { d.string(forKey: "petName") ?? "Cariberry" }
        set { d.set(newValue, forKey: "petName") }
    }
    static var species: Species {
        get { Species(rawValue: d.string(forKey: "species") ?? "") ?? .dog }
        set { d.set(newValue.rawValue, forKey: "species") }
    }
    static var launchAtLogin: Bool {
        get { bool("launchAtLogin", false) }
        set { d.set(newValue, forKey: "launchAtLogin"); d.set(true, forKey: "launchAtLoginPreferenceSet") }
    }
    static var launchAtLoginPreferenceSet: Bool {
        d.bool(forKey: "launchAtLoginPreferenceSet")
    }

    // MARK: Quiet hours: no barking/scolding in this window, even if distracted.
    static var quietHoursEnabled: Bool {
        get { bool("quietHoursEnabled", false) }
        set { d.set(newValue, forKey: "quietHoursEnabled") }
    }
    static var quietHoursStart: Int {
        get { d.object(forKey: "quietHoursStart") == nil ? 22 : d.integer(forKey: "quietHoursStart") }
        set { d.set(min(23, max(0, newValue)), forKey: "quietHoursStart") }
    }
    static var quietHoursEnd: Int {
        get { d.object(forKey: "quietHoursEnd") == nil ? 8 : d.integer(forKey: "quietHoursEnd") }
        set { d.set(min(23, max(0, newValue)), forKey: "quietHoursEnd") }
    }
    /// Handles overnight windows (e.g. 22 -> 8) as well as same-day ones (e.g. 12 -> 13).
    static var inQuietHours: Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        let s = quietHoursStart, e = quietHoursEnd
        if s == e { return false }
        return s < e ? (hour >= s && hour < e) : (hour >= s || hour < e)
    }
}
