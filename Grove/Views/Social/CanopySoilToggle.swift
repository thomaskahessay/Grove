import SwiftUI

struct CanopySoilToggle: View {
    @Binding var mode: FeedMode

    var body: some View {
        HStack(spacing: 0) {
            toggleLeaf(
                label: "Canopy",
                icon: "leaf.fill",
                isSelected: mode == .canopy
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    mode = .canopy
                }
            }

            toggleLeaf(
                label: "Soil",
                icon: "leaf.fill",
                isSelected: mode == .soil
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    mode = .soil
                }
            }
        }
        .padding(4)
        .background(Color.groveCardBackground)
        .clipShape(Capsule())
    }

    private func toggleLeaf(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .rotationEffect(label == "Soil" ? .degrees(180) : .zero)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : Color.groveTextSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.groveSage : .clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var mode: FeedMode = .canopy
    VStack(spacing: 20) {
        CanopySoilToggle(mode: $mode)
        Text("Current: \(mode.rawValue)")
            .foregroundStyle(Color.groveText)
    }
    .padding()
    .background(Color.groveBackground)
}
