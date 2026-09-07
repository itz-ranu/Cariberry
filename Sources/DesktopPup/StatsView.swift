import SwiftUI

struct StatsView: View {
    @ObservedObject var pet: Pet
    /// ImageRenderer can't capture a ScrollView's contents, so the render helper asks
    /// for the same layout laid out at full height instead.
    var scrolls: Bool = true
    @State private var browserAwareness = Prefs.browserAwareness

    /// Every app she's watched you in today, distraction or work or neither: the
    /// comprehensive, same-day picture `siteTime` never gave (see the comment on
    /// `Pet.dailyAppTime`). This is the whole point of the window now.
    private var todayAppTime: [String: Double] {
        pet.dailyAppTime[Calendar.current.startOfDay(for: Date())] ?? [:]
    }

    private var topSitesToday: [(String, Double)] {
        todayAppTime.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
    }

    private var maxTimeToday: Double { topSitesToday.first?.1 ?? 1 }

    private var trackedToday: Double { todayAppTime.values.reduce(0, +) }

    private var focusedToday: Double {
        (pet.dailyFocus[Calendar.current.startOfDay(for: Date())] ?? 0) * 60
    }

    /// Oldest to newest, always exactly 7 entries, today last.
    private var last7Days: [(label: String, minutes: Double, isToday: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let symbols = cal.shortWeekdaySymbols
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let isToday = offset == 0
            let weekday = cal.component(.weekday, from: day)
            return (isToday ? "Today" : symbols[weekday - 1], pet.dailyFocus[day] ?? 0, isToday)
        }
    }

    /// Every category she's ever logged time under, newest rules included, tagged with
    /// whether it counted as work or distraction so the ring below can score the split.
    /// Time logged under a rule name that no longer exists (renamed, deleted, or a
    /// rules reset) folds into "Other" instead of sitting invisible under its old
    /// name: see the note on why in the git history / above this file.
    private var categoryBreakdown: [(name: String, seconds: Double, kind: ActivityKind)] {
        let kinds = Dictionary(uniqueKeysWithValues: RuleStore.shared.book.rules.map { ($0.name, $0.kind) })
        var totals: [String: Double] = [:]
        for (name, seconds) in pet.categoryTime {
            let bucket = kinds[name] != nil ? name : "Other"
            totals[bucket, default: 0] += seconds
        }
        return totals.map { (name: $0.key, seconds: $0.value, kind: kinds[$0.key] ?? .neutral) }
    }

    /// A couple of shipped rule names are internal jokes or too long for a small UI
    /// pill. This only relabels what's shown, the underlying category key (and its
    /// accumulated time) is untouched.
    private func displayName(_ raw: String) -> String {
        switch raw {
        case "YouTube (might be learning, might not)": return "YouTube"
        default: return raw
        }
    }

    /// -1 means not enough signal yet to say anything meaningful.
    private var focusRatio: Double {
        let work = categoryBreakdown.filter { $0.kind == .work }.reduce(0) { $0 + $1.seconds }
        let distraction = categoryBreakdown.filter { $0.kind == .distraction }.reduce(0) { $0 + $1.seconds }
        let total = work + distraction
        return total > 0 ? work / total : -1
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [UI.bg, UI.bgLow],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // scrolls rather than clipping: the card layout is taller than the old
            // loose stack, and this way it survives a shorter window or more sections
            if scrolls {
                ScrollView(.vertical, showsIndicators: false) { stack }
            } else {
                stack
            }
        }
        .frame(width: 340, height: scrolls ? 780 : 1020)
    }

    private var stack: some View {
        VStack(spacing: 14) {
            header
            levelCard
            statTiles
            card { focusRing }
            card { dailyHistory }
            card { siteList }
        }
        .padding(.top, 20)
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }

    /// One surface style for every section: before this the level card and tiles had
    /// backgrounds while the ring, chart and site list floated loose on the gradient.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(UI.card)
                    .shadow(color: UI.ink.opacity(0.05), radius: 8, y: 2)
            )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(UI.inkSoft)
            .textCase(.uppercase)
            .kerning(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A section title plus a small, honest scope label, so a lifetime total never
    /// gets mistaken for today's, or vice versa.
    private func sectionHeader(_ text: String, scope: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(UI.inkSoft)
                .textCase(.uppercase)
                .kerning(0.6)
            Spacer()
            Text(scope)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(UI.inkSoft.opacity(0.7))
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [UI.blush.opacity(0.35), UI.lilac.opacity(0.30)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 92, height: 92)
                CharacterView(species: pet.species, pose: DogPose(emotion: .proud, phase: 0.42))
                    .frame(width: Design.width, height: Design.height)
                    .scaleEffect(0.46)
                    .frame(width: 92, height: 78)
            }

            Text(pet.name)
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(UI.ink)

            Text("day \(pet.ageDays) · together since \(pet.born.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(UI.inkSoft)
        }
    }

    /// The progression card: level, title, the bar to the next level, and what's
    /// waiting at the next unlock. This is the whole reason to keep her around past
    /// the first few days, so it sits directly under her name rather than buried.
    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Level \(pet.level)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(UI.ink)
                Text(pet.levelTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(UI.lilac)
                Spacer()
                if pet.collarTier > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Progression.collarColor(tier: pet.collarTier))
                            .frame(width: 9, height: 9)
                        Text(Progression.collarName(tier: pet.collarTier))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(UI.inkSoft)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(UI.track)
                    Capsule()
                        .fill(LinearGradient(colors: [UI.lilac, UI.blush],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * pet.levelProgress))
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(Int(pet.xpIntoLevel)) / \(Int(pet.xpForThisLevel)) XP")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(UI.inkSoft)
                Spacer()
                if let next = Progression.nextUnlock(level: pet.level) {
                    Text("next: \(next)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(UI.inkSoft)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [UI.blush.opacity(0.22), UI.lilac.opacity(0.20)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: UI.ink.opacity(0.05), radius: 8, y: 2)
        )
    }

    private var statTiles: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 8) {
            tile("Focused today", formatDuration(focusedToday), UI.sage)
            tile("Current streak", formatDuration(pet.focusSeconds), UI.lilac)
            tile("Lifetime focus", formatDuration(pet.totalFocusMinutes * 60), UI.blush)
            tile("Treats eaten", "\(pet.treatsEaten)", UI.butter)
            tile("Barks given", "\(pet.barksGiven)", Fur.alertAccent)
        }
    }

    private func tile(_ label: String, _ value: String, _ accent: Color) -> some View {
        HStack(spacing: 9) {
            Capsule().fill(accent).frame(width: 4, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(UI.ink)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(UI.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UI.card)
                .shadow(color: UI.ink.opacity(0.04), radius: 5, y: 1)
        )
    }

    /// A soft ring for the split between recognized work and recognized distraction,
    /// with the two biggest categories underneath as tiny quiet pills.
    ///
    /// This is deliberately NOT called "Focus quality": the denominator only counts
    /// time a rule actually classified as work or distraction. An unrecognized
    /// productive app (or just idle/neutral time) is invisible to this number, so it
    /// can't honestly claim to measure the whole day, only the apps she has rules for.
    private var focusRing: some View {
        VStack(spacing: 12) {
            sectionHeader("Work vs. distraction", scope: "all time")
            Text("of the apps she has rules for, not your whole day")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(UI.inkSoft.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            let ratio = focusRatio
            ZStack {
                Circle().stroke(UI.track, lineWidth: 12)
                if ratio >= 0 {
                    Circle()
                        .trim(from: 0, to: max(0.03, ratio))
                        .stroke(AngularGradient(colors: [UI.lilac, UI.blush, UI.sage, UI.lilac],
                                                center: .center),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(ratio * 100))%")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(UI.ink)
                        Text(moodWord(ratio))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(UI.inkSoft)
                    }
                } else {
                    Text("🐾").font(.system(size: 26))
                }
            }
            .frame(width: 100, height: 100)

            if ratio >= 0 {
                topCategoryPills
            } else {
                Text("not enough data yet, get to work 💪")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(UI.inkSoft.opacity(0.8))
            }
        }
    }

    private var topCategoryPills: some View {
        let topWork = categoryBreakdown.filter { $0.kind == .work }.max { $0.seconds < $1.seconds }
        let topDistraction = categoryBreakdown.filter { $0.kind == .distraction }.max { $0.seconds < $1.seconds }
        return HStack(spacing: 8) {
            if let w = topWork { categoryPill(displayName(w.name), w.seconds, UI.sage) }
            if let d = topDistraction { categoryPill(displayName(d.name), d.seconds, UI.blush) }
        }
    }

    private func categoryPill(_ name: String, _ seconds: Double, _ dot: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(UI.ink)
                .lineLimit(1)
            Text(formatDuration(seconds))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(UI.inkSoft)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(UI.bg))
    }

    private func moodWord(_ ratio: Double) -> String {
        switch ratio {
        case 0.8...:    return "excellent"
        case 0.6..<0.8: return "good"
        case 0.4..<0.6: return "mixed"
        default:        return "rough day"
        }
    }

    private var dailyHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Last 7 days")

            let days = last7Days
            let maxMinutes = max(days.map(\.minutes).max() ?? 0, 1)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.label) { day in
                    VStack(spacing: 4) {
                        Text(day.minutes >= 1 ? "\(Int(day.minutes))m" : "")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(UI.inkSoft)
                            .frame(height: 11)
                        ZStack(alignment: .bottom) {
                            Capsule().fill(UI.track).frame(width: 16)
                            Capsule()
                                .fill(day.isToday
                                      ? LinearGradient(colors: [UI.blush, UI.lilac],
                                                       startPoint: .top, endPoint: .bottom)
                                      : LinearGradient(colors: [UI.lilac.opacity(0.75), UI.lilac.opacity(0.5)],
                                                       startPoint: .top, endPoint: .bottom))
                                .frame(width: 16, height: max(6, 66 * (day.minutes / maxMinutes)))
                        }
                        .frame(height: 66)
                        Text(day.label)
                            .font(.system(size: 10, weight: day.isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(day.isToday ? UI.ink : UI.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Every app, every kind, today: the comprehensive "what did I actually do"
    /// picture. Distinct from `focusRing`/`topCategoryPills` above, which only ever
    /// scored the apps a rule recognised as work or distraction, all-time.
    private var siteList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Where today went", scope: "today")

            if !browserAwareness {
                browserAwarenessHint
            }

            if topSitesToday.isEmpty {
                Text("no data yet, I'm still watching 👀")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(UI.inkSoft.opacity(0.8))
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity)
            } else {
                Text("\(formatDuration(trackedToday)) tracked across \(todayAppTime.count) app\(todayAppTime.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(UI.inkSoft)
                VStack(spacing: 12) {
                    ForEach(topSitesToday, id: \.0) { site, seconds in
                        siteRow(site, seconds)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var browserAwarenessHint: some View {
        HStack(spacing: 8) {
            Text("🔒 browser awareness is off, so sites show up as just \"Safari\" or \"Chrome\", not the actual page")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(UI.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Turn on") {
                Prefs.browserAwareness = true
                browserAwareness = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Fur.heart)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Fur.warnAccent.opacity(0.12)))
    }

    private func siteRow(_ site: String, _ seconds: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(site)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(UI.ink)
                    .lineLimit(1)
                Spacer()
                Text(formatDuration(seconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(UI.inkSoft)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(UI.track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [UI.lilac, UI.blush],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, seconds / maxTimeToday))
                    }
            }
            .frame(height: 8)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }
}
