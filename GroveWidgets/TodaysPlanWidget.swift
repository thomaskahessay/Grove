import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Entry

enum TodayPlanState {
    case workout(name: String, exerciseCount: Int, categoryIcon: String, isCompleted: Bool)
    case restDay
    case noPlan
}

struct TodaysPlanEntry: TimelineEntry {
    let date: Date
    let planState: TodayPlanState
    let tomorrowName: String?

    static let placeholder = TodaysPlanEntry(
        date: .now,
        planState: .workout(name: "Push Day", exerciseCount: 6, categoryIcon: "arrow.up.circle", isCompleted: false),
        tomorrowName: "Pull Day"
    )

    static let empty = TodaysPlanEntry(
        date: .now,
        planState: .noPlan,
        tomorrowName: nil
    )
}

// MARK: - Provider

struct TodaysPlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysPlanEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysPlanEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysPlanEntry>) -> Void) {
        let entry = fetchEntry()
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func fetchEntry() -> TodaysPlanEntry {
        do {
            let container = try SharedModelContainer.makeContainer()
            let context = ModelContext(container)

            let today = Calendar.current.startOfDay(for: .now)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

            let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
            let todaysPlan = plans.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            let tomorrowsPlan = plans.first { Calendar.current.isDate($0.date, inSameDayAs: tomorrow) }

            let tomorrowName: String? = {
                guard let plan = tomorrowsPlan, !plan.isRestDay else { return nil }
                return plan.template?.name
            }()

            guard let plan = todaysPlan else {
                return TodaysPlanEntry(date: .now, planState: .noPlan, tomorrowName: tomorrowName)
            }

            if plan.isRestDay {
                return TodaysPlanEntry(date: .now, planState: .restDay, tomorrowName: tomorrowName)
            }

            let name = plan.template?.name ?? "Workout"
            let exerciseCount = plan.template?.exerciseIDs.count ?? 0
            let categoryIcon = plan.template?.category.icon ?? "figure.mixed.cardio"
            let isCompleted = plan.completedWorkout != nil

            return TodaysPlanEntry(
                date: .now,
                planState: .workout(
                    name: name,
                    exerciseCount: exerciseCount,
                    categoryIcon: categoryIcon,
                    isCompleted: isCompleted
                ),
                tomorrowName: tomorrowName
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Views

struct TodaysPlanWidgetView: View {
    var entry: TodaysPlanEntry
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
        VStack(spacing: 8) {
            switch entry.planState {
            case .workout(let name, let count, let icon, let isCompleted):
                Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                    .font(.title2)
                    .foregroundStyle(isCompleted ? Color.groveTerracotta : Color.groveSage)

                Text(name)
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("\(count) exercises")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)

                if isCompleted {
                    Text("Done")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.groveTerracotta)
                }

            case .restDay:
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Color.groveSage)
                Text("Rest Day")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Text("Recover & grow")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)

            case .noPlan:
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.groveTextSecondary)
                Text("No Plan")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Text("Open Grove to plan")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            switch entry.planState {
            case .workout(let name, let count, let icon, let isCompleted):
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.groveTerracotta.opacity(0.15) : Color.groveSage.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                        .font(.title2)
                        .foregroundStyle(isCompleted ? Color.groveTerracotta : Color.groveSage)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Text("\(count) exercises")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }

                Spacer()

                if isCompleted {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.groveTerracotta)
                        Text("Done")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.groveTerracotta)
                    }
                } else {
                    Text("Planned")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.groveSage)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.groveSage.opacity(0.15), in: Capsule())
                }

            case .restDay:
                ZStack {
                    Circle()
                        .fill(Color.groveWarmSand.opacity(0.3))
                        .frame(width: 52, height: 52)
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(Color.groveSage)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rest Day")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Text("Recovery is part of the process")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                Spacer()

            case .noPlan:
                ZStack {
                    Circle()
                        .fill(Color.groveWarmSand.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Plan Today")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Text("Open Grove to set up your week")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Today's Plan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.groveTextSecondary)
                .textCase(.uppercase)

            // Main content
            switch entry.planState {
            case .workout(let name, let count, let icon, let isCompleted):
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCompleted ? Color.groveTerracotta.opacity(0.15) : Color.groveSage.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                            .font(.title)
                            .foregroundStyle(isCompleted ? Color.groveTerracotta : Color.groveSage)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.groveText)
                        HStack(spacing: 12) {
                            Label("\(count) exercises", systemImage: "dumbbell.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                    }

                    Spacer()

                    if isCompleted {
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(Color.groveTerracotta)
                            Text("Complete")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.groveTerracotta)
                        }
                    }
                }

            case .restDay:
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.groveSage.opacity(0.1))
                            .frame(width: 56, height: 56)
                        Image(systemName: "leaf.fill")
                            .font(.title)
                            .foregroundStyle(Color.groveSage)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rest Day")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.groveText)
                        Text("Your muscles grow during recovery")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }

            case .noPlan:
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.groveWarmSand.opacity(0.2))
                            .frame(width: 56, height: 56)
                        Image(systemName: "calendar.badge.plus")
                            .font(.title)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Plan")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.groveText)
                        Text("Open Grove to plan your week")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }
            }

            Spacer()

            // Tomorrow's plan
            if let tomorrow = entry.tomorrowName {
                Divider()
                HStack {
                    Text("Up Next")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.groveTextSecondary)
                    Spacer()
                    Text(tomorrow)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.groveSage)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }
}

// MARK: - Widget

struct TodaysPlanWidget: Widget {
    let kind = "TodaysPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysPlanProvider()) { entry in
            TodaysPlanWidgetView(entry: entry)
                .containerBackground(Color.groveBackground, for: .widget)
        }
        .configurationDisplayName("Today's Plan")
        .description("See today's scheduled workout at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    TodaysPlanWidget()
} timeline: {
    TodaysPlanEntry.placeholder
}

#Preview(as: .systemMedium) {
    TodaysPlanWidget()
} timeline: {
    TodaysPlanEntry.placeholder
}

#Preview(as: .systemLarge) {
    TodaysPlanWidget()
} timeline: {
    TodaysPlanEntry.placeholder
}
