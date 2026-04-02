import SwiftUI

/// Draws the evolving card background scene: soil, grass, plant, and flowers.
/// Simplified landscape version of PlantCanvasRenderer, optimized for semi-transparent card backgrounds.
struct CardSceneRenderer {

    // MARK: - Colors

    static let drySoil = Color(red: 0.83, green: 0.77, blue: 0.66)     // groveWarmSand-ish
    static let moistSoil = Color(red: 0.55, green: 0.42, blue: 0.30)   // Rich brown
    static let soilDark = Color(red: 0.45, green: 0.34, blue: 0.24)    // Deep layer

    static let grassGreen = Color(red: 0.48, green: 0.62, blue: 0.38)
    static let grassLight = Color(red: 0.55, green: 0.70, blue: 0.42)

    static let stemGreen = Color(red: 0.38, green: 0.52, blue: 0.30)
    static let stemLight = Color(red: 0.48, green: 0.62, blue: 0.38)

    static let leafDark = Color(red: 0.40, green: 0.54, blue: 0.34)
    static let leafMid = Color(red: 0.50, green: 0.64, blue: 0.44)
    static let leafLight = Color(red: 0.62, green: 0.76, blue: 0.55)
    static let leafHighlight = Color(red: 0.68, green: 0.82, blue: 0.62)

    static let flowerPetal = Color(red: 0.95, green: 0.85, blue: 0.90)
    static let flowerCenter = Color(red: 0.92, green: 0.78, blue: 0.35)
    static let flowerGlow = Color(red: 1.0, green: 0.84, blue: 0.0)

    static let skyWarm = Color(red: 0.98, green: 0.95, blue: 0.88)

    // MARK: - Main Draw

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        growth: CardGrowthState,
        swayOffset: CGFloat
    ) {
        let soilTop = size.height * 0.85
        let plantX = size.width * 0.72

        // 1. Subtle sky warmth (only when lush)
        if growth.lushness > 0.3 {
            drawSkyGradient(context: &context, size: size, lushness: growth.lushness)
        }

        // 2. Soil band across full width
        drawSoil(context: &context, size: size, soilTop: soilTop, moisture: growth.soilMoisture)

        // 3. Grass tufts
        if growth.grassDensity > 0 {
            drawGrass(context: &context, size: size, soilTop: soilTop, density: growth.grassDensity, swayOffset: swayOffset)
        }

        // 4. Plant
        if growth.plantStage > 0 {
            drawPlant(
                context: &context, size: size,
                soilTop: soilTop, plantX: plantX,
                stage: growth.plantStage,
                bloomProgress: growth.bloomProgress,
                swayOffset: swayOffset
            )
        }
    }

    // MARK: - Sky

    private static func drawSkyGradient(context: inout GraphicsContext, size: CGSize, lushness: CGFloat) {
        let opacity = (lushness - 0.3) / 0.7 * 0.08 // max 8% opacity
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [skyWarm.opacity(opacity), Color.clear]),
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height * 0.6)
            )
        )
    }

    // MARK: - Soil

    private static func drawSoil(
        context: inout GraphicsContext,
        size: CGSize,
        soilTop: CGFloat,
        moisture: CGFloat
    ) {
        // Interpolate soil color based on moisture
        let topColor = interpolateColor(from: drySoil, to: moistSoil, t: moisture)
        let bottomColor = interpolateColor(from: drySoil.opacity(0.7), to: soilDark, t: moisture)

        // Full-width soil with gentle curve at top
        var soilPath = Path()
        soilPath.move(to: CGPoint(x: 0, y: soilTop + 4))
        soilPath.addQuadCurve(
            to: CGPoint(x: size.width, y: soilTop + 4),
            control: CGPoint(x: size.width * 0.5, y: soilTop - 3)
        )
        soilPath.addLine(to: CGPoint(x: size.width, y: size.height))
        soilPath.addLine(to: CGPoint(x: 0, y: size.height))
        soilPath.closeSubpath()

        context.fill(soilPath, with: .linearGradient(
            Gradient(colors: [topColor, bottomColor]),
            startPoint: CGPoint(x: size.width / 2, y: soilTop),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))

        // Subtle top edge highlight
        var edgePath = Path()
        edgePath.move(to: CGPoint(x: 0, y: soilTop + 4))
        edgePath.addQuadCurve(
            to: CGPoint(x: size.width, y: soilTop + 4),
            control: CGPoint(x: size.width * 0.5, y: soilTop - 3)
        )
        context.stroke(edgePath, with: .color(topColor.opacity(0.5)), lineWidth: 0.8)

        // Moisture droplets scattered on soil surface when wet
        if moisture > 0.5 {
            let dropOpacity = (moisture - 0.5) * 0.3
            let positions: [CGFloat] = [0.15, 0.35, 0.55, 0.8]
            for px in positions {
                let x = size.width * px
                let y = soilTop + 6 + CGFloat.random(in: 0...4)
                let r: CGFloat = 1.2
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.blue.opacity(dropOpacity)))
            }
        }
    }

    // MARK: - Grass

    private static func drawGrass(
        context: inout GraphicsContext,
        size: CGSize,
        soilTop: CGFloat,
        density: Int,
        swayOffset: CGFloat
    ) {
        // Distribute grass tufts across the card width
        let positions: [(x: CGFloat, lean: CGFloat)] = [
            (0.08, -0.3), (0.22, 0.2), (0.38, -0.15),
            (0.55, 0.35), (0.78, -0.2), (0.92, 0.25)
        ]

        for i in 0..<min(density, positions.count) {
            let pos = positions[i]
            let baseX = size.width * pos.x
            let baseY = soilTop + 2
            let height = size.height * 0.035

            // Add subtle sway to grass
            let grassSway = swayOffset * 0.02
            drawGrassTuft(
                context: &context,
                baseX: baseX, baseY: baseY,
                height: height,
                lean: pos.lean + grassSway
            )
        }
    }

    private static func drawGrassTuft(
        context: inout GraphicsContext,
        baseX: CGFloat, baseY: CGFloat,
        height: CGFloat, lean: CGFloat
    ) {
        let blades: [(dx: CGFloat, curveDx: CGFloat)] = [
            (-1.5, -2.5 + lean * 3),
            (0.5, 0.5 + lean * 2),
            (2, 3.5 + lean * 3),
        ]
        for (i, b) in blades.enumerated() {
            var blade = Path()
            blade.move(to: CGPoint(x: baseX + b.dx, y: baseY))
            blade.addQuadCurve(
                to: CGPoint(x: baseX + b.dx + b.curveDx, y: baseY - height * (0.8 + CGFloat(i) * 0.1)),
                control: CGPoint(x: baseX + b.dx + b.curveDx * 0.4, y: baseY - height * 0.5)
            )
            let c = i == 1 ? grassLight : grassGreen
            context.stroke(blade, with: .color(c), lineWidth: 0.7)
        }
    }

    // MARK: - Plant

    private static func drawPlant(
        context: inout GraphicsContext,
        size: CGSize,
        soilTop: CGFloat,
        plantX: CGFloat,
        stage: CGFloat,
        bloomProgress: CGFloat,
        swayOffset: CGFloat
    ) {
        let stemBase = CGPoint(x: plantX, y: soilTop + 2)

        if stage <= 1.0 {
            // Tiny sprout: single stem + 2 cotyledon leaves
            drawSprout(context: &context, size: size, base: stemBase, progress: stage, swayOffset: swayOffset)
        } else if stage <= 2.5 {
            // Seedling: taller stem, more leaves
            let t = (stage - 1.0) / 1.5 // 0→1 within this stage
            drawSeedling(context: &context, size: size, base: stemBase, progress: t, swayOffset: swayOffset)
        } else {
            // Bush: branching, dense foliage, possible flowers
            let t = (stage - 2.5) / 1.5 // 0→1 within this stage
            drawBush(context: &context, size: size, base: stemBase, progress: t, bloomProgress: bloomProgress, swayOffset: swayOffset)
        }
    }

    // MARK: Sprout (stage 0-1)

    private static func drawSprout(
        context: inout GraphicsContext,
        size: CGSize,
        base: CGPoint,
        progress: CGFloat,
        swayOffset: CGFloat
    ) {
        let stemH = size.height * 0.08 * progress
        guard stemH > 0 else { return }

        let topSway = swayForHeight(1.0, swayOffset, scale: 1.5)
        let stemTop = CGPoint(x: base.x + topSway, y: base.y - stemH)

        // Stem
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(
            to: stemTop,
            control: CGPoint(x: base.x + topSway * 0.5, y: base.y - stemH * 0.5)
        )
        context.stroke(stem, with: .linearGradient(
            Gradient(colors: [stemGreen, stemLight]),
            startPoint: base, endPoint: stemTop
        ), lineWidth: 1.5)

        // Cotyledon leaves (appear as progress → 1)
        if progress > 0.3 {
            let leafProgress = (progress - 0.3) / 0.7
            let leafLen = size.width * 0.04 * leafProgress
            let leafSway = swayOffset * 0.03

            drawLeaf(context: &context, origin: stemTop, length: leafLen,
                     angle: -.pi / 3 + leafSway, width: leafLen * 0.45, shade: 0)
            drawLeaf(context: &context, origin: stemTop, length: leafLen,
                     angle: .pi + .pi / 3 + leafSway, width: leafLen * 0.45, shade: 1)
        }
    }

    // MARK: Seedling (stage 1-2.5)

    private static func drawSeedling(
        context: inout GraphicsContext,
        size: CGSize,
        base: CGPoint,
        progress: CGFloat,
        swayOffset: CGFloat
    ) {
        let stemH = size.height * (0.08 + 0.08 * progress)
        let topSway = swayForHeight(1.0, swayOffset, scale: 2.0)
        let midSway = swayForHeight(0.5, swayOffset, scale: 2.0)
        let stemTop = CGPoint(x: base.x + topSway, y: base.y - stemH)

        // S-curved stem
        let ctrl1 = CGPoint(x: base.x - 2 + midSway * 0.3, y: base.y - stemH * 0.3)
        let ctrl2 = CGPoint(x: base.x + 3 + topSway * 0.7, y: base.y - stemH * 0.7)

        var stem = Path()
        stem.move(to: base)
        stem.addCurve(to: stemTop, control1: ctrl1, control2: ctrl2)
        context.stroke(stem, with: .linearGradient(
            Gradient(colors: [stemGreen, stemLight]),
            startPoint: base, endPoint: stemTop
        ), lineWidth: 1.8)

        // Leaves along stem (2-6 based on progress)
        let leafCount = 2 + Int(progress * 4)
        let leafSway = swayOffset * 0.04
        let baseLeafLen = size.width * 0.035

        for i in 0..<leafCount {
            let t = CGFloat(i + 1) / CGFloat(leafCount + 1) * 0.85 + 0.1
            let pt = cubicBezierPoint(from: base, to: stemTop, control1: ctrl1, control2: ctrl2, t: t)
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            let angle = side * (.pi / 3 + CGFloat(i) * 0.08) + leafSway
            let len = baseLeafLen * (0.7 + t * 0.5)
            drawLeaf(context: &context, origin: pt, length: len, angle: angle, width: len * 0.4, shade: i % 3)
        }

        // Top bud
        drawBud(context: &context, at: stemTop, size: size.width * 0.012, swayOffset: swayOffset)
    }

    // MARK: Bush (stage 2.5-4)

    private static func drawBush(
        context: inout GraphicsContext,
        size: CGSize,
        base: CGPoint,
        progress: CGFloat,
        bloomProgress: CGFloat,
        swayOffset: CGFloat
    ) {
        let stemH = size.height * (0.16 + 0.06 * progress)
        let topSway = swayForHeight(1.0, swayOffset, scale: 2.2)
        let midSway = swayForHeight(0.5, swayOffset, scale: 2.2)
        let stemTop = CGPoint(x: base.x + topSway, y: base.y - stemH)

        // Main stem (thicker)
        let ctrl1 = CGPoint(x: base.x - 3 + midSway * 0.3, y: base.y - stemH * 0.3)
        let ctrl2 = CGPoint(x: base.x + 4 + topSway * 0.7, y: base.y - stemH * 0.7)

        drawTaperedStem(context: &context, from: base, to: stemTop,
                        control1: ctrl1, control2: ctrl2,
                        baseWidth: 3.5, topWidth: 1.5)

        // Branches
        let branchCount = 2 + Int(progress * 2)
        let branchDefs: [(t: CGFloat, angle: CGFloat, lenFactor: CGFloat)] = [
            (0.45, -.pi / 4, 0.5),
            (0.55, .pi / 3.5, 0.6),
            (0.7, -.pi / 3, 0.55),
            (0.8, .pi / 4, 0.45),
        ]

        var branchEnds: [CGPoint] = []

        for i in 0..<min(branchCount, branchDefs.count) {
            let def = branchDefs[i]
            let branchStart = cubicBezierPoint(from: base, to: stemTop, control1: ctrl1, control2: ctrl2, t: def.t)
            let branchSway = swayForHeight(def.t, swayOffset, scale: 1.8, phase: CGFloat(i))
            let branchLen = stemH * def.lenFactor * 0.5
            let branchEnd = CGPoint(
                x: branchStart.x + cos(def.angle) * branchLen + branchSway,
                y: branchStart.y + sin(def.angle) * branchLen
            )

            // Draw branch
            var branch = Path()
            branch.move(to: branchStart)
            branch.addQuadCurve(
                to: branchEnd,
                control: CGPoint(
                    x: (branchStart.x + branchEnd.x) / 2,
                    y: min(branchStart.y, branchEnd.y) - 3
                )
            )
            context.stroke(branch, with: .color(stemGreen.opacity(0.8)), lineWidth: 1.2)
            branchEnds.append(branchEnd)

            // Leaves at branch end (cluster of 3-4)
            let leafSway = swayOffset * 0.05
            let leafLen = size.width * 0.03
            for j in 0..<(3 + (i % 2)) {
                let angle = def.angle + CGFloat(j - 1) * 0.5 + leafSway
                drawLeaf(context: &context, origin: branchEnd, length: leafLen,
                         angle: angle, width: leafLen * 0.4, shade: (i + j) % 3)
            }
        }

        // Main stem leaves
        let stemLeafCount = 4 + Int(progress * 3)
        let leafSway = swayOffset * 0.04
        for i in 0..<stemLeafCount {
            let t = CGFloat(i + 1) / CGFloat(stemLeafCount + 1) * 0.8 + 0.1
            let pt = cubicBezierPoint(from: base, to: stemTop, control1: ctrl1, control2: ctrl2, t: t)
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            let angle = side * (.pi / 3 + CGFloat(i) * 0.06) + leafSway
            let len = size.width * 0.028 * (0.6 + t * 0.5)
            drawLeaf(context: &context, origin: pt, length: len, angle: angle, width: len * 0.4, shade: i % 3)
        }

        // Top crown leaves
        let crownLeafLen = size.width * 0.035
        for i in 0..<3 {
            let angle = CGFloat(i - 1) * 0.6 + swayOffset * 0.04
            drawLeaf(context: &context, origin: stemTop, length: crownLeafLen,
                     angle: angle - .pi / 2, width: crownLeafLen * 0.4, shade: i)
        }

        // Flowers (based on bloomProgress)
        if bloomProgress > 0 {
            drawFlowers(context: &context, stemTop: stemTop, branchEnds: branchEnds,
                        bloomProgress: bloomProgress, swayOffset: swayOffset)
        }
    }

    // MARK: - Drawing Helpers

    private static func drawLeaf(
        context: inout GraphicsContext,
        origin: CGPoint,
        length: CGFloat,
        angle: CGFloat,
        width: CGFloat,
        shade: Int
    ) {
        let tip = CGPoint(
            x: origin.x + cos(angle) * length,
            y: origin.y + sin(angle) * length
        )

        // Teardrop shape: widest at 30% from base
        let wideT: CGFloat = 0.3
        let midX = origin.x + cos(angle) * length * wideT
        let midY = origin.y + sin(angle) * length * wideT

        let perpAngle = angle + .pi / 2
        let halfW = width / 2

        let left = CGPoint(x: midX + cos(perpAngle) * halfW, y: midY + sin(perpAngle) * halfW)
        let right = CGPoint(x: midX - cos(perpAngle) * halfW, y: midY - sin(perpAngle) * halfW)

        var path = Path()
        path.move(to: origin)
        path.addQuadCurve(to: tip, control: left)
        path.addQuadCurve(to: origin, control: right)
        path.closeSubpath()

        let colors: [Color] = shade == 0 ? [leafDark, leafMid] : shade == 1 ? [leafMid, leafLight] : [leafLight, leafHighlight]
        context.fill(path, with: .linearGradient(
            Gradient(colors: colors),
            startPoint: origin, endPoint: tip
        ))
    }

    private static func drawBud(context: inout GraphicsContext, at point: CGPoint, size: CGFloat, swayOffset: CGFloat) {
        let budSway = swayOffset * 0.02
        let tip = CGPoint(x: point.x + budSway, y: point.y - size * 3)

        var bud = Path()
        bud.move(to: point)
        bud.addCurve(
            to: tip,
            control1: CGPoint(x: point.x + size * 1.5, y: point.y - size),
            control2: CGPoint(x: point.x + size, y: point.y - size * 2.5)
        )
        bud.addCurve(
            to: point,
            control1: CGPoint(x: point.x - size * 0.5, y: point.y - size * 2),
            control2: CGPoint(x: point.x - size * 0.3, y: point.y - size * 0.8)
        )
        bud.closeSubpath()
        context.fill(bud, with: .linearGradient(
            Gradient(colors: [leafMid, leafHighlight]),
            startPoint: point, endPoint: tip
        ))
    }

    private static func drawTaperedStem(
        context: inout GraphicsContext,
        from base: CGPoint, to top: CGPoint,
        control1: CGPoint, control2: CGPoint,
        baseWidth: CGFloat, topWidth: CGFloat
    ) {
        let steps = 12
        var leftPts: [CGPoint] = []
        var rightPts: [CGPoint] = []

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pt = cubicBezierPoint(from: base, to: top, control1: control1, control2: control2, t: t)
            let t2 = min(t + 0.01, 1.0)
            let pt2 = cubicBezierPoint(from: base, to: top, control1: control1, control2: control2, t: t2)
            let dx = pt2.x - pt.x, dy = pt2.y - pt.y
            let len = sqrt(dx * dx + dy * dy)
            guard len > 0 else { continue }
            let nx = -dy / len, ny = dx / len
            let w = (baseWidth + (topWidth - baseWidth) * t) / 2
            leftPts.append(CGPoint(x: pt.x + nx * w, y: pt.y + ny * w))
            rightPts.append(CGPoint(x: pt.x - nx * w, y: pt.y - ny * w))
        }

        var path = Path()
        guard let first = leftPts.first else { return }
        path.move(to: first)
        for pt in leftPts.dropFirst() { path.addLine(to: pt) }
        for pt in rightPts.reversed() { path.addLine(to: pt) }
        path.closeSubpath()

        context.fill(path, with: .linearGradient(
            Gradient(colors: [stemGreen, stemLight]),
            startPoint: base, endPoint: top
        ))
    }

    private static func drawFlowers(
        context: inout GraphicsContext,
        stemTop: CGPoint,
        branchEnds: [CGPoint],
        bloomProgress: CGFloat,
        swayOffset: CGFloat
    ) {
        // Flower positions: at stem top and branch ends
        var flowerPositions: [CGPoint] = [stemTop]
        flowerPositions.append(contentsOf: branchEnds)

        let maxFlowers = bloomProgress >= 1.0 ? min(flowerPositions.count, 5) : min(Int(bloomProgress * 3) + 1, flowerPositions.count)

        for i in 0..<maxFlowers {
            let pos = flowerPositions[i]
            let radius: CGFloat = 4.0 + bloomProgress * 2.0

            // Golden glow behind flower
            if bloomProgress > 0.5 {
                let glowR = radius * 2.5
                let glowRect = CGRect(x: pos.x - glowR, y: pos.y - glowR, width: glowR * 2, height: glowR * 2)
                context.fill(Path(ellipseIn: glowRect), with: .color(flowerGlow.opacity(0.08 * bloomProgress)))
            }

            // 5-petal flower
            let petalR = radius * 0.55
            for j in 0..<5 {
                let angle = CGFloat(j) * (.pi * 2 / 5) - .pi / 2 + swayOffset * 0.02
                let px = pos.x + cos(angle) * radius * 0.6
                let py = pos.y + sin(angle) * radius * 0.6
                let rect = CGRect(x: px - petalR, y: py - petalR, width: petalR * 2, height: petalR * 2)
                context.fill(Path(ellipseIn: rect), with: .color(flowerPetal))
            }

            // Center
            let cr = radius * 0.3
            let centerRect = CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)
            context.fill(Path(ellipseIn: centerRect), with: .color(flowerCenter))
        }
    }

    // MARK: - Math Helpers

    static func swayForHeight(_ h: CGFloat, _ swayOffset: CGFloat, scale: CGFloat = 1.0, phase: CGFloat = 0) -> CGFloat {
        let clamped = max(0, min(h, 1))
        let flex = clamped * clamped
        let phased = phase == 0 ? swayOffset : swayOffset * cos(phase * 0.15)
        return flex * phased * scale
    }

    static func quadBezierPoint(from: CGPoint, to: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        let omt = 1 - t
        return CGPoint(
            x: omt * omt * from.x + 2 * omt * t * control.x + t * t * to.x,
            y: omt * omt * from.y + 2 * omt * t * control.y + t * t * to.y
        )
    }

    static func cubicBezierPoint(from: CGPoint, to: CGPoint, control1: CGPoint, control2: CGPoint, t: CGFloat) -> CGPoint {
        let omt = 1 - t
        let omt2 = omt * omt
        let omt3 = omt2 * omt
        let t2 = t * t
        let t3 = t2 * t
        return CGPoint(
            x: omt3 * from.x + 3 * omt2 * t * control1.x + 3 * omt * t2 * control2.x + t3 * to.x,
            y: omt3 * from.y + 3 * omt2 * t * control1.y + 3 * omt * t2 * control2.y + t3 * to.y
        )
    }

    /// Linearly interpolate between two colors (approximation using resolved values not needed for Canvas)
    private static func interpolateColor(from: Color, to: Color, t: CGFloat) -> Color {
        // Since we can't resolve Color components directly, use opacity blending
        // Draw `from` at (1-t) opacity and `to` at t opacity for visual interpolation
        // For Canvas we'll use the `to` color with the interpolated factor
        return t < 0.5 ? from.opacity(1.0 - t * 0.5) : to.opacity(0.5 + t * 0.5)
    }
}
