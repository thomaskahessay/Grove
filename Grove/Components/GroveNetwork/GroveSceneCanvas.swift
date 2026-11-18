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

    /// The ground's wavy top edge, as quadratic segments in fractions of the width:
    /// (end x, end y offset, control y offset). Controls sit halfway along x, so x is
    /// linear in t and the surface height at any x is easy to work out.
    private static let groundSegments: [(endX: CGFloat, endDY: CGFloat, controlDY: CGFloat)] = [
        (0.3, -2, 6), (0.7, 2, -5), (1.0, -1, 5),
    ]
    private static let groundStartDY: CGFloat = 4

    /// The ground's surface height at `x`, so plants can stand on the wavy line.
    static func surfaceY(atX x: CGFloat, width: CGFloat, groundY: CGFloat) -> CGFloat {
        guard width > 0 else { return groundY }
        let fx = min(max(x / width, 0), 1)
        var startX: CGFloat = 0
        var startDY = groundStartDY
        for segment in groundSegments {
            if fx <= segment.endX {
                let t = (fx - startX) / (segment.endX - startX)
                let u = 1 - t
                return groundY + u * u * startDY + 2 * u * t * segment.controlDY + t * t * segment.endDY
            }
            startX = segment.endX
            startDY = segment.endDY
        }
        return groundY + startDY
    }

    private static func groundEdge(width: CGFloat, groundY: CGFloat) -> Path {
        var path = Path()
        var startX: CGFloat = 0
        path.move(to: CGPoint(x: 0, y: groundY + groundStartDY))
        for segment in groundSegments {
            path.addQuadCurve(
                to: CGPoint(x: width * segment.endX, y: groundY + segment.endDY),
                control: CGPoint(x: width * (startX + segment.endX) / 2, y: groundY + segment.controlDY)
            )
            startX = segment.endX
        }
        return path
    }

    private func drawGroundBand(context: GraphicsContext, size: CGSize) {
        // Organic curved top edge
        var groundPath = Self.groundEdge(width: size.width, groundY: groundY)
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
        context.stroke(Self.groundEdge(width: size.width, groundY: groundY),
                       with: .color(Color.groveWarmSand.opacity(0.3)), lineWidth: 1.5)
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

    private static let rootColor = Color(red: 0.55, green: 0.42, blue: 0.31)

    /// How far below ground a connection's root runs: under the names, a little deeper
    /// for closer friends, and jittered per friend so the roots don't stack.
    static func rootDepth(for connection: RootConnection) -> CGFloat {
        let base: CGFloat
        switch connection.level {
        case .scattered: base = 34
        case .growing: base = 38
        case .intertwined: base = 42
        case .deep: base = 46
        }
        let jitter = CGFloat(PlantStyle.stableHash(connection.friendID) % 7) - 3
        return base + jitter
    }

    /// The root's lowest point, for placing its tap target.
    static func rootMidY(groundY: CGFloat, connection: RootConnection) -> CGFloat {
        groundY + 4 + rootDepth(for: connection) * 0.75
    }

    /// Each connection is a real-looking root between your plant and a friend's: it tapers
    /// away from both plants and wanders a little. Closer friendships
    /// add strands that twine around it. Near the surface it fades, so it reads as coming
    /// up from the soil instead of crossing the names.
    private func drawRootConnections(context: GraphicsContext, size: CGSize, time: Double) {
        for connection in connections {
            guard let friendSlot = friendSlots.first(where: { $0.id == connection.friendID }) else { continue }

            let level = connection.level
            let depth = Self.rootDepth(for: connection)
            let seed = Double(PlantStyle.stableHash(connection.friendID) % 1000) / 1000
            let p0 = CGPoint(x: userCenter.x, y: groundY + 4)
            let p3 = CGPoint(x: friendSlot.center.x, y: groundY + 4)
            let dx = p3.x - p0.x
            let p1 = CGPoint(x: p0.x + dx * 0.08, y: groundY + 4 + depth)
            let p2 = CGPoint(x: p3.x - dx * 0.08, y: groundY + 4 + depth)

            let strands: Int
            let width: CGFloat
            let opacity: Double
            switch level {
            case .scattered: strands = 1; width = 1.5; opacity = 0.32
            case .growing: strands = 1; width = 1.9; opacity = 0.42
            case .intertwined: strands = 2; width = 2.2; opacity = 0.5
            case .deep: strands = 3; width = 2.5; opacity = 0.58
            }

            // Fades in below the names, so roots seem to come up from the soil.
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Self.rootColor.opacity(0), Self.rootColor.opacity(opacity)]),
                startPoint: CGPoint(x: 0, y: groundY + 22),
                endPoint: CGPoint(x: 0, y: groundY + 38)
            )

            let samples = 40
            for strand in 0..<strands {
                let phase = Double(strand) * 2 * .pi / Double(strands)
                let isMain = strand == 0
                var centers: [CGPoint] = []
                var halfWidths: [CGFloat] = []
                for i in 0...samples {
                    let t = CGFloat(i) / CGFloat(samples)
                    var p = bezier(p0, p1, p2, p3, t)
                    let envelope = sin(.pi * t)
                    // A slow wander, plus a gentle twist for the extra strands.
                    p.y += CGFloat(sin(Double(t) * 7 + seed * 6)) * 1.6 * envelope
                    if !isMain {
                        p.y += CGFloat(sin(Double(t) * 12 + phase)) * 2.2 * envelope
                    }
                    centers.append(p)
                    let taper = 0.3 + 0.7 * pow(abs(1 - 2 * t), 1.4)
                    halfWidths.append(width * taper * (isMain ? 1 : 0.55) / 2)
                }
                let body = taperedPath(centers: centers, halfWidths: halfWidths)
                var strandContext = context
                if !isMain { strandContext.opacity = 0.7 }
                strandContext.fill(body, with: shading)
            }
        }
    }

    /// One filled shape along the centre line, so a tapering root has no seams.
    private func taperedPath(centers: [CGPoint], halfWidths: [CGFloat]) -> Path {
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in centers.indices {
            let a = centers[max(i - 1, 0)]
            let b = centers[min(i + 1, centers.count - 1)]
            let dx = b.x - a.x, dy = b.y - a.y
            let length = max(sqrt(dx * dx + dy * dy), 0.001)
            let normal = CGPoint(x: -dy / length, y: dx / length)
            let w = halfWidths[i]
            left.append(CGPoint(x: centers[i].x + normal.x * w, y: centers[i].y + normal.y * w))
            right.append(CGPoint(x: centers[i].x - normal.x * w, y: centers[i].y - normal.y * w))
        }
        var path = Path()
        guard let first = left.first else { return path }
        path.move(to: first)
        for point in left.dropFirst() + right.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func bezier(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * a.x + 3 * u * u * t * b.x + 3 * u * t * t * c.x + t * t * t * d.x
        let y = u * u * u * a.y + 3 * u * u * t * b.y + 3 * u * t * t * c.y + t * t * t * d.y
        return CGPoint(x: x, y: y)
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
}
