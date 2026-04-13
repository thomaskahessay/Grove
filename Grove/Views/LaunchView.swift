import SwiftUI

struct LaunchView: View {
    @State private var seedVisible = false
    @State private var sproutGrown = false
    @State private var leavesAppeared = false
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 10
    @State private var glowOpacity: Double = 0
    @State private var swayAngle: Double = 0
    @State private var motesActive = false

    var body: some View {
        ZStack {
            Color.groveBackground
                .ignoresSafeArea()

            // Warm radial glow behind the plant
            RadialGradient(
                colors: [
                    Color.groveSage.opacity(glowOpacity * 0.18),
                    Color.groveWarmSand.opacity(glowOpacity * 0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 180
            )
            .offset(y: -40)
            .ignoresSafeArea()

            // Floating motes
            if motesActive {
                MoteFieldView()
                    .transition(.opacity)
            }

            VStack(spacing: 28) {
                Spacer()

                // Animated plant with sway
                ZStack {
                    // Soil line
                    Capsule()
                        .fill(Color.groveWarmSand.opacity(0.6))
                        .frame(width: 60, height: 6)
                        .offset(y: 40)
                        .opacity(seedVisible ? 1 : 0)

                    // Stem (sways from base)
                    StemShape()
                        .trim(from: 0, to: sproutGrown ? 1 : 0)
                        .stroke(
                            Color.groveSage,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 40, height: 70)
                        .offset(y: 5)
                        .rotationEffect(.degrees(swayAngle * 0.6), anchor: .bottom)

                    // Left leaf
                    LeafShape()
                        .fill(Color.groveSage)
                        .frame(width: 18, height: 24)
                        .rotationEffect(.degrees(-35 + swayAngle * 1.2))
                        .offset(x: -14, y: -8)
                        .scaleEffect(leavesAppeared ? 1 : 0, anchor: .bottomTrailing)
                        .opacity(leavesAppeared ? 1 : 0)

                    // Right leaf
                    LeafShape()
                        .fill(Color.groveSage.opacity(0.85))
                        .frame(width: 16, height: 22)
                        .rotationEffect(.degrees(40 + swayAngle * 0.9))
                        .offset(x: 14, y: -18)
                        .scaleEffect(leavesAppeared ? 1 : 0, anchor: .bottomLeading)
                        .opacity(leavesAppeared ? 1 : 0)

                    // Seed (below soil)
                    Ellipse()
                        .fill(Color.groveTerracotta)
                        .frame(width: 12, height: 8)
                        .offset(y: 36)
                        .scaleEffect(seedVisible ? 1 : 0.3)
                        .opacity(seedVisible ? 1 : 0)
                }
                .frame(height: 90)

                // App name
                Text("Grove")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.groveText)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Seed drops in
            withAnimation(.easeOut(duration: 0.4)) {
                seedVisible = true
            }
            // Stem grows up
            withAnimation(.easeInOut(duration: 0.7).delay(0.3)) {
                sproutGrown = true
            }
            // Leaves pop out
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.8)) {
                leavesAppeared = true
            }
            // Title fades in
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                titleOpacity = 1
                titleOffset = 0
            }
            // Glow blooms as plant grows
            withAnimation(.easeIn(duration: 1.0).delay(0.5)) {
                glowOpacity = 1
            }
            // Motes appear after plant is grown
            withAnimation(.easeIn(duration: 0.8).delay(1.2)) {
                motesActive = true
            }
            // Start gentle sway after growth finishes
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
                .delay(1.3)
            ) {
                swayAngle = 2.5
            }
        }
    }
}

// MARK: - Floating Motes

private struct MoteFieldView: View {
    private let motes = (0..<12).map { _ in Mote() }

    var body: some View {
        GeometryReader { geo in
            ForEach(motes) { mote in
                MoteView(mote: mote, bounds: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Mote: Identifiable {
    let id = UUID()
    let xRatio: CGFloat = .random(in: 0.15...0.85)
    let startYRatio: CGFloat = .random(in: 0.35...0.75)
    let size: CGFloat = .random(in: 2.5...5)
    let duration: Double = .random(in: 3.0...5.5)
    let delay: Double = .random(in: 0...2.0)
    let drift: CGFloat = .random(in: -20...20)
    let opacity: Double = .random(in: 0.25...0.6)
}

private struct MoteView: View {
    let mote: Mote
    let bounds: CGSize
    @State private var floating = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.98, blue: 0.88).opacity(mote.opacity),
                        Color(red: 1.0, green: 0.98, blue: 0.88).opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: mote.size
                )
            )
            .frame(width: mote.size * 2, height: mote.size * 2)
            .position(
                x: bounds.width * mote.xRatio + (floating ? mote.drift : 0),
                y: bounds.height * mote.startYRatio + (floating ? -60 : 0)
            )
            .opacity(floating ? 0 : mote.opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: mote.duration)
                    .repeatForever(autoreverses: false)
                    .delay(mote.delay)
                ) {
                    floating = true
                }
            }
    }
}

// MARK: - Shapes

private struct StemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: midX - 2, y: rect.minY),
            control: CGPoint(x: midX + 6, y: rect.midY)
        )
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control: CGPoint(x: -w * 0.15, y: h * 0.3)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control: CGPoint(x: w * 1.15, y: h * 0.3)
        )
        return path
    }
}

#Preview {
    LaunchView()
}
