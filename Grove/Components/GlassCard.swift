import SwiftUI

/// A card container with iOS 26 Liquid Glass effect
/// Use for floating elements, bottom sheets, and navigation overlays
/// Do NOT use for list rows, exercise cards, or data displays
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A glass card with a specific tint color
struct TintedGlassCard<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = .groveSage, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(tint.opacity(0.1))
            .background(.ultraThinMaterial)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A floating action button container with glass effect
struct GlassFloatingContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .glassEffect()
            .clipShape(Capsule())
    }
}

/// Bottom toolbar container with glass effect
struct GlassToolbar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .glassEffect()
    }
}

#Preview("GlassCard") {
    ZStack {
        LinearGradient(
            colors: [.groveSage, .groveTerracotta],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Workout")
                        .font(.headline)
                    Text("Push Day")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("6 exercises")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TintedGlassCard(tint: .groveTerracotta) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.groveSage)
                    Text("12 day streak!")
                        .fontWeight(.medium)
                }
            }

            Spacer()

            GlassFloatingContainer {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "xmark")
                    }
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                    Button(action: {}) {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.title2)
            }
        }
        .padding()
    }
}
