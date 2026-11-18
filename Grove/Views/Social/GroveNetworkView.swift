import SwiftUI

struct GroveNetworkView: View {
    let connections: [RootConnection]
    let friends: [CKFriendProfile]
    let userStreak: Int
    let isWilted: Bool
    let wiltedAtStage: Int
    /// Most recent workout per user ID, for bloom (today) and droop (quiet 4+ days).
    var lastWorkoutByUser: [String: Date] = [:]
    var userTrainedToday: Bool = false
    /// The signed-in person's Apple user ID, so their plant matches everywhere else.
    var userIdentity: String?
    /// This week's progress per friend ID, and yours, for the goal dots under each name.
    var weekByUser: [String: GroveWeekProgress] = [:]
    var userWeek: GroveWeekProgress?
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
                                .frame(width: layout.totalWidth, height: 170)
                        }
                        .defaultScrollAnchor(.center)
                    } else {
                        groveContent(layout: layout, viewportWidth: geo.size.width)
                    }
                }
            }
        .frame(height: 170)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.groveGroveWindowBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.groveGroveWindowBorder, lineWidth: 1)
        )
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
                    let midY = GroveSceneCanvas.rootMidY(groundY: layout.groundY, connection: connection)

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
                        style: PlantStyle(identity: friend.id),
                        plantSize: slot.plantSize,
                        label: String(friend.displayName.prefix(8)),
                        week: weekByUser[friend.id],
                        isUser: false,
                        activity: GroveActivity.from(lastWorkout: lastWorkoutByUser[friend.id]),
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
                style: PlantStyle(identity: userIdentity),
                plantSize: layout.userSlot.plantSize,
                label: "You",
                week: userWeek,
                isUser: true,
                activity: userTrainedToday ? .today : .recent,
                onTap: {}
            )
            .position(layout.userSlot.center)
            .zIndex(10)

            // Empty state hint
            if friends.isEmpty {
                Text("Your grove grows as people join Grove")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary.opacity(0.6))
                    .position(x: viewportWidth / 2, y: layout.groundY + 30)
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
