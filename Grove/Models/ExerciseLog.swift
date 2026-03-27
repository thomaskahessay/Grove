import Foundation
import SwiftData

@Model
class ExerciseLog {
    var id: UUID = UUID()
    var exercise: Exercise?
    var workout: Workout?
    var orderIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog] = []

    var targetSets: Int?
    var targetReps: Int?
    var status: ExerciseStatus = ExerciseStatus.planned

    // For pre-filling from last session
    var lastWeight: Double?
    var lastReps: Int?

    var hasLastSessionData: Bool {
        sets.contains { $0.lastSessionWeight != nil || $0.lastSessionReps != nil }
    }

    init(
        exercise: Exercise,
        orderIndex: Int,
        targetSets: Int? = nil,
        targetReps: Int? = nil
    ) {
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
    }
}
