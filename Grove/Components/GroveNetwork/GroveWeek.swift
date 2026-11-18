import Foundation

/// How someone's week is going: workouts so far (Monday first, like the rest of the app)
/// against the days per week they're aiming for. Shown as goal dots under each name in
/// the grove strip.
struct GroveWeekProgress: Equatable {
    let trained: Int
    /// Days per week they're aiming for; nil when they don't share their program.
    let target: Int?

    var reachedGoal: Bool { target.map { trained >= $0 } ?? false }

    /// Workouts on distinct days this week among `dates`.
    init(dates: [Date], target: Int?, now: Date = Date(), calendar: Calendar = .current) {
        let start = Self.weekStart(for: now, calendar: calendar)
        let days = Set(dates.filter { $0 >= start && $0 <= now }.map { calendar.startOfDay(for: $0) })
        self.trained = days.count
        self.target = target
    }

    /// Midnight on the Monday of the week containing `date`.
    static func weekStart(for date: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        let mondayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        return calendar.date(byAdding: .day, value: -mondayIndex, to: today) ?? today
    }
}
