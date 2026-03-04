import SwiftUI

struct WorkoutShareCardView: View {
    let workout: Workout
    let prCount: Int
    let prSetIDs: Set<UUID>
    let unitLabel: String
    let colorScheme: ColorScheme
    var detailed: Bool = false

    private var formattedDate: String {
        guard let completedAt = workout.completedAt else { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = detailed ? "EEEE, MMM d, yyyy" : "MMM d, yyyy"
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

    private var totalSets: Int {
        workout.exercises.reduce(0) { total, exerciseLog in
            total + exerciseLog.sets.filter { $0.isCompleted }.count
        }
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

    private var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk", totalVolume / 1000)
        } else {
            return String(format: "%.0f", totalVolume)
        }
    }

    private var sortedExercises: [ExerciseLog] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        if detailed {
            detailedBody
        } else {
            compactBody
        }
    }

    // MARK: - Compact Layout

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBar
            workoutTitle

            statsRow
                .padding(.vertical, 8)
                .background(Color.groveWarmSand.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            compactExerciseList

            footer
        }
        .padding(16)
        .background(Color.groveBackground)
        .frame(width: 340)
        .environment(\.colorScheme, colorScheme)
    }

    // MARK: - Detailed Layout

    private var detailedBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.title2.bold())
                    .foregroundStyle(Color.groveText)
                HStack(spacing: 6) {
                    Text(formattedDuration)
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                    if let subtitle = healthKitSubtitle {
                        Text("·")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveTextSecondary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }
            }

            Divider()

            statsRow
                .padding(.vertical, 10)
                .background(Color.groveWarmSand.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            detailedExerciseList

            footer
        }
        .padding(20)
        .background(Color.groveBackground)
        .frame(width: 390)
        .environment(\.colorScheme, colorScheme)
    }

    // MARK: - Shared Components

    private var headerBar: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.groveSage)
                Text("Grove")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.groveSage)
            }
            Spacer()
            if detailed {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formattedDate) · \(formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)
                    if let subtitle = healthKitSubtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                }
            }
        }
    }

    private var workoutTitle: some View {
        Text(workout.name)
            .font(.title3.bold())
            .foregroundStyle(Color.groveText)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            shareStatColumn(value: "\(workout.completedExerciseCount)", label: "Exercises")
            shareStatColumn(value: "\(totalSets)", label: "Sets")
            shareStatColumn(value: "\(formattedVolume) \(unitLabel)", label: "Volume")
            if prCount > 0 {
                shareStatColumn(value: "\(prCount)", label: prCount == 1 ? "PR" : "PRs", accent: true)
            }
        }
    }

    private var healthKitSubtitle: String? {
        var parts: [String] = []
        if let cal = workout.caloriesBurned {
            parts.append("\(Int(cal)) kcal")
        }
        if let avgHR = workout.heartRateAvg {
            parts.append("\(Int(avgHR)) avg bpm")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var footer: some View {
        Text("Tracked with Grove")
            .font(.caption2)
            .foregroundStyle(Color.groveTextSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }

    // MARK: - Compact Exercise List (all exercises, no cap)

    private var compactExerciseList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(sortedExercises, id: \.id) { exerciseLog in
                compactExerciseRow(exerciseLog)
            }
        }
    }

    // MARK: - Detailed Exercise List

    private var detailedExerciseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            let exercises = sortedExercises

            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exerciseLog in
                detailedExerciseRow(exerciseLog)

                if index < exercises.count - 1 {
                    Divider()
                        .padding(.leading, 28)
                }
            }
        }
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Row Helpers

    private func compactExerciseRow(_ exerciseLog: ExerciseLog) -> some View {
        HStack(spacing: 6) {
            Image(systemName: exerciseLog.status == .completed ? "checkmark.circle.fill" : "forward.fill")
                .font(.caption2)
                .foregroundStyle(exerciseLog.status == .completed ? Color.groveSage : Color.groveMutedRust)
                .frame(width: 14)

            Text(exerciseLog.exercise?.name ?? "Unknown")
                .font(.caption)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(compactSummary(exerciseLog))
                .font(.caption2)
                .foregroundStyle(Color.groveTextSecondary)
                .fixedSize()
        }
    }

    private func detailedExerciseRow(_ exerciseLog: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: exerciseLog.status == .completed ? "checkmark.circle.fill" : "forward.fill")
                    .font(.caption)
                    .foregroundStyle(exerciseLog.status == .completed ? Color.groveSage : Color.groveMutedRust)

                Text(exerciseLog.exercise?.name ?? "Unknown")
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

            let completedSets = exerciseLog.sets
                .filter { $0.isCompleted }
                .sorted { $0.setNumber < $1.setNumber }

            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(completedSets, id: \.id) { setLog in
                        HStack(spacing: 4) {
                            Text("Set \(setLog.setNumber):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 46, alignment: .leading)

                            Text("\(formatWeight(setLog.weight ?? 0)) \(unitLabel)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)

                            Text("×")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(setLog.reps ?? 0) reps")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)

                            if prSetIDs.contains(setLog.id) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.groveTerracotta)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Stat Column

    private func shareStatColumn(value: String, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(accent ? Color.groveTerracotta : Color.groveText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(accent ? Color.groveTerracotta.opacity(0.8) : Color.groveTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Compact Summary

    /// Same weight+reps → "3×10 @ 135 lbs"
    /// Same weight, varying reps → "135 lbs · 10,8,6"
    /// Varying weights → "3 sets · 135-155 lbs"
    private func compactSummary(_ exerciseLog: ExerciseLog) -> String {
        let completed = exerciseLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }

        if completed.isEmpty {
            return exerciseLog.status == .skipped ? "Skipped" : ""
        }

        let pairs: [(Double, Int)] = completed.compactMap { set in
            guard let w = set.weight, let r = set.reps else { return nil }
            return (w, r)
        }

        guard !pairs.isEmpty else { return "\(completed.count) sets" }

        let allSameWeight = pairs.allSatisfy { $0.0 == pairs[0].0 }
        let allSameReps = pairs.allSatisfy { $0.1 == pairs[0].1 }

        if allSameWeight && allSameReps {
            return "\(pairs.count)×\(pairs[0].1) @ \(formatWeight(pairs[0].0)) \(unitLabel)"
        } else if allSameWeight {
            let reps = pairs.map { "\($0.1)" }.joined(separator: ",")
            return "\(formatWeight(pairs[0].0)) \(unitLabel) · \(reps)"
        } else {
            let minW = pairs.map(\.0).min()!
            let maxW = pairs.map(\.0).max()!
            return "\(pairs.count) sets · \(formatWeight(minW))-\(formatWeight(maxW)) \(unitLabel)"
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight == floor(weight) ? "\(Int(weight))" : String(format: "%.1f", weight)
    }
}
