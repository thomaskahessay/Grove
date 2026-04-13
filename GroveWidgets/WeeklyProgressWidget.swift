import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Entry

enum DayDotStatus {
    case completed
    case planned
    case rest
    case today
    case todayDone
}

struct DayStatus {
    let letter: String
    let status: DayDotStatus
    let categoryIcon: String?  // SF Symbol from TemplateCategory
    let workoutName: String?   // e.g. "Push", "Upper A"
}

struct WeeklyProgressEntry: TimelineEntry {
    let date: Date
    let completedCount: Int
    let goalCount: Int
    let dayStatuses: [DayStatus]

    var progress: Double {
        guard goalCount > 0 else { return 0 }
        return min(Double(completedCount) / Double(goalCount), 1.0)
    }

    var remaining: Int {
        max(0, goalCount - completedCount)
    }

    static let placeholder = WeeklyProgressEntry(
        date: .now,
        completedCount: 3,
        goalCount: 5,
        dayStatuses: [
            DayStatus(letter: "M", status: .completed, categoryIcon: "arrow.up.circle", workoutName: "Push"),
            DayStatus(letter: "T", status: .rest, categoryIcon: nil, workoutName: nil),
            DayStatus(letter: "W", status: .completed, categoryIcon: "arrow.down.circle", workoutName: "Pull"),
            DayStatus(letter: "T", status: .rest, categoryIcon: nil, workoutName: nil),
            DayStatus(letter: "F", status: .completed, categoryIcon: "figure.run", workoutName: "Legs"),
            DayStatus(letter: "S", status: .today, categoryIcon: "arrow.up.circle", workoutName: "Push"),
            DayStatus(letter: "S", status: .planned, categoryIcon: nil, workoutName: nil),
        ]
    )

    static let empty = WeeklyProgressEntry(
        date: .now,
        completedCount: 0,
        goalCount: 3,
        dayStatuses: defaultDayStatuses()
    )

    private static func defaultDayStatuses() -> [DayStatus] {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return letters.map { DayStatus(letter: $0, status: .rest, categoryIcon: nil, workoutName: nil) }
    }
}

// MARK: - Provider

struct WeeklyProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyProgressEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyProgressEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyProgressEntry>) -> Void) {
        let entry = fetchEntry()
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func fetchEntry() -> WeeklyProgressEntry {
        do {
            let container = try SharedModelContainer.makeContainer()
            let context = ModelContext(container)

            guard let user = try context.fetch(FetchDescriptor<User>()).first else {
                return .empty
            }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)

            // Find Monday of current week (locale-independent)
            // Calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat → convert to Mon=0, Tue=1, ..., Sun=6
            let weekday = calendar.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

            // Get all completed workouts this week
            let allWorkouts = try context.fetch(FetchDescriptor<Workout>())
            let weekWorkouts = allWorkouts.filter { workout in
                guard let completedAt = workout.completedAt else { return false }
                let completedDay = calendar.startOfDay(for: completedAt)
                return completedDay >= monday && completedDay <= today
            }

            // Get plans for the week
            let allPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!

            // Training slots (0=Mon..6=Sun)
            let trainingSlots = Set(user.preferredTrainingSlots)

            // Build day statuses
            let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
            var dayStatuses: [DayStatus] = []

            for dayOffset in 0..<7 {
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
                let letter = dayLetters[dayOffset]
                let isToday = calendar.isDate(dayDate, inSameDayAs: today)

                // Check if workout was completed on this day
                let completedOnDay = weekWorkouts.contains { workout in
                    guard let completedAt = workout.completedAt else { return false }
                    return calendar.isDate(completedAt, inSameDayAs: dayDate)
                }

                // Check if there's a plan for this day
                let planForDay = allPlans.first { calendar.isDate($0.date, inSameDayAs: dayDate) }
                let isTrainingDay = trainingSlots.contains(dayOffset) || (planForDay != nil && !planForDay!.isRestDay)

                // Get template info for this day
                let categoryIcon = planForDay?.template?.category.icon
                let workoutName = planForDay?.template?.name

                let status: DayDotStatus
                if isToday && completedOnDay {
                    status = .todayDone
                } else if isToday {
                    status = .today
                } else if completedOnDay {
                    status = .completed
                } else if dayDate > today && isTrainingDay {
                    status = .planned
                } else {
                    status = .rest
                }

                dayStatuses.append(DayStatus(letter: letter, status: status, categoryIcon: categoryIcon, workoutName: workoutName))
            }

            return WeeklyProgressEntry(
                date: .now,
                completedCount: weekWorkouts.count,
                goalCount: user.preferredDaysPerWeek,
                dayStatuses: dayStatuses
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Views

struct WeeklyProgressWidgetView: View {
    var entry: WeeklyProgressEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(spacing: 0) {
            // Count header
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(entry.completedCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.groveSage)
                    Text("/\(entry.goalCount)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.groveTextSecondary)
                }
                Text("workouts")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.groveTextSecondary)
            }

            Spacer()

            // Day row fills width
            HStack(spacing: 0) {
                ForEach(Array(entry.dayStatuses.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 4) {
                        Text(day.letter)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(dayLabelColor(day.status))
                        dayCircleView(day, size: 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
    }

    // MARK: Medium

    private var mediumView: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(alignment: .firstTextBaseline) {
                Text("This Week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.groveText)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.completedCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.groveSage)
                    Text("/\(entry.goalCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }

            Spacer()

            // Day columns — fill available width
            HStack(spacing: 0) {
                ForEach(Array(entry.dayStatuses.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        Text(day.letter)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(dayLabelColor(day.status))
                        dayCircleView(day, size: 28)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer()

            // Progress bar + text
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.groveWarmSand.opacity(0.5))
                        Capsule()
                            .fill(Color.groveSage)
                            .frame(width: max(geo.size.width * entry.progress, entry.progress > 0 ? 8 : 0))
                    }
                }
                .frame(height: 6)

                Text(motivationalText)
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: Large

    private var largeView: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("This Week")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.completedCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.groveSage)
                    Text("/\(entry.goalCount)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }

            // Day columns — fill available height
            HStack(spacing: 6) {
                ForEach(Array(entry.dayStatuses.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 8) {
                        Text(day.letter)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(dayLabelColor(day.status))

                        // Tall pill fills remaining height
                        RoundedRectangle(cornerRadius: 10)
                            .fill(dayPillColor(day.status))
                            .frame(maxHeight: .infinity)
                            .overlay {
                                VStack(spacing: 6) {
                                    if day.status == .completed || day.status == .todayDone {
                                        Image(systemName: day.categoryIcon ?? "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    } else if day.status == .today {
                                        if let icon = day.categoryIcon {
                                            Image(systemName: icon)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(Color.groveTerracotta)
                                        } else {
                                            Circle()
                                                .fill(Color.groveTerracotta)
                                                .frame(width: 8, height: 8)
                                        }
                                    } else if day.status == .planned {
                                        if let icon = day.categoryIcon {
                                            Image(systemName: icon)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.groveSage.opacity(0.6))
                                        }
                                    }
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Bottom motivational text
            Text(motivationalText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.groveTerracotta)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: Helpers

    private func dayCircleView(_ day: DayStatus, size: CGFloat) -> some View {
        ZStack {
            switch day.status {
            case .completed:
                Circle().fill(Color.groveSage)
                if let icon = day.categoryIcon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                }
            case .todayDone:
                Circle().fill(Color.groveTerracotta)
                if let icon = day.categoryIcon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                }
            case .today:
                Circle().fill(Color.groveTerracotta.opacity(0.15))
                if let icon = day.categoryIcon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(Color.groveTerracotta)
                } else {
                    Circle()
                        .fill(Color.groveTerracotta)
                        .frame(width: size * 0.3, height: size * 0.3)
                }
            case .planned:
                Circle().fill(Color.groveSage.opacity(0.15))
                if let icon = day.categoryIcon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(Color.groveSage.opacity(0.7))
                } else {
                    Circle()
                        .stroke(Color.groveSage.opacity(0.5), lineWidth: 1.5)
                        .frame(width: size * 0.45, height: size * 0.45)
                }
            case .rest:
                Circle().fill(Color.groveWarmSand.opacity(0.35))
            }
        }
        .frame(width: size, height: size)
    }

    private func dayLabelColor(_ status: DayDotStatus) -> Color {
        switch status {
        case .completed, .todayDone: return Color.groveText
        case .today: return Color.groveTerracotta
        case .planned: return Color.groveTextSecondary
        case .rest: return Color.groveTextSecondary.opacity(0.6)
        }
    }

    private func dayPillColor(_ status: DayDotStatus) -> Color {
        switch status {
        case .completed: return Color.groveSage
        case .todayDone: return Color.groveTerracotta
        case .today: return Color.groveTerracotta.opacity(0.15)
        case .planned: return Color.groveSage.opacity(0.12)
        case .rest: return Color.groveWarmSand.opacity(0.25)
        }
    }

    private var motivationalText: String {
        if entry.completedCount >= entry.goalCount {
            return "Goal reached! Great week!"
        } else if entry.remaining == 1 {
            return "1 more workout to hit your goal!"
        } else {
            return "\(entry.remaining) more to hit your goal"
        }
    }
}

// MARK: - Widget

struct WeeklyProgressWidget: Widget {
    let kind = "WeeklyProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyProgressProvider()) { entry in
            WeeklyProgressWidgetView(entry: entry)
                .containerBackground(Color.groveBackground, for: .widget)
        }
        .configurationDisplayName("Weekly Progress")
        .description("Track your workouts completed this week.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    WeeklyProgressWidget()
} timeline: {
    WeeklyProgressEntry.placeholder
}

#Preview(as: .systemMedium) {
    WeeklyProgressWidget()
} timeline: {
    WeeklyProgressEntry.placeholder
}

#Preview(as: .systemLarge) {
    WeeklyProgressWidget()
} timeline: {
    WeeklyProgressEntry.placeholder
}
