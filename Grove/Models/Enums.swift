import Foundation

enum FitnessGoal: String, Codable, CaseIterable {
    case buildMuscle = "Build Muscle"
    case loseWeight = "Lose Weight"
    case stayActive = "Stay Active"
    case trainForEvent = "Train for Event"
}

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum UnitSystem: String, Codable, CaseIterable {
    case imperial = "Imperial (lbs)"
    case metric = "Metric (kg)"
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
}

enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case upper = "Upper"
    case lower = "Lower"
    case fullBody = "Full Body"
    case chestTriceps = "Chest & Triceps"
    case backBiceps = "Back & Biceps"
    case shoulders = "Shoulders"
    case custom = "Custom"
}

enum ExerciseStatus: String, Codable {
    case planned
    case inProgress
    case completed
    case skipped
}

enum PlanStatus: String, Codable {
    case planned
    case completed
    case incomplete
    case rest
}

enum AchievementType: String, Codable, CaseIterable {
    case firstRep = "First Rep"
    case weekWarrior = "Week Warrior"
    case consistent = "Consistent"
    case prCrusher = "PR Crusher"
    case planner = "Planner"
    case centuryClub = "Century Club"
    case ironWill = "Iron Will"

    var description: String {
        switch self {
        case .firstRep: return "Log your first workout"
        case .weekWarrior: return "Achieve a 7-day streak"
        case .consistent: return "Log 50 workouts"
        case .prCrusher: return "Set a personal record"
        case .planner: return "Complete a full planned week"
        case .centuryClub: return "Log 100 workouts"
        case .ironWill: return "Achieve a 30-day streak"
        }
    }

    var icon: String {
        switch self {
        case .firstRep: return "leaf.fill"
        case .weekWarrior: return "flame.fill"
        case .consistent: return "calendar"
        case .prCrusher: return "trophy.fill"
        case .planner: return "checkmark.calendar"
        case .centuryClub: return "medal.fill"
        case .ironWill: return "mountain.2.fill"
        }
    }
}
