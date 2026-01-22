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
                        .foregroundStyle(Color.groveCharcoal)

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

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color.groveCream)
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
                        .foregroundStyle(Color.groveCharcoal)
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Empty Today Card

struct EmptyTodayCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Color.groveSage.opacity(0.6))

            Text("No workout planned for today")
                .font(.headline)
                .foregroundStyle(Color.groveCharcoal)

            Text("Start a quick workout or plan your week")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                // TODO: Create workout
            }) {
                Text("Start Empty Workout")
            }
            .buttonStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
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
        case .custom: return "star.circle.fill"
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 36))
            .foregroundStyle(Color.groveSage)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [User.self, WorkoutPlan.self, WorkoutTemplate.self])
}
