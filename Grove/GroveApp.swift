import SwiftUI
import SwiftData

@main
struct GroveApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                User.self,
                Exercise.self,
                Workout.self,
                ExerciseLog.self,
                SetLog.self,
                WorkoutTemplate.self,
                WorkoutPlan.self,
                Achievement.self,
                PersonalRecord.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Seed built-in exercises on first launch
            let context = ModelContext(modelContainer)
            ExerciseSeeds.seedExercises(context: context)

            // Migrate existing templates to 3 default sets
            let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
            for template in templates where template.defaultSets != 3 {
                template.defaultSets = 3
            }
            try? context.save()

            // Fix existing PR reps (one-time migration for records with wrong rep counts)
            PRDetectionService.fixExistingPRReps(context: context)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    @State private var workoutSessionManager = WorkoutSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutSessionManager)
        }
        .modelContainer(modelContainer)
    }
}
