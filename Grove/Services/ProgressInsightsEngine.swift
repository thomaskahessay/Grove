import Foundation
import SwiftData

struct ProgressInsight: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
    let color: String // "sage", "terracotta", "rust"
}

struct ProgressInsightsEngine {

    /// Returns 1-2 most relevant insights based on current data.
    static func generateInsights(
        user: User,
        completedWorkouts: [Workout],
        plans: [WorkoutPlan]
    ) -> [ProgressInsight] {
        var insights: [ProgressInsight] = []

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Volume trend: compare this week vs last week
        if let thisMonday = currentMonday(from: today, calendar: calendar),
           let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday) {
            let thisWeekVolume = weeklyVolume(workouts: completedWorkouts, weekStart: thisMonday, calendar: calendar)
            let lastWeekVolume = weeklyVolume(workouts: completedWorkouts, weekStart: lastMonday, calendar: calendar)

            if lastWeekVolume > 0 && thisWeekVolume > 0 {
                let change = ((thisWeekVolume - lastWeekVolume) / lastWeekVolume) * 100
                if change > 5 {
                    insights.append(ProgressInsight(
                        icon: "arrow.up.right",
                        message: "Your total volume is up \(Int(change))% from last week — keep pushing!",
                        color: "sage"
                    ))
                } else if change < -5 {
                    insights.append(ProgressInsight(
                        icon: "arrow.down.right",
                        message: "Volume dipped \(abs(Int(change)))% from last week. Rest weeks are important too.",
                        color: "rust"
                    ))
                }
            }
        }

        // PR momentum
        let recentPRs = user.personalRecords.filter { $0.type == .maxWeight }
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        let thisWeekPRs = recentPRs.filter { $0.achievedAt >= oneWeekAgo }
        if let latestPR = thisWeekPRs.sorted(by: { $0.achievedAt > $1.achievedAt }).first,
           let exerciseName = latestPR.exercise?.name {
            let weightStr = latestPR.weight == floor(latestPR.weight) ?
                String(format: "%.0f", latestPR.weight) :
                String(format: "%.1f", latestPR.weight)
            let unit = user.preferredUnits == .metric ? "kg" : "lbs"
            insights.append(ProgressInsight(
                icon: "trophy.fill",
                message: "New PR on \(exerciseName) this week! \(weightStr) \(unit).",
                color: "terracotta"
            ))
        } else if recentPRs.allSatisfy({ $0.achievedAt < thirtyDaysAgo }) && !recentPRs.isEmpty {
            // Per-exercise plateau detection (60+ days without PR)
            let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: today) ?? today
            var latestPRByExercise: [UUID: (name: String, date: Date)] = [:]
            for pr in recentPRs {
                guard let exerciseID = pr.exercise?.id, let name = pr.exercise?.name else { continue }
                if let existing = latestPRByExercise[exerciseID] {
                    if pr.achievedAt > existing.date {
                        latestPRByExercise[exerciseID] = (name, pr.achievedAt)
                    }
                } else {
                    latestPRByExercise[exerciseID] = (name, pr.achievedAt)
                }
            }

            if let stalest = latestPRByExercise.values
                .filter({ $0.date < sixtyDaysAgo })
                .sorted(by: { $0.date < $1.date })
                .first {
                let daysSincePR = calendar.dateComponents([.day], from: stalest.date, to: today).day ?? 0
                insights.append(ProgressInsight(
                    icon: "chart.line.flattrend.xyaxis",
                    message: "No PR on \(stalest.name) in \(daysSincePR) days — consider a deload or variation.",
                    color: "rust"
                ))
            } else {
                insights.append(ProgressInsight(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "No PRs in the last 30 days — try adding weight to your strongest lifts.",
                    color: "rust"
                ))
            }
        }

        // Consistency / adherence
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        let recentPlans = plans.filter { !$0.isRestDay && $0.date >= fourWeeksAgo && $0.date <= today }
        if recentPlans.count >= 8 {
            let completed = recentPlans.filter { $0.completedWorkout != nil }.count
            let adherence = Double(completed) / Double(recentPlans.count) * 100
            if adherence >= 90 {
                insights.append(ProgressInsight(
                    icon: "checkmark.seal.fill",
                    message: "Incredible consistency — \(Int(adherence))% plan adherence over 4 weeks!",
                    color: "sage"
                ))
            }
        }

        // Streak milestone
        if user.currentStreak > 0 && user.currentStreak >= user.longestStreak {
            insights.append(ProgressInsight(
                icon: "flame.fill",
                message: "This is your longest streak ever at \(user.currentStreak) days!",
                color: "terracotta"
            ))
        }

        // Return top 2 most relevant
        return Array(insights.prefix(2))
    }

    // MARK: - Helpers

    private static func currentMonday(from date: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: date)
        let daysBack: Int
        if weekday == 1 {
            daysBack = 6
        } else {
            daysBack = weekday - 2
        }
        return calendar.date(byAdding: .day, value: -daysBack, to: date)
    }

    private static func weeklyVolume(workouts: [Workout], weekStart: Date, calendar: Calendar) -> Double {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        var total: Double = 0

        for workout in workouts {
            guard let completedAt = workout.completedAt,
                  completedAt >= weekStart && completedAt < weekEnd else { continue }

            for log in workout.exercises where log.status == .completed {
                for set in log.sets where set.isCompleted {
                    if let weight = set.weight, let reps = set.reps {
                        total += weight * Double(reps)
                    }
                }
            }
        }
        return total
    }
}
