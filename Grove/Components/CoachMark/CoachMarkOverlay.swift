import SwiftUI

struct CoachMarkOverlay: View {
    @Environment(CoachMarkManager.self) private var manager

    var body: some View {
        if manager.isActive, let frame = manager.currentFrame {
            GeometryReader { geometry in
                ZStack {
                    // Dimmed backdrop with spotlight cutout
                    SpotlightBackdrop(targetFrame: frame)

                    // Spotlight border ring
                    SpotlightBorder(targetFrame: frame)

                    // Tooltip
                    CoachMarkTooltip(
                        content: manager.currentStepContent,
                        stepIndex: manager.stepIndex,
                        totalSteps: manager.totalSteps,
                        isLastStep: manager.isLastStep,
                        onNext: { manager.advance() },
                        onSkip: { manager.skip() }
                    )
                    .frame(maxWidth: 300)
                    .position(
                        tooltipPosition(
                            for: frame,
                            edge: manager.currentStepContent.tooltipEdge,
                            screenSize: geometry.size
                        )
                    )
                }
                .ignoresSafeArea()
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.35), value: manager.currentStep)
        }
    }

    private func tooltipPosition(
        for targetFrame: CGRect,
        edge: Edge,
        screenSize: CGSize
    ) -> CGPoint {
        let tooltipHeight: CGFloat = 140
        let spacing: CGFloat = 16

        let y: CGFloat = switch edge {
        case .bottom:
            targetFrame.maxY + spacing + tooltipHeight / 2
        case .top:
            targetFrame.minY - spacing - tooltipHeight / 2
        default:
            targetFrame.maxY + spacing + tooltipHeight / 2
        }

        // Clamp X to keep tooltip within screen bounds
        let x = max(170, min(screenSize.width - 170, targetFrame.midX))

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Spotlight Backdrop

private struct SpotlightBackdrop: View {
    let targetFrame: CGRect

    var body: some View {
        Canvas { context, size in
            // Fill entire screen with semi-transparent black
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.6))
            )

            // Punch out the spotlight area
            let insetFrame = targetFrame.insetBy(dx: -8, dy: -8)
            context.blendMode = .clear
            context.fill(
                Path(roundedRect: insetFrame, cornerRadius: 16),
                with: .color(.white)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .onTapGesture { }  // Block taps on the dimmed area
    }
}

// MARK: - Spotlight Border

private struct SpotlightBorder: View {
    let targetFrame: CGRect
    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.groveSage.opacity(pulseOpacity), lineWidth: 2)
            .frame(width: targetFrame.width + 16, height: targetFrame.height + 16)
            .position(x: targetFrame.midX, y: targetFrame.midY)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    pulseOpacity = 0.9
                }
            }
    }
}
