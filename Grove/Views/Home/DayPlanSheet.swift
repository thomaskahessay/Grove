import SwiftUI
import SwiftData

struct DayPlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.usageCount, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let date: Date
    var existingPlan: WorkoutPlan?

    @State private var isRestDay: Bool
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var newTemplateCategory: TemplateCategory?
    @State private var filterCategory: TemplateCategory?
    @State private var editingTemplate: WorkoutTemplate?

    init(date: Date, existingPlan: WorkoutPlan? = nil) {
        self.date = date
        self.existingPlan = existingPlan
        _isRestDay = State(initialValue: existingPlan?.isRestDay ?? false)
        let template = existingPlan?.template
        _selectedTemplate = State(initialValue: (template?.isArchived == true) ? nil : template)
    }

    /// A missed day is a past day that had a workout planned but wasn't completed
    private var isMissedWorkoutDay: Bool {
        guard let plan = existingPlan else { return false }
        return plan.status == .incomplete
    }

    private var dateHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var userTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isBuiltIn && !$0.isArchived }
    }

    private var filteredUserTemplates: [WorkoutTemplate] {
        guard let category = filterCategory else { return userTemplates }
        return userTemplates.filter { $0.category == category }
    }

    private var selectedTemplateExercises: [Exercise] {
        guard let template = selectedTemplate else { return [] }
        return template.exerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }
    }

    private func sharedTemplate(for template: WorkoutTemplate) -> SharedTemplate {
        let exerciseNames = template.exerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }?.name
        }
        return SharedTemplate(
            name: template.name,
            category: template.category.rawValue,
            exerciseNames: exerciseNames,
            defaultSets: template.defaultSets,
            defaultReps: template.defaultReps,
            sharedBy: nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date header
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.groveSage)
                        Text(dateHeader)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveText)
                    }

                    // Rest day toggle
                    restDaySection

                    // Template picker (hidden when rest day or missed day)
                    if !isRestDay && !isMissedWorkoutDay {
                        templatePickerSection
                    }

                    // Missed day explanation
                    if isMissedWorkoutDay && !isRestDay {
                        missedDayMessage
                    }

                    // Clear plan button (not shown for missed days)
                    if existingPlan != nil && !isMissedWorkoutDay {
                        clearPlanButton
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.groveBackground)
            .navigationTitle("Plan Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlan()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isRestDay && selectedTemplate == nil)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(item: $newTemplateCategory, onDismiss: {
            if selectedTemplate == nil || selectedTemplate?.category != filterCategory {
                filterCategory = nil
                selectedTemplate = nil
            }
        }) { category in
            NewTemplateSheet(category: category) { template in
                selectedTemplate = template
            }
        }
        .sheet(item: $editingTemplate) { template in
            EditTemplateSheet(template: template)
        }
    }

    // MARK: - Sections

    private var restDaySection: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.fill")
                .font(.title2)
                .foregroundStyle(isRestDay ? Color.groveTerracotta : Color.groveWarmSand)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest Day")
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                Text("Recovery is part of the plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isRestDay)
                .labelsHidden()
                .tint(Color.groveSage)
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var templatePickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assign a Workout")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            // User templates (only show after a category is selected)
            if filterCategory != nil && !filteredUserTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Templates")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let category = filterCategory {
                            Button {
                                newTemplateCategory = category
                            } label: {
                                Label("New", systemImage: "plus")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .tint(.groveSage)
                        }
                    }

                    ForEach(filteredUserTemplates) { template in
                        TemplatePlanRow(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTemplate = (selectedTemplate?.id == template.id) ? nil : template
                                }
                            },
                            onDelete: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedTemplate?.id == template.id {
                                        selectedTemplate = nil
                                    }
                                    let isLastForCategory = filterCategory != nil &&
                                        userTemplates.filter({ $0.category == filterCategory && $0.id != template.id }).isEmpty
                                    template.isArchived = true
                                    if isLastForCategory {
                                        newTemplateCategory = filterCategory
                                    }
                                }
                            }
                        )
                    }
                }
            }

            // Show exercises if a template is selected, otherwise show categories
            if let template = selectedTemplate, !selectedTemplateExercises.isEmpty {
                templateExercisesSection(template: template)
            } else {
                categoriesSection
            }
        }
    }

    private func templateExercisesSection(template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exercises in \(template.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    if let url = sharedTemplate(for: template).toURL() {
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.keyWindow?.rootViewController {
                            let presenter = root.presentedViewController ?? root
                            activityVC.popoverPresentationController?.sourceView = presenter.view
                            presenter.present(activityVC, animated: true)
                        }
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveSage)
                }

                Button {
                    editingTemplate = template
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveSage)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTemplate = nil
                        filterCategory = nil
                    }
                } label: {
                    Label("Change", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveSage)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(selectedTemplateExercises.enumerated()), id: \.element.id) { index, exercise in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.groveText)
                            Text(exercise.muscleGroup.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < selectedTemplateExercises.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    CategoryPlanButton(
                        category: category,
                        isSelected: filterCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if filterCategory == category {
                                filterCategory = nil
                            } else {
                                filterCategory = category
                                selectedTemplate = nil
                                // Only open new template sheet if no templates exist for this category
                                if userTemplates.filter({ $0.category == category }).isEmpty {
                                    newTemplateCategory = category
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var missedDayMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.groveWarmSand)

            VStack(alignment: .leading, spacing: 4) {
                Text("Missed Workout")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)
                Text("You can mark this day as a rest day to preserve your streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groveWarmSand.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var clearPlanButton: some View {
        Button {
            clearPlan()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Clear Plan")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.destructive)
    }

    // MARK: - Actions

    private func savePlan() {
        if let existing = existingPlan {
            existing.isRestDay = isRestDay
            existing.template = isRestDay ? nil : selectedTemplate
        } else {
            let plan = WorkoutPlan(date: Calendar.current.startOfDay(for: date), isRestDay: isRestDay)
            plan.template = isRestDay ? nil : selectedTemplate
            modelContext.insert(plan)
        }

        dismiss()
    }

    private func clearPlan() {
        if let existing = existingPlan {
            modelContext.delete(existing)
        }
        dismiss()
    }
}

// MARK: - Template Plan Row

struct TemplatePlanRow: View {
    let template: WorkoutTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(isSelected ? .white : Color.groveSage)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(template.exerciseIDs.count) exercises")
                            .font(.caption)
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(Color.groveMutedRust)
                    .padding(.leading, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isSelected ? Color.groveSage : Color.groveCardBackground)
        .foregroundStyle(isSelected ? .white : Color.groveText)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.groveSage : Color.groveWarmSand.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Category Plan Button

struct CategoryPlanButton: View {
    let category: TemplateCategory
    let isSelected: Bool
    let action: () -> Void

    private var iconName: String {
        switch category {
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .legs: return "figure.run"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.walk"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "slider.horizontal.3"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.body)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.groveSage : Color.groveCardBackground)
            .foregroundStyle(isSelected ? .white : Color.groveText)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.groveSage : Color.groveWarmSand.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Template Sheet

struct NewTemplateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var allTemplates: [WorkoutTemplate]

    let category: TemplateCategory
    let onCreated: (WorkoutTemplate) -> Void

    @State private var templateName: String
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var suggestedExerciseIDs: [UUID] = []

    init(category: TemplateCategory, onCreated: @escaping (WorkoutTemplate) -> Void) {
        self.category = category
        self.onCreated = onCreated
        _templateName = State(initialValue: category.rawValue)
    }

    private var trimmedName: String {
        templateName.trimmingCharacters(in: .whitespaces)
    }

    private var nameAlreadyExists: Bool {
        let name = trimmedName.isEmpty ? category.rawValue : trimmedName
        return allTemplates.contains { !$0.isArchived && $0.name.lowercased() == name.lowercased() }
    }

    private var suggestedExercises: [Exercise] {
        suggestedExerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }.filter { !selectedExercises.contains($0) }
    }

    private func refreshSuggestions() {
        let muscleGroups = muscleGroupsForCategory(category)
        suggestedExerciseIDs = allExercises
            .filter { muscleGroups.contains($0.muscleGroup) }
            .shuffled()
            .prefix(8)
            .map { $0.id }
    }

    private func muscleGroupsForCategory(_ category: TemplateCategory) -> [MuscleGroup] {
        switch category {
        case .push: return [.chest, .shoulders, .triceps]
        case .pull: return [.back, .biceps]
        case .legs: return [.legs]
        case .upper: return [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower: return [.legs, .core]
        case .fullBody: return MuscleGroup.allCases
        case .chestTriceps: return [.chest, .triceps]
        case .backBiceps: return [.back, .biceps]
        case .shoulders: return [.shoulders]
        case .custom: return MuscleGroup.allCases
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Template name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)

                        TextField("e.g., Push Day, Leg Day", text: $templateName)
                            .textFieldStyle(.roundedBorder)

                        if nameAlreadyExists {
                            Label("A template with this name already exists", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.groveMutedRust)
                        }
                    }

                    // Suggested Exercises
                    if !suggestedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Suggested")
                                    .font(.headline)
                                    .foregroundStyle(Color.groveText)

                                Spacer()

                                Button {
                                    refreshSuggestions()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                        .font(.subheadline)
                                }
                                .tint(.groveSage)
                            }

                            Text("Tap to add")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(suggestedExercises) { exercise in
                                        SuggestedExerciseCard(exercise: exercise) {
                                            withAnimation {
                                                selectedExercises.append(exercise)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Exercises
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Exercises")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)

                            Spacer()

                            Button {
                                showingExercisePicker = true
                            } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.subheadline)
                            }
                            .tint(.groveSage)
                        }

                        if selectedExercises.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "dumbbell")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.groveWarmSand)

                                Text("No exercises added yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    showingExercisePicker = true
                                } label: {
                                    Text("Browse Exercises")
                                }
                                .buttonStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                                    SelectedExerciseRow(
                                        exercise: exercise,
                                        index: index + 1,
                                        onRemove: {
                                            withAnimation {
                                                selectedExercises.removeAll { $0.id == exercise.id }
                                            }
                                        },
                                        onMoveUp: index > 0 ? {
                                            withAnimation {
                                                selectedExercises.swapAt(index, index - 1)
                                            }
                                        } : nil,
                                        onMoveDown: index < selectedExercises.count - 1 ? {
                                            withAnimation {
                                                selectedExercises.swapAt(index, index + 1)
                                            }
                                        } : nil
                                    )

                                    if index < selectedExercises.count - 1 {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.groveBackground.ignoresSafeArea())
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTemplate()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty || nameAlreadyExists)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedExercises: $selectedExercises,
                    filterCategory: category
                )
            }
            .onAppear {
                refreshSuggestions()
            }
        }
    }

    private func createTemplate() {
        let template = WorkoutTemplate(
            name: trimmedName.isEmpty ? category.rawValue : trimmedName,
            category: category,
            isBuiltIn: false
        )
        template.exerciseIDs = selectedExercises.map { $0.id }
        modelContext.insert(template)
        onCreated(template)
        dismiss()
    }
}

// MARK: - Edit Template Sheet

struct EditTemplateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var allTemplates: [WorkoutTemplate]

    @Bindable var template: WorkoutTemplate

    @State private var templateName: String
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var suggestedExerciseIDs: [UUID] = []

    init(template: WorkoutTemplate) {
        self.template = template
        _templateName = State(initialValue: template.name)
    }

    private var trimmedName: String {
        templateName.trimmingCharacters(in: .whitespaces)
    }

    private var nameAlreadyExists: Bool {
        let name = trimmedName.isEmpty ? template.category.rawValue : trimmedName
        return allTemplates.contains {
            !$0.isArchived &&
            $0.id != template.id &&
            $0.name.lowercased() == name.lowercased()
        }
    }

    private var suggestedExercises: [Exercise] {
        suggestedExerciseIDs.compactMap { id in
            allExercises.first { $0.id == id }
        }.filter { !selectedExercises.contains($0) }
    }

    private func refreshSuggestions() {
        let muscleGroups = muscleGroupsForCategory(template.category)
        suggestedExerciseIDs = allExercises
            .filter { muscleGroups.contains($0.muscleGroup) }
            .shuffled()
            .prefix(8)
            .map { $0.id }
    }

    private func muscleGroupsForCategory(_ category: TemplateCategory) -> [MuscleGroup] {
        switch category {
        case .push: return [.chest, .shoulders, .triceps]
        case .pull: return [.back, .biceps]
        case .legs: return [.legs]
        case .upper: return [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower: return [.legs, .core]
        case .fullBody: return MuscleGroup.allCases
        case .chestTriceps: return [.chest, .triceps]
        case .backBiceps: return [.back, .biceps]
        case .shoulders: return [.shoulders]
        case .custom: return MuscleGroup.allCases
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Template name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)

                        TextField("e.g., Push Day, Leg Day", text: $templateName)
                            .textFieldStyle(.roundedBorder)

                        if nameAlreadyExists {
                            Label("A template with this name already exists", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.groveMutedRust)
                        }
                    }

                    // Suggested Exercises
                    if !suggestedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Suggested")
                                    .font(.headline)
                                    .foregroundStyle(Color.groveText)

                                Spacer()

                                Button {
                                    refreshSuggestions()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                        .font(.subheadline)
                                }
                                .tint(.groveSage)
                            }

                            Text("Tap to add")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(suggestedExercises) { exercise in
                                        SuggestedExerciseCard(exercise: exercise) {
                                            withAnimation {
                                                selectedExercises.append(exercise)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Exercises
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Exercises")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)

                            Spacer()

                            Button {
                                showingExercisePicker = true
                            } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.subheadline)
                            }
                            .tint(.groveSage)
                        }

                        if selectedExercises.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "dumbbell")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.groveWarmSand)

                                Text("No exercises added yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    showingExercisePicker = true
                                } label: {
                                    Text("Browse Exercises")
                                }
                                .buttonStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                                    SelectedExerciseRow(
                                        exercise: exercise,
                                        index: index + 1,
                                        onRemove: {
                                            withAnimation {
                                                selectedExercises.removeAll { $0.id == exercise.id }
                                            }
                                        },
                                        onMoveUp: index > 0 ? {
                                            withAnimation {
                                                selectedExercises.swapAt(index, index - 1)
                                            }
                                        } : nil,
                                        onMoveDown: index < selectedExercises.count - 1 ? {
                                            withAnimation {
                                                selectedExercises.swapAt(index, index + 1)
                                            }
                                        } : nil
                                    )

                                    if index < selectedExercises.count - 1 {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.groveBackground.ignoresSafeArea())
            .navigationTitle("Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty || nameAlreadyExists)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedExercises: $selectedExercises,
                    filterCategory: template.category
                )
            }
            .onAppear {
                selectedExercises = template.exerciseIDs.compactMap { id in
                    allExercises.first { $0.id == id }
                }
                refreshSuggestions()
            }
        }
    }

    private func saveTemplate() {
        template.name = trimmedName.isEmpty ? template.category.rawValue : trimmedName
        template.exerciseIDs = selectedExercises.map { $0.id }
        dismiss()
    }
}

#Preview {
    DayPlanSheet(date: Date())
        .modelContainer(for: [WorkoutPlan.self, WorkoutTemplate.self, Exercise.self], inMemory: true)
}
