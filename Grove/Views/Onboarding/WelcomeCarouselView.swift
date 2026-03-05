import SwiftUI

struct WelcomeCarouselView: View {
    var onGetStarted: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false
    @State private var bounceCounter = 0

    private let slides: [(icon: String, secondaryIcon: String?, title: String, subtitle: String, accentColor: Color)] = [
        (
            "dumbbell.fill",
            nil,
            "Easy Workout Logging",
            "Track your sets, reps, and weight with a clean, intuitive interface",
            .groveSage
        ),
        (
            "bolt.fill",
            "arrow.triangle.2.circlepath",
            "Smart & Automatic",
            "Auto-fill from previous workouts and detect new personal records",
            .groveTerracotta
        ),
        (
            "leaf.fill",
            "chart.line.uptrend.xyaxis",
            "Watch Yourself Grow",
            "Track your streak, grow your plant, and celebrate every milestone",
            Color(hex: "6B8E5A")
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                if currentPage < slides.count - 1 {
                    Button {
                        onGetStarted()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(height: 44)
            .animation(.easeInOut(duration: 0.2), value: currentPage)

            // Carousel
            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide: slide, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom section
            VStack(spacing: 24) {
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? slides[currentPage].accentColor : Color.groveSage.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }

                // Button
                Button(action: {
                    if currentPage == slides.count - 1 {
                        onGetStarted()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(currentPage == slides.count - 1 ? "Get Started" : "Next")
                            .font(.headline)

                        if currentPage == slides.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                                .transition(.scale.combined(with: .opacity))
                        }
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
                .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groveBackground)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            bounceCounter += 1
        }
        .onChange(of: currentPage) {
            bounceCounter += 1
        }
    }

    // MARK: - Slide View

    private func slideView(slide: (icon: String, secondaryIcon: String?, title: String, subtitle: String, accentColor: Color), index: Int) -> some View {
        VStack(spacing: 28) {
            Spacer()

            // Illustrated icon composition
            ZStack {
                // Background circle
                Circle()
                    .fill(slide.accentColor.opacity(0.08))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(slide.accentColor.opacity(0.05))
                    .frame(width: 140, height: 140)

                // Main icon
                Image(systemName: slide.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(slide.accentColor)
                    .symbolEffect(.bounce, value: currentPage == index ? bounceCounter : 0)

                // Secondary floating icon
                if let secondary = slide.secondaryIcon {
                    Image(systemName: secondary)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(slide.accentColor.opacity(0.6))
                        .offset(x: 58, y: -50)
                        .rotationEffect(.degrees(currentPage == index ? 0 : -15))
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: currentPage)
                }
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            // Text content
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveText)

                Text(slide.subtitle)
                    .font(.body)
                    .foregroundStyle(Color.groveTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 36)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WelcomeCarouselView(onGetStarted: {})
}
