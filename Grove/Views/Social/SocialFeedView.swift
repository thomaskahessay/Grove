import SwiftUI
import SwiftData

struct SocialFeedView: View {
    @Environment(CloudKitSocialService.self) private var socialService
    @Query private var users: [User]

    @State private var showingAddFriend = false
    @State private var codeCopied = false
    @State private var selectedSeedItem: SharedWorkoutItem?
    @State private var selectedDetailItem: SharedWorkoutItem?
    @State private var feedMode: FeedMode = .canopy
    @State private var selectedConnection: RootConnection?
    /// Tracks which workout just had a seed sent — triggers the drop animation immediately
    @State private var seedAnimationWorkoutID: String?

    private var user: User? { users.first }
    private var hasCode: Bool { socialService.myInviteCode != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !socialService.iCloudAvailable {
                        iCloudUnavailableView
                    } else {
                        // Error banner
                        if let error = socialService.error {
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
                            }
                            .padding(12)
                            .background(Color.groveMutedRust.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Show full card only when no code exists yet
                        if !hasCode {
                            InviteCodeCard(
                                inviteCode: nil,
                                isLoading: socialService.isLoading,
                                onGenerate: {
                                    Task { await socialService.generateInviteCode(user: user) }
                                }
                            )
                        }

                        // Feed or empty state
                        if socialService.friends.isEmpty {
                            noFriendsView
                        } else if socialService.feedItems.isEmpty && !socialService.isLoading {
                            noActivityView
                        } else {
                            // Grove network view
                            if !socialService.friends.isEmpty {
                                GroveNetworkView(
                                    connections: socialService.rootConnections,
                                    friends: socialService.friends,
                                    userStreak: user?.currentStreak ?? 0,
                                    isWilted: user?.isStreakWilted ?? false,
                                    wiltedAtStage: user?.wiltedAtStage ?? 0,
                                    onFriendTap: { friendID in
                                        selectedDetailItem = nil
                                    },
                                    onConnectionTap: { connection in
                                        selectedConnection = connection
                                    }
                                )
                                .padding(.vertical, 4)

                                // Canopy/Soil toggle
                                HStack {
                                    Spacer()
                                    CanopySoilToggle(mode: $feedMode)
                                    Spacer()
                                }
                            }

                            feedList
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.groveBackground)
            .navigationTitle("Activity")
            .toolbar {
                if let code = socialService.myInviteCode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            UIPasteboard.general.string = code
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            codeCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                codeCopied = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.caption2)
                                if codeCopied {
                                    Text("Copied!")
                                        .font(.system(.caption2))
                                        .fontWeight(.medium)
                                } else {
                                    Text(code)
                                        .font(.system(.caption2, design: .monospaced))
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(Color.groveSage)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingAddFriend = true
                        } label: {
                            Label("Add Friend", systemImage: "person.badge.plus")
                        }

                        #if DEBUG
                        Divider()
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
                        #endif
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
            .refreshable {
                await socialService.fetchFriends()
                await socialService.fetchFeed()
                await socialService.fetchRootConnections()
                await socialService.checkAvailableSunlight()
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendSheet()
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
                .presentationDetents([.medium])
            }
            .navigationDestination(for: String.self) { userID in
                FriendProfileView(userID: userID)
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                WorkoutInteractionDetailView(item: item)
            }
            .sheet(item: $selectedConnection) { connection in
                InteractionBreakdownSheet(connection: connection)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Feed List

    private var filteredFeedItems: [SharedWorkoutItem] {
        if feedMode == .soil {
            return socialService.feedItems.filter { item in
                let interactions = socialService.interactionsByWorkout[item.id]
                return interactions?.iWatered == true || interactions?.iSunlit == true || !(interactions?.seeds.isEmpty ?? true)
            }
        }
        return socialService.feedItems
    }

    private var feedList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredFeedItems) { item in
                FeedItemCard(
                    item: item,
                    interactions: socialService.interactionsByWorkout[item.id],
                    showSunlight: socialService.availableSunlightCount > 0,
                    isOwnPost: item.userID == socialService.currentUserID,
                    triggerSeedAnimation: .init(
                        get: { seedAnimationWorkoutID == item.id },
                        set: { if !$0 { seedAnimationWorkoutID = nil } }
                    ),
                    onProfileTap: {
                        selectedDetailItem = nil // Clear detail selection
                        // Navigate to profile via NavigationLink value
                    },
                    onWater: {
                        Task {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            await socialService.sendWater(to: item.id, recipientID: item.userID)
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
                                await socialService.sendSunlight(
                                    to: item.id,
                                    recipientID: item.userID,
                                    fromWorkoutRecordName: myWorkout
                                )
                            }
                        }
                    }
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    selectedDetailItem = item
                }
            }
        }
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

    private var noFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Friends Yet")
                .font(.headline)
                .foregroundStyle(Color.groveText)
            Text("Share your invite code or enter a friend's code to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
            Text("When your friends share workouts, they'll show up here.")
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
