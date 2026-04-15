import SwiftUI
import SwiftData
import WidgetKit

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

    // HealthKit connect state
    var showingHealthKitConnect: Bool = false
    var pendingHealthKitWorkout: Workout?

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

    /// Checks for an incomplete workout (no completedAt) and resumes it as minimized.
    /// Only resumes workouts started within the last 24 hours; older ones are cleaned up.
    func resumeIncompleteWorkout(context: ModelContext) {
        guard activeWorkout == nil else { return }
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.completedAt == nil },
            sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)]
        )
        guard let incompleteWorkouts = try? context.fetch(descriptor) else { return }

        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)

        // Separate fresh from stale before any deletion to avoid accessing deleted objects
        let freshWorkouts = incompleteWorkouts.filter { $0.startedAt >= cutoff }
        let staleWorkouts = incompleteWorkouts.filter { $0.startedAt < cutoff }

        // Clean up old abandoned workouts
        for workout in staleWorkouts {
            for exerciseLog in workout.exercises {
                for setLog in exerciseLog.sets {
                    context.delete(setLog)
                }
                context.delete(exerciseLog)
            }
            context.delete(workout)
        }
        do {
            try context.save()
        } catch {
            print("[Grove] ERROR: Failed to save after cleaning up stale workouts: \(error)")
        }

        // Resume the most recent fresh workout if it has exercises
        guard let recent = freshWorkouts.first,
              !recent.exercises.isEmpty else { return }
        activeWorkout = recent
        isMinimized = true
        isFullScreenPresented = false
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

        // Capture pre-workout stage before updating streak
        let preWorkoutStage = user.map { PlantStage.from(streak: $0.currentStreak) }

        // Persist immediately so recalculateStreak sees the new workout in its fetch
        if let context = context {
            do {
                try context.save()
            } catch {
                print("[Grove] ERROR: Failed to save workout completion: \(error)")
            }
        }

        if let user = user, let context = context {
            let allWorkouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
            let completedWorkouts = allWorkouts.filter { $0.completedAt != nil }
            let allPlans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
            StreakManager.recalculateStreak(for: user, workouts: completedWorkouts, plans: allPlans)
            if user.currentStreak > 0 {
                user.isStreakWilted = false
            }

            // Persist streak before PR/achievement detection so it's not lost if app exits
            do {
                try context.save()
            } catch {
                print("[Grove] ERROR: Failed to save streak update: \(error)")
            }
        }

        let postWorkoutStage = user.map { PlantStage.from(streak: $0.currentStreak) }

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

        // Refresh widgets with updated streak/plan data
        WidgetCenter.shared.reloadAllTimelines()

        // Cancel abandoned workout notification since workout is now complete
        NotificationService.shared.cancelAbandonedWorkoutReminder()

        // Delay presentation until fullScreenCover dismissal completes.
        // SwiftUI crashes if a sheet is presented while a fullScreenCover is being dismissed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if HealthKitManager.shared.isAuthorized,
               let workout = self.completedWorkout,
               let endDate = workout.completedAt {
                // Check for matches before showing the sheet to avoid blank flash
                Task {
                    let matches = await HealthKitManager.shared.findOverlappingWorkouts(
                        workoutStart: workout.startedAt,
                        workoutEnd: endDate
                    )
                    if matches.isEmpty {
                        self.showingSummary = true
                    } else {
                        self.pendingHealthKitWorkout = workout
                        self.showingHealthKitConnect = true
                    }
                }
            } else {
                self.showingSummary = true
            }
        }
    }

    func finishHealthKitConnect() {
        showingHealthKitConnect = false
        pendingHealthKitWorkout = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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

    // MARK: - Shared Workout Creation

    /// Creates and starts a workout from a template, with auto-fill from last session.
    /// Used by FAB menu, HomeView today card, and QuickStartSection template buttons.
    static func createAndStartWorkout(
        from template: WorkoutTemplate,
        allExercises: [Exercise],
        context: ModelContext,
        sessionManager: WorkoutSessionManager
    ) {
        let exercises = template.exerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }
        guard !exercises.isEmpty else { return }

        let defaultSets = template.defaultSets
        let defaultReps = template.defaultReps

        let workout = Workout(name: template.name, templateUsed: template)
        context.insert(workout)

        for (index, exercise) in exercises.enumerated() {
            let history = getExerciseHistory(exercise, context: context, sessionCount: 2)
            let lastSets = history.first ?? []
            let numberOfSets = lastSets.isEmpty ? defaultSets : lastSets.count

            let exerciseLog = ExerciseLog(
                exercise: exercise,
                orderIndex: index,
                targetSets: numberOfSets,
                targetReps: defaultReps
            )
            exerciseLog.workout = workout
            context.insert(exerciseLog)

            let isBodyweight = exercise.isBodyweight
            for setNumber in 1...numberOfSets {
                let lastSetData = lastSets.indices.contains(setNumber - 1) ? lastSets[setNumber - 1] : nil
                let modifier: BodyweightModifier = {
                    if !isBodyweight { return .none }
                    if let lastMod = lastSetData?.modifier, lastMod != .none { return lastMod }
                    return .bodyweight
                }()
                let setLog = SetLog(
                    setNumber: setNumber,
                    weight: modifier == .bodyweight ? nil : lastSetData?.weight,
                    reps: lastSetData?.reps,
                    bodyweightModifier: modifier
                )
                setLog.lastSessionWeight = lastSetData?.weight
                setLog.lastSessionReps = lastSetData?.reps
                let nudge = computeNudge(
                    forSetPosition: setNumber - 1,
                    history: history,
                    isCompound: exercise.isCompound
                )
                setLog.suggestedWeight = nudge.weight
                setLog.suggestedReps = nudge.reps
                setLog.exerciseLog = exerciseLog
                exerciseLog.sets.append(setLog)
                context.insert(setLog)
            }
        }

        template.usageCount += 1
        template.lastUsedDate = Date()

        do {
            try context.save()
        } catch {
            print("[Grove] ERROR: Failed to save new workout: \(error)")
        }

        sessionManager.startWorkout(workout)
    }

    /// Gets the most recent completed sets for an exercise from prior workouts.
    private static func getLastSetsForExercise(_ exercise: Exercise, context: ModelContext) -> [(weight: Double?, reps: Int?, modifier: BodyweightModifier)] {
        let history = getExerciseHistory(exercise, context: context, sessionCount: 1)
        return history.first ?? []
    }

    /// Gets completed sets from the last N sessions for an exercise, most recent first.
    private static func getExerciseHistory(
        _ exercise: Exercise,
        context: ModelContext,
        sessionCount: Int = 2
    ) -> [[(weight: Double?, reps: Int?, modifier: BodyweightModifier)]] {
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exerciseID
            }
        )

        guard let logs = try? context.fetch(descriptor) else { return [] }

        // Sort in memory — SortDescriptor through optional relationships
        // (\.workout?.completedAt) crashes SwiftData's schema validation.
        let completedLogs = logs
            .filter { $0.workout?.completedAt != nil }
            .sorted { ($0.workout?.completedAt ?? .distantPast) > ($1.workout?.completedAt ?? .distantPast) }
        let sessionsToUse = completedLogs.prefix(sessionCount)

        return sessionsToUse.map { log in
            log.sets
                .filter { $0.isCompleted }
                .sorted { $0.setNumber < $1.setNumber }
                .map { (weight: $0.weight, reps: $0.reps, modifier: $0.bodyweightModifier ?? .none) }
        }
    }

    /// Computes a progressive nudge suggestion for a specific set position.
    /// Returns a suggested weight increase (for weighted exercises) or rep increase (for bodyweight).
    private static func computeNudge(
        forSetPosition index: Int,
        history: [[(weight: Double?, reps: Int?, modifier: BodyweightModifier)]],
        isCompound: Bool
    ) -> (weight: Double?, reps: Int?) {
        guard history.count >= 2 else { return (nil, nil) }

        let session1 = history[0] // most recent
        let session2 = history[1] // second most recent

        guard index < session1.count, index < session2.count else { return (nil, nil) }

        let set1 = session1[index]
        let set2 = session2[index]

        let weight1 = set1.weight
        let weight2 = set2.weight
        let reps1 = set1.reps
        let reps2 = set2.reps

        let isBodyweight1 = weight1 == nil || weight1 == 0
        let isBodyweight2 = weight2 == nil || weight2 == 0

        if isBodyweight1 && isBodyweight2 {
            // Bodyweight exercise: nudge +1 rep if reps were consistent
            if let r1 = reps1, let r2 = reps2, r1 == r2 {
                return (nil, r1 + 1)
            }
        } else if let w1 = weight1, let w2 = weight2, w1 > 0, w2 > 0, w1 == w2 {
            // Weighted exercise: nudge weight up if both sessions used the same weight
            if reps1 != nil && reps2 != nil {
                let increment = isCompound ? 5.0 : 2.5
                return (w1 + increment, nil)
            }
        }

        return (nil, nil)
    }

    func discardWorkout(context: ModelContext) {
        guard let workout = activeWorkout else { return }

        // Dismiss the UI first so SwiftUI stops reading from the model objects.
        // Deleting data while the fullScreenCover is still presented causes a
        // fault crash (detached backing data) during the dismiss animation.
        activeWorkout = nil
        isMinimized = false
        isFullScreenPresented = false

        // Cancel abandoned workout notification since workout is discarded
        NotificationService.shared.cancelAbandonedWorkoutReminder()

        // Delete the data after the dismiss animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for exerciseLog in workout.exercises {
                for setLog in exerciseLog.sets {
                    context.delete(setLog)
                }
                context.delete(exerciseLog)
            }
            context.delete(workout)

            do {
                try context.save()
            } catch {
                print("[Grove] ERROR: Failed to save workout discard: \(error)")
            }
        }
    }
}
