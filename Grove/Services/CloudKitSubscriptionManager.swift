import CloudKit

/// Reconciles the CKQuerySubscriptions that back Grove's social push notifications
/// against what actually exists on the CloudKit server.
///
/// - Friend activity and seeds are *visible* pushes: APNs shows them directly, so they
///   arrive promptly even when the app is suspended or force-quit. There is one
///   subscription per friend so the predicate only matches friends, and the friend's
///   display name is baked into the alert title (records don't carry sender names).
///   The body comes from `Localizable.strings` with record fields as format args.
/// - The interaction subscription stays *silent* (`shouldSendContentAvailable`) — it
///   only wakes the app so `PushNotificationHandler` can check connection milestones,
///   which are computed locally and can't be expressed as a server-side alert.
///
/// Visible pushes bypass the app, so quiet hours can't apply to them; the per-type
/// toggles are honored by creating/deleting the matching subscriptions.
@MainActor
enum CloudKitSubscriptionManager {
    struct Friend: Hashable {
        let id: String
        let name: String
    }

    struct Configuration: Hashable {
        let myAppleUserID: String
        let friends: [Friend]
        let friendActivityEnabled: Bool
        let seedsEnabled: Bool

        /// Stable fingerprint of everything that affects the desired subscription set.
        var signature: String {
            let friendPart = friends
                .sorted { $0.id < $1.id }
                .map { "\($0.id)=\($0.name)" }
                .joined(separator: ";")
            return "v2|\(myAppleUserID)|fa:\(friendActivityEnabled)|seed:\(seedsEnabled)|\(friendPart)"
        }
    }

    static let interactionSubscriptionID = "grove.sub.interaction.v1"
    private static let friendWorkoutPrefix = "grove.sub.friendWorkout.v2."
    private static let seedPrefix = "grove.sub.seed.v2."
    private static let ownedPrefix = "grove.sub."

    private static let friendWorkoutAlertKey = "GROVE_PUSH_FRIEND_WORKOUT"
    private static let seedAlertKey = "GROVE_PUSH_SEED"

    private static let verifiedSignatureKey = "grove_ckSubscriptionSignature"
    private static let verifiedAtKey = "grove_ckSubscriptionVerifiedAt"
    /// How long a successful server check is trusted before re-fetching. The server is
    /// the source of truth — a local "done" flag alone can't detect subscriptions that
    /// were never created in this CloudKit environment (e.g. dev build → TestFlight).
    private static let reverifyInterval: TimeInterval = 24 * 60 * 60

    /// Brings the server's subscriptions in line with `configuration`. Cheap no-op when
    /// nothing changed and the server was verified recently.
    static func sync(_ configuration: Configuration, database: CKDatabase) async {
        let defaults = UserDefaults.standard
        let signature = configuration.signature
        if defaults.string(forKey: verifiedSignatureKey) == signature,
           let verifiedAt = defaults.object(forKey: verifiedAtKey) as? Date,
           Date().timeIntervalSince(verifiedAt) < reverifyInterval {
            return
        }

        do {
            let desired = makeSubscriptions(for: configuration)
            let existing = try await database.allSubscriptions()
            let existingByID = Dictionary(existing.map { ($0.subscriptionID, $0) }, uniquingKeysWith: { first, _ in first })

            let toSave = desired.filter { subscription in
                guard let current = existingByID[subscription.subscriptionID] else { return true }
                return !matches(current, subscription)
            }
            let desiredIDs = Set(desired.map(\.subscriptionID))
            let toDelete = existing
                .map(\.subscriptionID)
                .filter { $0.hasPrefix(ownedPrefix) && !desiredIDs.contains($0) }

            if !toSave.isEmpty || !toDelete.isEmpty {
                let (saveResults, deleteResults) = try await database.modifySubscriptions(saving: toSave, deleting: toDelete)
                var failed = false
                for (id, result) in saveResults {
                    if case .failure(let error) = result {
                        print("[Grove] Failed to save subscription \(id): \(error)")
                        failed = true
                    }
                }
                for (id, result) in deleteResults {
                    if case .failure(let error) = result,
                       (error as? CKError)?.code != .unknownItem {
                        print("[Grove] Failed to delete subscription \(id): \(error)")
                        failed = true
                    }
                }
                // Leave the signature unset so the next sync retries the whole diff.
                if failed { return }
            }

            defaults.set(signature, forKey: verifiedSignatureKey)
            defaults.set(Date(), forKey: verifiedAtKey)
        } catch {
            print("[Grove] CKSubscription sync failed: \(error)")
        }
    }

    // MARK: - Desired Subscriptions

    private static func makeSubscriptions(for configuration: Configuration) -> [CKQuerySubscription] {
        var subscriptions = [makeInteractionSubscription(recipientID: configuration.myAppleUserID)]

        for friend in configuration.friends {
            if configuration.friendActivityEnabled {
                subscriptions.append(makeFriendWorkoutSubscription(friend: friend))
            }
            if configuration.seedsEnabled {
                subscriptions.append(makeSeedSubscription(friend: friend, recipientID: configuration.myAppleUserID))
            }
        }
        return subscriptions
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

    private static func makeFriendWorkoutSubscription(friend: Friend) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "userID == %@", friend.id)
        let subscription = CKQuerySubscription(
            recordType: "SharedWorkout",
            predicate: predicate,
            subscriptionID: friendWorkoutPrefix + friend.id,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.title = friend.name
        info.alertLocalizationKey = friendWorkoutAlertKey
        info.alertLocalizationArgs = ["workoutName"]
        info.soundName = "default"
        subscription.notificationInfo = info
        return subscription
    }

    private static func makeSeedSubscription(friend: Friend, recipientID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(
            format: "recipientID == %@ AND senderID == %@ AND type == %@",
            recipientID, friend.id, InteractionType.seed.rawValue
        )
        let subscription = CKQuerySubscription(
            recordType: "Interaction",
            predicate: predicate,
            subscriptionID: seedPrefix + friend.id,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.title = friend.name
        info.alertLocalizationKey = seedAlertKey
        info.alertLocalizationArgs = ["message"]
        info.soundName = "default"
        subscription.notificationInfo = info
        return subscription
    }

    /// Whether a server subscription already matches the desired one. Subscription IDs
    /// encode the record type and friend, so comparing the alert payload is enough to
    /// catch renamed friends and silent → visible migrations.
    private static func matches(_ current: CKSubscription, _ desired: CKSubscription) -> Bool {
        let a = current.notificationInfo
        let b = desired.notificationInfo
        return a?.title == b?.title
            && a?.alertLocalizationKey == b?.alertLocalizationKey
            && a?.alertLocalizationArgs == b?.alertLocalizationArgs
            && a?.soundName == b?.soundName
            && a?.shouldSendContentAvailable == b?.shouldSendContentAvailable
    }
}
