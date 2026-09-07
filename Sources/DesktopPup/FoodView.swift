import SwiftUI

/// What she's eating depends on what she is: a dog's bowl of kibble, a cat's saucer
/// of fish. Drawn in the same design space as the character so it lines up with her.
struct FoodView: View {
    var species: Species
    var fullness: Double   // 1 = fresh, 0 = finished

    var body: some View {
        switch species {
        case .dog: DogBowlView(fullness: fullness)
        case .cat: CatSaucerView(fullness: fullness)
        }
    }
}

/// A simple side-on fish silhouette for the cat's saucer.
func fishPath(cx: Double, cy: Double, w: Double, h: Double) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: cx - w * 0.5, y: cy))
    p.addQuadCurve(to: CGPoint(x: cx + w * 0.32, y: cy - h * 0.5), control: CGPoint(x: cx - w * 0.15, y: cy - h * 0.62))
    p.addQuadCurve(to: CGPoint(x: cx + w * 0.32, y: cy + h * 0.5), control: CGPoint(x: cx + w * 0.5, y: cy))
    p.addQuadCurve(to: CGPoint(x: cx - w * 0.5, y: cy), control: CGPoint(x: cx - w * 0.15, y: cy + h * 0.62))
    p.closeSubpath()
    // tail fin
    p.move(to: CGPoint(x: cx - w * 0.46, y: cy))
    p.addLine(to: CGPoint(x: cx - w * 0.72, y: cy - h * 0.34))
    p.addLine(to: CGPoint(x: cx - w * 0.72, y: cy + h * 0.34))
    p.closeSubpath()
    return p
}

/// Round kibble bits piled in a ceramic bowl: replaces the old single brown mound.
struct DogBowlView: View {
    var fullness: Double

    var body: some View {
        Canvas { ctx, _ in
            let cx = 166.0, cy = Design.ground - 4

            if fullness > 0.02 {
                let bits: [(Double, Double, Double)] = [
                    (-11, -3, 6.5), (0, -7, 7), (11, -4, 6),
                    (-6, -9, 5.5), (7, -10, 5), (-1, -12, 5),
                ]
                for (dx, dy, r) in bits.prefix(max(1, Int(fullness * Double(bits.count)))) {
                    let shade = Bool.random() ? Color(red: 0.72, green: 0.55, blue: 0.36)
                                               : Color(red: 0.82, green: 0.65, blue: 0.44)
                    ctx.fill(ovalPath(cx + dx, cy - 8 + dy * fullness, r, r * 0.82), with: .color(shade))
                }
                if fullness > 0.7 {
                    // a little bone resting on top when the bowl's freshly filled
                    var bone = Path()
                    bone.move(to: CGPoint(x: cx - 9, y: cy - 17))
                    bone.addLine(to: CGPoint(x: cx + 9, y: cy - 17))
                    ctx.stroke(bone, with: .color(Dish.light), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    for end in [cx - 9.0, cx + 9.0] {
                        ctx.fill(ovalPath(end, cy - 20, 5, 5), with: .color(Dish.light))
                        ctx.fill(ovalPath(end, cy - 14, 5, 5), with: .color(Dish.light))
                    }
                }
            }

            var bowl = Path()
            bowl.move(to: CGPoint(x: cx - 24, y: cy))
            bowl.addLine(to: CGPoint(x: cx + 24, y: cy))
            bowl.addQuadCurve(to: CGPoint(x: cx - 24, y: cy), control: CGPoint(x: cx, y: cy + 28))
            ctx.fill(bowl, with: .linearGradient(
                Gradient(colors: [Dish.mid, Dish.shade]),
                startPoint: CGPoint(x: cx - 24, y: cy), endPoint: CGPoint(x: cx + 24, y: cy + 22)))
            ctx.fill(capsulePath(cx, cy - 1, 52, 9), with: .color(Dish.light))
            ctx.fill(heartPath(center: CGPoint(x: cx, y: cy + 11), size: 11), with: .color(.white.opacity(0.85)))
        }
        .frame(width: Design.width, height: Design.height)
    }
}

/// A shallow saucer with a little fish instead of kibble: cats don't eat from a
/// deep bowl the way a dog does.
struct CatSaucerView: View {
    var fullness: Double

    var body: some View {
        Canvas { ctx, _ in
            let cx = 166.0, cy = Design.ground - 2

            var saucer = Path()
            saucer.move(to: CGPoint(x: cx - 26, y: cy))
            saucer.addLine(to: CGPoint(x: cx + 26, y: cy))
            saucer.addQuadCurve(to: CGPoint(x: cx - 26, y: cy), control: CGPoint(x: cx, y: cy + 16))
            ctx.fill(saucer, with: .linearGradient(
                Gradient(colors: [Dish.mid, Dish.shade]),
                startPoint: CGPoint(x: cx - 26, y: cy), endPoint: CGPoint(x: cx + 26, y: cy + 12)))
            ctx.fill(capsulePath(cx, cy - 1, 56, 7), with: .color(Dish.light))

            if fullness > 0.04 {
                let scale = 0.5 + 0.5 * fullness
                var f = ctx
                f.opacity = min(1, fullness * 1.6)
                f.translateBy(x: cx, y: cy - 8)
                f.scaleBy(x: scale, y: scale)
                f.fill(fishPath(cx: 0, cy: 0, w: 34, h: 16), with: .color(Color(red: 0.62, green: 0.73, blue: 0.88)))
                f.fill(ovalPath(6, -2, 3, 3), with: .color(Fur.ink.opacity(0.7)))
            }
        }
        .frame(width: Design.width, height: Design.height)
    }
}
