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

                    // Tooltip, anchored to the spotlight's edge whatever its height
                    tooltipLayer(for: frame, screenSize: geometry.size)
                }
            }
            // On the reader itself, so its size is the whole screen and matches the
            // global frames the anchors report.
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.35), value: manager.currentStep)
        }
    }

    /// Places the tooltip just above or below the spotlight. Built from spacers rather
    /// than `.position` so a card that wraps to more lines grows away from the
    /// spotlight instead of over it.
    @ViewBuilder
    private func tooltipLayer(for targetFrame: CGRect, screenSize: CGSize) -> some View {
        let spacing: CGFloat = 16
        let spotlightInset: CGFloat = 8
        let maxWidth: CGFloat = 300
        let width = min(maxWidth, screenSize.width - 32)
        // Clamp X to keep the tooltip within the screen
        let centerX = max(16 + width / 2, min(screenSize.width - 16 - width / 2, targetFrame.midX))

        let tooltip = CoachMarkTooltip(
            content: manager.currentStepContent,
            stepIndex: manager.stepIndex,
            totalSteps: manager.totalSteps,
            isLastStep: manager.isLastStep,
            onNext: { manager.advance() },
            onSkip: { manager.skip() }
        )
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 0) {
            if manager.currentStepContent.tooltipEdge == .top {
                Spacer(minLength: 0)
                tooltip
                Color.clear.frame(height: max(0, screenSize.height - targetFrame.minY + spotlightInset + spacing))
            } else {
                Color.clear.frame(height: max(0, targetFrame.maxY + spotlightInset + spacing))
                tooltip
                Spacer(minLength: 0)
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .offset(x: centerX - screenSize.width / 2)
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
