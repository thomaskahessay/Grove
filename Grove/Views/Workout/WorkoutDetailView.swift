import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let workout: Workout

    private var workoutExercises: [ExerciseLog] {
        workout.exercises
    }

    private var formattedDate: String {
        guard let completedAt = workout.completedAt else { return "In Progress" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }

    private var formattedDuration: String {
        let totalSeconds = Int(workout.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }

    private var totalVolume: Double {
        workoutExercises.reduce(0) { exerciseTotal, exerciseLog in
            exerciseTotal + exerciseLog.sets.reduce(0) { setTotal, setLog in
                guard setLog.isCompleted,
                      let weight = setLog.weight,
                      let reps = setLog.reps else { return setTotal }
                return setTotal + (weight * Double(reps))
            }
        }
    }

    private var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk lbs", totalVolume / 1000)
        } else {
            return String(format: "%.0f lbs", totalVolume)
        }
    }

    private var totalSets: Int {
        workoutExercises.reduce(0) { total, exerciseLog in
            total + exerciseLog.sets.filter { $0.isCompleted }.count
        }
    }

    private var sortedExercises: [ExerciseLog] {
        workoutExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var workoutPRs: [PersonalRecord] {
        let setIDs = Set(workout.exercises.flatMap { $0.sets.map { $0.id } })
        let descriptor = FetchDescriptor<PersonalRecord>()
        guard let allPRs = try? modelContext.fetch(descriptor) else { return [] }
        return allPRs.filter { pr in
            guard let setLogID = pr.setLogID else { return false }
            return setIDs.contains(setLogID)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Stats
                headerSection

                // Personal Records (if any)
                if !workoutPRs.isEmpty {
                    prSection
                }

                // Exercises
                exercisesSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color.groveBackground)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Date and Duration
            HStack {
                Label(formattedDate, systemImage: "calendar")
                Spacer()
                Label(formattedDuration, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Stats Grid
            HStack(spacing: 16) {
                StatBox(
                    title: "Exercises",
                    value: "\(workout.completedExerciseCount)",
                    icon: "figure.strengthtraining.traditional"
                )

                StatBox(
                    title: "Sets",
                    value: "\(totalSets)",
                    icon: "repeat"
                )

                StatBox(
                    title: "Volume",
                    value: formattedVolume,
                    icon: "scalemass"
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - PR Section

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Personal Records", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(Color.groveTerracotta)

                Spacer()

                Text("\(workoutPRs.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(workoutPRs, id: \.id) { pr in
                        PRCard(pr: pr)
                    }
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -16)
        }
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 0) {
                ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, exerciseLog in
                    ExerciseDetailRow(exerciseLog: exerciseLog)

                    if index < sortedExercises.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.groveSage)
                .frame(height: 24)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .background(Color.groveWarmSand.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - PR Card

private struct PRCard: View {
    let pr: PersonalRecord

    private var exerciseName: String {
        pr.exercise?.name ?? "Unknown"
    }

    private var typeLabel: String {
        pr.type == .maxWeight ? "Max Weight" : "Est. 1RM"
    }

    private var displayValue: String {
        if pr.type == .estimatedOneRM {
            let v = pr.value
            return v == floor(v) ? "\(Int(v)) lbs" : String(format: "%.1f lbs", v)
        } else {
            let w = pr.weight == floor(pr.weight) ? "\(Int(pr.weight))" : String(format: "%.1f", pr.weight)
            return "\(w) × \(pr.reps)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Color.groveTerracotta)

            Text(exerciseName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)

            Text(typeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(displayValue)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveTerracotta)
        }
        .padding(12)
        .frame(width: 140, alignment: .leading)
        .background(Color.groveTerracotta.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exercise Detail Row

private struct ExerciseDetailRow: View {
    let exerciseLog: ExerciseLog

    private var exerciseName: String {
        exerciseLog.exercise?.name ?? "Unknown Exercise"
    }

    private var completedSets: [SetLog] {
        exerciseLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
    }

    private var statusIcon: String {
        switch exerciseLog.status {
        case .completed:
            return "checkmark.circle.fill"
        case .skipped:
            return "forward.fill"
        case .inProgress:
            return "circle.dotted"
        case .planned:
            return "circle"
        }
    }

    private var statusColor: Color {
        switch exerciseLog.status {
        case .completed:
            return Color.groveSage
        case .skipped:
            return Color.groveMutedRust
        case .inProgress:
            return Color.groveTerracotta
        case .planned:
            return Color.groveWarmSand
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise Name and Status
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)

                Spacer()

                if exerciseLog.status == .skipped {
                    Text("Skipped")
                        .font(.caption)
                        .foregroundStyle(Color.groveMutedRust)
                }
            }

            // Sets
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(completedSets, id: \.id) { setLog in
                        SetDetailRow(setLog: setLog)
                    }
                }
                .padding(.leading, 28)
            } else if exerciseLog.status != .skipped {
                Text("No sets completed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 28)
            }
        }
        .padding(16)
    }
}

// MARK: - Set Detail Row

private struct SetDetailRow: View {
    let setLog: SetLog

    private var weightText: String {
        guard let weight = setLog.weight else { return "-" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        } else {
            return String(format: "%.1f", weight)
        }
    }

    private var repsText: String {
        guard let reps = setLog.reps else { return "-" }
        return "\(reps)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("Set \(setLog.setNumber):")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text("\(weightText) lbs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveText)

            Text("×")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(repsText) reps")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveText)

            Spacer()
        }
    }
}

private struct WorkoutDetailPreview: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workout: Workout?

    var body: some View {
        NavigationStack {
            if let workout {
                WorkoutDetailView(workout: workout)
            } else {
                ProgressView()
                    .onAppear { setupPreviewData() }
            }
        }
    }

    private func setupPreviewData() {
        let exercise1 = Exercise(name: "Bench Press", muscleGroup: .chest)
        let exercise2 = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        let exercise3 = Exercise(name: "Cable Flyes", muscleGroup: .chest)

        modelContext.insert(exercise1)
        modelContext.insert(exercise2)
        modelContext.insert(exercise3)

        let newWorkout = Workout(name: "Push Day")
        newWorkout.startedAt = Date().addingTimeInterval(-3600)
        newWorkout.completedAt = Date()
        modelContext.insert(newWorkout)

        let log1 = ExerciseLog(exercise: exercise1, orderIndex: 0)
        log1.workout = newWorkout
        log1.status = ExerciseStatus.completed
        modelContext.insert(log1)

        for i in 1...4 {
            let set = SetLog(setNumber: i, weight: 135, reps: 10)
            set.isCompleted = true
            set.exerciseLog = log1
            log1.sets.append(set)
            modelContext.insert(set)
        }

        let log2 = ExerciseLog(exercise: exercise2, orderIndex: 1)
        log2.workout = newWorkout
        log2.status = ExerciseStatus.completed
        modelContext.insert(log2)

        for i in 1...3 {
            let set = SetLog(setNumber: i, weight: 50, reps: 12)
            set.isCompleted = true
            set.exerciseLog = log2
            log2.sets.append(set)
            modelContext.insert(set)
        }

        let log3 = ExerciseLog(exercise: exercise3, orderIndex: 2)
        log3.workout = newWorkout
        log3.status = ExerciseStatus.skipped
        modelContext.insert(log3)

        workout = newWorkout
    }
}

#Preview {
    WorkoutDetailPreview()
        .modelContainer(for: [User.self, Workout.self, ExerciseLog.self, SetLog.self, Exercise.self], inMemory: true)
}
