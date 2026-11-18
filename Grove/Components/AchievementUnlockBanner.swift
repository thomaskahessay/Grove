import SwiftUI

/// A brief "Achievement unlocked" banner for achievements earned outside a workout
/// (creatine logs, custom exercises, posting, a full planned week…). Unlocks during a
/// workout are celebrated on the workout summary instead.
struct AchievementUnlockBannerModifier: ViewModifier {
    @Binding var unlocked: [AchievementType]

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let first = unlocked.first {
                    banner(for: first, extra: unlocked.count - 1)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: unlocked) {
                            try? await Task.sleep(for: .seconds(3.5))
                            withAnimation(.easeInOut(duration: 0.3)) { unlocked = [] }
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) { unlocked = [] }
                        }
                }
            }
            .animation(.spring(duration: 0.4), value: unlocked)
    }

    private func banner(for type: AchievementType, extra: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundStyle(Color.groveTerracotta)
                .frame(width: 36, height: 36)
                .background(Color.groveTerracotta.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked")
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
                Text(extra > 0 ? "\(type.rawValue) +\(extra) more" : type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func achievementUnlockBanner(_ unlocked: Binding<[AchievementType]>) -> some View {
        modifier(AchievementUnlockBannerModifier(unlocked: unlocked))
    }
}
