import Foundation

// MARK: - Interaction Type

enum InteractionType: String, Codable, CaseIterable, Sendable {
    case water
    case sunlight
    case seed

    var connectionWeight: Int {
        switch self {
        case .water: return 1
        case .seed: return 2
        case .sunlight: return 3
        }
    }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .sunlight: return "sun.max.fill"
        case .seed: return "leaf.fill"
        }
    }
}

// MARK: - Root Connection Level

enum RootLevel: String, CaseIterable, Sendable {
    case scattered = "Scattered Roots"
    case growing = "Growing Roots"
    case intertwined = "Intertwined"
    case deep = "Deep Roots"

    static func from(score: Int) -> RootLevel {
        switch score {
        case 0...15: return .scattered
        case 16...40: return .growing
        case 41...80: return .intertwined
        default: return .deep
        }
    }

    var minScore: Int {
        switch self {
        case .scattered: return 0
        case .growing: return 16
        case .intertwined: return 41
        case .deep: return 81
        }
    }

    var maxScore: Int {
        switch self {
        case .scattered: return 15
        case .growing: return 40
        case .intertwined: return 80
        case .deep: return Int.max
        }
    }

    var nextLevel: RootLevel? {
        switch self {
        case .scattered: return .growing
        case .growing: return .intertwined
        case .intertwined: return .deep
        case .deep: return nil
        }
    }

    var icon: String {
        switch self {
        case .scattered: return "line.3.horizontal"
        case .growing: return "arrow.triangle.branch"
        case .intertwined: return "point.3.connected.trianglepath.dotted"
        case .deep: return "tree.fill"
        }
    }
}

// MARK: - Interaction Summary (per workout post)

struct InteractionSummary: Sendable {
    let workoutRecordName: String
    var waterCount: Int
    var sunlightCount: Int
    var seeds: [SeedMessage]
    var iWatered: Bool
    var iSunlit: Bool
    var waterers: [InteractorInfo]
    var sunlighters: [SunlightInfo]

    /// Most recent water interaction date (for shimmer expiry)
    var latestWaterDate: Date?
    /// Most recent sunlight interaction date (for glow expiry)
    var latestSunlightDate: Date?

    static func empty(for workoutRecordName: String) -> InteractionSummary {
        InteractionSummary(
            workoutRecordName: workoutRecordName,
            waterCount: 0,
            sunlightCount: 0,
            seeds: [],
            iWatered: false,
            iSunlit: false,
            waterers: [],
            sunlighters: [],
            latestWaterDate: nil,
            latestSunlightDate: nil
        )
    }

    /// Whether the water shimmer effect should still be visible
    var isWaterShimmerActive: Bool {
        guard let date = latestWaterDate else { return false }
        let endOfNextDay = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: date))!
        return Date() < endOfNextDay
    }

    /// Visual growth state for the evolving card background
    var growthState: CardGrowthState {
        CardGrowthState(from: self)
    }

    /// Whether the sunlight glow effect should still be visible
    var isSunlightGlowActive: Bool {
        guard let date = latestSunlightDate else { return false }
        let endOfNextDay = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: date))!
        return Date() < endOfNextDay
    }
}

// MARK: - Seed Message

struct SeedMessage: Identifiable, Sendable {
    let id: String // CKRecord.recordName
    let senderID: String
    let senderName: String
    let senderProfileImageData: Data?
    let message: String
    let isCustom: Bool
    let createdAt: Date

    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }
}

// MARK: - Sunlight Info

struct SunlightInfo: Sendable {
    let senderID: String
    let senderName: String
    let senderProfileImageData: Data?
    let earnedFromWorkoutName: String?
}

// MARK: - Interactor Info

struct InteractorInfo: Sendable {
    let userID: String
    let displayName: String
    let profileImageData: Data?
}

// MARK: - Root Connection

struct RootConnection: Identifiable, Sendable {
    let friendID: String
    let friendName: String
    let friendProfileImageData: Data?
    let score: Int

    var id: String { friendID }
    var level: RootLevel { RootLevel.from(score: score) }

    var progressToNextLevel: Double {
        guard let next = level.nextLevel else { return 1.0 }
        let range = Double(next.minScore - level.minScore)
        let progress = Double(score - level.minScore)
        return min(progress / range, 1.0)
    }
}

// MARK: - Interaction Breakdown (between two users)

struct InteractionBreakdown: Sendable {
    let friendID: String
    let friendName: String
    let friendProfileImageData: Data?
    var watersSent: Int = 0
    var watersReceived: Int = 0
    var seedsSent: Int = 0
    var seedsReceived: Int = 0
    var sunlightsSent: Int = 0
    var sunlightsReceived: Int = 0

    var totalScore: Int {
        let waterScore = (watersSent + watersReceived) * InteractionType.water.connectionWeight
        let seedScore = (seedsSent + seedsReceived) * InteractionType.seed.connectionWeight
        let sunlightScore = (sunlightsSent + sunlightsReceived) * InteractionType.sunlight.connectionWeight
        return waterScore + seedScore + sunlightScore
    }

    var level: RootLevel { RootLevel.from(score: totalScore) }
}

// MARK: - Feed Mode

enum FeedMode: String, CaseIterable {
    case canopy = "Canopy"
    case soil = "Soil"
}
