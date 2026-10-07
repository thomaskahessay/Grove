import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @Binding var selectedExercises: [Exercise]
    var filterCategory: TemplateCategory?

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showingAddExercise = false

    private var filteredExercises: [Exercise] {
        var result = exercises

        // Apply muscle group filter
        if let muscleGroup = selectedMuscleGroup {
            result = result.filter { $0.muscleGroup == muscleGroup }
        } else if let category = filterCategory {
            // If no muscle group selected but category provided, filter by category's muscle groups
            let muscleGroups = muscleGroupsForCategory(category)
            result = result.filter { muscleGroups.contains($0.muscleGroup) }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                (exercise.muscleSubgroup?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var groupedExercises: [(MuscleGroup, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return MuscleGroup.allCases
            .filter { grouped[$0] != nil }
            .map { ($0, grouped[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Muscle Group Filter
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All",
                                isSelected: selectedMuscleGroup == nil
                            ) {
                                selectedMuscleGroup = nil
                            }

                            ForEach(relevantMuscleGroups, id: \.self) { group in
                                FilterChip(
                                    title: group.rawValue,
                                    isSelected: selectedMuscleGroup == group
                                ) {
                                    selectedMuscleGroup = group
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Exercise List
                ForEach(groupedExercises, id: \.0) { muscleGroup, exercises in
                    Section {
                        ForEach(exercises) { exercise in
                            ExercisePickerRow(
                                exercise: exercise,
                                isSelected: selectedExercises.contains { $0.id == exercise.id },
                                onToggle: {
                                    toggleExercise(exercise)
                                }
                            )
                        }
                    } header: {
                        HStack {
                            Image(systemName: iconName(for: muscleGroup))
                                .foregroundStyle(Color.groveSage)
                            Text(muscleGroup.rawValue)
                                .textCase(.uppercase)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("New Exercise", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView(
                    prefillName: searchText,
                    initialMuscleGroup: selectedMuscleGroup ?? relevantMuscleGroups.first ?? .chest
                ) { exercise in
                    selectedExercises.append(exercise)
                    searchText = ""
                }
            }
            .overlay {
                if filteredExercises.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Results for \"\(searchText)\"", systemImage: "magnifyingglass")
                    } description: {
                        Text("Check the spelling or create it as a new exercise.")
                    } actions: {
                        Button("Create \"\(searchText)\"") {
                            showingAddExercise = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.groveSage)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var relevantMuscleGroups: [MuscleGroup] {
        if let category = filterCategory {
            return muscleGroupsForCategory(category)
        }
        return MuscleGroup.allCases
    }

    private func toggleExercise(_ exercise: Exercise) {
        if let index = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
            selectedExercises.remove(at: index)
        } else {
            selectedExercises.append(exercise)
        }
    }

    private func muscleGroupsForCategory(_ category: TemplateCategory) -> [MuscleGroup] {
        switch category {
        case .push:
            return [.chest, .shoulders, .triceps]
        case .pull:
            return [.back, .biceps]
        case .legs:
            return [.legs]
        case .upper:
            return [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower:
            return [.legs, .core]
        case .fullBody:
            return MuscleGroup.allCases
        case .chestTriceps:
            return [.chest, .triceps]
        case .backBiceps:
            return [.back, .biceps]
        case .shoulders:
            return [.shoulders]
        case .custom:
            return MuscleGroup.allCases
        }
    }

    private func iconName(for muscleGroup: MuscleGroup) -> String {
        switch muscleGroup {
        case .chest: return "figure.arms.open"
        case .back: return "figure.strengthtraining.traditional"
        case .shoulders: return "figure.boxing"
        case .biceps: return "dumbbell.fill"
        case .triceps: return "arrowtriangle.down.fill"
        case .legs: return "figure.run"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Exercise Picker Row

struct ExercisePickerRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(Color.groveText)

                    if let subgroup = exercise.muscleSubgroup {
                        Text(subgroup)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !exercise.isBuiltIn {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(Color.groveTerracotta)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.groveSage : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selected: [Exercise] = []

    ExercisePickerView(
        selectedExercises: $selected,
        filterCategory: .push
    )
    .modelContainer(for: [Exercise.self])
}
