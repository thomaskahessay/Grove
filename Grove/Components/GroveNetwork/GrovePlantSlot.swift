import SwiftUI

struct GrovePlantSlot: View {
    let streak: Int
    let isWilted: Bool
    let wiltedAtStage: PlantStage
    let plantSize: CGFloat
    let label: String
    let sublabel: String?
    let isUser: Bool
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

            Text(label)
                .font(.system(size: isUser ? 11 : 9, weight: isUser ? .semibold : .medium))
                .foregroundStyle(isUser ? Color.groveText : Color.groveTextSecondary)
                .lineLimit(1)

            if let sublabel {
                Text(sublabel)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(Color.groveTextSecondary.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
