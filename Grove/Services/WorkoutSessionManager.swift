import SwiftUI
import SwiftData

@Observable
class WorkoutSessionManager {
    var activeWorkout: Workout?
    var isMinimized: Bool = false
    var isFullScreenPresented: Bool = false

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

    func endWorkout() {
        activeWorkout?.completedAt = Date()

        // Mark any in-progress exercises as completed
        if let exercises = activeWorkout?.exercises {
            for exercise in exercises {
                if exercise.status == .inProgress {
                    exercise.status = .completed
                }
            }
        }

        activeWorkout = nil
        isMinimized = false
        isFullScreenPresented = false
    }
}
