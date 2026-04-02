import SwiftUI

struct GroveNetworkView: View {
    let connections: [RootConnection]
    let friends: [CKFriendProfile]
    let userStreak: Int
    let isWilted: Bool
    let wiltedAtStage: Int
    let onFriendTap: (String) -> Void
    let onConnectionTap: (RootConnection) -> Void

    @State private var swayPhase: Double = 0

    private var plantStage: PlantStage {
        if isWilted {
            return PlantStage(rawValue: wiltedAtStage) ?? .seed
        }
        return PlantStage.from(streak: userStreak)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Your Grove")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveTextSecondary)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawGrove(context: context, size: size, time: time)
                }
                .frame(height: 180)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(at: location, in: CGSize(width: UIScreen.main.bounds.width - 32, height: 180))
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Drawing

    private func drawGrove(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
        let radius = min(size.width, size.height) * 0.32

        // Draw ground/soil line
        let groundY = size.height * 0.65
        var groundPath = Path()
        groundPath.move(to: CGPoint(x: 0, y: groundY))
        groundPath.addLine(to: CGPoint(x: size.width, y: groundY))
        context.stroke(groundPath, with: .color(Color.groveWarmSand.opacity(0.4)), lineWidth: 1)

        // Fill soil area
        var soilPath = Path()
        soilPath.addRect(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY))
        context.fill(soilPath, with: .color(Color.groveWarmSand.opacity(0.08)))

        // Calculate friend positions
        let friendPositions = calculateFriendPositions(center: center, radius: radius, groundY: groundY)

        // Draw root connections underground
        for (index, connection) in connections.enumerated() {
            if let pos = friendPositions[connection.friendID] {
                drawRoot(context: context, from: CGPoint(x: center.x, y: groundY + 8),
                         to: CGPoint(x: pos.x, y: groundY + 8),
                         level: connection.level, groundY: groundY, size: size, time: time)
            }
        }

        // Draw friend plants
        for friend in friends {
            let pos = friendPositions[friend.id] ?? center
            drawFriendPlant(context: context, at: pos, name: friend.displayName,
                           connection: connections.first { $0.friendID == friend.id },
                           time: time, groundY: groundY)
        }

        // Draw user's plant (center, larger)
        drawUserPlant(context: context, at: center, time: time, groundY: groundY)
    }

    private func calculateFriendPositions(center: CGPoint, radius: CGFloat, groundY: CGFloat) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let sortedFriends = friends.sorted { f1, f2 in
            let score1 = connections.first { $0.friendID == f1.id }?.score ?? 0
            let score2 = connections.first { $0.friendID == f2.id }?.score ?? 0
            return score1 > score2
        }

        let count = sortedFriends.count
        guard count > 0 else { return positions }

        for (index, friend) in sortedFriends.enumerated() {
            let angle: CGFloat
            if count == 1 {
                angle = -.pi / 2
            } else {
                // Spread across a semicircle above ground
                let spread = min(.pi * 0.8, .pi)
                let startAngle = -.pi / 2 - spread / 2
                angle = startAngle + spread * CGFloat(index) / CGFloat(count - 1)
            }

            let connectionScore = connections.first { $0.friendID == friend.id }?.score ?? 0
            let distanceFactor = max(0.6, 1.0 - Double(connectionScore) / 100.0)
            let dist = radius * distanceFactor

            let x = center.x + cos(angle) * dist
            let y = min(center.y + sin(angle) * dist, groundY - 20)

            positions[friend.id] = CGPoint(x: x, y: y)
        }

        return positions
    }

    private func drawRoot(context: GraphicsContext, from start: CGPoint, to end: CGPoint,
                          level: RootLevel, groundY: CGFloat, size: CGSize, time: Double) {
        let midY = groundY + (size.height - groundY) * 0.4
        let controlX = (start.x + end.x) / 2 + sin(time * 0.3) * 2

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: controlX, y: midY))

        let lineWidth: CGFloat
        let opacity: Double

        switch level {
        case .scattered:
            lineWidth = 1.0
            opacity = 0.3
        case .growing:
            lineWidth = 2.0
            opacity = 0.5
        case .intertwined:
            lineWidth = 3.0
            opacity = 0.7
        case .deep:
            lineWidth = 4.0
            opacity = 0.9
        }

        context.stroke(path, with: .color(Color.groveWarmSand.opacity(opacity)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

        // Draw small decorations for higher levels
        if level == .intertwined || level == .deep {
            let dotCount = level == .deep ? 3 : 1
            for i in 0..<dotCount {
                let t = 0.3 + Double(i) * 0.2
                let dotX = start.x + (end.x - start.x) * t
                let dotY = start.y + (midY - start.y) * t * 2 * (1 - t) + (end.y - start.y) * t * t
                var dot = Path()
                dot.addEllipse(in: CGRect(x: dotX - 2, y: dotY - 2, width: 4, height: 4))
                context.fill(dot, with: .color(level == .deep ? Color.groveSage.opacity(0.6) : Color.groveWarmSand.opacity(0.5)))
            }
        }
    }

    private func drawUserPlant(context: GraphicsContext, at point: CGPoint, time: Double, groundY: CGFloat) {
        // Simple plant representation
        let sway = sin(time * 1.2) * 3
        let stemHeight: CGFloat = 28

        // Stem
        var stem = Path()
        stem.move(to: CGPoint(x: point.x, y: point.y + 8))
        stem.addQuadCurve(
            to: CGPoint(x: point.x + sway, y: point.y - stemHeight),
            control: CGPoint(x: point.x + sway * 0.5, y: point.y - stemHeight * 0.5)
        )
        context.stroke(stem, with: .color(Color.groveSage), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // Canopy/top
        var canopy = Path()
        canopy.addEllipse(in: CGRect(x: point.x - 14 + sway, y: point.y - stemHeight - 14, width: 28, height: 22))
        context.fill(canopy, with: .color(Color.groveSage.opacity(0.7)))

        // "You" label
        context.draw(
            Text("You")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color.groveText),
            at: CGPoint(x: point.x, y: point.y + 18)
        )
    }

    private func drawFriendPlant(context: GraphicsContext, at point: CGPoint, name: String,
                                  connection: RootConnection?, time: Double, groundY: CGFloat) {
        let sway = sin(time * 1.0 + point.x * 0.01) * 2
        let stemHeight: CGFloat = 18

        // Stem
        var stem = Path()
        stem.move(to: CGPoint(x: point.x, y: point.y + 6))
        stem.addQuadCurve(
            to: CGPoint(x: point.x + sway, y: point.y - stemHeight),
            control: CGPoint(x: point.x + sway * 0.5, y: point.y - stemHeight * 0.5)
        )
        context.stroke(stem, with: .color(Color.groveSage.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Leaves
        var leaf = Path()
        leaf.addEllipse(in: CGRect(x: point.x - 8 + sway, y: point.y - stemHeight - 8, width: 16, height: 14))
        let leafOpacity = connection.map { Double(min($0.score, 80)) / 80.0 * 0.4 + 0.3 } ?? 0.3
        context.fill(leaf, with: .color(Color.groveSage.opacity(leafOpacity)))

        // Name label
        let displayName = String(name.prefix(8))
        context.draw(
            Text(displayName)
                .font(.system(size: 8))
                .foregroundColor(Color.groveTextSecondary),
            at: CGPoint(x: point.x, y: point.y + 14)
        )
    }

    // MARK: - Tap Handling

    @MainActor
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
        let radius = min(size.width, size.height) * 0.32
        let groundY = size.height * 0.65

        let friendPositions = calculateFriendPositions(center: center, radius: radius, groundY: groundY)

        // Check if tapped on a friend plant
        for (friendID, pos) in friendPositions {
            let distance = sqrt(pow(location.x - pos.x, 2) + pow(location.y - pos.y, 2))
            if distance < 25 {
                onFriendTap(friendID)
                return
            }
        }

        // Check if tapped on a root connection (below ground)
        if location.y > groundY {
            for connection in connections {
                if let pos = friendPositions[connection.friendID] {
                    let midX = (center.x + pos.x) / 2
                    let distance = sqrt(pow(location.x - midX, 2) + pow(location.y - (groundY + 20), 2))
                    if distance < 30 {
                        onConnectionTap(connection)
                        return
                    }
                }
            }
        }
    }
}

#Preview("Grove Network — 7 Friends") {
    VStack {
        GroveNetworkView(
            connections: SocialPreviewData.rootConnections,
            friends: SocialPreviewData.friends,
            userStreak: 14,
            isWilted: false,
            wiltedAtStage: 0,
            onFriendTap: { _ in },
            onConnectionTap: { _ in }
        )
    }
    .padding()
    .background(Color.groveBackground)
}

#Preview("Grove Network — 3 Friends") {
    VStack {
        GroveNetworkView(
            connections: Array(SocialPreviewData.rootConnections.prefix(3)),
            friends: Array(SocialPreviewData.friends.prefix(3)),
            userStreak: 5,
            isWilted: false,
            wiltedAtStage: 0,
            onFriendTap: { _ in },
            onConnectionTap: { _ in }
        )
    }
    .padding()
    .background(Color.groveBackground)
}

#Preview("Grove Network — Wilted") {
    VStack {
        GroveNetworkView(
            connections: SocialPreviewData.rootConnections,
            friends: SocialPreviewData.friends,
            userStreak: 0,
            isWilted: true,
            wiltedAtStage: 3,
            onFriendTap: { _ in },
            onConnectionTap: { _ in }
        )
    }
    .padding()
    .background(Color.groveBackground)
}
