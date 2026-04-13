import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Entry

struct StreakPlantEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let isWilted: Bool
    let stage: PlantStage
    let progressToNext: Double
    let daysUntilNext: Int?
    let stageName: String
    let trackCreatine: Bool
    let creatineLoggedToday: Bool

    static let placeholder = StreakPlantEntry(
        date: .now,
        streak: 7,
        isWilted: false,
        stage: .youngPlant,
        progressToNext: 0.5,
        daysUntilNext: 7,
        stageName: "Young Plant",
        trackCreatine: true,
        creatineLoggedToday: false
    )

    static let empty = StreakPlantEntry(
        date: .now,
        streak: 0,
        isWilted: false,
        stage: .seed,
        progressToNext: 0,
        daysUntilNext: 1,
        stageName: "Seed",
        trackCreatine: false,
        creatineLoggedToday: false
    )
}

// MARK: - Creatine Intent

struct LogCreatineIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Creatine"
    static let description: IntentDescription = "Toggle today's creatine log"

    func perform() async throws -> some IntentResult {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let calendar = Calendar.current

        let allLogs = try context.fetch(FetchDescriptor<CreatineLog>())
        let todaysLog = allLogs.first { calendar.isDateInToday($0.date) }

        if let existing = todaysLog {
            context.delete(existing)
        } else {
            let log = CreatineLog()
            log.user = try context.fetch(FetchDescriptor<User>()).first
            context.insert(log)
        }

        try context.save()
        return .result()
    }
}

// MARK: - Provider

struct StreakPlantProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakPlantEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakPlantEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakPlantEntry>) -> Void) {
        let entry = fetchEntry()
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func fetchEntry() -> StreakPlantEntry {
        do {
            let container = try SharedModelContainer.makeContainer()
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<User>()
            guard let user = try context.fetch(descriptor).first else {
                return .empty
            }

            let streak = user.currentStreak
            let stage = PlantStage.from(streak: streak)

            // Check creatine status
            let creatineLoggedToday: Bool
            if user.trackCreatine {
                let allLogs = try context.fetch(FetchDescriptor<CreatineLog>())
                creatineLoggedToday = allLogs.contains { Calendar.current.isDateInToday($0.date) }
            } else {
                creatineLoggedToday = false
            }

            return StreakPlantEntry(
                date: .now,
                streak: streak,
                isWilted: user.isStreakWilted,
                stage: stage,
                progressToNext: stage.progressToNext(currentStreak: streak),
                daysUntilNext: stage.daysUntilNext(currentStreak: streak),
                stageName: stage.displayName,
                trackCreatine: user.trackCreatine,
                creatineLoggedToday: creatineLoggedToday
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Views

struct StreakPlantWidgetView: View {
    var entry: StreakPlantEntry
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
        VStack(spacing: 4) {
            plantCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(streakLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.groveSage)
        }
        .padding(12)
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 12) {
            plantCanvas
                .frame(width: 120)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.stageName)
                    .font(.headline)
                    .foregroundStyle(Color.groveText)

                Text(streakLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.groveSage)

                if let daysLeft = entry.daysUntilNext {
                    ProgressView(value: entry.progressToNext)
                        .tint(Color.groveSage)
                    Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") to \(entry.stage.nextStage?.displayName ?? "max")")
                        .font(.caption2)
                        .foregroundStyle(Color.groveTextSecondary)
                } else {
                    Text("Max stage reached!")
                        .font(.caption2)
                        .foregroundStyle(Color.groveTerracotta)
                }

                if entry.trackCreatine {
                    creatineButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    // MARK: Large

    private var largeView: some View {
        VStack(spacing: 8) {
            plantCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 6) {
                Text(entry.stageName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.groveText)

                Text(streakLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.groveSage)

                if let daysLeft = entry.daysUntilNext {
                    ProgressView(value: entry.progressToNext)
                        .tint(Color.groveSage)
                    Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") to \(entry.stage.nextStage?.displayName ?? "max")")
                        .font(.caption2)
                        .foregroundStyle(Color.groveTextSecondary)
                } else {
                    Text("Your grove tree is fully grown!")
                        .font(.caption)
                        .foregroundStyle(Color.groveTerracotta)
                }
            }

            if entry.trackCreatine {
                creatineButton
            }
        }
        .padding(16)
    }

    // MARK: Helpers

    private var creatineButton: some View {
        Button(intent: LogCreatineIntent()) {
            HStack(spacing: 6) {
                Image(systemName: entry.creatineLoggedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(entry.creatineLoggedToday ? Color.groveSage : Color.groveTextSecondary)
                Text(entry.creatineLoggedToday ? "Creatine taken" : "Log creatine")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.creatineLoggedToday ? Color.groveSage : Color.groveText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(entry.creatineLoggedToday ? Color.groveSage.opacity(0.12) : Color.groveWarmSand.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }

    private var plantCanvas: some View {
        Canvas { context, size in
            PlantCanvasRenderer.draw(
                context: &context,
                size: size,
                stage: entry.stage,
                isWilted: entry.isWilted,
                swayOffset: 0,
                growthProgress: 1.0,
                elapsedTime: 0,
                bloomPulse: 0.5,
                lightPhase: 0.5
            )
        }
    }

    private var streakLabel: String {
        if entry.streak == 0 {
            return "Start your streak!"
        }
        return "\(entry.streak)-day streak"
    }
}

// MARK: - Widget

struct StreakPlantWidget: Widget {
    let kind = "StreakPlantWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakPlantProvider()) { entry in
            StreakPlantWidgetView(entry: entry)
                .containerBackground(Color.groveBackground, for: .widget)
        }
        .configurationDisplayName("Streak Plant")
        .description("Watch your plant grow with your workout streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    StreakPlantWidget()
} timeline: {
    StreakPlantEntry.placeholder
}

#Preview(as: .systemMedium) {
    StreakPlantWidget()
} timeline: {
    StreakPlantEntry.placeholder
}

#Preview(as: .systemLarge) {
    StreakPlantWidget()
} timeline: {
    StreakPlantEntry.placeholder
}
