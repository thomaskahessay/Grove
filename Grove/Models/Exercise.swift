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

    init(
        name: String,
        muscleGroup: MuscleGroup,
        muscleSubgroup: String? = nil,
        isBuiltIn: Bool = true
    ) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.muscleSubgroup = muscleSubgroup
        self.isBuiltIn = isBuiltIn
    }
}
