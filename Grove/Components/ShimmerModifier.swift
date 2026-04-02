import SwiftUI

struct ShimmerModifier: ViewModifier {
    let isActive: Bool

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                stops: shimmerStops(phase: phase),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .onAppear {
                            withAnimation(
                                .linear(duration: 2.5)
                                .repeatForever(autoreverses: false)
                            ) {
                                phase = 1.0
                            }
                        }
                }
            }
    }

    private func shimmerStops(phase: CGFloat) -> [Gradient.Stop] {
        let center = phase
        let leading = max(0, center - 0.2)
        let trailing = min(1, center + 0.2)

        // Ensure stops are always in ascending order
        var stops: [Gradient.Stop] = []
        stops.append(.init(color: .clear, location: 0))
        if leading > 0 {
            stops.append(.init(color: .clear, location: leading))
        }
        let clampedCenter = max(leading, min(trailing, center))
        stops.append(.init(color: Color.blue.opacity(0.25), location: clampedCenter))
        if trailing < 1 {
            stops.append(.init(color: .clear, location: trailing))
        }
        stops.append(.init(color: .clear, location: 1))
        return stops
    }
}

extension View {
    func waterShimmer(active: Bool) -> some View {
        modifier(ShimmerModifier(isActive: active))
    }
}
