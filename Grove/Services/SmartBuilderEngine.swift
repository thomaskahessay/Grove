import Foundation
import SwiftData

/// Pure logic for the Smart Builder: exercise selection, template creation, plan generation
struct SmartBuilderEngine {

    /// Generates default exercise selections for each day based on split, budget, and available exercises
    static func generateDefaults(
        state: SmartBuilderState,
        allExercises: [Exercise]
    ) -> [Int: [Exercise]] {
        var result: [Int: [Exercise]] = [:]
        let labels = state.dayLabels

        for (dayIndex, label) in labels.enumerated() {
            let muscleGroups = SplitType.muscleGroups(for: label)
            let budget = state.exerciseBudget
            let exercises = pickExercises(
                muscleGroups: muscleGroups,
                budget: budget,
                from: allExercises
            )
            result[dayIndex] = exercises
        }

        return result
    }

    /// Picks exercises for a day given muscle groups and budget
    private static func pickExercises(
        muscleGroups: [MuscleGroup],
        budget: Int,
        from allExercises: [Exercise]
    ) -> [Exercise] {
        guard !muscleGroups.isEmpty else { return [] }

        // Distribute budget across muscle groups
        let perGroup = max(1, budget / muscleGroups.count)
        let remainder = budget - (perGroup * muscleGroups.count)

        var selected: [Exercise] = []
        for (index, group) in muscleGroups.enumerated() {
            let count = perGroup + (index == 0 ? remainder : 0)
            let groupExercises = allExercises
                .filter { $0.muscleGroup == group && $0.isBuiltIn }
                .sorted { $0.sortPriority < $1.sortPriority }

            selected.append(contentsOf: groupExercises.prefix(count))
        }

        // Sort the final list: compounds first, then isolations
        return selected.sorted { $0.sortPriority < $1.sortPriority }
    }

    /// Creates templates and plans from the builder state
    static func createPlan(
        state: SmartBuilderState,
        user: User,
        context: ModelContext
    ) {
        let labels = state.dayLabels
        var templates: [Int: WorkoutTemplate] = [:]

        // Create a template for each unique day type
        var templatesByLabel: [String: WorkoutTemplate] = [:]

        for (dayIndex, label) in labels.enumerated() {
            let exercises = state.sortedExercises(for: dayIndex)

            // For splits that repeat (e.g., PPL 2x), create separate templates
            let templateKey = "\(label)-\(dayIndex)"
            let template = WorkoutTemplate(name: label, category: categoryFor(label), isBuiltIn: false)
            template.exerciseIDs = exercises.map { $0.id }
            template.defaultSets = state.repRange.compoundSets
            template.defaultReps = state.repRange.compoundReps
            template.user = user
            context.insert(template)

            templates[dayIndex] = template
            templatesByLabel[templateKey] = template
        }

        // Create plans for the current week (today onward)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else { return }

        let trainingSlots = Set(state.trainingDaySlots)

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { continue }
            guard date >= today else { continue }

            if trainingSlots.contains(dayOffset),
               let slotIndex = state.trainingDaySlots.firstIndex(of: dayOffset),
               let template = templates[slotIndex] {
                let plan = WorkoutPlan(date: date, user: user, template: template)
                context.insert(plan)
            } else {
                let plan = WorkoutPlan(date: date, user: user, isRestDay: true)
                context.insert(plan)
            }
        }

        // Save user preferences
        user.preferredDaysPerWeek = state.daysPerWeek
        user.preferredWorkoutMinutes = state.minutesPerWorkout
        user.preferredRepRange = state.repRange
        user.preferredSplit = state.selectedSplit
        user.preferredTrainingSlots = state.trainingDaySlots
        user.weeklyTemplateIDs = (0..<labels.count).compactMap { templates[$0]?.id }
    }

    /// Extends the user's workout plan into weeks that don't have any plans yet.
    /// Only fills days that have no existing plan (respects manual edits).
    /// Generates plans for the current week and next week.
    static func extendPlansIfNeeded(
        user: User,
        existingPlans: [WorkoutPlan],
        context: ModelContext
    ) {
        let templateIDs = user.weeklyTemplateIDs
        let trainingSlots = user.preferredTrainingSlots
        guard !templateIDs.isEmpty, !trainingSlots.isEmpty else { return }

        // Fetch templates by ID
        let allTemplates: [WorkoutTemplate]
        do {
            let descriptor = FetchDescriptor<WorkoutTemplate>()
            allTemplates = try context.fetch(descriptor)
        } catch {
            return
        }

        let templatesByID = Dictionary(uniqueKeysWithValues: allTemplates.compactMap { t in
            (t.id, t)
        })

        // Build a lookup of template per training slot index
        var slotTemplates: [Int: WorkoutTemplate] = [:]
        for (index, slot) in trainingSlots.enumerated() {
            if index < templateIDs.count, let template = templatesByID[templateIDs[index]] {
                slotTemplates[slot] = template
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get Monday of current week and next week
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let nextMonday = calendar.date(byAdding: .day, value: 7, to: thisMonday) else { return }

        let trainingSlotSet = Set(trainingSlots)

        // Set of dates that already have plans
        let existingDates = Set(existingPlans.map { calendar.startOfDay(for: $0.date) })

        for monday in [thisMonday, nextMonday] {
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { continue }
                // Only create plans for today onward, and only if no plan exists
                guard date >= today, !existingDates.contains(date) else { continue }

                if trainingSlotSet.contains(dayOffset), let template = slotTemplates[dayOffset] {
                    let plan = WorkoutPlan(date: date, user: user, template: template)
                    context.insert(plan)
                } else {
                    let plan = WorkoutPlan(date: date, user: user, isRestDay: true)
                    context.insert(plan)
                }
            }
        }
    }

    private static func categoryFor(_ dayLabel: String) -> TemplateCategory {
        switch dayLabel {
        case "Push": return .push
        case "Pull": return .pull
        case "Legs": return .legs
        case "Upper": return .upper
        case "Lower": return .lower
        case "Full Body": return .fullBody
        case "Chest": return .chestTriceps
        case "Back": return .backBiceps
        case "Shoulders": return .shoulders
        case "Arms": return .custom
        case "Chest & Back": return .upper
        case "Shoulders & Arms": return .shoulders
        default: return .custom
        }
    }
}
