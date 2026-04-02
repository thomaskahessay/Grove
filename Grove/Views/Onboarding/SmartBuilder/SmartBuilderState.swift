import SwiftUI
import SwiftData

/// Configuration for a single day in a custom split
struct CustomDayConfig {
    var name: String
    var muscleGroups: [MuscleGroup]
}

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

    // Custom split configuration
    var customDayConfigs: [CustomDayConfig] = []

    // Step 4 — per-day exercise selections (keyed by day index)
    var dayExerciseSelections: [Int: [Exercise]] = [:]

    // Internal step tracking
    var currentStep: Int = 0
    var totalSteps: Int { selectedSplit == .custom ? 4 : 3 }

    var exerciseBudget: Int {
        minutesPerWorkout / 10
    }

    var dayLabels: [String] {
        if selectedSplit == .custom && !customDayConfigs.isEmpty {
            return customDayConfigs.map { $0.name }
        }
        return selectedSplit.dayLabels(for: daysPerWeek)
    }

    /// Returns muscle groups for a given day index, using custom config when applicable
    func muscleGroups(forDayIndex index: Int) -> [MuscleGroup] {
        if selectedSplit == .custom, index < customDayConfigs.count {
            return customDayConfigs[index].muscleGroups
        }
        guard index < dayLabels.count else { return [] }
        let label = dayLabels[index]
        return SplitType.muscleGroups(for: label)
    }

    /// Ensures customDayConfigs count matches daysPerWeek
    func syncCustomDayCount() {
        while customDayConfigs.count < daysPerWeek {
            customDayConfigs.append(CustomDayConfig(name: "", muscleGroups: []))
        }
        if customDayConfigs.count > daysPerWeek {
            customDayConfigs = Array(customDayConfigs.prefix(daysPerWeek))
        }
    }

    /// Whether the custom split configuration is valid for advancing
    var isCustomConfigValid: Bool {
        guard selectedSplit == .custom else { return true }
        return customDayConfigs.count == daysPerWeek
            && customDayConfigs.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && !$0.muscleGroups.isEmpty }
    }

    /// Auto-distribution of training days across a week (Mon=0 .. Sun=6)
    var trainingDaySlots: [Int] {
        switch daysPerWeek {
        case 1: return [2]              // Wed
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

    /// Pre-fills state from existing user preferences (for edit mode)
    convenience init(from user: User) {
        self.init()
        self.daysPerWeek = user.preferredDaysPerWeek
        self.minutesPerWorkout = user.preferredWorkoutMinutes
        self.selectedSplit = user.preferredSplit
        self.repRange = user.preferredRepRange

        if user.preferredSplit == .custom {
            self.customDayConfigs = zip(user.customDayNames, user.customDayMuscleGroups).map { name, rawGroups in
                CustomDayConfig(
                    name: name,
                    muscleGroups: rawGroups.compactMap { MuscleGroup(rawValue: $0) }
                )
            }
        }
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
