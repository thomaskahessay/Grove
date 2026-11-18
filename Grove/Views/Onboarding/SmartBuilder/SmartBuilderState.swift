import SwiftUI
import SwiftData

/// Configuration for a single day in a custom split
struct CustomDayConfig {
    var name: String
    var muscleGroups: [MuscleGroup]
}

/// How the user wants to set up their workouts (asked right after picking days).
enum PlanSetupMode: String {
    /// They enter the exercises they already do; suggestions only on request.
    case ownRoutine
    /// Length, split and rep range questions, then a generated plan to tweak.
    case generate

    /// Remembered so editing the plan from Settings starts on the same path.
    static let defaultsKey = "planSetupMode"
}

/// The screens of the builder. Which ones appear depends on the setup mode and split.
enum BuilderStep {
    case days, setupChoice, length, split, customSplit, dayNames, exercises
}

/// Holds all state for the Smart Workout Builder flow
@Observable
class SmartBuilderState {
    // Step 1
    var daysPerWeek: Int = 3

    // Step 2 — nil until they pick
    var setupMode: PlanSetupMode?
    var isOwnRoutine: Bool { setupMode == .ownRoutine }

    // Step 2
    var minutesPerWorkout: Int = 60

    // Step 3
    var selectedSplit: SplitType = .pushPullLegs
    var repRange: RepRangePreference = .hypertrophy

    // Custom split configuration. Also holds the day names on the own-routine path.
    var customDayConfigs: [CustomDayConfig] = []

    // Step 4 — per-day exercise selections (keyed by day index)
    var dayExerciseSelections: [Int: [Exercise]] = [:]

    // Internal step tracking
    var currentStep: Int = 0

    var steps: [BuilderStep] {
        var steps: [BuilderStep] = [.days, .setupChoice]
        if isOwnRoutine {
            // Same split choice as the generated path, then name the days (prefilled
            // from the split) and add exercises.
            steps += [.split, .dayNames, .exercises]
        } else {
            steps += [.length, .split]
            if selectedSplit == .custom { steps.append(.customSplit) }
            steps.append(.exercises)
        }
        return steps
    }

    var currentStepKind: BuilderStep { steps[min(currentStep, steps.count - 1)] }
    var nextStepKind: BuilderStep? { currentStep + 1 < steps.count ? steps[currentStep + 1] : nil }
    var totalSteps: Int { steps.count - 1 }

    var exerciseBudget: Int {
        minutesPerWorkout / 10
    }

    var dayLabels: [String] {
        if isOwnRoutine {
            return customDayConfigs.enumerated().map { index, config in
                let name = config.name.trimmingCharacters(in: .whitespaces)
                return name.isEmpty ? "Day \(index + 1)" : name
            }
        }
        if selectedSplit == .custom && !customDayConfigs.isEmpty {
            return customDayConfigs.map { $0.name }
        }
        return selectedSplit.dayLabels(for: daysPerWeek)
    }

    /// Day labels as shown on screen: repeated names get A, B… ("Upper A", "Upper B"),
    /// matching the workout names createTemplates saves.
    var displayDayLabels: [String] { Self.distinctNames(dayLabels) }

    /// Appends A, B, C… to names that appear more than once; unique names are unchanged.
    static func distinctNames(_ names: [String]) -> [String] {
        let suffixes = ["A", "B", "C", "D", "E", "F"]
        let counts = names.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        var seen: [String: Int] = [:]
        return names.map { name in
            guard (counts[name] ?? 0) > 1 else { return name }
            let n = seen[name, default: 0]
            seen[name] = n + 1
            return "\(name) \(n < suffixes.count ? suffixes[n] : String(n + 1))"
        }
    }

    /// "Upper A" → "Upper": the name without a trailing single-letter A/B suffix.
    static func baseName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ")
        guard parts.count > 1, let last = parts.last, last.count == 1,
              ("A"..."F").contains(String(last)) else { return trimmed }
        return parts.dropLast().joined(separator: " ")
    }

    /// Gives repeated day names A/B suffixes after a rename (e.g. tapping "Upper" twice).
    func disambiguateDayNames() {
        let bases = customDayConfigs.map { Self.baseName($0.name) }
        let counts = bases.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        // Only renumber names that are repeated; leave unique and hand-typed names alone.
        let repeated = Set(counts.filter { $0.value > 1 && !$0.key.isEmpty }.keys)
        var seen: [String: Int] = [:]
        let suffixes = ["A", "B", "C", "D", "E", "F"]
        for index in customDayConfigs.indices where repeated.contains(bases[index]) {
            let n = seen[bases[index], default: 0]
            seen[bases[index]] = n + 1
            customDayConfigs[index].name = "\(bases[index]) \(n < suffixes.count ? suffixes[n] : String(n + 1))"
        }
        // A name left alone after its twin was renamed drops its suffix.
        for index in customDayConfigs.indices where (counts[bases[index]] ?? 0) == 1 && customDayConfigs[index].name != bases[index] {
            customDayConfigs[index].name = bases[index]
        }
    }

    /// Returns muscle groups for a given day index, using custom config when applicable
    func muscleGroups(forDayIndex index: Int) -> [MuscleGroup] {
        if isOwnRoutine {
            return ownRoutineMuscleGroups(forDayIndex: index)
        }
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

    /// Selected training days (Mon=0 .. Sun=6), always sorted. Count matches daysPerWeek.
    var trainingDaySlots: [Int] = SmartBuilderState.defaultTrainingSlots(for: 3)

    /// Default distribution of training days across a week (Mon=0 .. Sun=6)
    static func defaultTrainingSlots(for daysPerWeek: Int) -> [Int] {
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

    /// Sets the day count and resets training days to the default distribution
    func setDaysPerWeek(_ count: Int) {
        daysPerWeek = count
        trainingDaySlots = Self.defaultTrainingSlots(for: count)
        validateSplit()
    }

    /// Toggles a weekday on or off; the day count follows the selection (1...6 days)
    func toggleTrainingDay(_ day: Int) {
        var slots = Set(trainingDaySlots)
        if slots.contains(day) {
            guard slots.count > 1 else { return }
            slots.remove(day)
        } else {
            guard slots.count < 6 else { return }
            slots.insert(day)
        }
        trainingDaySlots = slots.sorted()
        daysPerWeek = trainingDaySlots.count
        validateSplit()
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

    /// The exercises selected for a day, in the order the user arranged them.
    /// Generated defaults arrive already sorted compounds-first.
    func sortedExercises(for dayIndex: Int) -> [Exercise] {
        dayExerciseSelections[dayIndex] ?? []
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
        let savedSlots = user.preferredTrainingSlots.sorted()
        self.trainingDaySlots = savedSlots.count == user.preferredDaysPerWeek
            ? savedSlots
            : Self.defaultTrainingSlots(for: user.preferredDaysPerWeek)
        self.minutesPerWorkout = user.preferredWorkoutMinutes
        self.selectedSplit = user.preferredSplit
        self.repRange = user.preferredRepRange
        self.setupMode = UserDefaults.standard.string(forKey: PlanSetupMode.defaultsKey)
            .flatMap(PlanSetupMode.init(rawValue:)) ?? .generate

        if user.preferredSplit == .custom {
            self.customDayConfigs = zip(user.customDayNames, user.customDayMuscleGroups).map { name, rawGroups in
                CustomDayConfig(
                    name: name,
                    muscleGroups: rawGroups.compactMap { MuscleGroup(rawValue: $0) }
                )
            }
        }
    }

    // MARK: - Own Routine

    /// Quick picks offered when naming a day.
    static let dayNameSuggestions = [
        "Push", "Pull", "Legs", "Upper", "Lower", "Full Body",
        "Chest", "Back", "Shoulders", "Arms"
    ]

    /// The split and day count the current day names were filled in from.
    private var dayNamesSource: (split: SplitType, days: Int)?

    /// Fills the day names from the chosen split (Push, Pull, Legs…) so most people only
    /// tap Continue. A Custom split starts blank for them to type. Names they edited are
    /// kept unless they went back and picked a different split or day count.
    /// `existingNames` (edit mode) are used instead when the split hasn't changed.
    func prepareDayNames(existingNames: [String]? = nil) {
        let sourceChanged = dayNamesSource.map { $0.split != selectedSplit || $0.days != daysPerWeek } ?? true
        if sourceChanged {
            customDayConfigs = []
        }
        syncCustomDayCount()
        guard sourceChanged else { return }
        dayNamesSource = (selectedSplit, daysPerWeek)

        let defaults = existingNames ?? (selectedSplit == .custom ? [] : Self.distinctNames(selectedSplit.dayLabels(for: daysPerWeek)))
        for index in customDayConfigs.indices {
            customDayConfigs[index].name = index < defaults.count ? defaults[index] : ""
        }
    }

    /// Whether the routine still matches the split exactly (names untouched).
    private var namesMatchSplit: Bool {
        selectedSplit != .custom
            && customDayConfigs.map { $0.name.trimmingCharacters(in: .whitespaces) }
                == Self.distinctNames(selectedSplit.dayLabels(for: daysPerWeek))
    }

    var areDayNamesValid: Bool {
        customDayConfigs.count == daysPerWeek
            && customDayConfigs.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The first own-routine day that still has no exercises, if any.
    var firstEmptyDayIndex: Int? {
        (0..<daysPerWeek).first { (dayExerciseSelections[$0] ?? []).isEmpty }
    }

    /// What a day trains: from its name when it's a familiar one ("Push"), otherwise
    /// from the exercises already on it. Used to suggest and to fill.
    func ownRoutineMuscleGroups(forDayIndex index: Int) -> [MuscleGroup] {
        guard index < customDayConfigs.count else { return [] }
        let name = Self.baseName(customDayConfigs[index].name)
        if let match = Self.dayNameSuggestions.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return SplitType.muscleGroups(for: match)
        }
        var groups: [MuscleGroup] = []
        for exercise in dayExerciseSelections[index] ?? [] where !groups.contains(exercise.muscleGroup) {
            groups.append(exercise.muscleGroup)
        }
        return groups
    }

    /// Turns the own-routine answers into the custom-split shape plan creation expects.
    func finalizeOwnRoutine() {
        guard isOwnRoutine else { return }
        // Keep "Push / Pull / Legs" when that's what it still is; renamed days make it custom.
        if !namesMatchSplit {
            selectedSplit = .custom
        }
        for index in customDayConfigs.indices {
            customDayConfigs[index].name = dayLabels[index]
            var groups: [MuscleGroup] = []
            for exercise in dayExerciseSelections[index] ?? [] where !groups.contains(exercise.muscleGroup) {
                groups.append(exercise.muscleGroup)
            }
            customDayConfigs[index].muscleGroups = groups
        }
        // There was no length question; record what they actually built (10 min per exercise).
        let counts = (0..<daysPerWeek).map { (dayExerciseSelections[$0] ?? []).count }
        let average = counts.isEmpty ? 6 : counts.reduce(0, +) / counts.count
        minutesPerWorkout = max(30, min(120, average * 10))
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
