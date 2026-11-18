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

    // MARK: - Shared stats

    /// One set of numbers for both unlocking and the progress bars, so a bar can never
    /// read full while the badge stays locked.
    private struct Stats {
        let completedWorkouts: [Workout]
        let workoutCount: Int
        /// Best of current and longest streak: a streak counts even if it has since broken.
        let bestStreak: Int
        let uniquePRExerciseCount: Int
        let uniqueExerciseCount: Int
        let uniqueMuscleGroupCount: Int
        let totalCompletedSets: Int
        let hasEarlyWorkout: Bool
        let hasLateWorkout: Bool
        let hasLongWorkout: Bool

        init(user: User) {
            let calendar = Calendar.current
            // Only this user's workouts, everywhere (not a store-wide count).
            completedWorkouts = user.workouts.filter { $0.completedAt != nil }
            workoutCount = completedWorkouts.count
            bestStreak = max(user.currentStreak, user.longestStreak)
            // Baselines from first-time exercises are not PRs
            uniquePRExerciseCount = Set(PRDetectionService.newPRRecords(from: user.personalRecords).compactMap { $0.exercise?.id }).count
            let logs = completedWorkouts.flatMap { $0.exercises }.filter { $0.status == .completed }
            uniqueExerciseCount = Set(logs.compactMap { $0.exercise?.id }).count
            uniqueMuscleGroupCount = Set(logs.compactMap { $0.exercise?.muscleGroup }).count
            totalCompletedSets = logs.flatMap { $0.sets }.filter { $0.isCompleted && !$0.isWarmup }.count
            // Early Bird: started 4–8 AM. Night Owl: finished 9 PM–4 AM ("complete after 9 PM").
            hasEarlyWorkout = completedWorkouts.contains { (4..<8).contains(calendar.component(.hour, from: $0.startedAt)) }
            hasLateWorkout = completedWorkouts.contains { workout in
                guard let end = workout.completedAt else { return false }
                let hour = calendar.component(.hour, from: end)
                return hour >= 21 || hour < 4
            }
            hasLongWorkout = completedWorkouts.contains { $0.duration >= 5400 }
        }
    }

    /// Set once a workout has actually been posted to the feed (see `CloudKitSocialService`).
    /// Socializer uses this instead of `Workout.isShared`, which is set before uploading.
    static let hasPostedWorkoutKey = "grove_hasPostedWorkout"

    private static var hasPostedWorkout: Bool {
        UserDefaults.standard.bool(forKey: hasPostedWorkoutKey)
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

        let stats = Stats(user: user)
        let completedWorkouts = stats.completedWorkouts
        let workoutCount = stats.workoutCount
        let streak = stats.bestStreak

        for type in AchievementType.allCases {
            guard !existingTypes.contains(type) else { continue }

            var earned = false
            var relatedData: String?

            switch type {
            // -- Workout milestones --
            case .firstRep:
                earned = workoutCount >= 1
                relatedData = completedWorkouts.min { ($0.completedAt ?? .distantFuture) < ($1.completedAt ?? .distantFuture) }?.name

            case .tenDown:
                earned = workoutCount >= 10
                relatedData = "\(workoutCount) workouts"

            case .quarterCentury:
                earned = workoutCount >= 25
                relatedData = "\(workoutCount) workouts"

            case .consistent:
                earned = workoutCount >= 50
                relatedData = "\(workoutCount) workouts"

            case .centuryClub:
                earned = workoutCount >= 100
                relatedData = "\(workoutCount) workouts"

            case .dedicated:
                earned = workoutCount >= 200
                relatedData = "\(workoutCount) workouts"

            // -- Streak milestones --
            case .threePeat:
                earned = streak >= 3
                relatedData = "\(streak)-day streak"

            case .weekWarrior:
                earned = streak >= 7
                relatedData = "\(streak)-day streak"

            case .fortnight:
                earned = streak >= 14
                relatedData = "\(streak)-day streak"

            case .ironWill:
                earned = streak >= 30
                relatedData = "\(streak)-day streak"

            case .legendary:
                earned = streak >= 60
                relatedData = "\(streak)-day streak"

            case .unstoppable:
                earned = streak >= 100
                relatedData = "\(streak)-day streak"

            // -- Personal records --
            case .prCrusher:
                // Also counts PRs from before achievements existed.
                earned = !newPRs.isEmpty || stats.uniquePRExerciseCount >= 1
                relatedData = newPRs.first?.exercise.name

            case .prCollector:
                earned = stats.uniquePRExerciseCount >= 5
                relatedData = "\(stats.uniquePRExerciseCount) exercises"

            case .prMachine:
                earned = stats.uniquePRExerciseCount >= 10
                relatedData = "\(stats.uniquePRExerciseCount) exercises"

            // -- Variety & planning --
            case .explorer:
                earned = stats.uniqueExerciseCount >= 10
                relatedData = "\(stats.uniqueExerciseCount) exercises"

            case .wellRounded:
                earned = stats.uniqueMuscleGroupCount >= 6
                relatedData = "\(stats.uniqueMuscleGroupCount) muscle groups"

            case .planner:
                earned = checkFullPlannedWeek(for: user, context: context)
                relatedData = "Full week completed"

            // -- Special --
            case .earlyBird:
                earned = stats.hasEarlyWorkout
                relatedData = "Early morning workout"

            case .nightOwl:
                earned = stats.hasLateWorkout
                relatedData = "Late night workout"

            case .marathoner:
                earned = stats.hasLongWorkout
                relatedData = "90+ minute workout"

            case .socializer:
                earned = hasPostedWorkout
                relatedData = "Shared a workout"

            case .volumeKing:
                earned = stats.totalCompletedSets >= 1000
                relatedData = "\(stats.totalCompletedSets) sets"

            case .creatineCommit:
                earned = user.creatineLogs.count >= 30
                relatedData = "\(user.creatineLogs.count) days logged"

            case .customCreator:
                earned = !user.customExercises.isEmpty
                relatedData = user.customExercises.first?.name
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
        // Keep the earliest unlock if duplicates ever exist, instead of crashing.
        let unlockedMap = Dictionary(
            user.achievements.map { ($0.type, $0.unlockedAt) },
            uniquingKeysWith: { min($0, $1) }
        )

        let stats = Stats(user: user)
        let completedWorkoutCount = stats.workoutCount
        let streak = stats.bestStreak
        let uniquePRExerciseCount = stats.uniquePRExerciseCount
        let uniqueExerciseCount = stats.uniqueExerciseCount
        let uniqueMuscleGroupCount = stats.uniqueMuscleGroupCount
        let totalCompletedSets = stats.totalCompletedSets

        return AchievementType.allCases.map { type in
            let isUnlocked = unlockedMap[type] != nil

            let (current, target): (Int, Int) = {
                switch type {
                // -- Workout milestones --
                case .firstRep:
                    return (min(completedWorkoutCount, 1), 1)
                case .tenDown:
                    return (min(completedWorkoutCount, 10), 10)
                case .quarterCentury:
                    return (min(completedWorkoutCount, 25), 25)
                case .consistent:
                    return (min(completedWorkoutCount, 50), 50)
                case .centuryClub:
                    return (min(completedWorkoutCount, 100), 100)
                case .dedicated:
                    return (min(completedWorkoutCount, 200), 200)

                // -- Streak milestones --
                case .threePeat:
                    return (min(isUnlocked ? max(streak, 3) : streak, 3), 3)
                case .weekWarrior:
                    return (min(isUnlocked ? max(streak, 7) : streak, 7), 7)
                case .fortnight:
                    return (min(isUnlocked ? max(streak, 14) : streak, 14), 14)
                case .ironWill:
                    return (min(isUnlocked ? max(streak, 30) : streak, 30), 30)
                case .legendary:
                    return (min(isUnlocked ? max(streak, 60) : streak, 60), 60)
                case .unstoppable:
                    return (min(isUnlocked ? max(streak, 100) : streak, 100), 100)

                // -- Personal records --
                case .prCrusher:
                    return (isUnlocked ? 1 : min(uniquePRExerciseCount, 1), 1)
                case .prCollector:
                    return (min(uniquePRExerciseCount, 5), 5)
                case .prMachine:
                    return (min(uniquePRExerciseCount, 10), 10)

                // -- Variety & planning --
                case .explorer:
                    return (min(uniqueExerciseCount, 10), 10)
                case .wellRounded:
                    return (min(uniqueMuscleGroupCount, 6), 6)
                case .planner:
                    return (isUnlocked ? 1 : 0, 1)

                // -- Special --
                case .earlyBird:
                    return (isUnlocked || stats.hasEarlyWorkout ? 1 : 0, 1)
                case .nightOwl:
                    return (isUnlocked || stats.hasLateWorkout ? 1 : 0, 1)
                case .marathoner:
                    return (isUnlocked || stats.hasLongWorkout ? 1 : 0, 1)
                case .socializer:
                    return (isUnlocked || hasPostedWorkout ? 1 : 0, 1)
                case .volumeKing:
                    return (min(totalCompletedSets, 1000), 1000)
                case .creatineCommit:
                    return (min(user.creatineLogs.count, 30), 30)
                case .customCreator:
                    let hasCustom = !user.customExercises.isEmpty
                    return (isUnlocked || hasCustom ? 1 : 0, 1)
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

    /// Whether any of the last 4 finished Mon–Sun weeks had a plan every day with every
    /// non-rest day completed. (Checking only last week missed weeks if nothing ran the
    /// achievement check during the following week.)
    private static func checkFullPlannedWeek(for user: User, context: ModelContext) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let lastMonday = previousMonday(from: today, calendar: calendar) else { return false }

        return (0..<4).contains { weeksBack in
            guard let monday = calendar.date(byAdding: .day, value: -7 * weeksBack, to: lastMonday) else { return false }
            return (0..<7).allSatisfy { dayOffset in
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monday),
                      let plan = user.plans.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else {
                    return false
                }
                return plan.isRestDay || plan.completedWorkout != nil
            }
        }
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
