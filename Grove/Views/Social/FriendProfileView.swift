import SwiftUI
import SwiftData

struct FriendProfileView: View {
    let userID: String

    @Environment(CloudKitSocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]

    @State private var profileData: FriendProfileData?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showingRemoveConfirmation = false
    @State private var selectedDetailItem: SharedWorkoutItem?
    @State private var selectedSeedItem: SharedWorkoutItem?
    @State private var seedAnimationWorkoutID: String?

    private var currentUser: User? { users.first }

    var body: some View {
        ScrollView {
            if isLoading {
                SwiftUI.ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let data = profileData {
                VStack(spacing: 24) {
                    heroSection(data.profile)
                    connectionCard(data)
                    statsCard(data.profile)
                    mutualIndicators(data)
                    programCard(data.profile)
                    recentPRsSection(data.recentPRExerciseNames)
                    sharedWorkoutsSection(data)
                    removeFriendButton
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            } else {
                errorView
            }
        }
        .background(Color.groveBackground)
        .navigationTitle(profileData?.profile.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
        }
        .navigationDestination(item: $selectedDetailItem) { item in
            WorkoutInteractionDetailView(item: item)
        }
        .sheet(item: $selectedSeedItem) { item in
            SeedPickerSheet(item: item) { message, isCustom in
                seedAnimationWorkoutID = item.id
                Task {
                    await socialService.sendSeed(
                        to: item.id,
                        recipientID: item.userID,
                        message: message,
                        isCustom: isCustom
                    )
                }
            }
        }
        .alert("Remove Friend", isPresented: $showingRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                Task {
                    let success = await socialService.removeFriend(theirUserID: userID)
                    if success { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to see your shared workouts and you won't see theirs.")
        }
    }

    // MARK: - Hero Section

    private func heroSection(_ profile: CKFriendProfile) -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.groveSage.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay {
                    if let data = profile.profileImageData,
                       let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        Text(profile.initials)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                    }
                }

            Text(profile.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            StreakPlantView(
                streak: profile.currentStreak,
                size: 140,
                showLabel: true
            )

            Text("Member since \(memberSinceText(profile.memberSince))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Connection Card (with interaction breakdown)

    @ViewBuilder
    private func connectionCard(_ data: FriendProfileData) -> some View {
        if let connection = socialService.rootConnections.first(where: { $0.friendID == userID }) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: connection.level.icon)
                        .font(.title3)
                        .foregroundStyle(Color.groveSage)
                        .frame(width: 36, height: 36)
                        .background(Color.groveSage.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.level.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveText)
                        Text("\(connection.score) connection points")
                            .font(.caption)
                            .foregroundStyle(Color.groveTextSecondary)
                    }

                    Spacer()

                    if connection.level.nextLevel != nil {
                        CircularProgressView(progress: connection.progressToNextLevel)
                            .frame(width: 32, height: 32)
                    }
                }

                // Interaction breakdown
                if let breakdown = data.interactionBreakdown {
                    Divider()

                    HStack(spacing: 0) {
                        interactionStat(
                            icon: "drop.fill",
                            color: Color(hex: "5B9BD5"),
                            sent: breakdown.watersSent,
                            received: breakdown.watersReceived,
                            label: "Water"
                        )
                        interactionStat(
                            icon: "leaf.fill",
                            color: Color.groveSage,
                            sent: breakdown.seedsSent,
                            received: breakdown.seedsReceived,
                            label: "Seeds"
                        )
                        interactionStat(
                            icon: "sun.max.fill",
                            color: Color(hex: "E8A838"),
                            sent: breakdown.sunlightsSent,
                            received: breakdown.sunlightsReceived,
                            label: "Sunlight"
                        )
                    }
                }
            }
            .padding(14)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func interactionStat(icon: String, color: Color, sent: Int, received: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(sent + received)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7))
                Text("\(sent)")
                    .font(.system(size: 9))
                Image(systemName: "arrow.down.left")
                    .font(.system(size: 7))
                Text("\(received)")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Card

    private func statsCard(_ profile: CKFriendProfile) -> some View {
        HStack(spacing: 0) {
            statItem(
                icon: "dumbbell.fill",
                value: "\(profile.workoutCount)",
                label: "Workouts"
            )

            statDivider

            statItem(
                icon: "flame.fill",
                value: "\(profile.currentStreak)",
                label: "Streak"
            )

            statDivider

            statItem(
                icon: "calendar",
                value: memberSinceShort(profile.memberSince),
                label: "Joined"
            )
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.groveSage)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.groveText.opacity(0.1))
            .frame(width: 1, height: 40)
    }

    // MARK: - Mutual Indicators

    @ViewBuilder
    private func mutualIndicators(_ data: FriendProfileData) -> some View {
        let indicators = buildMutualIndicators(data)
        if !indicators.isEmpty {
            VStack(spacing: 8) {
                ForEach(indicators, id: \.text) { indicator in
                    HStack(spacing: 8) {
                        Image(systemName: indicator.icon)
                            .font(.caption)
                            .foregroundStyle(Color.groveSage)
                            .frame(width: 24)
                        Text(indicator.text)
                            .font(.subheadline)
                            .foregroundStyle(Color.groveText)
                        Spacer()
                    }
                }
            }
            .padding(14)
            .background(Color.groveSage.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private struct MutualIndicator {
        let icon: String
        let text: String
    }

    private func buildMutualIndicators(_ data: FriendProfileData) -> [MutualIndicator] {
        var indicators: [MutualIndicator] = []

        // Shared split check
        if let friendSplit = data.profile.splitName,
           let myUser = currentUser {
            let mySplit = myUser.preferredSplit.rawValue
            if friendSplit == mySplit {
                indicators.append(MutualIndicator(
                    icon: "person.2.fill",
                    text: "You both train \(friendSplit)"
                ))
            }
        }

        // Common exercises
        if data.commonExerciseCount > 0 {
            indicators.append(MutualIndicator(
                icon: "dumbbell.fill",
                text: "\(data.commonExerciseCount) exercises in common"
            ))
        }

        return indicators
    }

    // MARK: - Program Card

    @ViewBuilder
    private func programCard(_ profile: CKFriendProfile) -> some View {
        if let splitName = profile.splitName {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(Color.groveSage)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Program")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)

                    Text(splitName)
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)

                    if let days = profile.daysPerWeek, let rep = profile.repRange {
                        Text("\(days) days/week \u{00B7} \(rep)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let mins = profile.sessionMinutes {
                        Text("\(mins) min sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
    }

    // MARK: - Recent PRs

    @ViewBuilder
    private func recentPRsSection(_ prNames: [String]) -> some View {
        if !prNames.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(Color.groveTerracotta)
                    Text("Recent PRs")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(prNames.prefix(6), id: \.self) { name in
                            Text(name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveTerracotta)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.groveTerracotta.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Shared Workouts (Feed Cards)

    private func sharedWorkoutsSection(_ data: FriendProfileData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Workouts")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            if data.recentWorkouts.isEmpty {
                Text("No shared workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(data.recentWorkouts) { workout in
                    FeedItemCard(
                        item: workout,
                        interactions: socialService.interactionsByWorkout[workout.id],
                        showSunlight: socialService.availableSunlightCount > 0,
                        isOwnPost: false,
                        triggerSeedAnimation: .init(
                            get: { seedAnimationWorkoutID == workout.id },
                            set: { if !$0 { seedAnimationWorkoutID = nil } }
                        ),
                        onProfileTap: { },
                        onWater: {
                            Task {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                _ = await socialService.sendWater(to: workout.id, recipientID: workout.userID)
                            }
                        },
                        onSeed: {
                            selectedSeedItem = workout
                        },
                        onSunlight: {
                            Task {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                if let myWorkout = await socialService.myLatestSharedWorkoutRecordName() {
                                    _ = await socialService.sendSunlight(
                                        to: workout.id,
                                        recipientID: workout.userID,
                                        fromWorkoutRecordName: myWorkout
                                    )
                                }
                            }
                        }
                    )
                    .onTapGesture {
                        selectedDetailItem = workout
                    }
                }
            }
        }
    }

    // MARK: - Remove Friend

    private var removeFriendButton: some View {
        Button {
            showingRemoveConfirmation = true
        } label: {
            Label("Remove Friend", systemImage: "person.badge.minus")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DestructiveButtonStyle())
        .padding(.top, 8)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(loadError ?? "Could not load profile")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await loadProfile() }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func loadProfile() async {
        isLoading = true
        loadError = nil
        if let data = await socialService.fetchFriendProfile(userID: userID) {
            profileData = data

            // Fetch interactions for the friend's workouts so FeedItemCards can render them
            let workoutIDs = data.recentWorkouts.map { $0.id }
            await socialService.fetchInteractions(for: workoutIDs)
        } else {
            loadError = socialService.error ?? "Could not load profile"
        }
        isLoading = false
    }

    private func memberSinceText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func memberSinceShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date)
    }
}

// MARK: - Circular Progress

private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.groveWarmSand.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.groveSage, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
