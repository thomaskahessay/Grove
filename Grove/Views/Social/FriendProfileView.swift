import SwiftUI

struct FriendProfileView: View {
    let userID: String

    @Environment(CloudKitSocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss

    @State private var profileData: FriendProfileData?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showingRemoveConfirmation = false

    var body: some View {
        ScrollView {
            if isLoading {
                SwiftUI.ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let data = profileData {
                VStack(spacing: 24) {
                    heroSection(data.profile)
                    connectionCard
                    statsCard(data.profile)
                    recentWorkoutsSection(data.recentWorkouts)
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
            // Avatar
            Circle()
                .fill(Color.groveSage.opacity(0.15))
                .frame(width: 100, height: 100)
                .overlay {
                    if let data = profile.profileImageData,
                       let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        Text(profile.initials)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                    }
                }

            Text(profile.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            Text("Member since \(memberSinceText(profile.memberSince))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Connection Card

    @ViewBuilder
    private var connectionCard: some View {
        if let connection = socialService.rootConnections.first(where: { $0.friendID == userID }) {
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

                // Progress to next level
                if connection.level.nextLevel != nil {
                    CircularProgressView(progress: connection.progressToNextLevel)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(14)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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

    // MARK: - Recent Workouts

    private func recentWorkoutsSection(_ workouts: [SharedWorkoutItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            if workouts.isEmpty {
                Text("No shared workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(workouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.workoutName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)
                            HStack(spacing: 8) {
                                if workout.duration > 0 {
                                    Text(workout.durationText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if workout.exerciseCount > 0 {
                                    Text("\(workout.exerciseCount) exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Text(workout.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.groveCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
