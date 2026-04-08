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

    var icon: String {
        switch self {
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .legs: return "figure.run"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.walk"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum ExerciseStatus: String, Codable {
    case planned
    case inProgress
    case completed
    case skipped
}

enum BodyweightModifier: String, Codable {
    case none       // Standard weighted exercise (bench press, curls, etc.)
    case bodyweight // Pure bodyweight — reps only (push-ups, unweighted pull-ups)
    case weighted   // Bodyweight + added weight (weighted pull-ups, weighted dips)
    case assisted   // Bodyweight - assistance (band-assisted pull-ups, machine-assisted dips)
}

enum PlanStatus: String, Codable {
    case planned
    case completed
    case incomplete
    case rest
}

// MARK: - Smart Builder Enums

enum RepRangePreference: String, Codable, CaseIterable {
    case strength = "Strength"
    case hypertrophy = "Hypertrophy"
    case endurance = "Endurance"

    var subtitle: String {
        switch self {
        case .strength: return "3-5 reps"
        case .hypertrophy: return "8-12 reps"
        case .endurance: return "15+ reps"
        }
    }

    var description: String {
        switch self {
        case .strength: return "Heavier weight, longer rest"
        case .hypertrophy: return "Balanced for growth"
        case .endurance: return "Lighter weight, high volume"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .hypertrophy: return "flame.fill"
        case .endurance: return "heart.fill"
        }
    }

    var compoundSets: Int {
        switch self {
        case .strength: return 3
        case .hypertrophy: return 3
        case .endurance: return 3
        }
    }

    var compoundReps: Int {
        switch self {
        case .strength: return 5
        case .hypertrophy: return 10
        case .endurance: return 15
        }
    }

    var isolationSets: Int {
        switch self {
        case .strength: return 3
        case .hypertrophy: return 3
        case .endurance: return 3
        }
    }

    var isolationReps: Int {
        switch self {
        case .strength: return 8
        case .hypertrophy: return 12
        case .endurance: return 15
        }
    }
}

enum SplitType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case fullBody = "Full Body"
    case upperLower = "Upper / Lower"
    case pushPullLegs = "Push / Pull / Legs"
    case broSplit = "Bro Split"
    case arnoldSplit = "Arnold Split"
    case custom = "Custom"

    var validDayCounts: [Int] {
        switch self {
        case .fullBody: return [1, 2, 3]
        case .upperLower: return [2, 3, 4]
        case .pushPullLegs: return [3, 6]
        case .broSplit: return [5]
        case .arnoldSplit: return [5, 6]
        case .custom: return Array(1...6)
        }
    }

    func dayLabels(for dayCount: Int) -> [String] {
        switch self {
        case .fullBody:
            return Array(repeating: "Full Body", count: dayCount)
        case .upperLower:
            switch dayCount {
            case 2: return ["Upper", "Lower"]
            case 3: return ["Upper", "Lower", "Full Body"]
            case 4: return ["Upper", "Lower", "Upper", "Lower"]
            default: return []
            }
        case .pushPullLegs:
            switch dayCount {
            case 3: return ["Push", "Pull", "Legs"]
            case 6: return ["Push", "Pull", "Legs", "Push", "Pull", "Legs"]
            default: return []
            }
        case .broSplit:
            return ["Chest", "Back", "Shoulders", "Legs", "Arms"]
        case .arnoldSplit:
            switch dayCount {
            case 5: return ["Chest & Back", "Shoulders & Arms", "Legs", "Chest & Back", "Shoulders & Arms"]
            case 6: return ["Chest & Back", "Shoulders & Arms", "Legs", "Chest & Back", "Shoulders & Arms", "Legs"]
            default: return []
            }
        case .custom:
            return (1...dayCount).map { "Day \($0)" }
        }
    }

    func weekPreview(for dayCount: Int) -> String {
        let labels = dayLabels(for: dayCount)
        return labels.joined(separator: " · ")
    }

    /// Returns the muscle groups to train on a given day label
    static func muscleGroups(for dayLabel: String) -> [MuscleGroup] {
        switch dayLabel {
        case "Push": return [.chest, .shoulders, .triceps]
        case "Pull": return [.back, .biceps]
        case "Legs": return [.legs, .core]
        case "Upper": return [.chest, .back, .shoulders, .biceps, .triceps]
        case "Lower": return [.legs, .core]
        case "Full Body": return [.chest, .back, .shoulders, .legs, .biceps, .triceps]
        case "Chest": return [.chest, .triceps]
        case "Back": return [.back, .biceps]
        case "Shoulders": return [.shoulders]
        case "Arms": return [.biceps, .triceps]
        case "Chest & Back": return [.chest, .back]
        case "Shoulders & Arms": return [.shoulders, .biceps, .triceps]
        default: return [.chest, .back, .shoulders, .legs]
        }
    }
}

// MARK: - Achievements

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

    var shortLabel: String {
        switch self {
        case .firstRep: return "1st"
        case .weekWarrior: return "7day"
        case .consistent: return "50"
        case .prCrusher: return "PR"
        case .planner: return "Plan"
        case .centuryClub: return "100"
        case .ironWill: return "30d"
        }
    }
}
