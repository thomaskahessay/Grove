import SwiftUI
import SwiftData

/// Lets the user pick which weekdays their planned workouts land on.
/// The number of days stays fixed — changing it requires editing the full plan.
struct TrainingDaysView: View {
    var user: User
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedDays: [Int] = []
    @State private var workoutNames: [String] = []
    @State private var appeared = false

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private var requiredCount: Int { user.preferredDaysPerWeek }
    private var isValid: Bool { selectedDays.count == requiredCount }
    private var hasChanges: Bool { selectedDays != user.preferredTrainingSlots.sorted() }
    private var canSave: Bool { isValid && hasChanges }

    var body: some View {
        ZStack {
            Color.groveBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 24)

                        // Header
                        VStack(spacing: 10) {
                            Text("Which days\ndo you train?")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(Color.groveText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)

                            Text("Pick \(requiredCount) \(requiredCount == 1 ? "day" : "days") and your workouts will follow")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4), value: appeared)

                        Spacer()
                            .frame(height: 48)

                        TrainingWeekBar(selectedDays: selectedDays) { day in
                            toggle(day)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                        Text(selectionHint)
                            .font(.caption)
                            .foregroundStyle(isValid ? Color.groveTextSecondary : Color.groveTerracotta)
                            .padding(.top, 14)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: selectedDays)

                        Spacer()
                            .frame(height: 36)

                        schedulePreview
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                        Text("Completed workouts aren't affected. To change how many days you train, use Edit Training Plan.")
                            .font(.caption)
                            .foregroundStyle(Color.groveTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal, 12)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollBounceBehavior(.basedOnSize)

                saveButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onComplete() }
            }
        }
        .onAppear {
            let saved = user.preferredTrainingSlots.sorted()
            selectedDays = saved.count == requiredCount
                ? saved
                : SmartBuilderState.defaultTrainingSlots(for: requiredCount)
            workoutNames = fetchWorkoutNames()
            appeared = true
        }
    }

    // MARK: - Subviews

    private var selectionHint: String {
        if selectedDays.count < requiredCount {
            let remaining = requiredCount - selectedDays.count
            return "Pick \(remaining) more \(remaining == 1 ? "day" : "days")"
        }
        return "Tap a selected day to swap it out"
    }

    /// Each selected day paired with the workout that will land on it
    private var schedulePreview: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedDays.enumerated()), id: \.element) { index, day in
                HStack(spacing: 12) {
                    Text(dayNames[day])
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.groveText)
                    Spacer()
                    Text(index < workoutNames.count ? workoutNames[index] : "Workout")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                if index < selectedDays.count - 1 {
                    Divider()
                        .overlay(Color.groveWarmSand.opacity(0.5))
                        .padding(.horizontal, 18)
                }
            }
        }
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
        )
    }

    private var saveButton: some View {
        Button {
            SmartBuilderEngine.updateTrainingDays(selectedDays, user: user, context: modelContext)
            onComplete()
        } label: {
            HStack(spacing: 8) {
                Text("Save Changes")
                    .font(.headline)
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
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
        .disabled(!canSave)
        .opacity(canSave ? 1.0 : 0.5)
    }

    // MARK: - Helpers

    private func toggle(_ day: Int) {
        if let index = selectedDays.firstIndex(of: day) {
            selectedDays.remove(at: index)
        } else if selectedDays.count < requiredCount {
            selectedDays = (selectedDays + [day]).sorted()
        }
    }

    /// Workout names in weekly order, matching the order of sorted training days
    private func fetchWorkoutNames() -> [String] {
        let templates: [WorkoutTemplate]
        do {
            templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
        } catch { return [] }

        let byID = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.name) })
        return user.weeklyTemplateIDs.compactMap { byID[$0] }
    }
}
