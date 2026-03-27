import Foundation
import HealthKit
import SwiftData

@MainActor
@Observable
class HealthKitManager {
    static let shared = HealthKitManager()

    var isAuthorized = false

    private let healthStore: HKHealthStore?

    private init() {
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    var isAvailable: Bool {
        healthStore != nil
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard let healthStore else { return false }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            markAuthorized()
            return true
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() {
        guard let healthStore else {
            isAuthorized = false
            return
        }
        // HealthKit doesn't expose read authorization status directly.
        // We check if the user has been asked (workout type share status as proxy).
        // A better approach: just check if we can query. We use a simple heuristic.
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        // For read-only, authorizationStatus always returns .sharingDenied since we don't share.
        // We track authorization ourselves after a successful request.
        // Use UserDefaults to persist the "has requested" state.
        isAuthorized = UserDefaults.standard.bool(forKey: "healthKitAuthorized")
        _ = status // suppress unused warning
    }

    private func markAuthorized() {
        isAuthorized = true
        UserDefaults.standard.set(true, forKey: "healthKitAuthorized")
    }

    // MARK: - Query Overlapping Workouts

    struct HKWorkoutMatch {
        let hkWorkout: HKWorkout
        let overlapSeconds: TimeInterval
    }

    func findOverlappingWorkouts(workoutStart: Date, workoutEnd: Date) async -> [HKWorkout] {
        guard let healthStore else { return [] }

        // Expand search window by 30 minutes on each side
        let searchStart = workoutStart.addingTimeInterval(-30 * 60)
        let searchEnd = workoutEnd.addingTimeInterval(30 * 60)

        let predicate = HKQuery.predicateForSamples(withStart: searchStart, end: searchEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 20,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    /// Fetches HealthKit workouts for a specific day.
    func fetchWorkoutsForDay(date: Date) async -> [HKWorkout] {
        guard let healthStore else { return [] }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    /// Fetches recent HealthKit workouts from the past N days for manual browsing.
    func fetchRecentWorkouts(days: Int = 7) async -> [HKWorkout] {
        guard let healthStore else { return [] }

        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    func bestOverlapMatch(groveStart: Date, groveEnd: Date, candidates: [HKWorkout]) -> HKWorkout? {
        var bestMatch: HKWorkout?
        var bestOverlap: TimeInterval = 0

        for hk in candidates {
            let overlapStart = max(groveStart, hk.startDate)
            let overlapEnd = min(groveEnd, hk.endDate)
            let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))

            if overlap > bestOverlap {
                bestOverlap = overlap
                bestMatch = hk
            }
        }

        return bestMatch
    }

    // MARK: - Heart Rate Stats

    struct HeartRateStats {
        let min: Double
        let avg: Double
        let max: Double
    }

    func getHeartRateStats(for workout: HKWorkout) async -> HeartRateStats? {
        guard let healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteMin, .discreteMax, .discreteAverage]
            ) { _, statistics, _ in
                guard let statistics else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let min = statistics.minimumQuantity()?.doubleValue(for: unit)
                let avg = statistics.averageQuantity()?.doubleValue(for: unit)
                let max = statistics.maximumQuantity()?.doubleValue(for: unit)

                guard let min, let avg, let max else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: HeartRateStats(min: min, avg: avg, max: max))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Calories

    func getCalories(for workout: HKWorkout) async -> Double? {
        guard let healthStore,
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Populate Workout

    func populateWorkout(_ workout: Workout, from hkWorkout: HKWorkout) async {
        workout.healthKitWorkoutID = hkWorkout.uuid

        // Override duration with Apple Watch timing
        workout.startedAt = hkWorkout.startDate
        if workout.completedAt != nil {
            workout.completedAt = hkWorkout.endDate
        }

        async let hrStats = getHeartRateStats(for: hkWorkout)
        async let calories = getCalories(for: hkWorkout)

        if let hr = await hrStats {
            workout.heartRateMin = hr.min
            workout.heartRateAvg = hr.avg
            workout.heartRateMax = hr.max
        }

        if let cal = await calories {
            workout.caloriesBurned = cal
        }

        markAuthorized()
    }

    // MARK: - Formatting Helpers

    static func formattedWorkoutType(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Training"
        case .crossTraining: return "Cross Training"
        case .coreTraining: return "Core Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .flexibility: return "Flexibility"
        case .other: return "Other"
        default: return "Workout"
        }
    }

    static func formattedDuration(_ workout: HKWorkout) -> String {
        let totalSeconds = Int(workout.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}
