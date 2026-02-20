import Foundation
import SwiftData

struct StreakManager {

    // MARK: - Record a Workout

    /// Called after a workout is completed. Updates streak based on gap since last workout.
    ///
    /// Streak rule: after completing a workout, the user has until the end of the next calendar
    /// day to either complete another workout (increments streak) or mark it as a rest day
    /// (preserves streak). If neither happens by midnight, the streak breaks.
    ///
    /// - daysBetween 0: same day — no streak change
    /// - daysBetween 1: next day — streak continues (increment)
    /// - daysBetween 2+: gap too large — streak resets (rest days in between are handled
    ///   by recalculateStreak which checks each day individually)
    static func recordWorkout(for user: User, on date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let lastDate = user.lastWorkoutDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                // Same day — no streak change
            } else if daysBetween == 1 {
                // Next day — streak continues
                user.currentStreak += 1
            } else {
                // 2+ day gap — check if rest days bridge the gap
                // Walk forward from lastDay+1 to today-1 and verify each day is a rest day
                // This is handled more accurately by recalculateStreak, but for immediate
                // feedback we do a simple check: if the user had consecutiveRestDays covering
                // the gap, the streak was preserved
                let gapDays = daysBetween - 1 // days between last workout and today
                if gapDays <= user.consecutiveRestDays && user.consecutiveRestDays <= 3 {
                    // Rest days bridged the gap
                    user.currentStreak += 1
                } else {
                    // Gap not covered by rest days — streak broken, start fresh
                    user.previousStreak = user.currentStreak
                    user.currentStreak = 1
                }
            }
        } else {
            // First workout ever
            user.currentStreak = 1
        }

        user.lastWorkoutDate = today
        user.consecutiveRestDays = 0
        user.isStreakWilted = false

        if user.currentStreak > user.longestStreak {
            user.longestStreak = user.currentStreak
        }
    }

    // MARK: - Record a Rest Day

    /// Preserves the streak for today without incrementing it. The user must mark
    /// a rest day before midnight or their streak breaks. Max 3 consecutive rest days
    /// before the streak breaks regardless.
    static func recordRestDay(for user: User) {
        user.consecutiveRestDays += 1

        if user.consecutiveRestDays > 3 && !isOnVacation(user: user) {
            user.previousStreak = user.currentStreak
            user.wiltedAtStage = PlantStage.from(streak: user.currentStreak).rawValue
            user.isStreakWilted = true
            user.currentStreak = 0
        }
    }

    // MARK: - Full Recalculation

    /// Recalculates the streak by walking backwards from today.
    ///
    /// Rules:
    /// - Today is a "grace period": if no workout and no rest day yet, but yesterday had
    ///   a workout or valid rest day, the streak is still alive (user has until midnight).
    /// - A workout day increments the streak.
    /// - A rest day (or vacation day) preserves the streak without incrementing, up to
    ///   3 consecutive rest days max (vacation days don't count toward the limit).
    /// - Any day with no workout, no rest day, and no vacation breaks the streak.
    static func recalculateStreak(for user: User, workouts: [Workout], plans: [WorkoutPlan]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build lookup sets for completed workout dates and rest day dates
        var workoutDates = Set<Date>()
        for workout in workouts {
            if let completedAt = workout.completedAt {
                workoutDates.insert(calendar.startOfDay(for: completedAt))
            }
        }

        var restDayDates = Set<Date>()
        for plan in plans where plan.isRestDay {
            restDayDates.insert(calendar.startOfDay(for: plan.date))
        }

        var streak = 0
        var consecutiveRest = 0
        var currentDate = today
        var isFirstDay = true // today gets grace period treatment

        // Walk backwards day by day
        while true {
            let isWorkoutDay = workoutDates.contains(currentDate)
            let isRestDay = restDayDates.contains(currentDate)
            let onVacation = isOnVacation(user: user, on: currentDate)

            if isWorkoutDay {
                streak += 1
                consecutiveRest = 0
                isFirstDay = false
            } else if isRestDay || onVacation {
                consecutiveRest += 1
                if consecutiveRest > 3 && !onVacation {
                    break
                }
                isFirstDay = false
                // Rest/vacation days preserve streak but don't increment
            } else if isFirstDay {
                // Today has no workout and no rest day yet — grace period.
                // The streak is still alive as long as yesterday continues the chain.
                // Don't increment, don't break — just move to yesterday.
                isFirstDay = false
            } else {
                // Past day with no workout, no rest day, no vacation — streak broken
                break
            }

            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDate

            // Safety: don't go back more than 365 days
            let daysBefore = calendar.dateComponents([.day], from: currentDate, to: today).day ?? 0
            if daysBefore > 365 {
                break
            }
        }

        // Detect if streak was lost
        if streak == 0 && user.currentStreak > 0 {
            user.previousStreak = user.currentStreak
            user.wiltedAtStage = PlantStage.from(streak: user.currentStreak).rawValue
            user.isStreakWilted = true
        }

        user.currentStreak = streak
        if streak > user.longestStreak {
            user.longestStreak = streak
        }

        // Update consecutive rest days from today backwards
        var restCount = 0
        var checkDate = today
        while restDayDates.contains(checkDate) && !workoutDates.contains(checkDate) {
            restCount += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        user.consecutiveRestDays = restCount
    }

    // MARK: - Vacation Check

    /// Checks if the user is on vacation on a given date.
    static func isOnVacation(user: User, on date: Date = Date()) -> Bool {
        guard user.vacationModeEnabled else { return false }

        // If no date range is set, vacation mode applies broadly
        guard let start = user.vacationStartDate, let end = user.vacationEndDate else {
            return user.vacationModeEnabled
        }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let vacStart = calendar.startOfDay(for: start)
        let vacEnd = calendar.startOfDay(for: end)

        return day >= vacStart && day <= vacEnd
    }
}
