import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Query private var users: [User]
    @Query(
        sort: \WorkoutPlan.date,
        order: .reverse
    ) private var workoutPlans: [WorkoutPlan]

    @Query(
        filter: #Predicate<Workout> { workout in
            workout.completedAt != nil
        },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var achievements: [Achievement]

    @State private var showingWeeklyPlan = false

    private var recentWorkouts: [Workout] {
        Array(completedWorkouts.prefix(5))
    }

    private var currentUser: User? { users.first }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var welcomeMessage: String {
        let name = currentUser?.displayName ?? "there"
        let messages = [
            "\(greeting), \(name)!",
            "Welcome back, \(name)!",
            "Ready to train, \(name)?",
            "Let's grow, \(name)!",
            "Hey \(name), let's go!"
        ]
        // Use day of year to rotate messages (consistent per day)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return messages[dayOfYear % messages.count]
    }

    private var todaysPlan: WorkoutPlan? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return workoutPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: today)
        }
    }

    // MARK: - Next Upcoming Workout

    private var nextPlannedWorkout: (name: String, date: Date)? {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        let futurePlans = workoutPlans
            .filter { plan in
                let day = calendar.startOfDay(for: plan.date)
                return day >= tomorrow && !plan.isRestDay && plan.template != nil
            }
            .sorted { $0.date < $1.date }

        guard let next = futurePlans.first, let template = next.template else {
            return nil
        }
        return (name: template.name, date: next.date)
    }

    private var tomorrowsPlan: WorkoutPlan? {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return workoutPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: tomorrow)
        }
    }

    private var todaysCompletedWorkout: Workout? {
        let calendar = Calendar.current
        return completedWorkouts.first { workout in
            guard let completedAt = workout.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Message
                    Text(welcomeMessage)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Streak Plant Hero
                    if let user = currentUser {
                        NavigationLink(destination: StreakDetailView(user: user)) {
                            StreakPlantView(
                                streak: user.currentStreak,
                                isWilted: user.isStreakWilted,
                                wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                                size: 160,
                                showLabel: true
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }

                    // Today's Workout Card
                    if let plan = todaysPlan {
                        if plan.isRestDay {
                            RestDayCard()
                        } else if let completedWorkout = plan.completedWorkout {
                            CompletedTodayCard(
                                workout: completedWorkout,
                                tomorrowsPlan: tomorrowsPlan,
                                onPlanTomorrow: { showingWeeklyPlan = true }
                            )
                        } else if let template = plan.template {
                            TodayWorkoutCard(
                                workoutName: template.name,
                                exerciseCount: template.exerciseIDs.count,
                                category: template.category,
                                onStart: { startTodaysWorkout(plan: plan) }
                            )
                        } else if let next = nextPlannedWorkout {
                            NextWorkoutCard(name: next.name, date: next.date)
                        } else {
                            EmptyTodayCard()
                        }
                    } else if let completedWorkout = todaysCompletedWorkout {
                        CompletedTodayCard(
                            workout: completedWorkout,
                            tomorrowsPlan: tomorrowsPlan,
                            onPlanTomorrow: { showingWeeklyPlan = true }
                        )
                    } else if let next = nextPlannedWorkout {
                        NextWorkoutCard(name: next.name, date: next.date)
                    } else {
                        EmptyTodayCard()
                    }

                    // Calendar Strip
                    CalendarStripView()

                    // Plan My Week
                    Button {
                        showingWeeklyPlan = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(Color.groveSage)
                            Text("Plan My Week")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color.groveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    // Latest Achievement
                    if let latest = achievements.first {
                        NavigationLink(destination: AchievementsGalleryView()) {
                            LatestAchievementCard(
                                achievement: latest,
                                totalCount: achievements.count
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Recent Workouts Section
                    if !recentWorkouts.isEmpty {
                        RecentWorkoutsSection(workouts: recentWorkouts)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color.groveBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {}
            .sheet(isPresented: $showingWeeklyPlan) {
                WeeklyPlanView()
            }
            .onAppear {
                if let user = currentUser {
                    StreakManager.recalculateStreak(
                        for: user,
                        workouts: completedWorkouts,
                        plans: workoutPlans
                    )
                }
            }
        }
    }

    // MARK: - Start Today's Workout

    private func startTodaysWorkout(plan: WorkoutPlan) {
        guard let template = plan.template else { return }

        let exercises = template.exerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }
        guard !exercises.isEmpty else { return }

        let defaultSets = template.defaultSets
        let defaultReps = template.defaultReps

        let workout = Workout(name: template.name, templateUsed: template)
        modelContext.insert(workout)

        for (index, exercise) in exercises.enumerated() {
            let lastSets = getLastSetsForExercise(exercise)
            let numberOfSets = lastSets.isEmpty ? defaultSets : lastSets.count

            let exerciseLog = ExerciseLog(
                exercise: exercise,
                orderIndex: index,
                targetSets: numberOfSets,
                targetReps: defaultReps
            )
            exerciseLog.workout = workout
            modelContext.insert(exerciseLog)

            for setNumber in 1...numberOfSets {
                let lastSetData = lastSets.indices.contains(setNumber - 1) ? lastSets[setNumber - 1] : nil
                let setLog = SetLog(
                    setNumber: setNumber,
                    weight: lastSetData?.weight,
                    reps: lastSetData?.reps
                )
                setLog.exerciseLog = exerciseLog
                exerciseLog.sets.append(setLog)
                modelContext.insert(setLog)
            }
        }

        template.usageCount += 1
        template.lastUsedDate = Date()

        sessionManager.startWorkout(workout)
    }

    /// Gets the most recent completed sets for an exercise (fetches on-demand to avoid memory bloat)
    private func getLastSetsForExercise(_ exercise: Exercise) -> [(weight: Double?, reps: Int?)] {
        // Query only completed exercise logs for this specific exercise
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exerciseID
            },
            sortBy: [SortDescriptor(\.workout?.completedAt, order: .reverse)]
        )

        guard let logs = try? modelContext.fetch(descriptor) else { return [] }

        // Find the first log from a completed workout
        guard let lastLog = logs.first(where: { $0.workout?.completedAt != nil }) else { return [] }

        return lastLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
            .map { (weight: $0.weight, reps: $0.reps) }
    }
}

// MARK: - Today's Workout Card

struct TodayWorkoutCard: View {
    let workoutName: String
    let exerciseCount: Int
    let category: TemplateCategory
    var onStart: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Workout")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(workoutName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)
                }
                Spacer()
                CategoryIcon(category: category)
            }

            HStack {
                Label("\(exerciseCount) exercises", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button(action: {
                onStart?()
            }) {
                Text("Start Workout")
            }
            .buttonStyle(.primary)
        }
        .padding(20)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Empty Today Card

struct EmptyTodayCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.title)
                .foregroundStyle(Color.groveWarmSand)

            VStack(alignment: .leading, spacing: 4) {
                Text("No workout planned")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                Text("Tap + to start a workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Next Workout Card

struct NextWorkoutCard: View {
    let name: String
    let date: Date

    private var dayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.title)
                .foregroundStyle(Color.groveTerracotta)

            VStack(alignment: .leading, spacing: 4) {
                Text("Next up: \(name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                Text(dayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Rest Day Card

struct RestDayCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "moon.fill")
                .font(.title)
                .foregroundStyle(Color.groveTerracotta)

            VStack(alignment: .leading, spacing: 4) {
                Text("Rest Day")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                Text("Recovery is part of the plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Completed Today Card

struct CompletedTodayCard: View {
    let workout: Workout
    let tomorrowsPlan: WorkoutPlan?
    var onPlanTomorrow: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.groveSage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveText)
                    Text("\(workout.completedExerciseCount) exercises completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Up Next section
            upNextSection
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var upNextSection: some View {
        if let plan = tomorrowsPlan {
            if plan.isRestDay {
                HStack(spacing: 10) {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(Color.groveTerracotta)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest Day Tomorrow")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveText)
                        Text("Recovery is part of the plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else if let template = plan.template {
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.groveSage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveText)
                        Text("Tomorrow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                unscheduledTomorrow
            }
        } else {
            unscheduledTomorrow
        }
    }

    private var unscheduledTomorrow: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.groveWarmSand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tomorrow isn't planned yet")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)
            }
            Spacer()
            Button {
                onPlanTomorrow?()
            } label: {
                Text("Plan My Week")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveSage)
            }
        }
    }
}

// MARK: - Category Icon

struct CategoryIcon: View {
    let category: TemplateCategory

    private var iconName: String {
        switch category {
        case .push: return "arrow.up.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .legs: return "figure.walk.circle.fill"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.run.circle.fill"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "slider.horizontal.3"
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 36))
            .foregroundStyle(Color.groveSage)
    }
}

// MARK: - Recent Workouts Section

struct RecentWorkoutsSection: View {
    let workouts: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 0) {
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        RecentWorkoutRow(workout: workout)
                    }
                    .buttonStyle(.plain)

                    if index < workouts.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct RecentWorkoutRow: View {
    let workout: Workout

    private var formattedDate: String {
        guard let completedAt = workout.completedAt else { return "" }

        let calendar = Calendar.current
        if calendar.isDateInToday(completedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(completedAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: completedAt)
        }
    }

    private var formattedDuration: String {
        let minutes = Int(workout.duration / 60)
        return "\(minutes) min"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.groveSage)

            // Workout info
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                HStack(spacing: 8) {
                    Text(formattedDate)
                    Text("•")
                    Text(formattedDuration)
                    Text("•")
                    Text("\(workout.completedExerciseCount) exercises")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Latest Achievement Card

struct LatestAchievementCard: View {
    let achievement: Achievement
    let totalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.type.icon)
                .font(.title2)
                .foregroundStyle(Color.groveTerracotta)
                .frame(width: 40, height: 40)
                .background(Color.groveTerracotta.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                Text("\(totalCount) of 7 achievements earned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .environment(WorkoutSessionManager())
        .modelContainer(.preview)
}
