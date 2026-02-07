import Foundation
import SwiftData

struct AchievementService {

    struct AchievementResult {
        let achievement: Achievement
        let type: AchievementType
    }

    struct AchievementProgress {
        let type: AchievementType
        let isUnlocked: Bool
        let unlockedAt: Date?
        let currentValue: Int
        let targetValue: Int

        var progressFraction: Double {
            guard targetValue > 0 else { return 0 }
            return min(Double(currentValue) / Double(targetValue), 1.0)
        }
    }

    // MARK: - Detection

    /// Checks all achievement conditions and returns newly unlocked ones.
    /// Call after streak update and PR detection in endWorkout().
    static func checkAndAwardAchievements(
        for user: User,
        context: ModelContext,
        newPRs: [PRDetectionService.PRResult] = []
    ) -> [AchievementResult] {
        let existingTypes = Set(user.achievements.map { $0.type })
        var results: [AchievementResult] = []

        let completedWorkouts = user.workouts.filter { $0.completedAt != nil }
        let workoutCount = completedWorkouts.count

        for type in AchievementType.allCases {
            guard !existingTypes.contains(type) else { continue }

            var earned = false
            var relatedData: String?

            switch type {
            case .firstRep:
                earned = workoutCount >= 1
                relatedData = completedWorkouts.last?.name

            case .weekWarrior:
                earned = user.currentStreak >= 7
                relatedData = "\(user.currentStreak)-day streak"

            case .consistent:
                earned = workoutCount >= 50
                relatedData = "\(workoutCount) workouts"

            case .prCrusher:
                earned = !newPRs.isEmpty
                relatedData = newPRs.first?.exercise.name

            case .planner:
                earned = checkFullPlannedWeek(for: user, context: context)
                relatedData = "Full week completed"

            case .centuryClub:
                earned = workoutCount >= 100
                relatedData = "\(workoutCount) workouts"

            case .ironWill:
                earned = user.currentStreak >= 30
                relatedData = "\(user.currentStreak)-day streak"
            }

            if earned {
                let achievement = Achievement(type: type, user: user, relatedData: relatedData)
                context.insert(achievement)
                results.append(AchievementResult(achievement: achievement, type: type))
            }
        }

        if !results.isEmpty {
            try? context.save()
        }

        return results
    }

    // MARK: - Progress

    /// Returns progress info for all achievement types (for gallery view).
    static func getProgress(
        for user: User,
        context: ModelContext
    ) -> [AchievementProgress] {
        let unlockedMap = Dictionary(
            uniqueKeysWithValues: user.achievements.map { ($0.type, $0.unlockedAt) }
        )

        // Use fetchCount to avoid loading full object graphs into memory
        let workoutPredicate = #Predicate<Workout> { $0.completedAt != nil }
        let completedWorkoutCount = (try? context.fetchCount(FetchDescriptor<Workout>(predicate: workoutPredicate))) ?? 0
        let prCount = (try? context.fetchCount(FetchDescriptor<PersonalRecord>())) ?? 0

        return AchievementType.allCases.map { type in
            let isUnlocked = unlockedMap[type] != nil

            let (current, target): (Int, Int) = {
                switch type {
                case .firstRep:
                    return (min(completedWorkoutCount, 1), 1)
                case .weekWarrior:
                    let best = isUnlocked ? max(user.currentStreak, 7) : user.currentStreak
                    return (min(best, 7), 7)
                case .consistent:
                    return (min(completedWorkoutCount, 50), 50)
                case .prCrusher:
                    return (min(prCount, 1), 1)
                case .planner:
                    return (isUnlocked ? 1 : 0, 1)
                case .centuryClub:
                    return (min(completedWorkoutCount, 100), 100)
                case .ironWill:
                    let best = isUnlocked ? max(user.longestStreak, 30) : user.longestStreak
                    return (min(best, 30), 30)
                }
            }()

            return AchievementProgress(
                type: type,
                isUnlocked: isUnlocked,
                unlockedAt: unlockedMap[type],
                currentValue: current,
                targetValue: target
            )
        }
    }

    // MARK: - Helpers

    /// Checks if any full Mon-Sun week has all plans completed.
    private static func checkFullPlannedWeek(for user: User, context: ModelContext) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check the week that just ended (last Monday through Sunday)
        guard let lastMonday = previousMonday(from: today, calendar: calendar) else { return false }

        var allDaysPlanned = true
        var allWorkoutsCompleted = true

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: lastMonday) else {
                allDaysPlanned = false
                break
            }

            let plan = user.plans.first { plan in
                calendar.isDate(plan.date, inSameDayAs: day)
            }

            guard let plan = plan else {
                allDaysPlanned = false
                break
            }

            if !plan.isRestDay && plan.completedWorkout == nil {
                allWorkoutsCompleted = false
                break
            }
        }

        return allDaysPlanned && allWorkoutsCompleted
    }

    private static func previousMonday(from date: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        // Days to go back to reach the previous Monday
        let daysBack: Int
        if weekday == 1 {
            daysBack = 6 // Sunday -> previous Monday = 6 days back
        } else {
            daysBack = weekday - 2 // Mon=0, Tue=1, ... Sat=5
        }
        // Go to the Monday of *last* week (7 more days back)
        return calendar.date(byAdding: .day, value: -(daysBack + 7), to: date)
    }
}
