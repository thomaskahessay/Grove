import SwiftUI
import SwiftData

/// Holds all state for the Smart Workout Builder flow
@Observable
class SmartBuilderState {
    // Step 1
    var daysPerWeek: Int = 3

    // Step 2
    var minutesPerWorkout: Int = 60

    // Step 3
    var selectedSplit: SplitType = .pushPullLegs
    var repRange: RepRangePreference = .hypertrophy

    // Step 4 — per-day exercise selections (keyed by day index)
    var dayExerciseSelections: [Int: [Exercise]] = [:]

    // Internal step tracking
    var currentStep: Int = 0
    let totalSteps = 3 // Last step index: 0=days, 1=length, 2=split, 3=exercises

    var exerciseBudget: Int {
        minutesPerWorkout / 10
    }

    var dayLabels: [String] {
        selectedSplit.dayLabels(for: daysPerWeek)
    }

    /// Auto-distribution of training days across a week (Mon=0 .. Sun=6)
    var trainingDaySlots: [Int] {
        switch daysPerWeek {
        case 2: return [0, 3]           // Mon, Thu
        case 3: return [0, 2, 4]        // Mon, Wed, Fri
        case 4: return [0, 1, 3, 4]     // Mon, Tue, Thu, Fri
        case 5: return [0, 1, 2, 3, 4]  // Mon-Fri
        case 6: return [0, 1, 2, 3, 4, 5] // Mon-Sat
        default: return [0, 2, 4]
        }
    }

    /// Available splits for the current day count
    var availableSplits: [SplitType] {
        SplitType.allCases.filter { $0.validDayCounts.contains(daysPerWeek) }
    }

    /// Ensures the selected split is valid for the current day count
    func validateSplit() {
        if !availableSplits.contains(selectedSplit) {
            selectedSplit = availableSplits.first ?? .fullBody
        }
    }

    /// Returns the exercises selected for a given day, sorted by priority
    func sortedExercises(for dayIndex: Int) -> [Exercise] {
        let exercises = dayExerciseSelections[dayIndex] ?? []
        return exercises.sorted { $0.sortPriority < $1.sortPriority }
    }

    /// Total exercise count across all days
    var totalExerciseCount: Int {
        dayExerciseSelections.values.reduce(0) { $0 + $1.count }
    }

    /// Estimated total time for a specific day
    func estimatedMinutes(for dayIndex: Int) -> Int {
        (dayExerciseSelections[dayIndex]?.count ?? 0) * 10
    }

    func advance() {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }

    func goBack() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
}
