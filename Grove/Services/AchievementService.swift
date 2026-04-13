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

        // Precompute data needed by multiple checks
        let uniquePRExerciseCount = Set(user.personalRecords.compactMap { $0.exercise?.id }).count
        let allExerciseLogs = completedWorkouts.flatMap { $0.exercises }
        let completedExerciseLogs = allExerciseLogs.filter { $0.status == .completed }
        let uniqueExerciseIDs = Set(completedExerciseLogs.compactMap { $0.exercise?.id })
        let uniqueMuscleGroups = Set(completedExerciseLogs.compactMap { $0.exercise?.muscleGroup })
        let totalCompletedSets = completedExerciseLogs.flatMap { $0.sets }.filter { $0.isCompleted }.count

        for type in AchievementType.allCases {
            guard !existingTypes.contains(type) else { continue }

            var earned = false
            var relatedData: String?

            switch type {
            // -- Workout milestones --
            case .firstRep:
                earned = workoutCount >= 1
                relatedData = completedWorkouts.last?.name

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
                earned = user.currentStreak >= 3
                relatedData = "\(user.currentStreak)-day streak"

            case .weekWarrior:
                earned = user.currentStreak >= 7
                relatedData = "\(user.currentStreak)-day streak"

            case .fortnight:
                earned = user.currentStreak >= 14
                relatedData = "\(user.currentStreak)-day streak"

            case .ironWill:
                earned = user.currentStreak >= 30
                relatedData = "\(user.currentStreak)-day streak"

            case .legendary:
                earned = user.currentStreak >= 60
                relatedData = "\(user.currentStreak)-day streak"

            case .unstoppable:
                earned = user.currentStreak >= 100
                relatedData = "\(user.currentStreak)-day streak"

            // -- Personal records --
            case .prCrusher:
                earned = !newPRs.isEmpty
                relatedData = newPRs.first?.exercise.name

            case .prCollector:
                earned = uniquePRExerciseCount >= 5
                relatedData = "\(uniquePRExerciseCount) exercises"

            case .prMachine:
                earned = uniquePRExerciseCount >= 10
                relatedData = "\(uniquePRExerciseCount) exercises"

            // -- Variety & planning --
            case .explorer:
                earned = uniqueExerciseIDs.count >= 10
                relatedData = "\(uniqueExerciseIDs.count) exercises"

            case .wellRounded:
                earned = uniqueMuscleGroups.count >= 6
                relatedData = "\(uniqueMuscleGroups.count) muscle groups"

            case .planner:
                earned = checkFullPlannedWeek(for: user, context: context)
                relatedData = "Full week completed"

            // -- Special --
            case .earlyBird:
                let calendar = Calendar.current
                earned = completedWorkouts.contains { workout in
                    let hour = calendar.component(.hour, from: workout.startedAt)
                    return hour < 8
                }
                relatedData = "Early morning workout"

            case .nightOwl:
                let calendar = Calendar.current
                earned = completedWorkouts.contains { workout in
                    let hour = calendar.component(.hour, from: workout.startedAt)
                    return hour >= 21
                }
                relatedData = "Late night workout"

            case .marathoner:
                earned = completedWorkouts.contains { $0.duration >= 5400 }
                relatedData = "90+ minute workout"

            case .socializer:
                earned = user.workouts.contains { $0.isShared }
                relatedData = "Shared a workout"

            case .volumeKing:
                earned = totalCompletedSets >= 1000
                relatedData = "\(totalCompletedSets) sets"

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
        let unlockedMap = Dictionary(
            uniqueKeysWithValues: user.achievements.map { ($0.type, $0.unlockedAt) }
        )

        let workoutPredicate = #Predicate<Workout> { $0.completedAt != nil }
        let completedWorkoutCount = (try? context.fetchCount(FetchDescriptor<Workout>(predicate: workoutPredicate))) ?? 0

        // Precompute expensive data only once
        let completedWorkouts = user.workouts.filter { $0.completedAt != nil }
        let uniquePRExerciseCount = Set(user.personalRecords.compactMap { $0.exercise?.id }).count
        let allCompletedExerciseLogs = completedWorkouts.flatMap { $0.exercises }.filter { $0.status == .completed }
        let uniqueExerciseCount = Set(allCompletedExerciseLogs.compactMap { $0.exercise?.id }).count
        let uniqueMuscleGroupCount = Set(allCompletedExerciseLogs.compactMap { $0.exercise?.muscleGroup }).count
        let totalCompletedSets = allCompletedExerciseLogs.flatMap { $0.sets }.filter { $0.isCompleted }.count

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
                    let best = isUnlocked ? max(user.currentStreak, 3) : user.currentStreak
                    return (min(best, 3), 3)
                case .weekWarrior:
                    let best = isUnlocked ? max(user.currentStreak, 7) : user.currentStreak
                    return (min(best, 7), 7)
                case .fortnight:
                    let best = isUnlocked ? max(user.currentStreak, 14) : user.currentStreak
                    return (min(best, 14), 14)
                case .ironWill:
                    let best = isUnlocked ? max(user.longestStreak, 30) : user.longestStreak
                    return (min(best, 30), 30)
                case .legendary:
                    let best = isUnlocked ? max(user.longestStreak, 60) : user.longestStreak
                    return (min(best, 60), 60)
                case .unstoppable:
                    let best = isUnlocked ? max(user.longestStreak, 100) : user.longestStreak
                    return (min(best, 100), 100)

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
                    let hasEarly = completedWorkouts.contains { Calendar.current.component(.hour, from: $0.startedAt) < 8 }
                    return (isUnlocked || hasEarly ? 1 : 0, 1)
                case .nightOwl:
                    let hasLate = completedWorkouts.contains { Calendar.current.component(.hour, from: $0.startedAt) >= 21 }
                    return (isUnlocked || hasLate ? 1 : 0, 1)
                case .marathoner:
                    let hasLong = completedWorkouts.contains { $0.duration >= 5400 }
                    return (isUnlocked || hasLong ? 1 : 0, 1)
                case .socializer:
                    let hasShared = user.workouts.contains { $0.isShared }
                    return (isUnlocked || hasShared ? 1 : 0, 1)
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
