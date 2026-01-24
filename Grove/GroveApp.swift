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
                Achievement.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Seed built-in exercises on first launch
            let context = ModelContext(modelContainer)
            ExerciseSeeds.seedExercises(context: context)
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
