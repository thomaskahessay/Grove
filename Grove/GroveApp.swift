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
                PersonalRecord.self,
                CreatineLog.self
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
    @State private var socialService = CloudKitSocialService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutSessionManager)
                .environment(socialService)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if workoutSessionManager.hasActiveWorkout {
                    Task { @MainActor in
                        await NotificationService.shared.checkAuthorizationStatus()
                        NotificationService.shared.scheduleAbandonedWorkoutReminder()
                    }
                }
            case .active:
                Task { @MainActor in
                    NotificationService.shared.cancelAbandonedWorkoutReminder()
                    await socialService.fetchInteractionsForFeed()
                    await socialService.checkAvailableSunlight()
                }
            default:
                break
            }
        }
    }
}
