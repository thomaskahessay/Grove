import SwiftUI

struct InviteCodeCard: View {
    let inviteCode: String?
    let isLoading: Bool
    let onGenerate: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.groveSage)
                Text("My Invite Code")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Spacer()
            }

            if let code = inviteCode {
                Text(code)
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)
                    .kerning(2)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    ShareLink(
                        item: "Add me on Grove! My code is \(code)",
                        subject: Text("Join me on Grove"),
                        message: Text("Add me on Grove! My invite code is \(code)")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                if isLoading {
                    SwiftUI.ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    Button {
                        onGenerate()
                    } label: {
                        Label("Get My Code", systemImage: "sparkle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }
}
