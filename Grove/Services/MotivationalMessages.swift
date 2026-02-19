import Foundation

struct MotivationalMessages {

    enum Category {
        case continuing
        case stageUp(stageName: String)
        case streakBroken
    }

    static func message(for category: Category) -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

        switch category {
        case .continuing:
            let messages = [
                "Another day, another leaf.",
                "Your roots are getting deeper!",
                "Growing stronger every day.",
                "Consistency is your superpower.",
                "Your grove is thriving!",
                "Keep watering your goals.",
            ]
            return messages[dayOfYear % messages.count]

        case .stageUp(let stageName):
            let messages = [
                "Your plant evolved into a \(stageName)!",
                "New growth unlocked: \(stageName)!",
                "Look at you bloom! Hello, \(stageName).",
                "From tiny seeds grow mighty trees. Welcome to \(stageName)!",
                "Level up! Your plant is now a \(stageName).",
            ]
            return messages[dayOfYear % messages.count]

        case .streakBroken:
            let messages = [
                "Every tree starts from a seed.",
                "Time to plant a new beginning.",
                "Rest is part of growth. Start again.",
                "New roots, new strength.",
                "The best time to plant was yesterday. The next best time is now.",
                "Even forests regrow after a storm.",
            ]
            return messages[dayOfYear % messages.count]
        }
    }
}
