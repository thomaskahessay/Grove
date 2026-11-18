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
/// - The self-test subscription is visible and only matches `Interaction` records of type
///   `pushTest` addressed to this user, so Notification Settings can send a real push
///   through the same CloudKit → APNs path (see `CloudKitSocialService.sendTestPush`).
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
            return "v3|\(myAppleUserID)|fa:\(friendActivityEnabled)|seed:\(seedsEnabled)|\(friendPart)"
        }
    }

    static let interactionSubscriptionID = "grove.sub.interaction.v1"
    static let selfTestSubscriptionID = "grove.sub.selftest.v1"
    /// `Interaction.type` of test records. Not an `InteractionType`, so every reader of
    /// interactions ignores it.
    static let testInteractionType = "pushTest"
    private static let friendWorkoutPrefix = "grove.sub.friendWorkout.v2."
    private static let seedPrefix = "grove.sub.seed.v2."
    private static let ownedPrefix = "grove.sub."

    private static let friendWorkoutAlertKey = "GROVE_PUSH_FRIEND_WORKOUT"
    private static let seedAlertKey = "GROVE_PUSH_SEED"
    private static let testAlertKey = "GROVE_PUSH_TEST"

    private static let verifiedSignatureKey = "grove_ckSubscriptionSignature"
    private static let verifiedAtKey = "grove_ckSubscriptionVerifiedAt"
    private static let lastErrorKey = "grove_ckSubscriptionLastError"
    private static let lastErrorAtKey = "grove_ckSubscriptionLastErrorAt"
    /// How long a successful server check is trusted before re-fetching. The server is
    /// the source of truth — a local "done" flag alone can't detect subscriptions that
    /// were never created in this CloudKit environment (e.g. dev build → TestFlight).
    private static let reverifyInterval: TimeInterval = 24 * 60 * 60

    /// Brings the server's subscriptions in line with `configuration`. Cheap no-op when
    /// nothing changed and the server was verified recently, unless `force` is set.
    static func sync(_ configuration: Configuration, database: CKDatabase, force: Bool = false) async {
        let defaults = UserDefaults.standard
        let signature = configuration.signature
        if !force,
           defaults.string(forKey: verifiedSignatureKey) == signature,
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
                var failure: String?
                for (id, result) in saveResults {
                    if case .failure(let error) = result {
                        print("[Grove] Failed to save subscription \(id): \(error)")
                        failure = failure ?? "Couldn't create an alert subscription: \(describe(error))"
                    }
                }
                for (id, result) in deleteResults {
                    if case .failure(let error) = result,
                       (error as? CKError)?.code != .unknownItem {
                        print("[Grove] Failed to delete subscription \(id): \(error)")
                        failure = failure ?? "Couldn't remove an old alert subscription: \(describe(error))"
                    }
                }
                // Leave the signature unset so the next sync retries the whole diff.
                if let failure {
                    recordError(failure)
                    return
                }
            }

            defaults.set(signature, forKey: verifiedSignatureKey)
            defaults.set(Date(), forKey: verifiedAtKey)
            recordError(nil)
        } catch {
            print("[Grove] CKSubscription sync failed: \(error)")
            recordError("Couldn't reach iCloud alert subscriptions: \(describe(error))")
        }
    }

    // MARK: - Diagnostics

    /// The most recent sync failure on this device, kept so Notification Settings can show
    /// it (TestFlight builds have no visible console). Cleared by the next successful sync.
    static var lastSyncError: (message: String, date: Date)? {
        let defaults = UserDefaults.standard
        guard let message = defaults.string(forKey: lastErrorKey),
              let date = defaults.object(forKey: lastErrorAtKey) as? Date else { return nil }
        return (message, date)
    }

    private static func recordError(_ message: String?) {
        let defaults = UserDefaults.standard
        if let message {
            defaults.set(message, forKey: lastErrorKey)
            defaults.set(Date(), forKey: lastErrorAtKey)
        } else {
            defaults.removeObject(forKey: lastErrorKey)
            defaults.removeObject(forKey: lastErrorAtKey)
        }
    }

    /// What actually exists on the server for this user, compared to `configuration`.
    struct ServerStatus: Sendable {
        /// Friends who should have a workout alert subscription (empty when the toggle is off).
        let expectedFriendIDs: Set<String>
        /// Of those, the ones whose subscription exists with the current alert payload.
        let activeFriendIDs: Set<String>
        let selfTestActive: Bool
    }

    /// Reads the server's subscriptions. Throws when CloudKit can't be reached, so callers
    /// can show the real error rather than "0 active".
    static func serverStatus(for configuration: Configuration, database: CKDatabase) async throws -> ServerStatus {
        let existing = try await database.allSubscriptions()
        let existingByID = Dictionary(existing.map { ($0.subscriptionID, $0) }, uniquingKeysWith: { first, _ in first })
        let desired = makeSubscriptions(for: configuration)

        func isActive(_ subscription: CKSubscription) -> Bool {
            guard let current = existingByID[subscription.subscriptionID] else { return false }
            return matches(current, subscription)
        }

        var expected: Set<String> = []
        var active: Set<String> = []
        var selfTestActive = false
        for subscription in desired {
            let id = subscription.subscriptionID
            if id.hasPrefix(friendWorkoutPrefix) {
                let friendID = String(id.dropFirst(friendWorkoutPrefix.count))
                expected.insert(friendID)
                if isActive(subscription) { active.insert(friendID) }
            } else if id == selfTestSubscriptionID {
                selfTestActive = isActive(subscription)
            }
        }
        return ServerStatus(expectedFriendIDs: expected, activeFriendIDs: active, selfTestActive: selfTestActive)
    }

    /// A short, human-readable CloudKit error for the settings screen.
    static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        switch ckError.code {
        case .notAuthenticated: return "not signed in to iCloud on this phone"
        case .networkUnavailable, .networkFailure: return "no network connection"
        case .permissionFailure: return "iCloud denied permission (\(ckError.localizedDescription))"
        case .quotaExceeded: return "iCloud quota exceeded"
        case .requestRateLimited, .serviceUnavailable, .zoneBusy: return "iCloud is busy, try again shortly"
        case .invalidArguments, .serverRejectedRequest:
            return "iCloud rejected the request, likely a Production schema issue (\(ckError.localizedDescription))"
        default: return "\(ckError.localizedDescription) (code \(ckError.code.rawValue))"
        }
    }

    // MARK: - Desired Subscriptions

    private static func makeSubscriptions(for configuration: Configuration) -> [CKQuerySubscription] {
        var subscriptions = [
            makeInteractionSubscription(recipientID: configuration.myAppleUserID),
            makeSelfTestSubscription(recipientID: configuration.myAppleUserID),
        ]

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

    /// Visible push for test records sent from Notification Settings. `message` carries the
    /// sender's name, so a test from a friend says who sent it.
    private static func makeSelfTestSubscription(recipientID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(
            format: "recipientID == %@ AND type == %@",
            recipientID, testInteractionType
        )
        let subscription = CKQuerySubscription(
            recordType: "Interaction",
            predicate: predicate,
            subscriptionID: selfTestSubscriptionID,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.title = "Grove test alert"
        info.alertLocalizationKey = testAlertKey
        info.alertLocalizationArgs = ["message"]
        info.soundName = "default"
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
