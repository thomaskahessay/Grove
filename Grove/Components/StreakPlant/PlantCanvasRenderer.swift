import SwiftUI

struct PlantCanvasRenderer {

    // MARK: - Colors

    static let leafGreen = Color.groveSage
    static let trunkBrown = Color.groveTerracotta
    static let soilColor = Color.groveWarmSand
    static let wiltedLeaf = Color.groveWarmSand.opacity(0.6)
    static let wiltedTrunk = Color.groveWarmSand.opacity(0.8)

    // MARK: - Main Draw

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        stage: PlantStage,
        isWilted: Bool,
        swayOffset: CGFloat,
        growthProgress: CGFloat
    ) {
        let groundY = size.height * 0.85

        if stage.showsSoil {
            drawSoil(context: &context, size: size, groundY: groundY)
        }

        switch stage {
        case .seed:
            drawSeed(context: &context, size: size, groundY: groundY, isWilted: isWilted)
        case .sprout:
            drawSprout(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .seedling:
            drawSeedling(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .youngPlant:
            drawYoungPlant(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        case .tree:
            drawTree(context: &context, size: size, groundY: groundY, isWilted: isWilted, swayOffset: swayOffset)
        }
    }

    // MARK: - Soil

    static func drawSoil(context: inout GraphicsContext, size: CGSize, groundY: CGFloat) {
        let centerX = size.width / 2
        var path = Path()
        path.move(to: CGPoint(x: centerX - size.width * 0.3, y: groundY))
        path.addQuadCurve(
            to: CGPoint(x: centerX + size.width * 0.3, y: groundY),
            control: CGPoint(x: centerX, y: groundY - size.height * 0.06)
        )
        path.addLine(to: CGPoint(x: centerX + size.width * 0.3, y: groundY + 4))
        path.addQuadCurve(
            to: CGPoint(x: centerX - size.width * 0.3, y: groundY + 4),
            control: CGPoint(x: centerX, y: groundY - size.height * 0.04)
        )
        path.closeSubpath()
        context.fill(path, with: .color(soilColor))
    }

    // MARK: - Seed

    static func drawSeed(context: inout GraphicsContext, size: CGSize, groundY: CGFloat, isWilted: Bool) {
        let centerX = size.width / 2
        let seedWidth = size.width * 0.1
        let seedHeight = size.height * 0.07
        let seedY = groundY - seedHeight * 0.7

        // Seed body (oval)
        let seedRect = CGRect(
            x: centerX - seedWidth / 2,
            y: seedY - seedHeight / 2,
            width: seedWidth,
            height: seedHeight
        )
        let seedPath = Path(ellipseIn: seedRect)
        let seedColor = isWilted ? wiltedTrunk : trunkBrown
        context.fill(seedPath, with: .color(seedColor))

        // Crack line
        var crack = Path()
        crack.move(to: CGPoint(x: centerX - seedWidth * 0.15, y: seedY - seedHeight * 0.1))
        crack.addLine(to: CGPoint(x: centerX + seedWidth * 0.05, y: seedY + seedHeight * 0.15))
        crack.addLine(to: CGPoint(x: centerX + seedWidth * 0.15, y: seedY - seedHeight * 0.05))
        context.stroke(crack, with: .color(soilColor), lineWidth: 1)
    }

    // MARK: - Sprout

    static func drawSprout(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let centerX = size.width / 2
        let stemHeight = size.height * 0.2
        let stemBase = CGPoint(x: centerX, y: groundY - size.height * 0.02)
        let stemTop = CGPoint(x: centerX + swayOffset * 2, y: groundY - stemHeight)

        // Stem
        var stem = Path()
        stem.move(to: stemBase)
        stem.addQuadCurve(to: stemTop, control: CGPoint(x: centerX + swayOffset, y: groundY - stemHeight * 0.5))
        let stemColor = isWilted ? wiltedLeaf : leafGreen
        context.stroke(stem, with: .color(stemColor), lineWidth: size.width * 0.015)

        // Two cotyledon leaves
        let lColor = isWilted ? wiltedLeaf : leafGreen
        let droopAngle: CGFloat = isWilted ? 0.4 : 0

        drawLeaf(
            context: &context,
            origin: stemTop,
            length: size.width * 0.12,
            angle: -.pi / 3 + swayOffset * 0.05 + droopAngle,
            width: size.width * 0.06,
            color: lColor
        )
        drawLeaf(
            context: &context,
            origin: stemTop,
            length: size.width * 0.12,
            angle: .pi + .pi / 3 + swayOffset * 0.05 - droopAngle,
            width: size.width * 0.06,
            color: lColor
        )
    }

    // MARK: - Seedling

    static func drawSeedling(
        context: inout GraphicsContext,
        size: CGSize,
        groundY: CGFloat,
        isWilted: Bool,
        swayOffset: CGFloat
    ) {
        let centerX = size.width / 2
        let stemHeight = size.height * 0.35
        let stemBase = CGPoint(x: centerX, y: groundY - size.height * 0.02)
        let stemTop = CGPoint(x: centerX + swayOffset * 3, y: groundY - stemHeight)

        // Stem
        var stem = Path()
        stem.move(to: stemBase)
        stem.addQuadCurve(to: stemTop, control: CGPoint(x: centerX + swayOffset * 1.5, y: groundY - stemHeight * 0.5))
        let stemColor = isWilted ? wiltedLeaf : leafGreen
        context.stroke(stem, with: .color(stemColor), lineWidth: size.width * 0.02)

        let lColor = isWilted ? wiltedLeaf : leafGreen
        let droopAngle: CGFloat = isWilted ? 0.5 : 0
        let leafLen = size.width * 0.14

        // Leaves along stem
        let leafPositions: [(t: CGFloat, angle: CGFloat)] = [
            (0.3, -.pi / 4),
            (0.3, .pi + .pi / 4),
            (0.55, -.pi / 3.5),
            (0.55, .pi + .pi / 3.5),
            (0.85, -.pi / 3),
        ]

        for leaf in leafPositions {
            let t = leaf.t
            let pos = quadBezierPoint(
                from: stemBase,
                to: stemTop,
                control: CGPoint(x: centerX + swayOffset * 1.5, y: groundY - stemHeight * 0.5),
                t: t
            )
            let isLeft = leaf.angle > .pi / 2
            let droop = isLeft ? -droopAngle : droopAngle
            drawLeaf(
                context: &context,
                origin: pos,
                length: leafLen * (0.7 + t * 0.3),
                angle: leaf.angle + swayOffset * 0.04 + droop,
                width: size.width * 0.05,
                color: lColor
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
        let centerX = size.width / 2
        let trunkHeight = size.height * 0.5
        let trunkBase = CGPoint(x: centerX, y: groundY)
        let trunkTop = CGPoint(x: centerX + swayOffset * 2, y: groundY - trunkHeight)

        // Trunk
        drawTrunk(
            context: &context,
            base: trunkBase,
            top: trunkTop,
            baseWidth: size.width * 0.04,
            topWidth: size.width * 0.02,
            isWilted: isWilted
        )

        // Two branches
        let branchStart1 = CGPoint(x: centerX + swayOffset * 0.8, y: groundY - trunkHeight * 0.55)
        let branchEnd1 = CGPoint(x: centerX + size.width * 0.18 + swayOffset * 3, y: groundY - trunkHeight * 0.75)
        drawBranch(context: &context, from: branchStart1, to: branchEnd1, width: size.width * 0.012, isWilted: isWilted)

        let branchStart2 = CGPoint(x: centerX + swayOffset * 1.2, y: groundY - trunkHeight * 0.7)
        let branchEnd2 = CGPoint(x: centerX - size.width * 0.15 + swayOffset * 3, y: groundY - trunkHeight * 0.88)
        drawBranch(context: &context, from: branchStart2, to: branchEnd2, width: size.width * 0.01, isWilted: isWilted)

        // Leaves
        let lColor = isWilted ? wiltedLeaf : leafGreen
        let droopAngle: CGFloat = isWilted ? 0.6 : 0
        let leafLen = size.width * 0.11

        // Leaves on branches and top
        let leafSpots: [(point: CGPoint, angle: CGFloat)] = [
            (branchEnd1, -.pi / 4 + droopAngle),
            (branchEnd1, -.pi / 2.5 + droopAngle),
            (CGPoint(x: branchEnd1.x - size.width * 0.04, y: branchEnd1.y + size.height * 0.02), .pi + .pi / 3 - droopAngle),
            (branchEnd2, .pi + .pi / 4 - droopAngle),
            (branchEnd2, .pi + .pi / 3 - droopAngle),
            (CGPoint(x: branchEnd2.x + size.width * 0.04, y: branchEnd2.y + size.height * 0.02), -.pi / 3 + droopAngle),
            (trunkTop, -.pi / 4 + droopAngle),
            (trunkTop, .pi + .pi / 4 - droopAngle),
            (CGPoint(x: trunkTop.x, y: trunkTop.y - size.height * 0.02), -.pi / 6 + droopAngle),
            (CGPoint(x: trunkTop.x, y: trunkTop.y - size.height * 0.02), .pi + .pi / 6 - droopAngle),
        ]

        for spot in leafSpots {
            drawLeaf(
                context: &context,
                origin: spot.point,
                length: leafLen,
                angle: spot.angle + swayOffset * 0.03,
                width: size.width * 0.045,
                color: lColor
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
        let centerX = size.width / 2
        let trunkHeight = size.height * 0.55
        let trunkBase = CGPoint(x: centerX, y: groundY)
        let trunkTop = CGPoint(x: centerX + swayOffset, y: groundY - trunkHeight)

        // Ground line
        var groundLine = Path()
        groundLine.move(to: CGPoint(x: size.width * 0.15, y: groundY))
        groundLine.addLine(to: CGPoint(x: size.width * 0.85, y: groundY))
        context.stroke(groundLine, with: .color(soilColor), lineWidth: 2)

        // Thick trunk
        drawTrunk(
            context: &context,
            base: trunkBase,
            top: trunkTop,
            baseWidth: size.width * 0.06,
            topWidth: size.width * 0.025,
            isWilted: isWilted
        )

        // Major branches
        let branches: [(start: CGFloat, dx: CGFloat, dy: CGFloat)] = [
            (0.4, 0.22, -0.15),
            (0.4, -0.20, -0.18),
            (0.6, 0.18, -0.2),
            (0.6, -0.16, -0.22),
            (0.8, 0.12, -0.15),
            (0.8, -0.10, -0.18),
        ]

        var branchEnds: [CGPoint] = []
        for b in branches {
            let startY = groundY - trunkHeight * b.start
            let startPt = CGPoint(x: centerX + swayOffset * b.start, y: startY)
            let endPt = CGPoint(
                x: centerX + size.width * b.dx + swayOffset * 3,
                y: startY + size.height * b.dy
            )
            drawBranch(context: &context, from: startPt, to: endPt, width: size.width * 0.01, isWilted: isWilted)
            branchEnds.append(endPt)
        }

        // Canopy — many leaves around branch ends and top
        let lColor = isWilted ? wiltedLeaf : leafGreen
        let droopAngle: CGFloat = isWilted ? 0.7 : 0
        let leafLen = size.width * 0.1

        // Leaves around each branch end
        let leafAngles: [CGFloat] = [-.pi / 4, -.pi / 2.5, .pi + .pi / 4, .pi + .pi / 3, -.pi / 6]

        for (i, end) in branchEnds.enumerated() {
            let anglesForThis = leafAngles.prefix(i % 2 == 0 ? 3 : 2)
            for angle in anglesForThis {
                let adjustedAngle = angle + (end.x > centerX ? droopAngle : -droopAngle)
                drawLeaf(
                    context: &context,
                    origin: end,
                    length: leafLen * CGFloat.random(in: 0.8...1.1),
                    angle: adjustedAngle + swayOffset * 0.03,
                    width: size.width * 0.04,
                    color: lColor
                )
            }
        }

        // Crown leaves
        let crownOffsets: [(dx: CGFloat, dy: CGFloat, angle: CGFloat)] = [
            (0, 0, -.pi / 4),
            (0, 0, .pi + .pi / 4),
            (0, -0.03, -.pi / 6),
            (0, -0.03, .pi + .pi / 6),
            (0.04, -0.02, -.pi / 3),
            (-0.04, -0.02, .pi + .pi / 3),
        ]

        for offset in crownOffsets {
            let point = CGPoint(
                x: trunkTop.x + size.width * offset.dx,
                y: trunkTop.y + size.height * offset.dy
            )
            let adjustedAngle = offset.angle + (offset.dx >= 0 ? droopAngle : -droopAngle)
            drawLeaf(
                context: &context,
                origin: point,
                length: leafLen,
                angle: adjustedAngle + swayOffset * 0.03,
                width: size.width * 0.04,
                color: lColor
            )
        }
    }

    // MARK: - Helpers

    static func drawLeaf(
        context: inout GraphicsContext,
        origin: CGPoint,
        length: CGFloat,
        angle: CGFloat,
        width: CGFloat,
        color: Color
    ) {
        let tip = CGPoint(
            x: origin.x + cos(angle) * length,
            y: origin.y + sin(angle) * length
        )
        let midPoint = CGPoint(
            x: (origin.x + tip.x) / 2,
            y: (origin.y + tip.y) / 2
        )
        let perpAngle = angle + .pi / 2

        let control1 = CGPoint(
            x: midPoint.x + cos(perpAngle) * width,
            y: midPoint.y + sin(perpAngle) * width
        )
        let control2 = CGPoint(
            x: midPoint.x - cos(perpAngle) * width,
            y: midPoint.y - sin(perpAngle) * width
        )

        var path = Path()
        path.move(to: origin)
        path.addQuadCurve(to: tip, control: control1)
        path.addQuadCurve(to: origin, control: control2)
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }

    static func drawTrunk(
        context: inout GraphicsContext,
        base: CGPoint,
        top: CGPoint,
        baseWidth: CGFloat,
        topWidth: CGFloat,
        isWilted: Bool
    ) {
        var path = Path()
        path.move(to: CGPoint(x: base.x - baseWidth / 2, y: base.y))
        path.addLine(to: CGPoint(x: top.x - topWidth / 2, y: top.y))
        path.addLine(to: CGPoint(x: top.x + topWidth / 2, y: top.y))
        path.addLine(to: CGPoint(x: base.x + baseWidth / 2, y: base.y))
        path.closeSubpath()

        let color = isWilted ? wiltedTrunk : trunkBrown
        context.fill(path, with: .color(color))
    }

    static func drawBranch(
        context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        width: CGFloat,
        isWilted: Bool
    ) {
        var path = Path()
        path.move(to: start)
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: min(start.y, end.y) - abs(end.x - start.x) * 0.1
        )
        path.addQuadCurve(to: end, control: control)
        let color = isWilted ? wiltedTrunk : trunkBrown
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    static func quadBezierPoint(from: CGPoint, to: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * from.x + 2 * oneMinusT * t * control.x + t * t * to.x
        let y = oneMinusT * oneMinusT * from.y + 2 * oneMinusT * t * control.y + t * t * to.y
        return CGPoint(x: x, y: y)
    }
}
