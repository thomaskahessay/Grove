import SwiftUI

struct SeedPickerSheet: View {
    let item: SharedWorkoutItem
    let onSend: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customMessage = ""
    @FocusState private var isCustomFocused: Bool
    @State private var shuffle = 0
    /// Measured height of the sheet's content, so the sheet hugs it instead of using a
    /// fixed fraction (which was either squished or left a gap at the bottom).
    @State private var contentHeight: CGFloat = 480

    private var suggestions: [String] {
        SeedMessages.suggestions(for: item, shuffle: shuffle)
    }

    private var trimmedCustom: String {
        customMessage.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Suggested messages
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Suggested")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveTextSecondary)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { shuffle += 1 }
                            } label: {
                                Label("More ideas", systemImage: "shuffle")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.groveSage)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)

                        ForEach(suggestions, id: \.self) { message in
                            Button {
                                onSend(message, false)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(message)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.groveText)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    Image(systemName: "leaf")
                                        .font(.caption)
                                        .foregroundStyle(Color.groveSage.opacity(0.5))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.groveCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Custom message, with its send button inline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or write your own")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveTextSecondary)
                            .padding(.horizontal, 4)

                        HStack(spacing: 10) {
                            TextField("Type something…", text: $customMessage)
                                .font(.subheadline)
                                .focused($isCustomFocused)
                                .submitLabel(.send)
                                .onSubmit(sendCustom)
                                .onChange(of: customMessage) { _, newValue in
                                    if newValue.count > 60 {
                                        customMessage = String(newValue.prefix(60))
                                    }
                                }

                            if !customMessage.isEmpty {
                                Text("\(customMessage.count)/60")
                                    .font(.caption2)
                                    .foregroundStyle(Color.groveTextSecondary)
                                    .monospacedDigit()
                            }

                            Button(action: sendCustom) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(trimmedCustom.isEmpty ? Color.groveTextSecondary.opacity(0.4) : Color.groveSage)
                            }
                            .buttonStyle(.plain)
                            .disabled(trimmedCustom.isEmpty)
                            .accessibilityLabel("Plant seed")
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 8)
                        .padding(.vertical, 8)
                        .background(Color.groveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.groveBackground)
            .navigationTitle("Plant a seed for \(item.friendName.components(separatedBy: " ").first ?? item.friendName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }
        }
        // Fit the content (plus the nav bar and grabber); still scrolls if it can't fit.
        .presentationDetents([.height(contentHeight + 72)])
        .presentationDragIndicator(.visible)
    }

    private func sendCustom() {
        guard !trimmedCustom.isEmpty else { return }
        onSend(trimmedCustom, true)
        dismiss()
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
