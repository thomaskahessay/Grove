import AuthenticationServices
import SwiftUI

@MainActor @Observable
class AuthService: NSObject {
    var isSigningIn = false
    var signInError: String?

    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?

    func signInWithApple() async throws -> (userIdentifier: String, fullName: PersonNameComponents?, email: String?) {
        isSigningIn = true
        signInError = nil

        defer { isSigningIn = false }

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            self.signInContinuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }

        return (
            userIdentifier: credential.user,
            fullName: credential.fullName,
            email: credential.email
        )
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidCredential: return "Invalid sign-in credential."
            case .cancelled: return "Sign in was cancelled."
            }
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated {
            signInContinuation?.resume(returning: authorization)
            signInContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            signInContinuation?.resume(throwing: error)
            signInContinuation = nil
        }
    }
}
