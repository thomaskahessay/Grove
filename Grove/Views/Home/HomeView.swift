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

    // MARK: - Weekly Stats

    private var weekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
    }

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        return completedWorkouts.filter { workout in
            guard let completedAt = workout.completedAt else { return false }
            let day = calendar.startOfDay(for: completedAt)
            return day >= weekStart && day <= weekEnd
        }.count
    }

    private var plannedThisWeek: Int {
        let calendar = Calendar.current
        return workoutPlans.filter { plan in
            let day = calendar.startOfDay(for: plan.date)
            return day >= weekStart && day <= weekEnd && !plan.isRestDay
        }.count
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

                    // Plan My Week Button
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

                    // Weekly Stats
                    WeeklyStatsCard(
                        completed: workoutsThisWeek,
                        planned: plannedThisWeek
                    )

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    StreakBadge(streak: currentUser?.currentStreak ?? 0)
                }
                ToolbarItem(placement: .principal) {
                    Text("Grove")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: Text("Profile")) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
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
            let exerciseLog = ExerciseLog(
                exercise: exercise,
                orderIndex: index,
                targetSets: defaultSets,
                targetReps: defaultReps
            )
            exerciseLog.workout = workout
            modelContext.insert(exerciseLog)

            for setNumber in 1...defaultSets {
                let setLog = SetLog(setNumber: setNumber)
                setLog.exerciseLog = exerciseLog
                exerciseLog.sets.append(setLog)
                modelContext.insert(setLog)
            }
        }

        template.usageCount += 1
        template.lastUsedDate = Date()

        sessionManager.startWorkout(workout)
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak > 0 ? Color.groveTerracotta : Color.gray)
            Text("\(streak)")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.groveWarmSand.opacity(0.5))
        .clipShape(Capsule())
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

// MARK: - Weekly Stats Card

struct WeeklyStatsCard: View {
    let completed: Int
    let planned: Int

    private var hasPlans: Bool { planned > 0 }

    private var progress: Double {
        guard planned > 0 else { return 0 }
        return min(Double(completed) / Double(planned), 1.0)
    }

    private var summaryText: String {
        if hasPlans {
            return "\(completed) of \(planned) workouts"
        } else {
            return "\(completed) workout\(completed == 1 ? "" : "s")"
        }
    }

    private var subtitleText: String {
        if !hasPlans && completed == 0 {
            return "Plan your week to set goals"
        } else if completed >= planned && hasPlans {
            return "Week complete!"
        } else {
            return "This week"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.groveSage)
                Text("Weekly Progress")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                Text(summaryText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveSage)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.groveWarmSand.opacity(0.4))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.groveSage)
                        .frame(width: hasPlans ? geo.size.width * progress : (completed > 0 ? geo.size.width * 0.5 : 0), height: 8)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)

            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
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
        case .custom: return "star.circle.fill"
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
                    RecentWorkoutRow(workout: workout)

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

#Preview("Home - Empty") {
    HomeView()
        .environment(WorkoutSessionManager())
        .modelContainer(for: [User.self, WorkoutPlan.self, WorkoutTemplate.self, Workout.self, Exercise.self], inMemory: true)
}

#Preview("Home - With Workouts") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: User.self, Workout.self, ExerciseLog.self, WorkoutPlan.self, WorkoutTemplate.self, Exercise.self,
        configurations: config
    )

    // Create sample workouts
    let workout1 = Workout(name: "Push Day")
    workout1.startedAt = Date().addingTimeInterval(-3600) // 1 hour ago
    workout1.completedAt = Date()

    let workout2 = Workout(name: "Leg Day")
    workout2.startedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    workout2.completedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())!.addingTimeInterval(2700)

    let workout3 = Workout(name: "Pull Day")
    workout3.startedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    workout3.completedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())!.addingTimeInterval(3000)

    let workout4 = Workout(name: "Upper Body")
    workout4.startedAt = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    workout4.completedAt = Calendar.current.date(byAdding: .day, value: -5, to: Date())!.addingTimeInterval(2400)

    container.mainContext.insert(workout1)
    container.mainContext.insert(workout2)
    container.mainContext.insert(workout3)
    container.mainContext.insert(workout4)

    return HomeView()
        .environment(WorkoutSessionManager())
        .modelContainer(container)
}
