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

        for (dayIndex, _) in labels.enumerated() {
            let muscleGroups = state.muscleGroups(forDayIndex: dayIndex)
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

    /// Generates defaults for edit mode, reusing exercises from existing templates
    /// where their category matches the new day's category.
    static func generateDefaultsForEdit(
        state: SmartBuilderState,
        allExercises: [Exercise],
        existingTemplates: [WorkoutTemplate]
    ) -> [Int: [Exercise]] {
        var result: [Int: [Exercise]] = [:]
        let labels = state.dayLabels

        // Group existing templates by category, preserving order for A/B matching
        var templatesByCategory: [TemplateCategory: [WorkoutTemplate]] = [:]
        for template in existingTemplates {
            templatesByCategory[template.category, default: []].append(template)
        }

        // Track how many times we've used each category so we pull A first, then B, etc.
        var categoryUsed: [TemplateCategory: Int] = [:]

        for (dayIndex, label) in labels.enumerated() {
            let category: TemplateCategory
            if state.selectedSplit == .custom {
                category = categoryForMuscleGroups(state.muscleGroups(forDayIndex: dayIndex))
            } else {
                category = categoryFor(label)
            }
            let usedCount = categoryUsed[category, default: 0]
            categoryUsed[category] = usedCount + 1

            // Try to find a matching existing template by category
            if let templates = templatesByCategory[category],
               usedCount < templates.count {
                let template = templates[usedCount]
                let exercises = template.exerciseIDs.compactMap { id in
                    allExercises.first { $0.id == id }
                }
                if !exercises.isEmpty {
                    result[dayIndex] = exercises
                    continue
                }
            }

            // No match — fall back to fresh defaults
            let muscleGroups = state.muscleGroups(forDayIndex: dayIndex)
            let budget = state.exerciseBudget
            result[dayIndex] = pickExercises(
                muscleGroups: muscleGroups,
                budget: budget,
                from: allExercises
            )
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

    /// Creates templates and plans from the builder state (used during onboarding)
    static func createPlan(
        state: SmartBuilderState,
        user: User,
        context: ModelContext
    ) {
        let templates = createTemplates(state: state, user: user, context: context)
        generatePlansForCurrentWeek(
            state: state,
            templates: templates,
            user: user,
            context: context
        )
        savePreferences(state: state, templates: templates, user: user)
    }

    /// Updates an existing plan: deletes future unstarted plans, creates new templates,
    /// and regenerates plans for 3 weeks (used from Settings edit mode)
    static func updatePlan(
        state: SmartBuilderState,
        user: User,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Delete future unstarted plans (can't use relationship filtering in #Predicate)
        let allPlans: [WorkoutPlan]
        do {
            allPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        } catch { return }

        for plan in allPlans {
            let planDate = calendar.startOfDay(for: plan.date)
            if planDate >= today && plan.completedWorkout == nil {
                context.delete(plan)
            }
        }

        // Create new templates and generate plans for 3 weeks
        let templates = createTemplates(state: state, user: user, context: context)
        generatePlansForWeeks(
            weekCount: 3,
            state: state,
            templates: templates,
            user: user,
            context: context
        )
        savePreferences(state: state, templates: templates, user: user)
    }

    /// Moves the user's existing workouts onto new weekdays without rebuilding templates.
    /// Deletes future unstarted plans and regenerates them on the new days (used from Settings).
    static func updateTrainingDays(
        _ slots: [Int],
        user: User,
        context: ModelContext
    ) {
        let sortedSlots = slots.sorted()
        guard sortedSlots.count == user.preferredDaysPerWeek else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let allPlans: [WorkoutPlan]
        do {
            allPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        } catch { return }

        var remainingPlans: [WorkoutPlan] = []
        for plan in allPlans {
            let planDate = calendar.startOfDay(for: plan.date)
            if planDate >= today && plan.completedWorkout == nil {
                context.delete(plan)
            } else {
                remainingPlans.append(plan)
            }
        }

        user.preferredTrainingSlots = sortedSlots
        extendPlansIfNeeded(user: user, existingPlans: remainingPlans, context: context)
    }

    // MARK: - Shared Helpers

    /// Creates workout templates from the builder state
    private static func createTemplates(
        state: SmartBuilderState,
        user: User,
        context: ModelContext
    ) -> [Int: WorkoutTemplate] {
        let labels = state.dayLabels
        var templates: [Int: WorkoutTemplate] = [:]

        // Count occurrences of each label to detect duplicates (e.g. Upper/Lower 4-day)
        var labelCounts: [String: Int] = [:]
        for label in labels { labelCounts[label, default: 0] += 1 }

        // Track how many times we've seen each label so far for suffix assignment
        var labelSeen: [String: Int] = [:]
        let suffixes = ["A", "B", "C", "D", "E", "F"]

        for (dayIndex, label) in labels.enumerated() {
            let seen = labelSeen[label, default: 0]
            labelSeen[label] = seen + 1

            // Only add suffix if the label appears more than once
            let name: String
            if (labelCounts[label] ?? 1) > 1 {
                let suffix = seen < suffixes.count ? suffixes[seen] : "\(seen + 1)"
                name = "\(label) \(suffix)"
            } else {
                name = label
            }

            let exercises = state.sortedExercises(for: dayIndex)
            let category: TemplateCategory
            if state.selectedSplit == .custom {
                category = categoryForMuscleGroups(state.muscleGroups(forDayIndex: dayIndex))
            } else {
                category = categoryFor(label)
            }
            let template = WorkoutTemplate(name: name, category: category, isBuiltIn: false)
            template.exerciseIDs = exercises.map { $0.id }
            template.defaultSets = state.repRange.compoundSets
            template.defaultReps = state.repRange.compoundReps
            template.user = user
            context.insert(template)
            templates[dayIndex] = template
        }

        return templates
    }

    /// Generates plans for the current week only (today onward) — used during onboarding
    private static func generatePlansForCurrentWeek(
        state: SmartBuilderState,
        templates: [Int: WorkoutTemplate],
        user: User,
        context: ModelContext
    ) {
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
    }

    /// Generates plans for multiple weeks (today onward, skipping existing plans)
    private static func generatePlansForWeeks(
        weekCount: Int,
        state: SmartBuilderState,
        templates: [Int: WorkoutTemplate],
        user: User,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else { return }

        let trainingSlots = Set(state.trainingDaySlots)

        for weekOffset in 0..<weekCount {
            guard let monday = calendar.date(byAdding: .day, value: weekOffset * 7, to: thisMonday) else { continue }

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
        }
    }

    /// Saves builder preferences to the user model
    private static func savePreferences(
        state: SmartBuilderState,
        templates: [Int: WorkoutTemplate],
        user: User
    ) {
        let labels = state.dayLabels
        user.preferredDaysPerWeek = state.daysPerWeek
        user.preferredWorkoutMinutes = state.minutesPerWorkout
        user.preferredRepRange = state.repRange
        user.preferredSplit = state.selectedSplit
        user.preferredTrainingSlots = state.trainingDaySlots
        user.weeklyTemplateIDs = (0..<labels.count).compactMap { templates[$0]?.id }

        if state.selectedSplit == .custom {
            user.customDayNames = state.customDayConfigs.map { $0.name }
            user.customDayMuscleGroups = state.customDayConfigs.map { $0.muscleGroups.map(\.rawValue) }
        } else {
            user.customDayNames = []
            user.customDayMuscleGroups = []
        }
    }

    /// Extends the user's workout plan into weeks that don't have any plans yet.
    /// Only fills days that have no existing plan (respects manual edits).
    /// Generates plans for the current week and next week.
    static func extendPlansIfNeeded(
        user: User,
        existingPlans: [WorkoutPlan],
        context: ModelContext
    ) {
        guard !user.streakPaused else { return }

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
              let nextMonday = calendar.date(byAdding: .day, value: 7, to: thisMonday),
              let thirdMonday = calendar.date(byAdding: .day, value: 14, to: thisMonday) else { return }

        let trainingSlotSet = Set(trainingSlots)

        // Set of dates that already have plans
        let existingDates = Set(existingPlans.map { calendar.startOfDay(for: $0.date) })

        for monday in [thisMonday, nextMonday, thirdMonday] {
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

    /// Infers the best TemplateCategory from selected muscle groups (used for custom splits)
    private static func categoryForMuscleGroups(_ groups: [MuscleGroup]) -> TemplateCategory {
        let set = Set(groups)

        let hasChest = set.contains(.chest)
        let hasBack = set.contains(.back)
        let hasShoulders = set.contains(.shoulders)
        let hasBiceps = set.contains(.biceps)
        let hasTriceps = set.contains(.triceps)
        let hasLegs = set.contains(.legs)
        let hasUpperBody = hasChest || hasBack || hasShoulders || hasBiceps || hasTriceps

        // Full body: both upper and lower muscle groups
        if hasUpperBody && hasLegs {
            return .fullBody
        }

        // Legs (with or without core)
        if hasLegs {
            return .legs
        }

        // Push: chest + shoulders (± triceps), no back
        if hasChest && hasShoulders && !hasBack {
            return .push
        }

        // Pull: back (± biceps), no chest or shoulders
        if hasBack && !hasChest && !hasShoulders {
            return hasBiceps ? .pull : .backBiceps
        }

        // Chest focused (± triceps)
        if hasChest && !hasBack && !hasShoulders {
            return .chestTriceps
        }

        // Shoulders focused (± arms)
        if hasShoulders && !hasChest && !hasBack {
            return .shoulders
        }

        // Broad upper body (chest + back)
        if hasChest && hasBack {
            return .upper
        }

        return .custom
    }
}
