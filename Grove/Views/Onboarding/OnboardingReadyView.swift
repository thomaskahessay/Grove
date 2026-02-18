import SwiftUI
import SwiftData

struct OnboardingReadyView: View {
    var user: User

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.groveSage)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(duration: 0.6, bounce: 0.35), value: appeared)

                VStack(spacing: 8) {
                    Text("You're all set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveCharcoal)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                    Text("Let's grow.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)
                }
            }

            Spacer()
            Spacer()

            Button(action: handleStart) {
                Text("Start")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.groveSage)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)
        }
        .background(Color.groveCream)
        .onAppear {
            appeared = true
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
    container.mainContext.insert(user)

    return OnboardingReadyView(user: user)
        .modelContainer(container)
}
