import SwiftUI

/// Draws the streak plant for every stage and species.
///
/// One plant that only ever grows: every stage stands on the same soil bed, the sprout's
/// two leaves stay at the crown from day 1 to Grove Tree, and each stage adds one new
/// feature (first leaves → grows tall → first bud → fills out → first flowers → grows a
/// trunk → first fruit → a bird moves in → starts a grove).
///
/// Style: lobed (oak), serrated (cherry) or needle (pine) leaves, one light source from the
/// top left, layered crowns with soft shade, and per-clump flutter. Small sizes (the feed's
/// grove strip, the widget) draw with less detail to stay fast.
///
/// Shared with the widget extension, so it depends only on `PlantStage`, `PlantStyle`
/// and the Grove colours.
enum GrovePlantRenderer {

    // MARK: - Entry point

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        stage: PlantStage,
        style: PlantStyle,
        isWilted: Bool,
        elapsed: TimeInterval,
        sway: CGFloat,
        showsGround: Bool = true,
        trainedToday: Bool = false
    ) {
        let u = min(size.width, size.height)
        var rng = SeededRandom(state: style.seed &+ 0x9E3779B97F4A7C15)
        let shift = Double(rng.range(-1, 1))
        let flip: CGFloat = style.seed & 1 == 1 ? -1 : 1
        let c = Ctx(
            u: u,
            cx: size.width / 2,
            groundY: size.height - u * 0.14,
            leaves: shades(for: style.species, wilted: isWilted, shift: shift),
            bark: bark(for: style.species, wilted: isWilted),
            style: style,
            stage: stage,
            wilted: isWilted,
            elapsed: elapsed,
            sway: isWilted ? sway * 0.3 : sway,
            detail: u >= 110,
            showsGround: showsGround,
            flip: flip,
            lean: rng.range(0.006, 0.026) * flip
        )

        let showsBloom = trainedToday && !isWilted
        if showsBloom {
            drawTrainedTodayGlow(&context, c)
        }
        if stage == .groveTree && !isWilted {
            drawGroveGlow(&context, c)
        }
        if showsGround {
            drawGround(&context, c, halfWidth: stage == .groveTree ? 0.46 : 0.40)
        } else {
            // Scenes with their own ground (the grove strip) get just a contact shadow.
            softEllipse(&context, c, center: CGPoint(x: c.cx, y: c.groundY + c.u * 0.005),
                        size: CGSize(width: c.u * (stage.rawValue >= PlantStage.youngTree.rawValue ? 0.34 : 0.2), height: c.u * 0.035),
                        color: soilDeep.opacity(0.28), blur: c.u * 0.01)
        }

        // A wilted plant leans over, drained of colour; flowers, fruit and the bird are gone.
        var g = context
        if isWilted {
            g.translateBy(x: c.cx, y: c.groundY)
            g.rotate(by: .degrees(-6 * Double(flip)))
            g.translateBy(x: -c.cx, y: -c.groundY)
        }

        switch stage {
        case .seed: drawSeedStage(&g, c)
        case .sprout: drawSprout(&g, c)
        case .seedling: drawSeedling(&g, c)
        case .youngPlant: drawYoungPlant(&g, c)
        case .bush, .floweringBush, .sapling, .youngTree, .tree, .groveTree:
            if style.species == .pine {
                drawPineStage(&g, c)
            } else {
                drawBroadleafStage(&g, c)
            }
        }
        if showsBloom {
            drawTrainedTodayBlooms(&g, c)
        }
    }

    // MARK: - Trained today

    /// The part of the plant to highlight: its crown or top, as a centre height and radius.
    private static func bloomRegion(_ c: Ctx) -> (up: CGFloat, radius: CGFloat) {
        switch c.stage {
        case .seed: return (0.06, 0.06)
        case .sprout: return (0.20, 0.08)
        case .seedling: return (0.29, 0.10)
        case .youngPlant: return (0.34, 0.14)
        default:
            if c.species == .pine {
                let spec = pineSpec(c.stage)
                return (spec.apexUp - spec.height * 0.5, spec.halfWidth * 0.85)
            }
            let spec = crownSpec(c)
            return (spec.centerUp, spec.radius)
        }
    }

    /// A warm, slowly breathing glow behind someone who trained today.
    private static func drawTrainedTodayGlow(_ g: inout GraphicsContext, _ c: Ctx) {
        let region = bloomRegion(c)
        let center = c.point(0, region.up)
        let r = c.u * max(region.radius * 2.1, 0.2)
        let breath = 0.85 + 0.15 * sin(c.elapsed * 1.6)
        g.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.86, blue: 0.55).opacity(0.55 * breath),
                                                       Color(red: 1, green: 0.90, blue: 0.70).opacity(0.18 * breath), .clear]),
                                     center: center, startRadius: 0, endRadius: r))
    }

    /// Fresh blossoms over the top of the plant, in a warm colour that reads at small sizes.
    private static func drawTrainedTodayBlooms(_ g: inout GraphicsContext, _ c: Ctx) {
        let region = bloomRegion(c)
        let count: Int
        switch c.stage {
        case .seed: count = 0
        case .sprout: count = 1
        case .seedling: count = 2
        case .youngPlant: count = 3
        default: count = 6
        }
        guard count > 0 else { return }
        var bloomContext = c
        bloomContext.style.blossom = .coral
        var rng = SeededRandom(state: c.style.seed &+ 77)
        let radius = max(c.u * 0.034, 2.4)
        for k in 0..<count {
            // Spread over the upper arc of the crown, slightly jittered per person.
            let t = count == 1 ? 0.5 : CGFloat(k) / CGFloat(count - 1)
            let angle = -.pi * (0.12 + 0.76 * t) + rng.range(-0.12, 0.12)
            let reach = region.radius * (count <= 3 ? 0.7 : rng.range(0.55, 0.85))
            let up = region.up - sin(angle) * reach
            let p = c.point(cos(angle) * reach * c.flip, up)
            flower(&g, bloomContext, at: p, radius: radius, spin: rng.range(0, .pi))
        }
    }

    // MARK: - Context

    private struct Ctx {
        let u: CGFloat
        let cx: CGFloat
        let groundY: CGFloat
        let leaves: Shades
        let bark: Bark
        var style: PlantStyle
        let stage: PlantStage
        let wilted: Bool
        let elapsed: Double
        let sway: CGFloat
        let detail: Bool
        /// Without its soil mound, the seed rests on the surface instead of nesting in it.
        let showsGround: Bool
        /// 1 or -1: mirrors the layout per person.
        let flip: CGFloat
        let lean: CGFloat

        var species: PlantSpecies { style.species }
        var showsExtras: Bool { !wilted }

        /// y for a height above ground, in units of the canvas size.
        func y(_ up: CGFloat) -> CGFloat { groundY - up * u }

        /// How far the plant leans and sways at a given height.
        func offset(at up: CGFloat) -> CGFloat {
            let h = min(max(up / 0.75, 0), 1)
            return lean * u * min(up / 0.45, 1.2) + h * h * sway
        }

        /// A point on the plant at a height, `dx` to the side (mirrored per person).
        func point(_ dx: CGFloat, _ up: CGFloat) -> CGPoint {
            CGPoint(x: cx + offset(at: up) + dx * u * flip, y: y(up))
        }
    }

    // MARK: - Palettes

    struct Shades {
        let deep: Color, dark: Color, mid: Color, light: Color, sun: Color, under: Color
    }

    struct Bark {
        let dark: Color, mid: Color, light: Color
    }

    private struct RGB {
        let r: Double, g: Double, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        func color(shift: Double = 0) -> Color {
            Color(red: clamp(r + shift * 0.035), green: clamp(g + shift * 0.01), blue: clamp(b - shift * 0.04))
        }
        private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
    }

    static func shades(for species: PlantSpecies, wilted: Bool, shift: Double) -> Shades {
        let p: [RGB]
        if wilted {
            p = [RGB(0.45, 0.36, 0.24), RGB(0.55, 0.45, 0.30), RGB(0.66, 0.56, 0.38),
                 RGB(0.76, 0.67, 0.47), RGB(0.84, 0.76, 0.56), RGB(0.72, 0.64, 0.46)]
        } else {
            switch species {
            case .oak:
                p = [RGB(0.25, 0.39, 0.26), RGB(0.33, 0.49, 0.31), RGB(0.45, 0.61, 0.38),
                     RGB(0.60, 0.74, 0.48), RGB(0.78, 0.86, 0.56), RGB(0.68, 0.76, 0.55)]
            case .cherry:
                p = [RGB(0.30, 0.42, 0.25), RGB(0.38, 0.53, 0.30), RGB(0.50, 0.65, 0.37),
                     RGB(0.64, 0.77, 0.46), RGB(0.82, 0.88, 0.58), RGB(0.72, 0.78, 0.55)]
            case .pine:
                p = [RGB(0.15, 0.29, 0.24), RGB(0.21, 0.37, 0.30), RGB(0.30, 0.47, 0.37),
                     RGB(0.43, 0.59, 0.46), RGB(0.60, 0.74, 0.56), RGB(0.50, 0.62, 0.50)]
            }
        }
        return Shades(deep: p[0].color(shift: shift), dark: p[1].color(shift: shift), mid: p[2].color(shift: shift),
                      light: p[3].color(shift: shift), sun: p[4].color(shift: shift), under: p[5].color(shift: shift))
    }

    static func bark(for species: PlantSpecies, wilted: Bool) -> Bark {
        let p: [RGB]
        if wilted {
            p = [RGB(0.40, 0.33, 0.27), RGB(0.55, 0.47, 0.40), RGB(0.70, 0.62, 0.54)]
        } else {
            switch species {
            case .oak: p = [RGB(0.34, 0.22, 0.15), RGB(0.50, 0.33, 0.22), RGB(0.69, 0.50, 0.36)]
            case .cherry: p = [RGB(0.36, 0.22, 0.21), RGB(0.53, 0.34, 0.31), RGB(0.69, 0.51, 0.47)]
            case .pine: p = [RGB(0.32, 0.25, 0.20), RGB(0.47, 0.37, 0.29), RGB(0.63, 0.52, 0.42)]
            }
        }
        return Bark(dark: p[0].color(), mid: p[1].color(), light: p[2].color())
    }

    private static let soilTop = Color(red: 0.84, green: 0.76, blue: 0.62)
    private static let soilMid = Color(red: 0.70, green: 0.59, blue: 0.45)
    private static let soilDeep = Color(red: 0.55, green: 0.44, blue: 0.33)
    private static let grass = Color(red: 0.48, green: 0.62, blue: 0.38)
    private static let grassLight = Color(red: 0.58, green: 0.71, blue: 0.44)

    // MARK: - Random

    struct SeededRandom {
        var state: UInt64
        mutating func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 10_000) / 10_000
        }
        mutating func range(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * next() }
    }

    // MARK: - Ground and light

    private static func drawGroveGlow(_ g: inout GraphicsContext, _ c: Ctx) {
        let center = CGPoint(x: c.cx - c.u * 0.06, y: c.y(0.52))
        let r = c.u * 0.42
        g.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.92, blue: 0.68).opacity(0.5), .clear]),
                                     center: center, startRadius: 0, endRadius: r))
    }

    private static func softEllipse(_ g: inout GraphicsContext, _ c: Ctx, center: CGPoint, size: CGSize, color: Color, blur: CGFloat) {
        var layer = g
        if c.detail { layer.addFilter(.blur(radius: blur)) }
        layer.fill(Path(ellipseIn: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                          width: size.width, height: size.height)),
                   with: .color(c.detail ? color : color.opacity(0.6)))
    }

    /// The same soil bed for every stage: a mound with a bumpy edge, pebbles and grass.
    private static func drawGround(_ g: inout GraphicsContext, _ c: Ctx, halfWidth: CGFloat) {
        let soilW = c.u * halfWidth
        let depth = c.u * 0.05
        let cx = c.cx
        let gy = c.groundY

        softEllipse(&g, c, center: CGPoint(x: cx, y: gy + depth * 0.9), size: CGSize(width: soilW * 2.1, height: depth * 0.9),
                    color: .black.opacity(0.10), blur: c.u * 0.015)

        var rng = SeededRandom(state: 91)
        let steps = 16
        var edge: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let bump = (i == 0 || i == steps) ? 0 : rng.range(-0.12, 0.12) * depth
            edge.append(CGPoint(x: cx - soilW + t * soilW * 2, y: gy - sin(.pi * t) * depth * 0.95 + bump))
        }
        var mound = Path()
        mound.move(to: edge[0])
        for i in 1..<edge.count {
            mound.addQuadCurve(to: CGPoint(x: (edge[i - 1].x + edge[i].x) / 2, y: (edge[i - 1].y + edge[i].y) / 2), control: edge[i - 1])
        }
        mound.addLine(to: edge[steps])
        mound.addQuadCurve(to: edge[0], control: CGPoint(x: cx, y: gy + depth * 1.6))
        mound.closeSubpath()
        g.fill(mound, with: .linearGradient(Gradient(stops: [
            .init(color: soilTop, location: 0), .init(color: soilMid, location: 0.55), .init(color: soilDeep, location: 1),
        ]), startPoint: CGPoint(x: cx - soilW * 0.4, y: gy - depth), endPoint: CGPoint(x: cx + soilW * 0.3, y: gy + depth)))

        guard c.detail else { return }

        var rim = Path()
        rim.move(to: edge[2])
        for i in 3...8 { rim.addLine(to: CGPoint(x: edge[i].x, y: edge[i].y + 0.6)) }
        g.stroke(rim, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

        for _ in 0..<7 {
            let x = cx + rng.range(-soilW * 0.8, soilW * 0.8)
            let y = gy + rng.range(-depth * 0.2, depth * 0.55)
            let r = c.u * rng.range(0.006, 0.011)
            g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.7, width: r * 2, height: r * 1.4)),
                   with: .linearGradient(Gradient(colors: [Color(white: 0.84), Color(white: 0.62)]),
                                         startPoint: CGPoint(x: x - r, y: y - r), endPoint: CGPoint(x: x + r, y: y + r)))
        }

        let tufts: [(x: CGFloat, lean: CGFloat, height: CGFloat)] = [(-0.80, -0.4, 0.036), (-0.56, 0.1, 0.026), (0.64, 0.35, 0.032), (0.86, 0.2, 0.022)]
        for tuft in tufts {
            drawGrassTuft(&g, c, base: CGPoint(x: cx + soilW * tuft.x, y: gy - depth * sin(.pi * (tuft.x + 1) / 2) * 0.9),
                          height: c.u * tuft.height, lean: tuft.lean)
        }
    }

    private static func drawGrassTuft(_ g: inout GraphicsContext, _ c: Ctx, base: CGPoint, height: CGFloat, lean: CGFloat) {
        let blades: [(dx: CGFloat, curve: CGFloat)] = [(-1.5, -2.5 + lean * 3), (0.5, 0.5 + lean * 2), (2, 3.5 + lean * 3)]
        for (i, blade) in blades.enumerated() {
            var p = Path()
            p.move(to: CGPoint(x: base.x + blade.dx, y: base.y))
            p.addQuadCurve(to: CGPoint(x: base.x + blade.dx + blade.curve, y: base.y - height * (0.8 + CGFloat(i) * 0.1)),
                           control: CGPoint(x: base.x + blade.dx + blade.curve * 0.4, y: base.y - height * 0.5))
            g.stroke(p, with: .color(c.wilted ? soilMid : (i == 1 ? grassLight : grass)), lineWidth: 0.7)
        }
    }

    // MARK: - Leaves

    static func leafPath(length L: CGFloat, width W: CGFloat, lobes: CGFloat, serration: CGFloat, taper: CGFloat) -> Path {
        let steps = 22
        var top: [CGPoint] = []
        var bottom: [CGPoint] = []
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let envelope = pow(sin(.pi * min(t * 1.05, 1)), 0.8) * (1 - taper * t)
            let lobe = 1 - lobes + lobes * cos(t * .pi * 5)
            let teeth = 1 + serration * sin(t * .pi * 18)
            let half = W / 2 * envelope * lobe * teeth
            top.append(CGPoint(x: t * L, y: -half))
            bottom.append(CGPoint(x: t * L, y: half))
        }
        var path = Path()
        path.move(to: .zero)
        for p in top { path.addLine(to: p) }
        for p in bottom.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    /// One leaf in the species' shape. Pine leaves are fans of needles.
    private static func leaf(_ g: inout GraphicsContext, _ c: Ctx, base: CGPoint, length L: CGFloat, width W: CGFloat,
                             angle: CGFloat, colors: [Color]) {
        if c.species == .pine {
            needles(&g, c, base: base, length: L, angle: angle, light: colors.last ?? c.leaves.mid, dark: colors.first ?? c.leaves.dark)
            return
        }
        let shape = c.species == .oak
            ? leafPath(length: L, width: W, lobes: 0.14, serration: 0, taper: 0.15)
            : leafPath(length: L, width: W * 0.9, lobes: 0, serration: 0.05, taper: 0.35)
        let path = shape.applying(CGAffineTransform(translationX: base.x, y: base.y).rotated(by: angle))
        let tip = CGPoint(x: base.x + cos(angle) * L, y: base.y + sin(angle) * L)
        g.fill(path, with: .linearGradient(Gradient(colors: colors), startPoint: base, endPoint: tip))
        if c.detail {
            var vein = Path()
            vein.move(to: base)
            vein.addLine(to: CGPoint(x: base.x + cos(angle) * L * 0.85, y: base.y + sin(angle) * L * 0.85))
            g.stroke(vein, with: .color(c.leaves.deep.opacity(0.3)), lineWidth: 0.5)
        }
    }

    private static func needles(_ g: inout GraphicsContext, _ c: Ctx, base: CGPoint, length L: CGFloat, angle: CGFloat,
                                light: Color, dark: Color) {
        let n = c.detail ? 7 : 4
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n - 1) - 0.5
            let a = angle + t * 1.0
            let len = L * (0.7 + 0.3 * (1 - abs(t) * 2))
            var p = Path()
            p.move(to: base)
            p.addLine(to: CGPoint(x: base.x + cos(a) * len, y: base.y + sin(a) * len))
            g.stroke(p, with: .color(i % 2 == 0 ? light : dark), style: StrokeStyle(lineWidth: max(0.7, c.u * 0.0045), lineCap: .round))
        }
    }

    /// Leaf varied in size, side-on (narrow), or curled showing its paler underside.
    private static func variedLeaf(_ g: inout GraphicsContext, _ c: Ctx, rng: inout SeededRandom, base: CGPoint,
                                   baseLength: CGFloat, angle: CGFloat, colors: [Color]) {
        let roll = rng.next()
        var length = baseLength * rng.range(0.62, 1.3)
        var width = length * 0.62
        var fill = colors
        if roll < 0.18 {
            width = length * 0.26
        } else if roll < 0.3 {
            length *= 0.72
            width = length * 0.5
            fill = [colors[0], c.leaves.under]
        }
        leaf(&g, c, base: base, length: length, width: width, angle: angle, colors: fill)
    }

    /// The Grove signature: the sprout's first two leaves, kept at the top of every stage.
    private static func signature(_ g: inout GraphicsContext, _ c: Ctx, at p: CGPoint, length L: CGFloat) {
        let flutter = CGFloat(sin(c.elapsed * 1.9)) * 0.06
        let droop: CGFloat = c.wilted ? 0.45 : 0
        var stem = Path()
        stem.move(to: CGPoint(x: p.x, y: p.y + L * 0.5))
        stem.addLine(to: p)
        g.stroke(stem, with: .color(c.leaves.mid), style: StrokeStyle(lineWidth: max(1, c.u * 0.007), lineCap: .round))
        let pairs: [(angle: CGFloat, colors: [Color])] = [
            (-2.35 + flutter - droop, [c.leaves.mid, c.leaves.light]),
            (-0.79 + flutter + droop, [c.leaves.light, c.leaves.sun]),
        ]
        for pair in pairs {
            let path = leafPath(length: L, width: L * 0.55, lobes: 0, serration: 0, taper: 0.2)
                .applying(CGAffineTransform(translationX: p.x, y: p.y).rotated(by: pair.angle))
            let tip = CGPoint(x: p.x + cos(pair.angle) * L, y: p.y + sin(pair.angle) * L)
            g.fill(path, with: .linearGradient(Gradient(colors: pair.colors), startPoint: p, endPoint: tip))
            if c.detail {
                var vein = Path()
                vein.move(to: p)
                vein.addLine(to: CGPoint(x: p.x + cos(pair.angle) * L * 0.8, y: p.y + sin(pair.angle) * L * 0.8))
                g.stroke(vein, with: .color(c.leaves.deep.opacity(0.28)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Stems

    private static func stem(_ g: inout GraphicsContext, _ c: Ctx, from a: CGPoint, to b: CGPoint, control: CGPoint, width: CGFloat) {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: control)
        g.stroke(p, with: .linearGradient(Gradient(colors: [c.leaves.dark, c.leaves.mid]), startPoint: a, endPoint: b),
                 style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    // MARK: - Flowers, buds and fruit

    private static func flower(_ g: inout GraphicsContext, _ c: Ctx, at p: CGPoint, radius r: CGFloat, spin: CGFloat) {
        let blossom = c.style.blossom
        for k in 0..<5 {
            let a = spin + CGFloat(k) * .pi * 2 / 5
            let petal = Path(ellipseIn: CGRect(x: -r * 0.42, y: -r * 0.3, width: r * 0.84, height: r * 0.6))
                .applying(CGAffineTransform(translationX: p.x + cos(a) * r * 0.5, y: p.y + sin(a) * r * 0.5).rotated(by: a))
            g.fill(petal, with: .linearGradient(Gradient(colors: [blossom.petal, blossom.petal.opacity(0.85)]),
                                                startPoint: p, endPoint: CGPoint(x: p.x + cos(a) * r, y: p.y + sin(a) * r)))
        }
        g.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.28, y: p.y - r * 0.28, width: r * 0.56, height: r * 0.56)), with: .color(blossom.center))
    }

    private static func bud(_ g: inout GraphicsContext, _ c: Ctx, at p: CGPoint, size s: CGFloat) {
        let body = leafPath(length: s, width: s * 0.62, lobes: 0, serration: 0, taper: 0.3)
            .applying(CGAffineTransform(translationX: p.x, y: p.y).rotated(by: -.pi / 2))
        g.fill(body, with: .linearGradient(Gradient(colors: [c.style.blossom.center, c.style.blossom.petal]),
                                           startPoint: p, endPoint: CGPoint(x: p.x, y: p.y - s)))
        for side: CGFloat in [-1, 1] {
            let sepal = leafPath(length: s * 0.45, width: s * 0.25, lobes: 0, serration: 0, taper: 0.3)
                .applying(CGAffineTransform(translationX: p.x, y: p.y).rotated(by: -.pi / 2 + side * 0.5))
            g.fill(sepal, with: .color(c.leaves.mid))
        }
    }

    private static func fruit(_ g: inout GraphicsContext, _ c: Ctx, at p: CGPoint, size r: CGFloat, tilt: CGFloat) {
        var f = g
        f.translateBy(x: p.x, y: p.y)
        f.rotate(by: .radians(tilt))
        switch c.species {
        case .oak:
            f.fill(Path(ellipseIn: CGRect(x: -r * 0.85, y: -r * 0.2, width: r * 1.7, height: r * 2.1)),
                   with: .linearGradient(Gradient(colors: [Color(red: 0.74, green: 0.52, blue: 0.30), c.bark.mid]),
                                         startPoint: CGPoint(x: -r, y: 0), endPoint: CGPoint(x: r, y: r * 2)))
            f.fill(Path(ellipseIn: CGRect(x: -r * 0.2, y: r * 0.35, width: r * 0.4, height: r * 0.6)), with: .color(.white.opacity(0.3)))
            var cap = Path()
            cap.addArc(center: CGPoint(x: 0, y: r * 0.15), radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            cap.closeSubpath()
            f.fill(cap, with: .color(Color(red: 0.42, green: 0.30, blue: 0.20)))
            f.fill(Path(CGRect(x: -r * 0.08, y: -r * 1.1, width: r * 0.16, height: r * 0.35)), with: .color(c.bark.dark))
        case .cherry:
            let red = Color(red: 0.72, green: 0.16, blue: 0.20)
            for side: CGFloat in [-1, 1] {
                let center = CGPoint(x: side * r * 0.75, y: r * 0.9)
                var stalk = Path()
                stalk.move(to: CGPoint(x: 0, y: -r * 0.9))
                stalk.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r * 0.7), control: CGPoint(x: side * r * 0.2, y: -r * 0.2))
                f.stroke(stalk, with: .color(c.bark.mid), lineWidth: max(0.6, r * 0.14))
                f.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.75, y: center.y - r * 0.75, width: r * 1.5, height: r * 1.5)),
                       with: .radialGradient(Gradient(colors: [Color(red: 0.92, green: 0.38, blue: 0.38), red]),
                                             center: CGPoint(x: center.x - r * 0.25, y: center.y - r * 0.25), startRadius: 0, endRadius: r))
                f.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.35, y: center.y - r * 0.4, width: r * 0.3, height: r * 0.3)),
                       with: .color(.white.opacity(0.45)))
            }
        case .pine:
            let cone = Path(ellipseIn: CGRect(x: -r * 0.7, y: 0, width: r * 1.4, height: r * 2.4))
            f.fill(cone, with: .linearGradient(Gradient(colors: [c.bark.light, c.bark.dark]),
                                               startPoint: CGPoint(x: -r, y: 0), endPoint: CGPoint(x: r, y: r * 2.4)))
            for row in 1..<5 {
                let y = r * 2.4 * CGFloat(row) / 5
                var scale = Path()
                scale.move(to: CGPoint(x: -r * 0.6, y: y - r * 0.15))
                scale.addLine(to: CGPoint(x: 0, y: y + r * 0.12))
                scale.addLine(to: CGPoint(x: r * 0.6, y: y - r * 0.15))
                f.stroke(scale, with: .color(c.bark.dark.opacity(0.6)), lineWidth: max(0.5, r * 0.1))
            }
            f.fill(Path(CGRect(x: -r * 0.08, y: -r * 0.4, width: r * 0.16, height: r * 0.45)), with: .color(c.bark.dark))
        }
    }

    // MARK: - Early stages (shared by all species)

    private static func drawSeedStage(_ g: inout GraphicsContext, _ c: Ctx) {
        let p = CGPoint(x: c.cx, y: c.y(c.showsGround ? 0.045 : 0.018))
        softEllipse(&g, c, center: CGPoint(x: p.x, y: p.y + c.u * 0.02), size: CGSize(width: c.u * 0.12, height: c.u * 0.03),
                    color: soilDeep.opacity(0.5), blur: c.u * 0.006)
        let r = c.u * 0.03
        switch c.species {
        case .oak:
            fruit(&g, c, at: CGPoint(x: p.x, y: p.y - r * 0.4), size: r, tilt: 0.3 * c.flip)
        case .cherry:
            g.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.8, width: r * 2, height: r * 1.6)),
                   with: .linearGradient(Gradient(colors: [Color(red: 0.86, green: 0.74, blue: 0.58), Color(red: 0.62, green: 0.48, blue: 0.34)]),
                                         startPoint: CGPoint(x: p.x - r, y: p.y - r), endPoint: CGPoint(x: p.x + r, y: p.y + r)))
            var ridge = Path()
            ridge.move(to: CGPoint(x: p.x - r * 0.6, y: p.y - r * 0.5))
            ridge.addQuadCurve(to: CGPoint(x: p.x + r * 0.6, y: p.y - r * 0.5), control: CGPoint(x: p.x, y: p.y - r * 0.9))
            g.stroke(ridge, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
        case .pine:
            let wing = leafPath(length: r * 2.6, width: r * 1.1, lobes: 0, serration: 0, taper: 0.1)
                .applying(CGAffineTransform(translationX: p.x - r * 0.5, y: p.y).rotated(by: -0.5 * c.flip - .pi * (c.flip < 0 ? 1 : 0)))
            g.fill(wing, with: .color(Color(red: 0.80, green: 0.70, blue: 0.55).opacity(0.75)))
            g.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.75, y: p.y - r * 0.45, width: r * 1.1, height: r * 0.8)), with: .color(c.bark.dark))
        }
        if c.detail && !c.wilted {
            // A faint glint: something is about to grow
            let glint = CGFloat(0.5 + 0.5 * sin(c.elapsed * 1.4))
            softEllipse(&g, c, center: CGPoint(x: p.x, y: p.y - r), size: CGSize(width: r * 4, height: r * 3),
                        color: Color(red: 1, green: 0.95, blue: 0.75).opacity(0.25 * glint), blur: r)
        }
    }

    private static func drawSprout(_ g: inout GraphicsContext, _ c: Ctx) {
        let top = c.point(0, 0.20)
        stem(&g, c, from: CGPoint(x: c.cx, y: c.y(0.02)), to: top, control: c.point(-0.02, 0.10), width: c.u * 0.016)
        signature(&g, c, at: top, length: c.u * 0.09)
    }

    private static func drawSeedling(_ g: inout GraphicsContext, _ c: Ctx) {
        let top = c.point(0, 0.34)
        stem(&g, c, from: CGPoint(x: c.cx, y: c.y(0.02)), to: top, control: c.point(-0.025, 0.17), width: c.u * 0.017)
        var rng = SeededRandom(state: c.style.seed &+ 21)
        let pairs: [(up: CGFloat, length: CGFloat)] = [(0.12, 0.075), (0.20, 0.07), (0.27, 0.06)]
        for (i, pair) in pairs.enumerated() {
            let p = c.point(0, pair.up)
            for side: CGFloat in [-1, 1] {
                let angle = (side < 0 ? CGFloat.pi + 0.35 : -0.35) + rng.range(-0.12, 0.12) + (i % 2 == 0 ? 0.1 : -0.1)
                let colors = side < 0 ? [c.leaves.mid, c.leaves.light] : [c.leaves.dark, c.leaves.mid]
                leaf(&g, c, base: p, length: c.u * pair.length, width: c.u * pair.length * 0.6, angle: angle, colors: colors)
            }
        }
        signature(&g, c, at: top, length: c.u * 0.085)
    }

    private static func drawYoungPlant(_ g: inout GraphicsContext, _ c: Ctx) {
        let top = c.point(0, 0.42)
        stem(&g, c, from: CGPoint(x: c.cx, y: c.y(0.02)), to: top, control: c.point(-0.02, 0.2), width: c.u * 0.02)
        var rng = SeededRandom(state: c.style.seed &+ 33)

        // Two side branches, each ending in leaves; a bud on the right one
        let branches: [(from: CGFloat, dx: CGFloat, up: CGFloat)] = [(0.17, -0.14, 0.29), (0.24, 0.15, 0.36)]
        var budPoint = top
        for branch in branches {
            let a = c.point(0, branch.from)
            let b = c.point(branch.dx, branch.up)
            stem(&g, c, from: a, to: b, control: c.point(branch.dx * 0.4, branch.up - 0.02), width: c.u * 0.012)
            for k in 0..<4 {
                let t = 0.35 + CGFloat(k) * 0.2
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let outward: CGFloat = (branch.dx * c.flip) < 0 ? .pi : 0
                let angle = outward + (k % 2 == 0 ? -0.6 : 0.5) * (outward == 0 ? 1 : -1) + rng.range(-0.2, 0.2)
                leaf(&g, c, base: p, length: c.u * rng.range(0.055, 0.075), width: c.u * 0.04, angle: angle,
                     colors: k % 2 == 0 ? [c.leaves.mid, c.leaves.light] : [c.leaves.dark, c.leaves.mid])
            }
            if branch.dx > 0 { budPoint = b }
        }
        for (i, up) in [0.08, 0.32].enumerated() {
            let p = c.point(0, CGFloat(up))
            leaf(&g, c, base: p, length: c.u * 0.06, width: c.u * 0.038, angle: i == 0 ? .pi + 0.4 : -0.4,
                 colors: [c.leaves.dark, c.leaves.mid])
        }
        if c.showsExtras {
            bud(&g, c, at: budPoint, size: c.u * 0.05)
        }
        signature(&g, c, at: top, length: c.u * 0.08)
    }

    // MARK: - Broadleaf (oak, cherry) from Bush onwards

    private struct Clump {
        let x: CGFloat, y: CGFloat, r: CGFloat, layer: Int
    }

    /// A deliberately lopsided crown (in units of crown radius); mirrored and jittered per person.
    private static let crownClumps: [Clump] = [
        Clump(x: -0.62, y: -0.16, r: 0.40, layer: 0), Clump(x: 0.56, y: -0.42, r: 0.40, layer: 0),
        Clump(x: 0.06, y: -0.74, r: 0.40, layer: 0), Clump(x: -0.30, y: -0.58, r: 0.38, layer: 0),
        Clump(x: 0.86, y: 0.02, r: 0.30, layer: 0), Clump(x: -0.18, y: -0.06, r: 0.50, layer: 0),
        Clump(x: 0.30, y: -0.08, r: 0.46, layer: 0),
        Clump(x: -0.90, y: 0.14, r: 0.32, layer: 1), Clump(x: -0.50, y: -0.44, r: 0.36, layer: 1),
        Clump(x: 0.40, y: -0.64, r: 0.32, layer: 1), Clump(x: 0.68, y: 0.18, r: 0.34, layer: 1),
        Clump(x: 0.02, y: -0.32, r: 0.40, layer: 1), Clump(x: -0.36, y: 0.14, r: 0.36, layer: 1),
        Clump(x: -0.62, y: 0.28, r: 0.27, layer: 2), Clump(x: 0.36, y: 0.26, r: 0.28, layer: 2),
        Clump(x: -0.08, y: 0.10, r: 0.30, layer: 2), Clump(x: 0.14, y: -0.50, r: 0.24, layer: 2),
        Clump(x: 0.62, y: -0.20, r: 0.22, layer: 2),
    ]

    private static let crownGaps: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [(0.50, -0.02, 0.10), (-0.50, -0.10, 0.08), (0.22, -0.30, 0.06)]

    private struct CrownSpec {
        let centerUp: CGFloat      // crown centre height above ground
        let radius: CGFloat        // crown radius
        let trunkUp: CGFloat       // where the visible trunk meets the crown
        let trunkHalf: CGFloat     // trunk half-width at the base
        let forked: Bool
        let flowers: Int
        let fruitClusters: Int
        let gaps: Bool
        let nest: Bool
        let saplings: Bool
    }

    private static func crownSpec(_ c: Ctx) -> CrownSpec {
        let cherry = c.species == .cherry
        switch c.stage {
        case .bush:
            return CrownSpec(centerUp: 0.24, radius: 0.19, trunkUp: 0.08, trunkHalf: 0.016, forked: false,
                             flowers: 0, fruitClusters: 0, gaps: false, nest: false, saplings: false)
        case .floweringBush:
            return CrownSpec(centerUp: 0.26, radius: 0.21, trunkUp: 0.09, trunkHalf: 0.018, forked: false,
                             flowers: cherry ? 20 : 11, fruitClusters: 0, gaps: false, nest: false, saplings: false)
        case .sapling:
            return CrownSpec(centerUp: 0.46, radius: 0.19, trunkUp: 0.32, trunkHalf: 0.026, forked: false,
                             flowers: cherry ? 12 : 4, fruitClusters: 0, gaps: false, nest: false, saplings: false)
        case .youngTree:
            return CrownSpec(centerUp: 0.46, radius: 0.23, trunkUp: 0.30, trunkHalf: 0.04, forked: true,
                             flowers: cherry ? 8 : 0, fruitClusters: 2, gaps: true, nest: false, saplings: false)
        case .tree:
            return CrownSpec(centerUp: 0.46, radius: 0.255, trunkUp: 0.28, trunkHalf: 0.05, forked: true,
                             flowers: cherry ? 10 : 0, fruitClusters: 3, gaps: true, nest: true, saplings: false)
        default: // groveTree
            return CrownSpec(centerUp: 0.45, radius: 0.28, trunkUp: 0.26, trunkHalf: 0.056, forked: true,
                             flowers: cherry ? 22 : 9, fruitClusters: 3, gaps: true, nest: true, saplings: true)
        }
    }

    private static func drawBroadleafStage(_ g: inout GraphicsContext, _ c: Ctx) {
        let spec = crownSpec(c)
        let R = c.u * spec.radius
        let crownCenter = c.point(0, spec.centerUp)
        let crownBaseY = crownCenter.y + R * 0.70

        if spec.saplings {
            drawGroveSaplings(&g, c)
        }

        // Ground shadow under the crown
        softEllipse(&g, c, center: CGPoint(x: c.cx + c.u * 0.03 * c.flip, y: c.groundY - c.u * 0.012),
                    size: CGSize(width: R * 2.1, height: c.u * 0.055), color: c.leaves.deep.opacity(0.26), blur: c.u * 0.02)

        if spec.forked { drawRoots(&g, c) }
        drawTrunk(&g, c, spec: spec, crownCenter: crownCenter, crownR: R, forkY: crownBaseY)

        // The crown in its own layer so (for bigger trees) small openings can show branches.
        let useGaps = spec.gaps && c.detail && !c.wilted
        let droop: CGFloat = c.wilted ? R * 0.12 : 0
        var rng = SeededRandom(state: c.style.seed &+ 55)
        let jitter: [CGPoint] = crownClumps.map { _ in CGPoint(x: rng.range(-0.06, 0.06), y: rng.range(-0.05, 0.05)) }
        g.drawLayer { crown in
            if useGaps {
                crown.clipToLayer(options: .inverse) { mask in
                    for (i, gap) in crownGaps.enumerated() {
                        let p = CGPoint(x: crownCenter.x + gap.x * R * c.flip, y: crownCenter.y + gap.y * R)
                        mask.fill(blobPath(center: p, radius: gap.r * R * 1.15, squash: 0.8, seed: UInt64(300 + i)), with: .color(.black))
                    }
                }
            }
            for layer in 0...2 {
                if layer == 2 && c.detail {
                    softEllipse(&crown, c, center: CGPoint(x: crownCenter.x, y: crownBaseY - R * 0.12),
                                size: CGSize(width: R * 1.3, height: R * 0.3), color: .black.opacity(0.14), blur: R * 0.08)
                }
                for (i, clump) in crownClumps.enumerated() where clump.layer == layer {
                    if !c.detail && clump.r < 0.25 { continue }
                    let heightFactor = 1 - (clump.y + 1) / 2
                    let flutter = CGFloat(sin(c.elapsed * 1.6 + Double(i) * 1.3)) * c.u * 0.002
                    let dx = heightFactor * c.sway * 0.5 + flutter
                    let center = CGPoint(x: crownCenter.x + (clump.x + jitter[i].x) * R * c.flip + dx,
                                         y: crownCenter.y + (clump.y + jitter[i].y) * R + droop * (1 + clump.x * c.flip) * 0.5)
                    drawClump(&crown, c, center: center, radius: clump.r * R, layer: layer, seed: c.style.seed &+ UInt64(i * 97 + 13))
                }
            }
        }
        if useGaps {
            drawGapDetails(&g, c, crownCenter: crownCenter, R: R)
        }

        if c.showsExtras {
            if spec.flowers > 0 {
                var frng = SeededRandom(state: c.style.seed &+ 77)
                for _ in 0..<spec.flowers {
                    let a = frng.range(0, .pi * 2)
                    let d = R * sqrt(frng.next()) * 0.95
                    let p = CGPoint(x: crownCenter.x + cos(a) * d, y: crownCenter.y + sin(a) * d * 0.85 - R * 0.05)
                    flower(&g, c, at: p, radius: c.u * (c.species == .cherry ? 0.017 : 0.019), spin: frng.range(0, 1.2))
                }
            }
            if spec.fruitClusters > 0 {
                drawFruitClusters(&g, c, crownCenter: crownCenter, R: R, count: spec.fruitClusters)
            }
            if spec.nest {
                let nest = CGPoint(x: crownCenter.x + R * 0.88 * c.flip, y: crownCenter.y + R * 0.26)
                drawNestAndBird(&g, c, at: nest)
            }
        }

        signature(&g, c, at: CGPoint(x: crownCenter.x + R * 0.06 * c.flip, y: crownCenter.y - R * 1.1 + droop),
                  length: c.u * (spec.radius > 0.24 ? 0.066 : 0.072))
    }

    /// A closed, lumpy blob (smooth curves through noisy points).
    static func blobPath(center: CGPoint, radius r: CGFloat, squash: CGFloat = 0.92, seed: UInt64) -> Path {
        var rng = SeededRandom(state: seed)
        let phase1 = rng.range(0, .pi * 2), phase2 = rng.range(0, .pi * 2)
        let n = 18
        let points: [CGPoint] = (0..<n).map { i in
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            let rr = r * (1 + 0.10 * sin(3 * a + phase1) + 0.06 * sin(5 * a + phase2))
            return CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr * squash)
        }
        var path = Path()
        let mid = { (a: CGPoint, b: CGPoint) in CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(points[n - 1], points[0]))
        for i in 0..<n {
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % n]), control: points[i])
        }
        path.closeSubpath()
        return path
    }

    private static func drawClump(_ g: inout GraphicsContext, _ c: Ctx, center: CGPoint, radius r: CGFloat, layer: Int, seed: UInt64) {
        let L = c.leaves
        let (dark, mid, light): (Color, Color, Color) = switch layer {
        case 0: (L.deep, L.dark, L.mid.opacity(0.95))
        case 1: (L.deep, L.mid, L.light)
        default: (L.dark, L.light, L.sun)
        }

        let body = blobPath(center: center, radius: r, seed: seed)
        g.fill(body, with: .radialGradient(Gradient(stops: [
            .init(color: mid, location: 0), .init(color: mid, location: 0.35), .init(color: dark, location: 1),
        ]), center: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.55), startRadius: 0, endRadius: r * 1.9))

        var rng = SeededRandom(state: seed)
        let baseLen = c.u * (layer == 2 ? 0.066 : 0.058)
        let count = c.detail ? max(12, Int(r / (c.u * 0.011))) : max(6, Int(r / (c.u * 0.022)))
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(count)
            let angle = -.pi * 1.12 + t * .pi * 2 + rng.range(-0.15, 0.15)
            let edge = CGPoint(x: center.x + cos(angle) * r * rng.range(0.78, 0.92), y: center.y + sin(angle) * r * rng.range(0.72, 0.86))
            let flutter = c.detail ? CGFloat(sin(c.elapsed * 2.2 + Double(seed % 97) + Double(i))) * 0.07 : 0
            let facing = (cos(angle + 2.3) + 1) / 2
            let colors = facing > 0.55 ? [mid, light] : [dark, mid]
            if c.detail {
                variedLeaf(&g, c, rng: &rng, base: edge, baseLength: baseLen, angle: angle + rng.range(-0.4, 0.4) + flutter, colors: colors)
            } else {
                leaf(&g, c, base: edge, length: baseLen, width: baseLen * 0.62, angle: angle, colors: colors)
            }
        }

        guard c.detail else { return }
        for _ in 0..<(layer == 2 ? 10 : 7) {
            let a = rng.range(-.pi * 1.05, .pi * 0.15)
            let d = r * rng.range(0.1, 0.72)
            let p = CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d)
            let litSide = p.x < center.x && p.y < center.y
            variedLeaf(&g, c, rng: &rng, base: p, baseLength: baseLen * 0.85, angle: a + rng.range(-0.7, 0.7),
                       colors: litSide ? [mid, light] : [dark, mid])
        }
        var shade = g
        shade.clip(to: body)
        shade.addFilter(.blur(radius: r * 0.18))
        shade.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.9, y: center.y + r * 0.35, width: r * 1.8, height: r * 0.9)),
                   with: .color(L.deep.opacity(layer == 0 ? 0.35 : 0.25)))
    }

    /// Makes each crown opening read as shade between leaves rather than a hole.
    private static func drawGapDetails(_ g: inout GraphicsContext, _ c: Ctx, crownCenter: CGPoint, R: CGFloat) {
        for (i, gap) in crownGaps.enumerated() {
            let p = CGPoint(x: crownCenter.x + gap.x * R * c.flip, y: crownCenter.y + gap.y * R)
            let r = gap.r * R * 1.15
            var inner = g
            inner.clip(to: blobPath(center: p, radius: r, squash: 0.8, seed: UInt64(300 + i)))
            inner.addFilter(.blur(radius: r * 0.35))
            inner.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.1, y: p.y - r * 0.2, width: r * 2.2, height: r * 1.4)),
                       with: .color(c.leaves.deep.opacity(0.55)))
            var twig = Path()
            twig.move(to: CGPoint(x: p.x - r * 1.3 * c.flip, y: p.y + r * 0.6))
            twig.addQuadCurve(to: CGPoint(x: p.x + r * 1.2 * c.flip, y: p.y - r * 0.7), control: CGPoint(x: p.x - r * 0.1 * c.flip, y: p.y + r * 0.3))
            g.stroke(twig, with: .color(c.bark.mid.opacity(0.85)), style: StrokeStyle(lineWidth: c.u * 0.006, lineCap: .round))
            var rng = SeededRandom(state: UInt64(700 + i))
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * .pi * 2 + rng.range(-0.3, 0.3)
                let edge = CGPoint(x: p.x + cos(a) * r * 0.95, y: p.y + sin(a) * r * 0.8)
                leaf(&g, c, base: edge, length: c.u * rng.range(0.03, 0.042), width: c.u * 0.022, angle: a + .pi + rng.range(-0.5, 0.5),
                     colors: sin(a) < 0 ? [c.leaves.mid, c.leaves.light] : [c.leaves.dark, c.leaves.mid])
            }
        }
    }

    private static func drawRoots(_ g: inout GraphicsContext, _ c: Ctx) {
        let base = c.y(0.035)
        let roots: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [(-0.17, 0.012, 0.016), (-0.09, 0.02, 0.012), (0.12, 0.016, 0.014), (0.19, 0.006, 0.011)]
        for root in roots {
            var p = Path()
            p.move(to: CGPoint(x: c.cx + root.x * 0.15 * c.u, y: base))
            p.addQuadCurve(to: CGPoint(x: c.cx + root.x * c.u, y: c.groundY - c.u * 0.03 + root.y * c.u),
                           control: CGPoint(x: c.cx + root.x * 0.6 * c.u, y: base + c.u * 0.004))
            g.stroke(p, with: .linearGradient(Gradient(colors: [c.bark.mid, c.bark.dark.opacity(0.7)]),
                                              startPoint: CGPoint(x: c.cx, y: base), endPoint: CGPoint(x: c.cx + root.x * c.u, y: c.groundY)),
                     style: StrokeStyle(lineWidth: c.u * root.w, lineCap: .round))
        }
    }

    private static func drawTrunk(_ g: inout GraphicsContext, _ c: Ctx, spec: CrownSpec, crownCenter: CGPoint, crownR R: CGFloat, forkY: CGFloat) {
        let u = c.u
        let baseHalf = u * spec.trunkHalf
        let topHalf = baseHalf * 0.6
        let base = CGPoint(x: c.cx, y: c.groundY)
        let top = CGPoint(x: crownCenter.x - (crownCenter.x - c.cx) * 0.3, y: forkY)

        var trunk = Path()
        trunk.move(to: CGPoint(x: base.x - baseHalf * 1.5, y: base.y - u * 0.02))
        trunk.addQuadCurve(to: CGPoint(x: base.x - baseHalf, y: base.y - u * 0.06), control: CGPoint(x: base.x - baseHalf * 1.05, y: base.y - u * 0.03))
        trunk.addCurve(to: CGPoint(x: top.x - topHalf, y: top.y),
                       control1: CGPoint(x: base.x - baseHalf * 0.7, y: base.y - u * 0.15),
                       control2: CGPoint(x: top.x - topHalf * 1.3, y: top.y + u * 0.09))
        trunk.addLine(to: CGPoint(x: top.x + topHalf, y: top.y))
        trunk.addCurve(to: CGPoint(x: base.x + baseHalf, y: base.y - u * 0.06),
                       control1: CGPoint(x: top.x + topHalf * 1.1, y: top.y + u * 0.1),
                       control2: CGPoint(x: base.x + baseHalf * 0.85, y: base.y - u * 0.15))
        trunk.addQuadCurve(to: CGPoint(x: base.x + baseHalf * 1.6, y: base.y - u * 0.02), control: CGPoint(x: base.x + baseHalf * 1.05, y: base.y - u * 0.03))
        trunk.closeSubpath()
        let barkFill = GraphicsContext.Shading.linearGradient(Gradient(stops: [
            .init(color: c.bark.light, location: 0), .init(color: c.bark.mid, location: 0.45), .init(color: c.bark.dark, location: 1),
        ]), startPoint: CGPoint(x: base.x - baseHalf, y: 0), endPoint: CGPoint(x: base.x + baseHalf, y: 0))
        g.fill(trunk, with: barkFill)

        if spec.forked {
            let limbs: [(end: CGPoint, control: CGPoint)] = [
                (CGPoint(x: crownCenter.x - R * 0.62 * c.flip, y: crownCenter.y - R * 0.05), CGPoint(x: top.x - R * 0.45 * c.flip, y: top.y - R * 0.1)),
                (CGPoint(x: crownCenter.x + R * 0.05 * c.flip, y: crownCenter.y - R * 0.55), CGPoint(x: top.x - R * 0.05 * c.flip, y: top.y - R * 0.6)),
                (CGPoint(x: crownCenter.x + R * 0.58 * c.flip, y: crownCenter.y - R * 0.12), CGPoint(x: top.x + R * 0.42 * c.flip, y: top.y - R * 0.12)),
            ]
            for limb in limbs {
                var p = Path()
                p.move(to: CGPoint(x: top.x, y: top.y + u * 0.01))
                p.addQuadCurve(to: limb.end, control: limb.control)
                g.stroke(p, with: barkFill, style: StrokeStyle(lineWidth: topHalf * 1.3, lineCap: .round))
            }
        }

        guard c.detail else { return }
        var rng = SeededRandom(state: 7)
        let trunkHeight = base.y - top.y
        if c.species == .cherry {
            // Cherry bark: horizontal lenticel marks
            for i in 0..<6 {
                let y = base.y - u * 0.07 - trunkHeight * 0.75 * CGFloat(i) / 6
                let x = base.x + (top.x - base.x) * (base.y - y) / max(trunkHeight, 1) + rng.range(-baseHalf * 0.4, baseHalf * 0.3)
                var mark = Path()
                mark.move(to: CGPoint(x: x - baseHalf * 0.35, y: y))
                mark.addLine(to: CGPoint(x: x + baseHalf * 0.35, y: y))
                g.stroke(mark, with: .color(c.bark.dark.opacity(0.4)), style: StrokeStyle(lineWidth: max(0.6, u * 0.004), lineCap: .round))
            }
        } else {
            for i in 0..<5 {
                let t = CGFloat(i) / 4
                let x0 = base.x + (t - 0.5) * baseHalf * 1.2
                let y0 = base.y - u * rng.range(0.05, 0.09)
                let y1 = y0 - trunkHeight * rng.range(0.3, 0.55)
                var line = Path()
                line.move(to: CGPoint(x: x0, y: y0))
                line.addQuadCurve(to: CGPoint(x: x0 + (top.x - base.x) * 0.4, y: y1), control: CGPoint(x: x0 + rng.range(-2, 2), y: (y0 + y1) / 2))
                g.stroke(line, with: .color(c.bark.dark.opacity(0.32)), style: StrokeStyle(lineWidth: max(0.6, u * 0.004), lineCap: .round))
            }
            if c.stage >= .tree {
                let k = CGPoint(x: base.x + (top.x - base.x) * 0.55 - u * 0.006, y: base.y - trunkHeight * 0.55)
                let r = u * 0.01
                g.fill(Path(ellipseIn: CGRect(x: k.x - r * 1.3, y: k.y - r * 1.6, width: r * 2.6, height: r * 3.2)), with: .color(c.bark.light.opacity(0.35)))
                g.fill(Path(ellipseIn: CGRect(x: k.x - r * 0.7, y: k.y - r, width: r * 1.4, height: r * 2)), with: .color(c.bark.dark.opacity(0.75)))
            }
        }
    }

    private static func drawFruitClusters(_ g: inout GraphicsContext, _ c: Ctx, crownCenter: CGPoint, R: CGFloat, count: Int) {
        let all: [(x: CGFloat, y: CGFloat, n: Int)] = [(-0.72, 0.34, 2), (0.02, 0.36, 3), (0.56, 0.34, 2)]
        var rng = SeededRandom(state: c.style.seed &+ 512)
        for (ci, cluster) in all.prefix(count).enumerated() {
            let base = CGPoint(x: crownCenter.x + cluster.x * R * c.flip, y: crownCenter.y + cluster.y * R)
            let swing = CGFloat(sin(c.elapsed * 1.8 + Double(ci))) * c.u * 0.002
            let n = c.species == .cherry ? max(1, cluster.n - 1) : cluster.n
            for k in 0..<n {
                let p = CGPoint(x: base.x + (CGFloat(k) - CGFloat(n - 1) / 2) * c.u * 0.022 + swing, y: base.y + (k % 2 == 0 ? 0 : c.u * 0.008))
                fruit(&g, c, at: p, size: c.u * rng.range(0.010, 0.0125), tilt: rng.range(-0.35, 0.35))
            }
            if c.detail {
                for j in 0..<2 {
                    let a = -.pi / 2 + (j == 0 ? -0.9 : 0.8) + rng.range(-0.2, 0.2)
                    leaf(&g, c, base: CGPoint(x: base.x + (j == 0 ? -1 : 1) * c.u * 0.012, y: base.y - c.u * 0.018),
                         length: c.u * 0.042, width: c.u * 0.026, angle: a, colors: [c.leaves.mid, c.leaves.light])
                }
            }
        }
    }

    // MARK: - Pine from Bush onwards

    private struct PineSpec {
        let apexUp: CGFloat
        let height: CGFloat
        let halfWidth: CGFloat
        let tiers: Int
        let candles: Int
        let cones: Int
        let nest: Bool
        let saplings: Bool
    }

    private static func pineSpec(_ stage: PlantStage) -> PineSpec {
        switch stage {
        case .bush: PineSpec(apexUp: 0.44, height: 0.38, halfWidth: 0.21, tiers: 3, candles: 0, cones: 0, nest: false, saplings: false)
        case .floweringBush: PineSpec(apexUp: 0.48, height: 0.42, halfWidth: 0.23, tiers: 3, candles: 6, cones: 0, nest: false, saplings: false)
        case .sapling: PineSpec(apexUp: 0.60, height: 0.46, halfWidth: 0.21, tiers: 4, candles: 4, cones: 0, nest: false, saplings: false)
        case .youngTree: PineSpec(apexUp: 0.68, height: 0.56, halfWidth: 0.26, tiers: 5, candles: 0, cones: 3, nest: false, saplings: false)
        case .tree: PineSpec(apexUp: 0.73, height: 0.62, halfWidth: 0.30, tiers: 6, candles: 0, cones: 5, nest: true, saplings: false)
        default: PineSpec(apexUp: 0.76, height: 0.66, halfWidth: 0.33, tiers: 6, candles: 6, cones: 5, nest: true, saplings: true)
        }
    }

    private static func drawPineStage(_ g: inout GraphicsContext, _ c: Ctx) {
        let spec = pineSpec(c.stage)
        let apex = c.point(0, spec.apexUp)
        let bottomUp = spec.apexUp - spec.height

        if spec.saplings { drawGroveSaplings(&g, c) }
        softEllipse(&g, c, center: CGPoint(x: c.cx + c.u * 0.03 * c.flip, y: c.groundY - c.u * 0.012),
                    size: CGSize(width: c.u * spec.halfWidth * 2.1, height: c.u * 0.05), color: c.leaves.deep.opacity(0.26), blur: c.u * 0.02)

        // Straight trunk, visible below the lowest tier
        let trunkHalf = c.u * (0.012 + spec.halfWidth * 0.06)
        var trunk = Path()
        let trunkTop = c.point(0, spec.apexUp - spec.height * 0.3)
        trunk.move(to: CGPoint(x: c.cx - trunkHalf * 1.4, y: c.groundY - c.u * 0.015))
        trunk.addLine(to: CGPoint(x: trunkTop.x - trunkHalf * 0.4, y: trunkTop.y))
        trunk.addLine(to: CGPoint(x: trunkTop.x + trunkHalf * 0.4, y: trunkTop.y))
        trunk.addLine(to: CGPoint(x: c.cx + trunkHalf * 1.4, y: c.groundY - c.u * 0.015))
        trunk.closeSubpath()
        g.fill(trunk, with: .linearGradient(Gradient(colors: [c.bark.light, c.bark.mid, c.bark.dark]),
                                            startPoint: CGPoint(x: c.cx - trunkHalf, y: 0), endPoint: CGPoint(x: c.cx + trunkHalf, y: 0)))

        let droop: CGFloat = c.wilted ? 0.25 : 0
        var tierEdges: [(left: CGPoint, right: CGPoint)] = []
        // Draw from the bottom tier up, so upper tiers overlap lower ones.
        for i in stride(from: spec.tiers - 1, through: 0, by: -1) {
            let t0 = CGFloat(i) / CGFloat(spec.tiers)
            let t1 = CGFloat(i + 1) / CGFloat(spec.tiers)
            let topUp = spec.apexUp - spec.height * t0 * 0.92
            let bottomTierUp = max(bottomUp, spec.apexUp - spec.height * (t1 + 0.12))
            let halfW = c.u * spec.halfWidth * (0.32 + 0.68 * t1)
            let top = c.point(0, topUp)
            let bottomCenter = c.point(0, bottomTierUp)
            let left = CGPoint(x: bottomCenter.x - halfW, y: bottomCenter.y + halfW * (0.1 + droop))
            let right = CGPoint(x: bottomCenter.x + halfW, y: bottomCenter.y + halfW * (0.1 + droop))
            tierEdges.append((left, right))
            drawPineTier(&g, c, top: top, left: left, right: right, seed: c.style.seed &+ UInt64(i * 31 + 5))
        }

        if c.showsExtras {
            var rng = SeededRandom(state: c.style.seed &+ 88)
            for k in 0..<spec.candles {
                guard let edge = tierEdges.randomElementSeeded(&rng) else { break }
                let s = rng.next()
                let p = CGPoint(x: edge.left.x + (edge.right.x - edge.left.x) * s, y: edge.left.y - c.u * (0.02 + 0.03 * sin(.pi * s)))
                bud(&g, c, at: p, size: c.u * (k % 2 == 0 ? 0.035 : 0.028))
            }
            for k in 0..<spec.cones {
                let edge = tierEdges[(k * 2 + 1) % tierEdges.count]
                let s = 0.2 + 0.6 * CGFloat((k * 37) % 10) / 10
                let p = CGPoint(x: edge.left.x + (edge.right.x - edge.left.x) * s, y: edge.left.y - c.u * 0.01)
                fruit(&g, c, at: p, size: c.u * 0.012, tilt: CGFloat(k % 3 - 1) * 0.2)
            }
            if spec.nest, tierEdges.count > 2 {
                let edge = tierEdges[tierEdges.count / 2]
                let side = c.flip > 0 ? edge.right : edge.left
                drawNestAndBird(&g, c, at: CGPoint(x: side.x - c.u * 0.03 * c.flip, y: side.y - c.u * 0.02))
            }
        }

        signature(&g, c, at: apex, length: c.u * 0.062)
    }

    private static func drawPineTier(_ g: inout GraphicsContext, _ c: Ctx, top: CGPoint, left: CGPoint, right: CGPoint, seed: UInt64) {
        let L = c.leaves
        let scallops = 4
        var body = Path()
        body.move(to: top)
        body.addQuadCurve(to: left, control: CGPoint(x: top.x - (top.x - left.x) * 0.35, y: (top.y + left.y) / 2))
        for k in 0..<scallops {
            let t1 = CGFloat(k + 1) / CGFloat(scallops)
            let tm = (CGFloat(k) + 0.5) / CGFloat(scallops)
            let end = CGPoint(x: left.x + (right.x - left.x) * t1, y: left.y + (right.y - left.y) * t1 - (k == scallops - 1 ? 0 : 2))
            let ctrl = CGPoint(x: left.x + (right.x - left.x) * tm, y: left.y + (right.y - left.y) * tm + c.u * 0.025)
            body.addQuadCurve(to: end, control: ctrl)
        }
        body.addQuadCurve(to: top, control: CGPoint(x: top.x + (right.x - top.x) * 0.35, y: (top.y + right.y) / 2))
        body.closeSubpath()
        g.fill(body, with: .linearGradient(Gradient(stops: [
            .init(color: L.light, location: 0), .init(color: L.mid, location: 0.4), .init(color: L.deep, location: 1),
        ]), startPoint: CGPoint(x: left.x, y: top.y), endPoint: CGPoint(x: right.x, y: left.y)))

        // Needle fringe along the drooping bottom edge
        var rng = SeededRandom(state: seed)
        let fringe = c.detail ? 14 : 7
        for k in 0...fringe {
            let s = CGFloat(k) / CGFloat(fringe)
            let p = CGPoint(x: left.x + (right.x - left.x) * s, y: left.y + (right.y - left.y) * s + sin(.pi * s * CGFloat(scallops)) * c.u * 0.008)
            let flutter = c.detail ? CGFloat(sin(c.elapsed * 2.1 + Double(k))) * 0.08 : 0
            let angle = .pi / 2 + (s - 0.5) * 1.6 + rng.range(-0.2, 0.2) + flutter
            needles(&g, c, base: CGPoint(x: p.x, y: p.y - c.u * 0.012), length: c.u * rng.range(0.035, 0.05), angle: angle,
                    light: s < 0.5 ? L.light : L.mid, dark: L.dark)
        }
        guard c.detail else { return }
        // Sunlit needle tufts on the left of the tier
        for _ in 0..<3 {
            let s = rng.range(0.1, 0.55)
            let v = rng.range(0.3, 0.8)
            let p = CGPoint(x: top.x + (left.x - top.x) * v * (1 - s * 0.5) + (right.x - left.x) * s * 0.3, y: top.y + (left.y - top.y) * v)
            needles(&g, c, base: p, length: c.u * 0.022, angle: .pi / 2 + rng.range(-0.6, 0.6), light: L.light, dark: L.mid)
        }
    }

    // MARK: - Shared extras

    private static func drawGroveSaplings(_ g: inout GraphicsContext, _ c: Ctx) {
        for side: CGFloat in [-1, 1] {
            let base = CGPoint(x: c.cx + side * c.u * 0.37, y: c.groundY - c.u * 0.02)
            let top = CGPoint(x: base.x + c.sway * 0.1, y: base.y - c.u * (side < 0 ? 0.09 : 0.12))
            stem(&g, c, from: base, to: top, control: CGPoint(x: base.x - side * c.u * 0.01, y: (base.y + top.y) / 2), width: c.u * 0.009)
            if side > 0 {
                leaf(&g, c, base: CGPoint(x: base.x, y: base.y - c.u * 0.05), length: c.u * 0.04, width: c.u * 0.025,
                     angle: .pi + 0.4, colors: [c.leaves.dark, c.leaves.mid])
            }
            signature(&g, c, at: top, length: c.u * 0.045)
        }
    }

    private static func drawNestAndBird(_ g: inout GraphicsContext, _ c: Ctx, at nest: CGPoint) {
        var n = g
        n.translateBy(x: nest.x, y: nest.y)
        n.scaleBy(x: c.flip, y: 1)
        let u = c.u

        var stub = Path()
        stub.move(to: CGPoint(x: -u * 0.1, y: u * 0.04))
        stub.addQuadCurve(to: CGPoint(x: u * 0.055, y: u * 0.01), control: CGPoint(x: -u * 0.02, y: u * 0.04))
        n.stroke(stub, with: .color(c.bark.mid), style: StrokeStyle(lineWidth: u * 0.012, lineCap: .round))

        let nw = u * 0.088, nh = u * 0.042
        var bowl = Path()
        bowl.move(to: CGPoint(x: -nw / 2, y: -nh * 0.2))
        bowl.addQuadCurve(to: CGPoint(x: nw / 2, y: -nh * 0.2), control: CGPoint(x: 0, y: nh * 1.5))
        bowl.closeSubpath()
        n.fill(bowl, with: .linearGradient(Gradient(colors: [c.bark.light, c.bark.dark]),
                                           startPoint: CGPoint(x: 0, y: -nh), endPoint: CGPoint(x: 0, y: nh)))
        if c.detail {
            for i in 0..<4 {
                var twig = Path()
                let y = nh * (CGFloat(i) * 0.22 - 0.05)
                twig.move(to: CGPoint(x: -nw * 0.47, y: y))
                twig.addQuadCurve(to: CGPoint(x: nw * 0.47, y: y - nh * 0.1), control: CGPoint(x: 0, y: y + nh * 0.35))
                n.stroke(twig, with: .color(c.bark.light.opacity(0.7)), lineWidth: 0.6)
            }
        }

        let bob = CGFloat(max(0, sin(c.elapsed * 0.9))) * u * 0.006
        let body = CGPoint(x: -u * 0.004, y: -nh * 0.6 - bob)
        let br = u * 0.03
        let birdBody = Color(red: 0.45, green: 0.53, blue: 0.62)
        let birdWing = Color(red: 0.35, green: 0.42, blue: 0.51)
        let breast = Color(red: 0.86, green: 0.62, blue: 0.48)
        for (i, spread) in [-0.22, 0.0, 0.2].enumerated() {
            let angle = CGFloat.pi + 0.35 + CGFloat(spread)
            let feather = leafPath(length: br * 1.25, width: br * 0.34, lobes: 0, serration: 0, taper: 0.2)
                .applying(CGAffineTransform(translationX: body.x - br * 0.55, y: body.y - br * 0.05).rotated(by: angle))
            n.fill(feather, with: .color(i == 1 ? birdWing : birdBody))
        }
        n.fill(Path(ellipseIn: CGRect(x: body.x - br, y: body.y - br * 0.75, width: br * 2, height: br * 1.5)),
               with: .linearGradient(Gradient(colors: [birdBody, birdWing]),
                                     startPoint: CGPoint(x: body.x, y: body.y - br), endPoint: CGPoint(x: body.x, y: body.y + br)))
        n.fill(Path(ellipseIn: CGRect(x: body.x - br * 0.05, y: body.y - br * 0.25, width: br, height: br * 0.85)), with: .color(breast))
        let wing = leafPath(length: br * 1.25, width: br * 0.75, lobes: 0, serration: 0, taper: 0.2)
            .applying(CGAffineTransform(translationX: body.x + br * 0.25, y: body.y - br * 0.35).rotated(by: .pi + 0.18))
        n.fill(wing, with: .color(birdWing))
        let head = CGPoint(x: body.x + br * 0.78, y: body.y - br * 0.78)
        let hr = br * 0.55
        n.fill(Path(ellipseIn: CGRect(x: head.x - hr, y: head.y - hr, width: hr * 2, height: hr * 2)), with: .color(birdBody))
        n.fill(Path(ellipseIn: CGRect(x: head.x + hr * 0.12, y: head.y - hr * 0.38, width: hr * 0.4, height: hr * 0.4)), with: .color(Color(white: 0.1)))
        if c.detail {
            n.fill(Path(ellipseIn: CGRect(x: head.x + hr * 0.22, y: head.y - hr * 0.32, width: hr * 0.13, height: hr * 0.13)), with: .color(.white.opacity(0.9)))
        }
        var beak = Path()
        beak.move(to: CGPoint(x: head.x + hr * 0.85, y: head.y - hr * 0.12))
        beak.addLine(to: CGPoint(x: head.x + hr * 1.6, y: head.y + hr * 0.08))
        beak.addLine(to: CGPoint(x: head.x + hr * 0.85, y: head.y + hr * 0.3))
        beak.closeSubpath()
        n.fill(beak, with: .color(Color(red: 0.88, green: 0.65, blue: 0.26)))
    }
}

private extension Array {
    func randomElementSeeded(_ rng: inout GrovePlantRenderer.SeededRandom) -> Element? {
        isEmpty ? nil : self[Int(rng.next() * CGFloat(count)) % count]
    }
}
