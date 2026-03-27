import Foundation
import SwiftData

/// Detects and records personal records after workout completion.
/// A PR is simply the highest weight ever lifted for an exercise, regardless of reps.
struct PRDetectionService {

    /// Result of PR detection for a single exercise
    struct PRResult {
        let exercise: Exercise
        let newPR: PersonalRecord

        var hasPR: Bool { true }
    }

    /// Checks a completed workout for new PRs and saves them.
    /// First workout for an exercise establishes a baseline (not flagged as PR).
    /// Subsequent workouts that beat the baseline are flagged as new PRs.
    static func detectAndSavePRs(
        for workout: Workout,
        user: User,
        context: ModelContext
    ) -> [PRResult] {
        var results: [PRResult] = []

        for exerciseLog in workout.exercises {
            guard let exercise = exerciseLog.exercise,
                  exerciseLog.status == .completed else { continue }

            let completedSets = exerciseLog.sets.filter { $0.isCompleted && $0.weight != nil && $0.reps != nil }
            guard !completedSets.isEmpty else { continue }

            // Find the heaviest weight from this workout's sets
            var bestWeightSet: SetLog?
            var bestWeight: Double = 0

            for set in completedSets {
                guard let weight = set.weight else { continue }
                if weight > bestWeight || (weight == bestWeight && (set.reps ?? 0) > (bestWeightSet?.reps ?? 0)) {
                    bestWeight = weight
                    bestWeightSet = set
                }
            }

            guard let set = bestWeightSet else { continue }

            // Get current PR for this exercise (highest weight ever)
            let currentPR = getCurrentPR(for: exercise, user: user, context: context)

            // Only save if this beats or establishes the record
            // Also update if same weight but more reps
            let currentValue = currentPR?.value ?? 0
            let currentReps = currentPR?.reps ?? 0
            if bestWeight > currentValue || (bestWeight == currentValue && (set.reps ?? 0) > currentReps) {
                let pr = PersonalRecord(
                    exercise: exercise,
                    weight: set.weight!,
                    reps: set.reps!,
                    achievedAt: workout.completedAt ?? Date(),
                    setLogID: set.id
                )
                pr.user = user
                context.insert(pr)

                // Only flag as a "new PR" if beating an existing record (not a first-time baseline)
                if currentPR != nil {
                    results.append(PRResult(exercise: exercise, newPR: pr))
                }
            }
        }

        try? context.save()
        return results
    }

    /// Gets the current PR (highest weight) for an exercise
    private static func getCurrentPR(
        for exercise: Exercise,
        user: User,
        context: ModelContext
    ) -> PersonalRecord? {
        let exerciseID = exercise.id

        // Fetch all PRs for this exercise, filter to maxWeight type in memory
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { pr in
                pr.exercise?.id == exerciseID
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        return (try? context.fetch(descriptor))?.first { $0.type == .maxWeight }
    }

    /// One-time migration: fixes reps on existing PRs that may have stored the wrong set's reps.
    /// For each PR, finds all completed sets in the linked workout for the same exercise at the PR weight,
    /// and updates reps to the maximum.
    static func fixExistingPRReps(context: ModelContext) {
        let descriptor = FetchDescriptor<PersonalRecord>()
        guard let allPRs = try? context.fetch(descriptor) else { return }

        for pr in allPRs where pr.type == .maxWeight {
            guard let setLogID = pr.setLogID,
                  let exercise = pr.exercise else { continue }

            // Find the SetLog this PR references
            let setDescriptor = FetchDescriptor<SetLog>()
            guard let allSets = try? context.fetch(setDescriptor),
                  let linkedSet = allSets.first(where: { $0.id == setLogID }),
                  let exerciseLog = linkedSet.exerciseLog,
                  exerciseLog.exercise?.id == exercise.id else { continue }

            // Find the best reps at this weight across all completed sets in the same exercise log
            let bestReps = exerciseLog.sets
                .filter { $0.isCompleted && $0.weight == pr.weight && $0.reps != nil }
                .map { $0.reps! }
                .max() ?? pr.reps

            if bestReps > pr.reps {
                pr.reps = bestReps
                // Update setLogID to point to the set with the best reps
                if let bestSet = exerciseLog.sets.first(where: { $0.isCompleted && $0.weight == pr.weight && $0.reps == bestReps }) {
                    pr.setLogID = bestSet.id
                }
            }
        }

        try? context.save()
    }

    /// Gets all PRs for a user, optionally filtered by exercise
    static func getPRs(
        for user: User,
        exercise: Exercise? = nil,
        context: ModelContext
    ) -> [PersonalRecord] {
        var descriptor: FetchDescriptor<PersonalRecord>

        if let exercise = exercise {
            let exerciseID = exercise.id
            descriptor = FetchDescriptor<PersonalRecord>(
                predicate: #Predicate<PersonalRecord> { pr in
                    pr.exercise?.id == exerciseID
                },
                sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<PersonalRecord>(
                sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
            )
        }

        return ((try? context.fetch(descriptor)) ?? []).filter { $0.type == .maxWeight }
    }
}
