import SwiftUI
import SwiftData
import Charts

struct ExerciseProgressDetailView: View {
    let initialExercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { $0.completedAt != nil },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]
    @Query private var users: [User]

    @State private var selectedExercise: Exercise?
    @State private var selectedMetric: ProgressMetric = .maxWeight
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var showingExercisePicker = false
    @State private var searchText = ""

    private var currentUser: User? { users.first }

    private var unitLabel: String {
        currentUser?.preferredUnits == .metric ? "kg" : "lbs"
    }

    private var activeExercise: Exercise {
        selectedExercise ?? initialExercise
    }

    private var exercisesWithHistory: [(exercise: Exercise, count: Int)] {
        var exerciseUsage: [UUID: (exercise: Exercise, count: Int)] = [:]
        for workout in completedWorkouts {
            for log in workout.exercises where log.exercise != nil && log.status == .completed {
                let exercise = log.exercise!
                if let existing = exerciseUsage[exercise.id] {
                    exerciseUsage[exercise.id] = (exercise, existing.count + 1)
                } else {
                    exerciseUsage[exercise.id] = (exercise, 1)
                }
            }
        }
        return exerciseUsage.values.sorted { $0.exercise.name < $1.exercise.name }
    }

    private var exerciseCount: Int {
        exercisesWithHistory.first { $0.exercise.id == activeExercise.id }?.count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                exerciseHeader

                let dataPoints = getDataPoints(for: activeExercise)
                let highestWeight = getHighestWeight(for: activeExercise)

                if dataPoints.isEmpty {
                    noDataView
                } else {
                    chartSection(dataPoints: dataPoints, highestWeight: highestWeight)
                }

                filterRow

                let recentWorkouts = recentWorkouts(for: activeExercise)
                if !recentWorkouts.isEmpty {
                    recentWorkoutsSection(workouts: recentWorkouts)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .background(Color.groveBackground)
        .navigationTitle(activeExercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedExercise == nil {
                selectedExercise = initialExercise
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(
                exercises: exercisesWithHistory,
                selectedExercise: Binding(
                    get: { selectedExercise },
                    set: { selectedExercise = $0 }
                ),
                searchText: $searchText
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeExercise.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)

                    Text("\(exerciseCount) workouts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.groveSage)
            }
            .padding(16)
            .contentShape(Rectangle())
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.02), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart

    private func chartSection(dataPoints: [ProgressDataPoint], highestWeight: Double?) -> some View {
        let currentValue = dataPoints.last?.value ?? 0
        let bestValue = dataPoints.map { $0.value }.max() ?? 0
        let previousValue = dataPoints.dropLast().last?.value
        let change: Double? = previousValue.map { currentValue - $0 }

        return VStack(spacing: 12) {
            HStack(spacing: 24) {
                FloatingStat(value: formatValue(currentValue), label: "Current", color: Color.groveSage)

                if let change = change, dataPoints.count > 1 {
                    FloatingStat(
                        value: formatChange(change),
                        label: "Change",
                        color: change >= 0 ? Color.groveSage : Color.groveMutedRust
                    )
                }

                FloatingStat(value: formatValue(bestValue), label: "Best", color: Color.groveTerracotta)

                if !activeExercise.isBodyweight, let weight = highestWeight {
                    FloatingStat(value: formatWeight(weight), label: "Max", color: Color.groveText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)

            ExerciseProgressChart(dataPoints: dataPoints, metric: selectedMetric)
                .frame(height: 260)
        }
    }

    // MARK: - Filter

    private var filterRow: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(ProgressMetric.allCases, id: \.self) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        HStack {
                            Text(metric.fullName(isBodyweight: activeExercise.isBodyweight))
                            if selectedMetric == metric {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedMetric.shortName(isBodyweight: activeExercise.isBodyweight))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.groveSage)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity)

            Menu {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        selectedTimeRange = range
                    } label: {
                        HStack {
                            Text(range.fullLabel)
                            if selectedTimeRange == range {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedTimeRange.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.groveSage)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Empty

    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(Color.groveWarmSand)
            Text("No data in this time range")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }

    // MARK: - Recent Workouts

    private func recentWorkouts(for exercise: Exercise) -> [(workout: Workout, log: ExerciseLog)] {
        completedWorkouts.compactMap { workout in
            guard let log = workout.exercises.first(where: {
                $0.exercise?.id == exercise.id && $0.status == .completed
            }) else { return nil }
            return (workout, log)
        }
        .prefix(5)
        .map { $0 }
    }

    private func recentWorkoutsSection(workouts: [(workout: Workout, log: ExerciseLog)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 0) {
                ForEach(Array(workouts.enumerated()), id: \.element.workout.id) { index, item in
                    NavigationLink(destination: WorkoutDetailView(workout: item.workout)) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.groveSage)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.workout.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.groveText)

                                let completedSets = item.log.sets.filter { $0.isCompleted && !$0.isWarmup }
                                let maxWeight = completedSets.compactMap { $0.weight }.max()
                                let setCount = completedSets.count

                                HStack(spacing: 6) {
                                    if let date = item.workout.completedAt {
                                        Text(date, style: .date)
                                    }
                                    if setCount > 0 {
                                        Text("·")
                                        Text("\(setCount) sets")
                                        if let weight = maxWeight {
                                            Text("·")
                                            Text("\(formatWeight(weight)) \(unitLabel)")
                                        }
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < workouts.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        }
    }

    // MARK: - Data

    private func getDataPoints(for exercise: Exercise) -> [ProgressDataPoint] {
        let cutoffDate = selectedTimeRange.cutoffDate
        var dataPoints: [ProgressDataPoint] = []
        let isBW = exercise.isBodyweight

        for workout in completedWorkouts {
            guard let completedAt = workout.completedAt,
                  completedAt >= cutoffDate else { continue }

            for log in workout.exercises {
                guard log.exercise?.id == exercise.id,
                      log.status == .completed else { continue }

                let completedSets = log.sets.filter { $0.isCompleted && !$0.isWarmup && $0.reps != nil }
                guard !completedSets.isEmpty else { continue }

                let value: Double
                if isBW {
                    // Bodyweight metrics: reps-based
                    switch selectedMetric {
                    case .maxWeight:
                        // "Max Reps" — highest reps in a single set
                        value = Double(completedSets.compactMap { $0.reps }.max() ?? 0)
                    case .bestSet:
                        // "Total Reps" — sum of all reps
                        value = Double(completedSets.compactMap { $0.reps }.reduce(0, +))
                    case .totalVolume:
                        // For weighted bodyweight sets, show volume; for pure bodyweight, show total reps
                        let weightedVolume = completedSets.filter { $0.bodyweightModifier == .weighted && $0.weight != nil }
                            .reduce(0.0) { $0 + ($1.weight! * Double($1.reps ?? 0)) }
                        if weightedVolume > 0 {
                            value = weightedVolume
                        } else {
                            value = Double(completedSets.compactMap { $0.reps }.reduce(0, +))
                        }
                    }
                } else {
                    // Standard weighted metrics
                    let weightedSets = completedSets.filter { $0.weight != nil }
                    guard !weightedSets.isEmpty else { continue }

                    switch selectedMetric {
                    case .maxWeight:
                        value = weightedSets.compactMap { $0.weight }.max() ?? 0
                    case .bestSet:
                        value = weightedSets.compactMap { ($0.weight ?? 0) * Double($0.reps ?? 0) }.max() ?? 0
                    case .totalVolume:
                        value = weightedSets.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
                    }
                }

                if value > 0 {
                    dataPoints.append(ProgressDataPoint(date: completedAt, value: value))
                }
            }
        }

        return dataPoints.sorted { $0.date < $1.date }
    }

    private func getHighestWeight(for exercise: Exercise) -> Double? {
        var maxWeight: Double?
        for workout in completedWorkouts {
            for log in workout.exercises {
                guard log.exercise?.id == exercise.id, log.status == .completed else { continue }
                for set in log.sets where set.isCompleted && !set.isWarmup {
                    if let weight = set.weight {
                        if maxWeight == nil || weight > maxWeight! { maxWeight = weight }
                    }
                }
            }
        }
        return maxWeight
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }

    private func formatChange(_ change: Double) -> String {
        let prefix = change >= 0 ? "+" : ""
        if abs(change) >= 1000 {
            return prefix + String(format: "%.1fk", change / 1000)
        } else if change == floor(change) {
            return prefix + String(format: "%.0f", change)
        } else {
            return prefix + String(format: "%.1f", change)
        }
    }
}
