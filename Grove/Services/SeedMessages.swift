import Foundation

struct SeedMessages {

    enum Context {
        case general
        case personalRecord
        case longWorkout      // > 60 min
        case highStreak       // streak > 7
        case earlyMorning     // before 8 AM
        case lateNight        // after 9 PM
        case comeback         // first workout after a break
    }

    /// Determines the best context for a shared workout item
    static func contextFor(item: SharedWorkoutItem) -> Context {
        let hour = Calendar.current.component(.hour, from: item.completedAt)

        if item.hasPRs {
            return .personalRecord
        }
        if hour < 8 {
            return .earlyMorning
        }
        if hour >= 21 {
            return .lateNight
        }
        if item.duration > 3600 {
            return .longWorkout
        }
        return .general
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
            ]

        case .longWorkout:
            return [
                "That dedication is contagious",
                "Marathon session, marathon results",
                "Putting in the work",
                "Nothing stops you",
                "That's commitment",
                "Iron will",
            ]

        case .highStreak:
            return [
                "The streak speaks for itself",
                "Unstoppable",
                "Consistency king",
                "Your grove is thriving",
                "Building something great",
                "Day after day",
            ]

        case .earlyMorning:
            return [
                "Up before the sun",
                "Morning grind hits different",
                "Early bird gets the gains",
                "While the world sleeps",
                "Dawn patrol",
                "Starting the day right",
            ]

        case .lateNight:
            return [
                "Burning the midnight oil",
                "No excuses, any hour",
                "Night owl gains",
                "Getting it done no matter what",
                "Late night dedication",
                "The gym never closes for you",
            ]

        case .comeback:
            return [
                "Welcome back",
                "Every garden needs rain to grow",
                "The comeback is always stronger",
                "Back at it",
                "New roots, new strength",
                "Picking up where you left off",
            ]
        }
    }

    /// Returns a rotating subset of suggested messages for the seed picker
    static func suggestions(for item: SharedWorkoutItem, count: Int = 4) -> [String] {
        let context = contextFor(item: item)
        let contextMessages = messages(for: context)
        let generalMessages = messages(for: .general)

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let itemHash = item.id.hashValue

        // Pick from context-specific messages first, then fill with general
        var result: [String] = []
        let seed = abs(dayOfYear &+ itemHash)

        for i in 0..<min(count, contextMessages.count) {
            let index = (seed + i) % contextMessages.count
            let msg = contextMessages[index]
            if !result.contains(msg) {
                result.append(msg)
            }
        }

        // Fill remaining slots from general if needed
        if result.count < count {
            for i in 0..<generalMessages.count {
                if result.count >= count { break }
                let msg = generalMessages[(seed + i) % generalMessages.count]
                if !result.contains(msg) {
                    result.append(msg)
                }
            }
        }

        return Array(result.prefix(count))
    }
}
