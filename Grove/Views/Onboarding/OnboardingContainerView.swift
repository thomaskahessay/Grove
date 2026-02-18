import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    enum OnboardingStep {
        case welcome
        case signIn
        case profileSetup
        case weeklyPlan
        case ready
    }

    @Query private var users: [User]
    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                WelcomeCarouselView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .signIn
                    }
                }
                .transition(.move(edge: .leading))

            case .signIn:
                SignInView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .profileSetup
                    }
                }
                .transition(.move(edge: .trailing))

            case .profileSetup:
                if let user = users.first {
                    ProfileSetupView(user: user) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentStep = .weeklyPlan
                        }
                    }
                    .transition(.move(edge: .trailing))
                }

            case .weeklyPlan:
                if let user = users.first {
                    WeeklyPlanSetupView(user: user) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentStep = .ready
                        }
                    }
                    .transition(.move(edge: .trailing))
                }

            case .ready:
                if let user = users.first {
                    OnboardingReadyView(user: user)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentStep)
        .onAppear {
            // Resume mid-onboarding: user signed in but hasn't completed setup
            if let user = users.first, user.onboardingCompletedAt == nil {
                currentStep = .profileSetup
            }
        }
        .onChange(of: users.count) { _, newCount in
            // Catch the case where @Query loads after onAppear
            guard currentStep == .welcome,
                  newCount > 0,
                  let user = users.first,
                  user.onboardingCompletedAt == nil else { return }
            currentStep = .profileSetup
        }
    }
}

#Preview {
    OnboardingContainerView()
        .modelContainer(for: User.self, inMemory: true)
}
