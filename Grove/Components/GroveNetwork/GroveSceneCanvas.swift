import SwiftUI

struct GroveSceneCanvas: View {
    let groundY: CGFloat
    let userCenter: CGPoint
    let friendSlots: [GroveSlot]
    let connections: [RootConnection]
    let userStage: PlantStage
    let isWilted: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                drawSkyGradient(context: context, size: size)
                drawGroundBand(context: context, size: size)
                drawGrassTufts(context: context, size: size, time: time)
                drawRootConnections(context: context, size: size, time: time)
                if userStage >= .tree && !isWilted {
                    drawParticles(context: context, size: size, time: time)
                }
            }
            .drawingGroup()
        }
    }

    // MARK: - Sky Gradient

    private func drawSkyGradient(context: GraphicsContext, size: CGSize) {
        let gradientHeight = groundY
        let skyRect = CGRect(x: 0, y: 0, width: size.width, height: gradientHeight)

        let gradient = Gradient(stops: [
            .init(color: Color.groveCream.opacity(0.35), location: 0),
            .init(color: Color.groveCream.opacity(0.08), location: 0.6),
            .init(color: Color.clear, location: 1.0),
        ])

        context.fill(
            Path(skyRect),
            with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: gradientHeight))
        )
    }

    // MARK: - Ground Band

    private func drawGroundBand(context: GraphicsContext, size: CGSize) {
        // Organic curved top edge
        var groundPath = Path()
        groundPath.move(to: CGPoint(x: 0, y: groundY + 4))
        groundPath.addQuadCurve(
            to: CGPoint(x: size.width * 0.3, y: groundY - 2),
            control: CGPoint(x: size.width * 0.15, y: groundY + 6)
        )
        groundPath.addQuadCurve(
            to: CGPoint(x: size.width * 0.7, y: groundY + 2),
            control: CGPoint(x: size.width * 0.5, y: groundY - 5)
        )
        groundPath.addQuadCurve(
            to: CGPoint(x: size.width, y: groundY - 1),
            control: CGPoint(x: size.width * 0.85, y: groundY + 5)
        )
        groundPath.addLine(to: CGPoint(x: size.width, y: size.height))
        groundPath.addLine(to: CGPoint(x: 0, y: size.height))
        groundPath.closeSubpath()

        let soilGradient = Gradient(stops: [
            .init(color: Color.groveWarmSand.opacity(0.18), location: 0),
            .init(color: Color.groveWarmSand.opacity(0.08), location: 0.5),
            .init(color: Color.groveWarmSand.opacity(0.03), location: 1.0),
        ])

        context.fill(
            groundPath,
            with: .linearGradient(soilGradient, startPoint: CGPoint(x: 0, y: groundY), endPoint: CGPoint(x: 0, y: size.height))
        )

        // Ground line accent
        var linePath = Path()
        linePath.move(to: CGPoint(x: 0, y: groundY + 4))
        linePath.addQuadCurve(
            to: CGPoint(x: size.width * 0.3, y: groundY - 2),
            control: CGPoint(x: size.width * 0.15, y: groundY + 6)
        )
        linePath.addQuadCurve(
            to: CGPoint(x: size.width * 0.7, y: groundY + 2),
            control: CGPoint(x: size.width * 0.5, y: groundY - 5)
        )
        linePath.addQuadCurve(
            to: CGPoint(x: size.width, y: groundY - 1),
            control: CGPoint(x: size.width * 0.85, y: groundY + 5)
        )
        context.stroke(linePath, with: .color(Color.groveWarmSand.opacity(0.3)), lineWidth: 1.5)
    }

    // MARK: - Grass Tufts

    private func drawGrassTufts(context: GraphicsContext, size: CGSize, time: Double) {
        let grassColor = Color(red: 0.48, green: 0.62, blue: 0.38)
        let grassLight = Color(red: 0.55, green: 0.70, blue: 0.42)
        let sway = CGFloat(sin(time * 1.2) * 2)

        let tuftCount = 10
        for i in 0..<tuftCount {
            let t = CGFloat(i) / CGFloat(tuftCount - 1)
            let x = size.width * 0.05 + t * size.width * 0.9
            // Offset y slightly to follow ground curve
            let groundOffset = sin(Double(t) * .pi * 2) * 3
            let baseY = groundY + CGFloat(groundOffset)

            let tuftHeight: CGFloat = 8 + CGFloat(i % 3) * 3
            let lean = sway * (0.5 + CGFloat(i % 2) * 0.5)

            // Left blade
            var blade1 = Path()
            blade1.move(to: CGPoint(x: x - 2, y: baseY))
            blade1.addQuadCurve(
                to: CGPoint(x: x - 4 + lean * 0.6, y: baseY - tuftHeight),
                control: CGPoint(x: x - 5 + lean * 0.3, y: baseY - tuftHeight * 0.5)
            )
            context.stroke(blade1, with: .color(grassColor.opacity(0.5)), lineWidth: 1.2)

            // Center blade (tallest)
            var blade2 = Path()
            blade2.move(to: CGPoint(x: x, y: baseY))
            blade2.addQuadCurve(
                to: CGPoint(x: x + lean * 0.8, y: baseY - tuftHeight * 1.3),
                control: CGPoint(x: x + lean * 0.4, y: baseY - tuftHeight * 0.6)
            )
            context.stroke(blade2, with: .color(grassLight.opacity(0.6)), lineWidth: 1.0)

            // Right blade
            var blade3 = Path()
            blade3.move(to: CGPoint(x: x + 2, y: baseY))
            blade3.addQuadCurve(
                to: CGPoint(x: x + 5 + lean * 0.5, y: baseY - tuftHeight * 0.8),
                control: CGPoint(x: x + 4 + lean * 0.2, y: baseY - tuftHeight * 0.4)
            )
            context.stroke(blade3, with: .color(grassColor.opacity(0.4)), lineWidth: 1.0)
        }
    }

    // MARK: - Root Connections

    private func drawRootConnections(context: GraphicsContext, size: CGSize, time: Double) {
        for connection in connections {
            guard let friendSlot = friendSlots.first(where: { $0.id == connection.friendID }) else { continue }

            let start = CGPoint(x: userCenter.x, y: groundY + 6)
            let end = CGPoint(x: friendSlot.center.x, y: groundY + 6)

            let level = connection.level
            let depth = rootDepth(for: level)
            let midX = (start.x + end.x) / 2
            let undulation = CGFloat(sin(time * 0.3 + Double(connection.score) * 0.1)) * 2

            // Main root
            var rootPath = Path()
            rootPath.move(to: start)
            rootPath.addCurve(
                to: end,
                control1: CGPoint(x: midX - (end.x - start.x) * 0.15, y: groundY + depth + undulation),
                control2: CGPoint(x: midX + (end.x - start.x) * 0.15, y: groundY + depth - undulation)
            )

            let lineWidth = rootLineWidth(for: level)
            let opacity = rootOpacity(for: level)

            context.stroke(
                rootPath,
                with: .color(Color.groveTerracotta.opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            // Parallel root for deeper connections
            if level == .intertwined || level == .deep {
                let offset: CGFloat = level == .deep ? 5 : 3.5
                var parallelPath = Path()
                parallelPath.move(to: CGPoint(x: start.x, y: start.y + offset))
                parallelPath.addCurve(
                    to: CGPoint(x: end.x, y: end.y + offset),
                    control1: CGPoint(x: midX - (end.x - start.x) * 0.2, y: groundY + depth + offset + undulation * 0.7),
                    control2: CGPoint(x: midX + (end.x - start.x) * 0.2, y: groundY + depth + offset - undulation * 0.7)
                )
                context.stroke(
                    parallelPath,
                    with: .color(Color.groveTerracotta.opacity(opacity * 0.5)),
                    style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round)
                )
            }

            // Node dots for deep connections
            if level == .deep {
                for t in [0.33, 0.66] as [CGFloat] {
                    let dotX = start.x + (end.x - start.x) * t
                    let curveY = groundY + depth * (1 - 4 * (t - 0.5) * (t - 0.5)) + undulation * (t - 0.5)
                    var dot = Path()
                    dot.addEllipse(in: CGRect(x: dotX - 2.5, y: curveY - 2.5, width: 5, height: 5))
                    context.fill(dot, with: .color(Color.groveSage.opacity(0.45)))
                }
            }
        }
    }

    // MARK: - Particles

    private func drawParticles(context: GraphicsContext, size: CGSize, time: Double) {
        let particleCount = 5
        for i in 0..<particleCount {
            let seed = Double(i) * 47.3
            let cycleLength: Double = 8.0 + Double(i) * 1.5
            let phase = fmod(time * 0.4 + seed, cycleLength) / cycleLength

            let startX = size.width * CGFloat(0.15 + Double(i) * 0.15)
            let driftX = CGFloat(sin(time * 0.5 + seed)) * 12
            let x = startX + driftX
            let y = groundY - CGFloat(phase) * groundY * 0.8

            let alpha = phase < 0.1 ? phase * 10 : (phase > 0.85 ? (1 - phase) / 0.15 : 1.0)
            let radius: CGFloat = 1.5 + CGFloat(i % 2) * 0.8

            var dot = Path()
            dot.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(Color.groveWarmSand.opacity(0.2 * alpha)))
        }
    }

    // MARK: - Helpers

    func rootDepth(for level: RootLevel) -> CGFloat {
        switch level {
        case .scattered: return 15
        case .growing: return 25
        case .intertwined: return 35
        case .deep: return 50
        }
    }

    private func rootLineWidth(for level: RootLevel) -> CGFloat {
        switch level {
        case .scattered: return 1.5
        case .growing: return 2.5
        case .intertwined: return 3.5
        case .deep: return 5.0
        }
    }

    private func rootOpacity(for level: RootLevel) -> Double {
        switch level {
        case .scattered: return 0.25
        case .growing: return 0.4
        case .intertwined: return 0.6
        case .deep: return 0.8
        }
    }
}
