import SwiftUI

/// Animated card background that renders an evolving plant scene based on social interactions.
/// Uses TimelineView at 20fps for ambient sway animation with drawingGroup() for performance.
struct CardSceneBackgroundView: View {
    let interactions: InteractionSummary?
    let hasPRs: Bool

    private var growth: CardGrowthState {
        CardGrowthState(from: interactions)
    }

    var body: some View {
        ZStack {
            // Base card background
            if hasPRs {
                Color.groveTerracotta.opacity(0.06)
            } else {
                Color.groveCardBackground
            }

            // Living scene (only render if there's something to show)
            if growth.hasGrowth {
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let swayOffset = CGFloat(sin(elapsed * 1.2) * 0.3) * 8

                    Canvas { context, canvasSize in
                        CardSceneRenderer.draw(
                            context: &context,
                            size: canvasSize,
                            growth: growth,
                            swayOffset: swayOffset
                        )
                    }
                    .opacity(0.35)
                }
                .drawingGroup()

                // Gradient scrim for text readability:
                // Stronger at top (where text lives), weaker at bottom (where plant grows)
                LinearGradient(
                    colors: [
                        Color.groveCardBackground.opacity(hasPRs ? 0.65 : 0.7),
                        Color.groveCardBackground.opacity(hasPRs ? 0.15 : 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

// MARK: - Bare soil only (no interactions)

#Preview("No Interactions") {
    VStack(spacing: 16) {
        CardSceneBackgroundView(
            interactions: .empty(for: "test"),
            hasPRs: false
        )
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .background(Color.groveBackground)
}

#Preview("Watered") {
    VStack(spacing: 16) {
        CardSceneBackgroundView(
            interactions: InteractionSummary(
                workoutRecordName: "test",
                waterCount: 4, sunlightCount: 0, seeds: [],
                iWatered: true, iSunlit: false,
                waterers: [], sunlighters: [],
                latestWaterDate: Date(), latestSunlightDate: nil
            ),
            hasPRs: false
        )
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .background(Color.groveBackground)
}

#Preview("Full Bloom") {
    VStack(spacing: 16) {
        CardSceneBackgroundView(
            interactions: InteractionSummary(
                workoutRecordName: "test",
                waterCount: 6, sunlightCount: 2,
                seeds: [
                    SeedMessage(id: "1", senderID: "s1", senderName: "A", senderProfileImageData: nil, message: "Nice!", isCustom: false, createdAt: Date()),
                    SeedMessage(id: "2", senderID: "s2", senderName: "B", senderProfileImageData: nil, message: "Great!", isCustom: false, createdAt: Date()),
                    SeedMessage(id: "3", senderID: "s3", senderName: "C", senderProfileImageData: nil, message: "Strong!", isCustom: false, createdAt: Date()),
                    SeedMessage(id: "4", senderID: "s4", senderName: "D", senderProfileImageData: nil, message: "Keep it up!", isCustom: false, createdAt: Date()),
                    SeedMessage(id: "5", senderID: "s5", senderName: "E", senderProfileImageData: nil, message: "Beast!", isCustom: false, createdAt: Date()),
                    SeedMessage(id: "6", senderID: "s6", senderName: "F", senderProfileImageData: nil, message: "Fire!", isCustom: false, createdAt: Date()),
                    SeedMessage(id: "7", senderID: "s7", senderName: "G", senderProfileImageData: nil, message: "Go!", isCustom: false, createdAt: Date()),
                ],
                iWatered: true, iSunlit: true,
                waterers: [], sunlighters: [],
                latestWaterDate: Date(), latestSunlightDate: Date()
            ),
            hasPRs: true
        )
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .background(Color.groveBackground)
}
