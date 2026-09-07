import AppKit
import SwiftUI

/// `DesktopPup --render-sheet /path/out.png` draws every expression to one image.
/// Handy for tweaking the art without launching the whole pet.
enum RenderSheet {
    @MainActor
    static func run(path: String) {
        let renderer = ImageRenderer(content: SheetView())
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("render failed\n".utf8))
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

extension RenderSheet {
    @MainActor
    static func runIcon(path: String) {
        let renderer = ImageRenderer(content: IconView())
        renderer.scale = 1
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

extension RenderSheet {
    @MainActor
    static func runSpeciesZoom(path: String) {
        let renderer = ImageRenderer(content: SpeciesZoomView())
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

extension RenderSheet {
    @MainActor
    static func runSpecies(path: String) {
        let renderer = ImageRenderer(content: SpeciesCheckView())
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

extension RenderSheet {
    @MainActor
    static func runStats(path: String) {
        let p = Pet()
        p.name = "Cariberry"
        p.totalFocusMinutes = 187
        p.treatsEaten = 14
        p.barksGiven = 6
        p.siteTime = ["github.com": 5200, "xcode": 4100, "youtube.com": 1800,
                      "twitter.com": 900, "notion.so": 700, "reddit.com": 320]
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sample: [Double] = [12, 48, 0, 65, 30, 90, 22]
        for (i, minutes) in sample.enumerated() {
            let day = cal.date(byAdding: .day, value: -(6 - i), to: today)!
            p.dailyFocus[day] = minutes
        }
        p.xp = 1180        // ~level 6, part-way to the next
        // real numbers pulled from an actual save file, including a rule name
        // ("Games") whose total should include Discord's app-level time
        p.categoryTime = ["Coding": 9364, "Studying & writing": 8, "Games": 3998,
                          "Social media": 158, "Reels & short-form video": 666,
                          "YouTube (might be learning, might not)": 374, "Other": 81770]
        p.dailyFocus[Calendar.current.startOfDay(for: Date())] = 42.4
        // a realistic today, including music playing in the background: the
        // comprehensive per-app picture that "Where today went" now shows, which the
        // old rule-matched-only siteTime above never could
        p.dailyAppTime[today] = ["Xcode": 4080, "Spotify": 3120, "Safari": 1860,
                                  "Slack": 900, "Finder": 240, "Mail": 180, "Notes": 90]
        let renderer = ImageRenderer(content: StatsView(pet: p, scrolls: false))
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

extension RenderSheet {
    /// Renders the full window contents (pup + bubble + particles + bowl) so the
    /// layout can be checked without a screen recording permission.
    @MainActor
    static func runScene(path: String) {
        let renderer = ImageRenderer(content: SceneCheck())
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

private struct SceneCheck: View {
    @MainActor private static func pet(_ text: String, _ mood: Emotion, particles: Particle.Kind?, bowl: Double = 0) -> Pet {
        let p = Pet()
        p.bubbleText = text
        p.moodOverride = (mood, Date().addingTimeInterval(600))
        p.bowl = bowl
        if let k = particles { p.emit(k, count: 7, at: Stage.head, spread: 40) }
        return p
    }

    var body: some View {
        HStack(spacing: 8) {
            cell(SceneCheck.pet("BARK BARK! 🐶 reels again?! eyes UP", .angry, particles: .anger))
            cell(SceneCheck.pet("you're doing amazing 💗", .love, particles: .heart))
            cell(SceneCheck.pet("OM NOM NOM 🍖", .eating, particles: .crumb, bowl: 1))
            cell(SceneCheck.pet("zzz…", .sleepy, particles: .zzz))
        }
        .padding(8)
        .background(Color(white: 0.82))
    }

    private func cell(_ p: Pet) -> some View {
        SceneView(pet: p)
            .frame(width: Stage.size.width, height: Stage.size.height)
            .background(Color(white: 0.93))
            .border(Color.red.opacity(0.35))
    }
}

private struct IconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.90, blue: 0.78),
                                              Color(red: 1.0, green: 0.74, blue: 0.47)],
                                     startPoint: .top, endPoint: .bottom))
            DogView(pose: DogPose(emotion: .happy, phase: 0.42))
                .frame(width: Design.width, height: Design.height)
                .scaleEffect(4.3)
                .offset(y: 46)
        }
        .frame(width: 1024, height: 1024)
    }
}

private struct SheetView: View {
    private let cells: [(String, DogPose)] = {
        var out: [(String, DogPose)] = []
        for e in Emotion.allCases {
            out.append((e.rawValue, DogPose(emotion: e, phase: 0.42)))
        }

        out.append(("walking", DogPose(emotion: .happy, phase: 0.30, walk: 1)))
        out.append(("walk left", DogPose(emotion: .neutral, phase: 0.9, walk: 1, facing: -1)))
        out.append(("landed", DogPose(emotion: .dizzy, phase: 0.2, squash: 0.9)))
        out.append(("carried", DogPose(emotion: .dizzy, phase: 0.5, dangling: true)))
        out.append(("stretch", DogPose(emotion: .happy, phase: 0.35, stretching: true)))
        out.append(("sniff", DogPose(emotion: .curious, phase: 0.4, sniffing: true)))
        return out
    }()

    var body: some View {
        let cols = 4
        VStack(spacing: 0) {
            Text("Cariberry expression sheet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.vertical, 12)
            ForEach(0..<((cells.count + cols - 1) / cols), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { col in
                        let i = row * cols + col
                        if i < cells.count {
                            VStack(spacing: 2) {
                                DogView(pose: cells[i].1)
                                    .frame(width: Design.width, height: Design.height)
                                Text(cells[i].0)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(6)
                            .background((row + col).isMultiple(of: 2)
                                        ? Color(white: 0.90) : Color(white: 0.95))
                        } else {
                            Color(white: 0.93).frame(width: Design.width + 12, height: Design.height + 30)
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.93))
    }
}

/// Dev-only close-up of just the ambiguous frames, blown up, to check the
/// grooming-paw geometry reads clearly.
private struct SpeciesZoomView: View {
    private struct Cell { let label: String; let species: Species; let pose: DogPose }

    private let cells: [Cell] = [
        Cell(label: "cat neutral", species: .cat, pose: DogPose(emotion: .neutral, phase: 0.4)),
        Cell(label: "cat happy", species: .cat, pose: DogPose(emotion: .happy, phase: 0.4)),
        Cell(label: "cat sit", species: .cat, pose: DogPose(emotion: .neutral, phase: 0.2, sit: true)),
        Cell(label: "dog neutral", species: .dog, pose: DogPose(emotion: .neutral, phase: 0.4)),
        Cell(label: "dog excited", species: .dog, pose: DogPose(emotion: .excited, phase: 0.4)),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<cells.count, id: \.self) { i in
                VStack(spacing: 4) {
                    CharacterView(species: cells[i].species, pose: cells[i].pose)
                        .frame(width: Design.width, height: Design.height)
                        .scaleEffect(3.6)
                        .frame(width: Design.width * 3.6, height: Design.height * 3.6)
                    Text(cells[i].label)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .padding(10)
                .background(Color(white: 0.93))
            }
        }
        .padding(16)
        .background(Color(white: 0.98))
    }
}

/// Dev-only grid: one row per species, showing idle/walk plus that species' signature
/// move at a few points through its animation, so a redesign or a new special-move
/// visual can be checked side by side without launching the whole app.
private struct SpeciesCheckView: View {
    private struct Cell { let label: String; let species: Species; let pose: DogPose }

    private let cells: [Cell] = [
        Cell(label: "dog idle", species: .dog, pose: DogPose(emotion: .happy, phase: 0.4)),
        Cell(label: "dog walk", species: .dog, pose: DogPose(emotion: .happy, phase: 0.3, walk: 1)),
        Cell(label: "dog stretch", species: .dog, pose: DogPose(emotion: .happy, phase: 0.35, stretching: true)),
        Cell(label: "dog sniff", species: .dog, pose: DogPose(emotion: .curious, phase: 0.4, sniffing: true)),

        Cell(label: "cat idle", species: .cat, pose: DogPose(emotion: .happy, phase: 0.4)),
        Cell(label: "cat walk", species: .cat, pose: DogPose(emotion: .happy, phase: 0.3, walk: 1)),
        Cell(label: "cat groom: paw up", species: .cat, pose: DogPose(emotion: .happy, phase: 0.227, sit: true, grooming: true)),
        Cell(label: "cat groom: paw down", species: .cat, pose: DogPose(emotion: .happy, phase: 0.0, sit: true, grooming: true)),
        Cell(label: "cat sit", species: .cat, pose: DogPose(emotion: .happy, phase: 0.2, sit: true)),
        Cell(label: "cat love", species: .cat, pose: DogPose(emotion: .love, phase: 0.3)),

        Cell(label: "dog collar t1", species: .dog, pose: DogPose(emotion: .happy, phase: 0.4, collarTier: 1)),
        Cell(label: "dog collar t3", species: .dog, pose: DogPose(emotion: .happy, phase: 0.4, collarTier: 3)),
        Cell(label: "dog collar t5", species: .dog, pose: DogPose(emotion: .happy, phase: 0.4, collarTier: 5)),
        Cell(label: "cat collar t2", species: .cat, pose: DogPose(emotion: .happy, phase: 0.4, collarTier: 2)),
        Cell(label: "cat collar t5", species: .cat, pose: DogPose(emotion: .happy, phase: 0.4, collarTier: 5)),
    ]

    var body: some View {
        let cols = 5
        VStack(spacing: 0) {
            Text("Cariberry species + signature-move check")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.vertical, 12)
            ForEach(0..<((cells.count + cols - 1) / cols), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { col in
                        let i = row * cols + col
                        if i < cells.count {
                            VStack(spacing: 2) {
                                CharacterView(species: cells[i].species, pose: cells[i].pose)
                                    .frame(width: Design.width, height: Design.height)
                                Text(cells[i].label)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(6)
                            .background((row + col).isMultiple(of: 2)
                                        ? Color(white: 0.90) : Color(white: 0.95))
                        } else {
                            Color(white: 0.93).frame(width: Design.width + 12, height: Design.height + 30)
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.93))
    }
}
