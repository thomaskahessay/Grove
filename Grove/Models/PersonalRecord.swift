import Foundation
import SwiftData

enum PRType: String, Codable {
    case maxWeight = "Max Weight"
    case estimatedOneRM = "Estimated 1RM" // Legacy — no longer created
}

@Model
class PersonalRecord {
    var id: UUID = UUID()
    var user: User?
    var exercise: Exercise?

    // Type of PR (always .maxWeight for new records)
    var type: PRType

    // The lift that achieved the PR
    var weight: Double
    var reps: Int
    var value: Double // Always equals weight for new records

    // When it was achieved
    var achievedAt: Date

    // Reference to the actual set (optional, for navigation)
    var setLogID: UUID?

    init(
        exercise: Exercise,
        weight: Double,
        reps: Int,
        achievedAt: Date = Date(),
        setLogID: UUID? = nil
    ) {
        self.exercise = exercise
        self.type = .maxWeight
        self.weight = weight
        self.reps = reps
        self.value = weight
        self.achievedAt = achievedAt
        self.setLogID = setLogID
    }
}
