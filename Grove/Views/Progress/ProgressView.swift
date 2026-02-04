import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { $0.completedAt != nil },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]

    @State private var selectedExercise: Exercise?
    @State private var selectedMetric: ProgressMetric = .estimatedOneRM
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var searchText = ""
    @State private var showingExercisePicker = false
    @State private var hasAutoSelectedExercise = false

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

        return exerciseUsage.values.sorted { $0.count > $1.count }
    }

    private var selectedExerciseCount: Int {
        guard let selected = selectedExercise else { return 0 }
        return exercisesWithHistory.first { $0.exercise.id == selected.id }?.count ?? 0
    }

    private var filteredExercises: [(exercise: Exercise, count: Int)] {
        if searchText.isEmpty {
            return exercisesWithHistory
        }
        return exercisesWithHistory.filter {
            $0.exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if exercisesWithHistory.isEmpty {
                        emptyStateView
                    } else {
                        // Exercise header at top
                        exerciseHeader

                        if let exercise = selectedExercise {
                            let dataPoints = getDataPoints(for: exercise)
                            let highestWeight = getHighestWeight(for: exercise)

                            // Chart with floating stats
                            if dataPoints.isEmpty {
                                noDataView
                            } else {
                                chartSection(dataPoints: dataPoints, highestWeight: highestWeight)
                            }

                            // Minimal filter row
                            filterRow
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
            .background(Color.groveBackground)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet(
                    exercises: exercisesWithHistory,
                    selectedExercise: $selectedExercise,
                    searchText: $searchText
                )
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                if !hasAutoSelectedExercise && selectedExercise == nil,
                   let first = exercisesWithHistory.first {
                    selectedExercise = first.exercise
                    hasAutoSelectedExercise = true
                }
            }
            .onChange(of: completedWorkouts.count) { _, _ in
                if selectedExercise == nil, let first = exercisesWithHistory.first {
                    selectedExercise = first.exercise
                }
            }
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedExercise?.name ?? "Select Exercise")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)

                    if selectedExercise != nil {
                        Text("\(selectedExerciseCount) workouts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.groveSage)
            }
            .padding(16)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart Section

    private func chartSection(dataPoints: [ProgressDataPoint], highestWeight: Double?) -> some View {
        let currentValue = dataPoints.last?.value ?? 0
        let bestValue = dataPoints.map { $0.value }.max() ?? 0
        let previousValue = dataPoints.dropLast().last?.value
        let change: Double? = previousValue.map { currentValue - $0 }

        return VStack(spacing: 12) {
            // Stats row above chart
            HStack(spacing: 24) {
                FloatingStat(
                    value: formatValue(currentValue),
                    label: "Current",
                    color: Color.groveSage
                )

                if let change = change, dataPoints.count > 1 {
                    FloatingStat(
                        value: formatChange(change),
                        label: "Change",
                        color: change >= 0 ? Color.groveSage : Color.groveMutedRust
                    )
                }

                FloatingStat(
                    value: formatValue(bestValue),
                    label: "Best",
                    color: Color.groveTerracotta
                )

                if let weight = highestWeight {
                    FloatingStat(
                        value: formatWeight(weight),
                        label: "Max",
                        color: Color.groveText
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Chart with tooltip support
            ExerciseProgressChart(
                dataPoints: dataPoints,
                metric: selectedMetric
            )
            .frame(height: 260)
        }
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(spacing: 12) {
            // Metric selector
            Menu {
                ForEach(ProgressMetric.allCases, id: \.self) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        HStack {
                            Text(metric.fullName)
                            if selectedMetric == metric {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedMetric.shortName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.groveSage)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.groveSage.opacity(0.12))
                .clipShape(Capsule())
            }

            // Time range selector
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
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.groveSage)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.groveSage.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Color.groveWarmSand)

            Text("No workout data yet")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            Text("Complete some workouts to see your progress here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

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

    // MARK: - Data Processing

    private func getDataPoints(for exercise: Exercise) -> [ProgressDataPoint] {
        let cutoffDate = selectedTimeRange.cutoffDate
        var dataPoints: [ProgressDataPoint] = []

        for workout in completedWorkouts {
            guard let completedAt = workout.completedAt,
                  completedAt >= cutoffDate else { continue }

            for log in workout.exercises {
                guard log.exercise?.id == exercise.id,
                      log.status == .completed else { continue }

                let completedSets = log.sets.filter { $0.isCompleted && $0.weight != nil && $0.reps != nil }
                guard !completedSets.isEmpty else { continue }

                let value: Double
                switch selectedMetric {
                case .estimatedOneRM:
                    value = completedSets.compactMap { calculateOneRM(weight: $0.weight!, reps: $0.reps!) }.max() ?? 0
                case .bestSet:
                    value = completedSets.compactMap { ($0.weight ?? 0) * Double($0.reps ?? 0) }.max() ?? 0
                case .totalVolume:
                    value = completedSets.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
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
                guard log.exercise?.id == exercise.id,
                      log.status == .completed else { continue }

                for set in log.sets where set.isCompleted {
                    if let weight = set.weight {
                        if maxWeight == nil || weight > maxWeight! {
                            maxWeight = weight
                        }
                    }
                }
            }
        }

        return maxWeight
    }

    private func calculateOneRM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }

        if reps == 1 {
            return weight
        } else if reps <= 10 {
            return weight * (36.0 / (37.0 - Double(reps)))
        } else {
            return weight * (1.0 + Double(reps) / 30.0)
        }
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

// MARK: - Supporting Types

enum ProgressMetric: String, CaseIterable {
    case estimatedOneRM = "1RM"
    case bestSet = "Best"
    case totalVolume = "Volume"

    var shortName: String { rawValue }

    var fullName: String {
        switch self {
        case .estimatedOneRM: return "Estimated 1RM"
        case .bestSet: return "Best Set (Weight × Reps)"
        case .totalVolume: return "Total Volume"
        }
    }

    var unit: String { "lbs" }
}

enum TimeRange: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case allTime = "All"

    var label: String { rawValue }

    var fullLabel: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .allTime: return "All Time"
        }
    }

    var cutoffDate: Date {
        let calendar = Calendar.current
        switch self {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        case .allTime:
            return Date.distantPast
        }
    }
}

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Floating Stat

struct FloatingStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    let exercises: [(exercise: Exercise, count: Int)]
    @Binding var selectedExercise: Exercise?
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss

    private var filteredExercises: [(exercise: Exercise, count: Int)] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises, id: \.exercise.id) { item in
                    Button {
                        selectedExercise = item.exercise
                        searchText = ""
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exercise.name)
                                    .font(.body)
                                    .foregroundStyle(Color.groveText)

                                Text("\(item.count) workouts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedExercise?.id == item.exercise.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.groveSage)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedExercise?.id == item.exercise.id
                            ? Color.groveSage.opacity(0.1)
                            : Color.clear
                    )
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        searchText = ""
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chart View

struct ExerciseProgressChart: View {
    let dataPoints: [ProgressDataPoint]
    let metric: ProgressMetric

    @State private var selectedPoint: ProgressDataPoint?

    var body: some View {
        Chart(dataPoints) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value(metric.shortName, point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.groveSage.opacity(0.25), Color.groveSage.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.shortName, point.value)
            )
            .foregroundStyle(Color.groveSage)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.shortName, point.value)
            )
            .foregroundStyle(selectedPoint?.id == point.id ? Color.groveTerracotta : Color.groveSage)
            .symbolSize(selectedPoint?.id == point.id ? 60 : 20)

            // Selection indicator
            if let selected = selectedPoint, selected.id == point.id {
                RuleMark(x: .value("Date", point.date))
                    .foregroundStyle(Color.groveSage.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.groveWarmSand.opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.groveWarmSand.opacity(0.5))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedPoint = closestPoint(to: date)
                                }
                            }
                            .onEnded { _ in
                                // Keep selection visible for a moment then clear
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedPoint = nil
                                    }
                                }
                            }
                    )
            }
        }
        .chartBackground { proxy in
            // Tooltip
            if let selected = selectedPoint {
                GeometryReader { geometry in
                    if let x = proxy.position(forX: selected.date),
                       let y = proxy.position(forY: selected.value) {
                        TooltipView(date: selected.date, value: selected.value, metric: metric)
                            .position(
                                x: min(max(x, 50), geometry.size.width - 50),
                                y: max(y - 45, 30)
                            )
                    }
                }
            }
        }
    }

    private func closestPoint(to date: Date) -> ProgressDataPoint? {
        dataPoints.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}

// MARK: - Tooltip View

struct TooltipView: View {
    let date: Date
    let value: Double
    let metric: ProgressMetric

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var formattedValue: String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(formattedValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveText)

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Preview

#Preview("With Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: User.self, Exercise.self, Workout.self, ExerciseLog.self, SetLog.self,
        configurations: config
    )

    let benchPress = Exercise(name: "Bench Press", muscleGroup: .chest)
    let squat = Exercise(name: "Squat", muscleGroup: .legs)
    container.mainContext.insert(benchPress)
    container.mainContext.insert(squat)

    for i in 0..<10 {
        let workout = Workout(name: "Push Day")
        workout.startedAt = Calendar.current.date(byAdding: .day, value: -i * 7, to: Date())!
        workout.completedAt = workout.startedAt.addingTimeInterval(3600)
        container.mainContext.insert(workout)

        let log = ExerciseLog(exercise: benchPress, orderIndex: 0)
        log.workout = workout
        log.status = .completed
        container.mainContext.insert(log)

        let baseWeight = 135.0 + Double(10 - i) * 5
        for setNum in 1...3 {
            let set = SetLog(setNumber: setNum, weight: baseWeight, reps: 8)
            set.isCompleted = true
            set.exerciseLog = log
            log.sets.append(set)
            container.mainContext.insert(set)
        }
    }

    return ProgressView()
        .modelContainer(container)
}

#Preview("Empty") {
    ProgressView()
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseLog.self, SetLog.self], inMemory: true)
}
