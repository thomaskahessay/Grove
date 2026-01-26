import Foundation
import SwiftData

struct StreakManager {

    // MARK: - Record a Workout

    /// Called after a workout is completed. Updates streak based on gap since last workout.
    static func recordWorkout(for user: User, on date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let lastDate = user.lastWorkoutDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                // Same day — no streak change
            } else if daysBetween == 1 {
                // Consecutive day — increment streak
                user.currentStreak += 1
            } else if daysBetween <= 4 {
                // 2–4 day gap: streak continues if rest days cover the gap
                // (rest days are tracked via consecutiveRestDays)
                user.currentStreak += 1
            } else {
                // 5+ day gap — reset streak
                user.currentStreak = 1
            }
        } else {
            // First workout ever
            user.currentStreak = 1
        }

        user.lastWorkoutDate = today
        user.consecutiveRestDays = 0

        if user.currentStreak > user.longestStreak {
            user.longestStreak = user.currentStreak
        }
    }

    // MARK: - Record a Rest Day

    /// Increments consecutive rest days. Resets streak if too many consecutive rest days without vacation.
    static func recordRestDay(for user: User) {
        user.consecutiveRestDays += 1

        if user.consecutiveRestDays > 3 && !isOnVacation(user: user) {
            user.currentStreak = 0
        }
    }

    // MARK: - Full Recalculation

    /// Walks backwards from today counting consecutive valid days (workout or planned rest, max 3 consecutive rest).
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

        // Walk backwards day by day
        while true {
            let isWorkoutDay = workoutDates.contains(currentDate)
            let isRestDay = restDayDates.contains(currentDate)
            let onVacation = isOnVacation(user: user, on: currentDate)

            if isWorkoutDay {
                streak += 1
                consecutiveRest = 0
            } else if isRestDay || onVacation {
                consecutiveRest += 1
                if consecutiveRest > 3 && !onVacation {
                    break
                }
                // Rest days preserve streak but don't increment it
                // Only count if there's already a streak going
                if streak == 0 {
                    // Haven't found a workout yet — keep looking back
                } else {
                    // Valid rest day within streak
                }
            } else {
                // No workout, no rest day, no vacation — streak broken
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
