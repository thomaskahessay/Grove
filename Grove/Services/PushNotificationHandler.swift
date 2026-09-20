import CloudKit
import SwiftData
import UIKit

/// Dispatches an incoming CKQueryNotification (from `CloudKitSubscriptionManager`'s
/// subscriptions) to the right handler and turns it into a local notification via
/// `NotificationService`, which already respects each `notifyX` toggle and quiet hours.
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
        let context = ModelContext(modelContainer)
        guard let user = try? context.fetch(FetchDescriptor<User>()).first else {
            return .noData
        }

        await socialService.bootstrapIfNeeded(appleUserID: user.appleUserID)

        switch notification.subscriptionID {
        case CloudKitSubscriptionManager.interactionSubscriptionID:
            return await handleInteractionPush(notification, user: user, context: context, socialService: socialService)
        case CloudKitSubscriptionManager.sharedWorkoutSubscriptionID:
            return await handleSharedWorkoutPush(notification, user: user, context: context, socialService: socialService)
        default:
            return .noData
        }
    }

    // MARK: - Interaction (seed / connection-milestone trigger)

    private static func handleInteractionPush(
        _ notification: CKQueryNotification,
        user: User,
        context: ModelContext,
        socialService: CloudKitSocialService
    ) async -> UIBackgroundFetchResult {
        guard let recordID = notification.recordID else { return .noData }

        var type = notification.recordFields?["type"] as? String
        var senderID = notification.recordFields?["senderID"] as? String
        var message = notification.recordFields?["message"] as? String

        if type == nil || senderID == nil {
            guard let record = await socialService.fetchRecord(recordID) else { return .failed }
            type = record["type"] as? String
            senderID = record["senderID"] as? String
            message = record["message"] as? String
        }

        if type == "seed", let senderID, let message {
            let friends = socialService.friends
            let senderName = friends.first { $0.id == senderID }?.displayName ?? "A friend"
            await NotificationService.shared.checkAuthorizationStatus()
            NotificationService.shared.scheduleSeedReceivedNotification(
                senderName: senderName, message: message, recordName: recordID.recordName, user: user
            )
        }

        // Any interaction type (water/seed/sunlight) feeds the root-connection score,
        // so always re-check for a crossed milestone threshold, not just for seeds.
        await socialService.checkAndNotifyMilestones(user: user, context: context)

        return .newData
    }

    // MARK: - SharedWorkout (friend-activity trigger)

    private static func handleSharedWorkoutPush(
        _ notification: CKQueryNotification,
        user: User,
        context: ModelContext,
        socialService: CloudKitSocialService
    ) async -> UIBackgroundFetchResult {
        guard let recordID = notification.recordID,
              let record = await socialService.fetchRecord(recordID) else { return .failed }

        let userID = record["userID"] as? String ?? ""
        let friends = socialService.friends
        guard let matchedFriend = friends.first(where: { $0.id == userID }) else {
            // Not a friend — predicate can't filter this server-side, discard client-side.
            return .noData
        }

        let friendName = matchedFriend.displayName
        let workoutName = record["workoutName"] as? String ?? "Workout"
        let duration = record["duration"] as? TimeInterval ?? 0
        let completedAt = record["completedAt"] as? Date ?? Date()

        await NotificationService.shared.checkAuthorizationStatus()
        NotificationService.shared.scheduleFriendActivityNotification(
            friendName: friendName, workoutName: workoutName, duration: duration,
            workoutID: recordID.recordName, user: user
        )

        // Advance the same bookkeeping handleFeedCheck()'s BGAppRefreshTask backstop
        // relies on, so its next "since" poll excludes a workout this push already
        // delivered — without this, the two paths could both notify for the same event.
        if user.lastFeedCheckDate == nil || completedAt > user.lastFeedCheckDate! {
            user.lastFeedCheckDate = completedAt
            try? context.save()
        }

        return .newData
    }
}
