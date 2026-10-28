import SwiftUI

struct DaysPerWeekStep: View {
    @Bindable var state: SmartBuilderState
    @State private var appeared = false

    private let dayOptions = [1, 2, 3, 4, 5, 6]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            // Header
            VStack(spacing: 10) {
                Text("How many days\ndo you train?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.groveText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("We'll build a plan around your schedule")
                    .font(.subheadline)
                    .foregroundStyle(Color.groveTextSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer()
                .frame(height: 48)

            // Day count selector
            HStack(spacing: 10) {
                ForEach(dayOptions, id: \.self) { count in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            state.setDaysPerWeek(count)
                        }
                    } label: {
                        Text("\(count)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(state.daysPerWeek == count ? .white : Color.groveText)
                            .frame(width: 52, height: 52)
                            .background(
                                state.daysPerWeek == count
                                    ? AnyShapeStyle(Color.groveSage)
                                    : AnyShapeStyle(Color.groveCardBackground)
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        state.daysPerWeek == count ? Color.clear : Color.groveSage.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: state.daysPerWeek == count ? Color.groveSage.opacity(0.3) : .clear,
                                radius: 6, y: 3
                            )
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            // "days per week" label
            Text("days per week")
                .font(.subheadline)
                .foregroundStyle(Color.groveTextSecondary)
                .padding(.top, 12)

            Spacer()
                .frame(height: 48)

            // Week visualization — tap days to customize
            TrainingWeekBar(selectedDays: state.trainingDaySlots) { day in
                state.toggleTrainingDay(day)
            }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

            Text("Tap days to choose when you train")
                .font(.caption)
                .foregroundStyle(Color.groveTextSecondary)
                .padding(.top, 14)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { appeared = true }
    }
}
