import Foundation
import SwiftData

struct ExerciseResolver {

    struct ResolvedExercise {
        let name: String
        let exercise: Exercise?
        let wasCreated: Bool
    }

    /// Resolves exercise names to local Exercise objects via case-insensitive name matching.
    /// Built-in exercises (~180) are seeded identically on all devices by name, so they always match.
    static func resolve(
        names: [String],
        allExercises: [Exercise],
        context: ModelContext,
        createMissing: Bool = false
    ) -> [ResolvedExercise] {
        // Build case-insensitive lookup from existing exercises
        let lookup = Dictionary(
            allExercises.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return names.map { name in
            if let match = lookup[name.lowercased()] {
                return ResolvedExercise(name: name, exercise: match, wasCreated: false)
            } else if createMissing {
                let exercise = Exercise(
                    name: name,
                    muscleGroup: .fullBody,
                    isBuiltIn: false
                )
                context.insert(exercise)
                return ResolvedExercise(name: name, exercise: exercise, wasCreated: true)
            } else {
                return ResolvedExercise(name: name, exercise: nil, wasCreated: false)
            }
        }
    }
}
