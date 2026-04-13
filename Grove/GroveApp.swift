import SwiftUI
import SwiftData
import UIKit
import BackgroundTasks
import WidgetKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct GroveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let modelContainer: ModelContainer

    init() {
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

        do {
            let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("[Grove] ERROR: Persistent store failed: \(error). Using in-memory fallback.")
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                modelContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("[Grove] FATAL: Could not initialize any ModelContainer: \(error)")
            }
            return // Skip migrations on fresh in-memory store
        }

        // Seed built-in exercises on first launch
        let context = ModelContext(modelContainer)
        ExerciseSeeds.seedExercises(context: context)

        // Migrate existing templates to 3 default sets
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        for template in templates where template.defaultSets != 3 {
            template.defaultSets = 3
        }
        do {
            try context.save()
        } catch {
            print("[Grove] ERROR: Failed to save template migration: \(error)")
        }

        // Fix existing PR reps (one-time migration for records with wrong rep counts)
        PRDetectionService.fixExistingPRReps(context: context)
    }

    @State private var workoutSessionManager = WorkoutSessionManager()
    @State private var socialService = CloudKitSocialService()
    @State private var pendingTemplate: SharedTemplate?
    @Environment(\.scenePhase) private var scenePhase

    private static let feedCheckTaskID = "com.grove.feedCheck"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutSessionManager)
                .environment(socialService)
                .onOpenURL { url in
                    if let template = SharedTemplate.from(url: url) {
                        pendingTemplate = template
                    }
                }
                .sheet(item: $pendingTemplate) { template in
                    TemplateImportSheet(sharedTemplate: template)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                WidgetCenter.shared.reloadAllTimelines()
                if workoutSessionManager.hasActiveWorkout {
                    Task { @MainActor in
                        await NotificationService.shared.checkAuthorizationStatus()
                        NotificationService.shared.scheduleAbandonedWorkoutReminder()
                    }
                }
                scheduleFeedCheckTask()
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
        .backgroundTask(.appRefresh(Self.feedCheckTaskID)) {
            await handleFeedCheck()
        }
    }

    private func scheduleFeedCheckTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.feedCheckTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    @Sendable
    private func handleFeedCheck() async {
        let context = ModelContext(modelContainer)
        guard let user = try? context.fetch(FetchDescriptor<User>()).first,
              user.notifyFriendActivity else { return }

        let lastCheck = user.lastFeedCheckDate ?? Date(timeIntervalSinceNow: -3600)

        // Ensure friends list is loaded before querying
        await socialService.bootstrapIfNeeded(appleUserID: user.appleUserID)

        let newWorkouts = await socialService.checkForNewFriendWorkouts(since: lastCheck, user: user)

        if !newWorkouts.isEmpty {
            await NotificationService.shared.checkAuthorizationStatus()
            let items = Array(newWorkouts.prefix(3))
            await MainActor.run {
                for item in items {
                    NotificationService.shared.scheduleFriendActivityNotification(
                        friendName: item.friendName,
                        workoutName: item.workoutName,
                        duration: item.duration,
                        workoutID: item.id,
                        user: user
                    )
                }
            }
        }

        user.lastFeedCheckDate = Date()
        do {
            try context.save()
        } catch {
            print("[Grove] ERROR: Failed to save feed check date: \(error)")
        }

        // Reschedule for next check
        scheduleFeedCheckTask()
    }
}
