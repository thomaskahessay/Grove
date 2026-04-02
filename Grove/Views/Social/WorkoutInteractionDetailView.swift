import SwiftUI
import SwiftData

struct WorkoutInteractionDetailView: View {
    let item: SharedWorkoutItem

    @Environment(CloudKitSocialService.self) private var socialService
    @Query private var users: [User]
    @State private var detailedInteractions: InteractionSummary?
    @State private var isLoading = true
    @State private var selectedSeedItem: SharedWorkoutItem?

    private var currentUser: User? { users.first }
    private var myName: String { currentUser?.displayName ?? "You" }
    private var myProfileImageData: Data? { currentUser?.profileImageData }
    private var exercises: [SharedExercise] { item.parsedExercises }
    private var isOwnPost: Bool { item.userID == socialService.currentUserID }

    private var heroInteractions: InteractionSummary? {
        detailedInteractions ?? socialService.interactionsByWorkout[item.id]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero: plant scene behind header + stats
                heroSection

                // Exercises
                if !exercises.isEmpty {
                    exerciseSection
                }

                // Garden section (interactions)
                gardenSection
            }
            .padding(.bottom, 32)
        }
        .background(Color.groveBackground)
        .navigationTitle(item.workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let interactions = await socialService.fetchDetailedInteractions(for: item.id) {
                detailedInteractions = patchMyProfile(in: interactions)
            } else if let cached = socialService.interactionsByWorkout[item.id] {
                detailedInteractions = patchMyProfile(in: cached)
            }
            isLoading = false
        }
        .sheet(item: $selectedSeedItem) { seedItem in
            SeedPickerSheet(item: seedItem) { message, isCustom in
                // Optimistic local update
                var summary = detailedInteractions ?? .empty(for: item.id)
                summary.seeds.append(SeedMessage(
                    id: UUID().uuidString,
                    senderID: socialService.currentUserID ?? "",
                    senderName: myName,
                    senderProfileImageData: myProfileImageData,
                    message: String(message.prefix(60)),
                    isCustom: isCustom,
                    createdAt: Date()
                ))
                detailedInteractions = summary

                Task {
                    await socialService.sendSeed(
                        to: seedItem.id,
                        recipientID: seedItem.userID,
                        message: message,
                        isCustom: isCustom
                    )
                }
            }
            .presentationDetents([.medium])
        }

    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            CardSceneBackgroundView(interactions: heroInteractions, hasPRs: item.hasPRs, soilPosition: 0.55)

            VStack(alignment: .leading, spacing: 0) {
                // Name + date at the top
                headerSection
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Spacer(minLength: 16)

                // Stats card sits at the bottom, plants sprout from behind it
                statsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
        .waterShimmer(active: heroInteractions?.isWaterShimmerActive ?? false)
        .sunlightGlow(active: heroInteractions?.isSunlightGlowActive ?? false)
        .shadow(
            color: item.hasPRs ? Color.groveTerracotta.opacity(0.15) : .black.opacity(0.05),
            radius: item.hasPRs ? 10 : 6,
            y: 2
        )
        .padding(.horizontal)
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
        .background(.ultraThinMaterial)
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
        .padding(.horizontal)
    }

    // MARK: - Garden Section

    private var gardenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Label("Garden", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveSage)

                // Interaction counts
                if let interactions = detailedInteractions {
                    let waterCount = interactions.waterCount
                    let seedCount = interactions.seeds.count
                    let sunlightCount = interactions.sunlightCount
                    if waterCount > 0 || seedCount > 0 || sunlightCount > 0 {
                        HStack(spacing: 10) {
                            if waterCount > 0 {
                                interactionCount(icon: "drop.fill", count: waterCount, color: .blue)
                            }
                            if sunlightCount > 0 {
                                interactionCount(icon: "sun.max.fill", count: sunlightCount, color: .orange)
                            }
                            if seedCount > 0 {
                                interactionCount(icon: "leaf.fill", count: seedCount, color: .groveSage)
                            }
                        }
                    }
                }

                Spacer()
            }

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

                // Action buttons (hidden on own posts)
                if !isOwnPost {
                    Divider()
                        .padding(.vertical, 4)

                    gardenActions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Profile Patching

    /// Replace "You" placeholders from the server with the real user profile data
    private func patchMyProfile(in summary: InteractionSummary) -> InteractionSummary {
        guard let myID = socialService.currentUserID else { return summary }
        var patched = summary

        patched.waterers = summary.waterers.map { info in
            guard info.userID == myID else { return info }
            return InteractorInfo(userID: myID, displayName: myName, profileImageData: myProfileImageData)
        }

        patched.sunlighters = summary.sunlighters.map { info in
            guard info.senderID == myID else { return info }
            return SunlightInfo(senderID: myID, senderName: myName, senderProfileImageData: myProfileImageData, earnedFromWorkoutName: info.earnedFromWorkoutName)
        }

        patched.seeds = summary.seeds.map { seed in
            guard seed.senderID == myID else { return seed }
            return SeedMessage(id: seed.id, senderID: myID, senderName: myName, senderProfileImageData: myProfileImageData, message: seed.message, isCustom: seed.isCustom, createdAt: seed.createdAt)
        }

        return patched
    }

    // MARK: - Garden Actions

    private var iWatered: Bool { detailedInteractions?.iWatered ?? socialService.interactionsByWorkout[item.id]?.iWatered ?? false }
    private var iSunlit: Bool { detailedInteractions?.iSunlit ?? socialService.interactionsByWorkout[item.id]?.iSunlit ?? false }

    private func applyOptimisticWater() {
        var summary = detailedInteractions ?? .empty(for: item.id)
        summary.waterCount += 1
        summary.iWatered = true
        summary.latestWaterDate = Date()
        summary.waterers.append(InteractorInfo(userID: socialService.currentUserID ?? "", displayName: myName, profileImageData: myProfileImageData))
        detailedInteractions = summary
    }

    private func applyOptimisticSunlight() {
        var summary = detailedInteractions ?? .empty(for: item.id)
        summary.sunlightCount += 1
        summary.iSunlit = true
        summary.latestSunlightDate = Date()
        summary.sunlighters.append(SunlightInfo(senderID: socialService.currentUserID ?? "", senderName: myName, senderProfileImageData: myProfileImageData, earnedFromWorkoutName: nil))
        detailedInteractions = summary
    }

    private var gardenActions: some View {
        HStack(spacing: 0) {
            if !iWatered {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    applyOptimisticWater()
                    Task {
                        let success = await socialService.sendWater(to: item.id, recipientID: item.userID)
                        if !success {
                            // Revert on failure — re-fetch from server
                            if let updated = await socialService.fetchDetailedInteractions(for: item.id) {
                                detailedInteractions = updated
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "drop")
                            .font(.caption)
                        Text("Water")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            Button {
                selectedSeedItem = item
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "leaf")
                        .font(.caption)
                    Text("Seed")
                        .font(.caption)
                }
                .foregroundStyle(Color.groveSage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if socialService.availableSunlightCount > 0 && !iSunlit {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    applyOptimisticSunlight()
                    Task {
                        if let myWorkout = await socialService.myLatestSharedWorkoutRecordName() {
                            let success = await socialService.sendSunlight(
                                to: item.id,
                                recipientID: item.userID,
                                fromWorkoutRecordName: myWorkout
                            )
                            if !success {
                                if let updated = await socialService.fetchDetailedInteractions(for: item.id) {
                                    detailedInteractions = updated
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                        Text("Sunlight")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func interactionCount(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.7))
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveTextSecondary)
        }
    }

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
        if name.isEmpty { return "G" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
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
    .modelContainer(for: User.self, inMemory: true)
}

#Preview("Regular Workout — Light Garden") {
    NavigationStack {
        WorkoutInteractionDetailView(item: SocialPreviewData.feedItems[1])
    }
    .environment(SocialPreviewData.socialService)
    .modelContainer(for: User.self, inMemory: true)
}

#Preview("No Interactions") {
    NavigationStack {
        WorkoutInteractionDetailView(item: SocialPreviewData.feedItems[5])
    }
    .environment(SocialPreviewData.socialService)
    .modelContainer(for: User.self, inMemory: true)
}
