import SwiftUI

struct SeedPickerSheet: View {
    let item: SharedWorkoutItem
    let onSend: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customMessage = ""
    @FocusState private var isCustomFocused: Bool

    private var suggestions: [String] {
        SeedMessages.suggestions(for: item)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(Color.groveSage)
                    Text("Plant a seed for \(item.friendName)")
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                }
                .padding(.top, 8)

                // Suggested messages
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveTextSecondary)
                        .padding(.horizontal, 4)

                    ForEach(suggestions, id: \.self) { message in
                        Button {
                            onSend(message, false)
                            dismiss()
                        } label: {
                            HStack {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.groveText)
                                Spacer()
                                Image(systemName: "leaf")
                                    .font(.caption)
                                    .foregroundStyle(Color.groveSage.opacity(0.5))
                            }
                            .padding(12)
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Custom message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or write your own")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveTextSecondary)
                        .padding(.horizontal, 4)

                    HStack {
                        TextField("Type something...", text: $customMessage)
                            .font(.subheadline)
                            .focused($isCustomFocused)
                            .onChange(of: customMessage) { _, newValue in
                                if newValue.count > 60 {
                                    customMessage = String(newValue.prefix(60))
                                }
                            }

                        Text("\(customMessage.count)/60")
                            .font(.caption2)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                    .padding(12)
                    .background(Color.groveCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Plant button
                Button {
                    if !customMessage.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSend(customMessage, true)
                        dismiss()
                    }
                } label: {
                    Label("Plant Seed", systemImage: "leaf.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(customMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(customMessage.isEmpty ? 0.5 : 1)

                Spacer()
            }
            .padding(.horizontal)
            .background(Color.groveBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }
        }
    }
}

#Preview("Seed Picker — PR Context") {
    SeedPickerSheet(
        item: SocialPreviewData.feedItems[0],
        onSend: { msg, custom in print("Sent: \(msg), custom: \(custom)") }
    )
}

#Preview("Seed Picker — General Context") {
    SeedPickerSheet(
        item: SocialPreviewData.feedItems[1],
        onSend: { msg, custom in print("Sent: \(msg), custom: \(custom)") }
    )
}
