import Foundation
import SwiftData

/// Detects and records personal records after workout completion
struct PRDetectionService {

    /// Result of PR detection for a single exercise
    struct PRResult {
        let exercise: Exercise
        let newMaxWeight: PersonalRecord?
        let newEstimated1RM: PersonalRecord?

        var hasPR: Bool {
            newMaxWeight != nil || newEstimated1RM != nil
        }
    }

    /// Checks a completed workout for new PRs and saves them
    /// Returns array of exercises that achieved new PRs
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

            // Find best weight and best 1RM from this workout's sets
            var bestWeightSet: SetLog?
            var best1RMSet: SetLog?
            var bestWeight: Double = 0
            var best1RM: Double = 0

            for set in completedSets {
                guard let weight = set.weight, let reps = set.reps else { continue }

                if weight > bestWeight {
                    bestWeight = weight
                    bestWeightSet = set
                }

                let estimated1RM = PersonalRecord.calculateOneRM(weight: weight, reps: reps)
                if estimated1RM > best1RM {
                    best1RM = estimated1RM
                    best1RMSet = set
                }
            }

            // Get current PRs for this exercise
            let currentMaxWeight = getCurrentPR(for: exercise, type: .maxWeight, user: user, context: context)
            let current1RM = getCurrentPR(for: exercise, type: .estimatedOneRM, user: user, context: context)

            var newMaxWeightPR: PersonalRecord?
            var new1RMPR: PersonalRecord?

            // Check if we beat max weight PR
            if bestWeight > (currentMaxWeight?.value ?? 0), let set = bestWeightSet {
                let pr = PersonalRecord(
                    exercise: exercise,
                    type: .maxWeight,
                    weight: set.weight!,
                    reps: set.reps!,
                    achievedAt: workout.completedAt ?? Date(),
                    setLogID: set.id
                )
                pr.user = user
                context.insert(pr)
                newMaxWeightPR = pr
            }

            // Check if we beat estimated 1RM PR
            if best1RM > (current1RM?.value ?? 0), let set = best1RMSet {
                let pr = PersonalRecord(
                    exercise: exercise,
                    type: .estimatedOneRM,
                    weight: set.weight!,
                    reps: set.reps!,
                    achievedAt: workout.completedAt ?? Date(),
                    setLogID: set.id
                )
                pr.user = user
                context.insert(pr)
                new1RMPR = pr
            }

            if newMaxWeightPR != nil || new1RMPR != nil {
                results.append(PRResult(
                    exercise: exercise,
                    newMaxWeight: newMaxWeightPR,
                    newEstimated1RM: new1RMPR
                ))
            }
        }

        try? context.save()
        return results
    }

    /// Gets the current PR for an exercise and type
    private static func getCurrentPR(
        for exercise: Exercise,
        type: PRType,
        user: User,
        context: ModelContext
    ) -> PersonalRecord? {
        let exerciseID = exercise.id

        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { pr in
                pr.exercise?.id == exerciseID && pr.type == type
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )

        return try? context.fetch(descriptor).first
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

        return (try? context.fetch(descriptor)) ?? []
    }
}
