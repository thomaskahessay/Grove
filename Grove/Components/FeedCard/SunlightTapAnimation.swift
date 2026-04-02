import SwiftUI
import UIKit

/// Canvas-based sunlight animation: golden rays fan out, flowers bloom, warm particles rise.
/// Replaces the placeholder SunlightAnimationOverlay.
struct SunlightTapAnimation: View {
    let onComplete: () -> Void

    @State private var startTime: Date?
    @State private var isActive = true

    private let duration: TimeInterval = 2.5
    private let rayCount = 6

    // Phases
    private let raysFullAt: TimeInterval = 0.5
    private let bloomEnd: TimeInterval = 1.5
    // Fade: 1.5 - 2.5

    var body: some View {
        if isActive {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
                Canvas { context, size in
                    drawFrame(context: &context, size: size, date: timeline.date)
                }
            }
            .onAppear {
                startTime = Date()
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
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

        let sourceX = size.width * 0.5
        let sourceY: CGFloat = -5 // just above top edge

        // Phase 1 + 2: Light rays
        let rayProgress: CGFloat
        let rayOpacity: CGFloat
        if elapsed < raysFullAt {
            rayProgress = CGFloat(elapsed / raysFullAt)
            rayOpacity = 1.0
        } else if elapsed < bloomEnd {
            rayProgress = 1.0
            rayOpacity = 1.0
        } else {
            rayProgress = 1.0
            let fadeProgress = CGFloat((elapsed - bloomEnd) / (duration - bloomEnd))
            rayOpacity = max(0, 1.0 - fadeProgress)
        }

        drawLightRays(
            context: &context, size: size,
            sourceX: sourceX, sourceY: sourceY,
            progress: rayProgress, opacity: rayOpacity,
            elapsed: elapsed
        )

        // Phase 2: Bloom glow at plant area
        if elapsed >= raysFullAt * 0.8 {
            let bloomElapsed = elapsed - raysFullAt * 0.8
            let plantCenter = CGPoint(x: size.width * 0.72, y: size.height * 0.75)

            if elapsed < bloomEnd {
                let p = CGFloat(bloomElapsed / (bloomEnd - raysFullAt * 0.8))
                drawBloomGlow(context: &context, center: plantCenter, progress: p, size: size)
            } else {
                let fadeP = CGFloat((elapsed - bloomEnd) / (duration - bloomEnd))
                drawBloomGlow(context: &context, center: plantCenter, progress: 1.0 - fadeP, size: size)
            }

            // Warm rising particles
            drawWarmParticles(context: &context, center: plantCenter, elapsed: bloomElapsed, fadeOpacity: rayOpacity, size: size)
        }
    }

    private func drawLightRays(
        context: inout GraphicsContext,
        size: CGSize,
        sourceX: CGFloat, sourceY: CGFloat,
        progress: CGFloat, opacity: CGFloat,
        elapsed: TimeInterval
    ) {
        let fanAngle: CGFloat = .pi / 5  // total spread from center
        let rayLength = size.height * 1.2

        for i in 0..<rayCount {
            // Stagger ray appearance
            let stagger = CGFloat(i) / CGFloat(rayCount) * 0.3
            let rayProgress = max(0, min((progress - stagger) / (1.0 - stagger), 1.0))
            guard rayProgress > 0 else { continue }

            let t = CGFloat(i) / CGFloat(rayCount - 1)  // 0 to 1
            let angle = .pi / 2 + fanAngle * (t - 0.5) * 2 // centered downward

            // Slight oscillation for organic feel
            let wobble = CGFloat(sin(elapsed * 2.0 + Double(i) * 0.8)) * 0.02

            let effectiveAngle = angle + wobble
            let currentLength = rayLength * rayProgress

            // Ray as a thin triangle
            let tipX = sourceX + cos(effectiveAngle) * currentLength
            let tipY = sourceY + sin(effectiveAngle) * currentLength

            let halfWidth: CGFloat = 3 + rayProgress * 5
            let perpAngle = effectiveAngle + .pi / 2

            let leftBase = CGPoint(
                x: sourceX + cos(perpAngle) * halfWidth,
                y: sourceY + sin(perpAngle) * halfWidth
            )
            let rightBase = CGPoint(
                x: sourceX - cos(perpAngle) * halfWidth,
                y: sourceY - sin(perpAngle) * halfWidth
            )
            let tip = CGPoint(x: tipX, y: tipY)

            var rayPath = Path()
            rayPath.move(to: leftBase)
            rayPath.addLine(to: tip)
            rayPath.addLine(to: rightBase)
            rayPath.closeSubpath()

            let baseColor = Color(red: 1.0, green: 0.84, blue: 0.0)
            let rayOpacity = opacity * 0.12
            context.fill(rayPath, with: .linearGradient(
                Gradient(colors: [baseColor.opacity(rayOpacity), Color.clear]),
                startPoint: CGPoint(x: sourceX, y: sourceY),
                endPoint: tip
            ))
        }
    }

    private func drawBloomGlow(context: inout GraphicsContext, center: CGPoint, progress: CGFloat, size: CGSize) {
        guard progress > 0 else { return }

        // Radial warm glow
        let glowRadius = 40 * progress
        let glowColor = Color(red: 1.0, green: 0.84, blue: 0.0)

        // Outer glow
        let outerRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius,
                                width: glowRadius * 2, height: glowRadius * 2)
        context.fill(Path(ellipseIn: outerRect), with: .color(glowColor.opacity(0.06 * progress)))

        // Inner bright glow
        let innerR = glowRadius * 0.5
        let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR,
                                width: innerR * 2, height: innerR * 2)
        context.fill(Path(ellipseIn: innerRect), with: .color(glowColor.opacity(0.1 * progress)))

        // Sparkle ring (small dots in a circle)
        if progress > 0.3 {
            let sparkleProgress = (progress - 0.3) / 0.7
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi * 2 / 8)
                let dist = glowRadius * 0.7 * sparkleProgress
                let x = center.x + cos(angle) * dist
                let y = center.y + sin(angle) * dist
                let r: CGFloat = 1.5
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(glowColor.opacity(0.25 * sparkleProgress)))
            }
        }
    }

    private func drawWarmParticles(context: inout GraphicsContext, center: CGPoint, elapsed: TimeInterval, fadeOpacity: CGFloat, size: CGSize) {
        let particleCount = 8

        for i in 0..<particleCount {
            let seed = Double(i) * 1.3
            let particleElapsed = elapsed - seed * 0.15
            guard particleElapsed > 0 else { continue }

            let t = CGFloat(particleElapsed)
            let x = center.x + sin(t * 2.5 + seed) * 15
            let y = center.y - t * 25 // rise upward
            let opacity = max(0, fadeOpacity * (1.0 - t * 0.6))

            guard opacity > 0 && y > 0 else { continue }

            let r: CGFloat = 2.0 + sin(t * 4 + seed) * 0.5
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 1.0, green: 0.84 + sin(seed) * 0.1, blue: 0.3).opacity(0.3 * opacity))
            )
        }
    }
}
