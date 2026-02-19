import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var appleUserID: String
    var displayName: String?
    var fitnessGoal: FitnessGoal
    var experienceLevel: ExperienceLevel
    var preferredUnits: UnitSystem

    // Vacation mode
    var vacationModeEnabled: Bool = false
    var vacationStartDate: Date?
    var vacationEndDate: Date?

    // Sharing preferences (defaults)
    var shareWorkoutName: Bool = true
    var shareDuration: Bool = true
    var shareExercises: Bool = false
    var shareWeights: Bool = false

    // Notification preferences
    var notifyWorkoutReminder: Bool = true
    var notifyStreakAtRisk: Bool = true
    var notifyFriendActivity: Bool = true
    var notifyPersonalRecord: Bool = true
    var notifyWeeklySummary: Bool = true
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
