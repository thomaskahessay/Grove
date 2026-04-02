import SwiftUI

struct InteractionBreakdownSheet: View {
    let connection: RootConnection
    @Environment(CloudKitSocialService.self) private var socialService
    @State private var breakdown: InteractionBreakdown?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Friend avatar and name
                VStack(spacing: 10) {
                    Circle()
                        .fill(Color.groveSage.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay {
                            if let data = connection.friendProfileImageData,
                               let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else {
                                Text(initials(for: connection.friendName))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.groveSage)
                            }
                        }

                    Text(connection.friendName)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                }

                // Connection level
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: connection.level.icon)
                            .font(.caption)
                            .foregroundStyle(Color.groveSage)
                        Text(connection.level.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveText)
                    }

                    // Progress bar to next level
                    if connection.level.nextLevel != nil {
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.groveWarmSand.opacity(0.3))
                                    Capsule()
                                        .fill(Color.groveSage)
                                        .frame(width: geo.size.width * connection.progressToNextLevel)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("\(connection.score) pts")
                                    .font(.caption2)
                                    .foregroundStyle(Color.groveTextSecondary)
                                Spacer()
                                if let next = connection.level.nextLevel {
                                    Text("\(next.minScore) pts to \(next.rawValue)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.groveTextSecondary)
                                }
                            }
                        }
                    } else {
                        Text("Maximum level reached!")
                            .font(.caption)
                            .foregroundStyle(Color.groveSage)
                    }
                }
                .padding()
                .background(Color.groveCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Breakdown
                if isLoading {
                    SwiftUI.ProgressView()
                        .padding()
                } else if let breakdown {
                    VStack(spacing: 12) {
                        breakdownRow(icon: "drop.fill", color: .blue, label: "Waters",
                                     sent: breakdown.watersSent, received: breakdown.watersReceived)
                        breakdownRow(icon: "leaf.fill", color: .groveSage, label: "Seeds",
                                     sent: breakdown.seedsSent, received: breakdown.seedsReceived)
                        breakdownRow(icon: "sun.max.fill", color: .orange, label: "Sunlight",
                                     sent: breakdown.sunlightsSent, received: breakdown.sunlightsReceived)
                    }
                    .padding()
                    .background(Color.groveCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .background(Color.groveBackground)
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            breakdown = await socialService.fetchInteractionBreakdown(with: connection.friendID)
            isLoading = false
        }
    }

    private func breakdownRow(icon: String, color: Color, label: String, sent: Int, received: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.groveText)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(sent) sent")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
                Text("\(received) received")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }
}

#Preview("Deep Roots — Alex") {
    InteractionBreakdownSheet(
        connection: SocialPreviewData.rootConnections.first { $0.friendID == "user_alex" }!
    )
    .environment(SocialPreviewData.socialService)
}

#Preview("Intertwined — Sarah") {
    InteractionBreakdownSheet(
        connection: SocialPreviewData.rootConnections.first { $0.friendID == "user_sarah" }!
    )
    .environment(SocialPreviewData.socialService)
}

#Preview("Scattered — Taylor") {
    InteractionBreakdownSheet(
        connection: SocialPreviewData.rootConnections.first { $0.friendID == "user_taylor" }!
    )
    .environment(SocialPreviewData.socialService)
}
