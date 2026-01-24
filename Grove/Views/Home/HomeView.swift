import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(
        filter: #Predicate<WorkoutPlan> { plan in
            plan.isRestDay == false
        },
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Message
                    Text(welcomeMessage)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)

                    // Quick Start Section
                    QuickStartSection()

                    // Calendar Strip
                    CalendarStripView()

                    // Today's Workout Card
                    if let plan = todaysPlan, let template = plan.template {
                        TodayWorkoutCard(
                            workoutName: template.name,
                            exerciseCount: template.exerciseIDs.count,
                            category: template.category
                        )
                    } else {
                        EmptyTodayCard()
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
        }
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
                // TODO: Start workout
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

                Text("Use Quick Start above or tap + to begin")
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
        .modelContainer(for: [User.self, WorkoutPlan.self, WorkoutTemplate.self, Workout.self])
}

#Preview("Home - With Workouts") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: User.self, Workout.self, ExerciseLog.self, WorkoutPlan.self, WorkoutTemplate.self,
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
        .modelContainer(container)
}
