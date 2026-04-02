import Foundation
import SwiftData

struct StreakManager {

    // MARK: - Recalculate Streak

    /// Recalculates the streak using week-based logic.
    ///
    /// Rules:
    /// - Streak increments by 1 for each unique day a workout was completed.
    /// - Two workouts on the same day count as 1.
    /// - **Plan-aware mode** (user has an active plan): streak breaks if an entire
    ///   Mon-Sun calendar week passes with zero workouts.
    /// - **No-plan mode**: streak breaks after 7 consecutive days of inactivity.
    /// - Today is a grace period — the current (partial) week is never counted as empty.
    /// - When `streakPaused` is true, the current streak value is preserved unchanged.
    static func recalculateStreak(for user: User, workouts: [Workout], plans: [WorkoutPlan]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build set of unique workout dates
        var workoutDates = Set<Date>()
        for workout in workouts {
            if let completedAt = workout.completedAt {
                workoutDates.insert(calendar.startOfDay(for: completedAt))
            }
        }

        let hasActivePlan = !user.weeklyTemplateIDs.isEmpty && !user.preferredTrainingSlots.isEmpty

        let streak: Int
        if hasActivePlan {
            streak = calculatePlanAwareStreak(
                workoutDates: workoutDates,
                user: user,
                today: today,
                calendar: calendar
            )
        } else {
            streak = calculateNoPlanStreak(
                workoutDates: workoutDates,
                user: user,
                today: today,
                calendar: calendar
            )
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
    }

    // MARK: - Plan-Aware Streak (Week Chunks)

    /// Walks backwards week by week (Mon-Sun). The current partial week always contributes.
    /// A full past week with zero workouts breaks the streak (unless streak is paused).
    private static func calculatePlanAwareStreak(
        workoutDates: Set<Date>,
        user: User,
        today: Date,
        calendar: Calendar
    ) -> Int {
        // When paused, preserve the current streak value — don't recalculate
        if user.streakPaused { return user.currentStreak }

        var streak = 0
        let currentMonday = mondayOfWeek(for: today, calendar: calendar)

        // Current (partial) week: count workout days from Monday through today
        streak += countWorkoutDays(
            from: currentMonday,
            through: today,
            in: workoutDates,
            calendar: calendar
        )

        // Walk backwards through full past weeks
        var weekMonday = calendar.date(byAdding: .day, value: -7, to: currentMonday)!

        for _ in 0..<52 {
            let weekSunday = calendar.date(byAdding: .day, value: 6, to: weekMonday)!

            let workoutsInWeek = countWorkoutDays(
                from: weekMonday,
                through: weekSunday,
                in: workoutDates,
                calendar: calendar
            )

            if workoutsInWeek == 0 {
                break
            }

            streak += workoutsInWeek
            weekMonday = calendar.date(byAdding: .day, value: -7, to: weekMonday)!
        }

        return streak
    }

    // MARK: - No-Plan Streak (7-Day Inactivity)

    /// Walks backwards day by day. Streak breaks after 7 consecutive non-workout days.
    private static func calculateNoPlanStreak(
        workoutDates: Set<Date>,
        user: User,
        today: Date,
        calendar: Calendar
    ) -> Int {
        // When paused, preserve the current streak value — don't recalculate
        if user.streakPaused { return user.currentStreak }

        var streak = 0
        var consecutiveInactiveDays = 0
        var currentDate = today
        var isFirstDay = true

        for _ in 0..<365 {
            if workoutDates.contains(currentDate) {
                streak += 1
                consecutiveInactiveDays = 0
            } else if isFirstDay {
                // Grace period — skip today
            } else {
                consecutiveInactiveDays += 1
                if consecutiveInactiveDays >= 7 {
                    break
                }
            }

            isFirstDay = false
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = prev
        }

        return streak
    }

    // MARK: - Helpers

    /// Returns the Monday (start of ISO week) for the week containing the given date.
    private static func mondayOfWeek(for date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysSinceMonday = (weekday + 5) % 7 // Sun=1 → 6, Mon=2 → 0, Tue=3 → 1, ...
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: date)!
    }

    /// Counts unique workout days in a date range (inclusive).
    private static func countWorkoutDays(
        from start: Date,
        through end: Date,
        in workoutDates: Set<Date>,
        calendar: Calendar
    ) -> Int {
        var count = 0
        var date = start
        while date <= end {
            if workoutDates.contains(date) {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return count
    }

}
