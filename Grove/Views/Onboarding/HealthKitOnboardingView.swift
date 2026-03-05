import SwiftUI

struct HealthKitOnboardingView: View {
    let onContinue: () -> Void

    @State private var isConnecting = false
    @State private var isConnected = false
    @State private var appeared = false
    @State private var benefitsAppeared = false

    private let healthKitManager = HealthKitManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero icon composition
            ZStack {
                // Soft glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.groveSage.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)

                // Main health icon
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.groveSage, Color.groveSage.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, isActive: isConnecting)

                // Floating Apple Watch icon
                Image(systemName: "applewatch")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.groveSage.opacity(0.5))
                    .offset(x: 52, y: -40)
                    .rotationEffect(.degrees(appeared ? 0 : -20))

                // Floating heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.5))
                    .offset(x: -48, y: -44)
                    .scaleEffect(appeared ? 1 : 0.5)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(duration: 0.7, bounce: 0.3), value: appeared)

            Spacer()
                .frame(height: 32)

            VStack(spacing: 12) {
                Text("Connect Apple Health")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                Text("See heart rate and calories from your Apple Watch workouts right inside Grove.")
                    .font(.body)
                    .foregroundStyle(Color.groveTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
            }

            Spacer()
                .frame(height: 36)

            // Benefits list with staggered animation
            VStack(alignment: .leading, spacing: 18) {
                benefitRow(icon: "heart.fill", color: .red, text: "Heart rate stats (min, avg, max)", delay: 0)
                benefitRow(icon: "flame.fill", color: .orange, text: "Calories burned per workout", delay: 0.06)
                benefitRow(icon: "applewatch", color: Color.groveSage, text: "Auto-matches your Apple Watch data", delay: 0.12)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Bottom action area
            VStack(spacing: 14) {
                if isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.groveSage)
                        Text("Connected!")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                    }
                    .font(.title3)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        connect()
                    } label: {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Connect Apple Health")
                        }
                        .font(.headline)
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
                    .disabled(isConnecting || !healthKitManager.isAvailable)
                    .padding(.horizontal, 24)

                    Button {
                        onContinue()
                    } label: {
                        Text("Not Now")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }
            }
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
        }
        .background(Color.groveBackground.ignoresSafeArea())
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                benefitsAppeared = true
            }
        }
    }

    private func benefitRow(icon: String, color: Color, text: String, delay: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.groveText)
        }
        .opacity(benefitsAppeared ? 1 : 0)
        .offset(x: benefitsAppeared ? 0 : 16)
        .animation(.easeOut(duration: 0.35).delay(delay), value: benefitsAppeared)
    }

    private func connect() {
        isConnecting = true
        Task {
            let success = await healthKitManager.requestAuthorization()
            isConnecting = false
            if success {
                withAnimation {
                    isConnected = true
                }
                try? await Task.sleep(for: .seconds(1))
                onContinue()
            } else {
                onContinue()
            }
        }
    }
}

#Preview {
    HealthKitOnboardingView {
        print("Continue tapped")
    }
}
