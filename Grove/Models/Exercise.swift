import Foundation
import SwiftData

@Model
class Exercise {
    var id: UUID = UUID()
    var name: String
    var muscleGroup: MuscleGroup
    var muscleSubgroup: String?
    var isBuiltIn: Bool = true
    var createdBy: User?

    // For smart suggestions - track if user consistently removes this
    var removalCount: Int = 0

    // For smart builder ordering: compounds go first in workouts
    var isCompound: Bool = false
    var sortPriority: Int = 50  // lower = earlier in workout (compounds 10-20, isolations 50-80)

    // Bodyweight exercises show a mode picker (Bodyweight / Weighted / Assisted) instead of always requiring weight
    var isBodyweight: Bool = false

    // Rest timer length chosen by the user; nil falls back to a compound/isolation default
    var restSeconds: Int?

    /// Compounds get longer rest by default since they tax more muscle.
    var effectiveRestSeconds: Int {
        restSeconds ?? (isCompound ? 120 : 90)
    }

    init(
        name: String,
        muscleGroup: MuscleGroup,
        muscleSubgroup: String? = nil,
        isBuiltIn: Bool = true,
        isCompound: Bool = false,
        sortPriority: Int = 50,
        isBodyweight: Bool = false
    ) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.muscleSubgroup = muscleSubgroup
        self.isBuiltIn = isBuiltIn
        self.isCompound = isCompound
        self.sortPriority = sortPriority
        self.isBodyweight = isBodyweight
    }
}
