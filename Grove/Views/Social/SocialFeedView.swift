import SwiftUI
import SwiftData

struct SocialFeedView: View {
    @Environment(CloudKitSocialService.self) private var socialService
    @Query private var users: [User]

    @State private var selectedSeedItem: SharedWorkoutItem?
    @State private var selectedDetailItem: SharedWorkoutItem?
    @State private var templateImportItem: SharedWorkoutItem?
    /// Last time you viewed the feed, captured on appear so the "caught up" divider
    /// doesn't move while you're looking. Saved back to the user when you leave.
    @State private var lastSeen: Date?
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedConnection: RootConnection?
    @State private var selectedProfileUserID: String?
    /// Tracks which workout just had a seed sent — triggers the drop animation immediately
    @State private var seedAnimationWorkoutID: String?
    @State private var showSunlightUnavailableAlert = false

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !socialService.iCloudAvailable {
                        iCloudUnavailableView
                    } else {
                        if let error = socialService.error {
                            errorBanner(error)
                        }

                        if socialService.isOffline && socialService.friends.isEmpty && socialService.feedItems.isEmpty {
                            offlineView
                        } else {
                            groveSection

                            if socialService.feedItems.isEmpty && !socialService.isLoading {
                                noActivityView
                            } else {
                                feedList
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.groveBackground)
            .navigationTitle("Your grove")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await socialService.addTestFriend() }
                        } label: {
                            Label("Add Test Friend", systemImage: "person.badge.plus.fill")
                        }
                        Button(role: .destructive) {
                            Task { await socialService.removeAllTestData() }
                        } label: {
                            Label("Remove Test Data", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ladybug")
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }
                #endif
            }
            .onAppear {
                lastSeen = user?.lastFeedCheckDate
                // Preview data: pretend the last visit was 5 hours ago so the divider shows.
                if socialService.isPreviewMode && lastSeen == nil {
                    lastSeen = Date().addingTimeInterval(-5 * 3600)
                }
            }
            .onDisappear(perform: markFeedSeen)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { markFeedSeen() }
            }
            .refreshable {
                // Run in an unstructured Task: SwiftUI cancels the refreshable task when the
                // view re-renders mid-refresh (e.g. friends/isLoading changing), which would
                // abort the CloudKit queries partway through.
                await Task {
                    await socialService.fetchFriends()
                    await socialService.fetchFeed()
                    await socialService.fetchRootConnections()
                    await socialService.checkAvailableSunlight()
                }.value
            }
            .sheet(item: $selectedSeedItem) { item in
                SeedPickerSheet(item: item) { message, isCustom in
                    // Trigger the seed drop animation immediately (optimistic)
                    seedAnimationWorkoutID = item.id
                    // Send to CloudKit in background — background updates when data returns
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
            .navigationDestination(for: String.self) { userID in
                FriendProfileView(userID: userID)
            }
            .navigationDestination(item: $selectedProfileUserID) { userID in
                FriendProfileView(userID: userID)
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                WorkoutInteractionDetailView(item: item)
            }
            .sheet(item: $selectedConnection) { connection in
                InteractionBreakdownSheet(connection: connection)
                    .presentationDetents([.medium])
            }
            .sheet(item: $templateImportItem) { item in
                TemplateImportSheet(sharedTemplate: SharedTemplate.from(feedItem: item))
            }
            .alert("Share a Workout First", isPresented: $showSunlightUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You need to share a workout to the feed before you can send sunlight to others.")
            }
        }
    }

    // MARK: - Seen tracking

    private func markFeedSeen() {
        user?.lastFeedCheckDate = Date()
    }

    // MARK: - Grove

    /// Most recent loaded post per user, for blooms (today) and droops (quiet).
    private var lastWorkoutByUser: [String: Date] {
        var latest: [String: Date] = [:]
        for item in socialService.feedItems where (latest[item.userID] ?? .distantPast) < item.completedAt {
            latest[item.userID] = item.completedAt
        }
        return latest
    }

    private var userTrainedToday: Bool {
        user?.workouts.contains { $0.completedAt.map(Calendar.current.isDateInToday) ?? false } ?? false
    }

    /// "14 workouts this week · 5 of 7 growing" — counts loaded posts since the start of the week.
    private var weeklyRecap: String {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeek = socialService.feedItems.filter { $0.completedAt >= weekStart }
        let people = Set(thisWeek.map(\.userID)).count
        let total = socialService.friends.count + 1
        let workouts = thisWeek.count == 1 ? "1 workout" : "\(thisWeek.count) workouts"
        return "\(workouts) this week · \(people) of \(total) growing"
    }

    private var groveSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            GroveNetworkView(
                connections: socialService.rootConnections,
                friends: socialService.friends,
                userStreak: user?.currentStreak ?? 0,
                isWilted: user?.isStreakWilted ?? false,
                wiltedAtStage: user?.wiltedAtStage ?? 0,
                lastWorkoutByUser: lastWorkoutByUser,
                userTrainedToday: userTrainedToday,
                onFriendTap: { friendID in
                    selectedProfileUserID = friendID
                },
                onConnectionTap: { connection in
                    selectedConnection = connection
                }
            )

            Text(weeklyRecap)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveSage)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Feed List

    private enum FeedRow: Identifiable {
        case day(String)
        case caughtUp(since: Date, nothingNew: Bool)
        case post(SharedWorkoutItem)

        var id: String {
            switch self {
            case .day(let title): "day-\(title)"
            case .caughtUp: "caught-up"
            case .post(let item): item.id
            }
        }
    }

    /// Posts grouped under day headers, with a "caught up" divider before the first post
    /// you'd already have seen on your last visit.
    private var feedRows: [FeedRow] {
        var rows: [FeedRow] = []
        var currentDay: Date?
        var placedDivider = lastSeen == nil
        let calendar = Calendar.current

        for (index, item) in socialService.feedItems.enumerated() {
            if !placedDivider, let lastSeen, item.completedAt <= lastSeen {
                rows.append(.caughtUp(since: lastSeen, nothingNew: index == 0))
                placedDivider = true
                currentDay = nil  // repeat the day header below the divider
            }
            let day = calendar.startOfDay(for: item.completedAt)
            if day != currentDay {
                rows.append(.day(Self.dayTitle(for: day)))
                currentDay = day
            }
            rows.append(.post(item))
        }
        return rows
    }

    private static func dayTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: Date())).day ?? 0
        if days < 7 { return day.formatted(.dateTime.weekday(.wide)) }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var feedList: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(feedRows) { row in
                switch row {
                case .day(let title):
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveTextSecondary)
                        .padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)
                case .caughtUp(let since, let nothingNew):
                    caughtUpDivider(since: since, nothingNew: nothingNew)
                case .post(let item):
                    feedCard(item)
                }
            }

            feedFooter
        }
    }

    private func caughtUpDivider(since: Date, nothingNew: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                Text("You're all caught up")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.groveSage)
            if nothingNew {
                Text("Nothing new since \(since.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    /// Honest end of the list: how far back the loaded posts go, plus "Show older".
    private var feedFooter: some View {
        VStack(spacing: 10) {
            if let since = socialService.feedLoadedSince {
                let days = Calendar.current.dateComponents([.day], from: since, to: Calendar.current.startOfDay(for: Date())).day ?? 0
                Text(socialService.feedHasOlderPosts
                     ? "That's everything from the last \(days) days"
                     : "That's every post in your grove")
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
            }
            if socialService.feedHasOlderPosts {
                Button {
                    Task { await socialService.loadOlderFeed() }
                } label: {
                    if socialService.isLoadingOlderFeed {
                        ProgressView()
                    } else {
                        Text("Show older")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveSage)
                    }
                }
                .disabled(socialService.isLoadingOlderFeed)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func feedCard(_ item: SharedWorkoutItem) -> some View {
        FeedItemCard(
            item: item,
            interactions: socialService.interactionsByWorkout[item.id],
            showSunlight: socialService.availableSunlightCount > 0,
            isOwnPost: item.userID == socialService.currentUserID,
            onUseTemplate: item.exercisesJSON != nil && item.userID != socialService.currentUserID ? {
                templateImportItem = item
            } : nil,
            triggerSeedAnimation: .init(
                get: { seedAnimationWorkoutID == item.id },
                set: { if !$0 { seedAnimationWorkoutID = nil } }
            ),
            onProfileTap: {
                selectedProfileUserID = item.userID
            },
            onWater: {
                Task {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    _ = await socialService.sendWater(to: item.id, recipientID: item.userID)
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
                        _ = await socialService.sendSunlight(
                            to: item.id,
                            recipientID: item.userID,
                            fromWorkoutRecordName: myWorkout
                        )
                    } else {
                        showSunlightUnavailableAlert = true
                    }
                }
            }
        )
        .onTapGesture {
            selectedDetailItem = item
        }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.groveMutedRust)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                socialService.error = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(Color.groveMutedRust.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Empty States

    private var iCloudUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("iCloud Required")
                .font(.headline)
                .foregroundStyle(Color.groveText)
            Text("Sign in to iCloud in Settings to use social features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var offlineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("You're Offline")
                .font(.headline)
                .foregroundStyle(Color.groveText)
            Text("Connect to the internet to see friends and activity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    if let user { await socialService.refreshAll(user: user) }
                }
            } label: {
                Text("Retry")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.groveSage)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var noActivityView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Shared Workouts Yet")
                .font(.headline)
                .foregroundStyle(Color.groveText)
            Text("When anyone in your grove shares a workout, it shows up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview("Full Social Feed") {
    SocialFeedView()
        .environment(SocialPreviewData.socialService)
        .modelContainer(.preview)
}
