import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var appleUserID: String
    var displayName: String?
    var fitnessGoal: FitnessGoal
    var experienceLevel: ExperienceLevel
    var preferredUnits: UnitSystem

    // Smart Builder preferences
    var preferredDaysPerWeek: Int = 3
    var preferredWorkoutMinutes: Int = 60
    var preferredRepRange: RepRangePreference = RepRangePreference.hypertrophy
    var preferredSplit: SplitType = SplitType.pushPullLegs
    var preferredTrainingSlots: [Int] = [0, 2, 4]  // Mon=0..Sun=6 weekday slots
    var weeklyTemplateIDs: [UUID] = []  // Ordered template IDs matching training day indices
    var customDayNames: [String] = []              // Custom split: day names
    var customDayMuscleGroups: [[String]] = []     // Custom split: MuscleGroup rawValues per day

    // Creatine tracking
    var trackCreatine: Bool = false
    var notifyCreatineReminder: Bool = true

    // Streak pause
    var streakPaused: Bool = false

    // Social
    var inviteCode: String?

    // Feed / social notification bookkeeping
    var lastFeedCheckDate: Date?
    var lastSeedCheckDate: Date?
    var lastNotifiedRootLevels: [String: String] = [:]  // friendID -> RootLevel.rawValue

    // Sharing preferences (defaults)
    var autoShareWorkouts: Bool = false
    var shareWorkoutName: Bool = true
    var shareDuration: Bool = true
    var shareExercises: Bool = false
    var shareWeights: Bool = false
    var sharePRs: Bool = true
    var shareProgram: Bool = true

    // Notification preferences
    var notifyWorkoutReminder: Bool = true
    var notifyStreakAtRisk: Bool = true
    var notifyFriendActivity: Bool = true
    var notifyPersonalRecord: Bool = true
    var notifyWeeklySummary: Bool = true
    var notifySeedReceived: Bool = true
    var notifyConnectionMilestone: Bool = true
    var notifyWateringReminder: Bool = true
    var preferredReminderHour: Int = 8      // 0-23, default 8 AM
    var preferredReminderMinute: Int = 0
    var preferredCreatineReminderHour: Int = 9   // default 9 AM
    var preferredCreatineReminderMinute: Int = 0
    var preferredEveningReminderHour: Int = 19   // default 7 PM (watering)
    var preferredEveningReminderMinute: Int = 0
    var quietHoursStart: Date?
    var quietHoursEnd: Date?

    // Streak tracking
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWorkoutDate: Date?
    var consecutiveRestDays: Int = 0

    // Plant state
    var previousStreak: Int = 0
    var lastSeenPlantStage: Int = 0
    var isStreakWilted: Bool = false
    var wiltedAtStage: Int = 0

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Workout.user)
    var workouts: [Workout] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkoutPlan.user)
    var plans: [WorkoutPlan] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.user)
    var customTemplates: [WorkoutTemplate] = []

    @Relationship(deleteRule: .cascade, inverse: \Exercise.createdBy)
    var customExercises: [Exercise] = []

    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.user)
    var personalRecords: [PersonalRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \Achievement.user)
    var achievements: [Achievement] = []

    @Relationship(deleteRule: .cascade, inverse: \CreatineLog.user)
    var creatineLogs: [CreatineLog] = []

    var onboardingCompletedAt: Date?
    var profileImageData: Data?

    var createdAt: Date = Date()

    init(
        appleUserID: String,
        fitnessGoal: FitnessGoal = .stayActive,
        experienceLevel: ExperienceLevel = .beginner,
        preferredUnits: UnitSystem = .imperial
    ) {
        self.appleUserID = appleUserID
        self.fitnessGoal = fitnessGoal
        self.experienceLevel = experienceLevel
        self.preferredUnits = preferredUnits
    }
}
