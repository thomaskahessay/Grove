import SwiftUI
import UIKit

/// Canvas-based seed planting animation: seed drops from above the card into the soil,
/// burrows in, sprout unfurls with spring animation, sparkle particles emit.
struct SeedTapAnimation: View {
    let onComplete: () -> Void

    @State private var startTime: Date?
    @State private var isActive = true

    private let duration: TimeInterval = 2.2
    private let soilLineY: CGFloat = 0.85

    // Phases
    private let fallEnd: TimeInterval = 0.55      // seed falls from above
    private let burrowEnd: TimeInterval = 0.8      // seed sinks into soil
    private let sproutEnd: TimeInterval = 1.5      // sprout grows
    // Particles: 1.5 - 2.2

    var body: some View {
        if isActive {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
                Canvas { context, size in
                    drawFrame(context: &context, size: size, date: timeline.date)
                }
            }
            .onAppear {
                startTime = Date()
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

        let soilY = size.height * soilLineY
        let landingX = size.width * 0.72  // match plant position

        // Phase 1: Seed falling from above
        if elapsed < fallEnd {
            drawFallingSeed(context: &context, size: size, elapsed: elapsed, landingX: landingX, soilY: soilY)
        }

        // Phase 2: Seed burrowing into soil
        if elapsed >= fallEnd && elapsed < burrowEnd {
            let burrowElapsed = elapsed - fallEnd
            let burrowDuration = burrowEnd - fallEnd
            let progress = CGFloat(burrowElapsed / burrowDuration)

            // Impact haptic when seed lands
            if burrowElapsed < 0.05 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            drawBurrowingSeed(context: &context, landingX: landingX, soilY: soilY, progress: progress, size: size)
            drawDustPoof(context: &context, centerX: landingX, soilY: soilY, progress: progress)
        }

        // Phase 3: Sprout growing
        if elapsed >= burrowEnd && elapsed < sproutEnd {
            let sproutElapsed = elapsed - burrowEnd
            let sproutDuration = sproutEnd - burrowEnd
            let progress = CGFloat(min(sproutElapsed / sproutDuration, 1.0))

            drawGrowingSprout(context: &context, centerX: landingX, soilY: soilY, progress: progress, size: size)

            // Haptic when sprout breaks through
            if sproutElapsed > 0.1 && sproutElapsed < 0.15 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            }
        }

        // Phase 4: Sparkle particles (keep showing sprout)
        if elapsed >= sproutEnd {
            let particleElapsed = elapsed - sproutEnd
            let particleDuration = duration - sproutEnd
            let progress = CGFloat(particleElapsed / particleDuration)

            drawGrowingSprout(context: &context, centerX: landingX, soilY: soilY, progress: 1.0, size: size)
            drawSparkles(context: &context, centerX: landingX, soilY: soilY, progress: progress, size: size)
        }
    }

    // MARK: - Phase 1: Falling Seed

    private func drawFallingSeed(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval,
        landingX: CGFloat,
        soilY: CGFloat
    ) {
        let progress = CGFloat(elapsed / fallEnd)

        // Seed starts above the card and falls with acceleration
        let startX = landingX + 8  // slight offset for arc
        let startY: CGFloat = -15  // above the card
        let endY = soilY - 3

        // Ease-in curve for acceleration (gravity feel)
        let easedProgress = progress * progress
        let y = startY + (endY - startY) * easedProgress

        // Slight horizontal drift to landing position
        let x = startX + (landingX - startX) * progress

        // Rotation speeds up as it falls
        let rotation = progress * progress * .pi * 2.5

        // Seed gets slightly larger as it gets closer (perspective)
        let scale: CGFloat = 0.7 + progress * 0.3
        let seedW: CGFloat = 5 * scale
        let seedH: CGFloat = 7.5 * scale

        // Shadow on soil grows as seed approaches
        if progress > 0.4 {
            let shadowProgress = (progress - 0.4) / 0.6
            let shadowR = 4 + shadowProgress * 6
            let shadowOpacity = shadowProgress * 0.15
            let shadowRect = CGRect(x: landingX - shadowR, y: soilY - 1, width: shadowR * 2, height: 3)
            context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(shadowOpacity)))
        }

        // Draw seed
        let transform = CGAffineTransform.identity
            .translatedBy(x: x, y: y)
            .rotated(by: rotation)

        let seedRect = CGRect(x: -seedW / 2, y: -seedH / 2, width: seedW, height: seedH)
        var seedPath = Path(ellipseIn: seedRect)
        seedPath = seedPath.applying(transform)

        context.fill(seedPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.45, green: 0.28, blue: 0.18),
                Color(red: 0.60, green: 0.38, blue: 0.25),
                Color(red: 0.70, green: 0.48, blue: 0.32)
            ]),
            startPoint: CGPoint(x: x - seedW, y: y - seedH),
            endPoint: CGPoint(x: x + seedW, y: y + seedH)
        ))

        // Seed highlight
        let hlRect = CGRect(x: -seedW * 0.2, y: -seedH * 0.3, width: seedW * 0.3, height: seedH * 0.25)
        var hlPath = Path(ellipseIn: hlRect)
        hlPath = hlPath.applying(transform)
        context.fill(hlPath, with: .color(Color.white.opacity(0.25)))

        // Motion trail (subtle)
        if progress > 0.1 && progress < 0.9 {
            let trailLength: CGFloat = 12 * progress
            let trailY = y - trailLength
            var trail = Path()
            trail.move(to: CGPoint(x: x - 0.5, y: y - seedH * 0.3))
            trail.addLine(to: CGPoint(x: x, y: trailY))
            trail.addLine(to: CGPoint(x: x + 0.5, y: y - seedH * 0.3))
            trail.closeSubpath()
            context.fill(trail, with: .color(Color(red: 0.60, green: 0.38, blue: 0.25).opacity(0.15 * (1.0 - progress))))
        }
    }

    // MARK: - Phase 2: Burrowing

    private func drawBurrowingSeed(
        context: inout GraphicsContext,
        landingX: CGFloat,
        soilY: CGFloat,
        progress: CGFloat,
        size: CGSize
    ) {
        // Seed sinks below soil line
        let sinkDepth = progress * 8
        let seedY = soilY - 3 + sinkDepth
        let opacity = max(0, 1.0 - progress * 1.5)  // fades as it sinks

        guard opacity > 0 else { return }

        let seedW: CGFloat = 5
        let seedH: CGFloat = 7.5
        let seedRect = CGRect(x: landingX - seedW / 2, y: seedY - seedH / 2, width: seedW, height: seedH)
        context.fill(Path(ellipseIn: seedRect), with: .color(
            Color(red: 0.50, green: 0.30, blue: 0.20).opacity(opacity)
        ))

        // Soil ripple effect (concentric rings around impact point)
        let ringCount = 2
        for i in 0..<ringCount {
            let ringProgress = max(0, progress - CGFloat(i) * 0.15)
            guard ringProgress > 0 else { continue }
            let ringR = ringProgress * 14 + CGFloat(i) * 4
            let ringOpacity = max(0, 0.2 - ringProgress * 0.25)
            let ringRect = CGRect(x: landingX - ringR, y: soilY - ringR * 0.3, width: ringR * 2, height: ringR * 0.6)
            context.stroke(Path(ellipseIn: ringRect), with: .color(Color(red: 0.55, green: 0.42, blue: 0.30).opacity(ringOpacity)), lineWidth: 0.8)
        }
    }

    // MARK: - Dust Poof

    private func drawDustPoof(context: inout GraphicsContext, centerX: CGFloat, soilY: CGFloat, progress: CGFloat) {
        let particleCount = 6
        for i in 0..<particleCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(particleCount)) + .pi / 6
            let dist = progress * 16
            let x = centerX + cos(angle) * dist
            let y = soilY - abs(sin(angle)) * dist * 0.6 // particles go upward
            let opacity = max(0, 1.0 - progress * 1.2)
            let r: CGFloat = (1.5 + CGFloat(i % 3) * 0.5) * (1.0 - progress * 0.4)

            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(
                Color(red: 0.65, green: 0.55, blue: 0.40).opacity(0.4 * opacity)
            ))
        }
    }

    // MARK: - Phase 3: Growing Sprout

    private func drawGrowingSprout(context: inout GraphicsContext, centerX: CGFloat, soilY: CGFloat, progress: CGFloat, size: CGSize) {
        let stemHeight = size.height * 0.07 * progress
        guard stemHeight > 1 else { return }

        let stemBase = CGPoint(x: centerX, y: soilY)
        let stemTop = CGPoint(x: centerX, y: soilY - stemHeight)

        // Spring overshoot on stem
        let overshoot: CGFloat = progress > 0.6 ? sin((progress - 0.6) / 0.4 * .pi) * 4 : 0
        let ctrl = CGPoint(x: centerX + overshoot, y: soilY - stemHeight * 0.5)

        var stem = Path()
        stem.move(to: stemBase)
        stem.addQuadCurve(to: stemTop, control: ctrl)
        context.stroke(stem, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.35, green: 0.50, blue: 0.28),
                Color(red: 0.48, green: 0.62, blue: 0.38)
            ]),
            startPoint: stemBase, endPoint: stemTop
        ), lineWidth: 2.0)

        // Soil crack where sprout emerges
        if progress < 0.5 {
            let crackW: CGFloat = 3 + progress * 8
            var crack = Path()
            crack.move(to: CGPoint(x: centerX - crackW, y: soilY))
            crack.addQuadCurve(
                to: CGPoint(x: centerX + crackW, y: soilY),
                control: CGPoint(x: centerX, y: soilY - 2)
            )
            context.stroke(crack, with: .color(Color(red: 0.45, green: 0.34, blue: 0.24).opacity(0.4 * (1.0 - progress * 2))), lineWidth: 0.8)
        }

        // Leaves unfurl (appear after 35% progress)
        if progress > 0.35 {
            let leafProgress = (progress - 0.35) / 0.65
            let leafLen = size.width * 0.028 * leafProgress
            let leafAngle = leafProgress * (.pi / 3)

            // Leaves start folded up and spread outward
            drawAnimatedLeaf(context: &context, origin: stemTop, length: leafLen,
                             angle: -.pi / 2 - leafAngle, width: leafLen * 0.45, progress: leafProgress)
            drawAnimatedLeaf(context: &context, origin: stemTop, length: leafLen,
                             angle: -.pi / 2 + leafAngle, width: leafLen * 0.45, progress: leafProgress)
        }
    }

    private func drawAnimatedLeaf(context: inout GraphicsContext, origin: CGPoint, length: CGFloat, angle: CGFloat, width: CGFloat, progress: CGFloat) {
        let tip = CGPoint(
            x: origin.x + cos(angle) * length,
            y: origin.y + sin(angle) * length
        )

        let wideT: CGFloat = 0.3
        let midX = origin.x + cos(angle) * length * wideT
        let midY = origin.y + sin(angle) * length * wideT
        let perpAngle = angle + .pi / 2
        let halfW = width / 2

        let left = CGPoint(x: midX + cos(perpAngle) * halfW, y: midY + sin(perpAngle) * halfW)
        let right = CGPoint(x: midX - cos(perpAngle) * halfW, y: midY - sin(perpAngle) * halfW)

        var path = Path()
        path.move(to: origin)
        path.addQuadCurve(to: tip, control: left)
        path.addQuadCurve(to: origin, control: right)
        path.closeSubpath()

        context.fill(path, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.40, green: 0.54, blue: 0.34),
                Color(red: 0.55, green: 0.72, blue: 0.48),
                Color(red: 0.65, green: 0.80, blue: 0.55)
            ]),
            startPoint: origin, endPoint: tip
        ))

        // Leaf vein (appears as leaf unfolds)
        if progress > 0.6 {
            let veinOpacity = (progress - 0.6) / 0.4 * 0.3
            var vein = Path()
            vein.move(to: origin)
            vein.addLine(to: CGPoint(x: (origin.x + tip.x) / 2, y: (origin.y + tip.y) / 2))
            context.stroke(vein, with: .color(Color(red: 0.35, green: 0.48, blue: 0.28).opacity(veinOpacity)), lineWidth: 0.4)
        }
    }

    // MARK: - Phase 4: Sparkles

    private func drawSparkles(context: inout GraphicsContext, centerX: CGFloat, soilY: CGFloat, progress: CGFloat, size: CGSize) {
        let stemTop = CGPoint(x: centerX, y: soilY - size.height * 0.07)
        let sparkleCount = 6

        for i in 0..<sparkleCount {
            let seed = Double(i) * 1.1
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(sparkleCount)) - .pi / 2
            let dist = progress * 22 + CGFloat(i) * 2
            let x = stemTop.x + cos(angle) * dist * 0.6
            let y = stemTop.y - progress * 25 - CGFloat(i) * 3 + sin(angle + .pi / 4) * dist * 0.2
            let opacity = max(0, 1.0 - progress * 1.3)

            guard opacity > 0 else { continue }

            // Sparkle: small diamond shape
            let r: CGFloat = 2.5 * (1.0 + sin(CGFloat(seed) + progress * 4) * 0.3)
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.55, green: 0.76, blue: 0.44).opacity(0.5 * opacity))
            )

            // Tiny glow around each sparkle
            let glowR = r * 2
            let glowRect = CGRect(x: x - glowR, y: y - glowR, width: glowR * 2, height: glowR * 2)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(Color(red: 0.55, green: 0.76, blue: 0.44).opacity(0.08 * opacity))
            )
        }
    }
}
