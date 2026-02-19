import SwiftUI

struct StreakPlantView: View {
    let streak: Int
    var isWilted: Bool = false
    var wiltedAtStage: PlantStage = .seed
    var size: CGFloat = 200
    var showLabel: Bool = true
    var animateStageUp: Bool = false
    var animateCelebration: Bool = false

    @State private var stageUpScale: CGFloat = 1.0
    @State private var celebrationScale: CGFloat = 1.0

    private var stage: PlantStage {
        isWilted ? wiltedAtStage : PlantStage.from(streak: streak)
    }

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let swayOffset = CGFloat(sin(elapsed * 1.5) * 0.3) * size * 0.05

                Canvas { context, canvasSize in
                    PlantCanvasRenderer.draw(
                        context: &context,
                        size: canvasSize,
                        stage: stage,
                        isWilted: isWilted,
                        swayOffset: swayOffset,
                        growthProgress: 1.0
                    )
                }
                .frame(width: size, height: size)
            }
            .scaleEffect(stageUpScale * celebrationScale)

            if showLabel {
                if isWilted {
                    Text("Streak broken")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveMutedRust)
                } else {
                    Text("\(streak)-day streak")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveSage)
                }
            }
        }
        .onAppear {
            if animateStageUp {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    stageUpScale = 1.15
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.4)) {
                    stageUpScale = 1.0
                }
            }
            if animateCelebration {
                withAnimation(.easeInOut(duration: 0.6).repeatCount(2, autoreverses: true)) {
                    celebrationScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    celebrationScale = 1.0
                }
            }
        }
    }
}

#Preview("Seed") {
    StreakPlantView(streak: 0, size: 200)
}

#Preview("Sprout") {
    StreakPlantView(streak: 1, size: 200)
}

#Preview("Seedling") {
    StreakPlantView(streak: 5, size: 200)
}

#Preview("Young Plant") {
    StreakPlantView(streak: 10, size: 250)
}

#Preview("Tree") {
    StreakPlantView(streak: 60, size: 300)
}

#Preview("Wilted") {
    StreakPlantView(streak: 0, isWilted: true, wiltedAtStage: .seedling, size: 200)
}
