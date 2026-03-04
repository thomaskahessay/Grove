import SwiftUI

struct HealthKitOnboardingView: View {
    let onContinue: () -> Void

    @State private var isConnecting = false
    @State private var isConnected = false

    private let healthKitManager = HealthKitManager.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.groveSage)
                .symbolEffect(.pulse, isActive: isConnecting)

            VStack(spacing: 12) {
                Text("Connect Apple Health")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)

                Text("See heart rate and calories from your Apple Watch workouts right inside Grove.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 16) {
                benefitRow(icon: "heart.fill", color: .red, text: "Heart rate stats (min, avg, max)")
                benefitRow(icon: "flame.fill", color: .orange, text: "Calories burned per workout")
                benefitRow(icon: "applewatch", color: Color.groveSage, text: "Auto-matches your Apple Watch data")
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
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
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Connect Apple Health")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.groveSage)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isConnecting || !healthKitManager.isAvailable)
                    .padding(.horizontal, 24)

                    Button {
                        onContinue()
                    } label: {
                        Text("Not Now")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.groveBackground)
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.groveText)
        }
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
                // Even if denied, let them continue
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
