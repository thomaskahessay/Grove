import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { $0.completedAt != nil },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]
    @Query private var users: [User]
    @Query(sort: \PersonalRecord.achievedAt, order: .reverse) private var allRecords: [PersonalRecord]
    @Query(sort: \WorkoutPlan.date) private var allPlans: [WorkoutPlan]
    @Query private var creatineLogs: [CreatineLog]

    @State private var showingExercisePicker = false
    @State private var searchText = ""
    @State private var selectedExerciseForDetail: Exercise?
    @State private var achievementProgress: [AchievementService.AchievementProgress] = []

    private var currentUser: User? { users.first }

    private var unitLabel: String {
        currentUser?.preferredUnits == .metric ? "kg" : "lbs"
    }

    // MARK: - Computed Data

    /// Current max-weight PR per exercise, sorted by most recently achieved
    private var currentPRs: [PersonalRecord] {
        let maxWeightRecords = allRecords.filter { $0.type == .maxWeight }
        var bestByExercise: [UUID: PersonalRecord] = [:]
        for record in maxWeightRecords {
            guard let exerciseID = record.exercise?.id else { continue }
            if let existing = bestByExercise[exerciseID] {
                if record.value > existing.value || (record.value == existing.value && record.reps > existing.reps) {
                    bestByExercise[exerciseID] = record
                }
            } else {
                bestByExercise[exerciseID] = record
            }
        }
        return bestByExercise.values.sorted {
            if $0.achievedAt != $1.achievedAt { return $0.achievedAt > $1.achievedAt }
            return ($0.exercise?.name ?? "") < ($1.exercise?.name ?? "")
        }
    }

    private var exercisesWithHistory: [(exercise: Exercise, count: Int)] {
        var exerciseUsage: [UUID: (exercise: Exercise, count: Int)] = [:]
        for workout in completedWorkouts {
            for log in workout.exercises where log.exercise != nil && log.status == .completed {
                let exercise = log.exercise!
                if let existing = exerciseUsage[exercise.id] {
                    exerciseUsage[exercise.id] = (exercise, existing.count + 1)
                } else {
                    exerciseUsage[exercise.id] = (exercise, 1)
                }
            }
        }
        return exerciseUsage.values.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.exercise.name < $1.exercise.name
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if completedWorkouts.isEmpty {
                        emptyStateView
                    } else {
                        weeklySummaryCard
                        prShowcase
                        exerciseProgressSection
                        consistencySection
                        if currentUser?.trackCreatine == true {
                            creatineConsistencyCard
                        }
                        programSection
                        insightsCard
                        achievementsSection
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color.groveBackground)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedExerciseForDetail) { exercise in
                ExerciseProgressDetailView(initialExercise: exercise)
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet(
                    exercises: exercisesWithHistory,
                    selectedExercise: Binding(
                        get: { selectedExerciseForDetail },
                        set: { newVal in
                            selectedExerciseForDetail = newVal
                        }
                    ),
                    searchText: $searchText
                )
                .presentationDetents([.medium, .large])
            }
            .onAppear { loadAchievements() }
            .onChange(of: currentUser?.achievements.count) { _, _ in loadAchievements() }
        }
    }

    // MARK: - Section 1: Weekly Summary

    private var weeklySummaryCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysBack = weekday == 1 ? 6 : weekday - 2
        let monday = calendar.date(byAdding: .day, value: -daysBack, to: today)!
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!

        let weekWorkouts = completedWorkouts.filter { workout in
            guard let date = workout.completedAt else { return false }
            return date >= monday && date <= calendar.date(byAdding: .day, value: 1, to: sunday)!
        }

        let weekPlans = allPlans.filter { $0.date >= monday && $0.date <= sunday }
        let plannedCount = weekPlans.filter { !$0.isRestDay }.count
        let completedCount = weekWorkouts.count

        let totalVolume: Double = weekWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { exTotal, log in
                guard log.status == .completed else { return exTotal }
                return exTotal + log.sets.filter { $0.isCompleted }.reduce(0) { setTotal, set in
                    setTotal + (set.weight ?? 0) * Double(set.reps ?? 0)
                }
            }
        }

        return VStack(spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)

                Spacer()

                Text(weekRangeString(monday: monday, sunday: sunday))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Day indicators
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let day = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
                    let dayLabel = dayAbbreviation(for: dayOffset)
                    let isToday = calendar.isDate(day, inSameDayAs: today)
                    let plan = weekPlans.first { calendar.isDate($0.date, inSameDayAs: day) }
                    let hasWorkout = weekWorkouts.contains { workout in
                        guard let date = workout.completedAt else { return false }
                        return calendar.isDate(date, inSameDayAs: day)
                    }
                    let isPast = day < today
                    let isRest = plan?.isRestDay == true

                    VStack(spacing: 6) {
                        Text(dayLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        ZStack {
                            if hasWorkout {
                                Circle()
                                    .fill(Color.groveSage)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if isRest {
                                Circle()
                                    .fill(Color.groveWarmSand.opacity(0.5))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.groveWarmSand)
                            } else if plan != nil && !isPast {
                                Circle()
                                    .strokeBorder(Color.groveSage, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                            } else if plan != nil && isPast {
                                Circle()
                                    .strokeBorder(Color.groveMutedRust.opacity(0.6), lineWidth: 2)
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle()
                                    .fill(Color.groveWarmSand.opacity(0.2))
                                    .frame(width: 28, height: 28)
                            }
                        }

                        if isToday {
                            Circle()
                                .fill(Color.groveSage)
                                .frame(width: 4, height: 4)
                        } else {
                            Spacer().frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Stats pills
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.groveSage)
                    Text(plannedCount > 0 ? "\(completedCount) / \(plannedCount) workouts" : "\(completedCount) workouts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.groveTerracotta)
                    Text("\(formatVolume(totalVolume)) \(unitLabel)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }

    // MARK: - Section 2: Personal Records

    private var prShowcase: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                PersonalRecordsView()
            } label: {
                HStack {
                    Text("Personal Records")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Spacer()
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.groveSage)
                }
            }
            .buttonStyle(.plain)

            if currentPRs.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.title3)
                        .foregroundStyle(Color.groveWarmSand)
                    Text("Complete workouts to start tracking PRs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(currentPRs.prefix(8)), id: \.id) { record in
                            Button {
                                if let exercise = record.exercise {
                                    selectedExerciseForDetail = exercise
                                }
                            } label: {
                                PRCard(record: record, unitLabel: unitLabel, isNew: isRecentPR(record))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Exercise Progress

    private var exerciseProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Progress")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 0) {
                let topExercises = Array(exercisesWithHistory.prefix(5))
                ForEach(Array(topExercises.enumerated()), id: \.element.exercise.id) { index, item in
                    Button {
                        selectedExerciseForDetail = item.exercise
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.groveText)

                                Text("\(item.count) workouts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Mini sparkline
                            MiniSparkline(dataPoints: sparklineData(for: item.exercise))
                                .frame(width: 60, height: 24)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < topExercises.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)

            if exercisesWithHistory.count > 5 {
                Button {
                    showingExercisePicker = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.subheadline)
                        Text("View All Exercises")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.groveSage)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section 4: Consistency

    private var consistencySection: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Adherence over last 4 weeks
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: today)!
        let recentPlans = allPlans.filter { !$0.isRestDay && $0.date >= fourWeeksAgo && $0.date <= today }
        let completedPlanCount = recentPlans.filter { $0.completedWorkout != nil }.count
        let adherencePercent = recentPlans.isEmpty ? 0 : Int(Double(completedPlanCount) / Double(recentPlans.count) * 100)

        // Weekly workout counts (last 8 weeks)
        let weeklyData = weeklyWorkoutCounts(weeksBack: 8)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Consistency")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 16) {
                // Adherence
                if !recentPlans.isEmpty {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Plan Adherence")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(adherencePercent)%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(adherencePercent >= 75 ? Color.groveSage : Color.groveTerracotta)
                        }

                        Spacer()

                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.groveWarmSand.opacity(0.3), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: Double(adherencePercent) / 100)
                                .stroke(
                                    adherencePercent >= 75 ? Color.groveSage : Color.groveTerracotta,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 50, height: 50)
                    }
                    .padding(.horizontal, 16)

                    Divider().padding(.horizontal, 16)
                }

                // Weekly frequency chart
                if !weeklyData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workouts per Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)

                        Chart {
                            ForEach(weeklyData) { week in
                                BarMark(
                                    x: .value("Week", week.label),
                                    y: .value("Count", week.count)
                                )
                                .foregroundStyle(Color.groveSage.gradient)
                                .cornerRadius(4)
                            }

                            if let goal = currentUser?.preferredDaysPerWeek, goal > 0 {
                                RuleMark(y: .value("Goal", goal))
                                    .foregroundStyle(Color.groveTerracotta.opacity(0.6))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text("Goal")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.groveTerracotta)
                                    }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(Color.groveWarmSand.opacity(0.3))
                                AxisValueLabel()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 120)
                        .padding(.horizontal, 16)
                    }
                }

                // Streak row
                if let user = currentUser {
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Color.groveTerracotta)
                            Text("\(user.currentStreak)")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.groveText)
                            Text("current")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)

                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(Color.groveWarmSand)
                            Text("\(user.longestStreak)")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.groveText)
                            Text("longest")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
    }

    // MARK: - Creatine Consistency

    private var creatineConsistencyCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)!.count
        let dayOfMonth = calendar.component(.day, from: today)

        let logsThisMonth = creatineLogs.filter {
            calendar.startOfDay(for: $0.date) >= startOfMonth
        }
        let loggedCount = logsThisMonth.count
        let progress = Double(loggedCount) / Double(dayOfMonth)

        let monthFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMMM"
            return f
        }()
        let monthName = monthFormatter.string(from: today)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color.groveSage)
                Text("Creatine")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                Text("\(loggedCount)/\(daysInMonth) in \(monthName)")
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.groveSage.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.groveSage)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            // Weekly dots for current month
            let weeks = creatineWeeklyDots(calendar: calendar, today: today, startOfMonth: startOfMonth, dayOfMonth: dayOfMonth)
            HStack(spacing: 3) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, logged in
                    Circle()
                        .fill(logged ? Color.groveSage : Color.groveSage.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }

    private func creatineWeeklyDots(calendar: Calendar, today: Date, startOfMonth: Date, dayOfMonth: Int) -> [Bool] {
        let logDates = Set(creatineLogs.map { calendar.startOfDay(for: $0.date) })
        return (0..<dayOfMonth).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startOfMonth)!
            return logDates.contains(day)
        }
    }

    // MARK: - Section 5: Your Program

    private var programSection: some View {
        Group {
            if let user = currentUser {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Program")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.preferredSplit.rawValue)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.groveText)

                                Text("\(user.preferredDaysPerWeek) days/week · \(user.preferredRepRange.rawValue)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        // Weekday indicators
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let isTraining = user.preferredTrainingSlots.contains(dayIndex)

                                VStack(spacing: 4) {
                                    Text(dayAbbreviation(for: dayIndex))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    Circle()
                                        .fill(isTraining ? Color.groveSage : Color.groveWarmSand.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            if isTraining {
                                                Image(systemName: "dumbbell.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        // Template names per training day
                        if !user.weeklyTemplateIDs.isEmpty {
                            let templates = resolveTemplates(user: user)
                            if !templates.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(templates, id: \.day) { item in
                                        HStack(spacing: 8) {
                                            Text(item.day)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.groveSage)
                                                .frame(width: 32, alignment: .leading)
                                            Text(item.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                }
            }
        }
    }

    // MARK: - Section 6: Insights

    private var insightsCard: some View {
        Group {
            if let user = currentUser {
                let insights = ProgressInsightsEngine.generateInsights(
                    user: user,
                    completedWorkouts: completedWorkouts,
                    plans: allPlans
                )

                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Insights")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(insights) { insight in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: insight.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(insightColor(insight.color))
                                        .frame(width: 20)

                                    Text(insight.message)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.groveText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
                    }
                }
            }
        }
    }

    // MARK: - Section 7: Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                AchievementsGalleryView()
            } label: {
                HStack {
                    Text("Achievements")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Spacer()
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.groveSage)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 14) {
                // Summary count
                let unlocked = achievementProgress.filter { $0.isUnlocked }.count
                let total = AchievementType.allCases.count

                HStack {
                    Text("\(unlocked) / \(total) earned")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveText)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Achievement icons row
                HStack(spacing: 0) {
                    ForEach(AchievementType.allCases, id: \.self) { type in
                        let progress = achievementProgress.first { $0.type == type }
                        let isUnlocked = progress?.isUnlocked == true

                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isUnlocked ? Color.groveSage : Color.groveWarmSand.opacity(0.2))
                                    .frame(width: 36, height: 36)

                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(isUnlocked ? .white : .secondary.opacity(0.5))
                            }

                            Text(type.shortLabel)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)

                // Next up card
                if let nextUp = achievementProgress.filter({ !$0.isUnlocked && $0.progressFraction > 0 })
                    .sorted(by: { $0.progressFraction > $1.progressFraction }).first {
                    Divider().padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        Image(systemName: nextUp.type.icon)
                            .font(.subheadline)
                            .foregroundStyle(Color.groveTerracotta)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next: \(nextUp.type.rawValue)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)

                            SwiftUI.ProgressView(value: nextUp.progressFraction)
                                .tint(Color.groveSage)
                        }

                        Text("\(nextUp.currentValue)/\(nextUp.targetValue)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Color.groveWarmSand)

            Text("No workout data yet")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            Text("Complete some workouts to see your progress here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Helpers

    private func loadAchievements() {
        if let user = currentUser {
            achievementProgress = AchievementService.getProgress(for: user, context: modelContext)
        }
    }

    private func isRecentPR(_ record: PersonalRecord) -> Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return record.achievedAt >= oneWeekAgo
    }

    private func dayAbbreviation(for index: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][index]
    }

    private func weekRangeString(monday: Date, sunday: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: monday)) – \(formatter.string(from: sunday))"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        } else {
            return String(format: "%.0f", volume)
        }
    }

    private func sparklineData(for exercise: Exercise) -> [Double] {
        var points: [Double] = []
        for workout in completedWorkouts.reversed() {
            guard let log = workout.exercises.first(where: {
                $0.exercise?.id == exercise.id && $0.status == .completed
            }) else { continue }

            let maxWeight = log.sets.filter { $0.isCompleted }
                .compactMap { $0.weight }.max() ?? 0
            if maxWeight > 0 { points.append(maxWeight) }
            if points.count >= 6 { break }
        }
        return points
    }

    private func insightColor(_ name: String) -> Color {
        switch name {
        case "sage": return Color.groveSage
        case "terracotta": return Color.groveTerracotta
        case "rust": return Color.groveMutedRust
        default: return Color.groveSage
        }
    }

    struct WeekData: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }

    private func weeklyWorkoutCounts(weeksBack: Int) -> [WeekData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysBack = weekday == 1 ? 6 : weekday - 2
        let currentMonday = calendar.date(byAdding: .day, value: -daysBack, to: today)!

        var data: [WeekData] = []
        for i in stride(from: weeksBack - 1, through: 0, by: -1) {
            let weekStart = calendar.date(byAdding: .day, value: -7 * i, to: currentMonday)!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

            let count = completedWorkouts.filter { workout in
                guard let date = workout.completedAt else { return false }
                return date >= weekStart && date < weekEnd
            }.count

            let label: String
            if i == 0 {
                label = "This"
            } else if i == 1 {
                label = "Last"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"
                label = formatter.string(from: weekStart)
            }

            data.append(WeekData(label: label, count: count))
        }
        return data
    }

    struct TemplateDay: Hashable {
        let day: String
        let name: String
    }

    private func resolveTemplates(user: User) -> [TemplateDay] {
        let allTemplates = user.customTemplates
        var result: [TemplateDay] = []
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        for (idx, slot) in user.preferredTrainingSlots.enumerated() {
            guard slot >= 0 && slot < 7 else { continue }
            let dayName = days[slot]

            if idx < user.weeklyTemplateIDs.count {
                let templateID = user.weeklyTemplateIDs[idx]
                if let template = allTemplates.first(where: { $0.id == templateID }) {
                    result.append(TemplateDay(day: dayName, name: template.name))
                }
            }
        }
        return result
    }
}

// MARK: - PR Card

private struct PRCard: View {
    let record: PersonalRecord
    let unitLabel: String
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.exercise?.name ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)
                    .lineLimit(1)

                Spacer()

                if isNew {
                    Text("NEW")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.groveTerracotta, in: Capsule())
                }
            }

            Text("\(record.weight.formatted()) \(unitLabel)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveTerracotta)

            Text("\(record.reps) reps")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(record.achievedAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }
}

// MARK: - Mini Sparkline

private struct MiniSparkline: View {
    let dataPoints: [Double]

    var body: some View {
        if dataPoints.count >= 2 {
            Chart(Array(dataPoints.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(Color.groveSage)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        } else {
            Rectangle()
                .fill(Color.clear)
        }
    }
}

// MARK: - Supporting Types (kept from original)

enum ProgressMetric: String, CaseIterable {
    case maxWeight = "Max"
    case bestSet = "Best"
    case totalVolume = "Volume"

    var shortName: String { rawValue }

    var fullName: String {
        switch self {
        case .maxWeight: return "Max Weight"
        case .bestSet: return "Best Set (Weight × Reps)"
        case .totalVolume: return "Total Volume"
        }
    }

    var unit: String { "lbs" }
}

enum TimeRange: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case allTime = "All"

    var label: String { rawValue }

    var fullLabel: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .allTime: return "All Time"
        }
    }

    var cutoffDate: Date {
        let calendar = Calendar.current
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        case .allTime:
            return Date.distantPast
        }
    }
}

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Floating Stat

struct FloatingStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    let exercises: [(exercise: Exercise, count: Int)]
    @Binding var selectedExercise: Exercise?
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss

    private var filteredExercises: [(exercise: Exercise, count: Int)] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises, id: \.exercise.id) { item in
                    Button {
                        selectedExercise = item.exercise
                        searchText = ""
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exercise.name)
                                    .font(.body)
                                    .foregroundStyle(Color.groveText)

                                Text("\(item.count) workouts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedExercise?.id == item.exercise.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.groveSage)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedExercise?.id == item.exercise.id
                            ? Color.groveSage.opacity(0.1)
                            : Color.clear
                    )
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        searchText = ""
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chart View

struct ExerciseProgressChart: View {
    let dataPoints: [ProgressDataPoint]
    let metric: ProgressMetric

    @State private var selectedPoint: ProgressDataPoint?

    var body: some View {
        Chart(dataPoints) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value(metric.shortName, point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.groveSage.opacity(0.25), Color.groveSage.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.shortName, point.value)
            )
            .foregroundStyle(Color.groveSage)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.shortName, point.value)
            )
            .foregroundStyle(selectedPoint?.id == point.id ? Color.groveTerracotta : Color.groveSage)
            .symbolSize(selectedPoint?.id == point.id ? 60 : 20)

            if let selected = selectedPoint, selected.id == point.id {
                RuleMark(x: .value("Date", point.date))
                    .foregroundStyle(Color.groveSage.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.groveWarmSand.opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.groveWarmSand.opacity(0.5))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedPoint = closestPoint(to: date)
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedPoint = nil
                                    }
                                }
                            }
                    )
            }
        }
        .chartBackground { proxy in
            if let selected = selectedPoint {
                GeometryReader { geometry in
                    if let x = proxy.position(forX: selected.date),
                       let y = proxy.position(forY: selected.value) {
                        TooltipView(date: selected.date, value: selected.value, metric: metric)
                            .position(
                                x: min(max(x, 50), geometry.size.width - 50),
                                y: max(y - 45, 30)
                            )
                    }
                }
            }
        }
    }

    private func closestPoint(to date: Date) -> ProgressDataPoint? {
        dataPoints.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}

// MARK: - Tooltip View

struct TooltipView: View {
    let date: Date
    let value: Double
    let metric: ProgressMetric

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var formattedValue: String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(formattedValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveText)

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }
}

// MARK: - Preview

#Preview {
    ProgressView()
        .modelContainer(.preview)
}
