import SwiftUI
import SwiftData
import UIKit
import BackgroundTasks
import WidgetKit
import CloudKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    // Set by GroveApp.init() immediately after these are constructed. AppDelegate is
    // instantiated by UIKit before GroveApp.init() runs, so these can't be passed in
    // as constructor params — this static handoff is the simplest safe alternative.
    static var modelContainer: ModelContainer?
    static var socialService: CloudKitSocialService?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // No-op: CKQuerySubscription push delivery doesn't require us to hand the
        // device token to CloudKit ourselves; this callback just needs to exist.
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Grove] Remote notification registration failed: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
              let container = Self.modelContainer,
              let socialService = Self.socialService else {
            completionHandler(.noData)
            return
        }
        Task {
            let result = await PushNotificationHandler.handle(
                notification: notification,
                modelContainer: container,
                socialService: socialService
            )
            completionHandler(result)
        }
    }
}

@main
struct GroveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let modelContainer: ModelContainer
    let socialService = CloudKitSocialService()

    init() {
        AppDelegate.socialService = socialService

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
            AppDelegate.modelContainer = modelContainer
            return // Skip migrations on fresh in-memory store
        }

        AppDelegate.modelContainer = modelContainer

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
    @State private var pendingTemplate: SharedTemplate?
    @Environment(\.scenePhase) private var scenePhase

    nonisolated private static let feedCheckTaskID = "com.grove.feedCheck"

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
        // Retired: friend-activity notifications are now visible CloudKit pushes.
        // Kept registered as a no-op so refresh requests already queued by older
        // builds still find a handler. Nothing submits new requests anymore.
        .backgroundTask(.appRefresh(Self.feedCheckTaskID)) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.feedCheckTaskID)
        }
    }
}
