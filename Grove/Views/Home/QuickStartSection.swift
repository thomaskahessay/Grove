import SwiftUI
import SwiftData

// Wrapper to use with .sheet(item:) for reliable category passing
struct WorkoutCreationConfig: Identifiable {
    let id = UUID()
    let category: TemplateCategory?
}

struct QuickStartSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Query(sort: \WorkoutTemplate.usageCount, order: .reverse)
    private var templates: [WorkoutTemplate]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var allExerciseLogs: [ExerciseLog]

    @State private var workoutConfig: WorkoutCreationConfig?

    private var userTemplates: [WorkoutTemplate] {
        // Show up to 5 most used user templates (non-built-in, non-archived)
        Array(templates.filter { !$0.isBuiltIn && !$0.isArchived }.prefix(5))
    }

    private var defaultCategories: [TemplateCategory] {
        [.push, .pull, .legs, .chestTriceps, .backBiceps, .shoulders]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Empty workout button
                    QuickStartButton(
                        title: "Empty",
                        subtitle: "Blank workout",
                        icon: "plus.circle.fill",
                        color: Color.groveWarmSand
                    ) {
                        workoutConfig = WorkoutCreationConfig(category: nil)
                    }

                    // Show user's templates first
                    ForEach(userTemplates) { template in
                        QuickStartButton(
                            title: template.name,
                            subtitle: "\(template.exerciseIDs.count) exercises",
                            icon: iconName(for: template.category),
                            color: Color.groveTerracotta
                        ) {
                            startWorkoutFromTemplate(template)
                        }
                    }

                    // Then show default category buttons
                    ForEach(defaultCategories, id: \.self) { category in
                        QuickStartButton(
                            title: category.rawValue,
                            subtitle: "Quick start",
                            icon: iconName(for: category),
                            color: Color.groveSage
                        ) {
                            workoutConfig = WorkoutCreationConfig(category: category)
                        }
                    }
                }
            }
        }
        .sheet(item: $workoutConfig) { config in
            WorkoutCreationView(initialCategory: config.category)
        }
    }

    private func iconName(for category: TemplateCategory) -> String {
        switch category {
        case .push: return "arrow.up.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .legs: return "figure.walk.circle.fill"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.run.circle.fill"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "star.circle.fill"
        }
    }

    private func startWorkoutFromTemplate(_ template: WorkoutTemplate) {
        let exercises = template.exerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }
        guard !exercises.isEmpty else { return }

        let defaultSets = template.defaultSets
        let defaultReps = template.defaultReps

        let workout = Workout(name: template.name, templateUsed: template)
        modelContext.insert(workout)

        for (index, exercise) in exercises.enumerated() {
            let lastSets = getLastSetsForExercise(exercise)
            let numberOfSets = lastSets.isEmpty ? defaultSets : lastSets.count

            let exerciseLog = ExerciseLog(
                exercise: exercise,
                orderIndex: index,
                targetSets: numberOfSets,
                targetReps: defaultReps
            )
            exerciseLog.workout = workout
            modelContext.insert(exerciseLog)

            for setNumber in 1...numberOfSets {
                let lastSetData = lastSets.indices.contains(setNumber - 1) ? lastSets[setNumber - 1] : nil
                let setLog = SetLog(
                    setNumber: setNumber,
                    weight: lastSetData?.weight,
                    reps: lastSetData?.reps
                )
                setLog.exerciseLog = exerciseLog
                exerciseLog.sets.append(setLog)
                modelContext.insert(setLog)
            }
        }

        template.usageCount += 1
        template.lastUsedDate = Date()

        sessionManager.startWorkout(workout)
    }

    private func getLastSetsForExercise(_ exercise: Exercise) -> [(weight: Double?, reps: Int?)] {
        let completedLogs = allExerciseLogs
            .filter { $0.exercise?.id == exercise.id && $0.workout?.completedAt != nil }
            .sorted { ($0.workout?.completedAt ?? .distantPast) > ($1.workout?.completedAt ?? .distantPast) }

        guard let lastLog = completedLogs.first else { return [] }

        return lastLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
            .map { (weight: $0.weight, reps: $0.reps) }
    }
}

// MARK: - Quick Start Button

struct QuickStartButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 100, height: 90, alignment: .topLeading)
            .padding(12)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickStartSection()
        .padding()
        .background(Color.groveBackground)
        .modelContainer(for: [WorkoutTemplate.self])
}
