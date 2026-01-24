import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]

    let workout: Workout

    private var duration: TimeInterval {
        workout.duration
    }

    private var totalVolume: Double {
        workout.exercises.reduce(0) { exerciseTotal, exerciseLog in
            exerciseTotal + exerciseLog.sets.reduce(0) { setTotal, setLog in
                guard setLog.isCompleted,
                      let weight = setLog.weight,
                      let reps = setLog.reps else { return setTotal }
                return setTotal + (weight * Double(reps))
            }
        }
    }

    private var completedSetsCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    private var previousWorkout: Workout? {
        // Find the most recent completed workout with the same name (excluding current)
        allWorkouts.first { w in
            w.id != workout.id &&
            w.name == workout.name &&
            w.completedAt != nil
        }
    }

    private var previousVolume: Double? {
        guard let prev = previousWorkout else { return nil }
        return prev.exercises.reduce(0) { exerciseTotal, exerciseLog in
            exerciseTotal + exerciseLog.sets.reduce(0) { setTotal, setLog in
                guard setLog.isCompleted,
                      let weight = setLog.weight,
                      let reps = setLog.reps else { return setTotal }
                return setTotal + (weight * Double(reps))
            }
        }
    }

    private var volumeChange: Double? {
        guard let prev = previousVolume, prev > 0 else { return nil }
        return ((totalVolume - prev) / prev) * 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Stats cards
                    statsSection

                    // Comparison (if available)
                    if previousWorkout != nil {
                        comparisonSection
                    }

                    // Exercise breakdown
                    exerciseBreakdownSection

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color.groveBackground)
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        sessionManager.dismissSummary()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveSage)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.groveSage)

            Text(workout.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            Text(formattedDate(workout.startedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "clock.fill",
                value: formatDuration(duration),
                label: "Duration"
            )

            StatCard(
                icon: "scalemass.fill",
                value: formatVolume(totalVolume),
                label: "Volume"
            )

            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(completedSetsCount)",
                label: "Sets"
            )
        }
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("vs Last \(workout.name)")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            HStack(spacing: 16) {
                if let change = volumeChange {
                    ComparisonCard(
                        label: "Volume",
                        change: change,
                        isPositive: change >= 0
                    )
                }

                if let prev = previousWorkout {
                    let durationChange = ((duration - prev.duration) / prev.duration) * 100
                    ComparisonCard(
                        label: "Duration",
                        change: durationChange,
                        isPositive: durationChange <= 0 // Less time is better
                    )
                }
            }
        }
    }

    private var exerciseBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Breakdown")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 8) {
                ForEach(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }) { exerciseLog in
                    ExerciseSummaryRow(
                        exerciseLog: exerciseLog,
                        previousExerciseLog: findPreviousExerciseLog(for: exerciseLog)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func findPreviousExerciseLog(for exerciseLog: ExerciseLog) -> ExerciseLog? {
        guard let exercise = exerciseLog.exercise,
              let prev = previousWorkout else { return nil }

        return prev.exercises.first { $0.exercise?.id == exercise.id }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.groveSage)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ComparisonCard: View {
    let label: String
    let change: Double
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.subheadline)
                .foregroundStyle(isPositive ? Color.groveSage : Color.groveMutedRust)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%+.1f%%", change))
                    .font(.headline)
                    .foregroundStyle(isPositive ? Color.groveSage : Color.groveMutedRust)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExerciseSummaryRow: View {
    let exerciseLog: ExerciseLog
    let previousExerciseLog: ExerciseLog?

    private var completedSets: [SetLog] {
        exerciseLog.sets.filter { $0.isCompleted }.sorted { $0.setNumber < $1.setNumber }
    }

    private var exerciseVolume: Double {
        completedSets.reduce(0) { total, set in
            guard let weight = set.weight, let reps = set.reps else { return total }
            return total + (weight * Double(reps))
        }
    }

    private var bestSet: SetLog? {
        completedSets.max { a, b in
            let aVolume = (a.weight ?? 0) * Double(a.reps ?? 0)
            let bVolume = (b.weight ?? 0) * Double(b.reps ?? 0)
            return aVolume < bVolume
        }
    }

    private var previousBestSet: SetLog? {
        previousExerciseLog?.sets.filter { $0.isCompleted }.max { a, b in
            let aVolume = (a.weight ?? 0) * Double(a.reps ?? 0)
            let bVolume = (b.weight ?? 0) * Double(b.reps ?? 0)
            return aVolume < bVolume
        }
    }

    private var isPR: Bool {
        guard let best = bestSet,
              let prevBest = previousBestSet,
              let bestWeight = best.weight,
              let prevWeight = prevBest.weight else { return false }
        return bestWeight > prevWeight
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exerciseLog.exercise?.name ?? "Exercise")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(exerciseLog.status == .skipped ? .secondary : Color.groveText)
                        .strikethrough(exerciseLog.status == .skipped)

                    if isPR {
                        Text("PR")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.groveTerracotta)
                            .clipShape(Capsule())
                    }
                }

                if exerciseLog.status != .skipped {
                    Text(setsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Volume
            if exerciseLog.status != .skipped {
                Text(formatVolume(exerciseVolume))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)
            }
        }
        .padding()
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch exerciseLog.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.groveSage)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .foregroundStyle(.secondary)
        default:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    private var setsSummary: String {
        let sets = completedSets
        if sets.isEmpty { return "No sets completed" }

        // Show weight x reps for each set
        let descriptions = sets.compactMap { set -> String? in
            guard let weight = set.weight, let reps = set.reps else { return nil }
            if weight.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(weight))×\(reps)"
            } else {
                return String(format: "%.1f×%d", weight, reps)
            }
        }

        return descriptions.joined(separator: ", ")
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, ExerciseLog.self, SetLog.self, Exercise.self,
        configurations: config
    )

    let workout = Workout(name: "Push Day")
    workout.completedAt = Date()
    container.mainContext.insert(workout)

    let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, muscleSubgroup: "Middle")
    container.mainContext.insert(exercise)

    let exerciseLog = ExerciseLog(exercise: exercise, orderIndex: 0, targetSets: 3, targetReps: 10)
    exerciseLog.workout = workout
    exerciseLog.status = .completed
    container.mainContext.insert(exerciseLog)

    for i in 1...3 {
        let setLog = SetLog(setNumber: i, weight: 135, reps: 8)
        setLog.isCompleted = true
        setLog.exerciseLog = exerciseLog
        container.mainContext.insert(setLog)
    }

    return WorkoutSummaryView(workout: workout)
        .environment(WorkoutSessionManager())
        .modelContainer(container)
}
