import SwiftUI

struct FeedItemCard: View {
    let item: SharedWorkoutItem
    let interactions: InteractionSummary?
    let showSunlight: Bool
    var isOwnPost: Bool = false
    @Binding var triggerSeedAnimation: Bool
    let onProfileTap: () -> Void
    let onWater: () -> Void
    let onSeed: () -> Void
    let onSunlight: () -> Void

    @State private var showWaterAnimation = false
    @State private var showSunlightAnimation = false
    @State private var showSeedAnimation = false

    private var exercises: [SharedExercise] { item.parsedExercises }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: avatar + name + time ago
            if isOwnPost {
                HStack(spacing: 8) {
                    Text("Your Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)

                    Spacer()

                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    onProfileTap()
                } label: {
                    HStack(spacing: 8) {
                        avatarView

                        Text(item.friendName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveText)

                        Spacer()

                        Text(item.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            // PR banner
            if item.hasPRs {
                prBanner
            }

            // Workout title
            Text(item.workoutName)
                .font(.headline)
                .foregroundStyle(Color.groveText)

            // Stats row
            statsRow
                .padding(.vertical, 8)
                .background(Color.groveWarmSand.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Exercise list (if available)
            if !exercises.isEmpty {
                exerciseList
            }

            // Interaction bar — hidden on own posts
            if !isOwnPost {
                InteractionBar(
                    summary: interactions,
                    showSunlight: showSunlight,
                    onWater: {
                        showWaterAnimation = true
                        onWater()
                    },
                    onSeed: {
                        onSeed()
                    },
                    onSunlight: {
                        showSunlightAnimation = true
                        onSunlight()
                    }
                )
            }
        }
        .padding(14)
        .background {
            CardSceneBackgroundView(interactions: interactions, hasPRs: item.hasPRs)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.groveTerracotta.opacity(0.4), Color.groveTerracotta.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .opacity(item.hasPRs ? 1 : 0)
        )
        .waterShimmer(active: interactions?.isWaterShimmerActive ?? false)
        .sunlightGlow(active: interactions?.isSunlightGlowActive ?? false)
        .shadow(
            color: item.hasPRs ? Color.groveTerracotta.opacity(0.15) : .black.opacity(0.05),
            radius: item.hasPRs ? 10 : 6,
            y: 2
        )
        .overlay {
            if showWaterAnimation {
                WaterTapAnimation {
                    showWaterAnimation = false
                }
            }
            if showSunlightAnimation {
                SunlightTapAnimation {
                    showSunlightAnimation = false
                }
            }
            if showSeedAnimation {
                SeedTapAnimation {
                    showSeedAnimation = false
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: triggerSeedAnimation) { _, shouldAnimate in
            if shouldAnimate {
                showSeedAnimation = true
                // Reset the trigger so it can fire again
                triggerSeedAnimation = false
            }
        }
    }

    // MARK: - PR Banner

    private var prBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Color.groveTerracotta)

            Text(item.prCount == 1 ? "Personal Record" : "\(item.prCount) Personal Records")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveTerracotta)

            Spacer()

            Text("PR")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.groveTerracotta)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.groveTerracotta.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            if item.exerciseCount > 0 {
                feedStatColumn(value: "\(item.exerciseCount)", label: "Exercises")
            }
            if item.totalSets > 0 {
                feedStatColumn(value: "\(item.totalSets)", label: "Sets")
            }
            if item.duration > 0 {
                feedStatColumn(value: item.durationText, label: "Duration")
            }
            if item.prCount > 0 {
                feedStatColumn(value: "\(item.prCount)", label: item.prCount == 1 ? "PR" : "PRs", isPR: true)
            }
        }
    }

    private func feedStatColumn(value: String, label: String, isPR: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(isPR ? Color.groveTerracotta : Color.groveText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(isPR ? Color.groveTerracotta.opacity(0.8) : Color.groveTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(exercises.enumerated()), id: \.offset) { _, exercise in
                exerciseRow(exercise)
            }
        }
    }

    private func exerciseRow(_ exercise: SharedExercise) -> some View {
        HStack(spacing: 6) {
            Image(systemName: exercise.isPR ? "star.fill" : "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(exercise.isPR ? Color.groveTerracotta : Color.groveSage)
                .frame(width: 14)

            Text(exercise.name)
                .font(.caption)
                .fontWeight(exercise.isPR ? .semibold : .regular)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)

            if exercise.isPR {
                Text("PR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.groveTerracotta)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 4)

            if let summary = exercise.summary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
                    .fixedSize()
            } else if exercise.setCount > 0 {
                Text("\(exercise.setCount) sets")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
                    .fixedSize()
            }
        }
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Circle()
            .fill(Color.groveSage.opacity(0.15))
            .frame(width: 32, height: 32)
            .overlay {
                if let data = item.friendProfileImageData,
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials(for: item.friendName))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
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

// Animation overlays moved to:
// - Components/FeedCard/WaterTapAnimation.swift
// - Components/FeedCard/SeedTapAnimation.swift
// - Components/FeedCard/SunlightTapAnimation.swift

// MARK: - Previews

#Preview("PR + Watered + Sunlit + Seeds") {
    let items = SocialPreviewData.feedItems
    let interactions = SocialPreviewData.interactionsByWorkout
    ScrollView {
        VStack(spacing: 16) {
            // Sarah's Push Day — PR, watered, sunlit, 3 seeds
            FeedItemCard(
                item: items[0],
                interactions: interactions["workout_1"],
                showSunlight: true,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
            // Alex's Leg Day — 2 PRs, 5 waters, 2 sunlights, 4 seeds
            FeedItemCard(
                item: items[2],
                interactions: interactions["workout_3"],
                showSunlight: false,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
        }
        .padding()
    }
    .background(Color.groveBackground)
}

#Preview("Lightly Interacted") {
    let items = SocialPreviewData.feedItems
    let interactions = SocialPreviewData.interactionsByWorkout
    ScrollView {
        VStack(spacing: 16) {
            // Mike's Pull Day — 2 waters, 1 seed, no sunlight
            FeedItemCard(
                item: items[1],
                interactions: interactions["workout_2"],
                showSunlight: true,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
            // Jordan's Upper Body — 1 water only
            FeedItemCard(
                item: items[3],
                interactions: interactions["workout_4"],
                showSunlight: false,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
        }
        .padding()
    }
    .background(Color.groveBackground)
}

#Preview("No Interactions") {
    let items = SocialPreviewData.feedItems
    ScrollView {
        FeedItemCard(
            item: items[5],
            interactions: .empty(for: "workout_6"),
            showSunlight: true,
            triggerSeedAnimation: .constant(false),
            onProfileTap: {},
            onWater: {},
            onSeed: {},
            onSunlight: {}
        )
        .padding()
    }
    .background(Color.groveBackground)
}
