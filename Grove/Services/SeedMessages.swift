import Foundation

/// Suggested seed messages. Every message must fit the 60-character seed limit.
struct SeedMessages {

    enum Context {
        case general
        case personalRecord
        case longWorkout      // > 60 min
        case shortWorkout     // < 30 min
        case earlyMorning     // before 8 AM
        case lateNight        // after 9 PM
        case weekend
        // Workout type, from the post's template category
        case legDay
        case upperBody        // push, chest & triceps, shoulders, upper
        case pullDay          // pull, back & biceps
        case fullBody
    }

    /// Every context that applies to a post, most specific first.
    static func contextsFor(item: SharedWorkoutItem) -> [Context] {
        var contexts: [Context] = []
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: item.completedAt)

        if item.hasPRs { contexts.append(.personalRecord) }

        switch item.templateCategory.flatMap(TemplateCategory.init(rawValue:)) {
        case .legs, .lower: contexts.append(.legDay)
        case .push, .chestTriceps, .shoulders, .upper: contexts.append(.upperBody)
        case .pull, .backBiceps: contexts.append(.pullDay)
        case .fullBody: contexts.append(.fullBody)
        case .custom, nil: break
        }

        if hour < 8 { contexts.append(.earlyMorning) }
        if hour >= 21 { contexts.append(.lateNight) }
        if item.duration > 3600 { contexts.append(.longWorkout) }
        if item.duration > 0 && item.duration < 1800 { contexts.append(.shortWorkout) }
        if calendar.isDateInWeekend(item.completedAt) { contexts.append(.weekend) }

        return contexts
    }

    /// Kept for callers that want the single best context.
    static func contextFor(item: SharedWorkoutItem) -> Context {
        contextsFor(item: item).first ?? .general
    }

    /// Returns curated messages for a given context
    static func messages(for context: Context) -> [String] {
        switch context {
        case .general:
            return [
                "Rooting for you",
                "Growing stronger together",
                "That's how it's done",
                "Keep showing up",
                "Consistency looks good on you",
                "Another day, another rep",
                "You make it look easy",
                "Inspiring as always",
                "Proud of you",
                "Love to see it",
                "One more for the grove",
                "Showing up is the hard part",
                "Quietly putting in the work",
                "Keep that momentum going",
                "You're on a roll",
                "Solid session",
                "This is how habits are built",
                "Strong work today",
                "Making it look routine",
                "Future you says thanks",
                "Getting after it",
                "Way to keep it going",
                "Fuel for the rest of the week",
                "Nice work, seriously",
            ]

        case .personalRecord:
            return [
                "New heights!",
                "Stronger than yesterday",
                "That PR was earned",
                "Breaking barriers",
                "Beast mode unlocked",
                "The work is paying off",
                "You just leveled up",
                "PR machine",
                "New personal best!",
                "Raising the bar, literally",
                "Months of work in one lift",
                "The numbers don't lie",
                "That's a new ceiling",
                "Who's stronger now?",
                "Write that one down",
                "The grind shows",
            ]

        case .longWorkout:
            return [
                "That dedication is contagious",
                "Marathon session, marathon results",
                "Putting in the work",
                "Nothing stops you",
                "That's commitment",
                "Iron will",
                "Long one today!",
                "Every minute counted",
                "Stamina for days",
                "Hope you refuel well",
            ]

        case .shortWorkout:
            return [
                "Short and sweet still counts",
                "Quick one, still a win",
                "Every session counts",
                "Efficient and effective",
                "Squeezed it in. Respect",
                "Something beats nothing",
                "In and out, done",
                "Busy day, still showed up",
            ]

        case .earlyMorning:
            return [
                "Up before the sun",
                "Morning grind hits different",
                "Early bird gets the gains",
                "While the world sleeps",
                "Dawn patrol",
                "Starting the day right",
                "Done before breakfast",
                "Coffee earned",
                "Rest of the day is a bonus",
                "Morning person energy",
            ]

        case .lateNight:
            return [
                "Burning the midnight oil",
                "No excuses, any hour",
                "Night owl gains",
                "Getting it done no matter what",
                "Late night dedication",
                "The gym never closes for you",
                "Long day, still showed up",
                "Sleep well, you earned it",
                "Finishing the day strong",
            ]

        case .weekend:
            return [
                "Weekend warrior",
                "No days off energy",
                "Weekend well spent",
                "Training while others rest",
                "Saturday strength",
                "Making the weekend count",
            ]

        case .legDay:
            return [
                "Never skip leg day",
                "Stairs are going to be fun",
                "Legs of steel",
                "Leg day done. Respect",
                "Good luck walking tomorrow",
                "Building from the ground up",
                "Strong roots, strong legs",
            ]

        case .upperBody:
            return [
                "Pushing limits",
                "Sleeves getting tighter",
                "Pressing on",
                "Solid push session",
                "Shoulders looking sharp",
                "Upper body on point",
            ]

        case .pullDay:
            return [
                "Pulling your weight",
                "Strong back, strong everything",
                "Grip strength unlocked",
                "Wings getting wider",
                "Solid pull day",
                "Posture goals",
            ]

        case .fullBody:
            return [
                "Everything got worked",
                "Head to toe strong",
                "Full body, full effort",
                "Nothing left out",
                "Total package",
                "All-around strong",
            ]
        }
    }

    /// Suggested messages for the seed picker: a mix of messages for this post's specific
    /// contexts (PR, leg day, early morning…) and general ones, so the list varies.
    /// `shuffle` changes the selection; the same post and shuffle give the same list.
    static func suggestions(for item: SharedWorkoutItem, count: Int = 6, shuffle: Int = 0) -> [String] {
        var generator = SeededGenerator(seed: stableHash(item.id) &+ UInt64(truncatingIfNeeded: shuffle) &* 0x9E3779B97F4A7C15)

        // Up to two from each specific context, most specific first, then general.
        var result: [String] = []
        for context in contextsFor(item: item) {
            for message in messages(for: context).shuffled(using: &generator).prefix(2)
            where !result.contains(message) && result.count < count - 2 {
                result.append(message)
            }
        }
        for message in messages(for: .general).shuffled(using: &generator)
        where !result.contains(message) && result.count < count {
            result.append(message)
        }
        return result
    }

    /// FNV-1a: stable across launches, unlike `hashValue`.
    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x2545F4914F6CDD1D : seed }
        mutating func next() -> UInt64 {
            // xorshift64*
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 0x2545F4914F6CDD1D
        }
    }
}
