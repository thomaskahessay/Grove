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
    @State private var achievementProgress: [AchievementService.AchievementProgress] = []
    @State private var showingAddFriend = false
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

    private var plantHeroHeight: CGFloat {
        screenWidth * 0.75
    }

    /// Shift the plant canvas upward for early stages so small plants
    /// aren't hidden behind the profile photo overlay.
    private var plantVerticalOffset: CGFloat {
        guard let user = user else { return 0 }
        let stage = user.isStreakWilted
            ? (PlantStage(rawValue: user.wiltedAtStage) ?? .seed)
            : PlantStage.from(streak: user.currentStreak)
        switch stage {
        case .seed:       return -screenWidth * 0.35
        case .sprout:     return -screenWidth * 0.18
        case .seedling:   return -screenWidth * 0.08
        default:          return 0
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    plantHeroSection

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
            .ignoresSafeArea(edges: .top)
            .background(Color.groveBackground)
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
            .overlay(alignment: .topTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(Color.groveSage)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
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
            .sheet(isPresented: $showingAddFriend) {
                AddFriendSheet()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    user?.profileImageData = processImage(image)
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
                user?.profileImageData = processImage(image)
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

    private var plantHeroSection: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Full-width atmospheric plant
            if let user = user {
                NavigationLink {
                    StreakDetailView(user: user)
                } label: {
                    StreakPlantView(
                        streak: user.currentStreak,
                        isWilted: user.isStreakWilted,
                        wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                        size: screenWidth,
                        showLabel: false
                    )
                    .offset(y: plantVerticalOffset)
                    .frame(width: screenWidth, height: plantHeroHeight, alignment: .center)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.75),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .buttonStyle(.plain)
            }

            // Layer 2: Bottom gradient fade to background
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: Color.groveBackground.opacity(0.5), location: 0.6),
                    .init(color: Color.groveBackground.opacity(0.85), location: 0.8),
                    .init(color: Color.groveBackground, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Layer 3: Profile photo + name overlay
            if let user = user {
                VStack(spacing: 8) {
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

                        Text(PlantStage.from(streak: user.currentStreak).displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveSage)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(height: plantHeroHeight + 40)
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
            statColumn(icon: "dumbbell.fill", value: "\(user?.workouts.count ?? 0)", label: "Workouts")
            statDivider
            statColumn(icon: "flame.fill", value: "\(user?.currentStreak ?? 0)", label: "Streak")
            statDivider
            statColumn(icon: "trophy.fill", value: "\(prExerciseCount)", label: "PRs")
            statDivider
            statColumn(icon: "person.2.fill", value: "\(socialService.friends.count)", label: "Friends")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }

    private func statColumn(icon: String, value: String, label: String) -> some View {
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

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(Color.groveSage)
                Text("Friends")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                if !socialService.friends.isEmpty {
                    Button {
                        showingAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }

            if !socialService.friendsLoaded {
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
                Button {
                    showingAddFriend = true
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .strokeBorder(Color.groveSage.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "person.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(Color.groveSage.opacity(0.6))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add your first friend")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)
                            Text("Share invite codes to connect")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color.groveCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
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

                        // Add friend button at end
                        Button {
                            showingAddFriend = true
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .strokeBorder(Color.groveSage.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.title3)
                                            .foregroundStyle(Color.groveSage.opacity(0.6))
                                    }

                                Text("Add")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
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
        let weeks = 13
        let grid = heatmapGrid(weeks: weeks)
        let counts = workoutDayCounts
        let monthLabels = heatmapMonthLabels(grid: grid)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cellSize: CGFloat = 18
        let cellSpacing: CGFloat = 3
        let dayLabelWidth: CGFloat = 14

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

    private let achievementColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

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

            // Icon grid (5 columns)
            LazyVGrid(columns: achievementColumns, spacing: 10) {
                ForEach(achievementProgress, id: \.type) { progress in
                    ZStack {
                        Circle()
                            .fill(progress.isUnlocked
                                  ? Color.groveSage
                                  : Color.groveWarmSand.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .shadow(
                                color: progress.isUnlocked
                                    ? Color.groveSage.opacity(0.3)
                                    : .clear,
                                radius: 4
                            )

                        Image(systemName: progress.type.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(
                                progress.isUnlocked
                                    ? .white
                                    : Color.groveText.opacity(0.15)
                            )
                    }
                }
            }

            // Shelf line
            Capsule()
                .fill(Color.groveWarmSand.opacity(0.35))
                .frame(height: 1.5)

            // Earned count
            let earned = achievementProgress.filter(\.isUnlocked).count
            Text("\(earned) of \(AchievementType.allCases.count) earned")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func loadAchievementProgress() {
        if let user = user {
            // Award any achievements the user already qualifies for (retroactive check)
            let _ = AchievementService.checkAndAwardAchievements(for: user, context: modelContext)
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

                            Text("\(user.preferredDaysPerWeek) days/week \u{00B7} \(user.preferredRepRange.rawValue)")
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
