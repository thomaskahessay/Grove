import Foundation
import SwiftData

@Model
class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String
    var category: TemplateCategory
    var isBuiltIn: Bool = true
    var user: User?

    // Exercises in this template (stored as exercise IDs for flexibility)
    var exerciseIDs: [UUID] = []
    var defaultSets: Int = 3
    var defaultReps: Int = 10

    // For smart suggestions
    var usageCount: Int = 0
    var lastUsedDate: Date?

    // Exercises user consistently removes from this template
    var excludedExerciseIDs: [UUID] = []

    init(name: String, category: TemplateCategory, isBuiltIn: Bool = true) {
        self.name = name
        self.category = category
        self.isBuiltIn = isBuiltIn
    }
}
