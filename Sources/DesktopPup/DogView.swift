import SwiftUI

// MARK: - Pose

/// Everything that can be animated about the pup for a single frame.
struct DogPose {
    var emotion: Emotion = .neutral
    var phase: Double = 0          // seconds of animation time
    var walk: Double = 0           // 0 = standing, 1 = full stride
    var facing: Double = 1         // 1 = right, -1 = left
    var squash: Double = 0         // -1 stretched .. 0 normal .. 1 squashed
    var dangling: Bool = false     // held by the scruff (dragged)
    var look: CGVector = .zero     // -1..1 eye direction
    var sit: Bool = false
    var petting: Double = 0        // 0..1 how hard it is being scritched
    var stretching: Bool = false   // play-bow stretch
    var sniffing: Bool = false     // nose to the ground
    var grooming: Bool = false     // cat's signature: paw-lick and ear wipe
    var collarTier: Int = 0        // 0 = none, 1...5 = earned collar tiers
    var tapping: Bool = false      // reaching out to tap the Reels close button
    var tapPhase: Double = 0       // 0 = at rest, mid = fully reached and pressing, 1 = retracted
}

/// Shapes the one-shot reach-and-press arc of `tapping`: eases up to a held peak
/// (the moment the paw is actually on the button), then eases back down. Shared by
/// both species so the gesture reads the same regardless of who's doing it.
func tapRaise(_ phase: Double) -> Double {
    if phase < 0.4 { let t = phase / 0.4; return 1 - (1 - t) * (1 - t) }
    if phase < 0.6 { return 1 }
    let t = (phase - 0.6) / 0.4
    return max(0, 1 - t * t)
}

/// The collar she earns by levelling up: a band across the chest with a little tag
/// hanging off it. Shared by both species so an upgrade looks the same on either.
func drawCollar(_ ctx: GraphicsContext, tier: Int, at c: CGPoint, width: Double) {
    guard tier > 0 else { return }
    let colour = Progression.collarColor(tier: tier)

    var band = Path()
    band.move(to: CGPoint(x: c.x - width / 2, y: c.y - 3))
    band.addQuadCurve(to: CGPoint(x: c.x + width / 2, y: c.y - 5),
                      control: CGPoint(x: c.x, y: c.y + 7))
    ctx.stroke(band, with: .linearGradient(
        Gradient(colors: [colour.opacity(0.75), colour]),
        startPoint: CGPoint(x: c.x - width / 2, y: c.y),
        endPoint: CGPoint(x: c.x + width / 2, y: c.y)),
        style: StrokeStyle(lineWidth: 7, lineCap: .round))

    // the tag, with a highlight so it reads as metal rather than a flat dot
    let tagC = CGPoint(x: c.x + 2, y: c.y + 9)
    ctx.fill(ovalPath(tagC.x, tagC.y, 11, 11), with: .color(colour))
    ctx.fill(ovalPath(tagC.x - 2, tagC.y - 2, 4.5, 4), with: .color(.white.opacity(0.65)))
}

// MARK: - Small path helpers

@inline(__always) func ovalPath(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double) -> Path {
    Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
}

@inline(__always) func capsulePath(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double) -> Path {
    Path(roundedRect: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), cornerRadius: min(w, h) / 2)
}

func heartPath(center: CGPoint, size: Double) -> Path {
    var p = Path()
    let s = size / 2
    let x = center.x, y = center.y
    p.move(to: CGPoint(x: x, y: y + s * 0.95))
    p.addCurve(to: CGPoint(x: x - s, y: y - s * 0.25),
               control1: CGPoint(x: x - s * 0.55, y: y + s * 0.45),
               control2: CGPoint(x: x - s, y: y + s * 0.25))
    p.addArc(center: CGPoint(x: x - s * 0.5, y: y - s * 0.3), radius: s * 0.52,
             startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    p.addArc(center: CGPoint(x: x + s * 0.5, y: y - s * 0.3), radius: s * 0.52,
             startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    p.addCurve(to: CGPoint(x: x, y: y + s * 0.95),
               control1: CGPoint(x: x + s, y: y + s * 0.25),
               control2: CGPoint(x: x + s * 0.55, y: y + s * 0.45))
    p.closeSubpath()
    return p
}

// MARK: - Anatomy constants (design space, y grows down, pup faces right)

private enum A {
    // chunkier, rounder proportions: big head, short stubby legs, plush-toy build
    static let bodyC   = CGPoint(x: 82, y: 124)
    static let bodyW   = 82.0
    static let bodyH   = 62.0

    static let headC   = CGPoint(x: 120, y: 62)
    static let headR   = 54.0

    static let muzzleC = CGPoint(x: 134, y: 92)
    static let muzzleW = 56.0
    static let muzzleH = 40.0

    static let noseC   = CGPoint(x: 134, y: 76)

    static let eyeL    = CGPoint(x: 94, y: 60)
    static let eyeR    = CGPoint(x: 150, y: 56)

    static let earL    = CGPoint(x: 76, y: 38)     // attach points
    static let earR    = CGPoint(x: 162, y: 34)

    static let tailBase = CGPoint(x: 44, y: 110)

    static let hipY    = 130.0
    static let paw     = 152.0
    static let legs    = [52.0, 72.0, 96.0, 118.0]   // back-far, back-near, front-far, front-near
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
        // stubby limbs, big round paws: barely more than feet peeking from the belly
        return Leg(limb: capsulePath(x, top + h / 2, 19, h),
                   paw: ovalPath(x + 1, pawY - 3, far ? 21 : 24, 15))
    }

    // circles along a fixed bezier, pre-tinted so the curl reads as one rim-lit shape.
    // bigger radius throughout than before for a fluffier, more voluminous curl
    static let tail: [(path: Path, color: Color)] = {
        let p0 = CGPoint(x: 0, y: 0), cp = CGPoint(x: -36, y: -6), p1 = CGPoint(x: -18, y: -50)
        let steps = 20
        var out: [(Path, Color)] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let mt = 1 - t
            let x = mt * mt * p0.x + 2 * mt * t * cp.x + t * t * p1.x
            let y = mt * mt * p0.y + 2 * mt * t * cp.y + t * t * p1.y
            let r = 13.0 - t * 6.0
            // coatShade -> coatLight (soft caramel to oat milk), interpolated once at launch
            let c = Color(red: 0.89 + 0.10 * t, green: 0.77 + 0.19 * t, blue: 0.62 + 0.29 * t)
            out.append((ovalPath(x, y, r * 2, r * 2), c))
        }
        return out
    }()

    static let body = ovalPath(A.bodyC.x, A.bodyC.y, A.bodyW, A.bodyH)
    static let underShadow = ovalPath(A.bodyC.x + 6, A.bodyC.y + A.bodyH * 0.32, A.bodyW * 0.7, A.bodyH * 0.36)

    static let head = ovalPath(A.headC.x, A.headC.y, A.headR * 2, A.headR * 1.94)
    // soft ambient shadow where the big head overlaps the body, and under the chin
    static let chinShadow = ovalPath(A.muzzleC.x - 6, A.bodyC.y - A.bodyH * 0.55, A.headR * 1.5, A.headR * 0.7)

    // a plain rounded oval reads as a soft floppy ear far better than any hand-tuned
    // pointed curve: this is what actually gets it close to a plush toy's ears
    static let ear = ovalPath(10, 24, 38, 56)
    static let earShade = ovalPath(11, 27, 22, 38)
    // the exposed inner ear, a shade lighter and warmer than the shadow around it.
    // a real two-tone floppy ear instead of one flat colour
    static let earInner = ovalPath(13, 32, 15, 27)

    // raised snout bump, just a highlight fill, not a coloured patch
    static let muzzle = ovalPath(A.muzzleC.x, A.muzzleC.y, A.muzzleW, A.muzzleH)

    static let nose: Path = {
        var n = Path()
        let nx = A.noseC.x, ny = A.noseC.y
        n.move(to: CGPoint(x: nx - 8, y: ny - 4))
        n.addQuadCurve(to: CGPoint(x: nx + 8, y: ny - 4), control: CGPoint(x: nx, y: ny - 8))
        n.addQuadCurve(to: CGPoint(x: nx, y: ny + 6), control: CGPoint(x: nx + 8, y: ny + 4))
        n.addQuadCurve(to: CGPoint(x: nx - 8, y: ny - 4), control: CGPoint(x: nx - 8, y: ny + 4))
        n.closeSubpath()
        return n
    }()
}

// MARK: - The pup

struct DogView: View {
    var pose: DogPose

    var body: some View {
        Canvas { ctx, _ in
            draw(ctx)
        }
        .frame(width: Design.width, height: Design.height)
        .blur(radius: 0.45)
    }

    // her own warm golden-puppy coat, distinct from the other three species
    private var coatLight: Color { Coat.light(.dog) }
    private var coatMid: Color { Coat.mid(.dog) }
    private var coatShade: Color { Coat.shade(.dog) }

    private var breathe: Double { sin(pose.phase * 2.1) * 1.6 }

    private var gait: Double { pose.phase * 9.0 }

    private var bob: Double {
        let walking = abs(sin(gait)) * 3.4 * pose.walk
        let idle = breathe * 0.5
        let joy: Double
        switch pose.emotion {
        case .excited, .playful, .blissful: joy = abs(sin(pose.phase * 7)) * 5
        case .love, .proud:       joy = abs(sin(pose.phase * 3.4)) * 2.2
        case .angry:               joy = abs(sin(pose.phase * 11)) * 2.6
        default:                   joy = 0
        }
        return -(walking + joy) + idle
    }

    private var tailWag: Double {
        let speed: Double
        let amp: Double
        switch pose.emotion {
        case .love, .excited, .playful, .blissful: speed = 15; amp = 38
        case .happy, .eating, .proud:    speed = 9;  amp = 26
        case .angry:                     speed = 13; amp = 16
        case .sleepy, .bored:            speed = 1.2; amp = 5
        case .sad, .worried:             speed = 1.6; amp = 4
        case .shy:                       speed = 2.4; amp = 8
        case .curious:                   speed = 5;  amp = 12
        default:                         speed = 4;  amp = 14
        }
        let boost = 1 + pose.petting * 0.9
        return sin(pose.phase * speed * boost) * amp * (1 + pose.petting * 0.4)
    }

    private var earPerk: Double {
        switch pose.emotion {
        case .alert, .angry, .excited, .blissful: return -30 - abs(sin(pose.phase * 6)) * 6
        case .playful, .proud:         return -18
        case .sad, .sleepy, .bored:    return 14
        case .hungry, .worried:        return -8
        case .curious:                 return -16
        case .shy:                     return 10
        default:                       return sin(pose.phase * 2.4) * 3
        }
    }

    /// Curious cocks one ear higher than the other instead of both symmetrically.
    private var earAsymmetry: Double {
        pose.emotion == .curious ? 22 : 0
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
        ctx.fill(ovalPath(94, Design.ground + 4, 112 * shadowSquish, 15),
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
        if pose.tapping {
            let raise = tapRaise(pose.tapPhase)
            ctx.translateBy(x: Design.centerX, y: Design.ground)
            ctx.rotate(by: .degrees(-9 * raise))
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
        // it completely, which is what made the first attempt invisible
        drawCollar(body, tier: pose.collarTier,
                   at: CGPoint(x: A.headC.x - 18, y: A.headC.y + A.headR * 0.97 + 8), width: 54)
        drawHead(body)
    }

    /// A soft rim-lit curl, built from overlapping circles along a bezier.
    private func drawTail(_ ctx: GraphicsContext) {
        var c = ctx
        c.translateBy(x: A.tailBase.x, y: A.tailBase.y)
        let droop: Double
        if pose.stretching { droop = -55 }
        else if pose.emotion == .sad || pose.emotion == .sleepy { droop = 46 }
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
            if pose.tapping && !back {
                // the near paw reaches up and forward to poke the button; the far
                // paw braces down a little so the weight shift still reads
                let raise = tapRaise(pose.tapPhase)
                angle = i == 3 ? -95 * raise : 10 * raise
            }

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
                c.fill(ovalPath(px, py + 2, 8, 6.5), with: .color(Fur.blushAccent.opacity(0.5)))
                for dx in [-6.5, 0.0, 6.5] {
                    c.fill(ovalPath(px + dx, py - 3.5, 4.6, 4.0),
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
        } else if pose.tapping {
            tilt = -16 * tapRaise(pose.tapPhase)   // leans into the reach, determined
        } else if pose.sniffing {
            tilt = 30 + sin(pose.phase * 5) * 4
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
        else if pose.tapping { c.translateBy(x: 6 * tapRaise(pose.tapPhase), y: 0) }
        else if pose.sniffing { c.translateBy(x: 2, y: 7) }

        drawEar(c, at: A.earL, mirrored: true)
        drawEar(c, at: A.earR, mirrored: false)

        c.fill(Art.head, with: .radialGradient(
            Gradient(colors: [coatLight, coatMid]),
            center: CGPoint(x: A.headC.x - 6, y: A.headC.y - A.headR * 0.5),
            startRadius: 2, endRadius: A.headR * 1.35))

        // the softest possible raised-snout highlight: a white patch reads as a
        // marking, and markings are what we're stripping out
        c.fill(Art.muzzle, with: .color(coatLight.opacity(0.5)))

        drawBlush(c)
        drawMuzzleMarks(c)
        drawEyes(c)
    }

    private func drawBlush(_ ctx: GraphicsContext) {
        ctx.fill(ovalPath(A.eyeL.x - 10, A.eyeL.y + 20, 18, 11), with: .color(Fur.blushAccent.opacity(0.32)))
        ctx.fill(ovalPath(A.eyeR.x + 14, A.eyeR.y + 22, 18, 11), with: .color(Fur.blushAccent.opacity(0.32)))
    }

    private func drawEar(_ ctx: GraphicsContext, at attach: CGPoint, mirrored: Bool) {
        var c = ctx
        c.translateBy(x: attach.x, y: attach.y)
        if mirrored { c.scaleBy(x: -1, y: 1) }
        let flap = sin(pose.phase * 9 + (mirrored ? 0.7 : 0)) * 5 * (pose.walk + (pose.emotion == .excited ? 1 : 0))
        // curious cocks her right ear (the "far", non-mirrored one) higher than the left
        let asym = (!mirrored ? -earAsymmetry : 0)
        c.rotate(by: .degrees(earPerk + asym + flap + (pose.dangling ? -40 : 0)))

        c.fill(Art.ear, with: .linearGradient(
            Gradient(colors: [coatMid, coatShade]),
            startPoint: .zero, endPoint: CGPoint(x: 20, y: 44)))
        c.fill(Art.earShade, with: .color(coatShade.opacity(0.28)))
        c.fill(Art.earInner, with: .color(Fur.blushAccent.opacity(0.3)))
    }

    private func drawMuzzleMarks(_ ctx: GraphicsContext) {
        let mouthY = A.muzzleC.y + 2

        if pose.stretching {
            // a satisfied yawn, regardless of mood
            ctx.fill(ovalPath(A.muzzleC.x, mouthY + 2, 11, 9), with: .color(Fur.ink.opacity(0.85)))
            ctx.fill(Art.nose, with: .color(Fur.ink))
            return
        }

        switch pose.emotion {
        case .angry:
            let open = 9 + abs(sin(pose.phase * 12)) * 10
            var jaw = Path(ellipseIn: CGRect(x: A.muzzleC.x - 13, y: mouthY - 4, width: 26, height: open))
            ctx.fill(jaw, with: .color(Fur.ink.opacity(0.85)))
            jaw = Path(ellipseIn: CGRect(x: A.muzzleC.x - 7, y: mouthY + open * 0.3, width: 14, height: open * 0.5))
            ctx.fill(jaw, with: .color(Fur.tongue))

        case .happy, .excited, .playful, .love, .alert, .blissful, .proud:
            // tongue first so the mouth line lands on top of it and reads as the lip
            if pose.emotion == .excited || pose.emotion == .playful || pose.emotion == .love {
                let loll = 1 + sin(pose.phase * 6) * 0.12
                ctx.fill(ovalPath(A.muzzleC.x + 1, mouthY + 9, 13, 12 * loll),
                         with: .color(Fur.tongue))
                ctx.fill(ovalPath(A.muzzleC.x + 1, mouthY + 12, 5, 6 * loll),
                         with: .color(Fur.tongueDk.opacity(0.45)))
            }
            var m = Path()
            m.move(to: CGPoint(x: A.muzzleC.x - 11, y: mouthY - 1))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x, y: mouthY + 8), control: CGPoint(x: A.muzzleC.x - 6, y: mouthY + 8))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x + 11, y: mouthY - 1), control: CGPoint(x: A.muzzleC.x + 6, y: mouthY + 8))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

        case .curious:
            ctx.stroke(ovalPath(A.muzzleC.x, mouthY + 2, 7, 8), with: .color(Fur.ink),
                       style: StrokeStyle(lineWidth: 2.2))

        case .shy:
            var m = Path()
            m.move(to: CGPoint(x: A.muzzleC.x - 5, y: mouthY + 1))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x + 5, y: mouthY + 1), control: CGPoint(x: A.muzzleC.x, y: mouthY + 5))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .worried:
            var m = Path()
            m.move(to: CGPoint(x: A.muzzleC.x - 8, y: mouthY + 3))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x, y: mouthY), control: CGPoint(x: A.muzzleC.x - 3, y: mouthY - 3))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x + 8, y: mouthY + 3), control: CGPoint(x: A.muzzleC.x + 3, y: mouthY + 6))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .bored:
            var m = Path()
            m.move(to: CGPoint(x: A.muzzleC.x - 9, y: mouthY + 2))
            m.addLine(to: CGPoint(x: A.muzzleC.x + 9, y: mouthY + 2))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .eating, .hungry:
            let chomp = pose.emotion == .eating ? abs(sin(pose.phase * 14)) * 8 : 2
            ctx.fill(Path(ellipseIn: CGRect(x: A.muzzleC.x - 10, y: mouthY - 1, width: 20, height: 5 + chomp)),
                     with: .color(Fur.ink.opacity(0.85)))
            ctx.fill(capsulePath(A.muzzleC.x + 5, mouthY + 5, 10, 12), with: .color(Fur.tongue))

        case .sad:
            var m = Path()
            m.move(to: CGPoint(x: A.muzzleC.x - 9, y: mouthY + 5))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x + 9, y: mouthY + 5), control: CGPoint(x: A.muzzleC.x, y: mouthY - 2))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

        case .sleepy:
            ctx.fill(ovalPath(A.muzzleC.x, mouthY + 2, 10, 8), with: .color(Fur.ink.opacity(0.85)))

        default:
            var m = Path()
            m.move(to: CGPoint(x: A.muzzleC.x - 9, y: mouthY - 1))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x, y: mouthY + 5), control: CGPoint(x: A.muzzleC.x - 5, y: mouthY + 5))
            m.addQuadCurve(to: CGPoint(x: A.muzzleC.x + 9, y: mouthY - 1), control: CGPoint(x: A.muzzleC.x + 5, y: mouthY + 5))
            ctx.stroke(m, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }

        // small simple nose, same ink as the rest of the face
        ctx.fill(Art.nose, with: .color(Fur.ink))
    }

    private func drawEyes(_ ctx: GraphicsContext) {
        let lookX = pose.look.dx * 2.6
        let lookY = pose.look.dy * 2.2
        for (i, e) in [A.eyeL, A.eyeR].enumerated() {
            let c = CGPoint(x: e.x + lookX, y: e.y + lookY)
            let far = (i == 0)
            let w = far ? 15.0 : 17.0
            let h = far ? 18.0 : 20.0
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
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))

        case .sleepy:
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.55, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.55, y: c.y), control: CGPoint(x: c.x, y: c.y + h * 0.4))
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

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
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))

        case .bored:
            let hh = h * 0.5
            ctx.fill(ovalPath(c.x, c.y + h * 0.14, w * 0.65, hh * 0.65), with: .color(Fur.ink))
            var lid = Path()
            lid.move(to: CGPoint(x: c.x - w * 0.5, y: c.y - h * 0.08))
            lid.addLine(to: CGPoint(x: c.x + w * 0.5, y: c.y - h * 0.08))
            ctx.stroke(lid, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

        case .angry:
            ctx.fill(ovalPath(c.x, c.y + 2, w * 0.9, h * 0.55), with: .color(Fur.ink))

        case .dizzy:
            var p = Path()
            for t in Swift.stride(from: 0.0, through: 3.2 * .pi, by: 0.24) {
                let r = t * 1.1
                let pt = CGPoint(x: c.x + cos(t) * r, y: c.y + sin(t) * r)
                if t == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        default:
            let k = 1 - blink
            if k < 0.16 {
                var p = Path()
                p.move(to: CGPoint(x: c.x - w * 0.5, y: c.y))
                p.addLine(to: CGPoint(x: c.x + w * 0.5, y: c.y))
                ctx.stroke(p, with: .color(Fur.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                return
            }
            let hh = h * k
            let big = (pose.emotion == .alert || pose.emotion == .excited || pose.emotion == .curious) ? 1.12 : 1.0
            let ew = w * big, eh = hh * big
            ctx.fill(ovalPath(c.x, c.y, ew, eh), with: .color(Fur.ink))
            ctx.fill(ovalPath(c.x - ew * 0.2, c.y - eh * 0.24, ew * 0.32, eh * 0.28),
                     with: .color(.white.opacity(0.9)))
            // a second, much smaller shine low on the opposite side
            ctx.fill(ovalPath(c.x + ew * 0.19, c.y + eh * 0.2, ew * 0.15, eh * 0.13),
                     with: .color(.white.opacity(0.5)))
            if pose.emotion == .sad {
                let t = (pose.phase.truncatingRemainder(dividingBy: 2.6)) / 2.6
                let ty = c.y + hh * 0.5 + t * 20
                ctx.fill(ovalPath(c.x + (far ? -5 : 6), ty, 5, 7.5),
                         with: .color(Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.85 * (1 - t))))
            }
        }
    }

    private func drawBrows(_ ctx: GraphicsContext) {
        let lookX = pose.look.dx * 2.0
        func brow(_ c: CGPoint, mirrored: Bool, angle: Double, lift: Double) {
            var g = ctx
            g.translateBy(x: c.x + lookX, y: c.y - 14 + lift)
            if mirrored { g.scaleBy(x: -1, y: 1) }
            g.rotate(by: .degrees(angle))
            var p = Path()
            p.move(to: CGPoint(x: -6, y: 0))
            p.addLine(to: CGPoint(x: 6, y: 0))
            g.stroke(p, with: .color(Fur.ink.opacity(0.8)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
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
}

