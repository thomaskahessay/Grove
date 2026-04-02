import SwiftUI

struct ExerciseSelectionStep: View {
    @Bindable var state: SmartBuilderState
    let exercises: [Exercise]

    @State private var selectedDayIndex = 0
    @State private var showMoreExercises = false
    @State private var searchText = ""
    @State private var appeared = false

    private var dayLabels: [String] { state.dayLabels }

    private var currentDayExercises: [Exercise] {
        state.dayExerciseSelections[selectedDayIndex] ?? []
    }

    private var currentDayLabel: String {
        guard selectedDayIndex < dayLabels.count else { return "" }
        return dayLabels[selectedDayIndex]
    }

    private var muscleGroupsForDay: [MuscleGroup] {
        state.muscleGroups(forDayIndex: selectedDayIndex)
    }

    private var availableExercises: [Exercise] {
        let selected = Set(currentDayExercises.map { $0.id })
        let filtered = exercises
            .filter { muscleGroupsForDay.contains($0.muscleGroup) && !selected.contains($0.id) }
            .sorted { $0.sortPriority < $1.sortPriority }

        if searchText.isEmpty { return filtered }
        return filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var estimatedMinutes: Int {
        state.estimatedMinutes(for: selectedDayIndex)
    }

    private var isOverBudget: Bool {
        estimatedMinutes > state.minutesPerWorkout
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                Text("Build your workouts")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.groveText)

                Text("Tap to add or remove exercises")
                    .font(.subheadline)
                    .foregroundStyle(Color.groveTextSecondary)
            }
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: appeared)

            // Day tabs
            dayTabBar
                .padding(.top, 16)

            // Running indicator
            runningIndicator
                .padding(.horizontal, 24)
                .padding(.top, 10)

            // Exercise list
            ScrollView {
                VStack(spacing: 0) {
                    // Selected exercises
                    if !currentDayExercises.isEmpty {
                        selectedSection
                    }

                    // More exercises
                    moreExercisesSection
                        .padding(.top, 8)

                    // Plan summary
                    planSummary
                        .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Day Tab Bar

    private var dayTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDayIndex = index
                                showMoreExercises = false
                                searchText = ""
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text("Day \(index + 1)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(
                                        selectedDayIndex == index
                                            ? Color.groveSage
                                            : Color.groveTextSecondary.opacity(0.6)
                                    )

                                Text(label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(
                                        selectedDayIndex == index
                                            ? Color.groveText
                                            : Color.groveTextSecondary
                                    )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedDayIndex == index
                                    ? Color.groveSage.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        selectedDayIndex == index
                                            ? Color.groveSage.opacity(0.3)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: selectedDayIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Running Indicator

    private var runningIndicator: some View {
        HStack(spacing: 8) {
            let count = currentDayExercises.count

            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(isOverBudget ? Color.groveTerracotta : Color.groveSage)

            Text("\(count) exercise\(count == 1 ? "" : "s") · ~\(estimatedMinutes) min")
                .font(.caption.weight(.medium))
                .foregroundStyle(isOverBudget ? Color.groveTerracotta : Color.groveText)

            if isOverBudget {
                Text("over budget")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.groveTerracotta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.groveTerracotta.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.groveCardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Selected Exercises

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(state.sortedExercises(for: selectedDayIndex).enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(exercise: exercise, isSelected: true, index: index)
            }
        }
    }

    // MARK: - More Exercises

    private var moreExercisesSection: some View {
        VStack(spacing: 0) {
            // Disclosure button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showMoreExercises.toggle()
                    if !showMoreExercises { searchText = "" }
                }
            } label: {
                HStack {
                    Image(systemName: showMoreExercises ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.groveSage)
                        .frame(width: 16)

                    Text("More exercises")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.groveSage)

                    Spacer()

                    Text("\(availableExercises.count) available")
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
            }

            if showMoreExercises {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                    TextField("Search exercises", text: $searchText)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.groveCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
                )
                .padding(.bottom, 8)

                // Available exercises
                ForEach(availableExercises) { exercise in
                    exerciseRow(exercise: exercise, isSelected: false, index: nil)
                }
            }
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(exercise: Exercise, isSelected: Bool, index: Int?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                toggleExercise(exercise)
            }
        } label: {
            HStack(spacing: 12) {
                // Checkmark
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.groveSage : Color.groveSage.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.groveSage)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.groveText)

                    if let subgroup = exercise.muscleSubgroup {
                        Text(subgroup)
                            .font(.caption2)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }

                Spacer()

                // Compound tag
                if exercise.isCompound {
                    Text("compound")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.groveSage)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.groveSage.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Plan Summary

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(Color.groveSage)
                Text("Your Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.groveTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                    let exercises = state.dayExerciseSelections[index] ?? []
                    let mins = exercises.count * 10
                    HStack {
                        Text("Day \(index + 1)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.groveTextSecondary)
                            .frame(width: 36, alignment: .leading)

                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                selectedDayIndex == index ? Color.groveSage : Color.groveText
                            )

                        Spacer()

                        Text("\(exercises.count) exercises · ~\(mins) min")
                            .font(.caption2)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        selectedDayIndex == index
                            ? Color.groveSage.opacity(0.06)
                            : (index % 2 == 0 ? Color.groveCardBackground.opacity(0.4) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedDayIndex = index
                            showMoreExercises = false
                            searchText = ""
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.groveSage.opacity(0.12), lineWidth: 1)
            )

            // Total summary
            let totalExercises = state.totalExerciseCount
            let avgMinutes = state.daysPerWeek > 0 ? (totalExercises * 10) / state.daysPerWeek : 0
            Text("\(state.daysPerWeek) days · \(totalExercises) total exercises · ~\(avgMinutes) min avg")
                .font(.caption2)
                .foregroundStyle(Color.groveTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Actions

    private func toggleExercise(_ exercise: Exercise) {
        var current = state.dayExerciseSelections[selectedDayIndex] ?? []
        if let idx = current.firstIndex(where: { $0.id == exercise.id }) {
            current.remove(at: idx)
        } else {
            current.append(exercise)
        }
        state.dayExerciseSelections[selectedDayIndex] = current
    }
}
