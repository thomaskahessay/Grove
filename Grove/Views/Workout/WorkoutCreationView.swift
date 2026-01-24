import SwiftUI
import SwiftData

struct WorkoutCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    // Optional initial category passed from Quick Start
    var initialCategory: TemplateCategory?

    @State private var workoutName = ""
    @State private var selectedCategory: TemplateCategory?
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var defaultSets = 3
    @State private var defaultReps = 10
    @State private var hasAppliedInitialCategory = false

    // For navigation to active workout
    @State private var activeWorkout: Workout?
    @State private var navigateToActiveWorkout = false

    private var suggestedExercises: [Exercise] {
        guard let category = selectedCategory else { return [] }

        let muscleGroups = muscleGroupsForCategory(category)
        return allExercises
            .filter { muscleGroups.contains($0.muscleGroup) }
            .filter { !selectedExercises.contains($0) }
            .shuffled()
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout Name
                    workoutNameSection

                    // Category Selection
                    categorySelectionSection

                    // Suggested Exercises (if category selected)
                    if selectedCategory != nil && !suggestedExercises.isEmpty {
                        suggestedExercisesSection
                    }

                    // Selected Exercises
                    selectedExercisesSection

                    // Default Sets/Reps
                    if !selectedExercises.isEmpty {
                        defaultsSection
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color.groveBackground)
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startWorkoutButton
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedExercises: $selectedExercises,
                    filterCategory: selectedCategory
                )
            }
            .navigationDestination(isPresented: $navigateToActiveWorkout) {
                if let workout = activeWorkout {
                    // TODO: ActiveWorkoutView(workout: workout)
                    Text("Active Workout: \(workout.name)")
                }
            }
            .onAppear {
                if !hasAppliedInitialCategory, let category = initialCategory {
                    selectedCategory = category
                    workoutName = category.rawValue
                    hasAppliedInitialCategory = true
                }
            }
        }
    }

    // MARK: - Sections

    private var workoutNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Name")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            TextField("e.g., Push Day, Leg Day", text: $workoutName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedCategory == category {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                                selectedExercises.removeAll()
                                if workoutName.isEmpty || TemplateCategory.allCases.map(\.rawValue).contains(workoutName) {
                                    workoutName = category.rawValue
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var suggestedExercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)

                Spacer()

                Button {
                    // Force refresh by toggling category
                    let current = selectedCategory
                    selectedCategory = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedCategory = current
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .tint(.groveSage)
            }

            Text("Tap to add")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestedExercises) { exercise in
                        SuggestedExerciseCard(exercise: exercise) {
                            withAnimation {
                                selectedExercises.append(exercise)
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedExercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)

                Spacer()

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                }
                .tint(.groveSage)
            }

            if selectedExercises.isEmpty {
                emptyExercisesPlaceholder
            } else {
                exerciseList
            }
        }
    }

    private var emptyExercisesPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.largeTitle)
                .foregroundStyle(Color.groveWarmSand)

            Text("No exercises added yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingExercisePicker = true
            } label: {
                Text("Browse Library")
            }
            .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                SelectedExerciseRow(
                    exercise: exercise,
                    index: index + 1,
                    onRemove: {
                        withAnimation {
                            selectedExercises.removeAll { $0.id == exercise.id }
                        }
                    },
                    onMoveUp: index > 0 ? {
                        withAnimation {
                            selectedExercises.swapAt(index, index - 1)
                        }
                    } : nil,
                    onMoveDown: index < selectedExercises.count - 1 ? {
                        withAnimation {
                            selectedExercises.swapAt(index, index + 1)
                        }
                    } : nil
                )

                if index < selectedExercises.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default Sets & Reps")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(defaultSets)", value: $defaultSets, in: 1...10)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(defaultReps)", value: $defaultReps, in: 1...30)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var startWorkoutButton: some View {
        VStack {
            Button {
                startWorkout()
            } label: {
                Text("Start Workout")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(selectedExercises.isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func startWorkout() {
        let name = workoutName.isEmpty ? (selectedCategory?.rawValue ?? "Workout") : workoutName

        let workout = Workout(name: name)
        modelContext.insert(workout)

        // Create ExerciseLogs for each selected exercise
        for (index, exercise) in selectedExercises.enumerated() {
            let exerciseLog = ExerciseLog(
                exercise: exercise,
                orderIndex: index,
                targetSets: defaultSets,
                targetReps: defaultReps
            )
            exerciseLog.workout = workout
            modelContext.insert(exerciseLog)
        }

        activeWorkout = workout
        navigateToActiveWorkout = true
    }

    // MARK: - Helpers

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
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let category: TemplateCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.groveSage : Color.groveCardBackground)
            .foregroundStyle(isSelected ? .white : Color.groveText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.groveSage : Color.groveWarmSand.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch category {
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .legs: return "figure.run"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.walk"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct SuggestedExerciseCard: View {
    let exercise: Exercise
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(exercise.muscleSubgroup ?? exercise.muscleGroup.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .frame(width: 120, height: 70, alignment: .topLeading)
            .padding(12)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.groveWarmSand.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SelectedExerciseRow: View {
    let exercise: Exercise
    let index: Int
    let onRemove: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Index number
            Text("\(index)")
                .font(.headline)
                .foregroundStyle(Color.groveSage)
                .frame(width: 28)

            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                    .foregroundStyle(Color.groveText)

                Text(exercise.muscleGroup.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Reorder buttons
            HStack(spacing: 4) {
                if let moveUp = onMoveUp {
                    Button(action: moveUp) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let moveDown = onMoveDown {
                    Button(action: moveDown) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.groveMutedRust.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    WorkoutCreationView()
        .modelContainer(for: [
            Exercise.self,
            Workout.self,
            ExerciseLog.self,
            SetLog.self,
            WorkoutTemplate.self
        ])
}
