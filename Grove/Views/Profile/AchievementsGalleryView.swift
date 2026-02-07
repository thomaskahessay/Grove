import SwiftUI
import SwiftData

struct AchievementsGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    private var currentUser: User? { users.first }

    @State private var progressData: [AchievementService.AchievementProgress] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryHeader

                ForEach(progressData, id: \.type) { progress in
                    AchievementGalleryCard(item: progress)
                }
            }
            .padding()
        }
        .background(Color.groveBackground)
        .onAppear {
            loadProgress()
        }
        .onChange(of: users.count) { _, _ in
            loadProgress()
        }
    }

    private func loadProgress() {
        if let user = currentUser {
            progressData = AchievementService.getProgress(for: user, context: modelContext)
        } else {
            // Show all achievements as locked when no user exists
            progressData = AchievementType.allCases.map { type in
                AchievementService.AchievementProgress(
                    type: type,
                    isUnlocked: false,
                    unlockedAt: nil,
                    currentValue: 0,
                    targetValue: 1
                )
            }
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 8) {
            let unlocked = progressData.filter { $0.isUnlocked }.count

            Text("\(unlocked) / 7")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveTerracotta)

            Text("Achievements Earned")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Gallery Card

private struct AchievementGalleryCard: View {
    let item: AchievementService.AchievementProgress

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: item.type.icon)
                    .font(.title)
                    .foregroundStyle(item.isUnlocked ? .white : .secondary)
                    .frame(width: 48, height: 48)
                    .background(item.isUnlocked ? Color.groveSage : Color.groveWarmSand.opacity(0.3))
                    .clipShape(Circle())

                if item.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.groveSage)
                        .background(Circle().fill(Color.groveCardBackground).frame(width: 14, height: 14))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.type.rawValue)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(item.isUnlocked ? Color.groveText : .secondary)

                Text(item.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !item.isUnlocked {
                    HStack(spacing: 8) {
                        SwiftUI.ProgressView(value: item.progressFraction, total: 1.0)
                            .tint(Color.groveSage)

                        Text("\(item.currentValue)/\(item.targetValue)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else if let date = item.unlockedAt {
                    Text("Earned \(date.formatted(.dateTime.month().day().year()))")
                        .font(.caption2)
                        .foregroundStyle(Color.groveSage)
                }
            }

            Spacer()

            if item.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.groveSage)
            }
        }
        .padding()
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(item.isUnlocked ? 1.0 : 0.8)
    }
}

#Preview {
    NavigationStack {
        AchievementsGalleryView()
    }
    .modelContainer(.preview)
}
