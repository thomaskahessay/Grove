import Foundation
import SwiftData

@Model
class Workout {
    var id: UUID = UUID()
    var user: User?
    var name: String
    var templateUsed: WorkoutTemplate?

    var startedAt: Date = Date()
    var completedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.workout)
    var exercises: [ExerciseLog] = []

    // HealthKit data (linked after workout)
    var healthKitWorkoutID: UUID?
    var heartRateMin: Double?
    var heartRateMax: Double?
    var heartRateAvg: Double?
    var caloriesBurned: Double?

    // Social sharing
    var isShared: Bool = false
    var shareWorkoutName: Bool = true
    var shareDuration: Bool = true
    var shareExercises: Bool = false
    var shareWeights: Bool = false

    var notes: String?

    // Computed properties
    var duration: TimeInterval {
        guard let end = completedAt else { return Date().timeIntervalSince(startedAt) }
        return end.timeIntervalSince(startedAt)
    }

    var completedExerciseCount: Int {
        exercises.filter { $0.status == .completed }.count
    }

    var skippedExerciseCount: Int {
        exercises.filter { $0.status == .skipped }.count
    }

    var totalExerciseCount: Int {
        exercises.count
    }

    init(name: String, user: User? = nil, templateUsed: WorkoutTemplate? = nil) {
        self.name = name
        self.user = user
        self.templateUsed = templateUsed
    }
}
