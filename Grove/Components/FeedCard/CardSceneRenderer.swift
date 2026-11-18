import SwiftUI

/// Draws the evolving card background scene: soil, grass, plant, and flowers.
/// Simplified landscape plant scene, optimized for semi-transparent card backgrounds.
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
        swayOffset: CGFloat,
        soilPosition: CGFloat = 0.85
    ) {
        let soilTop = size.height * soilPosition
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

    // MARK: - Planted Seed (no interactions yet)

    /// The starting scene before anyone interacts: a soil band with a seed and a tiny
    /// shoot where the plant will grow (same spot as `draw` puts it).
    static func drawPlantedSeed(
        context: inout GraphicsContext,
        size: CGSize,
        soilPosition: CGFloat = 0.85
    ) {
        let soilTop = size.height * soilPosition
        let plantX = size.width * 0.72
        drawSoil(context: &context, size: size, soilTop: soilTop, moisture: 0.5)

        // Seed resting just in the soil
        let seedY = soilTop + 2
        let seedRect = CGRect(x: plantX - 8, y: seedY - 5.5, width: 16, height: 11)
        context.fill(Path(ellipseIn: seedRect), with: .color(Color(red: 0.62, green: 0.48, blue: 0.33)))
        context.stroke(Path(ellipseIn: seedRect), with: .color(soilDark.opacity(0.6)), lineWidth: 0.8)

        // A curled shoot just breaking out of the seed
        var shoot = Path()
        shoot.move(to: CGPoint(x: plantX, y: seedY - 5))
        shoot.addQuadCurve(to: CGPoint(x: plantX + 7, y: seedY - 13),
                           control: CGPoint(x: plantX + 0.5, y: seedY - 13.5))
        context.stroke(shoot, with: .color(stemLight), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        // First leaf
        var leaf = Path()
        leaf.move(to: CGPoint(x: plantX + 7, y: seedY - 13))
        leaf.addQuadCurve(to: CGPoint(x: plantX + 15, y: seedY - 15),
                          control: CGPoint(x: plantX + 11, y: seedY - 19))
        leaf.addQuadCurve(to: CGPoint(x: plantX + 7, y: seedY - 13),
                          control: CGPoint(x: plantX + 12, y: seedY - 12))
        context.fill(leaf, with: .color(leafMid))
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

    // Shapes follow the streak plant: broad paired leaves, a rounded canopy, and small
    // terracotta / gold / blush flowers. Sizes scale with the scene's height.

    // MARK: Sprout (stage 0-1)

    private static func drawSprout(
        context: inout GraphicsContext,
        size: CGSize,
        base: CGPoint,
        progress: CGFloat,
        swayOffset: CGFloat
    ) {
        let unit = min(size.height, size.width * 0.9)
        let stemH = unit * (0.12 + 0.08 * progress)
        let topSway = swayForHeight(1.0, swayOffset, scale: 1.5)
        let stemTop = CGPoint(x: base.x + topSway, y: base.y - stemH)

        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: stemTop, control: CGPoint(x: base.x - 1 + topSway * 0.5, y: base.y - stemH * 0.5))
        context.stroke(stem, with: .color(stemGreen), style: StrokeStyle(lineWidth: max(2, unit * 0.022), lineCap: .round))

        // Two broad seed leaves opening at the top
        let leafLen = unit * (0.09 + 0.05 * progress)
        let sway = swayOffset * 0.03
        drawLeaf(context: &context, origin: stemTop, length: leafLen, angle: -.pi * 0.85 + sway, width: leafLen * 0.8, shade: 0)
        drawLeaf(context: &context, origin: stemTop, length: leafLen, angle: -.pi * 0.18 + sway, width: leafLen * 0.8, shade: 1)
    }

    // MARK: Young plant (stage 1-2.5)

    private static func drawSeedling(
        context: inout GraphicsContext,
        size: CGSize,
        base: CGPoint,
        progress: CGFloat,
        swayOffset: CGFloat
    ) {
        let unit = min(size.height, size.width * 0.9)
        let stemH = unit * (0.24 + 0.14 * progress)
        let topSway = swayForHeight(1.0, swayOffset, scale: 2.0)
        let stemTop = CGPoint(x: base.x + topSway, y: base.y - stemH)
        let ctrl1 = CGPoint(x: base.x - unit * 0.025, y: base.y - stemH * 0.35)
        let ctrl2 = CGPoint(x: base.x + unit * 0.02 + topSway * 0.7, y: base.y - stemH * 0.7)

        drawTaperedStem(context: &context, from: base, to: stemTop, control1: ctrl1, control2: ctrl2,
                        baseWidth: max(2.5, unit * 0.03), topWidth: max(1.5, unit * 0.015))

        // A few broad leaves, alternating sides, largest at the bottom
        let leafCount = 3 + Int((progress * 1).rounded())
        let sway = swayOffset * 0.04
        for i in 0..<leafCount {
            let t = 0.3 + CGFloat(i) / CGFloat(leafCount) * 0.6
            let pt = cubicBezierPoint(from: base, to: stemTop, control1: ctrl1, control2: ctrl2, t: t)
            let len = unit * (0.17 - CGFloat(i) * 0.02)
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            drawLeaf(context: &context, origin: pt, length: len, angle: -.pi / 2 + side * 1.0 + sway,
                     width: len * 0.8, shade: i % 3)
        }

        // Fresh top pair
        let topLen = unit * 0.1
        drawLeaf(context: &context, origin: stemTop, length: topLen, angle: -.pi / 2 - 0.55 + sway, width: topLen * 0.75, shade: 2)
        drawLeaf(context: &context, origin: stemTop, length: topLen, angle: -.pi / 2 + 0.5 + sway, width: topLen * 0.75, shade: 1)
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
        let unit = min(size.height, size.width * 0.9)
        let scale = 0.8 + 0.2 * progress
        let trunkH = unit * 0.24 * scale
        let sway = swayForHeight(1.0, swayOffset, scale: 1.4)
        let crown = CGPoint(x: base.x + sway, y: base.y - trunkH)

        // Trunk with two short limbs
        let bark = Color(red: 0.43, green: 0.32, blue: 0.25)
        var trunk = Path()
        trunk.move(to: base)
        trunk.addQuadCurve(to: crown, control: CGPoint(x: base.x - unit * 0.01, y: base.y - trunkH * 0.5))
        trunk.move(to: CGPoint(x: base.x, y: base.y - trunkH * 0.5))
        trunk.addLine(to: CGPoint(x: base.x - unit * 0.11 + sway * 0.6, y: base.y - trunkH * 0.95))
        trunk.move(to: CGPoint(x: base.x, y: base.y - trunkH * 0.6))
        trunk.addLine(to: CGPoint(x: base.x + unit * 0.12 + sway * 0.6, y: base.y - trunkH * 1.05))
        context.stroke(trunk, with: .color(bark), style: StrokeStyle(lineWidth: max(2.5, unit * 0.03), lineCap: .round))

        // Rounded canopy of overlapping leaf masses (darker behind, lighter in front)
        let r = unit * 0.17 * scale
        let blobs: [(dx: CGFloat, dy: CGFloat, rr: CGFloat, color: Color)] = [
            (0, -0.25, 1.0, leafDark),
            (-0.75, 0.25, 0.7, leafMid),
            (0.8, 0.2, 0.75, leafMid),
            (-0.15, -0.75, 0.62, leafLight),
            (0.45, -0.45, 0.5, leafHighlight),
        ]
        var flowerSpots: [CGPoint] = []
        for blob in blobs.prefix(progress > 0.4 ? 5 : 4) {
            let c = CGPoint(x: crown.x + blob.dx * r, y: crown.y + blob.dy * r)
            let rr = r * blob.rr
            context.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(blob.color))
            flowerSpots.append(CGPoint(x: c.x - rr * 0.25, y: c.y - rr * 0.35))
        }

        if bloomProgress > 0 {
            drawFlowers(context: &context, stemTop: flowerSpots[0], branchEnds: Array(flowerSpots.dropFirst()),
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
        let spots = [stemTop] + branchEnds
        // Half bloom: a few flowers; full bloom: one on every leaf mass.
        let count = bloomProgress >= 1.0 ? spots.count : max(2, spots.count / 2)
        let palette: [Color] = [
            Color(red: 0.77, green: 0.47, blue: 0.36),  // terracotta
            Color(red: 0.91, green: 0.78, blue: 0.48),  // gold
            flowerPetal,                                 // blush
        ]
        for (i, pos) in spots.prefix(count).enumerated() {
            let radius: CGFloat = 3.2 + bloomProgress * 1.2
            let petal = palette[i % palette.count]
            let petalR = radius * 0.55
            for j in 0..<5 {
                let angle = CGFloat(j) * (.pi * 2 / 5) - .pi / 2 + swayOffset * 0.02
                let px = pos.x + cos(angle) * radius * 0.6
                let py = pos.y + sin(angle) * radius * 0.6
                context.fill(Path(ellipseIn: CGRect(x: px - petalR, y: py - petalR, width: petalR * 2, height: petalR * 2)),
                             with: .color(petal))
            }
            let cr = radius * 0.32
            context.fill(Path(ellipseIn: CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)),
                         with: .color(flowerCenter))
        }
    }

    // MARK: - Sunlight Rays

    static func drawSunlightRays(
        context: inout GraphicsContext,
        size: CGSize,
        bloomProgress: CGFloat,
        swayOffset: CGFloat
    ) {
        let sourceX = size.width + 10   // just beyond top-right corner
        let sourceY: CGFloat = -10
        let rayCount = 5
        let rayLength = max(size.width, size.height) * 1.3
        let baseColor = Color(red: 1.0, green: 0.84, blue: 0.0)

        // Rays fan downward-left from the top-right corner
        let startAngle: CGFloat = .pi * 0.55   // slightly past straight down
        let endAngle: CGFloat = .pi * 0.85      // toward bottom-left

        for i in 0..<rayCount {
            let t = CGFloat(i) / CGFloat(rayCount - 1) // 0 to 1
            let angle = startAngle + (endAngle - startAngle) * t

            // Gentle wobble synced to sway
            let wobble = swayOffset * 0.003 * (t - 0.5)
            let effectiveAngle = angle + wobble

            let tipX = sourceX + cos(effectiveAngle) * rayLength
            let tipY = sourceY + sin(effectiveAngle) * rayLength

            // Tapered triangle: wider at base, pointed at tip
            let halfWidth: CGFloat = 6 + bloomProgress * 4
            let perpAngle = effectiveAngle + .pi / 2

            let leftBase = CGPoint(
                x: sourceX + cos(perpAngle) * halfWidth,
                y: sourceY + sin(perpAngle) * halfWidth
            )
            let rightBase = CGPoint(
                x: sourceX - cos(perpAngle) * halfWidth,
                y: sourceY - sin(perpAngle) * halfWidth
            )
            let tip = CGPoint(x: tipX, y: tipY)

            var rayPath = Path()
            rayPath.move(to: leftBase)
            rayPath.addLine(to: tip)
            rayPath.addLine(to: rightBase)
            rayPath.closeSubpath()

            let opacity = 0.06 + bloomProgress * 0.06 // 6-12% opacity
            context.fill(rayPath, with: .linearGradient(
                Gradient(colors: [baseColor.opacity(opacity), Color.clear]),
                startPoint: CGPoint(x: sourceX, y: sourceY),
                endPoint: tip
            ))
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
