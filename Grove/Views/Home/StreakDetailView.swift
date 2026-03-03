import SwiftUI

struct StreakDetailView: View {
    let user: User

    private var stage: PlantStage {
        user.isStreakWilted
            ? PlantStage(rawValue: user.wiltedAtStage) ?? .seed
            : PlantStage.from(streak: user.currentStreak)
    }

    private var progressToNext: Double {
        stage.progressToNext(currentStreak: user.currentStreak)
    }

    private var daysUntilNext: Int? {
        stage.daysUntilNext(currentStreak: user.currentStreak)
    }

    private var motivationalMessage: String {
        if user.isStreakWilted {
            return MotivationalMessages.message(for: .streakBroken)
        } else {
            return MotivationalMessages.message(for: .continuing)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large plant
                StreakPlantView(
                    streak: user.currentStreak,
                    isWilted: user.isStreakWilted,
                    wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                    size: 300,
                    showLabel: false
                )
                .frame(maxWidth: .infinity)

                // Stage name + streak
                VStack(spacing: 4) {
                    Text(stage.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)

                    if user.isStreakWilted {
                        Text("Streak broken")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveMutedRust)
                    } else {
                        Text("\(user.currentStreak)-day streak")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveSage)
                    }
                }

                // Progress bar
                if !user.isStreakWilted, daysUntilNext != nil, let next = stage.nextStage {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.groveWarmSand.opacity(0.4))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.groveSage)
                                    .frame(width: geo.size.width * progressToNext, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("Day \(user.currentStreak) of \(next.minStreak) until \(next.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Stats row
                HStack(spacing: 0) {
                    StatItem(label: "Current", value: "\(user.currentStreak)")
                    Divider().frame(height: 40)
                    StatItem(label: "Longest", value: "\(user.longestStreak)")
                    Divider().frame(height: 40)
                    StatItem(label: "Previous", value: "\(user.previousStreak)")
                }
                .padding(16)
                .background(Color.groveCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Evolution timeline
                VStack(alignment: .leading, spacing: 12) {
                    Text("Evolution")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                        .padding(.horizontal)

                    EvolutionTimelineView(currentStage: stage)
                }

                // Motivational message
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.groveSage)
                    Text(motivationalMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.groveText)
                        .italic()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.groveCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(Color.groveBackground)
        .navigationTitle("Your Grove")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
