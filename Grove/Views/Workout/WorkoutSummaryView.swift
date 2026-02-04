import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]

    let workout: Workout

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

    private var skippedCount: Int {
        workout.exercises.filter { $0.status == .skipped }.count
    }

    private var personalRecords: [(name: String, weight: Double, reps: Int)] {
        workout.exercises.compactMap { exerciseLog in
            guard exerciseLog.status != .skipped else { return nil }
            let best = exerciseLog.sets.filter { $0.isCompleted }.max { a, b in
                (a.weight ?? 0) * Double(a.reps ?? 0) < (b.weight ?? 0) * Double(b.reps ?? 0)
            }
            let prevLog = findPreviousExerciseLog(for: exerciseLog)
            let prevBest = prevLog?.sets.filter { $0.isCompleted }.max { a, b in
                (a.weight ?? 0) * Double(a.reps ?? 0) < (b.weight ?? 0) * Double(b.reps ?? 0)
            }
            guard let bestSet = best,
                  let prevBestSet = prevBest,
                  let bestWeight = bestSet.weight,
                  let prevWeight = prevBestSet.weight,
                  bestWeight > prevWeight,
                  let reps = bestSet.reps else { return nil }
            return (exerciseLog.exercise?.name ?? "Exercise", bestWeight, reps)
        }
    }

    @State private var showConfetti = false

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

                    // Personal records (if any)
                    if !personalRecords.isEmpty {
                        prSection
                    }

                    // Exercise breakdown
                    exerciseBreakdownSection

                    // Done button
                    doneButton
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .padding()
            }
            .background(Color.groveBackground)
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if showConfetti {
                    ConfettiView()
                }
            }
            .onAppear {
                showConfetti = true
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

            Text(completionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var completionSummary: String {
        let total = workout.exercises.count
        let completed = exerciseCount
        var summary = "\(completed) of \(total) exercises completed"
        if skippedCount > 0 {
            summary += " (\(skippedCount) skipped)"
        }
        return summary
    }

    private var exerciseCount: Int {
        workout.exercises.filter { $0.status != .skipped }.count
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "figure.strengthtraining.traditional",
                value: "\(exerciseCount)",
                label: "Exercises"
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

            if let change = volumeChange {
                ComparisonCard(
                    label: "Volume",
                    change: change,
                    isPositive: change >= 0
                )
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("New Personal Records", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Color.groveTerracotta)

            VStack(spacing: 8) {
                ForEach(personalRecords, id: \.name) { record in
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.groveTerracotta)

                        Text(record.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveText)

                        Spacer()

                        Text(formatPRWeight(record.weight) + " × \(record.reps)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveTerracotta)
                    }
                    .padding()
                    .background(Color.groveTerracotta.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var doneButton: some View {
        Button {
            sessionManager.dismissSummary()
        } label: {
            Text("Done")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.groveSage)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private func formatPRWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) lbs"
        }
        return String(format: "%.1f lbs", weight)
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

    private var setsVary: Bool {
        guard completedSets.count > 1 else { return false }
        let volumes = completedSets.map { ($0.weight ?? 0) * Double($0.reps ?? 0) }
        return Set(volumes).count > 1
    }

    private func isBestSet(_ set: SetLog) -> Bool {
        guard setsVary, let best = bestSet else { return false }
        return set.setNumber == best.setNumber
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
                    setsSummaryText
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

    private var setsSummaryText: Text {
        let sets = completedSets
        guard !sets.isEmpty else {
            return Text("No sets completed")
        }

        var result = Text("")
        for (index, set) in sets.enumerated() {
            if index > 0 {
                result = result + Text(", ")
            }
            let desc = formatSetDescription(set)
            if isBestSet(set) {
                result = result + Text(Image(systemName: "star.fill")).foregroundColor(Color.groveTerracotta).font(.caption2) + Text(" \(desc)").bold()
            } else {
                result = result + Text(desc)
            }
        }
        return result
    }

    private func formatSetDescription(_ set: SetLog) -> String {
        guard let weight = set.weight, let reps = set.reps else { return "—" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))×\(reps)"
        }
        return String(format: "%.1f×%d", weight, reps)
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
    let ctx = container.mainContext

    // Exercises
    let bench = Exercise(name: "Bench Press", muscleGroup: .chest, muscleSubgroup: "Middle")
    let ohp = Exercise(name: "Overhead Press", muscleGroup: .shoulders, muscleSubgroup: "Front")
    let laterals = Exercise(name: "Lateral Raises", muscleGroup: .shoulders, muscleSubgroup: "Side")
    ctx.insert(bench)
    ctx.insert(ohp)
    ctx.insert(laterals)

    // --- Previous workout (for PR comparison) ---
    let prevWorkout = Workout(name: "Push Day")
    prevWorkout.startedAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    prevWorkout.completedAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    ctx.insert(prevWorkout)

    let prevBenchLog = ExerciseLog(exercise: bench, orderIndex: 0, targetSets: 3, targetReps: 8)
    prevBenchLog.workout = prevWorkout
    prevBenchLog.status = .completed
    ctx.insert(prevBenchLog)
    for i in 1...3 {
        let s = SetLog(setNumber: i, weight: 125, reps: 8)
        s.isCompleted = true
        s.exerciseLog = prevBenchLog
        ctx.insert(s)
    }

    let prevOHPLog = ExerciseLog(exercise: ohp, orderIndex: 1, targetSets: 3, targetReps: 10)
    prevOHPLog.workout = prevWorkout
    prevOHPLog.status = .completed
    ctx.insert(prevOHPLog)
    for i in 1...3 {
        let s = SetLog(setNumber: i, weight: 85, reps: 10)
        s.isCompleted = true
        s.exerciseLog = prevOHPLog
        ctx.insert(s)
    }

    // --- Current workout ---
    let workout = Workout(name: "Push Day")
    workout.completedAt = Date()
    ctx.insert(workout)

    // Bench Press: varying sets (star on set 2), PR vs previous 125
    let benchLog = ExerciseLog(exercise: bench, orderIndex: 0, targetSets: 3, targetReps: 8)
    benchLog.workout = workout
    benchLog.status = .completed
    ctx.insert(benchLog)
    let benchWeights: [(Double, Int)] = [(135, 8), (145, 8), (135, 6)]
    for (i, (w, r)) in benchWeights.enumerated() {
        let s = SetLog(setNumber: i + 1, weight: w, reps: r)
        s.isCompleted = true
        s.exerciseLog = benchLog
        ctx.insert(s)
    }

    // Overhead Press: varying sets (star on set 1), PR vs previous 85
    let ohpLog = ExerciseLog(exercise: ohp, orderIndex: 1, targetSets: 3, targetReps: 10)
    ohpLog.workout = workout
    ohpLog.status = .completed
    ctx.insert(ohpLog)
    let ohpWeights: [(Double, Int)] = [(95, 10), (105, 8), (105, 6)]
    for (i, (w, r)) in ohpWeights.enumerated() {
        let s = SetLog(setNumber: i + 1, weight: w, reps: r)
        s.isCompleted = true
        s.exerciseLog = ohpLog
        ctx.insert(s)
    }

    // Lateral Raises: skipped
    let lateralLog = ExerciseLog(exercise: laterals, orderIndex: 2, targetSets: 3, targetReps: 12)
    lateralLog.workout = workout
    lateralLog.status = .skipped
    ctx.insert(lateralLog)

    return WorkoutSummaryView(workout: workout)
        .environment(WorkoutSessionManager())
        .modelContainer(container)
}
