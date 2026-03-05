import SwiftUI

struct WorkoutLengthStep: View {
    @Bindable var state: SmartBuilderState
    @State private var appeared = false

    private let options: [(minutes: Int, label: String)] = [
        (30, "Quick & focused"),
        (45, "Efficient session"),
        (60, "Standard workout"),
        (75, "Extended session"),
        (90, "Full program"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            // Header
            VStack(spacing: 10) {
                Text("How long are\nyour sessions?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.groveText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("This helps us pick the right number of exercises")
                    .font(.subheadline)
                    .foregroundStyle(Color.groveTextSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer()
                .frame(height: 48)

            // Time cards
            HStack(spacing: 10) {
                ForEach(options, id: \.minutes) { option in
                    let isSelected = state.minutesPerWorkout == option.minutes
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            state.minutesPerWorkout = option.minutes
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(option.minutes)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(isSelected ? .white : Color.groveText)
                            Text("min")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.groveTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(
                            isSelected
                                ? AnyShapeStyle(Color.groveSage)
                                : AnyShapeStyle(Color.groveCardBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected ? Color.clear : Color.groveSage.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? Color.groveSage.opacity(0.3) : .clear,
                            radius: 6, y: 3
                        )
                        .scaleEffect(isSelected ? 1.04 : 1.0)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            Spacer()
                .frame(height: 28)

            // Exercise count hint
            let exerciseCount = state.exerciseBudget
            let selectedOption = options.first { $0.minutes == state.minutesPerWorkout }

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)
                    Text("~\(exerciseCount) exercises per workout")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.groveText)
                }

                if let option = selectedOption {
                    Text(option.label)
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
            )
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { appeared = true }
    }
}
