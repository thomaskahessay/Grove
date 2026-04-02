import SwiftUI

struct SunlightPromptCard: View {
    let feedItems: [SharedWorkoutItem]
    let onSend: (SharedWorkoutItem) -> Void
    let onDismiss: () -> Void

    @State private var sentItemID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Send sunlight to a friend")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }

            Text("You earned sunlight from this workout. Share it with a friend!")
                .font(.caption)
                .foregroundStyle(Color.groveTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(feedItems.prefix(8)) { item in
                        Button {
                            if sentItemID == nil {
                                sentItemID = item.id
                                onSend(item)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color.groveSage.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if let data = item.friendProfileImageData,
                                           let img = UIImage(data: data) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .clipShape(Circle())
                                        } else {
                                            Text(initials(for: item.friendName))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.groveSage)
                                        }
                                    }
                                    .overlay {
                                        if sentItemID == item.id {
                                            Circle()
                                                .fill(.orange.opacity(0.3))
                                            Image(systemName: "sun.max.fill")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }

                                Text(item.friendName.components(separatedBy: " ").first ?? item.friendName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.groveTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
                        .disabled(sentItemID != nil)
                    }
                }
            }

            if sentItemID != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Sunlight sent!")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: sentItemID)
    }

    private func initials(for name: String) -> String {
        if name.isEmpty { return "G" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

#Preview("Sunlight Prompt — Available") {
    VStack {
        SunlightPromptCard(
            feedItems: SocialPreviewData.feedItems,
            onSend: { _ in },
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.groveBackground)
}

#Preview("Sunlight Prompt — Sent") {
    VStack {
        SunlightPromptCard(
            feedItems: SocialPreviewData.feedItems,
            onSend: { _ in },
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.groveBackground)
}
