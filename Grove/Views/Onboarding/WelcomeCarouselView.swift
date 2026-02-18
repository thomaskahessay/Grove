import SwiftUI

struct WelcomeCarouselView: View {
    var onGetStarted: () -> Void

    @State private var currentPage = 0

    private let slides: [(icon: String, title: String, subtitle: String)] = [
        (
            "dumbbell.fill",
            "Easy Workout Logging",
            "Track your sets, reps, and weight with a clean, intuitive interface"
        ),
        (
            "bolt.fill",
            "Smart & Automatic",
            "Auto-fill from previous workouts and detect new personal records"
        ),
        (
            "person.2.fill",
            "Train Together",
            "Share progress and stay accountable with friends and family"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    VStack(spacing: 20) {
                        Image(systemName: slide.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.groveSage)

                        Text(slide.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.groveCharcoal)

                        Text(slide.subtitle)
                            .font(.body)
                            .foregroundStyle(Color.groveCharcoal.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page indicator + button — layoutPriority(1) ensures
            // these are measured first so the TabView above fills the rest
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.groveSage : Color.groveSage.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                if currentPage == slides.count - 1 {
                    Button(action: onGetStarted) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.groveSage)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .transition(.opacity)
                } else {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.groveSage)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .layoutPriority(1)
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
        .background(Color.groveCream)
    }
}

#Preview {
    WelcomeCarouselView(onGetStarted: {})
}
