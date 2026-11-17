import SwiftUI

/// Compact friend picker for sending this workout's sunlight, shown in the workout summary's
/// post bar. Picking a friend only selects them; the sunlight is sent after the workout posts,
/// so it's tied to this workout. Tap the selected friend again to clear the choice.
/// Like the feed's sunlight button, it's one sunlight per post: a friend whose latest post
/// you've already sunlit is shown dimmed with "sent" and can't be picked.
struct SunlightPromptCard: View {
    /// One post per friend, most recent first (see `CloudKitSocialService.sunlightCandidates`).
    let candidates: [SharedWorkoutItem]
    /// Posts you've already sent sunlight to.
    var alreadySunlitIDs: Set<String> = []
    @Binding var selectedItemID: String?

    /// Friends you can still send to come first, in recency order; already-sent ones last.
    private var ordered: [SharedWorkoutItem] {
        candidates.filter { !alreadySunlitIDs.contains($0.id) }
            + candidates.filter { alreadySunlitIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text(selectedName.map { "Sunlight goes to \($0)" } ?? "Send your sunlight (optional)")
                    .foregroundStyle(Color.groveTextSecondary)
            }
            .font(.caption)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ordered) { item in
                        friendButton(item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedItemID)
    }

    private var selectedName: String? {
        candidates.first { $0.id == selectedItemID }.map(firstName)
    }

    private func friendButton(_ item: SharedWorkoutItem) -> some View {
        let isSelected = selectedItemID == item.id
        let alreadySent = alreadySunlitIDs.contains(item.id)
        return Button {
            selectedItemID = isSelected ? nil : item.id
        } label: {
            VStack(spacing: 3) {
                Circle()
                    .fill(isSelected ? Color.orange.opacity(0.25) : Color.groveSage.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if let data = item.friendProfileImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            Text(initials(for: item.friendName))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(isSelected ? .orange : Color.groveSage)
                        }
                    }
                    .overlay {
                        Circle().strokeBorder(Color.orange, lineWidth: isSelected ? 2 : 0)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if alreadySent {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .padding(2)
                                .background(Circle().fill(Color.groveBackground))
                        }
                    }

                Text(firstName(item))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.groveText)
                    .lineLimit(1)

                Text(alreadySent ? "sent" : recency(item.completedAt))
                    .font(.system(size: 9))
                    .foregroundStyle(!alreadySent && Calendar.current.isDateInToday(item.completedAt) ? Color.groveSage : Color.groveTextSecondary)
            }
            .frame(width: 52)
            .opacity(alreadySent ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(alreadySent)
        .accessibilityLabel("\(item.friendName), \(alreadySent ? "sunlight already sent" : recency(item.completedAt))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func firstName(_ item: SharedWorkoutItem) -> String {
        item.friendName.components(separatedBy: " ").first ?? item.friendName
    }

    private func recency(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        return "\(max(days, 1))d ago"
    }

    private func initials(for name: String) -> String {
        if name.isEmpty { return "G" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

#Preview("Sunlight picker") {
    @Previewable @State var selected: String?
    SunlightPromptCard(candidates: SocialPreviewData.feedItems, selectedItemID: $selected)
        .padding()
        .background(Color.groveBackground)
}
