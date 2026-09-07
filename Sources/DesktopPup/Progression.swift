import SwiftUI

/// Levelling exists for one reason: a pet you have already seen do everything gets
/// closed after three days. XP turns "she's cute" into "she's *mine*, and she's come
/// this far": the early levels land fast enough to hook you in the first session,
/// and the curve stretches out so there's still somewhere to go months later.
enum Progression {

    // MARK: Curve

    /// XP needed to get from `level` to the next one.
    static func xpForNext(level: Int) -> Double {
        80 + Double(max(1, level) - 1) * 60
    }

    /// Total XP banked by the time you reach the start of `level`.
    static func totalXPToReach(level: Int) -> Double {
        guard level > 1 else { return 0 }
        return (1..<level).reduce(0) { $0 + xpForNext(level: $1) }
    }

    /// The level a given lifetime XP total lands you on, plus how far into it you are.
    static func resolve(totalXP: Double) -> (level: Int, into: Double, needed: Double) {
        var level = 1
        var remaining = max(0, totalXP)
        while remaining >= xpForNext(level: level) {
            remaining -= xpForNext(level: level)
            level += 1
            if level > 999 { break }
        }
        return (level, remaining, xpForNext(level: level))
    }

    // MARK: Rewards

    /// What each thing she does is worth. Focused work is deliberately the biggest
    /// steady earner: the whole point of her is to make you work, so the pet grows
    /// fastest when you actually do.
    enum Award {
        static let focusMinute = 1.0      // per minute of real focused work
        static let timerFinished = 25.0   // finishing a pomodoro
        static let fed = 5.0
        static let treat = 3.0
        static let played = 5.0
        static let petted = 1.0
        static let dailyFirstFocus = 20.0 // first focused minute of a new day
    }

    // MARK: Titles

    /// A name for where she's at, so the number means something. Species-flavoured so
    /// a level 12 cat doesn't read like a level 12 dog.
    static func title(level: Int, species: Species) -> String {
        switch level {
        case ..<3:   return species == .dog ? "Newborn Pup" : "Newborn Kitten"
        case 3..<5:  return species == .dog ? "Clumsy Puppy" : "Curious Kitten"
        case 5..<8:  return species == .dog ? "Good Dog" : "Clever Cat"
        case 8..<12: return "Best Friend"
        case 12..<17: return "Focus Buddy"
        case 17..<24: return "Study Champion"
        case 24..<32: return species == .dog ? "Legendary Hound" : "Legendary Feline"
        default:     return "Soulmate ✨"
        }
    }

    // MARK: Unlocks

    /// The collar she wears, which is the visible proof of all of the above: it shows
    /// up at level 3 and upgrades through the tiers, so progress is something you can
    /// see on her rather than a number buried in a stats window.
    static let collarLevels = [3, 8, 14, 20, 28]

    /// 0 = none yet, 1...5 = the collar tiers.
    static func collarTier(level: Int) -> Int {
        collarLevels.filter { level >= $0 }.count
    }

    static func collarColor(tier: Int) -> Color {
        switch tier {
        case 1:  return Color(red: 0.80, green: 0.52, blue: 0.34)   // leather
        case 2:  return Color(red: 0.72, green: 0.75, blue: 0.82)   // silver
        case 3:  return Color(red: 0.95, green: 0.78, blue: 0.36)   // gold
        case 4:  return Color(red: 0.62, green: 0.72, blue: 0.95)   // sapphire
        default: return Color(red: 0.86, green: 0.55, blue: 0.86)   // amethyst
        }
    }

    static func collarName(tier: Int) -> String {
        switch tier {
        case 1:  return "leather collar"
        case 2:  return "silver collar"
        case 3:  return "gold collar"
        case 4:  return "sapphire collar"
        default: return "amethyst collar"
        }
    }

    /// What she's working towards next: shown in the stats window so there's always
    /// a visible reason to keep going.
    static func nextUnlock(level: Int) -> String? {
        guard let next = collarLevels.first(where: { $0 > level }) else { return nil }
        let tier = collarLevels.firstIndex(of: next).map { $0 + 1 } ?? 1
        return "Level \(next): \(collarName(tier: tier))"
    }

    /// The line she says when she levels up.
    static func levelUpLine(level: Int, species: Species) -> String {
        let options = [
            "LEVEL \(level)!! 🎉 look how far we've come",
            "level \(level) — all because you kept showing up 💗",
            "*grows visibly more powerful* level \(level) ✨",
            "level \(level)! I'm basically unstoppable now",
        ]
        return options.randomElement() ?? "keep going!"
    }
}
