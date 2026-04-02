import SwiftUI
import SwiftData

struct ShareToFeedSheet: View {
    let workout: Workout
    var prExerciseNames: Set<String> = []
    @Environment(CloudKitSocialService.self) private var socialService
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]

    @State private var shareWorkoutName: Bool = true
    @State private var shareDuration: Bool = true
    @State private var shareExercises: Bool = false
    @State private var shareWeights: Bool = false
    @State private var sharePRs: Bool = true
    @State private var isSharing = false

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Workout info
                VStack(spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                    if let date = workout.completedAt {
                        Text(formattedDate(date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

                // Sharing toggles
                VStack(spacing: 16) {
                    Toggle("Workout Name", isOn: $shareWorkoutName)
                    Toggle("Duration", isOn: $shareDuration)
                    Toggle("Exercises", isOn: $shareExercises)
                    Toggle("Weights", isOn: $shareWeights)
                    if !prExerciseNames.isEmpty {
                        Toggle("Personal Records", isOn: $sharePRs)
                    }
                }
                .font(.subheadline)
                .tint(.groveSage)
                .padding(16)
                .background(Color.groveCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                // Share button
                Button {
                    Task { await shareToFeed() }
                } label: {
                    if isSharing {
                        SwiftUI.ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Share to Feed")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.groveSage)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .disabled(isSharing)
            }
            .padding()
            .background(Color.groveBackground)
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Pre-fill from user defaults
                if let user {
                    shareWorkoutName = user.shareWorkoutName
                    shareDuration = user.shareDuration
                    shareExercises = user.shareExercises
                    shareWeights = user.shareWeights
                    sharePRs = user.sharePRs
                }
            }
        }
    }

    private func shareToFeed() async {
        isSharing = true

        // Apply sharing preferences to workout
        workout.isShared = true
        workout.shareWorkoutName = shareWorkoutName
        workout.shareDuration = shareDuration
        workout.shareExercises = shareExercises
        workout.shareWeights = shareWeights
        workout.sharePRs = sharePRs

        if let user {
            let prNames = sharePRs ? prExerciseNames : []
            await socialService.shareWorkout(workout, user: user, prExerciseNames: prNames)
            await socialService.updateMyStats(user: user)
        }

        isSharing = false
        dismiss()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
