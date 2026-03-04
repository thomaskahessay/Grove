import SwiftUI
import HealthKit

struct HealthKitConnectView: View {
    let workout: Workout
    let onConnect: (HKWorkout) -> Void
    let onSkip: () -> Void

    private let healthKitManager = HealthKitManager.shared

    @State private var candidates: [HKWorkout] = []
    @State private var recentWorkouts: [HKWorkout] = []
    @State private var bestMatch: HKWorkout?
    @State private var selectedWorkout: HKWorkout?
    @State private var isLoading = true
    @State private var isConnecting = false
    @State private var isBrowsing = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Looking for Apple Watch data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isBrowsing {
                    browseContent
                } else if let match = selectedWorkout ?? bestMatch {
                    matchContent(match)
                } else {
                    browseContent
                }
            }
            .navigationTitle("Apple Watch Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { onSkip() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await findMatches()
        }
    }

    // MARK: - Match Content (auto-matched workout)

    private func matchContent(_ match: HKWorkout) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "applewatch")
                .font(.system(size: 48))
                .foregroundStyle(Color.groveSage)

            VStack(spacing: 8) {
                Text("Apple Watch Workout Found")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("We found a matching workout from your Apple Watch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            workoutPreviewCard(match)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    connectMatch(match)
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Connect")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.groveSage)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isConnecting)

                Button {
                    isBrowsing = true
                } label: {
                    Text("Choose Different")
                        .font(.body)
                        .foregroundStyle(Color.groveSage)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Browse Content (no auto-match or user chose "Choose Different")

    private var browseContent: some View {
        VStack(spacing: 0) {
            if allWorkouts.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "applewatch.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Workouts Found")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("No Apple Watch workouts found on \(formattedWorkoutDay).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workouts on \(formattedWorkoutDay)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveTextSecondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(allWorkouts.enumerated()), id: \.element.uuid) { index, hkWorkout in
                                Button {
                                    selectedWorkout = hkWorkout
                                    isBrowsing = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "applewatch")
                                            .font(.body)
                                            .foregroundStyle(Color.groveSage)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(HealthKitManager.formattedWorkoutType(hkWorkout))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.groveText)

                                            Text(formatDateTime(hkWorkout.startDate))
                                                .font(.caption)
                                                .foregroundStyle(Color.groveTextSecondary)
                                        }

                                        Spacer()

                                        Text(HealthKitManager.formattedDuration(hkWorkout))
                                            .font(.caption)
                                            .foregroundStyle(Color.groveTextSecondary)

                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(Color.groveWarmSand)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }

                                if index < allWorkouts.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color.groveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                }
                .background(Color.groveBackground)
            }
        }
    }

    /// Combined and deduplicated list of overlap candidates + recent workouts
    private var allWorkouts: [HKWorkout] {
        var seen = Set<UUID>()
        var result: [HKWorkout] = []
        for w in candidates + recentWorkouts {
            if seen.insert(w.uuid).inserted {
                result.append(w)
            }
        }
        return result.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Shared Components

    private func workoutPreviewCard(_ hkWorkout: HKWorkout) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label(HealthKitManager.formattedWorkoutType(hkWorkout), systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(HealthKitManager.formattedDuration(hkWorkout))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label(formatDateTime(hkWorkout.startDate), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func findMatches() async {
        let startDate = workout.startedAt
        let endDate = workout.completedAt

        guard let endDate else {
            recentWorkouts = await healthKitManager.fetchWorkoutsForDay(date: startDate)
            isLoading = false
            return
        }

        let overlap = await healthKitManager.findOverlappingWorkouts(
            workoutStart: startDate,
            workoutEnd: endDate
        )
        let dayWorkouts = await healthKitManager.fetchWorkoutsForDay(date: startDate)

        candidates = overlap
        recentWorkouts = dayWorkouts
        bestMatch = healthKitManager.bestOverlapMatch(
            groveStart: startDate,
            groveEnd: endDate,
            candidates: overlap
        )
        isLoading = false
    }

    private var formattedWorkoutDay: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.startedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.startedAt) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: workout.startedAt)
        }
    }

    private func connectMatch(_ hkWorkout: HKWorkout) {
        isConnecting = true
        Task {
            await healthKitManager.populateWorkout(workout, from: hkWorkout)
            isConnecting = false
            onConnect(hkWorkout)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
