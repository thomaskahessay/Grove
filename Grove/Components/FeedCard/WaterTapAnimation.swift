import SwiftUI
import UIKit

/// Canvas-based water drop animation with falling droplets and ripple splashes.
/// Replaces the placeholder WaterDropAnimationOverlay.
struct WaterTapAnimation: View {
    let onComplete: () -> Void

    @State private var startTime: Date?
    @State private var drops: [WaterDrop] = []
    @State private var ripples: [Ripple] = []
    @State private var isActive = true

    private let duration: TimeInterval = 1.8
    private let soilLineY: CGFloat = 0.85  // matches CardSceneRenderer
    private let dropCount = 10

    var body: some View {
        if isActive {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
                Canvas { context, size in
                    drawFrame(context: &context, size: size, date: timeline.date)
                }
            }
            .onAppear {
                startTime = Date()
                generateDrops()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func generateDrops() {
        drops = (0..<dropCount).map { i in
            WaterDrop(
                x: CGFloat.random(in: 0.1...0.9),
                y: CGFloat.random(in: 0.02...0.2),
                velocityY: CGFloat.random(in: 0.6...1.0),
                velocityX: CGFloat.random(in: -0.03...0.03),
                radius: CGFloat.random(in: 2.5...4.0),
                delay: Double(i) * 0.05 + Double.random(in: 0...0.1),
                splashed: false
            )
        }
    }

    private func drawFrame(context: inout GraphicsContext, size: CGSize, date: Date) {
        guard let startTime else { return }
        let elapsed = date.timeIntervalSince(startTime)

        if elapsed > duration {
            DispatchQueue.main.async {
                isActive = false
                onComplete()
            }
            return
        }

        let soilY = size.height * soilLineY

        // Update and draw drops
        for i in drops.indices {
            var drop = drops[i]
            let dropElapsed = elapsed - drop.delay
            guard dropElapsed > 0 else { continue }

            let t = CGFloat(dropElapsed)
            let gravity: CGFloat = 2.2
            let newY = drop.y * size.height + drop.velocityY * t * size.height * 0.5 + 0.5 * gravity * t * t * size.height
            let newX = drop.x * size.width + sin(t * 6) * 3 + drop.velocityX * t * size.width

            if newY >= soilY && !drop.splashed {
                drop.splashed = true
                drops[i] = drop

                // Spawn ripple at splash point
                let ripple = Ripple(x: newX, y: soilY, startTime: elapsed)
                ripples.append(ripple)

                // Haptic on first few splashes
                if ripples.count <= 3 {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
                }
            }

            if !drop.splashed {
                // Draw falling drop
                let opacity = 1.0 - (elapsed / duration) * 0.5
                let dropPath = Path(ellipseIn: CGRect(
                    x: newX - drop.radius,
                    y: newY - drop.radius * 1.3,
                    width: drop.radius * 2,
                    height: drop.radius * 2.6
                ))
                context.fill(dropPath, with: .color(Color.blue.opacity(0.35 * opacity)))

                // Tiny highlight on drop
                let hlSize = drop.radius * 0.5
                let hlRect = CGRect(x: newX - hlSize * 0.3, y: newY - drop.radius, width: hlSize, height: hlSize)
                context.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(0.3 * opacity)))
            }
        }

        // Draw ripples
        for ripple in ripples {
            let rippleElapsed = CGFloat(elapsed - ripple.startTime)
            let rippleDuration: CGFloat = 0.5
            guard rippleElapsed < rippleDuration else { continue }

            let progress = rippleElapsed / rippleDuration
            let radius = progress * 15
            let opacity = 1.0 - progress

            // Ripple ring
            let ringPath = Path(ellipseIn: CGRect(
                x: ripple.x - radius,
                y: ripple.y - radius * 0.4,
                width: radius * 2,
                height: radius * 0.8
            ))
            context.stroke(ringPath, with: .color(Color.blue.opacity(0.25 * opacity)), lineWidth: 1.2)

            // Soil darkening at impact
            if progress < 0.6 {
                let darkR = radius * 0.8
                let darkRect = CGRect(x: ripple.x - darkR, y: ripple.y - 1, width: darkR * 2, height: 4)
                context.fill(Path(ellipseIn: darkRect), with: .color(Color.brown.opacity(0.15 * (1.0 - progress / 0.6))))
            }
        }
    }
}

private struct WaterDrop {
    var x: CGFloat          // normalized 0-1
    var y: CGFloat          // normalized 0-1
    var velocityY: CGFloat  // normalized speed
    var velocityX: CGFloat  // normalized horizontal drift
    var radius: CGFloat     // in points
    var delay: Double       // stagger in seconds
    var splashed: Bool
}

private struct Ripple {
    var x: CGFloat    // in points
    var y: CGFloat    // in points
    var startTime: Double
}
