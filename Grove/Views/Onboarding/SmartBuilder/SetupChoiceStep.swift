import SwiftUI

/// "How do you want to set up your workouts?" — enter your own routine, or answer a few
/// questions and get a generated plan. Both end in the same exercise editor.
struct SetupChoiceStep: View {
    @Bindable var state: SmartBuilderState
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                VStack(spacing: 10) {
                    Text("How do you want to\nset up your workouts?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.groveText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("You can change anything later")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4), value: appeared)

                Spacer().frame(height: 40)

                VStack(spacing: 14) {
                    optionCard(
                        mode: .ownRoutine,
                        icon: "list.bullet.clipboard.fill",
                        title: "I have a routine",
                        subtitle: "Add the exercises you already do. We can fill in any gaps."
                    )
                    optionCard(
                        mode: .generate,
                        icon: "wand.and.stars",
                        title: "Build one for me",
                        subtitle: "Answer a few questions and we'll suggest a plan you can tweak."
                    )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear { appeared = true }
    }

    private func optionCard(mode: PlanSetupMode, icon: String, title: String, subtitle: String) -> some View {
        let isSelected = state.setupMode == mode
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                state.setupMode = mode
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.groveSage)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : Color.groveText)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.groveTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Color.groveSage.opacity(0.3))
            }
            .padding(18)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.groveSage, Color.groveSage.opacity(0.85)],
                        startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.groveCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.groveSage.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.groveSage.opacity(0.25) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
