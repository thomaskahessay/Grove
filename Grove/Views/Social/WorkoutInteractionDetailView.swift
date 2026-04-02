import SwiftUI

struct WorkoutInteractionDetailView: View {
    let item: SharedWorkoutItem

    @Environment(CloudKitSocialService.self) private var socialService
    @State private var detailedInteractions: InteractionSummary?
    @State private var isLoading = true
    @State private var selectedSeedItem: SharedWorkoutItem?

    private var exercises: [SharedExercise] { item.parsedExercises }
    private var isOwnPost: Bool { item.userID == socialService.currentUserID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Stats
                statsSection

                // Exercises
                if !exercises.isEmpty {
                    exerciseSection
                }

                // Garden section (interactions)
                gardenSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.groveBackground)
        .navigationTitle(item.workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let interactions = await socialService.fetchDetailedInteractions(for: item.id) {
                detailedInteractions = interactions
            } else {
                detailedInteractions = socialService.interactionsByWorkout[item.id]
            }
            isLoading = false
        }
        .sheet(item: $selectedSeedItem) { seedItem in
            SeedPickerSheet(item: seedItem) { message, isCustom in
                Task {
                    await socialService.sendSeed(
                        to: seedItem.id,
                        recipientID: seedItem.userID,
                        message: message,
                        isCustom: isCustom
                    )
                    // Refresh
                    if let updated = await socialService.fetchDetailedInteractions(for: item.id) {
                        detailedInteractions = updated
                    }
                }
            }
            .presentationDetents([.medium])
        }

        // Bottom action bar — hidden on own posts
        .safeAreaInset(edge: .bottom) {
            if !isOwnPost {
                actionBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                avatarView(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.friendName)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            if item.exerciseCount > 0 {
                statColumn(value: "\(item.exerciseCount)", label: "Exercises")
            }
            if item.totalSets > 0 {
                statColumn(value: "\(item.totalSets)", label: "Sets")
            }
            if item.duration > 0 {
                statColumn(value: item.durationText, label: "Duration")
            }
            if item.prCount > 0 {
                statColumn(value: "\(item.prCount)", label: item.prCount == 1 ? "PR" : "PRs")
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.groveTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercises

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Exercises", systemImage: "dumbbell.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveText)

            ForEach(Array(exercises.enumerated()), id: \.offset) { _, exercise in
                HStack(spacing: 8) {
                    Image(systemName: exercise.isPR ? "star.fill" : "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(exercise.isPR ? Color.groveTerracotta : Color.groveSage)
                        .frame(width: 14)

                    Text(exercise.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.groveText)

                    if exercise.isPR {
                        Text("PR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.groveTerracotta)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let summary = exercise.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(Color.groveTextSecondary)
                    } else if exercise.setCount > 0 {
                        Text("\(exercise.setCount) sets")
                            .font(.caption)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Garden Section

    private var gardenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Garden", systemImage: "leaf.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveSage)

            if isLoading {
                SwiftUI.ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let interactions = detailedInteractions {
                // Waterers
                if !interactions.waterers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Watered by")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                        HStack(spacing: -6) {
                            ForEach(Array(interactions.waterers.prefix(6).enumerated()), id: \.offset) { _, waterer in
                                miniAvatar(name: waterer.displayName, imageData: waterer.profileImageData)
                            }
                            if interactions.waterers.count > 6 {
                                Text("+\(interactions.waterers.count - 6)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.groveTextSecondary)
                                    .padding(.leading, 10)
                            }
                        }
                    }
                }

                // Sunlighters
                if !interactions.sunlighters.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Sunlight from")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                        ForEach(Array(interactions.sunlighters.enumerated()), id: \.offset) { _, sunlighter in
                            HStack(spacing: 6) {
                                miniAvatar(name: sunlighter.senderName, imageData: sunlighter.senderProfileImageData)
                                Text(sunlighter.senderName)
                                    .font(.caption)
                                    .foregroundStyle(Color.groveText)
                                if let workoutName = sunlighter.earnedFromWorkoutName {
                                    Text("after \(workoutName)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.groveTextSecondary)
                                }
                            }
                        }
                    }
                }

                // Seeds
                if !interactions.seeds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.caption)
                                .foregroundStyle(Color.groveSage)
                            Text("Seeds")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                        ForEach(interactions.seeds) { seed in
                            HStack(alignment: .top, spacing: 8) {
                                miniAvatar(name: seed.senderName, imageData: seed.senderProfileImageData)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(seed.senderName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.groveText)
                                        Text(seed.timeAgo)
                                            .font(.caption2)
                                            .foregroundStyle(Color.groveTextSecondary)
                                    }
                                    Text("\"\(seed.message)\"")
                                        .font(.caption)
                                        .foregroundStyle(Color.groveText)
                                        .italic()
                                }
                            }
                        }
                    }
                }

                // Empty garden
                if interactions.waterers.isEmpty && interactions.sunlighters.isEmpty && interactions.seeds.isEmpty {
                    Text("No interactions yet. Be the first!")
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        InteractionBar(
            summary: detailedInteractions ?? socialService.interactionsByWorkout[item.id],
            showSunlight: socialService.availableSunlightCount > 0,
            onWater: {
                Task {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    let success = await socialService.sendWater(to: item.id, recipientID: item.userID)
                    if success {
                        if let updated = await socialService.fetchDetailedInteractions(for: item.id) {
                            detailedInteractions = updated
                        }
                    }
                }
            },
            onSeed: {
                selectedSeedItem = item
            },
            onSunlight: {
                Task {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    if let myWorkout = await socialService.myLatestSharedWorkoutRecordName() {
                        let success = await socialService.sendSunlight(
                            to: item.id,
                            recipientID: item.userID,
                            fromWorkoutRecordName: myWorkout
                        )
                        if success {
                            if let updated = await socialService.fetchDetailedInteractions(for: item.id) {
                                detailedInteractions = updated
                            }
                        }
                    }
                }
            },
            showCounts: true
        )
    }

    // MARK: - Helpers

    private func avatarView(size: CGFloat) -> some View {
        Circle()
            .fill(Color.groveSage.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                if let data = item.friendProfileImageData,
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials(for: item.friendName))
                        .font(size > 30 ? .caption : .system(size: 8))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                }
            }
    }

    private func miniAvatar(name: String, imageData: Data?) -> some View {
        Circle()
            .fill(Color.groveSage.opacity(0.15))
            .frame(width: 24, height: 24)
            .overlay {
                if let data = imageData,
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials(for: name))
                        .font(.system(size: 8))
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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: item.completedAt)
    }
}

#Preview("PR Workout — Full Garden") {
    NavigationStack {
        WorkoutInteractionDetailView(item: SocialPreviewData.feedItems[2])
    }
    .environment(SocialPreviewData.socialService)
}

#Preview("Regular Workout — Light Garden") {
    NavigationStack {
        WorkoutInteractionDetailView(item: SocialPreviewData.feedItems[1])
    }
    .environment(SocialPreviewData.socialService)
}

#Preview("No Interactions") {
    NavigationStack {
        WorkoutInteractionDetailView(item: SocialPreviewData.feedItems[5])
    }
    .environment(SocialPreviewData.socialService)
}
