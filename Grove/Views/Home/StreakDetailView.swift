import SwiftUI

struct StreakDetailView: View {
    let user: User

    @State private var previewStage: PlantStage? = nil
    @State private var previewTimer: Timer? = nil

    private var stage: PlantStage {
        user.isStreakWilted
            ? PlantStage(rawValue: user.wiltedAtStage) ?? .seed
            : PlantStage.from(streak: user.currentStreak)
    }

    private var displayedStage: PlantStage {
        previewStage ?? stage
    }

    private var isPreviewingFuture: Bool {
        guard let preview = previewStage else { return false }
        return preview > stage
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
                ZStack {
                    StreakPlantView(
                        streak: previewStage != nil ? displayedStage.minStreak : user.currentStreak,
                        isWilted: previewStage == nil && user.isStreakWilted,
                        wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                        size: 300,
                        showLabel: false
                    )
                    .saturation(isPreviewingFuture ? 0 : 1)
                    .opacity(isPreviewingFuture ? 0.5 : 1)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.3), value: previewStage)

                // Stage name + streak
                VStack(spacing: 4) {
                    Text(displayedStage.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(isPreviewingFuture ? .secondary : Color.groveText)

                    if previewStage != nil {
                        if isPreviewingFuture {
                            Text("Day \(displayedStage.minStreak)+ to unlock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Reached!")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveSage)
                        }
                    } else if user.isStreakWilted {
                        Text("Streak broken")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveMutedRust)
                    } else {
                        Text("\(user.currentStreak)-day streak")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveSage)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: previewStage)

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

                    EvolutionTimelineView(currentStage: stage) { tappedStage in
                        previewTimer?.invalidate()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            previewStage = tappedStage
                        }
                        previewTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { _ in
                            Task { @MainActor in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    previewStage = nil
                                }
                            }
                        }
                    }
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
