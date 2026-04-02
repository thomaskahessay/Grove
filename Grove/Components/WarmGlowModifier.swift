import SwiftUI

struct WarmGlowModifier: ViewModifier {
    let isActive: Bool

    @State private var glowOpacity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.84, blue: 0).opacity(glowOpacity),
                                    Color.orange.opacity(glowOpacity * 0.7),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0).opacity(glowOpacity * 0.4), radius: 8)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.8)
                                .repeatForever(autoreverses: true)
                            ) {
                                glowOpacity = 0.7
                            }
                        }
                }
            }
    }
}

extension View {
    func sunlightGlow(active: Bool) -> some View {
        modifier(WarmGlowModifier(isActive: active))
    }
}
