import Foundation
import SwiftData

@Model
class SetLog {
    var id: UUID = UUID()
    var exerciseLog: ExerciseLog?
    var setNumber: Int
    var weight: Double?
    var reps: Int?
    var isCompleted: Bool = false
    var completedAt: Date?
    var lastSessionWeight: Double?
    var lastSessionReps: Int?
    var bodyweightModifier: BodyweightModifier = .none

    init(setNumber: Int, weight: Double? = nil, reps: Int? = nil, bodyweightModifier: BodyweightModifier = .none) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.bodyweightModifier = bodyweightModifier
    }
}
