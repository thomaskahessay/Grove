import SwiftUI

/// Mon–Sun row of tappable circles showing which days are training days (Mon=0 .. Sun=6)
struct TrainingWeekBar: View {
    var selectedDays: [Int]
    var onToggle: (Int) -> Void

    private let dayAbbreviations = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { index in
                let isTraining = selectedDays.contains(index)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        onToggle(index)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(isTraining ? Color.groveSage : Color.groveCardBackground)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isTraining ? Color.clear : Color.groveSage.opacity(0.15),
                                        lineWidth: 1
                                    )
                            )
                            .overlay {
                                if isTraining {
                                    Image(systemName: "dumbbell.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .shadow(
                                color: isTraining ? Color.groveSage.opacity(0.2) : .clear,
                                radius: 4, y: 2
                            )

                        Text(dayAbbreviations[index])
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(isTraining ? Color.groveText : Color.groveTextSecondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isTraining)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.03), value: selectedDays)
            }
        }
    }
}
