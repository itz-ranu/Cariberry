import SwiftUI

// MARK: - Anatomy constants (design space: 200x168, ground at 152, facing right)

private enum A {
    // same big-head-plush-toy build as the dog, but leaner through the body and
    // with a shorter, blunter muzzle: a cat's face is flatter than a dog's snout
    static let bodyC   = CGPoint(x: 80, y: 128)
    static let bodyW   = 76.0
    static let bodyH   = 54.0

    static let headC   = CGPoint(x: 122, y: 60)
    static let headR   = 52.0

    static let muzzleC = CGPoint(x: 130, y: 88)
    static let muzzleW = 40.0
    static let muzzleH = 30.0

    static let noseC   = CGPoint(x: 130, y: 74)

    // set close together and low: more forehead above the eyes reads as babyish,
    // which is the whole cuteness game
    static let eyeL    = CGPoint(x: 98, y: 58)
    static let eyeR    = CGPoint(x: 146, y: 54)

    static let earL    = CGPoint(x: 86, y: 26)     // perched on top, cat-style
    static let earR    = CGPoint(x: 152, y: 22)

    static let tailBase = CGPoint(x: 40, y: 114)

    static let hipY    = 132.0
    static let paw     = 152.0
    static let legs    = [48.0, 68.0, 92.0, 114.0]   // back-far, back-near, front-far, front-near
}

/// Static geometry, built once instead of allocated 30 times a second.
private enum Art {
    struct Leg { let limb: Path; let paw: Path }

    static let legs: [Leg] = (0..<4).map { i in
        let x = A.legs[i]
        let far = (i == 0 || i == 2)
        let top = A.hipY - 4
        let h = A.paw - top
        let pawY = far ? A.paw - 3 : A.paw
        // slim limbs, neat paws: leaner than the dog's stubby build
        return Leg(limb: capsulePath(x, top + h / 2, 16, h),
                   paw: ovalPath(x + 1, pawY - 3, far ? 18 : 20, 13))
    }

    // circles along a fixed bezier, hooking back over itself at the top: a curled
    // tip is the cat silhouette cue you read from across the screen, a straight
    // taper isn't
    static let tail: [(path: Path, color: Color)] = {
        let p0 = CGPoint(x: 0, y: 0), cp = CGPoint(x: -36, y: -16), p1 = CGPoint(x: 2, y: -50)
        let steps = 20
        var out: [(Path, Color)] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let mt = 1 - t
            let x = mt * mt * p0.x + 2 * mt * t * cp.x + t * t * p1.x
            let y = mt * mt * p0.y + 2 * mt * t * cp.y + t * t * p1.y
            let r = 8.0 - t * 3.5
            // coatShade -> coatLight (muted mauve to soft blush-white)
            let c = Color(red: 0.73 + 0.26 * t, green: 0.69 + 0.28 * t, blue: 0.80 + 0.18 * t)
            out.append((ovalPath(x, y, r * 2, r * 2), c))
        }
        return out
    }()

    static let body = ovalPath(A.bodyC.x, A.bodyC.y, A.bodyW, A.bodyH)
    static let underShadow = ovalPath(A.bodyC.x + 6, A.bodyC.y + A.bodyH * 0.32, A.bodyW * 0.7, A.bodyH * 0.36)

    static let head = ovalPath(A.headC.x, A.headC.y, A.headR * 2, A.headR * 1.9)
    // soft ambient shadow where the big head overlaps the body, and under the chin
    static let chinShadow = ovalPath(A.muzzleC.x - 6, A.bodyC.y - A.bodyH * 0.55, A.headR * 1.4, A.headR * 0.65)

    // a soft, rounded point reads as a cat ear without looking spiky next to the
    // rest of the round, plush design
    static let ear: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -15, y: 7))
        p.addQuadCurve(to: CGPoint(x: 1, y: -30), control: CGPoint(x: -12, y: -15))
        p.addQuadCurve(to: CGPoint(x: 18, y: 9), control: CGPoint(x: 14, y: -14))
        p.addQuadCurve(to: CGPoint(x: -15, y: 7), control: CGPoint(x: 1, y: 16))
        p.closeSubpath()
        return p
    }()
    // the bare pink skin inside the ear: a real two-tone ear instead of one flat shape
    static let earInner: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -7, y: 3))
        p.addQuadCurve(to: CGPoint(x: 1, y: -19), control: CGPoint(x: -5, y: -10))
        p.addQuadCurve(to: CGPoint(x: 9, y: 5), control: CGPoint(x: 6, y: -7))
        p.addQuadCurve(to: CGPoint(x: -7, y: 3), control: CGPoint(x: 1, y: 9))
        p.closeSubpath()
        return p
    }()

    // soft raised snout: a highlight, not a coloured patch
    static let muzzle = ovalPath(A.muzzleC.x, A.muzzleC.y, A.muzzleW, A.muzzleH)

    // a small triangular nose reads as cat; the dog's rounded one reads as dog
    static let nose: Path = {
        var n = Path()
        let nx = A.noseC.x, ny = A.noseC.y
        n.move(to: CGPoint(x: nx - 5, y: ny - 3))
        n.addQuadCurve(to: CGPoint(x: nx + 5, y: ny - 3), control: CGPoint(x: nx, y: ny - 6))
        n.addQuadCurve(to: CGPoint(x: nx, y: ny + 4), control: CGPoint(x: nx + 4, y: ny + 1))
        n.addQuadCurve(to: CGPoint(x: nx - 5, y: ny - 3), control: CGPoint(x: nx - 4, y: ny + 1))
        n.closeSubpath()
        return n
    }()

    // two short whiskers a side: a long scraggly set read messier than clean and cute
    static let whiskersL: [Path] = [-1.0, 6.0].map { dy in
        var p = Path()
        p.move(to: CGPoint(x: A.muzzleC.x - 13, y: A.muzzleC.y + dy))
        p.addQuadCurve(to: CGPoint(x: A.muzzleC.x - 28, y: A.muzzleC.y + dy - 3),
                       control: CGPoint(x: A.muzzleC.x - 21, y: A.muzzleC.y + dy - 1))
        return p
    }
    static let whiskersR: [Path] = [-1.0, 6.0].map { dy in
        var p = Path()
        p.move(to: CGPoint(x: A.muzzleC.x + 13, y: A.muzzleC.y + dy))
        p.addQuadCurve(to: CGPoint(x: A.muzzleC.x + 28, y: A.muzzleC.y + dy - 3),
                       control: CGPoint(x: A.muzzleC.x + 21, y: A.muzzleC.y + dy - 1))
        return p
    }
}

// MARK: - The cat

struct CatView: View {
    var pose: DogPose

    var body: some View {
        Canvas { ctx, _ in
            draw(ctx)
        }
        .frame(width: Design.width, height: Design.height)
        .blur(radius: 0.45)
    }

    // her own cool lilac-grey coat, distinct from the dog's warm golden one
    private var coatLight: Color { Coat.light(.cat) }
    private var coatMid: Color { Coat.mid(.cat) }
    private var coatShade: Color { Coat.shade(.cat) }

    private var breathe: Double { sin(pose.phase * 2.1) * 1.4 }
    private var gait: Double { pose.phase * 9.5 }

    private var bob: Double {
        let walking = abs(sin(gait)) * 3.2 * pose.walk
        let idle = breathe * 0.45
        let joy: Double
        switch pose.emotion {
        case .excited, .playful, .blissful: joy = abs(sin(pose.phase * 7)) * 4.5
        case .love, .proud:       joy = abs(sin(pose.phase * 3.4)) * 2
        case .angry:               joy = abs(sin(pose.phase * 11)) * 2.4
        default:                   joy = 0
        }
        return -(walking + joy) + idle
    }

    private var tailWag: Double {
        let speed: Double
        let amp: Double
        switch pose.emotion {
        case .love, .excited, .playful, .blissful: speed = 16; amp = 34
        case .happy, .eating, .proud:    speed = 10; amp = 22
        case .angry:                     speed = 15; amp = 12
        case .sleepy, .bored:            speed = 1.2; amp = 4
        case .sad, .worried:             speed = 1.6; amp = 3
        case .shy:                       speed = 2.4; amp = 7
        case .curious:                   speed = 5.5; amp = 11
        default:                         speed = 4.5; amp = 12
        }
        let boost = 1 + pose.petting * 0.9
        return sin(pose.phase * speed * boost) * amp * (1 + pose.petting * 0.4)
    }

    private var earPerk: Double {
        switch pose.emotion {
        case .alert, .angry, .excited, .blissful: return -28 - abs(sin(pose.phase * 6)) * 6
        case .playful, .proud:         return -16
        case .sad, .sleepy, .bored:    return 12
        case .hungry, .worried:        return -6
        case .curious:                 return -18
        case .shy:                     return 9
        default:                       return sin(pose.phase * 2.4) * 3
        }
    }

    /// Curious cocks one ear higher than the other instead of both symmetrically.
    private var earAsymmetry: Double {
        pose.emotion == .curious ? 20 : 0
    }

    private var blink: Double {
        switch pose.emotion {
        case .sleepy, .love, .happy, .eating, .angry, .sad,
             .shy, .proud, .bored, .blissful: return 0
        default: break
        }
        let cyc = pose.phase.truncatingRemainder(dividingBy: 4.4)
        if cyc < 0.13 { return sin(cyc / 0.13 * .pi) }
        if cyc > 0.30 && cyc < 0.41 { return sin((cyc - 0.30) / 0.11 * .pi) * 0.9 }
        return 0
    }

    private func draw(_ base: GraphicsContext) {
        var ctx = base

        // ground shadow (stays put while the body bounces): the only hard shadow
        let shadowSquish = 1 + bob * 0.02
        ctx.fill(ovalPath(90, Design.ground + 4, 108 * shadowSquish, 15),
                 with: .color(.black.opacity(0.13)))

        // whole-body transforms: facing, squash-and-stretch, dangle sway
        if pose.facing < 0 {
            ctx.translateBy(x: Design.centerX, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -Design.centerX, y: 0)
        }
        if pose.squash != 0 {
            let sx = 1 + pose.squash * 0.16
            let sy = 1 - pose.squash * 0.16
            ctx.translateBy(x: Design.centerX, y: Design.ground)
            ctx.scaleBy(x: sx, y: sy)
            ctx.translateBy(x: -Design.centerX, y: -Design.ground)
        }
        if pose.dangling {
            ctx.translateBy(x: Design.centerX, y: 24)
            ctx.rotate(by: .degrees(sin(pose.phase * 2.6) * 7))
            ctx.translateBy(x: -Design.centerX, y: -24)
        }
        if pose.stretching {
            ctx.translateBy(x: Design.centerX, y: Design.ground)
            ctx.rotate(by: .degrees(-8))
            ctx.translateBy(x: -Design.centerX, y: -Design.ground)
        }

        let lift = bob
        var body = ctx
        body.translateBy(x: 0, y: lift)

        drawTail(body)
        drawLegs(body, back: true)
        drawBody(body)
        drawLegs(body, back: false)
        // sits on the chest just below the chin: any higher and the big head covers
        // it completely
        drawCollar(body, tier: pose.collarTier,
                   at: CGPoint(x: A.headC.x - 16, y: A.headC.y + A.headR * 0.97 + 6), width: 48)
        drawHead(body)
        drawGroomingPaw(body)
    }

    /// A soft rim-lit curl, built from overlapping circles along a bezier.
    private func drawTail(_ ctx: GraphicsContext) {
        var c = ctx
        c.translateBy(x: A.tailBase.x, y: A.tailBase.y)
        let droop: Double
        if pose.stretching { droop = -50 }
        else if pose.emotion == .sad || pose.emotion == .sleepy { droop = 42 }
        else { droop = 0 }
        c.rotate(by: .degrees(tailWag + droop))
        for seg in Art.tail {
            c.fill(seg.path, with: .color(seg.color))
        }
    }

    private func drawLegs(_ ctx: GraphicsContext, back: Bool) {
        let idx = back ? [0, 1] : [2, 3]
        for i in idx {
            let far = (i == 0 || i == 2)
            let x = A.legs[i]
            let swingPhase = gait + (i % 2 == 0 ? 0 : .pi) + (back ? .pi : 0)
            var angle = sin(swingPhase) * 20 * pose.walk
            if pose.dangling { angle = sin(pose.phase * 3 + Double(i)) * 12 + (i < 2 ? 8 : -8) }
            if pose.sit && back { angle = i == 0 ? 62 : 56 }
            if pose.stretching && !back { angle = 58 }   // front legs bow forward and down

            var c = ctx
            if angle != 0 {
                c.translateBy(x: x, y: A.hipY - 6)
                c.rotate(by: .degrees(angle))
                c.translateBy(x: -x, y: -(A.hipY - 6))
            }
            let art = Art.legs[i]
            c.fill(art.limb, with: .color(far ? coatShade.opacity(0.9) : coatMid))
            c.fill(art.paw, with: .color(far ? coatMid : coatLight))
            // toe beans, only on the two near paws where they'd actually be visible
            if !far {
                let px = x + 1, py = A.paw - 5
                c.fill(ovalPath(px, py + 2, 7, 5.8), with: .color(Fur.blushAccent.opacity(0.5)))
                for dx in [-5.8, 0.0, 5.8] {
                    c.fill(ovalPath(px + dx, py - 3.2, 4.0, 3.6),
                           with: .color(Fur.blushAccent.opacity(0.45)))
                }
            }
        }
    }

    private func drawBody(_ ctx: GraphicsContext) {
        // radial, not linear: light falls from above like it's a soft plush toy,
        // not a flat cutout
        ctx.fill(Art.body, with: .radialGradient(
            Gradient(colors: [coatLight, coatMid]),
            center: CGPoint(x: A.bodyC.x - 8, y: A.bodyC.y - A.bodyH * 0.45),
            startRadius: 2, endRadius: A.bodyW * 1.05))
        var clipped = ctx
        clipped.clip(to: Art.body)
        clipped.fill(Art.underShadow, with: .color(coatShade.opacity(0.22)))
        clipped.fill(Art.chinShadow, with: .color(coatShade.opacity(0.14)))
    }

    private func drawHead(_ ctx: GraphicsContext) {
        var c = ctx
        // gentle head tilt with mood
        let tilt: Double
        if pose.stretching {
            tilt = 20 + sin(pose.phase * 3) * 2
        } else if pose.sniffing {
            tilt = 30 + sin(pose.phase * 5) * 4
        } else if pose.grooming {
            let cycle = (pose.phase * 2.2).truncatingRemainder(dividingBy: 1.0)
            tilt = 14 + sin(cycle * .pi) * 10
        } else {
            switch pose.emotion {
            case .love:     tilt = sin(pose.phase * 1.8) * 6 - 4
            case .alert:    tilt = -7
            case .sad, .worried: tilt = 6
            case .sleepy:   tilt = 9 + sin(pose.phase * 1.1) * 3
            case .playful:  tilt = sin(pose.phase * 5) * 7
            case .angry:    tilt = sin(pose.phase * 12) * 2.5
            case .curious:  tilt = 16 + sin(pose.phase * 1.4) * 3
            case .shy:      tilt = 10
            case .bored:    tilt = -3
            case .blissful: tilt = sin(pose.phase * 1.2) * 3
            default:        tilt = sin(pose.phase * 1.6) * 2
            }
        }
        c.translateBy(x: A.headC.x, y: A.headC.y + A.headR * 0.7)
        c.rotate(by: .degrees(tilt))
        c.translateBy(x: -A.headC.x, y: -(A.headC.y + A.headR * 0.7))
        // extra bounce for the head so it lags the body a touch
        c.translateBy(x: 0, y: sin(gait - 0.6) * 1.5 * pose.walk)
        if pose.stretching { c.translateBy(x: 4, y: 10) }
        else if pose.sniffing { c.translateBy(x: 2, y: 7) }

        drawEar(c, at: A.earL, mirrored: true)
        drawEar(c, at: A.earR, mirrored: false)

        c.fill(Art.head, with: .radialGradient(
            Gradient(colors: [coatLight, coatMid]),
            center: CGPoint(x: A.headC.x - 6, y: A.headC.y - A.headR * 0.5),
            startRadius: 2, endRadius: A.headR * 1.35))

        // the softest possible raised-snout highlight: a white patch reads as a
        // marking, and markings read busy on an otherwise plain, minimal face
        c.fill(Art.muzzle, with: .color(coatLight.opacity(0.5)))

        drawBlush(c)
        drawWhiskers(c)
        drawMuzzleMarks(c)
        drawEyes(c)
    }

    private func drawBlush(_ ctx: GraphicsContext) {
        ctx.fill(ovalPath(A.eyeL.x - 9, A.eyeL.y + 19, 17, 10), with: .color(Fur.blushAccent.opacity(0.32)))
        ctx.fill(ovalPath(A.eyeR.x + 13, A.eyeR.y + 21, 17, 10), with: .color(Fur.blushAccent.opacity(0.32)))
    }

    private func drawWhiskers(_ ctx: GraphicsContext) {
        let twitch = sin(pose.phase * 1.4) * 1.3
        for w in Art.whiskersL {
            ctx.stroke(w.applying(CGAffineTransform(translationX: 0, y: twitch)),
                       with: .color(Fur.ink.opacity(0.28)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        for w in Art.whiskersR {
            ctx.stroke(w.applying(CGAffineTransform(translationX: 0, y: -twitch)),
                       with: .color(Fur.ink.opacity(0.28)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    private func drawEar(_ ctx: GraphicsContext, at attach: CGPoint, mirrored: Bool) {
        var c = ctx
        c.translateBy(x: attach.x, y: attach.y)
        if mirrored { c.scaleBy(x: -1, y: 1) }
        let flap = sin(pose.phase * 9 + (mirrored ? 0.7 : 0)) * 4 * (pose.walk + (pose.emotion == .excited ? 1 : 0))
        // curious cocks her right ear (the "far", non-mirrored one) higher than the left
        let asym = (!mirrored ? -earAsymmetry : 0)
        c.rotate(by: .degrees(earPerk + asym + flap + (pose.dangling ? -34 : 0)))

        c.fill(Art.ear, with: .linearGradient(
            Gradient(colors: [coatMid, coatShade]),
            startPoint: .zero, endPoint: CGPoint(x: 16, y: 34)))
        c.fill(Art.earInner, with: .color(Fur.blushAccent.opacity(0.4)))
    }

    /// The classic cat "omega" muzzle: a short philtrum dropping from the nose with
    /// two soft curves sweeping out from its base. `lift` raises the curve ends for
    /// a happy mouth, lowers them for a downcast one.
    private func omegaMouth(_ ctx: GraphicsContext, lift: Double) {
        let top = A.noseC.y + 3
        let junction = top + 6

        var stem = Path()
        stem.move(to: CGPoint(x: A.noseC.x, y: top))
        stem.addLine(to: CGPoint(x: A.noseC.x, y: junction))
        ctx.stroke(stem, with: .color(Fur.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        var m = Path()
        m.move(to: CGPoint(x: A.noseC.x - 10, y: junction - lift))
        m.addQuadCurve(to: CGPoint(x: A.noseC.x, y: junction), control: CGPoint(x: A.noseC.x - 5, y: junction + 4))
        m.addQuadCurve(to: CGPoint(x: A.noseC.x + 10, y: junction - lift), control: CGPoint(x: A.noseC.x + 5, y: junction + 4))
        ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }

    private func drawMuzzleMarks(_ ctx: GraphicsContext) {
        if pose.stretching {
            // a satisfied yawn, regardless of mood
            ctx.fill(ovalPath(A.muzzleC.x, A.muzzleC.y + 4, 10, 8), with: .color(Fur.ink.opacity(0.85)))
            ctx.fill(Art.nose, with: .color(Fur.ink))
            return
        }

        switch pose.emotion {
        case .angry:
            let open = 8 + abs(sin(pose.phase * 12)) * 8
            var jaw = Path(ellipseIn: CGRect(x: A.muzzleC.x - 11, y: A.muzzleC.y - 2, width: 22, height: open))
            ctx.fill(jaw, with: .color(Fur.ink.opacity(0.85)))
            jaw = Path(ellipseIn: CGRect(x: A.muzzleC.x - 6, y: A.muzzleC.y + open * 0.3, width: 12, height: open * 0.5))
            ctx.fill(jaw, with: .color(Fur.tongue))

        case .happy, .excited, .playful, .love, .alert, .blissful, .proud:
            // tongue first so the mouth line lands on top of it
            if pose.emotion == .excited || pose.emotion == .playful || pose.emotion == .love {
                let loll = 1 + sin(pose.phase * 6) * 0.12
                ctx.fill(ovalPath(A.noseC.x, A.noseC.y + 13, 9, 9 * loll), with: .color(Fur.tongue))
            }
            omegaMouth(ctx, lift: 4)

        case .curious:
            ctx.stroke(ovalPath(A.noseC.x, A.noseC.y + 10, 6, 7), with: .color(Fur.ink),
                       style: StrokeStyle(lineWidth: 2.0))

        case .shy:
            omegaMouth(ctx, lift: 0)

        case .worried:
            omegaMouth(ctx, lift: -3)

        case .bored:
            var m = Path()
            m.move(to: CGPoint(x: A.noseC.x - 8, y: A.noseC.y + 9))
            m.addLine(to: CGPoint(x: A.noseC.x + 8, y: A.noseC.y + 9))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        case .eating, .hungry:
            let chomp = pose.emotion == .eating ? abs(sin(pose.phase * 14)) * 6 : 2
            ctx.fill(Path(ellipseIn: CGRect(x: A.muzzleC.x - 9, y: A.muzzleC.y - 1, width: 18, height: 4 + chomp)),
                     with: .color(Fur.ink.opacity(0.85)))
            ctx.fill(capsulePath(A.muzzleC.x + 4, A.muzzleC.y + 5, 9, 10), with: .color(Fur.tongue))

        case .sad:
            var m = Path()
            m.move(to: CGPoint(x: A.noseC.x - 8, y: A.noseC.y + 12))
            m.addQuadCurve(to: CGPoint(x: A.noseC.x + 8, y: A.noseC.y + 12), control: CGPoint(x: A.noseC.x, y: A.noseC.y + 5))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .sleepy:
            ctx.fill(ovalPath(A.muzzleC.x, A.muzzleC.y + 3, 9, 7), with: .color(Fur.ink.opacity(0.85)))

        default:
            omegaMouth(ctx, lift: 1)
        }

        // small simple nose, same ink as the rest of the face
        ctx.fill(Art.nose, with: .color(Fur.ink))
    }

    private func drawEyes(_ ctx: GraphicsContext) {
        let lookX = pose.look.dx * 2.5
        let lookY = pose.look.dy * 2.1
        for (i, e) in [A.eyeL, A.eyeR].enumerated() {
            let c = CGPoint(x: e.x + lookX, y: e.y + lookY)
            let far = (i == 0)
            let w = far ? 16.0 : 17.5
            let h = far ? 17.0 : 18.5
            drawEye(ctx, at: c, w: w, h: h, far: far)
        }
        drawBrows(ctx)
    }

    private func drawEye(_ ctx: GraphicsContext, at c: CGPoint, w: Double, h: Double, far: Bool) {
        switch pose.emotion {
        case .love:
            let pulse = 1 + sin(pose.phase * 6) * 0.10
            ctx.fill(heartPath(center: c, size: w * 1.3 * pulse), with: .color(Fur.heart))

        case .happy, .eating, .proud:
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.55, y: c.y + 2))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.55, y: c.y + 2), control: CGPoint(x: c.x, y: c.y - h * 0.5))
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

        case .sleepy:
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.55, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.55, y: c.y), control: CGPoint(x: c.x, y: c.y + h * 0.4))
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

        case .blissful:
            let pulse = 1 + sin(pose.phase * 5) * 0.14
            var star = Path()
            let r1 = w * 0.62 * pulse, r2 = w * 0.22 * pulse
            for i in 0..<8 {
                let ang = Double(i) * .pi / 4 - .pi / 2
                let r = i % 2 == 0 ? r1 : r2
                let pt = CGPoint(x: c.x + cos(ang) * r, y: c.y + sin(ang) * r * (h / w))
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(Fur.heart))

        case .shy:
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.5, y: c.y - 2))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.5, y: c.y - 2), control: CGPoint(x: c.x, y: c.y + h * 0.4))
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

        case .bored:
            let hh = h * 0.5
            ctx.fill(ovalPath(c.x, c.y + h * 0.14, w * 0.65, hh * 0.65), with: .color(Fur.ink))
            var lid = Path()
            lid.move(to: CGPoint(x: c.x - w * 0.5, y: c.y - h * 0.08))
            lid.addLine(to: CGPoint(x: c.x + w * 0.5, y: c.y - h * 0.08))
            ctx.stroke(lid, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .angry:
            ctx.fill(ovalPath(c.x, c.y + 2, w * 0.9, h * 0.55), with: .color(Fur.ink))

        case .dizzy:
            var p = Path()
            for t in Swift.stride(from: 0.0, through: 3.2 * .pi, by: 0.24) {
                let r = t * 1.05
                let pt = CGPoint(x: c.x + cos(t) * r, y: c.y + sin(t) * r)
                if t == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        default:
            let k = 1 - blink
            if k < 0.16 {
                var p = Path()
                p.move(to: CGPoint(x: c.x - w * 0.5, y: c.y))
                p.addLine(to: CGPoint(x: c.x + w * 0.5, y: c.y))
                ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                return
            }
            let hh = h * k
            let big = (pose.emotion == .alert || pose.emotion == .excited || pose.emotion == .curious) ? 1.1 : 1.0
            let ew = w * big, eh = hh * big
            ctx.fill(ovalPath(c.x, c.y, ew, eh), with: .color(Fur.ink))
            ctx.fill(ovalPath(c.x - ew * 0.2, c.y - eh * 0.24, ew * 0.32, eh * 0.28),
                     with: .color(.white.opacity(0.9)))
            // a second, much smaller shine low on the opposite side: one highlight
            // reads flat, two reads glossy
            ctx.fill(ovalPath(c.x + ew * 0.19, c.y + eh * 0.2, ew * 0.15, eh * 0.13),
                     with: .color(.white.opacity(0.5)))
            if pose.emotion == .sad {
                let t = (pose.phase.truncatingRemainder(dividingBy: 2.6)) / 2.6
                let ty = c.y + hh * 0.5 + t * 18
                ctx.fill(ovalPath(c.x + (far ? -5 : 6), ty, 4.5, 7),
                         with: .color(Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.85 * (1 - t))))
            }
        }
    }

    private func drawBrows(_ ctx: GraphicsContext) {
        let lookX = pose.look.dx * 1.9
        func brow(_ c: CGPoint, mirrored: Bool, angle: Double, lift: Double) {
            var g = ctx
            g.translateBy(x: c.x + lookX, y: c.y - 13 + lift)
            if mirrored { g.scaleBy(x: -1, y: 1) }
            g.rotate(by: .degrees(angle))
            var p = Path()
            p.move(to: CGPoint(x: -5, y: 0))
            p.addLine(to: CGPoint(x: 5, y: 0))
            g.stroke(p, with: .color(Fur.ink.opacity(0.8)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        switch pose.emotion {
        case .angry:
            brow(A.eyeL, mirrored: true, angle: -26, lift: 3)
            brow(A.eyeR, mirrored: false, angle: -26, lift: 3)
        case .sad, .hungry:
            brow(A.eyeL, mirrored: true, angle: 20, lift: -1)
            brow(A.eyeR, mirrored: false, angle: 20, lift: -1)
        case .worried:
            brow(A.eyeL, mirrored: true, angle: 28, lift: -3)
            brow(A.eyeR, mirrored: false, angle: 28, lift: -3)
        case .alert:
            brow(A.eyeL, mirrored: true, angle: -6, lift: -4)
            brow(A.eyeR, mirrored: false, angle: -6, lift: -4)
        case .curious:
            brow(A.eyeL, mirrored: true, angle: 4, lift: -2)
            brow(A.eyeR, mirrored: false, angle: -14, lift: -7)
        default:
            break
        }
    }

    /// Her signature move: a paw lifts and wipes across the cheek, once per cycle,
    /// drawn after the head so it reads as in front of the face, not behind it.
    private func drawGroomingPaw(_ ctx: GraphicsContext) {
        guard pose.grooming else { return }
        let cycle = (pose.phase * 2.2).truncatingRemainder(dividingBy: 1.0)
        let lift = sin(cycle * .pi)   // 0 -> 1 -> 0, one wipe per cycle

        // both endpoints stay inside the head silhouette: near the mouth at rest,
        // near the eye at the peak, so the paw always reads as touching her own
        // face instead of floating off past its edge
        let restP = CGPoint(x: A.headC.x - A.headR * 0.12, y: A.headC.y + A.headR * 0.55)
        let topP  = CGPoint(x: A.headC.x - A.headR * 0.58, y: A.headC.y - A.headR * 0.05)

        let x = restP.x + (topP.x - restP.x) * lift
        let y = restP.y + (topP.y - restP.y) * lift

        var c = ctx
        c.translateBy(x: x, y: y)
        c.rotate(by: .degrees(-25 - lift * 20))

        c.fill(capsulePath(0, 7, 11, 20), with: .linearGradient(
            Gradient(colors: [coatMid, coatShade]),
            startPoint: CGPoint(x: 0, y: -3), endPoint: CGPoint(x: 0, y: 14)))
        c.fill(ovalPath(0, -6, 13, 11), with: .color(coatLight))
    }
}
