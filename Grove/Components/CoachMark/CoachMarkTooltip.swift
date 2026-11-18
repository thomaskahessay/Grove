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
                            .fill(i == stepIndex ? Color.groveSage : Color.groveSage.opacity(0.3))
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

                Button(isLastStep ? "Got It" : "Next") {
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
        // Solid, not material: over the dimmed backdrop a material turns muddy grey
        // and the body text loses most of its contrast.
        .background(Color.groveCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.groveSage.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }
}
