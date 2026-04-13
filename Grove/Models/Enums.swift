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
    // Workout milestones
    case firstRep = "First Rep"
    case tenDown = "Ten Down"
    case quarterCentury = "Quarter Century"
    case consistent = "Consistent"
    case centuryClub = "Century Club"
    case dedicated = "Dedicated"

    // Streak milestones
    case threePeat = "Three-Peat"
    case weekWarrior = "Week Warrior"
    case fortnight = "Fortnight"
    case ironWill = "Iron Will"
    case legendary = "Legendary"
    case unstoppable = "Unstoppable"

    // Personal records
    case prCrusher = "PR Crusher"
    case prCollector = "PR Collector"
    case prMachine = "PR Machine"

    // Variety & planning
    case explorer = "Explorer"
    case wellRounded = "Well-Rounded"
    case planner = "Planner"

    // Special
    case earlyBird = "Early Bird"
    case nightOwl = "Night Owl"
    case marathoner = "Marathoner"
    case socializer = "Socializer"
    case volumeKing = "Volume King"
    case creatineCommit = "Supplement Streak"
    case customCreator = "Custom Creator"

    var description: String {
        switch self {
        case .firstRep: return "Log your first workout"
        case .tenDown: return "Complete 10 workouts"
        case .quarterCentury: return "Complete 25 workouts"
        case .consistent: return "Log 50 workouts"
        case .centuryClub: return "Log 100 workouts"
        case .dedicated: return "Log 200 workouts"
        case .threePeat: return "Achieve a 3-day streak"
        case .weekWarrior: return "Achieve a 7-day streak"
        case .fortnight: return "Achieve a 14-day streak"
        case .ironWill: return "Achieve a 30-day streak"
        case .legendary: return "Achieve a 60-day streak"
        case .unstoppable: return "Achieve a 100-day streak"
        case .prCrusher: return "Set a personal record"
        case .prCollector: return "Set PRs on 5 different exercises"
        case .prMachine: return "Set PRs on 10 different exercises"
        case .explorer: return "Log 10 different exercises"
        case .wellRounded: return "Train 6 different muscle groups"
        case .planner: return "Complete a full planned week"
        case .earlyBird: return "Complete a workout before 8 AM"
        case .nightOwl: return "Complete a workout after 9 PM"
        case .marathoner: return "Complete a workout over 90 minutes"
        case .socializer: return "Share a workout with friends"
        case .volumeKing: return "Complete 1,000 total sets"
        case .creatineCommit: return "Log creatine 30 times"
        case .customCreator: return "Create a custom exercise"
        }
    }

    var icon: String {
        switch self {
        case .firstRep: return "leaf.fill"
        case .tenDown: return "figure.strengthtraining.traditional"
        case .quarterCentury: return "dumbbell.fill"
        case .consistent: return "calendar"
        case .centuryClub: return "medal.fill"
        case .dedicated: return "heart.circle.fill"
        case .threePeat: return "bolt.fill"
        case .weekWarrior: return "flame.fill"
        case .fortnight: return "clock.badge.checkmark"
        case .ironWill: return "mountain.2.fill"
        case .legendary: return "crown.fill"
        case .unstoppable: return "infinity"
        case .prCrusher: return "trophy.fill"
        case .prCollector: return "star.fill"
        case .prMachine: return "seal.fill"
        case .explorer: return "map.fill"
        case .wellRounded: return "figure.mixed.cardio"
        case .planner: return "calendar.badge.checkmark"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .marathoner: return "timer"
        case .socializer: return "square.and.arrow.up.fill"
        case .volumeKing: return "scalemass.fill"
        case .creatineCommit: return "pill.fill"
        case .customCreator: return "plus.circle.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .firstRep: return "1st"
        case .tenDown: return "10"
        case .quarterCentury: return "25"
        case .consistent: return "50"
        case .centuryClub: return "100"
        case .dedicated: return "200"
        case .threePeat: return "3x"
        case .weekWarrior: return "7d"
        case .fortnight: return "14d"
        case .ironWill: return "30d"
        case .legendary: return "60d"
        case .unstoppable: return "100d"
        case .prCrusher: return "PR"
        case .prCollector: return "5PR"
        case .prMachine: return "10PR"
        case .explorer: return "10ex"
        case .wellRounded: return "All"
        case .planner: return "Plan"
        case .earlyBird: return "AM"
        case .nightOwl: return "PM"
        case .marathoner: return "90m"
        case .socializer: return "Share"
        case .volumeKing: return "1K"
        case .creatineCommit: return "Supp"
        case .customCreator: return "New"
        }
    }

    var category: String {
        switch self {
        case .firstRep, .tenDown, .quarterCentury, .consistent, .centuryClub, .dedicated:
            return "Workout Milestones"
        case .threePeat, .weekWarrior, .fortnight, .ironWill, .legendary, .unstoppable:
            return "Streak Milestones"
        case .prCrusher, .prCollector, .prMachine:
            return "Personal Records"
        case .explorer, .wellRounded, .planner:
            return "Variety & Planning"
        case .earlyBird, .nightOwl, .marathoner, .socializer, .volumeKing, .creatineCommit, .customCreator:
            return "Special"
        }
    }

    static let categoryOrder = [
        "Workout Milestones",
        "Streak Milestones",
        "Personal Records",
        "Variety & Planning",
        "Special"
    ]
}
