import Foundation

enum PlantStage: Int, Codable, CaseIterable, Comparable {
    case seed = 0
    case sprout = 1
    case seedling = 2
    case youngPlant = 3
    case bush = 4
    case floweringBush = 5
    case sapling = 6
    case youngTree = 7
    case tree = 8
    case groveTree = 9

    static func < (lhs: PlantStage, rhs: PlantStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var minStreak: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 1
        case .seedling: return 3
        case .youngPlant: return 7
        case .bush: return 14
        case .floweringBush: return 21
        case .sapling: return 30
        case .youngTree: return 45
        case .tree: return 60
        case .groveTree: return 100
        }
    }

    var displayName: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .seedling: return "Seedling"
        case .youngPlant: return "Young Plant"
        case .bush: return "Bush"
        case .floweringBush: return "Flowering Bush"
        case .sapling: return "Sapling"
        case .youngTree: return "Young Tree"
        case .tree: return "Tree"
        case .groveTree: return "Grove Tree"
        }
    }

    var nextStage: PlantStage? {
        PlantStage(rawValue: rawValue + 1)
    }

    var showsSoil: Bool {
        rawValue <= 2
    }

    static func from(streak: Int) -> PlantStage {
        // Walk backwards through cases to find highest matching stage
        for stage in allCases.reversed() {
            if streak >= stage.minStreak {
                return stage
            }
        }
        return .seed
    }

    func daysUntilNext(currentStreak: Int) -> Int? {
        guard let next = nextStage else { return nil }
        return max(0, next.minStreak - currentStreak)
    }

    func progressToNext(currentStreak: Int) -> Double {
        guard let next = nextStage else { return 1.0 }
        let range = next.minStreak - minStreak
        guard range > 0 else { return 1.0 }
        let progress = Double(currentStreak - minStreak) / Double(range)
        return min(max(progress, 0), 1.0)
    }
}
