import Foundation
import SwiftUI

/// Sample data for previewing social interaction views without CloudKit
@MainActor
enum SocialPreviewData {

    // MARK: - Friends

    static let friends: [CKFriendProfile] = [
        CKFriendProfile(id: "user_sarah", displayName: "Sarah", profileImageData: nil, inviteCode: "GROVE-AB12", workoutCount: 47, currentStreak: 12, memberSince: date(daysAgo: 120), recordID: .init(recordName: "user_sarah"), splitName: "Push / Pull / Legs", daysPerWeek: 6, repRange: "Hypertrophy", sessionMinutes: 60),
        CKFriendProfile(id: "user_mike", displayName: "Mike", profileImageData: nil, inviteCode: "GROVE-CD34", workoutCount: 82, currentStreak: 5, memberSince: date(daysAgo: 200), recordID: .init(recordName: "user_mike"), splitName: "Upper / Lower", daysPerWeek: 4, repRange: "Strength", sessionMinutes: 75),
        CKFriendProfile(id: "user_alex", displayName: "Alex", profileImageData: nil, inviteCode: "GROVE-EF56", workoutCount: 31, currentStreak: 22, memberSince: date(daysAgo: 90), recordID: .init(recordName: "user_alex"), splitName: "Push / Pull / Legs", daysPerWeek: 5, repRange: "Hypertrophy", sessionMinutes: 60),
        CKFriendProfile(id: "user_jordan", displayName: "Jordan", profileImageData: nil, inviteCode: "GROVE-GH78", workoutCount: 63, currentStreak: 0, memberSince: date(daysAgo: 180), recordID: .init(recordName: "user_jordan"), splitName: nil, daysPerWeek: nil, repRange: nil, sessionMinutes: nil),
        CKFriendProfile(id: "user_riley", displayName: "Riley", profileImageData: nil, inviteCode: "GROVE-IJ90", workoutCount: 19, currentStreak: 3, memberSince: date(daysAgo: 45), recordID: .init(recordName: "user_riley"), splitName: "Full Body", daysPerWeek: 3, repRange: "Hypertrophy", sessionMinutes: 45),
        CKFriendProfile(id: "user_casey", displayName: "Casey", profileImageData: nil, inviteCode: "GROVE-KL23", workoutCount: 55, currentStreak: 8, memberSince: date(daysAgo: 150), recordID: .init(recordName: "user_casey"), splitName: "Bro Split", daysPerWeek: 5, repRange: "Hypertrophy", sessionMinutes: 60),
        CKFriendProfile(id: "user_taylor", displayName: "Taylor", profileImageData: nil, inviteCode: "GROVE-MN45", workoutCount: 28, currentStreak: 15, memberSince: date(daysAgo: 75), recordID: .init(recordName: "user_taylor"), splitName: "Arnold Split", daysPerWeek: 6, repRange: "Strength", sessionMinutes: 90),
    ]

    // MARK: - Feed Items

    static let feedItems: [SharedWorkoutItem] = [
        // Sarah - Push Day with PRs (2h ago)
        SharedWorkoutItem(
            id: "workout_1", userID: "user_sarah",
            friendName: "Sarah", friendProfileImageData: nil,
            workoutName: "Push Day", templateCategory: "Push", duration: 3120,
            exerciseCount: 5, totalSets: 15,
            completedAt: date(hoursAgo: 2),
            exercisesJSON: exercisesJSON([
                ("Barbell Bench Press", 185, 8, 3, true),
                ("Incline Dumbbell Press", 60, 10, 3, false),
                ("Cable Crossover", 30, 12, 3, false),
                ("Tricep Pushdown", 55, 10, 3, false),
                ("Overhead Tricep Extension", 40, 12, 3, false),
            ]),
            prCount: 1, prExerciseNames: ["Barbell Bench Press"]
        ),
        // Mike - Pull Day (4h ago)
        SharedWorkoutItem(
            id: "workout_2", userID: "user_mike",
            friendName: "Mike", friendProfileImageData: nil,
            workoutName: "Pull Day", templateCategory: "Pull", duration: 3600,
            exerciseCount: 5, totalSets: 15,
            completedAt: date(hoursAgo: 4),
            exercisesJSON: exercisesJSON([
                ("Barbell Row", 155, 8, 3, false),
                ("Pull-Ups", 0, 10, 3, false),
                ("Seated Cable Row", 120, 10, 3, false),
                ("Face Pulls", 40, 15, 3, false),
                ("Barbell Curl", 75, 10, 3, false),
            ]),
            prCount: 0, prExerciseNames: []
        ),
        // Alex - Leg Day with 2 PRs (6h ago)
        SharedWorkoutItem(
            id: "workout_3", userID: "user_alex",
            friendName: "Alex", friendProfileImageData: nil,
            workoutName: "Leg Day", templateCategory: "Legs", duration: 4200,
            exerciseCount: 5, totalSets: 15,
            completedAt: date(hoursAgo: 6),
            exercisesJSON: exercisesJSON([
                ("Barbell Squat", 275, 5, 4, true),
                ("Romanian Deadlift", 225, 8, 3, true),
                ("Leg Press", 400, 10, 3, false),
                ("Leg Curl", 90, 12, 3, false),
                ("Calf Raises", 135, 15, 3, false),
            ]),
            prCount: 2, prExerciseNames: ["Barbell Squat", "Romanian Deadlift"]
        ),
        // Jordan - Upper Body (yesterday)
        SharedWorkoutItem(
            id: "workout_4", userID: "user_jordan",
            friendName: "Jordan", friendProfileImageData: nil,
            workoutName: "Upper Body", templateCategory: "Upper", duration: 2700,
            exerciseCount: 6, totalSets: 18,
            completedAt: date(hoursAgo: 26),
            exercisesJSON: exercisesJSON([
                ("Overhead Press", 115, 8, 3, false),
                ("Lateral Raises", 20, 12, 3, false),
                ("Barbell Bench Press", 165, 8, 3, false),
                ("Barbell Row", 135, 8, 3, false),
                ("Tricep Dips", 0, 12, 3, false),
                ("Barbell Curl", 65, 10, 3, false),
            ]),
            prCount: 0, prExerciseNames: []
        ),
        // Riley - Full Body (yesterday)
        SharedWorkoutItem(
            id: "workout_5", userID: "user_riley",
            friendName: "Riley", friendProfileImageData: nil,
            workoutName: "Full Body", templateCategory: "Full Body", duration: 3900,
            exerciseCount: 6, totalSets: 18,
            completedAt: date(hoursAgo: 28),
            exercisesJSON: exercisesJSON([
                ("Deadlift", 315, 3, 5, true),
                ("Barbell Bench Press", 155, 8, 3, false),
                ("Barbell Squat", 185, 8, 3, false),
                ("Pull-Ups", 0, 8, 3, false),
                ("Overhead Press", 95, 8, 3, false),
                ("Barbell Row", 115, 8, 3, false),
            ]),
            prCount: 1, prExerciseNames: ["Deadlift"]
        ),
        // Casey - Push Day (2 days ago)
        SharedWorkoutItem(
            id: "workout_6", userID: "user_casey",
            friendName: "Casey", friendProfileImageData: nil,
            workoutName: "Push Day", templateCategory: "Push", duration: 2400,
            exerciseCount: 4, totalSets: 12,
            completedAt: date(hoursAgo: 50),
            exercisesJSON: exercisesJSON([
                ("Barbell Bench Press", 135, 10, 3, false),
                ("Incline Dumbbell Press", 45, 10, 3, false),
                ("Cable Crossover", 25, 12, 3, false),
                ("Tricep Pushdown", 45, 12, 3, false),
            ]),
            prCount: 0, prExerciseNames: []
        ),
        // Taylor - Shoulders (2 days ago)
        SharedWorkoutItem(
            id: "workout_7", userID: "user_taylor",
            friendName: "Taylor", friendProfileImageData: nil,
            workoutName: "Shoulders", templateCategory: "Shoulders", duration: 2100,
            exerciseCount: 4, totalSets: 12,
            completedAt: date(hoursAgo: 52),
            exercisesJSON: exercisesJSON([
                ("Overhead Press", 105, 8, 3, false),
                ("Lateral Raises", 25, 12, 3, false),
                ("Front Raises", 20, 12, 3, false),
                ("Rear Delt Flyes", 15, 15, 3, false),
            ]),
            prCount: 0, prExerciseNames: []
        ),
    ]

    // MARK: - Interactions

    static let interactionsByWorkout: [String: InteractionSummary] = [
        // Sarah's Push Day — heavily interacted (watered, sunlit, 3 seeds)
        "workout_1": InteractionSummary(
            workoutRecordName: "workout_1",
            waterCount: 4,
            sunlightCount: 1,
            seeds: [
                SeedMessage(id: "seed_1", senderID: "user_mike", senderName: "Mike", senderProfileImageData: nil, message: "That PR was earned", isCustom: false, createdAt: date(hoursAgo: 1)),
                SeedMessage(id: "seed_2", senderID: "user_alex", senderName: "Alex", senderProfileImageData: nil, message: "Beast mode!", isCustom: true, createdAt: date(minutesAgo: 45)),
                SeedMessage(id: "seed_3", senderID: "user_jordan", senderName: "Jordan", senderProfileImageData: nil, message: "Stronger than yesterday", isCustom: false, createdAt: date(minutesAgo: 20)),
            ],
            iWatered: true,
            iSunlit: false,
            waterers: [
                InteractorInfo(userID: "preview_user", displayName: "You", profileImageData: nil),
                InteractorInfo(userID: "user_mike", displayName: "Mike", profileImageData: nil),
                InteractorInfo(userID: "user_alex", displayName: "Alex", profileImageData: nil),
                InteractorInfo(userID: "user_riley", displayName: "Riley", profileImageData: nil),
            ],
            sunlighters: [
                SunlightInfo(senderID: "user_alex", senderName: "Alex", senderProfileImageData: nil, earnedFromWorkoutName: "Leg Day"),
            ],
            latestWaterDate: date(minutesAgo: 30),
            latestSunlightDate: date(hoursAgo: 1)
        ),
        // Mike's Pull Day — watered by 2 people, 1 seed
        "workout_2": InteractionSummary(
            workoutRecordName: "workout_2",
            waterCount: 2,
            sunlightCount: 0,
            seeds: [
                SeedMessage(id: "seed_4", senderID: "user_sarah", senderName: "Sarah", senderProfileImageData: nil, message: "Consistency looks good on you", isCustom: false, createdAt: date(hoursAgo: 3)),
            ],
            iWatered: false,
            iSunlit: false,
            waterers: [
                InteractorInfo(userID: "user_sarah", displayName: "Sarah", profileImageData: nil),
                InteractorInfo(userID: "user_casey", displayName: "Casey", profileImageData: nil),
            ],
            sunlighters: [],
            latestWaterDate: date(hoursAgo: 3),
            latestSunlightDate: nil
        ),
        // Alex's Leg Day — heavily interacted (sunlit, watered, 4 seeds, 2 PRs)
        "workout_3": InteractionSummary(
            workoutRecordName: "workout_3",
            waterCount: 5,
            sunlightCount: 2,
            seeds: [
                SeedMessage(id: "seed_5", senderID: "user_sarah", senderName: "Sarah", senderProfileImageData: nil, message: "New heights!", isCustom: false, createdAt: date(hoursAgo: 5)),
                SeedMessage(id: "seed_6", senderID: "user_mike", senderName: "Mike", senderProfileImageData: nil, message: "275 squat is insane", isCustom: true, createdAt: date(hoursAgo: 5)),
                SeedMessage(id: "seed_7", senderID: "user_jordan", senderName: "Jordan", senderProfileImageData: nil, message: "PR machine", isCustom: false, createdAt: date(hoursAgo: 4)),
                SeedMessage(id: "seed_8", senderID: "user_riley", senderName: "Riley", senderProfileImageData: nil, message: "The work is paying off", isCustom: false, createdAt: date(hoursAgo: 3)),
            ],
            iWatered: true,
            iSunlit: true,
            waterers: [
                InteractorInfo(userID: "preview_user", displayName: "You", profileImageData: nil),
                InteractorInfo(userID: "user_sarah", displayName: "Sarah", profileImageData: nil),
                InteractorInfo(userID: "user_mike", displayName: "Mike", profileImageData: nil),
                InteractorInfo(userID: "user_jordan", displayName: "Jordan", profileImageData: nil),
                InteractorInfo(userID: "user_casey", displayName: "Casey", profileImageData: nil),
            ],
            sunlighters: [
                SunlightInfo(senderID: "preview_user", senderName: "You", senderProfileImageData: nil, earnedFromWorkoutName: "Push Day"),
                SunlightInfo(senderID: "user_sarah", senderName: "Sarah", senderProfileImageData: nil, earnedFromWorkoutName: "Push Day"),
            ],
            latestWaterDate: date(hoursAgo: 3),
            latestSunlightDate: date(hoursAgo: 4)
        ),
        // Jordan's Upper Body — only watered by 1 person, no seeds
        "workout_4": InteractionSummary(
            workoutRecordName: "workout_4",
            waterCount: 1,
            sunlightCount: 0,
            seeds: [],
            iWatered: false,
            iSunlit: false,
            waterers: [
                InteractorInfo(userID: "user_casey", displayName: "Casey", profileImageData: nil),
            ],
            sunlighters: [],
            latestWaterDate: date(hoursAgo: 20),
            latestSunlightDate: nil
        ),
        // Riley's Full Body — sunlit, watered, 2 seeds
        "workout_5": InteractionSummary(
            workoutRecordName: "workout_5",
            waterCount: 3,
            sunlightCount: 1,
            seeds: [
                SeedMessage(id: "seed_9", senderID: "user_taylor", senderName: "Taylor", senderProfileImageData: nil, message: "315 deadlift! Goals", isCustom: true, createdAt: date(hoursAgo: 24)),
                SeedMessage(id: "seed_10", senderID: "user_alex", senderName: "Alex", senderProfileImageData: nil, message: "Breaking barriers", isCustom: false, createdAt: date(hoursAgo: 22)),
            ],
            iWatered: true,
            iSunlit: false,
            waterers: [
                InteractorInfo(userID: "preview_user", displayName: "You", profileImageData: nil),
                InteractorInfo(userID: "user_taylor", displayName: "Taylor", profileImageData: nil),
                InteractorInfo(userID: "user_alex", displayName: "Alex", profileImageData: nil),
            ],
            sunlighters: [
                SunlightInfo(senderID: "user_mike", senderName: "Mike", senderProfileImageData: nil, earnedFromWorkoutName: "Pull Day"),
            ],
            latestWaterDate: date(hoursAgo: 22),
            latestSunlightDate: date(hoursAgo: 24)
        ),
        // Casey's Push Day — no interactions yet
        "workout_6": .empty(for: "workout_6"),
        // Taylor's Shoulders — just 1 water
        "workout_7": InteractionSummary(
            workoutRecordName: "workout_7",
            waterCount: 1,
            sunlightCount: 0,
            seeds: [],
            iWatered: false,
            iSunlit: false,
            waterers: [
                InteractorInfo(userID: "user_mike", displayName: "Mike", profileImageData: nil),
            ],
            sunlighters: [],
            latestWaterDate: date(hoursAgo: 48),
            latestSunlightDate: nil
        ),
    ]

    // MARK: - Root Connections

    static let rootConnections: [RootConnection] = [
        RootConnection(friendID: "user_sarah", friendName: "Sarah", friendProfileImageData: nil, score: 52),    // Intertwined
        RootConnection(friendID: "user_mike", friendName: "Mike", friendProfileImageData: nil, score: 35),      // Growing
        RootConnection(friendID: "user_alex", friendName: "Alex", friendProfileImageData: nil, score: 88),      // Deep Roots
        RootConnection(friendID: "user_jordan", friendName: "Jordan", friendProfileImageData: nil, score: 12),  // Scattered
        RootConnection(friendID: "user_riley", friendName: "Riley", friendProfileImageData: nil, score: 24),    // Growing
        RootConnection(friendID: "user_casey", friendName: "Casey", friendProfileImageData: nil, score: 45),    // Intertwined
        RootConnection(friendID: "user_taylor", friendName: "Taylor", friendProfileImageData: nil, score: 8),   // Scattered
    ]

    // MARK: - Interaction Breakdowns

    static func breakdown(for friendID: String) -> InteractionBreakdown {
        let friend = friends.first { $0.id == friendID }
        switch friendID {
        case "user_sarah":
            return InteractionBreakdown(friendID: friendID, friendName: "Sarah", friendProfileImageData: nil,
                                        watersSent: 12, watersReceived: 14, seedsSent: 4, seedsReceived: 6,
                                        sunlightsSent: 2, sunlightsReceived: 1)
        case "user_alex":
            return InteractionBreakdown(friendID: friendID, friendName: "Alex", friendProfileImageData: nil,
                                        watersSent: 22, watersReceived: 20, seedsSent: 8, seedsReceived: 10,
                                        sunlightsSent: 4, sunlightsReceived: 3)
        default:
            return InteractionBreakdown(friendID: friendID, friendName: friend?.displayName ?? "Friend",
                                        friendProfileImageData: nil,
                                        watersSent: 3, watersReceived: 2, seedsSent: 1, seedsReceived: 1,
                                        sunlightsSent: 0, sunlightsReceived: 0)
        }
    }

    // MARK: - Pre-configured Social Service

    static var socialService: CloudKitSocialService {
        let service = CloudKitSocialService()
        service.friends = friends
        service.feedItems = feedItems
        service.interactionsByWorkout = interactionsByWorkout
        service.rootConnections = rootConnections
        service.availableSunlightCount = 2
        service.myInviteCode = "GROVE-ZZ99"
        return service
    }

    // MARK: - Helpers

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    private static func date(hoursAgo: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date())!
    }

    private static func date(minutesAgo: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: -minutesAgo, to: Date())!
    }

    private static func exercisesJSON(_ exercises: [(String, Double, Int, Int, Bool)]) -> String {
        let array: [[String: Any]] = exercises.map { (name, weight, reps, sets, isPR) in
            var entry: [String: Any] = [
                "name": name,
                "sets": (0..<sets).map { _ in ["weight": weight, "reps": reps] as [String: Any] }
            ]
            if isPR { entry["isPR"] = true }
            return entry
        }
        let data = try! JSONSerialization.data(withJSONObject: array)
        return String(data: data, encoding: .utf8)!
    }
}
