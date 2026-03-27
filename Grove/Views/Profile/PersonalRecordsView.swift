import SwiftUI
import SwiftData

struct PersonalRecordsView: View {
    @Query(sort: \PersonalRecord.achievedAt, order: .reverse) private var allRecords: [PersonalRecord]
    @Query private var users: [User]

    private var currentUser: User? { users.first }

    private var unitLabel: String {
        currentUser?.preferredUnits == .metric ? "kg" : "lbs"
    }

    /// Current max-weight PR per exercise, sorted by most recently achieved
    private var currentPRs: [PersonalRecord] {
        let maxWeightRecords = allRecords.filter { $0.type == .maxWeight }

        var bestByExercise: [UUID: PersonalRecord] = [:]
        for record in maxWeightRecords {
            guard let exerciseID = record.exercise?.id else { continue }
            if let existing = bestByExercise[exerciseID] {
                if record.value > existing.value || (record.value == existing.value && record.reps > existing.reps) {
                    bestByExercise[exerciseID] = record
                }
            } else {
                bestByExercise[exerciseID] = record
            }
        }

        return bestByExercise.values.sorted { $0.achievedAt > $1.achievedAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryHeader

                if currentPRs.isEmpty {
                    emptyState
                } else {
                    ForEach(currentPRs, id: \.id) { record in
                        PRGalleryRow(record: record, unitLabel: unitLabel)
                    }
                }
            }
            .padding()
        }
        .background(Color.groveBackground)
        .navigationTitle("Personal Records")
    }

    private var summaryHeader: some View {
        VStack(spacing: 8) {
            Text("\(currentPRs.count)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveTerracotta)

            Text(currentPRs.count == 1 ? "Exercise" : "Exercises")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(Color.groveWarmSand)

            Text("No personal records yet")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            Text("Complete workouts to start tracking your max weight per exercise.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - PR Gallery Row

private struct PRGalleryRow: View {
    let record: PersonalRecord
    let unitLabel: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(Color.groveTerracotta)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.exercise?.name ?? "Unknown Exercise")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)

                Text(record.achievedAt.formatted(.dateTime.month().day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.weight.formatted()) \(unitLabel)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.groveTerracotta)

                Text("\(record.reps) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
    }
}

#Preview {
    NavigationStack {
        PersonalRecordsView()
    }
    .modelContainer(.preview)
}
