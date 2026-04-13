import SwiftUI
import SwiftData
import PhotosUI

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

struct ProfileView: View {
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSocialService.self) private var socialService

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var cameraImage: UIImage? = nil
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPlanEditor = false
    @State private var selectedSharedWorkout: SharedWorkoutItem?

    private var user: User? { users.first }

    /// Number of exercises with a max-weight PR (deduplicated per exercise)
    private var prExerciseCount: Int {
        guard let records = user?.personalRecords else { return 0 }
        let maxWeightRecords = records.filter { $0.type == .maxWeight }
        let uniqueExercises = Set(maxWeightRecords.compactMap { $0.exercise?.id })
        return uniqueExercises.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    statsCard
                    streakPlantCard
                    quickAccessCards
                    currentProgramCard
                    sharedWorkoutsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color.groveBackground)
            .task {
                await socialService.fetchMySharedWorkouts()
            }
            .navigationDestination(item: $selectedSharedWorkout) { item in
                WorkoutInteractionDetailView(item: item)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    user?.profileImageData = processImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView(selectedImage: $cameraImage, onDismiss: { showingCamera = false })
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                user?.profileImageData = processImage(image)
                cameraImage = nil
            }
        }
        .sheet(isPresented: $showingPlanEditor) {
            if let user = user {
                NavigationStack {
                    SmartBuilderView(
                        user: user,
                        isEditMode: true,
                        onComplete: { showingPlanEditor = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingPlanEditor = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            Menu {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.groveSage.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .overlay {
                            if let user = user,
                               let data = user.profileImageData,
                               let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else {
                                Text(initials(for: user))
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.groveSage)
                            }
                        }

                    Circle()
                        .fill(Color.groveSage)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 2, y: 2)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            if let user = user {
                Text(user.displayName ?? "Grove User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)

                Text("Member since \(memberSinceText(user.createdAt))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "dumbbell.fill",
                value: "\(user?.workouts.count ?? 0)",
                label: "Workouts"
            )

            statDivider

            statItem(
                icon: "flame.fill",
                value: "\(user?.currentStreak ?? 0)",
                label: "Streak"
            )

            statDivider

            statItem(
                icon: "trophy.fill",
                value: "\(prExerciseCount)",
                label: "PRs"
            )

            statDivider

            statItem(
                icon: "medal.fill",
                value: "\(user?.achievements.count ?? 0)",
                label: "Badges"
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

    // MARK: - Streak Plant Card

    private var streakPlantCard: some View {
        Group {
            if let user = user {
                NavigationLink {
                    StreakDetailView(user: user)
                } label: {
                    HStack(spacing: 16) {
                        StreakPlantView(
                            streak: user.currentStreak,
                            isWilted: user.isStreakWilted,
                            wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                            size: 80,
                            showLabel: false
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Grove")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)

                            Text(PlantStage.from(streak: user.currentStreak).displayName)
                                .font(.subheadline)
                                .foregroundStyle(Color.groveSage)

                            if user.isStreakWilted {
                                Text("Streak broken — keep going!")
                                    .font(.caption)
                                    .foregroundStyle(Color.groveMutedRust)
                            } else {
                                Text("\(user.currentStreak)-day streak")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick Access Cards

    private var quickAccessCards: some View {
        NavigationLink {
            AchievementsGalleryView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(Color.groveTerracotta)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievements")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)

                    Text("\(user?.achievements.count ?? 0) / \(AchievementType.allCases.count) earned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Program Card

    private var currentProgramCard: some View {
        Group {
            if let user = user {
                Button {
                    showingPlanEditor = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(Color.groveSage)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Program")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)

                            Text(user.preferredSplit.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(Color.groveSage)

                            Text("\(user.preferredDaysPerWeek) days/week · \(user.preferredRepRange.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(user.preferredWorkoutMinutes) min sessions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared Workouts Section

    private var sharedWorkoutsSection: some View {
        Group {
            if !socialService.mySharedWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Shared Workouts", systemImage: "square.and.arrow.up.fill")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                        .padding(.leading, 4)

                    ForEach(socialService.mySharedWorkouts) { item in
                        let interactions = socialService.interactionsByWorkout[item.id]

                        Button {
                            selectedSharedWorkout = item
                        } label: {
                            HStack(spacing: 12) {
                                // Mini plant background preview
                                CardSceneBackgroundView(interactions: interactions, hasPRs: item.hasPRs)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.workoutName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.groveText)

                                    Text(sharedWorkoutDateText(item.completedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // Interaction summary icons
                                interactionIcons(for: interactions)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func interactionIcons(for interactions: InteractionSummary?) -> some View {
        HStack(spacing: 6) {
            if let interactions, interactions.waterCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue.opacity(0.7))
                    Text("\(interactions.waterCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let interactions, !interactions.seeds.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.groveSage.opacity(0.7))
                    Text("\(interactions.seeds.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let interactions, interactions.sunlightCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.7))
                    Text("\(interactions.sunlightCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sharedWorkoutDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Helpers

    private func initials(for user: User?) -> String {
        let name = user?.displayName ?? ""
        if name.isEmpty { return "G" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func memberSinceText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func processImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 512
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
        let targetSize: CGSize
        if ratio >= 1 {
            targetSize = image.size
        } else {
            targetSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

#Preview {
    ProfileView()
        .modelContainer(.preview)
}
