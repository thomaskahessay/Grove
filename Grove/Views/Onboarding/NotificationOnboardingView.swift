import SwiftUI

struct NotificationOnboardingView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var isGranted = false
    @State private var appeared = false
    @State private var benefitsAppeared = false

    private let notificationService = NotificationService.shared

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

                // Main bell icon
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.groveSage, Color.groveSage.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, isActive: isRequesting)

                // Floating calendar icon
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.groveSage.opacity(0.5))
                    .offset(x: 52, y: -40)
                    .rotationEffect(.degrees(appeared ? 0 : -20))

                // Floating dumbbell icon
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.groveTerracotta.opacity(0.5))
                    .offset(x: -48, y: -44)
                    .scaleEffect(appeared ? 1 : 0.5)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(duration: 0.7, bounce: 0.3), value: appeared)

            Spacer()
                .frame(height: 32)

            VStack(spacing: 12) {
                Text("Stay on Track")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                Text("Get gentle reminders for your planned workouts and weekly check-ins.")
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
                benefitRow(icon: "bell.fill", color: .groveSage, text: "Daily reminders for planned workouts", delay: 0)
                benefitRow(icon: "calendar.badge.clock", color: .orange, text: "Weekly nudges to plan ahead", delay: 0.06)
                benefitRow(icon: "figure.run", color: .blue, text: "Alerts if you leave a workout unfinished", delay: 0.12)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Bottom action area
            VStack(spacing: 14) {
                if isGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.groveSage)
                        Text("Notifications Enabled!")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                    }
                    .font(.title3)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        enableNotifications()
                    } label: {
                        HStack(spacing: 8) {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Enable Notifications")
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
                    .disabled(isRequesting)
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

    private func enableNotifications() {
        isRequesting = true
        Task {
            let granted = await notificationService.requestAuthorization()
            isRequesting = false
            if granted {
                withAnimation {
                    isGranted = true
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
    NotificationOnboardingView {
        print("Continue tapped")
    }
}
