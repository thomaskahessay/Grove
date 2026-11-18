import SwiftUI
import UIKit

/// A profile photo enlarged over a blurred page, like tapping a profile picture on
/// Instagram: it pops in from small, and a tap anywhere or a swipe down closes it.
struct ExpandedPhotoView: View {
    let image: UIImage
    let name: String
    var onDismiss: () -> Void

    @State private var shown = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width - 48, 360)

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(shown ? 1 : 0)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)

                    Text(name)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                }
                .scaleEffect(shown ? 1 - min(abs(dragOffset) / 1200, 0.15) : 0.3)
                .opacity(shown ? 1 : 0)
                .offset(y: dragOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { close() }
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = max(0, $0.translation.height) }
                    .onEnded { value in
                        if value.translation.height > 100 || value.predictedEndTranslation.height > 300 {
                            close()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
                        }
                    }
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)'s profile photo")
        .accessibilityHint("Double-tap to close")
        .accessibilityAddTraits(.isImage)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { shown = true }
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}

extension View {
    /// Presents `ExpandedPhotoView` over everything (tab bar included) while `image` is set.
    func expandedPhoto(_ image: Binding<UIImage?>, name: String) -> some View {
        fullScreenCover(isPresented: Binding(
            get: { image.wrappedValue != nil },
            set: { if !$0 { image.wrappedValue = nil } }
        )) {
            if let photo = image.wrappedValue {
                ExpandedPhotoView(image: photo, name: name) {
                    // The view animates itself out; skip the cover's slide-down.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { image.wrappedValue = nil }
                }
                .presentationBackground(.clear)
            }
        }
    }
}

/// Opens an expanded photo without the full-screen cover's slide-up, so the photo's own
/// pop-in is the only animation.
@MainActor
func showExpandedPhoto(_ photo: UIImage, in binding: Binding<UIImage?>) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { binding.wrappedValue = photo }
}
