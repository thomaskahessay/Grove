import SwiftUI
import SwiftData

struct DayPlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.usageCount, order: .reverse) private var templates: [WorkoutTemplate]

    let date: Date
    var existingPlan: WorkoutPlan?

    @State private var isRestDay: Bool
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var newTemplateCategory: TemplateCategory?

    init(date: Date, existingPlan: WorkoutPlan? = nil) {
        self.date = date
        self.existingPlan = existingPlan
        _isRestDay = State(initialValue: existingPlan?.isRestDay ?? false)
        _selectedTemplate = State(initialValue: existingPlan?.template)
    }

    private var dateHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var userTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isBuiltIn }
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

                    // Template picker (hidden when rest day)
                    if !isRestDay {
                        templatePickerSection
                    }

                    // Clear plan button
                    if existingPlan != nil {
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
        .sheet(item: $newTemplateCategory) { category in
            NewTemplateSheet(category: category) { template in
                selectedTemplate = template
            }
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

            // User templates
            if !userTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Templates")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(userTemplates) { template in
                        TemplatePlanRow(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTemplate = (selectedTemplate?.id == template.id) ? nil : template
                            }
                        }
                    }
                }
            }

            // Category-based quick picks
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
                            isSelected: selectedTemplate?.category == category
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedTemplate?.category == category {
                                    selectedTemplate = nil
                                } else if let existing = templates.first(where: { $0.category == category }) {
                                    selectedTemplate = existing
                                } else {
                                    newTemplateCategory = category
                                }
                            }
                        }
                    }
                }
            }
        }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .padding(12)
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

    let category: TemplateCategory
    let onCreated: (WorkoutTemplate) -> Void

    @State private var templateName: String
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false

    init(category: TemplateCategory, onCreated: @escaping (WorkoutTemplate) -> Void) {
        self.category = category
        self.onCreated = onCreated
        _templateName = State(initialValue: category.rawValue)
    }

    private var suggestedExercises: [Exercise] {
        let muscleGroups = muscleGroupsForCategory(category)
        return allExercises
            .filter { muscleGroups.contains($0.muscleGroup) }
            .filter { !selectedExercises.contains($0) }
            .shuffled()
            .prefix(6)
            .map { $0 }
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
                    }

                    // Suggested Exercises
                    if !suggestedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)

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
                            .padding(.vertical, 24)
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.headline)
                                            .foregroundStyle(Color.groveSage)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exercise.name)
                                                .font(.body)
                                                .foregroundStyle(Color.groveText)
                                            Text(exercise.muscleGroup.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            withAnimation {
                                                selectedExercises.removeAll { $0.id == exercise.id }
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.groveMutedRust.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

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
            .background(Color.groveBackground)
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
                    .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedExercises: $selectedExercises,
                    filterCategory: category
                )
            }
        }
    }

    private func createTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespaces)
        let template = WorkoutTemplate(
            name: name.isEmpty ? category.rawValue : name,
            category: category,
            isBuiltIn: false
        )
        template.exerciseIDs = selectedExercises.map { $0.id }
        modelContext.insert(template)
        onCreated(template)
        dismiss()
    }
}

#Preview {
    DayPlanSheet(date: Date())
        .modelContainer(for: [WorkoutPlan.self, WorkoutTemplate.self, Exercise.self])
}
