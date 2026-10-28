import SwiftUI
import SwiftData

struct WorkoutCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \WorkoutTemplate.usageCount, order: .reverse) private var allTemplates: [WorkoutTemplate]

    // Optional initial category passed from Quick Start
    var initialCategory: TemplateCategory?

    @State private var workoutName = ""
    @State private var selectedCategory: TemplateCategory?
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var defaultSets = 3
    @State private var defaultReps = 10
    @State private var hasAppliedInitialCategory = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var suggestedExerciseIDs: [UUID] = []

    private var userTemplates: [WorkoutTemplate] {
        allTemplates.filter { !$0.isBuiltIn && !$0.isArchived }
    }

    private var suggestedExercises: [Exercise] {
        suggestedExerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }.filter { !selectedExercises.contains($0) }
    }

    private func refreshSuggestions() {
        guard let category = selectedCategory else {
            suggestedExerciseIDs = []
            return
        }

        let muscleGroups = muscleGroupsForCategory(category)
        suggestedExerciseIDs = allExercises
            .filter { muscleGroups.contains($0.muscleGroup) }
            .shuffled()
            .prefix(8)
            .map { $0.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout Name
                    workoutNameSection

                    // User Templates (if any)
                    if !userTemplates.isEmpty {
                        userTemplatesSection
                    }

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
            .onAppear {
                if !hasAppliedInitialCategory, let category = initialCategory {
                    selectedCategory = category
                    workoutName = category.rawValue
                    refreshSuggestions()
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

    private var userTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Templates")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(userTemplates) { template in
                        TemplateButton(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectTemplate(template)
                            }
                        }
                    }
                }
            }
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
                                suggestedExerciseIDs = []
                            } else {
                                selectedCategory = category
                                selectedExercises.removeAll()
                                refreshSuggestions()
                                if workoutName.isEmpty || TemplateCategory.allCases.map(\.rawValue).contains(workoutName) {
                                    workoutName = category.rawValue
                                }
                                // Auto-select template if only one exists for this category
                                let matchingTemplates = userTemplates.filter { $0.category == category }
                                if matchingTemplates.count == 1, let template = matchingTemplates.first {
                                    selectTemplate(template)
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
                    refreshSuggestions()
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
        .padding(.horizontal, 24)
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

        let workout = WorkoutSessionManager.buildWorkout(
            name: name,
            template: nil,
            exercises: selectedExercises,
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            context: modelContext
        )

        do {
            try modelContext.save()
        } catch {
            print("[Grove] ERROR: Failed to save new workout: \(error)")
        }

        // Dismiss the sheet first, then present the workout after a delay
        // to avoid the SwiftUI crash from simultaneous sheet dismiss + fullScreenCover present.
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sessionManager.startWorkout(workout)
        }
    }

    private func selectTemplate(_ template: WorkoutTemplate) {
        if selectedTemplate?.id == template.id {
            // Deselect template
            selectedTemplate = nil
            selectedExercises.removeAll()
            selectedCategory = nil
            workoutName = ""
        } else {
            // Select template and load its exercises
            selectedTemplate = template
            selectedCategory = template.category
            workoutName = template.name
            defaultSets = template.defaultSets
            defaultReps = template.defaultReps

            // Load exercises from template
            selectedExercises = template.exerciseIDs.compactMap { id in
                allExercises.first { $0.id == id }
            }
        }
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
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.vertical, 12)
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

struct TemplateButton: View {
    let template: WorkoutTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.groveTerracotta)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text("\(template.exerciseIDs.count) exercises")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }
            .frame(width: 110, height: 90, alignment: .topLeading)
            .padding(12)
            .background(isSelected ? Color.groveTerracotta : Color.groveCardBackground)
            .foregroundStyle(isSelected ? .white : Color.groveText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.groveTerracotta : Color.groveWarmSand.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Exercise.self, Workout.self, ExerciseLog.self, SetLog.self, WorkoutTemplate.self,
        configurations: config
    )
    ExerciseSeeds.seedExercises(context: container.mainContext)

    return WorkoutCreationView()
        .environment(WorkoutSessionManager())
        .modelContainer(container)
}
