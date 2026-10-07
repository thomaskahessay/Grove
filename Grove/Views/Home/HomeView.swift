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
    @Query private var creatineLogs: [CreatineLog]

    @State private var showingWeeklyPlan = false
    @State private var creatineCheckAnimation = false
    @State private var restNudgeDismissed = false

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

    private var todaysCreatineLog: CreatineLog? {
        let calendar = Calendar.current
        return creatineLogs.first { calendar.isDateInToday($0.date) }
    }

    private var creatineStreak: Int {
        let calendar = Calendar.current
        let sortedLogs = creatineLogs.sorted { $0.date > $1.date }
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for log in sortedLogs {
            let logDate = calendar.startOfDay(for: log.date)
            if logDate == checkDate {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if logDate < checkDate {
                break
            }
        }
        return streak
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
                    // Today's Workout Card
                    Group {
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
                                    isResuming: sessionManager.activeWorkout != nil,
                                    onStart: {
                                        if sessionManager.activeWorkout != nil {
                                            sessionManager.expandWorkout()
                                        } else {
                                            startTodaysWorkout(plan: plan)
                                        }
                                    }
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
                    }
                    .coachMarkAnchor(.todaysWorkout)

                    // Streak Plant
                    if let user = currentUser {
                        NavigationLink(destination: StreakDetailView(user: user)) {
                            StreakPlantView(
                                streak: user.currentStreak,
                                isWilted: user.isStreakWilted,
                                wiltedAtStage: PlantStage(rawValue: user.wiltedAtStage) ?? .seed,
                                size: 120,
                                showLabel: true
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .coachMarkAnchor(.streakPlant)

                        // Rest day nudge
                        if user.consecutiveRestDays >= 3, !restNudgeDismissed {
                            HStack(spacing: 12) {
                                Image(systemName: "sun.max.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.groveWarmSand)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Your plant could use some sunlight")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.groveText)
                                    Text((!user.weeklyTemplateIDs.isEmpty && !user.preferredTrainingSlots.isEmpty)
                                        ? "\(user.consecutiveRestDays) missed sessions — your grove misses you"
                                        : "\(user.consecutiveRestDays) rest days — your grove misses you")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    withAnimation { restNudgeDismissed = true }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(14)
                            .background(Color.groveWarmSand.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    // Creatine Check-in
                    if currentUser?.trackCreatine == true {
                        CreatinePillView(
                            isLogged: todaysCreatineLog != nil,
                            streak: creatineStreak,
                            animating: $creatineCheckAnimation,
                            onTap: { toggleCreatine() }
                        )
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
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .coachMarkAnchor(.planMyWeek)

                    // Recent Workouts Section
                    if !recentWorkouts.isEmpty {
                        RecentWorkoutsSection(workouts: recentWorkouts, allWorkouts: completedWorkouts)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color.groveBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(welcomeMessage)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .sheet(isPresented: $showingWeeklyPlan) {
                WeeklyPlanView()
            }
            .onAppear {
                // Skip recalculation when a workout was just completed — the streak
                // was already updated by recordWorkout() and the @Query results may
                // not yet include the new workout, which would cause recalculateStreak
                // to temporarily reset the streak to a wrong value.
                if let user = currentUser,
                   sessionManager.completedWorkout == nil && !sessionManager.showingSummary && !sessionManager.showingStreakMoment {
                    StreakManager.recalculateStreak(
                        for: user,
                        workouts: completedWorkouts,
                        plans: workoutPlans
                    )

                    // Auto-extend weekly plans if needed
                    SmartBuilderEngine.extendPlansIfNeeded(
                        user: user,
                        existingPlans: workoutPlans,
                        context: modelContext
                    )
                }
            }
        }
    }

    // MARK: - Start Today's Workout

    private func toggleCreatine() {
        if let existing = todaysCreatineLog {
            modelContext.delete(existing)
        } else {
            let log = CreatineLog()
            log.user = currentUser
            modelContext.insert(log)
            creatineCheckAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                creatineCheckAnimation = false
            }
        }
    }

    private func startTodaysWorkout(plan: WorkoutPlan) {
        guard let template = plan.template else { return }
        WorkoutSessionManager.createAndStartWorkout(
            from: template,
            allExercises: allExercises,
            context: modelContext,
            sessionManager: sessionManager
        )
    }
}

// MARK: - Today's Workout Card

struct TodayWorkoutCard: View {
    let workoutName: String
    let exerciseCount: Int
    let category: TemplateCategory
    var isResuming: Bool = false
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
                Text(isResuming ? "Resume Workout" : "Start Workout")
            }
            .buttonStyle(.primary)
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
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
        .glassEffect(.regular.tint(Color.groveTerracotta.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
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
        .glassEffect(.regular.tint(Color.groveTerracotta.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
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
    let allWorkouts: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(destination: AllWorkoutsView(workouts: allWorkouts)) {
                HStack {
                    Text("Recent Workouts")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
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
            // Category icon
            Image(systemName: workout.templateUsed?.category.icon ?? "dumbbell.fill")
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
        .contentShape(Rectangle())
    }
}

// MARK: - All Workouts View

struct AllWorkoutsView: View {
    let workouts: [Workout]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(groupedWorkouts, id: \.month) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.month)
                            .font(.headline)
                            .foregroundStyle(Color.groveText)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(group.workouts.enumerated()), id: \.element.id) { index, workout in
                                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                    RecentWorkoutRow(workout: workout)
                                }
                                .buttonStyle(.plain)

                                if index < group.workouts.count - 1 {
                                    Divider()
                                        .padding(.leading, 48)
                                }
                            }
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.groveBackground)
        .navigationTitle("All Workouts")
        .navigationBarTitleDisplayMode(.large)
    }

    private struct MonthGroup {
        let month: String
        let workouts: [Workout]
    }

    private var groupedWorkouts: [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [(key: String, workouts: [Workout])] = []
        var currentKey = ""
        var currentWorkouts: [Workout] = []

        for workout in workouts {
            guard let date = workout.completedAt else { continue }
            let key = formatter.string(from: date)
            if key != currentKey {
                if !currentWorkouts.isEmpty {
                    groups.append((key: currentKey, workouts: currentWorkouts))
                }
                currentKey = key
                currentWorkouts = [workout]
            } else {
                currentWorkouts.append(workout)
            }
        }
        if !currentWorkouts.isEmpty {
            groups.append((key: currentKey, workouts: currentWorkouts))
        }

        return groups.map { MonthGroup(month: $0.key, workouts: $0.workouts) }
    }
}


// MARK: - Creatine Pill

struct CreatinePillView: View {
    let isLogged: Bool
    let streak: Int
    @Binding var animating: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "drop.fill")
                    .font(.body)
                    .foregroundStyle(isLogged ? Color.groveSage : Color.groveSage.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(animating ? 1.3 : 1.0)
                    .animation(.spring(duration: 0.3, bounce: 0.4), value: animating)

                Text(isLogged ? "Creatine taken" : "Creatine")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isLogged ? Color.groveTextSecondary : Color.groveText)

                Spacer()

                if streak > 1 && isLogged {
                    Text("\(streak) days")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.tint(isLogged ? Color.groveSage.opacity(0.06) : .clear),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isLogged)
    }
}

#Preview {
    HomeView()
        .environment(WorkoutSessionManager())
        .modelContainer(.preview)
}
