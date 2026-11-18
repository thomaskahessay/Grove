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
    @State private var screenSize = CGSize(width: 402, height: 874)

    private var currentUser: User? { users.first }

    /// How many of their posts show before "See all".
    private static let previewCount = 6

    private let tileColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                SwiftUI.ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let data = profileData {
                VStack(spacing: 20) {
                    heroSection(data.profile)
                    statsCard(data)
                    connectionCard(data)
                    programCard(data)
                    sharedWorkoutsSection(data)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            } else {
                errorView
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            CGSize(width: proxy.size.width,
                   height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
        } action: { size in
            screenSize = size
        }
        // Their plant, still and faded, behind the page (as on your own profile).
        .background(alignment: .top) {
            if let profile = profileData?.profile { backgroundPlant(profile) }
        }
        .background(Color.groveBackground.ignoresSafeArea())
        .navigationTitle(profileData?.profile.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if profileData != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Hide Their Posts", systemImage: "eye.slash", role: .destructive) {
                            showingRemoveConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .task {
            await loadProfile()
        }
        .navigationDestination(item: $selectedDetailItem) { item in
            WorkoutInteractionDetailView(item: item)
        }
        .alert("Hide \(profileData?.profile.displayName ?? "their") posts?", isPresented: $showingRemoveConfirmation) {
            Button("Hide", role: .destructive) {
                socialService.hideUser(userID, name: profileData?.profile.displayName ?? "Someone")
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their workouts and plant won't show in your grove on this phone. They aren't told, and they can still see your posts. You can undo this in Settings.")
        }
    }

    // MARK: - Background Plant

    private func backgroundPlant(_ profile: CKFriendProfile) -> some View {
        let size = screenSize.width * 1.7
        let groundY = screenSize.height - 90
        return StreakPlantView(
            streak: profile.currentStreak,
            style: PlantStyle(identity: profile.id),
            size: size,
            showLabel: false,
            isAnimated: false
        )
        // The renderer's ground line sits at ~86% of the canvas.
        .offset(y: groundY - size * 0.86)
        .frame(width: screenSize.width, height: screenSize.height, alignment: .top)
        .clipped()
        .opacity(0.22)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Hero Section

    private func heroSection(_ profile: CKFriendProfile) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 90, height: 90)
                .overlay {
                    Circle()
                        .fill(Color.groveSage.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay {
                            if let data = profile.profileImageData,
                               let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Text(profile.initials)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.groveSage)
                            }
                        }
                        .clipShape(Circle())
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)

            Text(profile.displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            HStack(spacing: 6) {
                Text("Member since \(memberSinceText(profile.memberSince))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\u{00B7}")
                    .foregroundStyle(.secondary)
                Text(PlantStage.from(streak: profile.currentStreak).displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveSage)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
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

                // What you have in common
                if !buildMutualIndicators(data).isEmpty {
                    Divider()
                    mutualRows(data)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else if !buildMutualIndicators(data).isEmpty {
            mutualRows(data)
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func mutualRows(_ data: FriendProfileData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(buildMutualIndicators(data), id: \.text) { indicator in
                HStack(spacing: 8) {
                    Image(systemName: indicator.icon)
                        .font(.caption)
                        .foregroundStyle(Color.groveSage)
                        .frame(width: 20)
                    Text(indicator.text)
                        .font(.caption)
                        .foregroundStyle(Color.groveText)
                    Spacer()
                }
            }
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

    private func statsCard(_ data: FriendProfileData) -> some View {
        let profile = data.profile
        let week = GroveWeekProgress(dates: data.recentWorkouts.map(\.completedAt), target: profile.daysPerWeek)
        return HStack(spacing: 0) {
            statItem(icon: "dumbbell.fill", value: "\(profile.workoutCount)", label: "Workouts")
            statDivider
            statItem(icon: "flame.fill", value: "\(profile.currentStreak)", label: "Streak")
            statDivider
            statItem(
                icon: "calendar",
                // Their shared workouts this week against their goal, as in the grove.
                value: week.target.map { "\(week.trained)/\($0)" } ?? "\(week.trained)",
                label: "This week"
            )
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
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
    private func programCard(_ data: FriendProfileData) -> some View {
        let profile = data.profile
        let prNames = data.recentPRExerciseNames
        if profile.splitName != nil || !prNames.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if let splitName = profile.splitName {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(Color.groveSage)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Program")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)
                            Text(splitName)
                                .font(.subheadline)
                                .foregroundStyle(Color.groveSage)
                            if let days = profile.daysPerWeek {
                                Text([
                                    "\(days) days/week",
                                    profile.repRange,
                                    profile.sessionMinutes.map { "\($0) min" }
                                ].compactMap { $0 }.joined(separator: " \u{00B7} "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                if !prNames.isEmpty {
                    if profile.splitName != nil { Divider() }
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(Color.groveTerracotta)
                        Text("Recent PRs")
                            .font(.caption.weight(.semibold))
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
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
    }

    // MARK: - Shared Workouts

    private func sharedWorkoutsSection(_ data: FriendProfileData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shared Workouts")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                if data.recentWorkouts.count > Self.previewCount {
                    NavigationLink {
                        SharedWorkoutsGridView(
                            title: "\(data.profile.displayName)'s Workouts",
                            items: data.recentWorkouts
                        )
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
            .padding(.leading, 4)

            if data.recentWorkouts.isEmpty {
                Text("No shared workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                // Tap a tile to open it and water, seed or send sunlight.
                LazyVGrid(columns: tileColumns, spacing: 12) {
                    ForEach(data.recentWorkouts.prefix(Self.previewCount)) { workout in
                        Button {
                            selectedDetailItem = workout
                        } label: {
                            SharedWorkoutTile(
                                item: workout,
                                interactions: socialService.interactionsByWorkout[workout.id]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
