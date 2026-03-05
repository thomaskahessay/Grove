import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case signIn = 1
        case profileSetup = 2
        case smartBuilder = 3
        case healthKit = 4
        case ready = 5
    }

    @Query private var users: [User]
    @State private var currentStep: OnboardingStep = .welcome

    /// Steps that show in the progress bar (excludes welcome, ready, & smartBuilder which has its own)
    private var progressSteps: [OnboardingStep] { [.signIn, .profileSetup, .smartBuilder, .healthKit] }
    private var showsProgress: Bool { progressSteps.contains(currentStep) && currentStep != .smartBuilder }
    private var progressIndex: Int { progressSteps.firstIndex(of: currentStep) ?? 0 }
    private var showsBack: Bool { currentStep == .profileSetup || currentStep == .healthKit }

    var body: some View {
        ZStack(alignment: .top) {
            Color.groveBackground.ignoresSafeArea()

            // Content
            Group {
                switch currentStep {

                case .welcome:
                    WelcomeCarouselView {
                        advance(to: .signIn)
                    }
                    .transition(.move(edge: .leading))

                case .signIn:
                    SignInView {
                        advance(to: .profileSetup)
                    }
                    .transition(.move(edge: .trailing))

                case .profileSetup:
                    if let user = users.first {
                        ProfileSetupView(user: user) {
                            advance(to: .smartBuilder)
                        }
                        .transition(.move(edge: .trailing))
                    }

                case .smartBuilder:
                    if let user = users.first {
                        SmartBuilderView(user: user, onBack: {
                            advance(to: .profileSetup)
                        }) {
                            advance(to: .healthKit)
                        }
                        .transition(.move(edge: .trailing))
                    }

                case .healthKit:
                    HealthKitOnboardingView {
                        advance(to: .ready)
                    }
                    .transition(.move(edge: .trailing))

                case .ready:
                    if let user = users.first {
                        OnboardingReadyView(user: user)
                            .transition(.move(edge: .trailing))
                    }
                }
            }
            .clipped()

            // Progress bar overlay
            if showsProgress {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Back button
                        if showsBack {
                            Button {
                                goBack()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.groveText)
                                    .frame(width: 44, height: 44)
                            }
                            .transition(.opacity)
                        } else {
                            Color.clear.frame(width: 44, height: 44)
                        }

                        // Step dots
                        HStack(spacing: 8) {
                            ForEach(0..<progressSteps.count, id: \.self) { index in
                                Capsule()
                                    .fill(index <= progressIndex ? Color.groveSage : Color.groveSage.opacity(0.2))
                                    .frame(height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: progressIndex)
                            }
                        }
                        .padding(.horizontal, 8)

                        // Spacer to balance back button
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentStep)
        .onAppear {
            if let user = users.first {
                if (user.appleUserID.hasPrefix("debug-") || user.appleUserID.hasPrefix("signed-out-")) {
                    currentStep = .signIn
                } else if user.onboardingCompletedAt == nil {
                    currentStep = .profileSetup
                }
            }
        }
        .onChange(of: users.count) { _, newCount in
            guard currentStep == .welcome,
                  newCount > 0,
                  let user = users.first,
                  user.onboardingCompletedAt == nil else { return }
            currentStep = .profileSetup
        }
    }

    private func advance(to step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
    }

    private func goBack() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        let previousStep = OnboardingStep.allCases[currentIndex - 1]
        // Don't go back past sign-in (can't un-sign-in)
        guard previousStep != .welcome else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = previousStep
        }
    }
}

#Preview {
    OnboardingContainerView()
        .modelContainer(for: User.self, inMemory: true)
}
