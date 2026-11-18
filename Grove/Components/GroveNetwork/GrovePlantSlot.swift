import SwiftUI

/// How recently someone trained, shown on their plant in the grove strip.
enum GroveActivity {
    case today   // bloom: trained today
    case recent  // trained in the last few days
    case quiet   // nothing for 4+ days (or nothing loaded): drooping and faded

    static func from(lastWorkout: Date?, now: Date = Date()) -> GroveActivity {
        guard let lastWorkout else { return .quiet }
        let calendar = Calendar.current
        if calendar.isDateInToday(lastWorkout) { return .today }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastWorkout), to: calendar.startOfDay(for: now)).day ?? 99
        return days >= 4 ? .quiet : .recent
    }
}

struct GrovePlantSlot: View {
    let streak: Int
    let isWilted: Bool
    let wiltedAtStage: PlantStage
    var style: PlantStyle = .default
    let plantSize: CGFloat
    let label: String
    /// This week's workouts against their goal, as dots under the name.
    var week: GroveWeekProgress?
    let isUser: Bool
    var activity: GroveActivity = .recent
    let onTap: () -> Void

    /// Where the plant's base sits in its frame (the renderer's ground line).
    static let baseFraction: CGFloat = 0.86

    var body: some View {
        // The slot's frame is just the plant, so the layout can stand its base on the
        // strip's ground line; the name hangs below in the soil.
        StreakPlantView(
            streak: streak,
            isWilted: isWilted,
            wiltedAtStage: wiltedAtStage,
            style: style,
            size: plantSize,
            showLabel: false,
            showsGround: false,
            trainedToday: activity == .today
        )
        // Quiet plants fade (the plant's own art handles wilting).
        .saturation(activity == .quiet ? 0.35 : 1)
        .opacity(activity == .quiet ? 0.6 : 1)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: isUser ? 11 : 9, weight: isUser ? .semibold : .medium))
                    .foregroundStyle(isUser ? Color.groveText : Color.groveTextSecondary)
                    .lineLimit(1)

                if let week {
                    goalDots(week)
                        .padding(.top, 2)
                }
            }
            .fixedSize()
            .offset(y: plantSize * GrovePlantSlot.baseFraction + 3)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    /// One dot per day of their weekly goal, filled as they train (extra workouts add
    /// filled dots, up to seven). Without a shared goal, just a dot per workout.
    private func goalDots(_ week: GroveWeekProgress) -> some View {
        let total = min(max(week.target ?? 0, week.trained), 7)
        let size: CGFloat = isUser ? 5 : 4
        return HStack(spacing: isUser ? 2.5 : 2) {
            ForEach(0..<total, id: \.self) { index in
                if index < week.trained {
                    Circle()
                        .fill(week.reachedGoal ? Color.groveSage : Color.groveSage.opacity(0.8))
                        .frame(width: size, height: size)
                } else {
                    Circle()
                        .strokeBorder(Color.groveTextSecondary.opacity(0.35), lineWidth: 0.8)
                        .frame(width: size, height: size)
                }
            }
        }
        .frame(height: size)
    }

    private var accessibilityText: String {
        var text = label
        if activity == .today { text += ", trained today" } else if activity == .quiet { text += ", quiet lately" }
        if let week {
            let days = week.trained == 1 ? "1 workout" : "\(week.trained) workouts"
            text += ", \(days) this week"
            if let target = week.target { text += " of \(target)" }
        }
        return text
    }
}
