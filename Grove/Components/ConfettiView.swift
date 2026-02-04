import SwiftUI

struct ConfettiView: View {
    @State private var confettiData: [ConfettiData] = []
    @State private var isAnimating = false

    private let colors: [Color] = [
        .groveSage,
        .groveTerracotta,
        .groveWarmSand,
        Color(hex: "B8D4A8"),
        Color(hex: "E89B7B")
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiData) { piece in
                    ConfettiPiece(data: piece, isAnimating: isAnimating)
                }
            }
            .task {
                // Wait a frame for geometry to be ready
                try? await Task.sleep(for: .milliseconds(50))
                setupConfetti(in: geometry.size)

                // Start animation after pieces are positioned
                try? await Task.sleep(for: .milliseconds(50))
                withAnimation {
                    isAnimating = true
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func setupConfetti(in size: CGSize) {
        guard size.width > 0 else { return }

        let particleCount = 60

        confettiData = (0..<particleCount).map { index in
            let delay = Double(index) * 0.015

            // Start spread across the full width
            let startX = Double.random(in: 0...size.width)
            // Drift slightly as it falls
            let endX = startX + Double.random(in: -50...50)

            return ConfettiData(
                id: index,
                color: colors[index % colors.count],
                startX: startX,
                startY: -20,
                endX: endX,
                endY: size.height + 50,
                width: CGFloat.random(in: 8...12),
                height: CGFloat.random(in: 14...22),
                delay: delay,
                duration: Double.random(in: 2.5...3.5),
                rotationEnd: Double.random(in: 720...1440) * (Bool.random() ? 1 : -1)
            )
        }
    }
}

private struct ConfettiData: Identifiable {
    let id: Int
    let color: Color
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let duration: Double
    let rotationEnd: Double
}

private struct ConfettiPiece: View {
    let data: ConfettiData
    let isAnimating: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(data.color)
            .frame(width: data.width, height: data.height)
            .rotationEffect(.degrees(isAnimating ? data.rotationEnd : 0))
            .position(
                x: isAnimating ? data.endX : data.startX,
                y: isAnimating ? data.endY : data.startY
            )
            .opacity(isAnimating ? 0 : 1)
            .animation(
                .easeIn(duration: data.duration).delay(data.delay),
                value: isAnimating
            )
    }
}

#Preview {
    ZStack {
        Color.groveBackground
        ConfettiView()
    }
}
