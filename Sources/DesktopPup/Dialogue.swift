import Foundation

enum Dialogue {

    static let idleChatter = [
        "sniff sniff… 👃",
        "just vibing 🐾",
        "is that a squirrel? 👀",
        "boop me?",
        "I guarded the desk all day 🛡️",
        "your desktop smells nice",
        "I like it here 🏠",
        "*wags*",
    ]

    static let petted = [
        "aaaa yes right there 😩",
        "more. MORE. 💕",
        "you're my favourite human 💗",
        "*melts*",
        "I love you sm 🥺",
        "best. day. ever.",
    ]

    /// A dog gets excited about a bowl of kibble differently than a cat gets excited
    /// about a saucer of tuna: same enthusiasm, different food.
    static func fed(for species: Species) -> [String] {
        let common = ["you remembered! 💗", "*inhales the whole thing*"]
        switch species {
        case .dog: return common + ["OM NOM NOM 🍖", "food!! FOOD!!! 😋"]
        case .cat: return common + ["mrow! finally 🐟", "*devours the tuna*"]
        }
    }

    static func treat(for species: Species) -> [String] {
        switch species {
        case .dog: return ["a treat?! for ME? 🦴", "*crunch crunch* 😋", "I'll do a trick. later."]
        case .cat: return ["ooh, a little snack 🐟", "*sniffs it, then devours it*", "I suppose this'll do"]
        }
    }

    static func full(for species: Species) -> [String] {
        switch species {
        case .dog: return ["I'm SO full 🐶 no more, please", "*pats belly* can't fit another bite"]
        case .cat: return ["mrow, I'm stuffed 🐱", "not hungry, thanks — maybe later"]
        }
    }

    static func hungry(for species: Species) -> [String] {
        return ["my bowl is… empty 🥺", "I haven't eaten in FOREVER (20 min)",
                "feed me and I'll let you work 😤", "*stomach growls loudly*"]
    }


    static let sleepy = [
        "just a lil nap 💤",
        "zzz…",
        "wake me if snacks happen",
    ]

    static let wokeUp = [
        "YOU'RE BACK!!! 🎉",
        "*stretch* 🐕",
        "did I miss anything?",
    ]

    static let play = [
        "ZOOMIES!!! 💨",
        "catch me!! 🎾",
        "wheeeeeee",
    ]

    static let comeHere = [
        "coming!! 🐕💨",
        "on my way!",
        "did someone say ME?",
    ]

    static let picked = [
        "wheee 🫠",
        "I'm flying!!",
        "put me dooown 😵‍💫",
    ]

    static let landed = [
        "oof. 😵‍💫",
        "I meant to do that",
        "*shakes it off*",
    ]

    // Standard fallback complaints
    static let scold = [
        "BARK! 🐶 eyes back on the work",
        "hey. HEY. focus 😤",
        "woof! this isn't the plan",
    ]

    static let scoldHard = [
        "BARK BARK BARK!!! 😡 I will NOT stop",
        "I'm telling your future self 😤",
        "no treats for you until you focus 🚫🦴",
        "GRRR 🐕 close it. close it now.",
        "we said 5 more minutes… 20 minutes ago 😤",
    ]

    static let backToWork = [
        "GOOD HUMAN 🐾 I knew you had it in you",
        "yesss that's my human 💗",
        "proud of you! *tail explodes*",
        "see? that wasn't so hard 😊",
    ]

    static let working = [
        "you're doing amazing 💗",
        "I'll be right here 🐾",
        "big brain hours 🧠",
        "*stares at you lovingly*",
        "look at you go 🥹",
    ]

    static func milestone(minutes: Int) -> String {
        let options = [
            "\(minutes) minutes of focus!! I'm SO proud 💗",
            "\(minutes) min streak 🔥 you're unstoppable",
            "\(minutes) minutes! *happy tail thumping* 🐾",
            "\(minutes) min locked in 💪 marry me",
        ]
        return options.randomElement() ?? "keep going!"
    }

    static let lonely = [
        "…hello? 🥺",
        "I've been alone for a while",
        "pet me when you get a sec 💗",
    ]

    static let curious = [
        "hm? 🤔 whatcha doing",
        "ooh what's that",
        "*tilts head*",
        "wait, what are you clicking",
        "is that for me? 👀",
    ]

    static let shy = [
        "h-hi 🙈",
        "you called?? 🙈💕",
        "*hides face a little*",
        "eep, hi",
        "oh! you wanted me? 🙈",
    ]

    static let worried = [
        "are you okay? 😟",
        "I'm worried about you 🥺",
        "please eat something…",
        "I miss you 😟 come say hi",
        "*paces nervously*",
    ]

    static let bored = [
        "…anything happening? 😑",
        "*stares at the wall*",
        "I've counted the pixels twice",
        "bored bored bored",
        "entertain me 😑",
    ]

    static let blissful = [
        "life is perfect ✨",
        "this is the best day ever 💕",
        "everything is right in the world 🥹",
        "*floats with joy*",
        "I have never been happier ✨",
    ]

    static let stretch = [
        "streeeetch 🙆",
        "gotta stretch these legs",
        "*big stretch* ahh",
        "stretching is important, you should too",
    ]

    static let sniff = [
        "sniff sniff 👃 what's this",
        "*investigates something*",
        "smells interesting over here",
        "one sec, sniffing something",
    ]

    static let groom = [
        "*licks paw, wipes ear*",
        "gotta stay fabulous 🐾",
        "one moment, self-care time",
        "*grooming intensifies*",
    ]

    static let morningGreeting = [
        "good morning!! ☀️",
        "morning! let's get stuff done 🌅",
        "rise and shine 🐾",
        "morning! I slept great, how about you?",
    ]

    static let nightOwl = [
        "night owl mode 🌙",
        "burning the midnight oil huh",
        "it's late… I'm proud you're still going 🌙💪",
        "shh, the world's asleep but we're not 🌙",
    ]

    /// Casual dialogue, slightly influenced by the current hour.
    static func timeFlavoredChatter() -> [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 23, 0...4: return idleChatter + nightOwl
        case 5...9:      return idleChatter + morningGreeting
        default:         return idleChatter
        }
    }
}
