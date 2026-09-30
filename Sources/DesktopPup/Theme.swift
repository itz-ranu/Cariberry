import SwiftUI

// fixed coordinate space the pup is drawn in, y down, facing right: the scene
// just scales this box to whatever window size it needs
enum Design {
    static let width: CGFloat = 200
    static let height: CGFloat = 168
    static let ground: CGFloat = 152     // where the paws touch
    static let centerX: CGFloat = 100
}

// no outline: `ink` is the single dark tone for every facial mark so the face reads
// as plain linework on a painted body. These marks (eyes, tongue, love-heart, mood
// accents) stay identical across species so both still read as one family; only
// the coat itself (below, in `Coat`) is species-specific.
enum Fur {
    static let ink       = Color(red: 0.38, green: 0.34, blue: 0.40)
    static let tongue    = Color(red: 1.00, green: 0.58, blue: 0.68)
    static let tongueDk  = Color(red: 0.87, green: 0.40, blue: 0.52)
    static let heart     = Color(red: 0.93, green: 0.55, blue: 0.78)
    // no physical collar anymore, but keep these for the bubble border colours
    static let alertAccent = Color(red: 0.91, green: 0.40, blue: 0.45)
    static let warnAccent  = Color(red: 0.95, green: 0.72, blue: 0.40)
    static let blushAccent = Color(red: 0.95, green: 0.74, blue: 0.76)
}

/// Window chrome: the stats panel and anything else with a surface. Same soft
/// pastel world as the pets, so the UI doesn't look like a different app bolted on.
enum UI {
    static let bg       = Color(red: 0.99, green: 0.97, blue: 0.96)   // warm cream
    static let bgLow    = Color(red: 0.97, green: 0.95, blue: 0.96)
    static let card     = Color.white.opacity(0.72)
    static let ink      = Color(red: 0.36, green: 0.32, blue: 0.38)
    static let inkSoft  = Color(red: 0.36, green: 0.32, blue: 0.38).opacity(0.52)
    static let lilac    = Color(red: 0.74, green: 0.70, blue: 0.86)   // primary accent
    static let blush    = Color(red: 0.95, green: 0.72, blue: 0.76)   // secondary accent
    static let sage     = Color(red: 0.71, green: 0.83, blue: 0.75)   // "good" signal
    static let butter   = Color(red: 0.97, green: 0.86, blue: 0.66)   // "warn" signal
    static let track    = Color(red: 0.36, green: 0.32, blue: 0.38).opacity(0.09)
}

/// The original pastel-blue palette, kept for things that aren't any one species'
/// coat: food bowls/saucers, generic particles.
enum Dish {
    static let light = Color(red: 0.95, green: 0.96, blue: 1.00)
    static let mid   = Color(red: 0.85, green: 0.89, blue: 0.99)
    static let shade = Color(red: 0.70, green: 0.77, blue: 0.95)
}

/// Soft, low-contrast pastels: the muted oat-and-lavender palette that reads as
/// "minimal kawaii" rather than a saturated cartoon. The three tones sit close
/// together on purpose: big colour jumps are what make flat art look busy.
enum Coat {
    static func light(_ s: Species) -> Color {
        switch s {
        case .dog: return Color(red: 0.97, green: 0.98, blue: 1.00)   // frosted white
        case .cat: return Color(red: 0.99, green: 0.97, blue: 0.98)   // soft blush-white
        }
    }
    static func mid(_ s: Species) -> Color {
        switch s {
        case .dog: return Color(red: 0.91, green: 0.93, blue: 0.98)   // pale periwinkle
        case .cat: return Color(red: 0.87, green: 0.83, blue: 0.90)   // dusty lilac
        }
    }
    static func shade(_ s: Species) -> Color {
        switch s {
        case .dog: return Color(red: 0.71, green: 0.77, blue: 0.93)   // soft blue-grey
        case .cat: return Color(red: 0.73, green: 0.69, blue: 0.80)   // muted mauve
        }
    }
}

enum Species: String, CaseIterable, Codable {
    case dog, cat

    var displayName: String {
        switch self {
        case .dog: return "Dog"
        case .cat: return "Cat"
        }
    }

    var emoji: String {
        switch self {
        case .dog: return "🐶"
        case .cat: return "🐱"
        }
    }
}

enum Emotion: String, CaseIterable {
    case neutral
    case happy
    case love
    case excited
    case sleepy
    case hungry
    case angry      // the "GO BACK TO WORK" face
    case sad
    case playful
    case eating
    case alert
    case dizzy      // being carried around
    case curious    // your cursor is right next to her
    case shy        // just arrived after being called over
    case proud      // just crushed a focus timer
    case worried    // genuinely neglected, worse than plain sad/hungry
    case bored      // ignored for a long stretch while awake
    case blissful   // everything is perfect at once, rare and special

    var emoji: String {
        switch self {
        case .neutral:  return "🐶"
        case .happy:    return "😊"
        case .love:     return "💗"
        case .excited:  return "🤩"
        case .sleepy:   return "😴"
        case .hungry:   return "🍖"
        case .angry:    return "😤"
        case .sad:      return "🥺"
        case .playful:  return "🎾"
        case .eating:   return "😋"
        case .alert:    return "👀"
        case .dizzy:    return "😵‍💫"
        case .curious:  return "🤔"
        case .shy:      return "🙈"
        case .proud:    return "🥹"
        case .worried:  return "😟"
        case .bored:    return "😑"
        case .blissful: return "✨"
        }
    }

    var label: String {
        switch self {
        case .neutral:  return "chilling"
        case .happy:    return "happy"
        case .love:     return "in love with you"
        case .excited:  return "SO excited"
        case .sleepy:   return "sleepy"
        case .hungry:   return "hungry"
        case .angry:    return "disappointed in you"
        case .sad:      return "a little sad"
        case .playful:  return "playful"
        case .eating:   return "eating"
        case .alert:    return "watching you"
        case .dizzy:    return "wheee"
        case .curious:  return "curious about you"
        case .shy:      return "a little shy"
        case .proud:    return "so proud"
        case .worried:  return "worried about you"
        case .bored:    return "bored"
        case .blissful: return "perfectly happy"
        }
    }

    var accent: Color {
        switch self {
        case .angry:   return Fur.alertAccent
        case .love, .proud, .blissful: return UI.blush
        case .sleepy:  return UI.lilac
        case .hungry, .worried: return UI.butter
        case .shy:     return UI.blush
        default:       return UI.lilac
        }
    }
}
