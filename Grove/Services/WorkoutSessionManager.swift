import SwiftUI
import SwiftData

@MainActor
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

    // Streak moment state
    var showingStreakMoment: Bool = false
    var streakMomentData: StreakMomentData?

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

    var workoutProgressFraction: Double {
        guard let workout = activeWorkout, workout.exercises.count > 0 else { return 0 }
        let completed = workout.exercises.filter { $0.status == .completed || $0.status == .skipped }.count
        return Double(completed) / Double(workout.exercises.count)
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

        // Link workout to user (needed for achievement/PR tracking via user.workouts)
        if activeWorkout?.user == nil {
            activeWorkout?.user = user
        }

        // Mark any in-progress exercises as completed
        if let exercises = activeWorkout?.exercises {
            for exercise in exercises {
                if exercise.status == .inProgress {
                    exercise.status = .completed
                }
            }
        }

        // Update streak (capture pre/post stage for streak moment)
        let preWorkoutStage = user.map { PlantStage.from(streak: $0.currentStreak) }
        if let user = user {
            StreakManager.recordWorkout(for: user)
        }
        let postWorkoutStage = user.map { PlantStage.from(streak: $0.currentStreak) }

        // Persist immediately so @Query results include this workout before
        // HomeView.onAppear triggers recalculateStreak (which would otherwise
        // overwrite the streak with stale query data).
        if let context = context {
            try? context.save()
        }

        // Build streak moment data
        if let pre = preWorkoutStage, let post = postWorkoutStage, let user = user {
            let isStageUp = post.rawValue > pre.rawValue
            streakMomentData = StreakMomentData(
                streak: user.currentStreak,
                isStageUp: isStageUp,
                previousStage: pre,
                currentStage: post,
                isWilted: false
            )
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

        // Delay summary presentation until fullScreenCover dismissal completes.
        // SwiftUI crashes if a sheet is presented while a fullScreenCover is being dismissed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingSummary = true
        }
    }

    func dismissSummary() {
        showingSummary = false
        completedWorkout = nil
        newAchievements = []

        // Chain streak moment after summary dismisses
        if streakMomentData != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showingStreakMoment = true
            }
        }
    }

    func dismissStreakMoment() {
        showingStreakMoment = false
        streakMomentData = nil

        // Update last seen plant stage
        if let user = user {
            user.lastSeenPlantStage = PlantStage.from(streak: user.currentStreak).rawValue
        }
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
