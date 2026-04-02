import SwiftUI

struct GroveNetworkView: View {
    let connections: [RootConnection]
    let friends: [CKFriendProfile]
    let userStreak: Int
    let isWilted: Bool
    let wiltedAtStage: Int
    let onFriendTap: (String) -> Void
    let onConnectionTap: (RootConnection) -> Void

    private var userPlantStage: PlantStage {
        if isWilted {
            return PlantStage(rawValue: wiltedAtStage) ?? .seed
        }
        return PlantStage.from(streak: userStreak)
    }

    var body: some View {
        GeometryReader { geo in
                let layout = GroveLayoutEngine.compute(
                    containerSize: geo.size,
                    friends: friends,
                    connections: connections
                )
                let needsScroll = layout.totalWidth > geo.size.width

                Group {
                    if needsScroll {
                        ScrollView(.horizontal, showsIndicators: false) {
                            groveContent(layout: layout, viewportWidth: geo.size.width)
                                .frame(width: layout.totalWidth, height: 300)
                        }
                        .defaultScrollAnchor(.center)
                    } else {
                        groveContent(layout: layout, viewportWidth: geo.size.width)
                    }
                }
            }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func groveContent(layout: GroveLayout, viewportWidth: CGFloat) -> some View {
        ZStack {
            // Layer 1: Atmospheric background + roots
            GroveSceneCanvas(
                groundY: layout.groundY,
                userCenter: layout.userSlot.center,
                friendSlots: layout.friendSlots,
                connections: connections,
                userStage: userPlantStage,
                isWilted: isWilted
            )

            // Layer 2: Root connection tap targets
            ForEach(connections) { connection in
                if let friendSlot = layout.friendSlots.first(where: { $0.id == connection.friendID }) {
                    let midX = (layout.userSlot.center.x + friendSlot.center.x) / 2
                    let depth = rootDepth(for: connection.level)
                    let midY = layout.groundY + depth * 0.6

                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .position(x: midX, y: midY)
                        .onTapGesture { onConnectionTap(connection) }
                }
            }

            // Layer 3: Friend plants
            ForEach(layout.friendSlots) { slot in
                if let friend = friends.first(where: { $0.id == slot.id }) {
                    GrovePlantSlot(
                        streak: friend.currentStreak,
                        isWilted: false,
                        wiltedAtStage: .seed,
                        plantSize: slot.plantSize,
                        label: String(friend.displayName.prefix(8)),
                        sublabel: friend.currentStreak > 0 ? "\(friend.currentStreak)d" : nil,
                        isUser: false,
                        onTap: { onFriendTap(friend.id) }
                    )
                    .position(slot.center)
                    .zIndex(slot.zIndex)
                    .opacity(slot.opacity)
                }
            }

            // Layer 4: User plant (always on top)
            GrovePlantSlot(
                streak: userStreak,
                isWilted: isWilted,
                wiltedAtStage: PlantStage(rawValue: wiltedAtStage) ?? .seed,
                plantSize: layout.userSlot.plantSize,
                label: "You",
                sublabel: isWilted ? "Wilted" : (userStreak > 0 ? "\(userStreak)d" : nil),
                isUser: true,
                onTap: {}
            )
            .position(layout.userSlot.center)
            .zIndex(10)

            // Empty state hint
            if friends.isEmpty {
                Text("Invite friends to grow your grove")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary.opacity(0.6))
                    .position(x: viewportWidth / 2, y: layout.groundY + 30)
            }
        }
    }

    private func rootDepth(for level: RootLevel) -> CGFloat {
        switch level {
        case .scattered: return 15
        case .growing: return 25
        case .intertwined: return 35
        case .deep: return 50
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

#Preview("Grove Network — 1 Friend") {
    VStack {
        GroveNetworkView(
            connections: Array(SocialPreviewData.rootConnections.prefix(1)),
            friends: Array(SocialPreviewData.friends.prefix(1)),
            userStreak: 60,
            isWilted: false,
            wiltedAtStage: 0,
            onFriendTap: { _ in },
            onConnectionTap: { _ in }
        )
    }
    .padding()
    .background(Color.groveBackground)
}

#Preview("Grove Network — No Friends") {
    VStack {
        GroveNetworkView(
            connections: [],
            friends: [],
            userStreak: 7,
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
