import SwiftUI

/// Everything drawn inside the floating window: pup, bowl, particles, speech bubble.
struct SceneView: View {
    @ObservedObject var pet: Pet

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            AnimatedDog(species: pet.species, pose: pet.pose, interval: pet.desiredFrameInterval)
                .frame(width: Design.width, height: Design.height)
                .scaleEffect(Stage.dogScale, anchor: .topLeading)
                .offset(x: Stage.dogOrigin.x, y: Stage.dogOrigin.y)

            if pet.bowl > 0 {
                FoodView(species: pet.species, fullness: pet.bowl)
                    .frame(width: Design.width, height: Design.height)
                    .scaleEffect(x: pet.facing < 0 ? -1 : 1, y: 1, anchor: .center)
                    .scaleEffect(Stage.dogScale, anchor: .topLeading)
                    .offset(x: Stage.dogOrigin.x, y: Stage.dogOrigin.y)
            }

            if !pet.particles.isEmpty {
                ParticleLayer(particles: pet.particles)
                    .frame(width: Stage.size.width, height: Stage.size.height)
                    .allowsHitTesting(false)
            }

            if let pos = pet.closeButtonAt {
                CloseButtonProp(pressed: pet.closeButtonPressed)
                    .frame(width: 24, height: 24)
                    .position(pos)
                    .transition(.scale(scale: 0.3, anchor: .center).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            bubbleZone
        }
        .frame(width: Stage.size.width, height: Stage.size.height)
        .animation(.spring(response: 0.24, dampingFraction: 0.58), value: pet.closeButtonAt)
    }

    private var bubbleZone: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if let text = pet.bubbleText {
                SpeechBubble(text: text, accent: pet.emotion.accent)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                    .id(text)
            }
        }
        .frame(width: Stage.size.width, height: max(40, Stage.head.y - 30), alignment: .bottom)
        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: pet.bubbleText)
        .allowsHitTesting(false)
    }
}

/// Drives the pup's animation clock inside SwiftUI, so a wagging tail redraws only
/// this canvas instead of invalidating the whole window every frame.
struct AnimatedDog: View {
    var species: Species
    var pose: DogPose
    var interval: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: false)) { timeline in
            var p = pose
            let _ = (p.phase = timeline.date.timeIntervalSinceReferenceDate)
            CharacterView(species: species, pose: p)
        }
    }
}

struct SpeechBubble: View {
    var text: String
    var accent: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(UI.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .frame(maxWidth: 214)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(UI.bg)
                        .shadow(color: UI.ink.opacity(0.16), radius: 7, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(0.8), lineWidth: 2.2)
                )
            Triangle()
                .fill(UI.bg)
                .overlay(Triangle().stroke(accent.opacity(0.8), lineWidth: 2.2))
                .frame(width: 16, height: 10)
                .offset(x: 6, y: -1.5)
        }
        .padding(.horizontal, 16)
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The little red "✕" she taps during Settings ▸ Auto-close Reels tabs. Purely
/// decorative — the real close happens over AppleScript — but this is what makes
/// the animation actually read as "she clicked the close button" rather than just
/// a paw waving in the air.
struct CloseButtonProp: View {
    var pressed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.45, blue: 0.42), Color(red: 0.86, green: 0.20, blue: 0.23)],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 15))
                .shadow(color: .black.opacity(0.22), radius: 2.5, y: 1.5)
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
        }
        .scaleEffect(pressed ? 0.7 : 1)
        .animation(.spring(response: 0.13, dampingFraction: 0.45), value: pressed)
    }
}

struct ParticleLayer: View {
    var particles: [Particle]

    var body: some View {
        Canvas { ctx, _ in
            for p in particles {
                let fade = min(1, p.life / max(0.001, p.maxLife) * 1.6)
                var c = ctx
                c.opacity = fade
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(p.rot))
                switch p.kind {
                case .heart:
                    c.fill(heartPath(center: .zero, size: p.size), with: .color(Fur.heart))
                    c.fill(ovalPath(-p.size * 0.16, -p.size * 0.16, p.size * 0.18, p.size * 0.14),
                           with: .color(.white.opacity(0.8)))
                case .crumb:
                    c.fill(ovalPath(0, 0, p.size, p.size * 0.85),
                           with: .color(Color(red: 0.55, green: 0.34, blue: 0.19)))
                case .anger:
                    // drawn rather than the 💢 emoji, whose hard red was the one
                    // thing on screen still shouting over the pastels
                    let r = p.size * 0.5
                    for a in stride(from: 0.0, to: .pi * 2, by: .pi / 2) {
                        var spike = Path()
                        spike.move(to: CGPoint(x: cos(a) * r * 0.35, y: sin(a) * r * 0.35))
                        spike.addLine(to: CGPoint(x: cos(a) * r, y: sin(a) * r))
                        c.stroke(spike, with: .color(Fur.alertAccent.opacity(0.85)),
                                 style: StrokeStyle(lineWidth: p.size * 0.16, lineCap: .round))
                    }
                case .zzz:
                    // a soft lilac "z" instead of the bright blue 💤
                    c.draw(Text("z")
                            .font(.system(size: p.size * 1.15, weight: .heavy, design: .rounded))
                            .foregroundStyle(UI.lilac), at: .zero)
                case .bubble:
                    c.stroke(ovalPath(0, 0, p.size, p.size), with: .color(Dish.shade.opacity(0.6)), lineWidth: 1.2)
                    c.fill(ovalPath(0, 0, p.size, p.size), with: .color(.white.opacity(0.28)))
                    c.fill(ovalPath(-p.size * 0.22, -p.size * 0.22, p.size * 0.26, p.size * 0.2),
                           with: .color(.white.opacity(0.85)))
                default:
                    c.draw(Text(glyph(p.kind)).font(.system(size: p.size)), at: .zero)
                }
            }
        }
    }

    private func glyph(_ k: Particle.Kind) -> String {
        switch k {
        case .zzz:     return "💤"
        case .sparkle: return "✨"
        case .anger:   return "💢"
        case .star:    return "⭐️"
        case .note:    return "🎵"
        case .sweat:   return "💦"
        default:       return "•"
        }
    }
}
