import SwiftUI

struct AddFriendSheet: View {
    @Environment(CloudKitSocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput: String = ""
    @State private var state: AddFriendState = .idle
    @State private var foundProfile: CKFriendProfile?

    private enum AddFriendState {
        case idle
        case searching
        case found
        case notFound
        case alreadyFriends
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.groveSage)

                    Text("Add a Friend")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)

                    Text("Enter their invite code to connect")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                // Code input
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("GROVE-")
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.groveText.opacity(0.5))

                        TextField("XXXX", text: $codeInput)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.groveText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: codeInput) { _, newValue in
                                // Limit to 4 characters, strip prefix if pasted
                                var cleaned = newValue.uppercased()
                                if cleaned.hasPrefix("GROVE-") {
                                    cleaned = String(cleaned.dropFirst(6))
                                }
                                codeInput = String(cleaned.prefix(4))
                                state = .idle
                            }
                    }
                    .padding()
                    .background(Color.groveCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.groveSage.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // Status area
                Group {
                    switch state {
                    case .idle:
                        EmptyView()
                    case .searching:
                        SwiftUI.ProgressView("Looking up code...")
                            .foregroundStyle(.secondary)
                    case .found:
                        if let profile = foundProfile {
                            foundProfileView(profile)
                        }
                    case .notFound:
                        Label("No user found with that code", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveMutedRust)
                    case .alreadyFriends:
                        Label("You're already friends!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveSage)
                    case .error(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveMutedRust)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Search button
                if case .idle = state {
                    Button {
                        Task { await lookupCode() }
                    } label: {
                        Text("Look Up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(codeInput.count < 4)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
            .background(Color.groveBackground)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func foundProfileView(_ profile: CKFriendProfile) -> some View {
        VStack(spacing: 16) {
            // Avatar + name
            HStack(spacing: 12) {
                avatarView(profile: profile, size: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    Text("\(profile.workoutCount) workouts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Add button
            Button {
                Task { await addFriend(profile) }
            } label: {
                Label("Add Friend", systemImage: "person.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private func avatarView(profile: CKFriendProfile, size: CGFloat) -> some View {
        Circle()
            .fill(Color.groveSage.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                if let data = profile.profileImageData,
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(profile.initials)
                        .font(size > 40 ? .title3 : .caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                }
            }
    }

    private func lookupCode() async {
        state = .searching
        let fullCode = InviteCodeGenerator.normalize(codeInput)

        if let profile = await socialService.lookupInviteCode(fullCode) {
            // Check if already friends
            if socialService.friends.contains(where: { $0.id == profile.id }) {
                state = .alreadyFriends
            } else {
                foundProfile = profile
                state = .found
            }
        } else {
            state = .notFound
        }
    }

    private func addFriend(_ profile: CKFriendProfile) async {
        let success = await socialService.addFriend(theirUserID: profile.id)
        if success {
            dismiss()
        } else {
            state = .error("Could not add friend. Try again.")
        }
    }
}
