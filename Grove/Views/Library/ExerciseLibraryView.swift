import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showingAddExercise = false

    private var filteredExercises: [Exercise] {
        var result = exercises

        if let muscleGroup = selectedMuscleGroup {
            result = result.filter { $0.muscleGroup == muscleGroup }
        }

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedMuscleGroup == nil
                        ) {
                            selectedMuscleGroup = nil
                        }

                        ForEach(MuscleGroup.allCases, id: \.self) { group in
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
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Exercise List
                ForEach(groupedExercises, id: \.0) { muscleGroup, exercises in
                    Section {
                        ForEach(exercises) { exercise in
                            ExerciseRowView(exercise: exercise)
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
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddExercise = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
            .overlay {
                if filteredExercises.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
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

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.groveText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.groveSage : Color.groveWarmSand.opacity(0.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(for: [Exercise.self])
}
