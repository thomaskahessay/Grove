import SwiftUI

struct PlantCanvasRenderer {

    // MARK: - Colors

    static let leafGreen = Color.groveSage
    static let leafDark = Color(red: 0.40, green: 0.54, blue: 0.34)
    static let leafMid = Color(red: 0.50, green: 0.64, blue: 0.44)
    static let leafLight = Color(red: 0.62, green: 0.76, blue: 0.55)
    static let leafHighlight = Color(red: 0.68, green: 0.82, blue: 0.62)
    static let trunkBrown = Color.groveTerracotta
    static let trunkDark = Color(red: 0.50, green: 0.30, blue: 0.20)
    static let trunkMid = Color(red: 0.65, green: 0.42, blue: 0.30)
    static let trunkLight = Color(red: 0.80, green: 0.58, blue: 0.45)
    static let soilColor = Color.groveWarmSand
    static let soilDark = Color(red: 0.68, green: 0.58, blue: 0.45)
    static let soilRich = Color(red: 0.58, green: 0.48, blue: 0.36)
    static let wiltedLeaf = Color(red: 0.72, green: 0.65, blue: 0.50)
    static let wiltedTrunk = Color(red: 0.68, green: 0.58, blue: 0.46)
    static let wiltedTip = Color(red: 0.52, green: 0.40, blue: 0.28)
    static let flowerPetal = Color(red: 0.95, green: 0.85, blue: 0.90)
    static let flowerCenter = Color(red: 0.92, green: 0.78, blue: 0.35)
    static let fruitColor = Color(red: 0.85, green: 0.40, blue: 0.30)
    static let fruitHighlight = Color(red: 0.95, green: 0.55, blue: 0.40)
    static let shadowColor = Color.black.opacity(0.06)
    static let grassColor = Color(red: 0.48, green: 0.62, blue: 0.38)
    static let grassLight = Color(red: 0.55, green: 0.70, blue: 0.42)
    static let seedGlow = Color.groveWarmSand.opacity(0.2)
    static let groveGlow = Color(red: 0.95, green: 0.88, blue: 0.55)
    static let birdColor = Color(red: 0.35, green: 0.30, blue: 0.28)
    static let atmosphereWarm = Color(red: 0.98, green: 0.88, blue: 0.62)
    static let atmosphereCool = Color(red: 0.80, green: 0.93, blue: 0.82)
    static let moteColor = Color(red: 1.0, green: 0.98, blue: 0.88)

    // MARK: - Sway Physics

    /// Returns horizontal displacement for a given normalized height (0=ground, 1=top).
    /// Uses quadratic easing so the base stays firmly planted and flex increases naturally upward.
    /// `phase` adds a slight wave delay for organic motion (leaves trail behind trunk).
    static func swayForHeight(_ h: CGFloat, _ swayOffset: CGFloat, scale: CGFloat = 1.0, phase: CGFloat = 0) -> CGFloat {
        let clamped = max(0, min(h, 1))
        // Quadratic ease: 0 at ground, full at top
        let flex = clamped * clamped
        // Optional phase offset for wave-like motion (not used for trunk, used for leaves/branches)
        let phased = phase == 0 ? swayOffset : swayOffset * cos(phase * 0.15)
        return flex * phased * scale
    }

    /// Computes normalized height given a y position relative to ground
    static func normalizedHeight(y: CGFloat, groundY: CGFloat, totalHeight: CGFloat) -> CGFloat {
        guard totalHeight > 0 else { return 0 }
        return max(0, min((groundY - y) / totalHeight, 1))
    }

    // MARK: - Main Draw

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        stage: PlantStage,
        isWilted: Bool,
        swayOffset: CGFloat,
        growthProgress: CGFloat,
        elapsedTime: TimeInterval,
        bloomPulse: CGFloat,
        lightPhase: CGFloat
    ) {
        let groundY = size.height * 0.85

        if stage.showsSoil {
            drawSoil(context: &context, size: size, groundY: groundY)
        }

        drawAtmosphere(
            context: &context,
            size: size,
            groundY: groundY,
            stage: stage,
            isWilted: isWilted,
            elapsedTime: elapsedTime,
            bloomPulse: bloomPulse,
            lightPhase: lightPhase
        )

        switch stage {
        case .seed:
            drawSeed(context: &context, size: size, groundY: groundY, isWilted: isWilted)
        case .sprout:
            drawSprout(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .seedling:
            drawSeedling(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .youngPlant:
            drawYoungPlant(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .bush:
            drawBush(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .floweringBush:
            drawFloweringBush(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .sapling:
            drawSapling(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .youngTree:
            drawYoungTree(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .tree:
            drawTree(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .groveTree:
            drawGroveTree(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        }

        drawFloatingMotes(
            context: &context,
            size: size,
            groundY: groundY,
            stage: stage,
            isWilted: isWilted,
            elapsedTime: elapsedTime,
            lightPhase: lightPhase,
            foreground: true
        )
    }

    // MARK: - Soil

    static func drawSoil(context: inout GraphicsContext, size: CGSize, groundY: CGFloat) {
        let cx = size.width / 2
        let soilW = size.width * 0.3

        // Bottom rich layer
        var bottomPath = Path()
        bottomPath.move(to: CGPoint(x: cx - soilW, y: groundY + 1))
        bottomPath.addQuadCurve(
            to: CGPoint(x: cx + soilW, y: groundY + 1),
            control: CGPoint(x: cx, y: groundY - size.height * 0.025)
        )
        bottomPath.addLine(to: CGPoint(x: cx + soilW * 0.92, y: groundY + 7))
        bottomPath.addQuadCurve(
            to: CGPoint(x: cx - soilW * 0.92, y: groundY + 7),
            control: CGPoint(x: cx, y: groundY + 3)
        )
        bottomPath.closeSubpath()
        context.fill(bottomPath, with: .linearGradient(
            Gradient(colors: [soilRich, soilDark]),
            startPoint: CGPoint(x: cx, y: groundY),
            endPoint: CGPoint(x: cx, y: groundY + 7)
        ))

        // Top lighter mound
        var topPath = Path()
        topPath.move(to: CGPoint(x: cx - soilW, y: groundY))
        topPath.addQuadCurve(
            to: CGPoint(x: cx + soilW, y: groundY),
            control: CGPoint(x: cx, y: groundY - size.height * 0.055)
        )
        topPath.addLine(to: CGPoint(x: cx + soilW, y: groundY + 2))
        topPath.addQuadCurve(
            to: CGPoint(x: cx - soilW, y: groundY + 2),
            control: CGPoint(x: cx, y: groundY - size.height * 0.035)
        )
        topPath.closeSubpath()
        context.fill(topPath, with: .linearGradient(
            Gradient(colors: [soilColor, soilDark.opacity(0.7)]),
            startPoint: CGPoint(x: cx - soilW, y: groundY),
            endPoint: CGPoint(x: cx + soilW, y: groundY)
        ))

        // Grass tufts
        drawGrassTuft(context: &context, baseX: cx - soilW * 0.75, baseY: groundY - size.height * 0.018, height: size.height * 0.028, lean: -0.3)
        drawGrassTuft(context: &context, baseX: cx + soilW * 0.7, baseY: groundY - size.height * 0.014, height: size.height * 0.024, lean: 0.4)
        drawGrassTuft(context: &context, baseX: cx - soilW * 0.3, baseY: groundY - size.height * 0.038, height: size.height * 0.018, lean: -0.1)
    }

    // MARK: - Atmosphere

    static func drawAtmosphere(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        stage: PlantStage,
        isWilted: Bool,
        elapsedTime: TimeInterval,
        bloomPulse: CGFloat,
        lightPhase: CGFloat
    ) {
        guard !isWilted else { return }

        let stageFactor = CGFloat(stage.rawValue) / CGFloat(max(PlantStage.allCases.count - 1, 1))
        guard stageFactor > 0 else { return }

        let time = CGFloat(elapsedTime)
        let driftX = sin(time * 0.26 + stageFactor * 1.6) * size.width * 0.03
        let canopyCenter = CGPoint(
            x: size.width * 0.5 + driftX,
            y: groundY - size.height * (0.12 + stageFactor * 0.28)
        )

        let warmRect = CGRect(
            x: canopyCenter.x - size.width * (0.12 + stageFactor * 0.16),
            y: canopyCenter.y - size.height * (0.08 + stageFactor * 0.10),
            width: size.width * (0.24 + stageFactor * 0.32),
            height: size.height * (0.16 + stageFactor * 0.20)
        )
        context.fill(
            Path(ellipseIn: warmRect),
            with: .radialGradient(
                Gradient(colors: [
                    atmosphereWarm.opacity(0.04 + 0.04 * stageFactor + 0.03 * bloomPulse),
                    Color.clear
                ]),
                center: canopyCenter,
                startRadius: 0,
                endRadius: warmRect.width * 0.5
            )
        )

        let coolCenter = CGPoint(
            x: canopyCenter.x - size.width * 0.04,
            y: canopyCenter.y - size.height * 0.03
        )
        let coolRect = CGRect(
            x: coolCenter.x - size.width * (0.10 + stageFactor * 0.12),
            y: coolCenter.y - size.height * (0.06 + stageFactor * 0.08),
            width: size.width * (0.20 + stageFactor * 0.24),
            height: size.height * (0.12 + stageFactor * 0.16)
        )
        context.fill(
            Path(ellipseIn: coolRect),
            with: .radialGradient(
                Gradient(colors: [
                    atmosphereCool.opacity(0.03 + 0.03 * stageFactor + 0.02 * lightPhase),
                    Color.clear
                ]),
                center: coolCenter,
                startRadius: 0,
                endRadius: coolRect.width * 0.5
            )
        )

        if stage >= .floweringBush {
            let beamWidth = size.width * (0.22 + stageFactor * 0.08)
            let beamHeight = size.height * (0.30 + stageFactor * 0.10)
            let beamRect = CGRect(
                x: canopyCenter.x - beamWidth * 0.5 + driftX * 0.2,
                y: canopyCenter.y - beamHeight * 0.75,
                width: beamWidth,
                height: beamHeight
            )
            context.fill(
                Path(ellipseIn: beamRect),
                with: .linearGradient(
                    Gradient(colors: [
                        atmosphereWarm.opacity(0.015 + lightPhase * 0.025),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: beamRect.midX, y: beamRect.minY),
                    endPoint: CGPoint(x: beamRect.midX, y: beamRect.maxY)
                )
            )
        }

        drawFloatingMotes(
            context: &context,
            size: size,
            groundY: groundY,
            stage: stage,
            isWilted: false,
            elapsedTime: elapsedTime,
            lightPhase: lightPhase,
            foreground: false
        )
    }

    static func drawFloatingMotes(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        stage: PlantStage,
        isWilted: Bool,
        elapsedTime: TimeInterval,
        lightPhase: CGFloat,
        foreground: Bool
    ) {
        guard !isWilted, stage >= .seedling else { return }

        let stageFactor = CGFloat(stage.rawValue) / CGFloat(max(PlantStage.allCases.count - 1, 1))
        let time = CGFloat(elapsedTime)
        let count = (foreground ? 4 : 6) + Int(stageFactor * 4)
        let baseY = groundY - size.height * (0.06 + stageFactor * 0.18)
        let travel = size.height * (0.12 + stageFactor * (foreground ? 0.22 : 0.16))
        let xSpread = size.width * (0.08 + stageFactor * 0.12)

        for i in 0..<count {
            let seed = CGFloat(i) * 0.91 + (foreground ? 0.37 : 0)
            let speed = (foreground ? 11.0 : 8.5) + CGFloat(i) * 1.35
            let rise = (time * speed + seed * 23).truncatingRemainder(dividingBy: travel)
            let orbit = sin(time * (0.42 + CGFloat(i) * 0.05) + seed * 2.3)
            let drift = cos(time * (0.30 + CGFloat(i) * 0.04) + seed * 2.9)
            let sideBias: CGFloat = i.isMultiple(of: 2) ? -1 : 1

            let x = size.width * 0.5 + orbit * xSpread + drift * size.width * 0.018 + sideBias * size.width * 0.03 * stageFactor
            let y = baseY - rise + drift * size.height * 0.012
            let radius = size.width * (foreground ? 0.005 : 0.004) * (0.9 + CGFloat(i % 3) * 0.22)
            let opacity = (foreground ? 0.05 : 0.035) + stageFactor * 0.03 + lightPhase * 0.02

            let moteRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let color = (i % 3 == 0 ? atmosphereWarm : moteColor).opacity(opacity)
            context.fill(Path(ellipseIn: moteRect), with: .color(color))
        }
    }

    // MARK: - Seed

    static func drawSeed(context: inout GraphicsContext, size: CGSize, groundY: CGFloat, isWilted: Bool) {
        let cx = size.width / 2
        let seedW = size.width * 0.1
        let seedH = size.height * 0.07
        let seedY = groundY - seedH * 0.7

        // Soft glow
        if !isWilted {
            let glowR = seedW * 2.8
            let glowRect = CGRect(x: cx - glowR, y: seedY - glowR * 0.5, width: glowR * 2, height: glowR)
            context.fill(Path(ellipseIn: glowRect), with: .color(seedGlow))
            // Inner brighter glow
            let innerR = seedW * 1.5
            let innerRect = CGRect(x: cx - innerR, y: seedY - innerR * 0.4, width: innerR * 2, height: innerR * 0.8)
            context.fill(Path(ellipseIn: innerRect), with: .color(seedGlow.opacity(0.5)))
        }

        // Seed body — slightly rotated oval with gradient
        let seedRect = CGRect(x: cx - seedW / 2, y: seedY - seedH / 2, width: seedW, height: seedH)
        let seedPath = Path(ellipseIn: seedRect)

        if isWilted {
            context.fill(seedPath, with: .color(wiltedTrunk))
        } else {
            context.fill(seedPath, with: .linearGradient(
                Gradient(colors: [trunkDark, trunkMid, trunkLight.opacity(0.9)]),
                startPoint: CGPoint(x: cx - seedW * 0.4, y: seedY - seedH * 0.3),
                endPoint: CGPoint(x: cx + seedW * 0.4, y: seedY + seedH * 0.3)
            ))
            // Highlight
            let hlRect = CGRect(x: cx - seedW * 0.15, y: seedY - seedH * 0.3, width: seedW * 0.25, height: seedH * 0.25)
            context.fill(Path(ellipseIn: hlRect), with: .color(trunkLight.opacity(0.4)))
        }

        // Crack
        var crack = Path()
        crack.move(to: CGPoint(x: cx - seedW * 0.12, y: seedY - seedH * 0.18))
        crack.addCurve(
            to: CGPoint(x: cx + seedW * 0.15, y: seedY - seedH * 0.05),
            control1: CGPoint(x: cx, y: seedY + seedH * 0.1),
            control2: CGPoint(x: cx + seedW * 0.08, y: seedY - seedH * 0.15)
        )
        context.stroke(crack, with: .color(soilDark.opacity(0.6)), lineWidth: 0.8)

        // Tiny sprout tip
        if !isWilted {
            let tipBase = CGPoint(x: cx + seedW * 0.02, y: seedY - seedH * 0.18)
            let tipTop = CGPoint(x: cx, y: seedY - seedH * 0.55)
            var tip = Path()
            tip.move(to: tipBase)
            tip.addCurve(
                to: tipTop,
                control1: CGPoint(x: cx + seedW * 0.1, y: seedY - seedH * 0.3),
                control2: CGPoint(x: cx + seedW * 0.05, y: seedY - seedH * 0.45)
            )
            tip.addCurve(
                to: tipBase,
                control1: CGPoint(x: cx - seedW * 0.06, y: seedY - seedH * 0.4),
                control2: CGPoint(x: cx - seedW * 0.03, y: seedY - seedH * 0.25)
            )
            tip.closeSubpath()
            context.fill(tip, with: .linearGradient(
                Gradient(colors: [leafDark.opacity(0.6), leafGreen.opacity(0.7)]),
                startPoint: tipBase,
                endPoint: tipTop
            ))
        }
    }

    // MARK: - Sprout

    static func drawSprout(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let stemH = size.height * 0.2
        let stemBase = CGPoint(x: cx, y: groundY - size.height * 0.02)

        // Sway: base=0, midpoint=light, top=full
        let midSway = swayForHeight(0.5, swayOffset, scale: 2.0)
        let topSway = swayForHeight(1.0, swayOffset, scale: 2.0)

        let stemTop = CGPoint(x: cx + topSway, y: groundY - stemH)
        let stemCtrl = CGPoint(x: cx + midSway, y: groundY - stemH * 0.5)

        // Stem
        drawGradientStem(
            context: &context,
            from: stemBase,
            to: stemTop,
            control: stemCtrl,
            width: size.width * 0.014,
            isWilted: isWilted
        )

        // Cotyledon leaves — teardrop shaped
        let droopAngle: CGFloat = isWilted ? 0.4 : 0
        let leafSway = swayOffset * 0.04

        drawGradientLeaf(
            context: &context,
            origin: stemTop,
            length: size.width * 0.13,
            angle: -.pi / 3 + leafSway + droopAngle,
            width: size.width * 0.055,
            isWilted: isWilted,
            shade: 0
        )
        drawGradientLeaf(
            context: &context,
            origin: stemTop,
            length: size.width * 0.13,
            angle: .pi + .pi / 3 + leafSway - droopAngle,
            width: size.width * 0.055,
            isWilted: isWilted,
            shade: 1
        )

        // Unfurling bud
        if !isWilted {
            let budTip = CGPoint(x: stemTop.x + leafSway * 2, y: stemTop.y - size.height * 0.028)
            var bud = Path()
            bud.move(to: stemTop)
            bud.addCurve(
                to: budTip,
                control1: CGPoint(x: stemTop.x + size.width * 0.015, y: stemTop.y - size.height * 0.008),
                control2: CGPoint(x: stemTop.x + size.width * 0.02, y: stemTop.y - size.height * 0.022)
            )
            bud.addCurve(
                to: stemTop,
                control1: CGPoint(x: stemTop.x - size.width * 0.005, y: stemTop.y - size.height * 0.018),
                control2: CGPoint(x: stemTop.x - size.width * 0.003, y: stemTop.y - size.height * 0.006)
            )
            bud.closeSubpath()
            context.fill(bud, with: .linearGradient(
                Gradient(colors: [leafMid, leafHighlight]),
                startPoint: stemTop,
                endPoint: budTip
            ))
        }
    }

    // MARK: - Seedling

    static func drawSeedling(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let stemH = size.height * 0.35
        let stemBase = CGPoint(x: cx, y: groundY - size.height * 0.02)

        // S-curve with proper sway physics — base fixed, progressive flex
        let sway30 = swayForHeight(0.3, swayOffset, scale: 2.5)
        let sway70 = swayForHeight(0.7, swayOffset, scale: 2.5)
        let swayTop = swayForHeight(1.0, swayOffset, scale: 2.5)

        let stemTop = CGPoint(x: cx + swayTop, y: groundY - stemH)
        // S-curve: slight counter-bend low, then follow sway high
        let ctrl1 = CGPoint(x: cx - size.width * 0.02 + sway30, y: groundY - stemH * 0.3)
        let ctrl2 = CGPoint(x: cx + size.width * 0.025 + sway70, y: groundY - stemH * 0.7)

        // Stem
        drawCubicGradientStem(
            context: &context,
            from: stemBase,
            to: stemTop,
            control1: ctrl1,
            control2: ctrl2,
            width: size.width * 0.018,
            isWilted: isWilted
        )

        let droopAngle: CGFloat = isWilted ? 0.5 : 0
        let leafLen = size.width * 0.14

        // Leaves along stem — 8 with varied sizes, shades, angles
        let leafDefs: [(t: CGFloat, angle: CGFloat, shade: Int, scale: CGFloat)] = [
            (0.2, -.pi / 4, 0, 0.55),
            (0.2, .pi + .pi / 4, 1, 0.50),
            (0.38, -.pi / 3.5, 2, 0.70),
            (0.4, .pi + .pi / 3.5, 0, 0.65),
            (0.58, -.pi / 3, 1, 0.82),
            (0.6, .pi + .pi / 3, 2, 0.78),
            (0.78, -.pi / 3, 0, 0.92),
            (0.82, .pi + .pi / 3.5, 1, 0.88),
        ]

        for leaf in leafDefs {
            let pos = cubicBezierPoint(from: stemBase, to: stemTop, control1: ctrl1, control2: ctrl2, t: leaf.t)
            let isLeft = leaf.angle > .pi / 2
            let droop = isLeft ? -droopAngle : droopAngle
            // Leaf angle sway scales with height too
            let leafAngleSway = swayForHeight(leaf.t, swayOffset, scale: 0.04)
            let thisLen = leafLen * leaf.scale

            drawGradientLeaf(
                context: &context,
                origin: pos,
                length: thisLen,
                angle: leaf.angle + leafAngleSway + droop,
                width: size.width * 0.042,
                isWilted: isWilted,
                shade: leaf.shade
            )

            // Veins on larger leaves
            if leaf.scale > 0.7 {
                drawLeafVein(
                    context: &context,
                    origin: pos,
                    length: thisLen * 0.65,
                    angle: leaf.angle + leafAngleSway + droop,
                    isWilted: isWilted
                )
            }
        }

        // Top bud cluster — two small leaves emerging
        if !isWilted {
            drawGradientLeaf(
                context: &context,
                origin: stemTop,
                length: leafLen * 0.4,
                angle: -.pi / 5 + swayOffset * 0.03,
                width: size.width * 0.025,
                isWilted: false,
                shade: 2
            )
            drawGradientLeaf(
                context: &context,
                origin: stemTop,
                length: leafLen * 0.35,
                angle: .pi + .pi / 5 + swayOffset * 0.03,
                width: size.width * 0.022,
                isWilted: false,
                shade: 2
            )
        }
    }

    // MARK: - Young Plant

    static func drawYoungPlant(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let trunkH = size.height * 0.5
        let trunkBase = CGPoint(x: cx, y: groundY)

        // Height-based sway for trunk points
        let sway30 = swayForHeight(0.3, swayOffset, scale: 1.8)
        let sway70 = swayForHeight(0.7, swayOffset, scale: 1.8)
        let swayTop = swayForHeight(1.0, swayOffset, scale: 1.8)

        let trunkTop = CGPoint(x: cx + swayTop, y: groundY - trunkH)
        let tCtrl1 = CGPoint(x: cx - size.width * 0.015 + sway30, y: groundY - trunkH * 0.3)
        let tCtrl2 = CGPoint(x: cx + size.width * 0.018 + sway70, y: groundY - trunkH * 0.7)

        // Ground shadow
        drawGroundShadow(context: &context, center: CGPoint(x: cx + swayTop * 0.3, y: groundY + 2), width: size.width * 0.25, height: size.height * 0.012)

        // Roots (fixed — no sway)
        drawRoots(context: &context, basePoint: trunkBase, size: size, count: 3, isWilted: isWilted)

        // Curved trunk
        drawCurvedTrunk(
            context: &context,
            base: trunkBase, top: trunkTop,
            control1: tCtrl1, control2: tCtrl2,
            baseWidth: size.width * 0.042, topWidth: size.width * 0.018,
            isWilted: isWilted
        )

        // Bark
        drawBarkTexture(context: &context, base: trunkBase, top: trunkTop, control1: tCtrl1, control2: tCtrl2, width: size.width * 0.038, isWilted: isWilted)

        // Branches — start from trunk spine, ends sway based on their height
        let b1StartT: CGFloat = 0.55
        let b1Start = cubicBezierPoint(from: trunkBase, to: trunkTop, control1: tCtrl1, control2: tCtrl2, t: b1StartT)
        let b1EndH = normalizedHeight(y: groundY - trunkH * 0.75, groundY: groundY, totalHeight: trunkH)
        let b1EndSway = swayForHeight(b1EndH, swayOffset, scale: 2.5)
        let b1End = CGPoint(x: cx + size.width * 0.17 + b1EndSway, y: groundY - trunkH * 0.75)
        drawBranch(context: &context, from: b1Start, to: b1End, width: size.width * 0.011, isWilted: isWilted)

        let b2StartT: CGFloat = 0.7
        let b2Start = cubicBezierPoint(from: trunkBase, to: trunkTop, control1: tCtrl1, control2: tCtrl2, t: b2StartT)
        let b2EndH = normalizedHeight(y: groundY - trunkH * 0.88, groundY: groundY, totalHeight: trunkH)
        let b2EndSway = swayForHeight(b2EndH, swayOffset, scale: 2.5)
        let b2End = CGPoint(x: cx - size.width * 0.14 + b2EndSway, y: groundY - trunkH * 0.88)
        drawBranch(context: &context, from: b2Start, to: b2End, width: size.width * 0.009, isWilted: isWilted)

        // Leaf clusters — angle sway based on height
        let droopAngle: CGFloat = isWilted ? 0.6 : 0
        let leafLen = size.width * 0.1
        let leafAngleSway1 = swayForHeight(b1EndH, swayOffset, scale: 0.04)
        let leafAngleSway2 = swayForHeight(b2EndH, swayOffset, scale: 0.04)

        // Branch 1 cluster
        for (angle, shade, scale) in [(CGFloat(-0.78), 0, CGFloat(1.0)), (-1.0, 1, 0.9), (-0.52, 2, 0.85)] as [(CGFloat, Int, CGFloat)] {
            drawGradientLeaf(context: &context, origin: b1End,
                length: leafLen * scale, angle: angle + droopAngle + leafAngleSway1,
                width: size.width * 0.038, isWilted: isWilted, shade: shade)
        }

        // Branch 2 cluster
        for (angle, shade, scale) in [(CGFloat(.pi + 0.78), 1, CGFloat(1.0)), (.pi + 1.05, 0, 0.9), (.pi + 0.52, 2, 0.85)] as [(CGFloat, Int, CGFloat)] {
            drawGradientLeaf(context: &context, origin: b2End,
                length: leafLen * scale, angle: angle - droopAngle + leafAngleSway2,
                width: size.width * 0.038, isWilted: isWilted, shade: shade)
        }

        // Crown cluster
        let crownAngleSway = swayForHeight(1.0, swayOffset, scale: 0.03)
        let crownDefs: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, shade: Int)] = [
            (0, 0, -.pi / 4 + droopAngle, 0),
            (0, 0, .pi + .pi / 4 - droopAngle, 1),
            (0, -0.022, -.pi / 6 + droopAngle, 2),
            (0, -0.022, .pi + .pi / 6 - droopAngle, 0),
        ]
        for leaf in crownDefs {
            let pt = CGPoint(x: trunkTop.x + size.width * leaf.dx, y: trunkTop.y + size.height * leaf.dy)
            drawGradientLeaf(context: &context, origin: pt,
                length: leafLen, angle: leaf.angle + crownAngleSway,
                width: size.width * 0.04, isWilted: isWilted, shade: leaf.shade)
        }

        // Flower
        if !isWilted {
            let flowerCenter = CGPoint(x: b1End.x - size.width * 0.025, y: b1End.y - size.height * 0.012)
            drawFlower(
                context: &context,
                center: flowerCenter,
                radius: size.width * 0.016,
                bloomPhase: ornamentPhase(anchor: flowerCenter, swayOffset: swayOffset)
            )
        }
    }

    // MARK: - Tree

    static func drawTree(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let trunkH = size.height * 0.55
        let trunkBase = CGPoint(x: cx, y: groundY)

        // Trunk sway
        let sway25 = swayForHeight(0.25, swayOffset, scale: 1.5)
        let sway65 = swayForHeight(0.65, swayOffset, scale: 1.5)
        let swayTop = swayForHeight(1.0, swayOffset, scale: 1.5)

        let trunkTop = CGPoint(x: cx + swayTop, y: groundY - trunkH)
        let tCtrl1 = CGPoint(x: cx + size.width * 0.025 + sway25, y: groundY - trunkH * 0.25)
        let tCtrl2 = CGPoint(x: cx - size.width * 0.015 + sway65, y: groundY - trunkH * 0.65)

        // Ground shadow (follows trunk sway slightly)
        drawGroundShadow(context: &context, center: CGPoint(x: cx + swayTop * 0.2, y: groundY + 3), width: size.width * 0.42, height: size.height * 0.018)

        // Ground line
        var groundLine = Path()
        groundLine.move(to: CGPoint(x: size.width * 0.15, y: groundY))
        groundLine.addLine(to: CGPoint(x: size.width * 0.85, y: groundY))
        context.stroke(groundLine, with: .color(soilColor), lineWidth: 1.5)

        // Roots (fixed)
        drawRoots(context: &context, basePoint: trunkBase, size: size, count: 4, isWilted: isWilted)

        // Gnarled trunk
        drawCurvedTrunk(
            context: &context,
            base: trunkBase, top: trunkTop,
            control1: tCtrl1, control2: tCtrl2,
            baseWidth: size.width * 0.06, topWidth: size.width * 0.022,
            isWilted: isWilted
        )

        // Bark texture
        drawBarkTexture(context: &context, base: trunkBase, top: trunkTop, control1: tCtrl1, control2: tCtrl2, width: size.width * 0.05, isWilted: isWilted)

        // Branches — each sways based on its height
        let branchDefs: [(startT: CGFloat, dx: CGFloat, endYRatio: CGFloat)] = [
            (0.38, 0.21, 0.55),
            (0.40, -0.19, 0.58),
            (0.58, 0.17, 0.72),
            (0.60, -0.15, 0.75),
            (0.78, 0.11, 0.85),
            (0.80, -0.09, 0.88),
        ]

        var branchEnds: [CGPoint] = []
        for b in branchDefs {
            let startPt = cubicBezierPoint(from: trunkBase, to: trunkTop, control1: tCtrl1, control2: tCtrl2, t: b.startT)
            let endY = groundY - trunkH * b.endYRatio
            let endH = normalizedHeight(y: endY, groundY: groundY, totalHeight: trunkH)
            let endSway = swayForHeight(endH, swayOffset, scale: 2.2)
            let endPt = CGPoint(x: cx + size.width * b.dx + endSway, y: endY)
            drawBranch(context: &context, from: startPt, to: endPt, width: size.width * 0.009, isWilted: isWilted)
            branchEnds.append(endPt)
        }

        let droopAngle: CGFloat = isWilted ? 0.7 : 0
        let leafLen = size.width * 0.085

        // --- Canopy: 3 depth layers ---

        // Back layer (darkest, slightly offset for depth)
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let backAngles: [CGFloat] = [-.pi / 5, .pi + .pi / 5, -.pi / 2.5]
            for (j, angle) in backAngles.enumerated() {
                if (i + j) % 3 == 0 { continue }
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                let offset = CGPoint(x: end.x + CGFloat(j % 2) * 2, y: end.y + CGFloat(j) * 0.5)
                drawGradientLeaf(context: &context, origin: offset,
                    length: leafLen * 0.82, angle: adj,
                    width: size.width * 0.032, isWilted: isWilted, shade: 0)
            }
        }

        // Mid layer
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let midAngles: [CGFloat] = [-.pi / 4, .pi + .pi / 4, -.pi / 3]
            let count = i % 2 == 0 ? 3 : 2
            for angle in midAngles.prefix(count) {
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * 0.95, angle: adj,
                    width: size.width * 0.035, isWilted: isWilted, shade: 1)
            }
        }

        // Front layer (lightest)
        for end in branchEnds {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let frontAngles: [CGFloat] = [-.pi / 3.5, .pi + .pi / 3.5]
            for angle in frontAngles {
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * 0.88, angle: adj,
                    width: size.width * 0.033, isWilted: isWilted, shade: 2)
            }
        }

        // Crown leaves
        let crownSway = swayForHeight(1.0, swayOffset, scale: 0.03)
        let crownDefs: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, shade: Int)] = [
            (0, 0, -.pi / 4, 0),
            (0, 0, .pi + .pi / 4, 1),
            (0, -0.03, -.pi / 6, 2),
            (0, -0.03, .pi + .pi / 6, 0),
            (0.035, -0.02, -.pi / 3, 1),
            (-0.035, -0.02, .pi + .pi / 3, 2),
            (0.015, -0.04, -.pi / 5, 0),
            (-0.015, -0.04, .pi + .pi / 5, 1),
        ]
        for c in crownDefs {
            let pt = CGPoint(x: trunkTop.x + size.width * c.dx, y: trunkTop.y + size.height * c.dy)
            let adj = c.angle + (c.dx >= 0 ? droopAngle : -droopAngle) + crownSway
            drawGradientLeaf(context: &context, origin: pt,
                length: leafLen, angle: adj,
                width: size.width * 0.036, isWilted: isWilted, shade: c.shade)
        }

        // Fruits
        if !isWilted {
            let fruitSpots: [(CGPoint, CGFloat)] = [
                (CGPoint(x: branchEnds[0].x - 2, y: branchEnds[0].y + 3), 0.014),
                (CGPoint(x: branchEnds[2].x + 1, y: branchEnds[2].y + 2), 0.012),
                (CGPoint(x: branchEnds[3].x - 1, y: branchEnds[3].y + 2), 0.013),
                (CGPoint(x: trunkTop.x + size.width * 0.025, y: trunkTop.y + size.height * 0.012), 0.011),
                (CGPoint(x: trunkTop.x - size.width * 0.02, y: trunkTop.y + size.height * 0.018), 0.010),
            ]
            for (pos, rf) in fruitSpots {
                drawFruit(
                    context: &context,
                    center: pos,
                    radius: size.width * rf,
                    shimmer: ornamentPhase(anchor: pos, swayOffset: swayOffset, frequency: 0.1)
                )
            }
        }
    }

    // MARK: - Bush

    static func drawBush(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        drawBushBody(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset, withFlowers: false)
    }

    // MARK: - Flowering Bush

    static func drawFloweringBush(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let bushH = size.height * 0.45

        // Warm glow behind bush
        if !isWilted {
            let glowR = size.width * 0.28
            let glowRect = CGRect(
                x: cx - glowR,
                y: groundY - bushH * 0.55 - glowR * 0.3,
                width: glowR * 2,
                height: glowR * 0.8
            )
            context.fill(Path(ellipseIn: glowRect), with: .color(flowerPetal.opacity(0.08)))
        }

        drawBushBody(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset, withFlowers: true)
    }

    /// Shared bush drawing used by both bush and flowering bush
    private static func drawBushBody(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat,
        withFlowers: Bool
    ) {
        let cx = size.width / 2
        let bushH = size.height * 0.40
        let bushBase = CGPoint(x: cx, y: groundY)
        let domeSway = swayForHeight(0.5, swayOffset, scale: 1.5)

        // Ground shadow
        drawGroundShadow(context: &context, center: CGPoint(x: cx, y: groundY + 3), width: size.width * 0.40, height: size.height * 0.016)

        // Roots
        drawRoots(context: &context, basePoint: bushBase, size: size, count: 3, isWilted: isWilted)

        // Short stub trunk (will be mostly hidden)
        let stubH = bushH * 0.25
        let stubTop = CGPoint(x: cx + domeSway * 0.3, y: groundY - stubH)
        drawCurvedTrunk(
            context: &context,
            base: bushBase, top: stubTop,
            control1: CGPoint(x: cx, y: groundY - stubH * 0.5),
            control2: CGPoint(x: cx + domeSway * 0.15, y: groundY - stubH * 0.8),
            baseWidth: size.width * 0.03, topWidth: size.width * 0.015,
            isWilted: isWilted
        )

        // --- Dense dome ---
        // The dome center sits just above the stub trunk
        let domeCenter = CGPoint(x: cx + domeSway * 0.4, y: groundY - bushH * 0.55)
        let domeW = size.width * 0.22  // half-width of dome
        let domeH = bushH * 0.45       // half-height of dome
        let droopAngle: CGFloat = isWilted ? 0.5 : 0
        let leafLen = size.width * 0.10

        // Solid fill ellipse as bush mass (back)
        let massRect = CGRect(
            x: domeCenter.x - domeW,
            y: domeCenter.y - domeH,
            width: domeW * 2,
            height: domeH * 2
        )
        let massColor = isWilted ? wiltedLeaf.opacity(0.6) : leafDark.opacity(0.55)
        context.fill(Path(ellipseIn: massRect), with: .color(massColor))

        // Leaf positions: distributed across the dome surface, NOT just perimeter
        // Grid of points inside the ellipse for dense coverage
        let leafPoints: [(dx: CGFloat, dy: CGFloat, shade: Int, angles: [CGFloat])] = [
            // Bottom row
            (-0.65, 0.55, 0, [0.3, -0.8]),
            (-0.2, 0.7, 1, [0.5, -0.4]),
            (0.25, 0.65, 0, [0.2, -0.6]),
            (0.7, 0.5, 1, [-0.2, -1.0]),
            // Middle-bottom row
            (-0.8, 0.15, 0, [0.4, -0.5, -1.2]),
            (-0.35, 0.2, 2, [0.6, -0.3, -1.0]),
            (0.0, 0.25, 1, [0.3, -0.7, .pi + 0.3]),
            (0.4, 0.15, 0, [-0.2, -0.9, .pi + 0.5]),
            (0.8, 0.2, 2, [-0.4, -1.1]),
            // Center row
            (-0.7, -0.15, 1, [0.5, -0.6, -1.3]),
            (-0.25, -0.1, 0, [0.4, -0.5, .pi + 0.4]),
            (0.15, -0.15, 2, [-0.3, -0.8, .pi + 0.6]),
            (0.6, -0.1, 1, [-0.5, -1.0]),
            // Upper row
            (-0.5, -0.5, 2, [0.3, -0.7, -1.2]),
            (-0.05, -0.55, 1, [0.2, -0.5, .pi + 0.3]),
            (0.45, -0.45, 0, [-0.3, -0.9]),
            // Top
            (-0.15, -0.8, 2, [0.1, -0.4, -1.0]),
            (0.2, -0.75, 1, [-0.2, -0.7]),
        ]

        // Back layer — darker shade leaves filling dome
        for lp in leafPoints {
            let pt = CGPoint(
                x: domeCenter.x + domeW * lp.dx + swayForHeight(0.5 - lp.dy * 0.3, swayOffset, scale: 1.5) * 0.3,
                y: domeCenter.y + domeH * lp.dy
            )
            let angleSway = swayForHeight(0.5 - lp.dy * 0.3, swayOffset, scale: 0.03)
            for angle in lp.angles {
                let isLeft = lp.dx < 0
                let adj = angle + (isLeft ? -droopAngle : droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: pt,
                    length: leafLen * 0.8, angle: adj,
                    width: size.width * 0.04, isWilted: isWilted, shade: lp.shade)
            }
        }

        // Front highlight layer — sparser, lighter leaves on top
        let frontPoints: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, shade: Int)] = [
            (-0.5, 0.3, -0.6, 2),
            (0.0, 0.35, -0.4, 2),
            (0.5, 0.25, -0.8, 2),
            (-0.35, -0.2, -0.5, 2),
            (0.3, -0.25, -0.7, 2),
            (0.0, -0.6, -0.3, 2),
            (-0.6, -0.0, 0.3, 1),
            (0.55, 0.0, -1.0, 1),
        ]
        for fp in frontPoints {
            let pt = CGPoint(
                x: domeCenter.x + domeW * fp.dx + swayForHeight(0.5 - fp.dy * 0.3, swayOffset, scale: 1.5) * 0.3,
                y: domeCenter.y + domeH * fp.dy
            )
            let angleSway = swayForHeight(0.5 - fp.dy * 0.3, swayOffset, scale: 0.03)
            drawGradientLeaf(context: &context, origin: pt,
                length: leafLen * 0.9, angle: fp.angle + angleSway + (fp.dx < 0 ? -droopAngle : droopAngle),
                width: size.width * 0.042, isWilted: isWilted, shade: fp.shade)
        }

        // Flowers (only for flowering bush)
        if withFlowers && !isWilted {
            let flowerSpots: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [
                (-0.4, -0.5, 0.018),
                (0.35, -0.45, 0.016),
                (0.0, -0.8, 0.02),
                (-0.65, 0.0, 0.015),
                (0.6, 0.05, 0.016),
                (0.1, -0.15, 0.014),
            ]
            for spot in flowerSpots {
                let center = CGPoint(
                    x: domeCenter.x + domeW * spot.dx + swayForHeight(0.5, swayOffset, scale: 1.5) * 0.3,
                    y: domeCenter.y + domeH * spot.dy
                )
                drawFlower(
                    context: &context,
                    center: center,
                    radius: size.width * spot.r,
                    bloomPhase: ornamentPhase(anchor: center, swayOffset: swayOffset)
                )
            }
        }
    }

    // MARK: - Sapling

    static func drawSapling(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let trunkH = size.height * 0.55
        let trunkBase = CGPoint(x: cx, y: groundY)

        let sway30 = swayForHeight(0.3, swayOffset, scale: 1.6)
        let sway70 = swayForHeight(0.7, swayOffset, scale: 1.6)
        let swayTop = swayForHeight(1.0, swayOffset, scale: 1.6)

        let trunkTop = CGPoint(x: cx + swayTop, y: groundY - trunkH)
        let tCtrl1 = CGPoint(x: cx - size.width * 0.012 + sway30, y: groundY - trunkH * 0.3)
        let tCtrl2 = CGPoint(x: cx + size.width * 0.015 + sway70, y: groundY - trunkH * 0.7)

        // Ground shadow
        drawGroundShadow(context: &context, center: CGPoint(x: cx + swayTop * 0.3, y: groundY + 2), width: size.width * 0.3, height: size.height * 0.014)

        // Roots
        drawRoots(context: &context, basePoint: trunkBase, size: size, count: 3, isWilted: isWilted)

        // Thin trunk
        drawCurvedTrunk(
            context: &context,
            base: trunkBase, top: trunkTop,
            control1: tCtrl1, control2: tCtrl2,
            baseWidth: size.width * 0.035, topWidth: size.width * 0.015,
            isWilted: isWilted
        )

        // Light bark
        drawBarkTexture(context: &context, base: trunkBase, top: trunkTop, control1: tCtrl1, control2: tCtrl2, width: size.width * 0.03, isWilted: isWilted)

        // 3 short branches near top
        let branchDefs: [(startT: CGFloat, dx: CGFloat, endYRatio: CGFloat)] = [
            (0.6, 0.14, 0.72),
            (0.65, -0.12, 0.78),
            (0.8, 0.09, 0.88),
        ]

        var branchEnds: [CGPoint] = []
        for b in branchDefs {
            let startPt = cubicBezierPoint(from: trunkBase, to: trunkTop, control1: tCtrl1, control2: tCtrl2, t: b.startT)
            let endY = groundY - trunkH * b.endYRatio
            let endH = normalizedHeight(y: endY, groundY: groundY, totalHeight: trunkH)
            let endSway = swayForHeight(endH, swayOffset, scale: 2.2)
            let endPt = CGPoint(x: cx + size.width * b.dx + endSway, y: endY)
            drawBranch(context: &context, from: startPt, to: endPt, width: size.width * 0.008, isWilted: isWilted)
            branchEnds.append(endPt)
        }

        // Small canopy — leaf clusters at branches and crown
        let droopAngle: CGFloat = isWilted ? 0.6 : 0
        let leafLen = size.width * 0.09

        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.04)
            let angles: [(CGFloat, Int, CGFloat)] = [
                (CGFloat(-0.7), i % 3, CGFloat(1.0)),
                (CGFloat(-1.1), (i + 1) % 3, CGFloat(0.85)),
                (CGFloat(0.2), (i + 2) % 3, CGFloat(0.9)),
            ]
            for (angle, shade, scale) in angles {
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * scale, angle: adj,
                    width: size.width * 0.035, isWilted: isWilted, shade: shade)
            }
        }

        // Crown cluster
        let crownSway = swayForHeight(1.0, swayOffset, scale: 0.03)
        let crownDefs: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, shade: Int)] = [
            (0, 0, -.pi / 4 + droopAngle, 0),
            (0, 0, .pi + .pi / 4 - droopAngle, 1),
            (0, -0.02, -.pi / 6 + droopAngle, 2),
            (0, -0.02, .pi + .pi / 6 - droopAngle, 0),
            (0.02, -0.015, -.pi / 3 + droopAngle, 1),
            (-0.02, -0.015, .pi + .pi / 3 - droopAngle, 2),
        ]
        for c in crownDefs {
            let pt = CGPoint(x: trunkTop.x + size.width * c.dx, y: trunkTop.y + size.height * c.dy)
            drawGradientLeaf(context: &context, origin: pt,
                length: leafLen, angle: c.angle + crownSway,
                width: size.width * 0.036, isWilted: isWilted, shade: c.shade)
        }
    }

    // MARK: - Young Tree

    static func drawYoungTree(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let trunkH = size.height * 0.55
        let trunkBase = CGPoint(x: cx, y: groundY)

        let sway25 = swayForHeight(0.25, swayOffset, scale: 1.6)
        let sway65 = swayForHeight(0.65, swayOffset, scale: 1.6)
        let swayTop = swayForHeight(1.0, swayOffset, scale: 1.6)

        let trunkTop = CGPoint(x: cx + swayTop, y: groundY - trunkH)
        let tCtrl1 = CGPoint(x: cx + size.width * 0.02 + sway25, y: groundY - trunkH * 0.25)
        let tCtrl2 = CGPoint(x: cx - size.width * 0.012 + sway65, y: groundY - trunkH * 0.65)

        // Ground shadow
        drawGroundShadow(context: &context, center: CGPoint(x: cx + swayTop * 0.25, y: groundY + 3), width: size.width * 0.35, height: size.height * 0.016)

        // Ground line
        var groundLine = Path()
        groundLine.move(to: CGPoint(x: size.width * 0.2, y: groundY))
        groundLine.addLine(to: CGPoint(x: size.width * 0.8, y: groundY))
        context.stroke(groundLine, with: .color(soilColor), lineWidth: 1.2)

        // Roots
        drawRoots(context: &context, basePoint: trunkBase, size: size, count: 4, isWilted: isWilted)

        // Trunk — thicker than sapling
        drawCurvedTrunk(
            context: &context,
            base: trunkBase, top: trunkTop,
            control1: tCtrl1, control2: tCtrl2,
            baseWidth: size.width * 0.05, topWidth: size.width * 0.02,
            isWilted: isWilted
        )

        // Bark
        drawBarkTexture(context: &context, base: trunkBase, top: trunkTop, control1: tCtrl1, control2: tCtrl2, width: size.width * 0.042, isWilted: isWilted)

        // 4 branches
        let branchDefs: [(startT: CGFloat, dx: CGFloat, endYRatio: CGFloat)] = [
            (0.42, 0.18, 0.58),
            (0.45, -0.16, 0.62),
            (0.65, 0.15, 0.78),
            (0.68, -0.12, 0.82),
        ]

        var branchEnds: [CGPoint] = []
        for b in branchDefs {
            let startPt = cubicBezierPoint(from: trunkBase, to: trunkTop, control1: tCtrl1, control2: tCtrl2, t: b.startT)
            let endY = groundY - trunkH * b.endYRatio
            let endH = normalizedHeight(y: endY, groundY: groundY, totalHeight: trunkH)
            let endSway = swayForHeight(endH, swayOffset, scale: 2.2)
            let endPt = CGPoint(x: cx + size.width * b.dx + endSway, y: endY)
            drawBranch(context: &context, from: startPt, to: endPt, width: size.width * 0.01, isWilted: isWilted)
            branchEnds.append(endPt)
        }

        let droopAngle: CGFloat = isWilted ? 0.7 : 0
        let leafLen = size.width * 0.088

        // 2-layer canopy
        // Back layer
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let backAngles: [CGFloat] = [-.pi / 5, .pi + .pi / 5, -.pi / 2.5]
            for (j, angle) in backAngles.enumerated() {
                if (i + j) % 3 == 0 { continue }
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * 0.82, angle: adj,
                    width: size.width * 0.033, isWilted: isWilted, shade: 0)
            }
        }

        // Front layer
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let frontAngles: [CGFloat] = [-.pi / 4, .pi + .pi / 4]
            let count = i % 2 == 0 ? 2 : 1
            for angle in frontAngles.prefix(count + 1) {
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * 0.92, angle: adj,
                    width: size.width * 0.035, isWilted: isWilted, shade: i % 2 == 0 ? 1 : 2)
            }
        }

        // Crown leaves
        let crownSway = swayForHeight(1.0, swayOffset, scale: 0.03)
        let crownDefs: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, shade: Int)] = [
            (0, 0, -.pi / 4, 0),
            (0, 0, .pi + .pi / 4, 1),
            (0, -0.025, -.pi / 6, 2),
            (0, -0.025, .pi + .pi / 6, 0),
            (0.025, -0.015, -.pi / 3, 1),
            (-0.025, -0.015, .pi + .pi / 3, 2),
        ]
        for c in crownDefs {
            let pt = CGPoint(x: trunkTop.x + size.width * c.dx, y: trunkTop.y + size.height * c.dy)
            let adj = c.angle + (c.dx >= 0 ? droopAngle : -droopAngle) + crownSway
            drawGradientLeaf(context: &context, origin: pt,
                length: leafLen, angle: adj,
                width: size.width * 0.036, isWilted: isWilted, shade: c.shade)
        }

        // Small fruits
        if !isWilted {
            let fruitSpots: [(CGPoint, CGFloat)] = [
                (CGPoint(x: branchEnds[0].x - 1, y: branchEnds[0].y + 2), 0.011),
                (CGPoint(x: branchEnds[2].x + 1, y: branchEnds[2].y + 2), 0.010),
                (CGPoint(x: trunkTop.x + size.width * 0.02, y: trunkTop.y + size.height * 0.01), 0.009),
            ]
            for (pos, rf) in fruitSpots {
                drawFruit(
                    context: &context,
                    center: pos,
                    radius: size.width * rf,
                    shimmer: ornamentPhase(anchor: pos, swayOffset: swayOffset, frequency: 0.1)
                )
            }
        }
    }

    // MARK: - Grove Tree

    static func drawGroveTree(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let cx = size.width / 2
        let trunkH = size.height * 0.6
        let trunkBase = CGPoint(x: cx, y: groundY)

        let sway25 = swayForHeight(0.25, swayOffset, scale: 1.5)
        let sway65 = swayForHeight(0.65, swayOffset, scale: 1.5)
        let swayTop = swayForHeight(1.0, swayOffset, scale: 1.5)

        let trunkTop = CGPoint(x: cx + swayTop, y: groundY - trunkH)
        let tCtrl1 = CGPoint(x: cx + size.width * 0.03 + sway25, y: groundY - trunkH * 0.25)
        let tCtrl2 = CGPoint(x: cx - size.width * 0.018 + sway65, y: groundY - trunkH * 0.65)

        // Golden glow behind tree
        if !isWilted {
            let glowR = size.width * 0.35
            let glowRect = CGRect(
                x: cx - glowR,
                y: groundY - trunkH * 0.65 - glowR * 0.3,
                width: glowR * 2,
                height: glowR * 1.2
            )
            context.fill(Path(ellipseIn: glowRect), with: .color(groveGlow.opacity(0.12)))
            let innerRect = CGRect(
                x: cx - glowR * 0.6,
                y: groundY - trunkH * 0.55 - glowR * 0.2,
                width: glowR * 1.2,
                height: glowR * 0.8
            )
            context.fill(Path(ellipseIn: innerRect), with: .color(groveGlow.opacity(0.08)))
        }

        // Ground shadow
        drawGroundShadow(context: &context, center: CGPoint(x: cx + swayTop * 0.2, y: groundY + 3), width: size.width * 0.48, height: size.height * 0.02)

        // Ground line
        var groundLine = Path()
        groundLine.move(to: CGPoint(x: size.width * 0.1, y: groundY))
        groundLine.addLine(to: CGPoint(x: size.width * 0.9, y: groundY))
        context.stroke(groundLine, with: .color(soilColor), lineWidth: 1.5)

        // 5 roots (wider spread)
        drawRoots(context: &context, basePoint: trunkBase, size: size, count: 4, isWilted: isWilted)
        // Extra root
        let extraRootColor = isWilted ? wiltedTrunk : trunkMid
        var extraRoot = Path()
        extraRoot.move(to: trunkBase)
        extraRoot.addQuadCurve(
            to: CGPoint(x: trunkBase.x - size.width * 0.13, y: trunkBase.y + size.height * 0.015),
            control: CGPoint(x: trunkBase.x - size.width * 0.08, y: trunkBase.y + size.height * 0.02)
        )
        context.stroke(extraRoot, with: .color(extraRootColor), lineWidth: size.width * 0.007)

        // Thick trunk
        drawCurvedTrunk(
            context: &context,
            base: trunkBase, top: trunkTop,
            control1: tCtrl1, control2: tCtrl2,
            baseWidth: size.width * 0.07, topWidth: size.width * 0.025,
            isWilted: isWilted
        )

        // Bark
        drawBarkTexture(context: &context, base: trunkBase, top: trunkTop, control1: tCtrl1, control2: tCtrl2, width: size.width * 0.058, isWilted: isWilted)

        // 8 branches
        let branchDefs: [(startT: CGFloat, dx: CGFloat, endYRatio: CGFloat)] = [
            (0.32, 0.22, 0.48),
            (0.35, -0.20, 0.52),
            (0.48, 0.19, 0.62),
            (0.50, -0.17, 0.65),
            (0.62, 0.16, 0.76),
            (0.65, -0.14, 0.78),
            (0.78, 0.11, 0.88),
            (0.80, -0.10, 0.90),
        ]

        var branchEnds: [CGPoint] = []
        for b in branchDefs {
            let startPt = cubicBezierPoint(from: trunkBase, to: trunkTop, control1: tCtrl1, control2: tCtrl2, t: b.startT)
            let endY = groundY - trunkH * b.endYRatio
            let endH = normalizedHeight(y: endY, groundY: groundY, totalHeight: trunkH)
            let endSway = swayForHeight(endH, swayOffset, scale: 2.2)
            let endPt = CGPoint(x: cx + size.width * b.dx + endSway, y: endY)
            drawBranch(context: &context, from: startPt, to: endPt, width: size.width * 0.009, isWilted: isWilted)
            branchEnds.append(endPt)
        }

        let droopAngle: CGFloat = isWilted ? 0.7 : 0
        let leafLen = size.width * 0.088

        // 4-layer canopy

        // Layer 1 — deepest/darkest
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            if i % 2 == 0 {
                let adj: CGFloat = -.pi / 5 + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                let offset = CGPoint(x: end.x + 2, y: end.y + 1)
                drawGradientLeaf(context: &context, origin: offset,
                    length: leafLen * 0.75, angle: adj,
                    width: size.width * 0.03, isWilted: isWilted, shade: 0)
            }
        }

        // Layer 2 — back
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let backAngles: [CGFloat] = [-.pi / 5, .pi + .pi / 5, -.pi / 2.5]
            for (j, angle) in backAngles.enumerated() {
                if (i + j) % 3 == 0 { continue }
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * 0.85, angle: adj,
                    width: size.width * 0.033, isWilted: isWilted, shade: 0)
            }
        }

        // Layer 3 — mid
        for (i, end) in branchEnds.enumerated() {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let midAngles: [CGFloat] = [-.pi / 4, .pi + .pi / 4, -.pi / 3]
            let count = i % 2 == 0 ? 3 : 2
            for angle in midAngles.prefix(count) {
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen, angle: adj,
                    width: size.width * 0.036, isWilted: isWilted, shade: 1)
            }
        }

        // Layer 4 — front/lightest
        for end in branchEnds {
            let h = normalizedHeight(y: end.y, groundY: groundY, totalHeight: trunkH)
            let angleSway = swayForHeight(h, swayOffset, scale: 0.035)
            let frontAngles: [CGFloat] = [-.pi / 3.5, .pi + .pi / 3.5]
            for angle in frontAngles {
                let adj = angle + (end.x > cx ? droopAngle : -droopAngle) + angleSway
                drawGradientLeaf(context: &context, origin: end,
                    length: leafLen * 0.92, angle: adj,
                    width: size.width * 0.035, isWilted: isWilted, shade: 2)
            }
        }

        // Crown leaves (dense)
        let crownSway = swayForHeight(1.0, swayOffset, scale: 0.03)
        let crownDefs: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, shade: Int)] = [
            (0, 0, -.pi / 4, 0),
            (0, 0, .pi + .pi / 4, 1),
            (0, -0.035, -.pi / 6, 2),
            (0, -0.035, .pi + .pi / 6, 0),
            (0.04, -0.025, -.pi / 3, 1),
            (-0.04, -0.025, .pi + .pi / 3, 2),
            (0.02, -0.045, -.pi / 5, 0),
            (-0.02, -0.045, .pi + .pi / 5, 1),
            (0, -0.05, -.pi / 4.5, 2),
            (0, -0.05, .pi + .pi / 4.5, 0),
        ]
        for c in crownDefs {
            let pt = CGPoint(x: trunkTop.x + size.width * c.dx, y: trunkTop.y + size.height * c.dy)
            let adj = c.angle + (c.dx >= 0 ? droopAngle : -droopAngle) + crownSway
            drawGradientLeaf(context: &context, origin: pt,
                length: leafLen * 1.05, angle: adj,
                width: size.width * 0.038, isWilted: isWilted, shade: c.shade)
        }

        if !isWilted {
            // Flowers in canopy
            let flowerSpots: [(CGPoint, CGFloat)] = [
                (CGPoint(x: branchEnds[1].x + 2, y: branchEnds[1].y - 2), 0.014),
                (CGPoint(x: branchEnds[4].x - 1, y: branchEnds[4].y - 1), 0.012),
                (CGPoint(x: trunkTop.x - size.width * 0.03, y: trunkTop.y + size.height * 0.015), 0.013),
                (CGPoint(x: branchEnds[6].x, y: branchEnds[6].y - 2), 0.011),
            ]
            for (pos, rf) in flowerSpots {
                drawFlower(
                    context: &context,
                    center: pos,
                    radius: size.width * rf,
                    bloomPhase: ornamentPhase(anchor: pos, swayOffset: swayOffset)
                )
            }

            // Fruits
            let fruitSpots: [(CGPoint, CGFloat)] = [
                (CGPoint(x: branchEnds[0].x - 2, y: branchEnds[0].y + 3), 0.014),
                (CGPoint(x: branchEnds[2].x + 1, y: branchEnds[2].y + 2), 0.013),
                (CGPoint(x: branchEnds[3].x - 1, y: branchEnds[3].y + 2), 0.013),
                (CGPoint(x: branchEnds[5].x + 2, y: branchEnds[5].y + 3), 0.012),
                (CGPoint(x: trunkTop.x + size.width * 0.03, y: trunkTop.y + size.height * 0.015), 0.011),
                (CGPoint(x: trunkTop.x - size.width * 0.025, y: trunkTop.y + size.height * 0.022), 0.010),
                (CGPoint(x: branchEnds[7].x, y: branchEnds[7].y + 2), 0.012),
            ]
            for (pos, rf) in fruitSpots {
                drawFruit(
                    context: &context,
                    center: pos,
                    radius: size.width * rf,
                    shimmer: ornamentPhase(anchor: pos, swayOffset: swayOffset, frequency: 0.1)
                )
            }

            // Bird silhouettes
            let birdDefs: [(dx: CGFloat, dy: CGFloat, wingSpan: CGFloat, flapPhase: CGFloat)] = [
                (-0.18, -0.15, 0.035, 0.0),
                (0.2, -0.2, 0.03, 1.5),
                (-0.08, -0.25, 0.025, 3.0),
            ]
            for bird in birdDefs {
                let flapOffset = sin(swayOffset * 0.8 + bird.flapPhase) * size.height * 0.008
                let birdCenter = CGPoint(
                    x: cx + size.width * bird.dx + swayForHeight(0.9, swayOffset, scale: 1.0),
                    y: groundY - trunkH * 0.9 + size.height * bird.dy + flapOffset
                )
                let wingW = size.width * bird.wingSpan
                let wingDip = size.height * 0.004 + flapOffset * 0.5

                var birdPath = Path()
                // Left wing
                birdPath.move(to: CGPoint(x: birdCenter.x - wingW, y: birdCenter.y - wingDip))
                birdPath.addQuadCurve(
                    to: birdCenter,
                    control: CGPoint(x: birdCenter.x - wingW * 0.5, y: birdCenter.y + wingDip)
                )
                // Right wing
                birdPath.addQuadCurve(
                    to: CGPoint(x: birdCenter.x + wingW, y: birdCenter.y - wingDip),
                    control: CGPoint(x: birdCenter.x + wingW * 0.5, y: birdCenter.y + wingDip)
                )
                context.stroke(birdPath, with: .color(birdColor), lineWidth: size.width * 0.004)
            }
        }
    }

    // MARK: - Drawing Helpers

    static func ornamentPhase(anchor: CGPoint, swayOffset: CGFloat, frequency: CGFloat = 0.18) -> CGFloat {
        0.5 + 0.5 * sin(swayOffset * frequency + anchor.x * 0.08 + anchor.y * 0.05)
    }

    static func teardropPath(origin: CGPoint, length: CGFloat, angle: CGFloat, width: CGFloat) -> Path {
        let tip = CGPoint(
            x: origin.x + cos(angle) * length,
            y: origin.y + sin(angle) * length
        )
        let perpAngle = angle + .pi / 2

        let widePoint = CGPoint(
            x: origin.x + cos(angle) * length * 0.32,
            y: origin.y + sin(angle) * length * 0.32
        )
        let narrowPoint = CGPoint(
            x: origin.x + cos(angle) * length * 0.68,
            y: origin.y + sin(angle) * length * 0.68
        )

        let c1 = CGPoint(x: widePoint.x + cos(perpAngle) * width, y: widePoint.y + sin(perpAngle) * width)
        let c2 = CGPoint(x: widePoint.x - cos(perpAngle) * width, y: widePoint.y - sin(perpAngle) * width)
        let c3 = CGPoint(x: narrowPoint.x + cos(perpAngle) * width * 0.45, y: narrowPoint.y + sin(perpAngle) * width * 0.45)
        let c4 = CGPoint(x: narrowPoint.x - cos(perpAngle) * width * 0.45, y: narrowPoint.y - sin(perpAngle) * width * 0.45)

        var path = Path()
        path.move(to: origin)
        path.addCurve(to: tip, control1: c1, control2: c3)
        path.addCurve(to: origin, control1: c4, control2: c2)
        path.closeSubpath()
        return path
    }

    /// Teardrop-shaped leaf with gradient fill and shade variation
    static func drawGradientLeaf(
        context: inout GraphicsContext,
        origin: CGPoint,
        length: CGFloat,
        angle: CGFloat,
        width: CGFloat,
        isWilted: Bool,
        shade: Int
    ) {
        let tip = CGPoint(
            x: origin.x + cos(angle) * length,
            y: origin.y + sin(angle) * length
        )
        let path = teardropPath(origin: origin, length: length, angle: angle, width: width)

        if isWilted {
            context.fill(path, with: .linearGradient(
                Gradient(colors: [wiltedLeaf, wiltedTip]),
                startPoint: origin, endPoint: tip
            ))
        } else {
            let colors: [Color]
            switch shade {
            case 0: colors = [leafDark, leafMid]
            case 2: colors = [leafMid, leafHighlight]
            default: colors = [leafDark.opacity(0.9), leafLight]
            }
            context.fill(path, with: .linearGradient(
                Gradient(colors: colors), startPoint: origin, endPoint: tip
            ))
        }

        let edgeColor = isWilted ? wiltedTip.opacity(0.14) : leafDark.opacity(0.12)
        context.stroke(path, with: .color(edgeColor), lineWidth: max(0.45, width * 0.12))
    }

    /// Thin center vein on a leaf
    static func drawLeafVein(
        context: inout GraphicsContext,
        origin: CGPoint,
        length: CGFloat,
        angle: CGFloat,
        isWilted: Bool
    ) {
        let end = CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
        let mid = CGPoint(
            x: (origin.x + end.x) / 2 + cos(angle + .pi / 2) * 0.5,
            y: (origin.y + end.y) / 2 + sin(angle + .pi / 2) * 0.5
        )
        var vein = Path()
        vein.move(to: origin)
        vein.addQuadCurve(to: end, control: mid)
        let color = isWilted ? wiltedTip.opacity(0.25) : leafDark.opacity(0.25)
        context.stroke(vein, with: .color(color), lineWidth: 0.5)
    }

    /// Gradient-filled stem using quad bezier, tapered from base to tip
    static func drawGradientStem(
        context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        control: CGPoint,
        width: CGFloat,
        isWilted: Bool
    ) {
        let steps = 14
        var leftPts: [CGPoint] = []
        var rightPts: [CGPoint] = []

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pt = quadBezierPoint(from: start, to: end, control: control, t: t)
            let t2 = min(t + 0.01, 1.0)
            let pt2 = quadBezierPoint(from: start, to: end, control: control, t: t2)
            let dx = pt2.x - pt.x, dy = pt2.y - pt.y
            let len = sqrt(dx * dx + dy * dy)
            guard len > 0 else { continue }
            let nx = -dy / len, ny = dx / len
            let w = width * (1.0 - t * 0.35)
            leftPts.append(CGPoint(x: pt.x + nx * w, y: pt.y + ny * w))
            rightPts.append(CGPoint(x: pt.x - nx * w, y: pt.y - ny * w))
        }

        var path = Path()
        guard let first = leftPts.first else { return }
        path.move(to: first)
        for pt in leftPts.dropFirst() { path.addLine(to: pt) }
        for pt in rightPts.reversed() { path.addLine(to: pt) }
        path.closeSubpath()

        if isWilted {
            context.fill(path, with: .color(wiltedLeaf))
        } else {
            context.fill(path, with: .linearGradient(
                Gradient(colors: [leafDark, leafGreen, leafMid]),
                startPoint: start, endPoint: end
            ))
        }
    }

    /// Gradient stem using cubic bezier for S-curves
    static func drawCubicGradientStem(
        context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        width: CGFloat,
        isWilted: Bool
    ) {
        let steps = 18
        var leftPts: [CGPoint] = []
        var rightPts: [CGPoint] = []

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pt = cubicBezierPoint(from: start, to: end, control1: control1, control2: control2, t: t)
            let t2 = min(t + 0.008, 1.0)
            let pt2 = cubicBezierPoint(from: start, to: end, control1: control1, control2: control2, t: t2)
            let dx = pt2.x - pt.x, dy = pt2.y - pt.y
            let len = sqrt(dx * dx + dy * dy)
            guard len > 0 else { continue }
            let nx = -dy / len, ny = dx / len
            let w = width * (1.0 - t * 0.35)
            leftPts.append(CGPoint(x: pt.x + nx * w, y: pt.y + ny * w))
            rightPts.append(CGPoint(x: pt.x - nx * w, y: pt.y - ny * w))
        }

        var path = Path()
        guard let first = leftPts.first else { return }
        path.move(to: first)
        for pt in leftPts.dropFirst() { path.addLine(to: pt) }
        for pt in rightPts.reversed() { path.addLine(to: pt) }
        path.closeSubpath()

        if isWilted {
            context.fill(path, with: .color(wiltedLeaf))
        } else {
            context.fill(path, with: .linearGradient(
                Gradient(colors: [leafDark, leafGreen, leafLight]),
                startPoint: start, endPoint: end
            ))
        }
    }

    /// Curved trunk with gradient fill, built from cubic bezier spine
    static func drawCurvedTrunk(
        context: inout GraphicsContext,
        base: CGPoint,
        top: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        baseWidth: CGFloat,
        topWidth: CGFloat,
        isWilted: Bool
    ) {
        let steps = 18
        var leftPts: [CGPoint] = []
        var rightPts: [CGPoint] = []

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pt = cubicBezierPoint(from: base, to: top, control1: control1, control2: control2, t: t)
            let t2 = min(t + 0.008, 1.0)
            let pt2 = cubicBezierPoint(from: base, to: top, control1: control1, control2: control2, t: t2)
            let dx = pt2.x - pt.x, dy = pt2.y - pt.y
            let len = sqrt(dx * dx + dy * dy)
            guard len > 0 else { continue }
            let nx = -dy / len, ny = dx / len
            // Smooth width taper with slight bulge at base for organic feel
            let taper = baseWidth + (topWidth - baseWidth) * t
            let bulge: CGFloat = sin(t * .pi) * baseWidth * 0.08 // subtle organic bulge
            let w = (taper + bulge) / 2
            leftPts.append(CGPoint(x: pt.x + nx * w, y: pt.y + ny * w))
            rightPts.append(CGPoint(x: pt.x - nx * w, y: pt.y - ny * w))
        }

        var path = Path()
        guard let first = leftPts.first else { return }
        path.move(to: first)
        for pt in leftPts.dropFirst() { path.addLine(to: pt) }
        for pt in rightPts.reversed() { path.addLine(to: pt) }
        path.closeSubpath()

        if isWilted {
            context.fill(path, with: .color(wiltedTrunk))
        } else {
            context.fill(path, with: .linearGradient(
                Gradient(colors: [trunkDark, trunkMid, trunkLight]),
                startPoint: base, endPoint: top
            ))
            // Subtle highlight along left edge
            var highlightPath = Path()
            guard leftPts.count >= 2 else { return }
            highlightPath.move(to: leftPts[0])
            for pt in leftPts.dropFirst() { highlightPath.addLine(to: pt) }
            context.stroke(highlightPath, with: .color(trunkLight.opacity(0.2)), lineWidth: 0.8)

            var shadowPath = Path()
            shadowPath.move(to: rightPts[0])
            for pt in rightPts.dropFirst() { shadowPath.addLine(to: pt) }
            context.stroke(shadowPath, with: .color(trunkDark.opacity(0.16)), lineWidth: 0.75)
        }
    }

    /// Bark texture — short curved strokes across trunk
    static func drawBarkTexture(
        context: inout GraphicsContext,
        base: CGPoint, top: CGPoint,
        control1: CGPoint, control2: CGPoint,
        width: CGFloat, isWilted: Bool
    ) {
        let barkColor = isWilted ? wiltedTrunk.opacity(0.3) : trunkDark.opacity(0.25)
        let positions: [CGFloat] = [0.2, 0.38, 0.55, 0.72, 0.86]

        for t in positions {
            let pt = cubicBezierPoint(from: base, to: top, control1: control1, control2: control2, t: t)
            let w = width * (1.0 - t * 0.45) * 0.35
            var bark = Path()
            bark.move(to: CGPoint(x: pt.x - w, y: pt.y + 0.5))
            bark.addQuadCurve(
                to: CGPoint(x: pt.x + w, y: pt.y - 0.5),
                control: CGPoint(x: pt.x, y: pt.y - 1.2)
            )
            context.stroke(bark, with: .color(barkColor), lineWidth: 0.6)
        }
    }

    /// Root curves from trunk base (always fixed — no sway)
    static func drawRoots(
        context: inout GraphicsContext,
        basePoint: CGPoint, size: CGSize,
        count: Int, isWilted: Bool
    ) {
        let color = isWilted ? wiltedTrunk : trunkMid
        let defs: [(dx: CGFloat, dy: CGFloat, cdx: CGFloat, cdy: CGFloat)] = [
            (-0.075, 0.018, -0.045, 0.012),
            (0.085, 0.016, 0.055, 0.01),
            (-0.11, 0.013, -0.065, 0.022),
            (0.12, 0.02, 0.075, 0.015),
        ]
        for i in 0..<min(count, defs.count) {
            let r = defs[i]
            var root = Path()
            root.move(to: basePoint)
            root.addQuadCurve(
                to: CGPoint(x: basePoint.x + size.width * r.dx, y: basePoint.y + size.height * r.dy),
                control: CGPoint(x: basePoint.x + size.width * r.cdx, y: basePoint.y + size.height * r.cdy)
            )
            context.stroke(root, with: .color(color), lineWidth: size.width * 0.007)
        }
    }

    /// Branch as a curved quad bezier stroke
    static func drawBranch(
        context: inout GraphicsContext,
        from start: CGPoint, to end: CGPoint,
        width: CGFloat, isWilted: Bool
    ) {
        let ctrl = CGPoint(
            x: (start.x + end.x) / 2,
            y: min(start.y, end.y) - abs(end.x - start.x) * 0.08
        )
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: ctrl)
        let color = isWilted ? wiltedTrunk : trunkMid
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    /// Layered flower with teardrop petals and a soft glow.
    static func drawFlower(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        bloomPhase: CGFloat = 0
    ) {
        let pulse = 1 + bloomPhase * 0.12
        let glowRadius = radius * (2.2 + bloomPhase * 0.35)
        let glowRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    atmosphereWarm.opacity(0.08 + bloomPhase * 0.05),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        let petalCount = 6
        let petalLength = radius * 1.08 * pulse
        let petalWidth = radius * 0.34

        for i in 0..<petalCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(petalCount)) - .pi / 2 + bloomPhase * 0.05
            let tip = CGPoint(
                x: center.x + cos(angle) * petalLength,
                y: center.y + sin(angle) * petalLength
            )
            let petal = teardropPath(origin: center, length: petalLength, angle: angle, width: petalWidth)
            context.fill(
                petal,
                with: .linearGradient(
                    Gradient(colors: [
                        flowerPetal.opacity(0.95),
                        Color.white.opacity(0.7)
                    ]),
                    startPoint: center,
                    endPoint: tip
                )
            )
            context.stroke(petal, with: .color(flowerPetal.opacity(0.2)), lineWidth: max(0.25, radius * 0.08))
        }

        let coreRadius = radius * (0.36 + bloomPhase * 0.03)
        let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)
        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.25), flowerCenter]),
                center: CGPoint(x: center.x - coreRadius * 0.15, y: center.y - coreRadius * 0.2),
                startRadius: 0,
                endRadius: coreRadius * 1.2
            )
        )

        let highlightRadius = coreRadius * 0.32
        let highlightRect = CGRect(
            x: center.x - highlightRadius * 1.1,
            y: center.y - highlightRadius * 1.4,
            width: highlightRadius * 1.1,
            height: highlightRadius * 0.9
        )
        context.fill(Path(ellipseIn: highlightRect), with: .color(Color.white.opacity(0.22)))
    }

    /// A fruit with highlight and a tiny stem.
    static func drawFruit(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, shimmer: CGFloat = 0) {
        let shadowRect = CGRect(
            x: center.x - radius * 0.85,
            y: center.y + radius * 0.45,
            width: radius * 1.7,
            height: radius * 0.8
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.08)))

        let stemTop = CGPoint(x: center.x + radius * 0.08, y: center.y - radius * 1.15)
        var stem = Path()
        stem.move(to: stemTop)
        stem.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - radius * 0.35),
            control: CGPoint(x: center.x + radius * 0.35, y: center.y - radius * 0.85)
        )
        context.stroke(stem, with: .color(trunkDark.opacity(0.55)), lineWidth: max(0.45, radius * 0.22))

        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .linearGradient(
            Gradient(colors: [
                fruitColor,
                fruitHighlight.opacity(0.92 + shimmer * 0.08)
            ]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
        ))
        // Tiny highlight
        let hr = radius * 0.3
        let hlRect = CGRect(x: center.x - radius * 0.28, y: center.y - radius * 0.52, width: hr, height: hr)
        context.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(0.28 + shimmer * 0.08)))
    }

    /// Grass tufts — 3 blades with lean direction
    static func drawGrassTuft(context: inout GraphicsContext, baseX: CGFloat, baseY: CGFloat, height: CGFloat, lean: CGFloat) {
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
            let c = i == 1 ? grassLight : grassColor
            context.stroke(blade, with: .color(c), lineWidth: 0.6)
        }
    }

    /// Ground shadow oval
    static func drawGroundShadow(context: inout GraphicsContext, center: CGPoint, width: CGFloat, height: CGFloat) {
        let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        context.fill(Path(ellipseIn: rect), with: .color(shadowColor))
    }

    // MARK: - Bezier Math

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
}
