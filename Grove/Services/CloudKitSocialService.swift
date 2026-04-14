import Foundation
import CloudKit
import SwiftUI

// MARK: - Value Types

struct CKFriendProfile: Identifiable, Sendable {
    let id: String // appleUserID
    let displayName: String
    let profileImageData: Data?
    let inviteCode: String?
    let workoutCount: Int
    let currentStreak: Int
    let memberSince: Date
    let recordID: CKRecord.ID

    // Program info (nil when friend hasn't shared)
    let splitName: String?
    let daysPerWeek: Int?
    let repRange: String?
    let sessionMinutes: Int?

    var hasProgram: Bool { splitName != nil }

    var initials: String {
        if displayName.isEmpty { return "G" }
        let parts = displayName.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct SharedExercise: Sendable {
    let name: String
    let setCount: Int
    let summary: String? // e.g. "3×10 @ 135 lbs" when weights are shared
    let isPR: Bool
}

struct SharedWorkoutItem: Identifiable, Sendable, Hashable {
    static func == (lhs: SharedWorkoutItem, rhs: SharedWorkoutItem) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String // CKRecord name
    let userID: String
    let friendName: String
    let friendProfileImageData: Data?
    let workoutName: String
    let templateCategory: String?  // TemplateCategory.rawValue, e.g. "Push", "Pull", "Legs"
    let duration: TimeInterval
    let exerciseCount: Int
    let totalSets: Int
    let completedAt: Date
    let exercisesJSON: String?
    let prCount: Int
    let prExerciseNames: [String]

    var hasPRs: Bool { prCount > 0 }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(completedAt)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    var durationText: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var parsedExercises: [SharedExercise] {
        guard let json = exercisesJSON,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return array.map { entry in
            let name = entry["name"] as? String ?? "Exercise"
            var setCount = entry["setCount"] as? Int ?? 0
            var summary: String?

            if let sets = entry["sets"] as? [[String: Any]] {
                setCount = sets.count
                summary = buildSetSummary(sets)
            }

            let isPR = entry["isPR"] as? Bool ?? false
            return SharedExercise(name: name, setCount: setCount, summary: summary, isPR: isPR)
        }
    }

    private func buildSetSummary(_ sets: [[String: Any]]) -> String? {
        guard !sets.isEmpty else { return nil }

        let weights = sets.compactMap { $0["weight"] as? Double }
        let reps = sets.compactMap { $0["reps"] as? Int }

        guard weights.count == sets.count, reps.count == sets.count else { return nil }

        let allSameWeight = Set(weights).count == 1
        let allSameReps = Set(reps).count == 1

        if allSameWeight && allSameReps {
            let w = weights[0] == floor(weights[0]) ? "\(Int(weights[0]))" : String(format: "%.1f", weights[0])
            return "\(sets.count)×\(reps[0]) @ \(w) lbs"
        } else if allSameWeight {
            let w = weights[0] == floor(weights[0]) ? "\(Int(weights[0]))" : String(format: "%.1f", weights[0])
            return "\(w) lbs · \(reps.map(String.init).joined(separator: ","))"
        } else {
            guard let minW = weights.min(), let maxW = weights.max() else { return nil }
            return "\(sets.count) sets · \(Int(minW))-\(Int(maxW)) lbs"
        }
    }
}

struct FriendProfileData: Sendable {
    let profile: CKFriendProfile
    let recentWorkouts: [SharedWorkoutItem]
    let interactionBreakdown: InteractionBreakdown?
    let recentPRExerciseNames: [String]  // unique exercise names with PRs from recent workouts
    let commonExerciseCount: Int         // exercises in common with viewer
}

// MARK: - CloudKit Social Service

@MainActor
@Observable
class CloudKitSocialService {
    // State
    var friends: [CKFriendProfile] = []
    var friendsLoaded: Bool = false
    var feedItems: [SharedWorkoutItem] = []
    var mySharedWorkouts: [SharedWorkoutItem] = []
    var myInviteCode: String? = UserDefaults.standard.string(forKey: "grove_myInviteCode") {
        didSet { UserDefaults.standard.set(myInviteCode, forKey: "grove_myInviteCode") }
    }
    var isLoading: Bool = false
    var error: String?

    // Interaction state
    var interactionsByWorkout: [String: InteractionSummary] = [:]
    var rootConnections: [RootConnection] = []
    var availableSunlightCount: Int = 0
    private var usedSunlightSources: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "grove_usedSunlightSources") ?? []) {
        didSet { UserDefaults.standard.set(Array(usedSunlightSources), forKey: "grove_usedSunlightSources") }
    }

    // Track previous root levels for milestone detection
    private var previousRootLevels: [String: RootLevel] = [:]

    /// The current user's Apple User ID (for checking if a post is your own)
    var currentUserID: String? { myAppleUserID }

    // Private
    private let container = CKContainer(identifier: "iCloud.icloud.thomaskahessay.Grove")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private var myUserRecordID: CKRecord.ID?
    private var myAppleUserID: String?

    // Record type constants
    private enum RecordType {
        static let userProfile = "UserProfile"
        static let friendLink = "FriendLink"
        static let sharedWorkout = "SharedWorkout"
        static let interaction = "Interaction"
    }

    // MARK: - iCloud Availability

    var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Bootstrap (for background tasks)

    func bootstrapIfNeeded(appleUserID: String) async {
        if myAppleUserID == nil {
            myAppleUserID = appleUserID
            myUserRecordID = CKRecord.ID(recordName: appleUserID)
        }
        if friends.isEmpty {
            await fetchFriends()
        }
    }

    // MARK: - User Profile

    func ensureUserProfile(user: User) async {
        let appleUserID = user.appleUserID
        self.myAppleUserID = appleUserID

        do {
            let recordID = CKRecord.ID(recordName: appleUserID)
            self.myUserRecordID = recordID

            // Try to fetch existing profile
            if let existing = try? await publicDB.record(for: recordID) {
                // Read invite code immediately — before save which can fail
                if let code = existing["inviteCode"] as? String, !code.isEmpty {
                    self.myInviteCode = code
                    user.inviteCode = code
                }

                // Update mutable fields
                existing["displayName"] = (user.displayName ?? "Athlete") as CKRecordValue
                existing["workoutCount"] = Int64(user.workouts.count) as CKRecordValue
                existing["currentStreak"] = Int64(user.currentStreak) as CKRecordValue

                if let imageData = user.profileImageData {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(appleUserID)_profile.jpg")
                    try? imageData.write(to: tempURL)
                    existing["profileImage"] = CKAsset(fileURL: tempURL)
                }

                Self.writeProgramFields(to: existing, user: user)

                try await publicDB.save(existing)
            } else {
                // Create new profile — include all fields so schema gets created
                let record = CKRecord(recordType: RecordType.userProfile, recordID: recordID)
                record["appleUserID"] = appleUserID as CKRecordValue
                record["displayName"] = (user.displayName ?? "Athlete") as CKRecordValue
                record["workoutCount"] = Int64(user.workouts.count) as CKRecordValue
                record["currentStreak"] = Int64(user.currentStreak) as CKRecordValue
                record["memberSince"] = user.createdAt as CKRecordValue
                record["inviteCode"] = "" as CKRecordValue  // Placeholder so field exists in schema

                if let imageData = user.profileImageData {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(appleUserID)_profile.jpg")
                    try? imageData.write(to: tempURL)
                    record["profileImage"] = CKAsset(fileURL: tempURL)
                }

                Self.writeProgramFields(to: record, user: user)

                try await publicDB.save(record)
            }
        } catch {
            self.error = "Could not sync profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Invite Code

    func generateInviteCode(user: User? = nil) async {
        // Ensure profile exists first if not yet set up
        if myAppleUserID == nil || myUserRecordID == nil, let user {
            await ensureUserProfile(user: user)
        }

        guard let myAppleUserID, let myUserRecordID else {
            self.error = "Not signed in to iCloud"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var code: String
            var attempts = 0

            // Generate unique code with collision check (skip if schema not ready)
            repeat {
                code = InviteCodeGenerator.generate()
                do {
                    let pred = NSPredicate(format: "inviteCode == %@", code)
                    let query = CKQuery(recordType: RecordType.userProfile, predicate: pred)
                    let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
                    if results.isEmpty { break }
                } catch {
                    // Field doesn't exist yet in schema — no collision possible
                    break
                }
                attempts += 1
            } while attempts < 3

            // Save to user profile — fetch existing or create new
            let record: CKRecord
            if let existing = try? await publicDB.record(for: myUserRecordID) {
                record = existing
            } else {
                record = CKRecord(recordType: RecordType.userProfile, recordID: myUserRecordID)
                record["appleUserID"] = myAppleUserID as CKRecordValue
                record["displayName"] = "Athlete" as CKRecordValue
                record["memberSince"] = Date() as CKRecordValue
                record["workoutCount"] = Int64(0) as CKRecordValue
                record["currentStreak"] = Int64(0) as CKRecordValue
            }
            record["inviteCode"] = code as CKRecordValue
            try await publicDB.save(record)

            self.myInviteCode = code
            self.error = nil
        } catch {
            self.error = "Could not generate invite code: \(error.localizedDescription)"
        }
    }

    // MARK: - Friend Lookup & Management

    func lookupInviteCode(_ code: String) async -> CKFriendProfile? {
        let normalized = InviteCodeGenerator.normalize(code)

        do {
            let pred = NSPredicate(format: "inviteCode == %@", normalized)
            let query = CKQuery(recordType: RecordType.userProfile, predicate: pred)
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            guard let (_, result) = results.first,
                  let record = try? result.get() else { return nil }

            // Don't let users add themselves
            let foundUserID = record["appleUserID"] as? String ?? ""
            if foundUserID == myAppleUserID { return nil }

            return profileFromRecord(record)
        } catch {
            self.error = "Lookup failed: \(error.localizedDescription)"
            return nil
        }
    }

    func addFriend(theirUserID: String) async -> Bool {
        guard let myAppleUserID else { return false }

        // Canonical ordering to prevent duplicates
        let id1 = min(myAppleUserID, theirUserID)
        let id2 = max(myAppleUserID, theirUserID)

        do {
            // Check if already friends
            let pred = NSPredicate(format: "userID1 == %@ AND userID2 == %@", id1, id2)
            let query = CKQuery(recordType: RecordType.friendLink, predicate: pred)
            let (existing, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            if !existing.isEmpty { return true } // Already friends

            // Create link
            let record = CKRecord(recordType: RecordType.friendLink)
            record["userID1"] = id1 as CKRecordValue
            record["userID2"] = id2 as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            try await publicDB.save(record)

            // Refresh friends list
            await fetchFriends()
            return true
        } catch {
            self.error = "Could not add friend: \(error.localizedDescription)"
            return false
        }
    }

    func removeFriend(theirUserID: String) async -> Bool {
        guard let myAppleUserID else { return false }

        let id1 = min(myAppleUserID, theirUserID)
        let id2 = max(myAppleUserID, theirUserID)

        do {
            let pred = NSPredicate(format: "userID1 == %@ AND userID2 == %@", id1, id2)
            let query = CKQuery(recordType: RecordType.friendLink, predicate: pred)
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            if let (recordID, _) = results.first {
                try await publicDB.deleteRecord(withID: recordID)
            }

            // Remove from local state
            friends.removeAll { $0.id == theirUserID }
            feedItems.removeAll { $0.userID == theirUserID }
            return true
        } catch {
            self.error = "Could not remove friend: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Fetch Friends

    func fetchFriends() async {
        guard let myAppleUserID else { return }

        // Query both sides of friend links
        let pred1 = NSPredicate(format: "userID1 == %@", myAppleUserID)
        let pred2 = NSPredicate(format: "userID2 == %@", myAppleUserID)

        let query1 = CKQuery(recordType: RecordType.friendLink, predicate: pred1)
        let query2 = CKQuery(recordType: RecordType.friendLink, predicate: pred2)

        // These may fail if FriendLink record type doesn't exist yet — that's fine
        let results1 = (try? await publicDB.records(matching: query1))?.0 ?? []
        let results2 = (try? await publicDB.records(matching: query2))?.0 ?? []

        // Extract friend user IDs
        var friendIDs: Set<String> = []
        for (_, result) in results1 {
            if let record = try? result.get(),
               let id = record["userID2"] as? String {
                friendIDs.insert(id)
            }
        }
        for (_, result) in results2 {
            if let record = try? result.get(),
               let id = record["userID1"] as? String {
                friendIDs.insert(id)
            }
        }

        // Batch fetch friend profiles
        var profiles: [CKFriendProfile] = []
        for friendID in friendIDs {
            let recordID = CKRecord.ID(recordName: friendID)
            if let record = try? await publicDB.record(for: recordID) {
                profiles.append(profileFromRecord(record))
            }
        }

        self.friends = profiles.sorted { $0.displayName < $1.displayName }
        self.friendsLoaded = true
        self.error = nil
    }

    // MARK: - Social Feed

    func fetchFeed() async {
        guard let myAppleUserID else {
            feedItems = []
            return
        }

        // Allow feed to load even with no friends (user can still see own posts)
        isLoading = true
        defer { isLoading = false }

        // Include both friends and the current user in the feed query
        var allIDs = friends.map { $0.id }
        allIDs.append(myAppleUserID)

        let pred = NSPredicate(format: "userID IN %@", allIDs)
        let query = CKQuery(recordType: RecordType.sharedWorkout, predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

        // May fail if SharedWorkout record type doesn't exist yet — that's fine
        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 50) else {
            feedItems = []
            return
        }

        // Build a lookup for friend info
        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        var items: [SharedWorkoutItem] = []
        for (_, result) in results {
            if let record = try? result.get() {
                let userID = record["userID"] as? String ?? ""
                let isOwnPost = userID == myAppleUserID
                let friend = friendLookup[userID]

                items.append(SharedWorkoutItem(
                    id: record.recordID.recordName,
                    userID: userID,
                    friendName: isOwnPost ? "You" : (friend?.displayName ?? "Friend"),
                    friendProfileImageData: isOwnPost ? nil : friend?.profileImageData,
                    workoutName: record["workoutName"] as? String ?? "Workout",
                    templateCategory: record["templateCategory"] as? String,
                    duration: record["duration"] as? TimeInterval ?? 0,
                    exerciseCount: Int(record["exerciseCount"] as? Int64 ?? 0),
                    totalSets: Int(record["totalSets"] as? Int64 ?? 0),
                    completedAt: record["completedAt"] as? Date ?? Date(),
                    exercisesJSON: record["exercisesJSON"] as? String,
                    prCount: Int(record["prCount"] as? Int64 ?? 0),
                    prExerciseNames: Self.parsePRExerciseNames(record["prExerciseNamesJSON"] as? String)
                ))
            }
        }

        self.feedItems = items
        self.error = nil

        // Batch fetch interactions for the loaded feed
        await fetchInteractionsForFeed()
    }

    /// Fetch the current user's own shared workouts (for Profile view)
    func fetchMySharedWorkouts() async {
        guard let myAppleUserID else { return }

        let pred = NSPredicate(format: "userID == %@", myAppleUserID)
        let query = CKQuery(recordType: RecordType.sharedWorkout, predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 20) else {
            mySharedWorkouts = []
            return
        }

        var items: [SharedWorkoutItem] = []
        for (_, result) in results {
            if let record = try? result.get() {
                items.append(SharedWorkoutItem(
                    id: record.recordID.recordName,
                    userID: myAppleUserID,
                    friendName: "You",
                    friendProfileImageData: nil,
                    workoutName: record["workoutName"] as? String ?? "Workout",
                    templateCategory: record["templateCategory"] as? String,
                    duration: record["duration"] as? TimeInterval ?? 0,
                    exerciseCount: Int(record["exerciseCount"] as? Int64 ?? 0),
                    totalSets: Int(record["totalSets"] as? Int64 ?? 0),
                    completedAt: record["completedAt"] as? Date ?? Date(),
                    exercisesJSON: record["exercisesJSON"] as? String,
                    prCount: Int(record["prCount"] as? Int64 ?? 0),
                    prExerciseNames: Self.parsePRExerciseNames(record["prExerciseNamesJSON"] as? String)
                ))
            }
        }

        mySharedWorkouts = items

        // Fetch interactions for these workouts too
        let workoutIDs = items.map { $0.id }
        guard !workoutIDs.isEmpty else { return }

        let interPred = NSPredicate(format: "workoutRecordName IN %@", workoutIDs)
        let interQuery = CKQuery(recordType: RecordType.interaction, predicate: interPred)
        guard let (interResults, _) = try? await publicDB.records(matching: interQuery, resultsLimit: 200) else { return }

        // Build fresh summaries to avoid duplicating counts on repeated calls
        var freshSummaries: [String: InteractionSummary] = [:]
        for id in workoutIDs {
            freshSummaries[id] = .empty(for: id)
        }

        for (_, interResult) in interResults {
            guard let record = try? interResult.get() else { continue }
            let workoutRecordName = record["workoutRecordName"] as? String ?? ""
            let type = record["type"] as? String ?? ""
            let senderID = record["senderID"] as? String ?? ""
            let senderName = record["senderName"] as? String ?? ""
            let senderImage = record["senderProfileImage"] as? Data
            let createdAt = record["createdAt"] as? Date

            guard var summary = freshSummaries[workoutRecordName] else { continue }

            switch type {
            case "water":
                summary.waterCount += 1
                summary.waterers.append(InteractorInfo(userID: senderID, displayName: senderName, profileImageData: senderImage))
                if senderID == myAppleUserID { summary.iWatered = true }
                if let createdAt, createdAt > (summary.latestWaterDate ?? .distantPast) {
                    summary.latestWaterDate = createdAt
                }
            case "sunlight":
                summary.sunlightCount += 1
                summary.sunlighters.append(SunlightInfo(senderID: senderID, senderName: senderName, senderProfileImageData: senderImage, earnedFromWorkoutName: nil))
                if senderID == myAppleUserID { summary.iSunlit = true }
                if let createdAt, createdAt > (summary.latestSunlightDate ?? .distantPast) {
                    summary.latestSunlightDate = createdAt
                }
            case "seed":
                let message = record["message"] as? String ?? ""
                let isCustom = (record["isCustomMessage"] as? Int64 ?? 0) == 1
                summary.seeds.append(SeedMessage(
                    id: record.recordID.recordName,
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    message: message,
                    isCustom: isCustom,
                    createdAt: createdAt ?? Date()
                ))
            default: break
            }

            freshSummaries[workoutRecordName] = summary
        }

        // Replace (not merge) entries for these workouts
        for (key, summary) in freshSummaries {
            interactionsByWorkout[key] = summary
        }
    }

    // MARK: - Share Workout

    func shareWorkout(_ workout: Workout, user: User, prExerciseNames: Set<String> = []) async {
        guard let myAppleUserID else { return }

        do {
            let record = CKRecord(recordType: RecordType.sharedWorkout)
            record["userID"] = myAppleUserID as CKRecordValue
            record["workoutName"] = (workout.shareWorkoutName ? workout.name : "Workout") as CKRecordValue
            record["duration"] = (workout.shareDuration ? workout.duration : 0) as CKRecordValue
            record["exerciseCount"] = Int64(workout.shareExercises ? workout.completedExerciseCount : 0) as CKRecordValue
            record["totalSets"] = Int64(workout.exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }) as CKRecordValue
            record["completedAt"] = (workout.completedAt ?? Date()) as CKRecordValue
            record["shareExercises"] = Int64(workout.shareExercises ? 1 : 0) as CKRecordValue
            record["shareWeights"] = Int64(workout.shareWeights ? 1 : 0) as CKRecordValue
            if let category = workout.templateUsed?.category.rawValue {
                record["templateCategory"] = category as CKRecordValue
            }

            // PR data
            let sharePRs = workout.sharePRs && !prExerciseNames.isEmpty
            record["prCount"] = Int64(sharePRs ? prExerciseNames.count : 0) as CKRecordValue
            if sharePRs {
                let namesArray = Array(prExerciseNames)
                if let jsonData = try? JSONSerialization.data(withJSONObject: namesArray),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    record["prExerciseNamesJSON"] = jsonString as CKRecordValue
                }
            }

            // Build exercises JSON if sharing exercises
            if workout.shareExercises {
                let exerciseData = workout.exercises
                    .filter { $0.status == .completed }
                    .map { log -> [String: Any] in
                        var entry: [String: Any] = ["name": log.exercise?.name ?? "Exercise"]
                        if workout.shareWeights {
                            entry["sets"] = log.sets.map { ["weight": $0.weight as Any, "reps": $0.reps as Any] }
                        } else {
                            entry["setCount"] = log.sets.count
                        }
                        if sharePRs {
                            entry["isPR"] = prExerciseNames.contains(log.exercise?.name ?? "")
                        }
                        return entry
                    }
                if let jsonData = try? JSONSerialization.data(withJSONObject: exerciseData),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    record["exercisesJSON"] = jsonString as CKRecordValue
                }
            }

            try await publicDB.save(record)
        } catch {
            self.error = "Could not share workout: \(error.localizedDescription)"
        }
    }

    // MARK: - Update Stats

    func updateMyStats(user: User) async {
        guard let myUserRecordID else { return }

        do {
            let record = try await publicDB.record(for: myUserRecordID)
            record["workoutCount"] = Int64(user.workouts.filter { $0.completedAt != nil }.count) as CKRecordValue
            record["currentStreak"] = Int64(user.currentStreak) as CKRecordValue
            record["displayName"] = (user.displayName ?? "Athlete") as CKRecordValue
            try await publicDB.save(record)
        } catch {
            // Non-critical — stats will sync on next profile ensure
        }
    }

    // MARK: - Friend Profile

    func fetchFriendProfile(userID: String) async -> FriendProfileData? {
        do {
            // Fetch profile
            let recordID = CKRecord.ID(recordName: userID)
            let profileRecord = try await publicDB.record(for: recordID)
            let profile = profileFromRecord(profileRecord)

            // Fetch their shared workouts
            let pred = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: RecordType.sharedWorkout, predicate: pred)
            query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 20)

            var workouts: [SharedWorkoutItem] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    workouts.append(SharedWorkoutItem(
                        id: record.recordID.recordName,
                        userID: userID,
                        friendName: profile.displayName,
                        friendProfileImageData: profile.profileImageData,
                        workoutName: record["workoutName"] as? String ?? "Workout",
                        templateCategory: record["templateCategory"] as? String,
                        duration: record["duration"] as? TimeInterval ?? 0,
                        exerciseCount: Int(record["exerciseCount"] as? Int64 ?? 0),
                        totalSets: Int(record["totalSets"] as? Int64 ?? 0),
                        completedAt: record["completedAt"] as? Date ?? Date(),
                        exercisesJSON: record["exercisesJSON"] as? String,
                        prCount: Int(record["prCount"] as? Int64 ?? 0),
                        prExerciseNames: Self.parsePRExerciseNames(record["prExerciseNamesJSON"] as? String)
                    ))
                }
            }

            // Fetch interaction breakdown with this friend
            let breakdown = await fetchInteractionBreakdown(with: userID)

            // Collect unique PR exercise names from their recent workouts
            var prNames: [String] = []
            var seenPR: Set<String> = []
            for workout in workouts {
                for name in workout.prExerciseNames where seenPR.insert(name).inserted {
                    prNames.append(name)
                }
            }

            // Ensure viewer's shared workouts are loaded for common exercise comparison
            if mySharedWorkouts.isEmpty {
                await fetchMySharedWorkouts()
            }

            // Compute common exercises between viewer's and friend's shared workouts
            let friendExerciseNames = Self.extractExerciseNames(from: workouts)
            let myExerciseNames = Self.extractExerciseNames(from: mySharedWorkouts)
            let commonCount = friendExerciseNames.intersection(myExerciseNames).count

            return FriendProfileData(
                profile: profile,
                recentWorkouts: workouts,
                interactionBreakdown: breakdown,
                recentPRExerciseNames: prNames,
                commonExerciseCount: commonCount
            )
        } catch {
            self.error = "Could not load profile: \(error.localizedDescription)"
            return nil
        }
    }

    private static func extractExerciseNames(from workouts: [SharedWorkoutItem]) -> Set<String> {
        var names: Set<String> = []
        for workout in workouts {
            for exercise in workout.parsedExercises {
                names.insert(exercise.name)
            }
        }
        return names
    }

    // MARK: - Interactions

    /// Batch fetch all interactions for currently visible feed items
    func fetchInteractionsForFeed() async {
        guard let myAppleUserID else { return }
        let workoutIDs = feedItems.map { $0.id }
        guard !workoutIDs.isEmpty else { return }

        let pred = NSPredicate(format: "workoutRecordName IN %@", workoutIDs)
        let query = CKQuery(recordType: RecordType.interaction, predicate: pred)

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 500) else { return }

        // Build friend lookup for names/images
        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        // Group interactions by workout
        var grouped: [String: InteractionSummary] = [:]
        for workoutID in workoutIDs {
            grouped[workoutID] = .empty(for: workoutID)
        }

        for (_, result) in results {
            guard let record = try? result.get() else { continue }
            let workoutID = record["workoutRecordName"] as? String ?? ""
            let typeStr = record["type"] as? String ?? ""
            let senderID = record["senderID"] as? String ?? ""
            let createdAt = record["createdAt"] as? Date ?? Date()

            guard var summary = grouped[workoutID] else { continue }

            let senderName = senderID == myAppleUserID ? "You" : (friendLookup[senderID]?.displayName ?? "Friend")
            let senderImage = friendLookup[senderID]?.profileImageData

            switch typeStr {
            case "water":
                summary.waterCount += 1
                summary.waterers.append(InteractorInfo(userID: senderID, displayName: senderName, profileImageData: senderImage))
                if senderID == myAppleUserID { summary.iWatered = true }
                if createdAt > (summary.latestWaterDate ?? .distantPast) {
                    summary.latestWaterDate = createdAt
                }

            case "sunlight":
                summary.sunlightCount += 1
                summary.sunlighters.append(SunlightInfo(
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    earnedFromWorkoutName: nil
                ))
                if senderID == myAppleUserID { summary.iSunlit = true }
                if createdAt > (summary.latestSunlightDate ?? .distantPast) {
                    summary.latestSunlightDate = createdAt
                }

            case "seed":
                let message = record["message"] as? String ?? ""
                let isCustom = (record["isCustomMessage"] as? Int64 ?? 0) == 1
                summary.seeds.append(SeedMessage(
                    id: record.recordID.recordName,
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    message: message,
                    isCustom: isCustom,
                    createdAt: createdAt
                ))

            default:
                break
            }

            grouped[workoutID] = summary
        }

        // Sort seeds by date
        for (key, var summary) in grouped {
            summary.seeds.sort { $0.createdAt < $1.createdAt }
            grouped[key] = summary
        }

        self.interactionsByWorkout = grouped
    }

    /// Batch fetch interactions for specific workout IDs and merge into interactionsByWorkout
    func fetchInteractions(for workoutIDs: [String]) async {
        guard let myAppleUserID, !workoutIDs.isEmpty else { return }

        let pred = NSPredicate(format: "workoutRecordName IN %@", workoutIDs)
        let query = CKQuery(recordType: RecordType.interaction, predicate: pred)

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 500) else { return }

        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        var grouped: [String: InteractionSummary] = [:]
        for workoutID in workoutIDs {
            grouped[workoutID] = .empty(for: workoutID)
        }

        for (_, result) in results {
            guard let record = try? result.get() else { continue }
            let workoutID = record["workoutRecordName"] as? String ?? ""
            let typeStr = record["type"] as? String ?? ""
            let senderID = record["senderID"] as? String ?? ""
            let createdAt = record["createdAt"] as? Date ?? Date()

            guard var summary = grouped[workoutID] else { continue }

            let senderName = senderID == myAppleUserID ? "You" : (friendLookup[senderID]?.displayName ?? "Friend")
            let senderImage = friendLookup[senderID]?.profileImageData

            switch typeStr {
            case "water":
                summary.waterCount += 1
                summary.waterers.append(InteractorInfo(userID: senderID, displayName: senderName, profileImageData: senderImage))
                if senderID == myAppleUserID { summary.iWatered = true }
                if createdAt > (summary.latestWaterDate ?? .distantPast) {
                    summary.latestWaterDate = createdAt
                }
            case "sunlight":
                summary.sunlightCount += 1
                summary.sunlighters.append(SunlightInfo(
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    earnedFromWorkoutName: nil
                ))
                if senderID == myAppleUserID { summary.iSunlit = true }
                if createdAt > (summary.latestSunlightDate ?? .distantPast) {
                    summary.latestSunlightDate = createdAt
                }
            case "seed":
                let message = record["message"] as? String ?? ""
                let isCustom = (record["isCustomMessage"] as? Int64 ?? 0) == 1
                summary.seeds.append(SeedMessage(
                    id: record.recordID.recordName,
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    message: message,
                    isCustom: isCustom,
                    createdAt: createdAt
                ))
            default:
                break
            }

            grouped[workoutID] = summary
        }

        for (key, var summary) in grouped {
            summary.seeds.sort { $0.createdAt < $1.createdAt }
            self.interactionsByWorkout[key] = summary
        }
    }

    /// Fetch detailed interactions for a single workout post
    func fetchDetailedInteractions(for workoutRecordName: String) async -> InteractionSummary? {
        guard let myAppleUserID else { return nil }

        let pred = NSPredicate(format: "workoutRecordName == %@", workoutRecordName)
        let query = CKQuery(recordType: RecordType.interaction, predicate: pred)

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 200) else { return nil }

        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        var summary = InteractionSummary.empty(for: workoutRecordName)

        // Collect sunlight sender workout record names to resolve display names
        var sunlightWorkoutRecordNames = Set<String>()
        for (_, result) in results {
            guard let record = try? result.get(),
                  record["type"] as? String == "sunlight",
                  let senderWorkoutRN = record["senderWorkoutRecordName"] as? String else { continue }
            sunlightWorkoutRecordNames.insert(senderWorkoutRN)
        }

        // Batch-fetch workout names for sunlight sources
        var workoutNameLookup = [String: String]()
        for recordName in sunlightWorkoutRecordNames {
            let recordID = CKRecord.ID(recordName: recordName)
            if let workoutRecord = try? await publicDB.record(for: recordID) {
                workoutNameLookup[recordName] = workoutRecord["workoutName"] as? String
            }
        }

        for (_, result) in results {
            guard let record = try? result.get() else { continue }
            let typeStr = record["type"] as? String ?? ""
            let senderID = record["senderID"] as? String ?? ""
            let createdAt = record["createdAt"] as? Date ?? Date()

            let senderName = senderID == myAppleUserID ? "You" : (friendLookup[senderID]?.displayName ?? "Friend")
            let senderImage = friendLookup[senderID]?.profileImageData

            switch typeStr {
            case "water":
                summary.waterCount += 1
                summary.waterers.append(InteractorInfo(userID: senderID, displayName: senderName, profileImageData: senderImage))
                if senderID == myAppleUserID { summary.iWatered = true }
                if createdAt > (summary.latestWaterDate ?? .distantPast) {
                    summary.latestWaterDate = createdAt
                }
            case "sunlight":
                summary.sunlightCount += 1
                let senderWorkoutRN = record["senderWorkoutRecordName"] as? String
                let resolvedName = senderWorkoutRN.flatMap { workoutNameLookup[$0] }
                summary.sunlighters.append(SunlightInfo(
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    earnedFromWorkoutName: resolvedName
                ))
                if senderID == myAppleUserID { summary.iSunlit = true }
                if createdAt > (summary.latestSunlightDate ?? .distantPast) {
                    summary.latestSunlightDate = createdAt
                }
            case "seed":
                let message = record["message"] as? String ?? ""
                let isCustom = (record["isCustomMessage"] as? Int64 ?? 0) == 1
                summary.seeds.append(SeedMessage(
                    id: record.recordID.recordName,
                    senderID: senderID,
                    senderName: senderName,
                    senderProfileImageData: senderImage,
                    message: message,
                    isCustom: isCustom,
                    createdAt: createdAt
                ))
            default:
                break
            }
        }

        summary.seeds.sort { $0.createdAt < $1.createdAt }
        return summary
    }

    /// Send a water interaction (one per sender per workout)
    func sendWater(to workoutRecordName: String, recipientID: String) async -> Bool {
        guard let myAppleUserID else { return false }

        // Check if already watered
        do {
            let pred = NSPredicate(format: "type == %@ AND senderID == %@ AND workoutRecordName == %@",
                                   "water", myAppleUserID, workoutRecordName)
            let query = CKQuery(recordType: RecordType.interaction, predicate: pred)
            let (existing, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            if !existing.isEmpty { return false } // Already watered
        } catch {
            // Schema may not exist yet — proceed
        }

        // Optimistic local update
        var summary = interactionsByWorkout[workoutRecordName] ?? .empty(for: workoutRecordName)
        summary.waterCount += 1
        summary.iWatered = true
        summary.latestWaterDate = Date()
        summary.waterers.append(InteractorInfo(userID: myAppleUserID, displayName: "You", profileImageData: nil))
        interactionsByWorkout[workoutRecordName] = summary

        do {
            let record = CKRecord(recordType: RecordType.interaction)
            record["type"] = "water" as CKRecordValue
            record["senderID"] = myAppleUserID as CKRecordValue
            record["recipientID"] = recipientID as CKRecordValue
            record["workoutRecordName"] = workoutRecordName as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            try await publicDB.save(record)
            return true
        } catch {
            // Revert optimistic update
            summary.waterCount -= 1
            summary.iWatered = false
            summary.waterers.removeAll { $0.userID == myAppleUserID }
            interactionsByWorkout[workoutRecordName] = summary
            self.error = "Could not send water: \(error.localizedDescription)"
            return false
        }
    }

    /// Send sunlight (requires an earned workout)
    func sendSunlight(to workoutRecordName: String, recipientID: String, fromWorkoutRecordName: String) async -> Bool {
        guard let myAppleUserID else { return false }

        // Check local set first (prevents rapid-tap duplicates)
        guard !usedSunlightSources.contains(fromWorkoutRecordName) else { return false }

        // Mark as used immediately to block concurrent sends
        usedSunlightSources.insert(fromWorkoutRecordName)

        // Optimistic local update
        var summary = interactionsByWorkout[workoutRecordName] ?? .empty(for: workoutRecordName)
        summary.sunlightCount += 1
        summary.iSunlit = true
        summary.latestSunlightDate = Date()
        summary.sunlighters.append(SunlightInfo(senderID: myAppleUserID, senderName: "You", senderProfileImageData: nil, earnedFromWorkoutName: nil))
        interactionsByWorkout[workoutRecordName] = summary
        availableSunlightCount = max(0, availableSunlightCount - 1)

        do {
            let record = CKRecord(recordType: RecordType.interaction)
            record["type"] = "sunlight" as CKRecordValue
            record["senderID"] = myAppleUserID as CKRecordValue
            record["recipientID"] = recipientID as CKRecordValue
            record["workoutRecordName"] = workoutRecordName as CKRecordValue
            record["senderWorkoutRecordName"] = fromWorkoutRecordName as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            try await publicDB.save(record)
            return true
        } catch {
            // Revert optimistic update
            usedSunlightSources.remove(fromWorkoutRecordName)
            summary.sunlightCount -= 1
            summary.iSunlit = false
            summary.sunlighters.removeAll { $0.senderID == myAppleUserID }
            interactionsByWorkout[workoutRecordName] = summary
            availableSunlightCount += 1
            self.error = "Could not send sunlight: \(error.localizedDescription)"
            return false
        }
    }

    /// Send a seed message
    func sendSeed(to workoutRecordName: String, recipientID: String, message: String, isCustom: Bool) async -> Bool {
        guard let myAppleUserID else { return false }

        let trimmed = String(message.prefix(60))

        do {
            let record = CKRecord(recordType: RecordType.interaction)
            record["type"] = "seed" as CKRecordValue
            record["senderID"] = myAppleUserID as CKRecordValue
            record["recipientID"] = recipientID as CKRecordValue
            record["workoutRecordName"] = workoutRecordName as CKRecordValue
            record["message"] = trimmed as CKRecordValue
            record["isCustomMessage"] = Int64(isCustom ? 1 : 0) as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            try await publicDB.save(record)

            // Update local state
            var summary = interactionsByWorkout[workoutRecordName] ?? .empty(for: workoutRecordName)
            summary.seeds.append(SeedMessage(
                id: record.recordID.recordName,
                senderID: myAppleUserID,
                senderName: "You",
                senderProfileImageData: nil,
                message: trimmed,
                isCustom: isCustom,
                createdAt: Date()
            ))
            interactionsByWorkout[workoutRecordName] = summary
            return true
        } catch {
            self.error = "Could not plant seed: \(error.localizedDescription)"
            return false
        }
    }

    /// Check how many sunlights the user has available (only from today's completed workouts)
    func checkAvailableSunlight() async {
        guard let myAppleUserID else { return }

        // Fetch only today's shared workouts
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let myWorkoutsPred = NSPredicate(format: "userID == %@ AND completedAt >= %@", myAppleUserID, startOfToday as NSDate)
        let myWorkoutsQuery = CKQuery(recordType: RecordType.sharedWorkout, predicate: myWorkoutsPred)
        guard let (myWorkouts, _) = try? await publicDB.records(matching: myWorkoutsQuery, resultsLimit: 50) else {
            availableSunlightCount = 0
            return
        }

        let myWorkoutRecordNames = myWorkouts.compactMap { (_, result) -> String? in
            guard let record = try? result.get() else { return nil }
            return record.recordID.recordName
        }

        guard !myWorkoutRecordNames.isEmpty else {
            availableSunlightCount = 0
            return
        }

        // Fetch sunlight interactions sent by me
        let sunlightPred = NSPredicate(format: "type == %@ AND senderID == %@", "sunlight", myAppleUserID)
        let sunlightQuery = CKQuery(recordType: RecordType.interaction, predicate: sunlightPred)
        let usedWorkoutNames: Set<String>
        if let (sunlightResults, _) = try? await publicDB.records(matching: sunlightQuery, resultsLimit: 200) {
            usedWorkoutNames = Set(sunlightResults.compactMap { (_, result) -> String? in
                guard let record = try? result.get() else { return nil }
                return record["senderWorkoutRecordName"] as? String
            })
        } else {
            usedWorkoutNames = []
        }

        // Available = my shared workouts minus those already used as sunlight source
        usedSunlightSources = usedWorkoutNames
        availableSunlightCount = myWorkoutRecordNames.filter { !usedWorkoutNames.contains($0) }.count
    }

    /// Get the record name of the user's most recent unused shared workout from today (for sunlight sending)
    func myLatestSharedWorkoutRecordName() async -> String? {
        guard let myAppleUserID else { return nil }

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let pred = NSPredicate(format: "userID == %@ AND completedAt >= %@", myAppleUserID, startOfToday as NSDate)
        let query = CKQuery(recordType: RecordType.sharedWorkout, predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 50) else { return nil }

        for (_, result) in results {
            guard let record = try? result.get() else { continue }
            let name = record.recordID.recordName
            if !usedSunlightSources.contains(name) {
                return name
            }
        }
        return nil
    }

    // MARK: - Root Connections

    /// Compute root connection scores from all interactions involving the current user
    func fetchRootConnections() async {
        guard let myAppleUserID else { return }

        // Save previous levels for milestone detection
        previousRootLevels = Dictionary(uniqueKeysWithValues: rootConnections.map { ($0.friendID, $0.level) })

        // Fetch interactions where I'm the sender
        let sentPred = NSPredicate(format: "senderID == %@", myAppleUserID)
        let sentQuery = CKQuery(recordType: RecordType.interaction, predicate: sentPred)
        let sentResults = (try? await publicDB.records(matching: sentQuery, resultsLimit: 500))?.0 ?? []

        // Fetch interactions where I'm the recipient
        let receivedPred = NSPredicate(format: "recipientID == %@", myAppleUserID)
        let receivedQuery = CKQuery(recordType: RecordType.interaction, predicate: receivedPred)
        let receivedResults = (try? await publicDB.records(matching: receivedQuery, resultsLimit: 500))?.0 ?? []

        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        // Aggregate scores per friend
        var scores: [String: Int] = [:]
        for (_, result) in sentResults {
            guard let record = try? result.get() else { continue }
            let recipientID = record["recipientID"] as? String ?? ""
            let typeStr = record["type"] as? String ?? ""
            if let type = InteractionType(rawValue: typeStr) {
                scores[recipientID, default: 0] += type.connectionWeight
            }
        }
        for (_, result) in receivedResults {
            guard let record = try? result.get() else { continue }
            let senderID = record["senderID"] as? String ?? ""
            let typeStr = record["type"] as? String ?? ""
            if let type = InteractionType(rawValue: typeStr) {
                scores[senderID, default: 0] += type.connectionWeight
            }
        }

        // Build root connections (only for friends)
        var connections: [RootConnection] = []
        for (friendID, score) in scores {
            guard let friend = friendLookup[friendID] else { continue }
            connections.append(RootConnection(
                friendID: friendID,
                friendName: friend.displayName,
                friendProfileImageData: friend.profileImageData,
                score: score
            ))
        }

        self.rootConnections = connections.sorted { $0.score > $1.score }
    }

    /// Fetch interaction breakdown between current user and a specific friend
    func fetchInteractionBreakdown(with friendID: String) async -> InteractionBreakdown? {
        guard let myAppleUserID else { return nil }

        let friend = friends.first { $0.id == friendID }

        // Sent to friend
        let sentPred = NSPredicate(format: "senderID == %@ AND recipientID == %@", myAppleUserID, friendID)
        let sentQuery = CKQuery(recordType: RecordType.interaction, predicate: sentPred)
        let sentResults = (try? await publicDB.records(matching: sentQuery, resultsLimit: 200))?.0 ?? []

        // Received from friend
        let receivedPred = NSPredicate(format: "senderID == %@ AND recipientID == %@", friendID, myAppleUserID)
        let receivedQuery = CKQuery(recordType: RecordType.interaction, predicate: receivedPred)
        let receivedResults = (try? await publicDB.records(matching: receivedQuery, resultsLimit: 200))?.0 ?? []

        var breakdown = InteractionBreakdown(
            friendID: friendID,
            friendName: friend?.displayName ?? "Friend",
            friendProfileImageData: friend?.profileImageData
        )

        for (_, result) in sentResults {
            guard let record = try? result.get() else { continue }
            switch record["type"] as? String {
            case "water": breakdown.watersSent += 1
            case "seed": breakdown.seedsSent += 1
            case "sunlight": breakdown.sunlightsSent += 1
            default: break
            }
        }

        for (_, result) in receivedResults {
            guard let record = try? result.get() else { continue }
            switch record["type"] as? String {
            case "water": breakdown.watersReceived += 1
            case "seed": breakdown.seedsReceived += 1
            case "sunlight": breakdown.sunlightsReceived += 1
            default: break
            }
        }

        return breakdown
    }

    /// Check if any root connections leveled up since last fetch
    func checkForConnectionMilestones() -> [(friendName: String, newLevel: RootLevel)] {
        var milestones: [(String, RootLevel)] = []
        for connection in rootConnections {
            let previousLevel = previousRootLevels[connection.friendID]
            if let prev = previousLevel, connection.level != prev,
               let currentIdx = RootLevel.allCases.firstIndex(of: connection.level),
               let prevIdx = RootLevel.allCases.firstIndex(of: prev),
               currentIdx > prevIdx {
                milestones.append((connection.friendName, connection.level))
            }
        }
        return milestones
    }

    // MARK: - Debug

    #if DEBUG
    func addTestFriend() async {
        guard let myAppleUserID else { return }

        let testID = "debug_friend_\(UUID().uuidString.prefix(8))"
        let names = ["Alex", "Jordan", "Sam", "Riley", "Morgan"]
        let name = names.randomElement()!

        do {
            // Create a fake user profile
            let profileID = CKRecord.ID(recordName: testID)
            let profile = CKRecord(recordType: RecordType.userProfile, recordID: profileID)
            profile["appleUserID"] = testID as CKRecordValue
            profile["displayName"] = name as CKRecordValue
            profile["workoutCount"] = Int64.random(in: 5...50) as CKRecordValue
            profile["currentStreak"] = Int64.random(in: 0...14) as CKRecordValue
            profile["memberSince"] = Calendar.current.date(byAdding: .month, value: -Int.random(in: 1...6), to: Date())! as CKRecordValue
            profile["inviteCode"] = "" as CKRecordValue
            try await publicDB.save(profile)

            // Create friend link
            let id1 = min(myAppleUserID, testID)
            let id2 = max(myAppleUserID, testID)
            let link = CKRecord(recordType: RecordType.friendLink)
            link["userID1"] = id1 as CKRecordValue
            link["userID2"] = id2 as CKRecordValue
            link["createdAt"] = Date() as CKRecordValue
            try await publicDB.save(link)

            // Create a couple shared workouts with exercise data
            let workoutData: [(name: String, category: String, exercises: [String])] = [
                ("Push Day", "Push", ["Barbell Bench Press", "Incline Dumbbell Press", "Cable Crossover", "Tricep Pushdown", "Overhead Tricep Extension"]),
                ("Pull Day", "Pull", ["Barbell Row", "Pull-Ups", "Seated Cable Row", "Face Pulls", "Barbell Curl"]),
                ("Leg Day", "Legs", ["Barbell Squat", "Romanian Deadlift", "Leg Press", "Leg Curl", "Calf Raises"]),
                ("Shoulders", "Shoulders", ["Overhead Press", "Lateral Raises", "Front Raises", "Rear Delt Flyes"]),
                ("Full Body", "Full Body", ["Deadlift", "Barbell Bench Press", "Barbell Row", "Barbell Squat", "Pull-Ups", "Tricep Dips"])
            ]
            for i in 0..<2 {
                let picked = workoutData.randomElement()!
                let workout = CKRecord(recordType: RecordType.sharedWorkout)
                workout["userID"] = testID as CKRecordValue
                workout["workoutName"] = picked.name as CKRecordValue
                workout["templateCategory"] = picked.category as CKRecordValue
                workout["duration"] = Double.random(in: 1800...4200) as CKRecordValue
                let exCount = Int.random(in: 4...6)
                workout["exerciseCount"] = Int64(exCount) as CKRecordValue
                workout["totalSets"] = Int64(exCount * 3) as CKRecordValue
                workout["completedAt"] = Calendar.current.date(byAdding: .hour, value: -(i * Int.random(in: 2...24)), to: Date())! as CKRecordValue
                workout["shareExercises"] = Int64(1) as CKRecordValue
                workout["shareWeights"] = Int64(1) as CKRecordValue

                // Build exercises JSON with weights
                let selectedExercises = Array(picked.exercises.prefix(exCount))
                // Randomly mark some exercises as PRs (first workout gets PRs, second doesn't)
                let hasPRs = i == 0 && Bool.random()
                var prNames: [String] = []
                if hasPRs {
                    let prCount = Int.random(in: 1...min(2, selectedExercises.count))
                    prNames = Array(selectedExercises.shuffled().prefix(prCount))
                }
                let exerciseData: [[String: Any]] = selectedExercises.map { name in
                    let weight = Double(Int.random(in: 6...30) * 5) // 30-150 lbs
                    let reps = Int.random(in: 6...12)
                    var entry: [String: Any] = [
                        "name": name,
                        "sets": (0..<3).map { _ in ["weight": weight, "reps": reps] }
                    ]
                    if prNames.contains(name) {
                        entry["isPR"] = true
                    }
                    return entry
                }
                if !prNames.isEmpty {
                    workout["prCount"] = Int64(prNames.count) as CKRecordValue
                    if let prJSON = try? JSONSerialization.data(withJSONObject: prNames),
                       let prString = String(data: prJSON, encoding: .utf8) {
                        workout["prExerciseNamesJSON"] = prString as CKRecordValue
                    }
                }
                if let jsonData = try? JSONSerialization.data(withJSONObject: exerciseData),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    workout["exercisesJSON"] = jsonString as CKRecordValue
                }

                try await publicDB.save(workout)
            }

            // Refresh
            await fetchFriends()
            await fetchFeed()
            self.error = nil
        } catch {
            self.error = "Could not create test friend: \(error.localizedDescription)"
        }
    }
    func removeAllTestData() async {
        guard let myAppleUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Find all friend links involving this user
            let pred1 = NSPredicate(format: "userID1 == %@", myAppleUserID)
            let pred2 = NSPredicate(format: "userID2 == %@", myAppleUserID)
            let q1 = CKQuery(recordType: RecordType.friendLink, predicate: pred1)
            let q2 = CKQuery(recordType: RecordType.friendLink, predicate: pred2)

            let (links1, _) = (try? await publicDB.records(matching: q1)) ?? ([], nil)
            let (links2, _) = (try? await publicDB.records(matching: q2)) ?? ([], nil)

            // Collect debug friend IDs and delete links
            var debugFriendIDs: Set<String> = []
            for (recordID, result) in links1 + links2 {
                if let record = try? result.get() {
                    let id1 = record["userID1"] as? String ?? ""
                    let id2 = record["userID2"] as? String ?? ""
                    let friendID = (id1 == myAppleUserID) ? id2 : id1
                    if friendID.hasPrefix("debug_friend_") {
                        debugFriendIDs.insert(friendID)
                        _ = try? await publicDB.deleteRecord(withID: recordID)
                    }
                }
            }

            // Delete debug friend profiles, their shared workouts, and interactions
            for friendID in debugFriendIDs {
                // Delete profile
                let profileID = CKRecord.ID(recordName: friendID)
                _ = try? await publicDB.deleteRecord(withID: profileID)

                // Delete their shared workouts
                let wPred = NSPredicate(format: "userID == %@", friendID)
                let wQuery = CKQuery(recordType: RecordType.sharedWorkout, predicate: wPred)
                if let (workouts, _) = try? await publicDB.records(matching: wQuery) {
                    for (wRecordID, _) in workouts {
                        _ = try? await publicDB.deleteRecord(withID: wRecordID)
                    }
                }

                // Delete interactions involving this debug friend
                let iPred1 = NSPredicate(format: "senderID == %@", friendID)
                let iQuery1 = CKQuery(recordType: RecordType.interaction, predicate: iPred1)
                if let (interactions, _) = try? await publicDB.records(matching: iQuery1) {
                    for (iRecordID, _) in interactions {
                        _ = try? await publicDB.deleteRecord(withID: iRecordID)
                    }
                }
                let iPred2 = NSPredicate(format: "recipientID == %@", friendID)
                let iQuery2 = CKQuery(recordType: RecordType.interaction, predicate: iPred2)
                if let (interactions, _) = try? await publicDB.records(matching: iQuery2) {
                    for (iRecordID, _) in interactions {
                        _ = try? await publicDB.deleteRecord(withID: iRecordID)
                    }
                }
            }

            // Refresh
            await fetchFriends()
            await fetchFeed()
            self.error = nil
        }
    }
    #endif

    // MARK: - Helpers

    static func parsePRExerciseNames(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }

    // MARK: - Background Feed Check

    func checkForNewFriendWorkouts(since lastCheck: Date, user: User) async -> [SharedWorkoutItem] {
        guard let myAppleUserID else { return [] }

        let friendIDs = friends.map { $0.id }
        guard !friendIDs.isEmpty else { return [] }

        let pred = NSPredicate(format: "userID IN %@ AND completedAt > %@", friendIDs, lastCheck as NSDate)
        let query = CKQuery(recordType: RecordType.sharedWorkout, predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 10) else {
            return []
        }

        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        var items: [SharedWorkoutItem] = []
        for (_, result) in results {
            if let record = try? result.get() {
                let userID = record["userID"] as? String ?? ""
                guard userID != myAppleUserID else { continue }
                let friend = friendLookup[userID]

                items.append(SharedWorkoutItem(
                    id: record.recordID.recordName,
                    userID: userID,
                    friendName: friend?.displayName ?? "Friend",
                    friendProfileImageData: friend?.profileImageData,
                    workoutName: record["workoutName"] as? String ?? "Workout",
                    templateCategory: record["templateCategory"] as? String,
                    duration: record["duration"] as? TimeInterval ?? 0,
                    exerciseCount: Int(record["exerciseCount"] as? Int64 ?? 0),
                    totalSets: Int(record["totalSets"] as? Int64 ?? 0),
                    completedAt: record["completedAt"] as? Date ?? Date(),
                    exercisesJSON: record["exercisesJSON"] as? String,
                    prCount: Int(record["prCount"] as? Int64 ?? 0),
                    prExerciseNames: Self.parsePRExerciseNames(record["prExerciseNamesJSON"] as? String)
                ))
            }
        }

        return items
    }

    // MARK: - Background Interaction Check

    struct ReceivedInteraction: Sendable {
        let type: InteractionType
        let senderName: String
        let workoutName: String
        let seedMessage: String?
    }

    func checkForNewInteractions(since lastCheck: Date) async -> [ReceivedInteraction] {
        guard let myAppleUserID else { return [] }

        let pred = NSPredicate(format: "recipientID == %@ AND senderID != %@ AND createdAt > %@",
                               myAppleUserID, myAppleUserID, lastCheck as NSDate)
        let query = CKQuery(recordType: RecordType.interaction, predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 20) else {
            return []
        }

        // Collect unique sender IDs and workout record names to resolve display names
        var senderIDs = Set<String>()
        var workoutRecordNames = Set<String>()
        var records: [CKRecord] = []

        for (_, result) in results {
            if let record = try? result.get() {
                records.append(record)
                if let senderID = record["senderID"] as? String {
                    senderIDs.insert(senderID)
                }
                if let workoutRN = record["workoutRecordName"] as? String {
                    workoutRecordNames.insert(workoutRN)
                }
            }
        }

        guard !records.isEmpty else { return [] }

        // Resolve sender names from friends list or CloudKit
        let friendLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0.displayName) })
        var senderNames = friendLookup
        let unknownSenders = senderIDs.subtracting(Set(friendLookup.keys))
        for senderID in unknownSenders {
            let profileID = CKRecord.ID(recordName: senderID)
            if let profile = try? await publicDB.record(for: profileID),
               let name = profile["displayName"] as? String {
                senderNames[senderID] = name
            }
        }

        // Resolve workout names from shared workouts
        var workoutNames: [String: String] = [:]
        for rn in workoutRecordNames {
            let recordID = CKRecord.ID(recordName: rn)
            if let workout = try? await publicDB.record(for: recordID),
               let name = workout["workoutName"] as? String {
                workoutNames[rn] = name
            }
        }

        // Build interaction items
        var interactions: [ReceivedInteraction] = []
        for record in records {
            let typeStr = record["type"] as? String ?? ""
            guard let type = InteractionType(rawValue: typeStr) else { continue }
            let senderID = record["senderID"] as? String ?? ""
            let workoutRN = record["workoutRecordName"] as? String ?? ""

            interactions.append(ReceivedInteraction(
                type: type,
                senderName: senderNames[senderID] ?? "Someone",
                workoutName: workoutNames[workoutRN] ?? "Workout",
                seedMessage: record["message"] as? String
            ))
        }

        return interactions
    }

    // MARK: - Program Sync Helpers

    private static func writeProgramFields(to record: CKRecord, user: User) {
        if user.shareProgram {
            record["splitName"] = user.preferredSplit.rawValue as CKRecordValue
            record["daysPerWeek"] = Int64(user.preferredDaysPerWeek) as CKRecordValue
            record["repRange"] = user.preferredRepRange.rawValue as CKRecordValue
            record["sessionMinutes"] = Int64(user.preferredWorkoutMinutes) as CKRecordValue
        } else {
            record["splitName"] = nil
            record["daysPerWeek"] = nil
            record["repRange"] = nil
            record["sessionMinutes"] = nil
        }
    }

    private func profileFromRecord(_ record: CKRecord) -> CKFriendProfile {
        var imageData: Data?
        if let asset = record["profileImage"] as? CKAsset,
           let url = asset.fileURL {
            imageData = try? Data(contentsOf: url)
        }

        return CKFriendProfile(
            id: record["appleUserID"] as? String ?? record.recordID.recordName,
            displayName: record["displayName"] as? String ?? "Athlete",
            profileImageData: imageData,
            inviteCode: record["inviteCode"] as? String,
            workoutCount: Int(record["workoutCount"] as? Int64 ?? 0),
            currentStreak: Int(record["currentStreak"] as? Int64 ?? 0),
            memberSince: record["memberSince"] as? Date ?? Date(),
            recordID: record.recordID,
            splitName: record["splitName"] as? String,
            daysPerWeek: (record["daysPerWeek"] as? Int64).map { Int($0) },
            repRange: record["repRange"] as? String,
            sessionMinutes: (record["sessionMinutes"] as? Int64).map { Int($0) }
        )
    }
}
