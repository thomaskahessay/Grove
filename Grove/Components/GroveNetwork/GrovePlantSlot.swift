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
    let plantSize: CGFloat
    let label: String
    let sublabel: String?
    let isUser: Bool
    var activity: GroveActivity = .recent
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StreakPlantView(
                streak: streak,
                isWilted: isWilted,
                wiltedAtStage: wiltedAtStage,
                size: plantSize,
                showLabel: false
            )
            // Quiet plants droop and fade.
            .saturation(activity == .quiet ? 0.35 : 1)
            .opacity(activity == .quiet ? 0.6 : 1)
            .rotationEffect(.degrees(activity == .quiet ? -8 : 0), anchor: .bottom)

            // A small bloom next to the name marks someone who trained today.
            HStack(spacing: 2) {
                if activity == .today {
                    Image(systemName: "camera.macro")
                        .font(.system(size: isUser ? 9 : 8, weight: .semibold))
                        .foregroundStyle(Color.groveTerracotta)
                }
                Text(label)
                    .font(.system(size: isUser ? 11 : 9, weight: isUser ? .semibold : .medium))
                    .foregroundStyle(isUser ? Color.groveText : Color.groveTextSecondary)
                    .lineLimit(1)
            }

            if let sublabel {
                Text(sublabel)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(Color.groveTextSecondary.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label + (activity == .today ? ", trained today" : activity == .quiet ? ", quiet lately" : ""))
        .accessibilityAddTraits(.isButton)
    }
}
