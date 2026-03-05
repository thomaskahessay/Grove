import SwiftUI
import AuthenticationServices
import SwiftData

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var onSignInComplete: () -> Void

    @State private var authService = AuthService()
    @State private var showError = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: 24) {
                // Animated plant seed as branding
                ZStack {
                    // Soft glow behind the plant
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.groveSage.opacity(0.12), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)

                    StreakPlantView(streak: 0, size: 120, showLabel: false)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }
                .animation(.spring(duration: 0.7, bounce: 0.3), value: appeared)

                VStack(spacing: 10) {
                    Text("Grove")
                        .font(.system(size: 38, weight: .bold, design: .default))
                        .foregroundStyle(Color.groveText)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                    Text("Track your growth, one rep at a time")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
                }
            }

            Spacer()
            Spacer()

            // Sign-in section
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16))

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
                        .background(Color.groveSage.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groveBackground)
        .ignoresSafeArea()
        .onAppear {
            appeared = true
        }
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.signInError ?? "An unknown error occurred.")
        }
    }

    @Query private var existingUsers: [User]

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

            if let existingUser = existingUsers.first {
                existingUser.appleUserID = userID
                if existingUser.onboardingCompletedAt == nil {
                    existingUser.onboardingCompletedAt = Date()
                }
                if !displayName.isEmpty && existingUser.displayName == nil {
                    existingUser.displayName = displayName
                }
            } else {
                let user = User(appleUserID: userID)
                if !displayName.isEmpty {
                    user.displayName = displayName
                }
                modelContext.insert(user)
            }

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
