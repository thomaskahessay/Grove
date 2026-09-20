import CloudKit

/// Idempotently creates the CKQuerySubscriptions that back Grove's social push
/// notifications (friend activity, seed received, connection milestones). Both
/// subscriptions are silent (`shouldSendContentAvailable`) — the actual notification
/// content is built locally by `NotificationService` so existing per-type toggles and
/// quiet-hours preferences still apply.
enum CloudKitSubscriptionManager {
    private static let subscriptionVersionKey = "grove_ckSubscriptionVersion"
    private static let currentVersion = 1 // bump to force recreation if predicates/keys change

    static let interactionSubscriptionID = "grove.sub.interaction.v1"
    static let sharedWorkoutSubscriptionID = "grove.sub.sharedWorkout.v1"

    /// Safe to call on every `ensureUserProfile` — cheap no-op after the first
    /// successful run (gated by a UserDefaults version flag).
    static func ensureSubscriptions(myAppleUserID: String, database: CKDatabase) async {
        let storedVersion = UserDefaults.standard.integer(forKey: subscriptionVersionKey)
        guard storedVersion != currentVersion else { return }

        let interactionSub = makeInteractionSubscription(recipientID: myAppleUserID)
        let sharedWorkoutSub = makeSharedWorkoutSubscription(excludingUserID: myAppleUserID)

        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [interactionSub, sharedWorkoutSub],
            subscriptionIDsToDelete: nil
        )

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifySubscriptionsResultBlock = { result in
                    continuation.resume(with: result)
                }
                database.add(operation)
            }
            UserDefaults.standard.set(currentVersion, forKey: subscriptionVersionKey)
        } catch {
            print("[Grove] CKSubscription setup failed: \(error)")
            // Leave the version flag unset so the next ensureUserProfile call retries.
        }
    }

    private static func makeInteractionSubscription(recipientID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "recipientID == %@", recipientID)
        let subscription = CKQuerySubscription(
            recordType: "Interaction",
            predicate: predicate,
            subscriptionID: interactionSubscriptionID,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.desiredKeys = ["type", "senderID", "recipientID", "workoutRecordName", "message", "createdAt"]
        subscription.notificationInfo = info
        return subscription
    }

    private static func makeSharedWorkoutSubscription(excludingUserID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "userID != %@", excludingUserID)
        let subscription = CKQuerySubscription(
            recordType: "SharedWorkout",
            predicate: predicate,
            subscriptionID: sharedWorkoutSubscriptionID,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.desiredKeys = ["userID", "workoutName", "duration", "completedAt"]
        subscription.notificationInfo = info
        return subscription
    }
}
