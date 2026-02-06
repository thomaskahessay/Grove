import Foundation
import SwiftData

enum PRType: String, Codable {
    case maxWeight = "Max Weight"
    case estimatedOneRM = "Estimated 1RM"
}

@Model
class PersonalRecord {
    var id: UUID = UUID()
    var user: User?
    var exercise: Exercise?

    // Type of PR
    var type: PRType

    // The lift that achieved the PR
    var weight: Double
    var reps: Int
    var value: Double // The actual PR value (weight for maxWeight, calculated 1RM for estimatedOneRM)

    // When it was achieved
    var achievedAt: Date

    // Reference to the actual set (optional, for navigation)
    var setLogID: UUID?

    init(
        exercise: Exercise,
        type: PRType,
        weight: Double,
        reps: Int,
        achievedAt: Date = Date(),
        setLogID: UUID? = nil
    ) {
        self.exercise = exercise
        self.type = type
        self.weight = weight
        self.reps = reps
        self.achievedAt = achievedAt
        self.setLogID = setLogID

        switch type {
        case .maxWeight:
            self.value = weight
        case .estimatedOneRM:
            self.value = PersonalRecord.calculateOneRM(weight: weight, reps: reps)
        }
    }

    /// Calculates estimated 1RM using Brzycki formula (most accurate for <10 reps)
    /// Falls back to Epley for higher reps
    static func calculateOneRM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }

        if reps == 1 {
            return weight
        } else if reps <= 10 {
            // Brzycki formula: weight × (36 / (37 - reps))
            return weight * (36.0 / (37.0 - Double(reps)))
        } else {
            // Epley formula for higher reps: weight × (1 + reps/30)
            return weight * (1.0 + Double(reps) / 30.0)
        }
    }
}
