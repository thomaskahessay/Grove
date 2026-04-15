import SwiftUI

struct CoachMarkTooltip: View {
    let content: CoachMarkManager.StepContent
    let stepIndex: Int
    let totalSteps: Int
    let isLastStep: Bool
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(content.title)
                .font(.headline)
                .foregroundStyle(Color.groveText)

            Text(content.description)
                .font(.subheadline)
                .foregroundStyle(Color.groveTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                // Step dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == stepIndex ? Color.groveSage : Color.groveSage.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                if !isLastStep {
                    Button("Skip") {
                        onSkip()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.groveTextSecondary)
                }

                Button(isLastStep ? "Done" : "Next") {
                    onNext()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.groveSage)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}
