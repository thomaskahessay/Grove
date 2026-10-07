import CloudKit
import SwiftData
import UIKit

/// Handles the silent CKQueryNotification from `CloudKitSubscriptionManager`'s
/// interaction subscription by checking for crossed connection milestones.
///
/// Friend activity and seeds are *visible* pushes that APNs displays on its own, so
/// they never reach this handler and must not be re-posted locally here.
///
/// Builds its own fresh `ModelContext` from the shared `modelContainer` and fetches a
/// fresh `User` — this runs on a background task, so it must never reuse a `User` or
/// `ModelContext` instance that belongs to another context/thread.
///
/// `@MainActor` because both collaborators it talks to (`CloudKitSocialService`,
/// `NotificationService`) are MainActor-isolated — staying on the same actor throughout
/// avoids "sending non-Sendable value" errors when passing `User`/`ModelContext` around.
@MainActor
enum PushNotificationHandler {
    static func handle(
        notification: CKQueryNotification,
        modelContainer: ModelContainer,
        socialService: CloudKitSocialService
    ) async -> UIBackgroundFetchResult {
        guard notification.subscriptionID == CloudKitSubscriptionManager.interactionSubscriptionID else {
            return .noData
        }

        let context = ModelContext(modelContainer)
        guard let user = try? context.fetch(FetchDescriptor<User>()).first else {
            return .noData
        }

        await socialService.bootstrapIfNeeded(appleUserID: user.appleUserID)

        // Any interaction type (water/seed/sunlight) feeds the root-connection score,
        // so re-check for a crossed milestone threshold on every interaction.
        await socialService.checkAndNotifyMilestones(user: user, context: context)

        return .newData
    }
}
