import SwiftUI

struct GroveSlot: Identifiable {
    let id: String
    let center: CGPoint
    let plantSize: CGFloat
    let zIndex: Double
    let opacity: Double
}

struct GroveLayout {
    let userSlot: GroveSlot
    let friendSlots: [GroveSlot]
    let groundY: CGFloat
    let totalWidth: CGFloat
}

struct GroveLayoutEngine {

    /// Minimum spacing between friend plants
    private static let minSpacing: CGFloat = 70
    /// Comfortable plant size for friends
    private static let friendSize: CGFloat = 65

    static func compute(
        containerSize: CGSize,
        friends: [CKFriendProfile],
        connections: [RootConnection]
    ) -> GroveLayout {
        let viewportWidth = containerSize.width
        let height = containerSize.height
        let groundY = height * 0.62

        // Sort friends by connection score (highest first → closest to center)
        let sorted = friends.sorted { f1, f2 in
            let s1 = connections.first { $0.friendID == f1.id }?.score ?? 0
            let s2 = connections.first { $0.friendID == f2.id }?.score ?? 0
            return s1 > s2
        }

        let count = sorted.count

        // Calculate total width needed
        // Friends alternate left/right with `minSpacing` between each slot
        let friendsWidth = CGFloat(count) * minSpacing
        // Ensure at least the viewport, expand if friends need more room
        let totalWidth = max(viewportWidth, friendsWidth + minSpacing * 2)
        let centerX = totalWidth / 2

        // User plant — centered, large
        let userPlantSize: CGFloat = 120
        let userCenter = CGPoint(x: centerX, y: groundY - userPlantSize * 0.42)
        let userSlot = GroveSlot(
            id: "user",
            center: userCenter,
            plantSize: userPlantSize,
            zIndex: 10,
            opacity: 1.0
        )

        guard count > 0 else {
            return GroveLayout(userSlot: userSlot, friendSlots: [], groundY: groundY, totalWidth: totalWidth)
        }

        let plantSize = friendSize

        // Build x positions: alternate right/left from center, closest friends nearest
        var xPositions: [CGFloat] = []

        if count == 1 {
            xPositions = [centerX + minSpacing]
        } else if count == 2 {
            xPositions = [centerX - minSpacing, centerX + minSpacing]
        } else {
            // Generate slots radiating outward: right1, left1, right2, left2, ...
            var slots: [CGFloat] = []
            let maxSide = (count + 1) / 2  // enough slots for all friends
            for i in 1...maxSide {
                slots.append(centerX + minSpacing * CGFloat(i))   // right
                slots.append(centerX - minSpacing * CGFloat(i))   // left
            }
            // Take exactly `count` slots
            xPositions = Array(slots.prefix(count))
        }

        // Clamp and build friend slots
        let padding: CGFloat = plantSize * 0.4
        var friendSlots: [GroveSlot] = []

        for (index, friend) in sorted.enumerated() {
            let x = max(padding, min(xPositions[index], totalWidth - padding))

            // Vertical stagger: farther from center = slightly higher (depth)
            let distFromCenter = abs(x - centerX) / max(totalWidth / 2, 1)
            let yStagger = distFromCenter * 18
            let baseY = groundY - plantSize * 0.42
            let y = baseY - yStagger

            // Farther friends slightly dimmer
            let opacity = 1.0 - distFromCenter * 0.12

            friendSlots.append(GroveSlot(
                id: friend.id,
                center: CGPoint(x: x, y: y),
                plantSize: plantSize,
                zIndex: Double(count - index),
                opacity: opacity
            ))
        }

        return GroveLayout(userSlot: userSlot, friendSlots: friendSlots, groundY: groundY, totalWidth: totalWidth)
    }
}
