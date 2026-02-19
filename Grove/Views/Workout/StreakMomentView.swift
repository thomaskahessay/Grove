import SwiftUI

struct StreakMomentData {
    let streak: Int
    let isStageUp: Bool
    let previousStage: PlantStage
    let currentStage: PlantStage
    let isWilted: Bool
}

struct StreakMomentView: View {
    let data: StreakMomentData
    var onDismiss: () -> Void

    private var motivationalMessage: String {
        if data.isStageUp {
            return MotivationalMessages.message(for: .stageUp(stageName: data.currentStage.displayName))
        } else {
            return MotivationalMessages.message(for: .continuing)
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Plant
            StreakPlantView(
                streak: data.streak,
                size: 250,
                showLabel: false,
                animateStageUp: data.isStageUp,
                animateCelebration: !data.isStageUp
            )

            // Streak title
            Text("\(data.streak)-day streak")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            // Stage-up callout
            if data.isStageUp {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.groveTerracotta)
                    Text("New: \(data.currentStage.displayName)!")
                        .font(.headline)
                        .foregroundStyle(Color.groveTerracotta)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.groveTerracotta.opacity(0.1))
                .clipShape(Capsule())
            }

            // Message
            Text(motivationalMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.groveSage)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.groveBackground)
    }
}

#Preview {
    StreakMomentView(
        data: StreakMomentData(
            streak: 3,
            isStageUp: true,
            previousStage: .sprout,
            currentStage: .seedling,
            isWilted: false
        ),
        onDismiss: {}
    )
}
