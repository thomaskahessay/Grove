import SwiftUI

// MARK: - PreferenceKey

struct CoachMarkAnchorsKey: PreferenceKey {
    static var defaultValue: [CoachMarkManager.TourStep: CGRect] = [:]

    static func reduce(
        value: inout [CoachMarkManager.TourStep: CGRect],
        nextValue: () -> [CoachMarkManager.TourStep: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - ViewModifier

struct CoachMarkAnchorModifier: ViewModifier {
    let step: CoachMarkManager.TourStep

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: CoachMarkAnchorsKey.self,
                            value: [step: geometry.frame(in: .global)]
                        )
                }
            )
    }
}

// MARK: - View Extension

extension View {
    func coachMarkAnchor(_ step: CoachMarkManager.TourStep) -> some View {
        modifier(CoachMarkAnchorModifier(step: step))
    }
}
