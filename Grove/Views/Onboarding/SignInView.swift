import SwiftUI
import AuthenticationServices
import SwiftData

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var onSignInComplete: () -> Void

    @State private var authService = AuthService()
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Grove branding
            VStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.groveSage)

                Text("Grove")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveCharcoal)

                Text("Sign in to sync your workouts across devices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                #if DEBUG
                Button {
                    createDebugUser()
                } label: {
                    Text("Continue without Sign In")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveSage)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.groveSage.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.groveCream)
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.signInError ?? "An unknown error occurred.")
        }
    }

    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authService.signInError = "Invalid credential."
                showError = true
                return
            }

            let userID = credential.user
            let fullName = credential.fullName
            let displayName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            let user = User(appleUserID: userID)
            if !displayName.isEmpty {
                user.displayName = displayName
            }
            modelContext.insert(user)

            onSignInComplete()

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            authService.signInError = error.localizedDescription
            showError = true
        }
    }

    #if DEBUG
    private func createDebugUser() {
        let user = User(appleUserID: "debug-\(UUID().uuidString)")
        user.displayName = "Debug User"
        modelContext.insert(user)
        onSignInComplete()
    }
    #endif
}

#Preview {
    SignInView(onSignInComplete: {})
        .modelContainer(for: User.self, inMemory: true)
}
