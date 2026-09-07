# 🐾 Cariberry: a desktop pet by Ranveer Sanghvi
A custom desktop pet application created by Ranveer Sanghvi (ranu).

A soft, minimal pet who lives at the bottom of your screen. She roams, naps and
begs for food, and she **watches what you're doing and reacts**. She barks when
you drift into Reels, and curls up and tells you she loves you when you're
coding or studying.

She earns **XP** for every minute you stay focused, levels up, and unlocks
collars she actually wears. The pet who nags you to work is also the pet who
grows because you did.

Native Swift/SwiftUI. Every pixel of her is drawn in code, with no image files,
so she's razor-sharp on Retina and the whole app is about 1 MB.

---

## Build & run

You need Xcode Command Line Tools (`xcode-select --install`). Nothing else.

```bash
./build.sh && open Cariberry.app
```

That compiles the app, draws her face into an `.icns`, assembles `Cariberry.app`
and ad-hoc signs it. She appears at the bottom of your screen and a 🐶 shows up
in your menu bar.

**To quit:** menu bar → *Quit Cariberry*, or right-click her.

**To keep her:** drag `Cariberry.app` into `/Applications`, then turn on
**Settings ▸ Launch at login**. She'll start on her own every time you log in.

---

## Choose your pet

**Settings ▸ Choose pet** lets you have a **🐶 dog** or a **🐱 cat**. It's not a
recolour: each has her own body, ears, tail, face, food, voice and signature
move. Switching keeps all your progress.

| | Dog | Cat |
|---|---|---|
| Coat | Warm oat and sand | Soft lilac and mauve |
| Ears | Big floppy ovals, pink inside | Rounded points, pink inside |
| Face | Round nose, and a tongue that lolls out when she's excited | ω muzzle, whiskers, curled tail |
| Signature move | (none yet) | Sits and washes her face with a paw |
| Food | A bowl of kibble | A saucer with a fish |
| Voice | Woofs, yips, whines, crunching | Meows, hisses, purrs |

Both share the family look: glossy two-point eyes, blush cheeks, pink toe beans,
and the collar they've earned.

---

## Levels, XP and collars

She has a lifetime XP total, and her level comes from it. The early levels land
fast enough to matter on day one; the curve stretches so there's still somewhere
to go months later.

**How she earns:**

| Action | XP |
|---|---|
| Each minute of focused work | 1 |
| First focused minute of a new day | 20 |
| Finishing a focus timer | 25 |
| A meal | 5 |
| Playing (zoomies) | 5 |
| A treat | 3 |
| Being petted | 1 |

Focused work is the biggest steady earner, so she grows fastest when you
actually work.

**Levelling** costs `80 + (level − 1) × 60` XP, so level 2 is 80 XP and the
climb lengthens as you go. Each level-up is a party: proud face, stars, hearts,
and a line from her.

**Titles** change as she grows: Newborn Pup/Kitten → Clumsy Puppy / Curious
Kitten → Good Dog / Clever Cat → Best Friend → Focus Buddy → Study Champion →
Legendary Hound / Legendary Feline → Soulmate ✨

**Collars** are the visible proof, worn on her chest, and they get their own
celebration on top of the level-up:

| Level | Collar |
|---|---|
| 3 | Leather |
| 8 | Silver |
| 14 | Gold |
| 20 | Sapphire |
| 28 | Amethyst |

At a fairly typical couple of hours of focused work a day, that's level 2 on day
one, your first collar on day two, gold around a month in, and amethyst as a
long-haul goal.

---

## Playing with her

| What you do | What she does |
|---|---|
| **Click her** | Gets petted: hearts, blush, frantic tail wagging |
| **Click and scrub back and forth** | Keeps petting; she melts |
| **Drag her** (move >46px) | Picks her up by the scruff, and she dangles and goes 😵‍💫 |
| **Let go** | Falls, lands with a squash and an "oof" |
| **Right-click her** | Full menu (same as the menu bar one) |
| **Move your cursor** | Her eyes follow it, and she turns to face you |
| **Walk away for 4 min** | She curls up and sleeps 💤, wakes when you come back |

From the **menu bar** you can Feed a meal, Give a treat, Play (zoomies), Pet
her, call *Come here!* (she sprints to your cursor), and put her down for a nap.
The menu shows her level and progress bar at the top, then her vitals (belly,
happy, energy, love) and your focus stats.

She has real needs: her belly empties over about 90 minutes of use, and a hungry
or neglected pet gets sad and droopy. She won't eat past full, so you can't
cheese XP by spamming meals. Her state is saved, so she stays hungry (and gets a
bit lonely) while the app is closed.

---

## Her emotions

18 in total, all procedurally drawn. Most happen on their own:

| Emotion | When |
|---|---|
| Curious 🤔 | Your cursor parks next to her while she's idle, and one ear cocks up |
| Shy 🙈 | Right when she arrives after you call "Come here!" |
| Proud 🥹 | The moment a focus timer finishes, before melting into love |
| Worried 😟 | Genuinely neglected: very hungry *and* very unhappy at once |
| Bored 😑 | Ignored for a long stretch while awake |
| Blissful ✨ | Everything lines up: full belly, high energy, happiness and love. Rare |

Plus happy, love, excited, sleepy, hungry, angry, sad, playful, eating, alert,
neutral and dizzy (mid-air/carried). Her greeting and idle chatter are
time-of-day aware, so you get good morning before 10am and night owl after 11pm.

---

## Random things she does on her own

- **Her signature move.** The cat sits and washes her face with a paw
- **Stretch** 🙆, a full play-bow with front legs down, tail up and a little yawn
- **Sniff around** 👃, head down, investigating something on the ground
- **Scratch**, sit, and wander the width of your screen

Turn off **Settings ▸ Roam around the screen** and she'll stay put instead of
wandering.

---

## The stats window

**Menu bar ▸ View stats** opens her scrapbook:

- **Level card**, showing level, title, XP progress bar, the collar she's wearing and
  what the next unlock is
- **Lifetime focus, current streak, treats eaten, barks given**
- **Focus quality ring**, your work-vs-distraction split for everything she's
  logged, with your top work and top distraction category
- **Last 7 days**, focused minutes per day with today highlighted
- **Where your time went**, your top sites and apps by time

---

## Focus timer

The menu has a **Timer** section: quick-start 15/25/45/60-minute focuses, or
**Custom…** for any length. While it runs she parks herself nearby instead of
wandering, her patience for distractions gets much shorter, and your countdown
shows next to her face in the menu bar (`⏱ 24:10`). Finish it and she throws a
party, banks 25 XP, then starts a 5-minute break during which she won't bark no
matter what you open.

---

## The focus coaching

Every 2 seconds she checks what app you're in and, if you allow it, what page
your front browser tab is on. She matches that against a rule list and picks one
of three verdicts:

**🚫 Distraction.** She gives you a grace period, then storms over, ears up,
and **barks**:

> *BARK! 🐶 reels again?! eyes UP*

Ignore her and she escalates: the gap shrinks from 55s → 45s → 35s → every 25s,
and after the third bark she switches to her furious lines (*"no treats for you
until you focus 🚫🦴"*). The moment you go back to work she flips to praise:
*"GOOD HUMAN 🐾 I knew you had it in you."*

**💗 Work.** She goes soft. Sits nearby, heart-eyes, and every few minutes says
something embarrassing. At 10, 25, 40 and 70 minutes of unbroken focus she
throws a party. Your streak shows next to her in the menu bar, so `😊 24m` means
she's watched you work for 24 minutes.

**😐 Neutral.** Anything unmatched. She ignores it and goes back to being a pet.

### What ships as distractions

| Rule | Grace period | Reaction |
|---|---|---|
| Reels / Shorts / TikTok / Stories | 20s | Full bark 🔊 |
| Instagram, X, Facebook, Reddit, Threads, Pinterest | 40s | Full bark |
| Netflix, Hulu, Twitch, Prime, Disney+ | 60s | Full bark |
| YouTube (might be a tutorial, so she's suspicious rather than sure) | 150s | Soft whine 🥺 |
| Steam, Epic, Riot, Minecraft, Discord | 90s | Soft whine |

### What ships as work

**Coding.** Xcode, VS Code, Cursor, JetBrains, Zed, Sublime, Terminal, iTerm,
Ghostty, Warp, Figma, Postman, Docker, Android Studio, plus github.com,
stackoverflow, developer.apple.com, leetcode, `localhost:`, docs sites.

**Studying & writing.** Preview, Acrobat, Pages, Word, Notes, Obsidian, Notion,
Scrivener, Books, GoodNotes, Numbers, Excel, Anki, plus Overleaf, Coursera, Khan
Academy, Wikipedia, Google Scholar, arXiv, Canvas, Quizlet, Google Docs.

---

## ⚠️ To actually catch Reels, turn on browser awareness

**It's off by default**, and without it she can only see *which app* you're in,
so a browser just looks like "Safari" and Reels sails right past her.

**Settings ▸ Browser awareness (Reels detection)**

macOS will ask permission for Cariberry to control your browser. Say **OK**.
She reads only the URL and title of your frontmost tab, in memory, every 2
seconds. Nothing is stored or sent anywhere. If you denied it by accident, fix
it in System Settings ▸ Privacy & Security ▸ Automation.

Works with Safari, Chrome, Arc, Brave, Edge, Vivaldi, Opera and Orion. Firefox
has no AppleScript support for tabs, so she stays app-level blind there.

---

## Quiet hours

**Settings ▸ Quiet hours** lets you pick a start and end hour (24h, e.g. 22 to 8), and
she won't bark or scold during that window, even if you're deep in a
distraction. She still notices, she just keeps it to herself.

---

## Block a site or app on the spot

**Settings ▸ Block a site or app…** takes a domain (`twitter.com`) or an app
name and she'll bark the moment she sees it, no editing JSON required. It goes
to the top of her rule list, so it beats the defaults.

---

## Writing your own rules

**Settings ▸ Edit focus rules…** opens:

```
~/Library/Application Support/DesktopPup/rules.json
```

Edit it, then **Settings ▸ Reload rules**. One rule looks like this:

```json
{
  "name": "Group chats",
  "mode": "distraction",
  "apps": ["com.apple.MobileSMS", "whatsapp"],
  "urls": ["web.whatsapp.com", "messenger.com"],
  "delay": 30,
  "severity": 2,
  "lines": [
    "BARK! 🐶 they can wait 30 minutes",
    "woof!! put the phone down"
  ]
}
```

| Field | Meaning |
|---|---|
| `mode` | `"distraction"`, `"work"` or `"neutral"` |
| `apps` | Case-insensitive substrings matched against the bundle ID **and** app name |
| `urls` | Substrings matched against the front tab's URL **and** title (needs browser awareness) |
| `delay` | Seconds of tolerance before she reacts. `0` for work rules |
| `severity` | `2` = full bark, `1` = soft whine, `0` = for work rules |
| `lines` | What she says. She cycles through them as she escalates |

**Rules are matched top to bottom and the first hit wins**, so put specific
rules above broad ones. A rule with an empty `urls` list matches on apps only,
and vice versa. If you break the JSON she quietly falls back to her defaults, and
*Reset rules to defaults* rewrites the file.

---

## Settings

| Toggle | Default | What it does |
|---|---|---|
| Focus coaching | on | Turn off and she's just a pet, no opinions |
| Browser awareness | **off** | Needed for Reels/YouTube/Netflix detection |
| Sounds | on | Her voice is synthesised live, with no audio files |
| Stay above fullscreen apps | off | Turn on so she can nag you over a fullscreen video |
| Roam around the screen | on | Turn off and she stays put |
| Launch at login | off | She starts on her own at login |
| Quiet hours | off | A window where she won't bark |
| Choose pet | dog | Dog or cat |
| Rename | | She's yours, so call her whatever you like |

---

## Where her life is stored

```
~/Library/Application Support/DesktopPup/pet.json     stats, XP, focus history
~/Library/Application Support/DesktopPup/rules.json   your rules
```

Delete `pet.json` for a fresh pet. That wipes her XP and levels too.

Save files decode leniently field by field, so adding a new stat in a future
version won't wipe an existing pet.

---

## Developing on her

```bash
swift build -c release                                   # just compile

.build/release/DesktopPup --render-sheet out.png         # every expression, as one PNG
.build/release/DesktopPup --render-species out.png       # both species + signature moves
.build/release/DesktopPup --render-species-zoom out.png  # a few poses, blown up
.build/release/DesktopPup --render-scene out.png         # bubbles, bowl, particles
.build/release/DesktopPup --render-stats out.png         # the stats window
.build/release/DesktopPup --render-icon out.png          # 1024px app icon
.build/release/DesktopPup --test-sounds                  # play every voice in turn
```

The render modes let you iterate on the artwork without launching the pet:
edit, rebuild, render, look. That loop is how all of her art was tuned.

| File | What's in it |
|---|---|
| `Theme.swift` | Design space, the `Coat` (pet) and `UI` (window) palettes, species, emotions |
| `DogView.swift` | The dog's body. Anatomy constants live in `enum A`, and `DogPose` (shared by both species) is defined here |
| `CatView.swift` | The cat's body, same structure |
| `CharacterView.swift` | Picks which species to draw |
| `FoodView.swift` | Her bowl or saucer |
| `Progression.swift` | The XP curve, awards, titles and collar unlocks |
| `Pet.swift` | Stats, moods, state machine, physics, XP, the coaching logic |
| `Rules.swift` | Rule matching and the shipped defaults |
| `ActivityMonitor.swift` | Frontmost app + AppleScript browser polling |
| `PetWindow.swift` | The transparent floating panel, hit testing, drag & pet gestures |
| `SceneView.swift` | Speech bubble, particles, composition |
| `StatsView.swift` | The stats window |
| `Sound.swift` | Voice synthesis. Every sound is generated, not sampled |
| `Store.swift` | Save file and preferences |
| `Dialogue.swift` | Everything she says |

To reshape a pet, edit the constants in her `enum A` and re-run
`--render-species`.

---

## Privacy

There is no networking code in this app — no URL sessions, no telemetry, no
server component. Nothing is ever sent anywhere. But she does keep a local
record of what she's watched, so here's exactly what that is:

**What's stored, and where:**

```
~/Library/Application Support/DesktopPup/pet.json     her stats, XP, and activity history
~/Library/Application Support/DesktopPup/rules.json   your custom focus rules
```

**What's in `pet.json`, specifically:** app names and site domains (never full
URLs or page content) and how long you spent in each, grouped by the rule
category that matched (e.g. "Coding", "Social media"); your last 7-30 days of
focused minutes per day; and lifetime totals per category and per app. None of
it is a browsing history — just durations attached to a name.

**Retention:** the day-by-day breakdown (`dailyFocus`, `dailyAppTime`) is
automatically pruned to the last 30 days. The lifetime totals (`siteTime`,
`categoryTime`) are kept indefinitely, the same way the "Lifetime focus"
number in the stats window is.

**Deleting it:** quit the app and delete `pet.json` — that wipes her stats,
XP, and levels back to zero. `rules.json` is independent of that; delete it
separately (or use **Settings ▸ Reset rules to defaults**) if you want your
custom rules gone too.

**Browser awareness** (off by default) reads the URL and title of your
frontmost browser tab via macOS's Automation permission, so it can tell a work
site from a distraction. That permission is broader than what the app actually
uses it for — macOS grants "can send this app Apple Events," not "can only
read tab titles" — so it's worth knowing it exists even though the code only
ever reads, never acts on, what it sees.
