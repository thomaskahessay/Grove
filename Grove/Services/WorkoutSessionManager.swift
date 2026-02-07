import SwiftUI
import SwiftData

@Observable
class WorkoutSessionManager {
    var activeWorkout: Workout?
    var isMinimized: Bool = false
    var isFullScreenPresented: Bool = false

    // Summary state
    var completedWorkout: Workout?
    var showingSummary: Bool = false
    var newPRs: [PRDetectionService.PRResult] = []
    var newAchievements: [AchievementService.AchievementResult] = []

    // Streak & plan linking
    var user: User?
    var onWorkoutCompleted: ((Workout) -> Void)?

    var hasActiveWorkout: Bool {
        activeWorkout != nil && activeWorkout?.completedAt == nil
    }

    var workoutProgress: String {
        guard let workout = activeWorkout else { return "" }
        let completed = workout.exercises.filter { $0.status == .completed }.count
        let total = workout.exercises.count
        return "\(completed)/\(total) exercises"
    }

    func startWorkout(_ workout: Workout) {
        activeWorkout = workout
        isMinimized = false
        isFullScreenPresented = true
    }

    func minimizeWorkout() {
        isMinimized = true
        isFullScreenPresented = false
    }

    func expandWorkout() {
        isMinimized = false
        isFullScreenPresented = true
    }

    func endWorkout(context: ModelContext? = nil) {
        activeWorkout?.completedAt = Date()

        // Mark any in-progress exercises as completed
        if let exercises = activeWorkout?.exercises {
            for exercise in exercises {
                if exercise.status == .inProgress {
                    exercise.status = .completed
                }
            }
        }

        // Update streak
        if let user = user {
            StreakManager.recordWorkout(for: user)
        }

        // Detect PRs
        if let workout = activeWorkout, let user = user, let context = context {
            newPRs = PRDetectionService.detectAndSavePRs(for: workout, user: user, context: context)
        } else {
            newPRs = []
        }

        // Detect achievements
        if let user = user, let context = context {
            newAchievements = AchievementService.checkAndAwardAchievements(
                for: user, context: context, newPRs: newPRs
            )
        } else {
            newAchievements = []
        }

        // Store completed workout for summary
        completedWorkout = activeWorkout

        // Notify callback for plan linking
        if let workout = activeWorkout {
            onWorkoutCompleted?(workout)
        }

        activeWorkout = nil
        isMinimized = false
        isFullScreenPresented = false

        // Show summary
        showingSummary = true
    }

    func dismissSummary() {
        showingSummary = false
        completedWorkout = nil
        newAchievements = []
    }

    func discardWorkout(context: ModelContext) {
        guard let workout = activeWorkout else { return }

        // Delete all related data (sets, exercise logs, workout)
        for exerciseLog in workout.exercises {
            for setLog in exerciseLog.sets {
                context.delete(setLog)
            }
            context.delete(exerciseLog)
        }
        context.delete(workout)

        activeWorkout = nil
        isMinimized = false
        isFullScreenPresented = false
    }
}
