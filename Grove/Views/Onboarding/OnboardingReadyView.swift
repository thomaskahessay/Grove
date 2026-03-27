import SwiftUI
import SwiftData

struct OnboardingReadyView: View {
    var user: User

    @State private var appeared = false
    @State private var plantGrown = false
    @State private var showConfetti = false

    private var greeting: String {
        if let name = user.displayName, !name.isEmpty {
            return "Welcome, \(name)!"
        }
        return "You're all set!"
    }

    var body: some View {
        ZStack {
            // Background — solid color to match container (gradient gets clipped by parent)
            Color.groveBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Animated plant — grows from seed to sprout
                    ZStack {
                        // Soft glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.groveSage.opacity(0.12), Color.clear],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .opacity(appeared ? 1 : 0)

                        ZStack {
                            // Seed (fades out)
                            StreakPlantView(
                                streak: 0,
                                size: 200,
                                showLabel: false
                            )
                            .opacity(plantGrown ? 0 : 1)

                            // Sprout (fades in + scales up)
                            StreakPlantView(
                                streak: 1,
                                size: 200,
                                showLabel: false
                            )
                            .opacity(plantGrown ? 1 : 0)
                            .scaleEffect(plantGrown ? 1 : 0.6)
                        }
                        .scaleEffect(appeared ? 1 : 0.3)
                        .opacity(appeared ? 1 : 0)
                    }
                    .animation(.spring(duration: 0.8, bounce: 0.3), value: appeared)

                    // Text content
                    VStack(spacing: 10) {
                        Text(greeting)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.groveText)
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

                        Text("Let's grow together.")
                            .font(.title3)
                            .foregroundStyle(Color.groveTextSecondary)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
                    }

                    // Quick stats preview
                    HStack(spacing: 24) {
                        readyStat(value: "0", label: "Workouts")
                        readyStat(value: "0", label: "Day Streak")
                        readyStat(value: "Seed", label: "Plant Stage")
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
                }

                Spacer()
                Spacer()

                // Start button
                Button(action: handleStart) {
                    HStack(spacing: 8) {
                        Text("Let's Go")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color.groveSage, Color.groveSage.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.groveSage.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: appeared)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            // Stagger the entrance animations
            appeared = true

            // Grow the plant after the initial entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                    plantGrown = true
                }
            }

            // Trigger confetti after plant grows
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showConfetti = true
            }
        }
    }

    private func readyStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveSage)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.groveTextSecondary)
        }
    }

    private func handleStart() {
        user.onboardingCompletedAt = Date()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    let user = User(appleUserID: "preview")
    user.displayName = "Thomas"
    container.mainContext.insert(user)

    return OnboardingReadyView(user: user)
        .modelContainer(container)
}
