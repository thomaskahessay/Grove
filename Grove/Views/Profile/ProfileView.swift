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
    @Query private var templates: [WorkoutTemplate]
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSocialService.self) private var socialService

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var unlockedBanner: [AchievementType] = []
    @State private var cameraImage: UIImage? = nil
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPlanEditor = false
    @State private var selectedSharedWorkout: SharedWorkoutItem?
    @State private var achievementProgress: [AchievementService.AchievementProgress] = []
    @State private var selectedFriendID: String?

    private var user: User? { users.first }

    private var prExerciseCount: Int {
        guard let records = user?.personalRecords else { return 0 }
        let maxWeightRecords = records.filter { $0.type == .maxWeight }
        let uniqueExercises = Set(maxWeightRecords.compactMap { $0.exercise?.id })
        return uniqueExercises.count
    }

    private let sharedWorkoutColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @State private var screenWidth: CGFloat = 393 // sensible default, updated by GeometryReader

    private var plantStage: PlantStage {
        guard let user = user else { return .seed }
        return user.isStreakWilted
            ? (PlantStage(rawValue: user.wiltedAtStage) ?? .seed)
            : PlantStage.from(streak: user.currentStreak)
    }

    /// Small plants sit low in their square canvas, so their hero is shorter and
    /// bottom-aligned instead of leaving an empty band above them.
    private var isSmallPlant: Bool {
        switch plantStage {
        case .seed, .sprout, .seedling: return true
        default: return false
        }
    }

    /// Big enough that the plant rises behind the cards and its canopy reaches the header.
    private var backgroundPlantSize: CGFloat {
        screenWidth * 1.7
    }

    @State private var screenHeight: CGFloat = 874

    /// The plant's ground sits just above the tab bar, so it grows up behind the page.
    private var backgroundGroundY: CGFloat { screenHeight - 90 }

    private var completedWorkouts: [Workout] {
        (user?.workouts ?? [])
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// The grove count can come from a cache while iCloud is off; don't show it then.
    private var groveCountIsKnown: Bool {
        socialService.iCloudAvailable && socialService.friendsLoaded
    }

    var body: some View {
        screen
            // Achievements earned outside a workout (creatine, custom exercise, posting…)
            .achievementUnlockBanner($unlockedBanner)
    }

    private var screen: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    plantHeroSection
                        // Part of the scrolling content, so it never floats over the cards below.
                        .overlay(alignment: .topTrailing) {
                            settingsButton
                                .padding(.trailing)
                                .padding(.top, 4)
                        }

                    VStack(spacing: 24) {
                        statsCard
                            .padding(.top, 16)

                        friendsSection

                        currentProgramCard

                        workoutHeatmapSection

                        achievementShelf

                        sharedWorkoutsSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                screenWidth = newWidth
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            } action: { newHeight in
                screenHeight = newHeight
            }
            // The plant stays put behind the page, faded, while the content scrolls over it.
            .background(alignment: .top) { backgroundPlant }
            .background(Color.groveBackground.ignoresSafeArea())
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color.groveBackground,
                        Color.groveBackground.opacity(0.8),
                        Color.groveBackground.opacity(0.4),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .task {
                await socialService.fetchMySharedWorkouts()
            }
            .onAppear { loadAchievementProgress() }
            .onChange(of: users.count) { _, _ in loadAchievementProgress() }
            .navigationDestination(item: $selectedSharedWorkout) { item in
                WorkoutInteractionDetailView(item: item)
            }
            .navigationDestination(item: $selectedFriendID) { userID in
                FriendProfileView(userID: userID)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    user?.profileImageData = ProfilePhoto.jpegData(from: image)
                    if let user = user {
                        await socialService.ensureUserProfile(user: user)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView(selectedImage: $cameraImage, onDismiss: { showingCamera = false })
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                user?.profileImageData = ProfilePhoto.jpegData(from: image)
                cameraImage = nil
                if let user = user {
                    Task {
                        await socialService.ensureUserProfile(user: user)
                    }
                }
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

    // MARK: - Plant Hero Section

    private var settingsButton: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(Color.groveSage)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Settings")
    }

    /// A still, faded copy of the plant behind the whole page.
    @ViewBuilder
    private var backgroundPlant: some View {
        if let user = user {
            let size = backgroundPlantSize
            StreakPlantView(
                streak: user.currentStreak,
                isWilted: user.isStreakWilted,
                wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                style: user.plantStyle,
                size: size,
                showLabel: false,
                isAnimated: false
            )
            // The renderer's ground line sits at ~86% of the canvas.
            .offset(y: backgroundGroundY - size * 0.86)
            .frame(width: screenWidth, height: screenHeight, alignment: .top)
            .clipped()
            .opacity(0.22)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Photo, name and stage, sitting on the background plant's ground.
    private var plantHeroSection: some View {
        VStack(spacing: 8) {
            if let user = user {
                // Leaves room for the plant above the photo.
                Spacer().frame(height: 60)

                profilePhotoWithGlassRing

                Text(user.displayName ?? "Grove User")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)

                HStack(spacing: 6) {
                    Text("Member since \(memberSinceText(user.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\u{00B7}")
                        .foregroundStyle(.secondary)

                    Text(plantStage.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveSage)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var profilePhotoWithGlassRing: some View {
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
                    .fill(.ultraThinMaterial)
                    .frame(width: 90, height: 90)
                    .overlay {
                        Circle()
                            .fill(Color.groveSage.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay {
                                if let user = user,
                                   let data = user.profileImageData,
                                   let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Text(initials(for: user))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.groveSage)
                                }
                            }
                            .clipShape(Circle())
                    }
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)

                Circle()
                    .fill(Color.groveSage)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 2)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            NavigationLink {
                AllWorkoutsView(workouts: completedWorkouts)
                    .navigationTitle("Workouts")
            } label: {
                statColumn(icon: "dumbbell.fill", value: "\(completedWorkouts.count)", label: "Workouts", isLink: true)
            }
            .buttonStyle(.plain)
            statDivider
            if let user = user {
                NavigationLink {
                    StreakDetailView(user: user)
                } label: {
                    statColumn(icon: "flame.fill", value: "\(user.currentStreak)", label: "Streak", isLink: true)
                }
                .buttonStyle(.plain)
            } else {
                statColumn(icon: "flame.fill", value: "0", label: "Streak")
            }
            statDivider
            NavigationLink {
                PersonalRecordsView()
            } label: {
                statColumn(icon: "trophy.fill", value: "\(prExerciseCount)", label: "PRs", isLink: true)
            }
            .buttonStyle(.plain)
            statDivider
            statColumn(
                icon: "person.2.fill",
                value: groveCountIsKnown ? "\(socialService.friends.count)" : "–",
                label: "Grove"
            )
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }

    private func statColumn(icon: String, value: String, label: String, isLink: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.groveSage)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
            HStack(spacing: 2) {
                Text(label)
                if isLink {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.groveText.opacity(0.1))
            .frame(width: 1, height: 40)
    }

    // MARK: - Friends Section

    /// Everyone in Grove is in your grove automatically, so there's nothing to add here.
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(Color.groveSage)
                Text("Your grove")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                if groveCountIsKnown && !socialService.friends.isEmpty {
                    Text(socialService.friends.count == 1 ? "1 person" : "\(socialService.friends.count) people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !socialService.iCloudAvailable {
                Text("Sign in to iCloud in Settings to see your grove.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !socialService.friendsLoaded {
                // Still loading — show placeholder to avoid flashing the empty state
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.groveWarmSand.opacity(0.2))
                                .frame(width: 52, height: 52)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.groveWarmSand.opacity(0.15))
                                .frame(width: 36, height: 8)
                        }
                        .frame(width: 60)
                    }
                    Spacer()
                }
            } else if socialService.friends.isEmpty {
                Text("No one else is here yet. Everyone who joins Grove shows up automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(socialService.friends) { friend in
                            Button {
                                selectedFriendID = friend.id
                            } label: {
                                friendAvatar(friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func friendAvatar(_ friend: CKFriendProfile) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.groveSage.opacity(0.12))
                .frame(width: 52, height: 52)
                .overlay {
                    if let data = friend.profileImageData,
                       let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        Text(friend.initials)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if friend.currentStreak > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 7))
                            Text("\(friend.currentStreak)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.groveTerracotta, in: Capsule())
                        .offset(x: 4, y: 2)
                    }
                }

            Text(friend.displayName.split(separator: " ").first.map(String.init) ?? friend.displayName)
                .font(.caption2)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)
        }
        .frame(width: 60)
    }

    // MARK: - Workout Heatmap

    private var workoutDayCounts: [Date: Int] {
        guard let workouts = user?.workouts else { return [:] }
        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        for workout in workouts {
            guard let completedAt = workout.completedAt else { continue }
            let day = calendar.startOfDay(for: completedAt)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private func heatmapGrid(weeks: Int) -> [[Date?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) - 1
        let currentWeekStart = calendar.date(byAdding: .day, value: -weekday, to: today)!
        let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekStart)!

        var columns: [[Date?]] = []
        for week in 0..<weeks {
            let weekStart = calendar.date(byAdding: .day, value: week * 7, to: gridStart)!
            var days: [Date?] = []
            for day in 0..<7 {
                let date = calendar.date(byAdding: .day, value: day, to: weekStart)!
                days.append(date <= today ? date : nil)
            }
            columns.append(days)
        }
        return columns
    }

    private func heatmapMonthLabels(grid: [[Date?]]) -> [Int: String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var labels: [Int: String] = [:]
        var lastMonth = -1

        for (i, week) in grid.enumerated() {
            guard let firstDay = week.compactMap({ $0 }).first else { continue }
            let month = calendar.component(.month, from: firstDay)
            if month != lastMonth {
                labels[i] = formatter.string(from: firstDay)
                lastMonth = month
            }
        }
        return labels
    }

    private var workoutHeatmapSection: some View {
        // As many weeks as fit at a readable size, then cells stretch to fill the row.
        let cellSpacing: CGFloat = 3
        let dayLabelWidth: CGFloat = 14
        let available = max(200, screenWidth - 32 - dayLabelWidth - cellSpacing)
        let weeks = max(8, Int((available + cellSpacing) / (18 + cellSpacing)))
        let cellSize = (available - CGFloat(weeks - 1) * cellSpacing) / CGFloat(weeks)
        let grid = heatmapGrid(weeks: weeks)
        let counts = workoutDayCounts
        let monthLabels = heatmapMonthLabels(grid: grid)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var totalInPeriod = 0
        for week in grid {
            for date in week.compactMap({ $0 }) {
                totalInPeriod += counts[date] ?? 0
            }
        }

        return VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(Color.groveSage)
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                HStack(spacing: 3) {
                    Text("Less")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    ForEach([0.0, 0.4, 0.65, 0.9], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level == 0 ? Color.groveWarmSand.opacity(0.25) : Color.groveSage.opacity(level))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }

            // Month labels row
            HStack(alignment: .bottom, spacing: cellSpacing) {
                Color.clear.frame(width: dayLabelWidth, height: 12)

                ForEach(0..<weeks, id: \.self) { i in
                    if let label = monthLabels[i] {
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .frame(width: cellSize, alignment: .leading)
                    } else {
                        Color.clear.frame(width: cellSize, height: 12)
                    }
                }
            }

            // Grid
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week labels (show Mon, Wed, Fri)
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if dayIndex == 1 || dayIndex == 3 || dayIndex == 5 {
                            Text(["S","M","T","W","T","F","S"][dayIndex])
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(width: dayLabelWidth, height: cellSize)
                        } else {
                            Color.clear.frame(width: dayLabelWidth, height: cellSize)
                        }
                    }
                }

                // Week columns
                ForEach(0..<weeks, id: \.self) { weekIndex in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let date = grid[weekIndex][dayIndex] {
                                let count = counts[date] ?? 0
                                let isToday = date == today

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatmapCellColor(count: count))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay {
                                        if isToday {
                                            RoundedRectangle(cornerRadius: 3)
                                                .strokeBorder(Color.groveSage, lineWidth: 1.5)
                                        }
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.groveWarmSand.opacity(0.08))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }

            // Summary
            Text("\(totalInPeriod) workout\(totalInPeriod == 1 ? "" : "s") in the last \(weeks) weeks")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func heatmapCellColor(count: Int) -> Color {
        switch count {
        case 0:
            return Color.groveWarmSand.opacity(0.25)
        case 1:
            return Color.groveSage.opacity(0.4)
        case 2:
            return Color.groveSage.opacity(0.65)
        default:
            return Color.groveSage.opacity(0.9)
        }
    }

    // MARK: - Achievement Shelf

    private var achievementShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(Color.groveTerracotta)
                Text("Achievements")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                NavigationLink {
                    AchievementsGalleryView()
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)
                }
            }

            // Earned badges, newest first
            let earnedList = achievementProgress
                .filter(\.isUnlocked)
                .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
            if earnedList.isEmpty {
                Text("Your first workout earns your first badge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(earnedList, id: \.type) { progress in
                            VStack(spacing: 6) {
                                achievementBadge(progress.type, unlocked: true)
                                Text(progress.type.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(Color.groveText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 64)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // The locked one they're closest to
            if let next = achievementProgress
                .filter({ !$0.isUnlocked })
                .max(by: { $0.progressFraction < $1.progressFraction }) {
                HStack(spacing: 12) {
                    achievementBadge(next.type, unlocked: false)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Next: \(next.type.rawValue)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.groveText)
                            Spacer()
                            Text("\(next.currentValue)/\(next.targetValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(next.type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SwiftUI.ProgressView(value: next.progressFraction)
                            .tint(Color.groveSage)
                    }
                }
                .padding(12)
                .background(Color.groveWarmSand.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            // Earned count
            let earned = achievementProgress.filter(\.isUnlocked).count
            Text("\(earned) of \(AchievementType.allCases.count) earned")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func achievementBadge(_ type: AchievementType, unlocked: Bool) -> some View {
        ZStack {
            Circle()
                .fill(unlocked ? Color.groveSage : Color.groveWarmSand.opacity(0.2))
                .frame(width: 44, height: 44)
            Image(systemName: type.icon)
                .font(.system(size: 17))
                .foregroundStyle(unlocked ? .white : Color.groveText.opacity(0.35))
        }
    }

    private func loadAchievementProgress() {
        if let user = user {
            // Award any achievements the user already qualifies for (retroactive check)
            let newlyUnlocked = AchievementService.checkAndAwardAchievements(for: user, context: modelContext)
            if !newlyUnlocked.isEmpty { unlockedBanner = newlyUnlocked.map(\.type) }
            achievementProgress = AchievementService.getProgress(for: user, context: modelContext)
        } else {
            achievementProgress = AchievementType.allCases.map { type in
                AchievementService.AchievementProgress(
                    type: type,
                    isUnlocked: false,
                    unlockedAt: nil,
                    currentValue: 0,
                    targetValue: 1
                )
            }
        }
    }

    // MARK: - Current Program Card

    private var isOwnRoutine: Bool {
        UserDefaults.standard.string(forKey: PlanSetupMode.defaultsKey) == PlanSetupMode.ownRoutine.rawValue
    }

    /// The workouts in the plan, in order ("Upper A · Lower A · …").
    private func programDayNames(for user: User) -> [String] {
        let byID = Dictionary(templates.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return user.weeklyTemplateIDs.compactMap { byID[$0] }
    }

    private func programTitle(for user: User) -> String {
        let names = programDayNames(for: user)
        if (isOwnRoutine || user.preferredSplit == .custom), !names.isEmpty {
            return names.joined(separator: " \u{00B7} ")
        }
        return user.preferredSplit.rawValue
    }

    /// "4 days/week · Mon, Tue, Thu, Fri"
    private func programSchedule(for user: User) -> String {
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let days = user.preferredTrainingSlots.sorted().compactMap { $0 < weekdays.count ? weekdays[$0] : nil }
        let count = "\(user.preferredDaysPerWeek) days/week"
        return days.isEmpty ? count : "\(count) \u{00B7} \(days.joined(separator: ", "))"
    }

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

                            Text(programTitle(for: user))
                                .font(.subheadline)
                                .foregroundStyle(Color.groveSage)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(programSchedule(for: user))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Only the generated plan asked for these.
                            if !isOwnRoutine {
                                Text("\(user.preferredRepRange.rawValue) \u{00B7} \(user.preferredWorkoutMinutes) min sessions")
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

    // MARK: - Shared Workouts Grid

    private var sharedWorkoutsSection: some View {
        Group {
            if !socialService.mySharedWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    // Section header
                    HStack {
                        Label("Shared Workouts", systemImage: "square.and.arrow.up.fill")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)
                        Spacer()
                        Text("\(socialService.mySharedWorkouts.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)

                    // 2-column grid
                    LazyVGrid(columns: sharedWorkoutColumns, spacing: 12) {
                        ForEach(socialService.mySharedWorkouts) { item in
                            let interactions = socialService.interactionsByWorkout[item.id]

                            Button {
                                selectedSharedWorkout = item
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Plant scene thumbnail
                                    CardSceneBackgroundView(
                                        interactions: interactions,
                                        hasPRs: item.hasPRs
                                    )
                                    .frame(height: 120)
                                    .clipShape(UnevenRoundedRectangle(
                                        topLeadingRadius: 12,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 12
                                    ))

                                    // Text content
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.workoutName)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.groveText)
                                            .lineLimit(1)

                                        Text(sharedWorkoutDateText(item.completedAt))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 4) {
                                            HStack(spacing: 2) {
                                                Image(systemName: "figure.strengthtraining.traditional")
                                                    .font(.system(size: 8))
                                                Text("\(item.exerciseCount)")
                                                    .font(.system(size: 10))
                                            }

                                            Text("\u{00B7}")
                                                .font(.system(size: 10))

                                            HStack(spacing: 2) {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.system(size: 8))
                                                Text("\(item.totalSets)")
                                                    .font(.system(size: 10))
                                            }
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                }
                                .background(Color.groveCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
}

#Preview {
    ProfileView()
        .modelContainer(.preview)
}
