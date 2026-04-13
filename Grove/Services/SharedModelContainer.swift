import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupID = "group.com.thomaskahessay.Grove"

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            User.self,
            Exercise.self,
            Workout.self,
            ExerciseLog.self,
            SetLog.self,
            WorkoutTemplate.self,
            WorkoutPlan.self,
            Achievement.self,
            PersonalRecord.self,
            CreatineLog.self
        ])

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("[Grove] App Group container not found for \(appGroupID)")
        }

        let supportDir = containerURL
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")

        // Ensure the directory exists
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let storeURL = supportDir.appendingPathComponent("default.store")

        let config = ModelConfiguration(
            "Grove",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [config])
    }
}
