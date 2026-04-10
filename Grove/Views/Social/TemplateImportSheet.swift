import SwiftUI
import SwiftData

struct TemplateImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query private var allTemplates: [WorkoutTemplate]

    let sharedTemplate: SharedTemplate

    @State private var templateName: String
    @State private var selectedCategory: TemplateCategory
    @State private var createMissing = false
    @State private var imported = false

    init(sharedTemplate: SharedTemplate) {
        self.sharedTemplate = sharedTemplate
        _templateName = State(initialValue: sharedTemplate.name)
        _selectedCategory = State(initialValue:
            TemplateCategory(rawValue: sharedTemplate.category) ?? .custom)
    }

    private var trimmedName: String {
        templateName.trimmingCharacters(in: .whitespaces)
    }

    private var nameAlreadyExists: Bool {
        let name = trimmedName.isEmpty ? selectedCategory.rawValue : trimmedName
        return allTemplates.contains { !$0.isArchived && $0.name.lowercased() == name.lowercased() }
    }

    private var resolvedExercises: [ExerciseResolver.ResolvedExercise] {
        ExerciseResolver.resolve(
            names: sharedTemplate.exerciseNames,
            allExercises: allExercises,
            context: modelContext,
            createMissing: false
        )
    }

    private var matchedCount: Int {
        resolvedExercises.filter { $0.exercise != nil }.count
    }

    private var missingCount: Int {
        resolvedExercises.filter { $0.exercise == nil }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Attribution
                    if let sharedBy = sharedTemplate.sharedBy {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundStyle(Color.groveSage)
                            Text("Shared by \(sharedBy)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Template name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)

                        TextField("Template name", text: $templateName)
                            .textFieldStyle(.roundedBorder)

                        if nameAlreadyExists {
                            Label("A template with this name already exists", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.groveMutedRust)
                        }
                    }

                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TemplateCategory.allCases) { category in
                                    Button {
                                        selectedCategory = category
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: category.icon)
                                                .font(.caption2)
                                            Text(category.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedCategory == category ? Color.groveSage : Color.groveCardBackground)
                                        .foregroundStyle(selectedCategory == category ? .white : Color.groveText)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Exercise list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Exercises")
                                .font(.headline)
                                .foregroundStyle(Color.groveText)

                            Spacer()

                            Text("\(matchedCount)/\(sharedTemplate.exerciseNames.count) matched")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Missing exercises warning
                        if missingCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.groveMutedRust)

                                Text("\(missingCount) exercise\(missingCount == 1 ? "" : "s") not found on this device")
                                    .font(.caption)
                                    .foregroundStyle(Color.groveMutedRust)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.groveMutedRust.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Toggle(isOn: $createMissing) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create missing exercises")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.groveText)
                                    Text("Adds them as custom exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(Color.groveSage)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(resolvedExercises.enumerated()), id: \.offset) { index, resolved in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundStyle(resolved.exercise != nil ? Color.groveSage : Color.groveMutedRust)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(resolved.name)
                                            .font(.body)
                                            .foregroundStyle(resolved.exercise != nil ? Color.groveText : Color.groveTextSecondary)
                                        if let exercise = resolved.exercise {
                                            Text(exercise.muscleGroup.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Not found")
                                                .font(.caption)
                                                .foregroundStyle(Color.groveMutedRust)
                                        }
                                    }

                                    Spacer()

                                    if resolved.exercise != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(Color.groveSage)
                                    } else {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(Color.groveMutedRust.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if index < resolvedExercises.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color.groveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.groveBackground.ignoresSafeArea())
            .navigationTitle("Import Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        importTemplate()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty || nameAlreadyExists || (matchedCount == 0 && !createMissing))
                }
            }
        }
    }

    private func importTemplate() {
        let resolved = ExerciseResolver.resolve(
            names: sharedTemplate.exerciseNames,
            allExercises: allExercises,
            context: modelContext,
            createMissing: createMissing
        )

        let exerciseIDs = resolved.compactMap { $0.exercise?.id }

        let template = WorkoutTemplate(
            name: trimmedName.isEmpty ? selectedCategory.rawValue : trimmedName,
            category: selectedCategory,
            isBuiltIn: false
        )
        template.exerciseIDs = exerciseIDs
        template.defaultSets = sharedTemplate.defaultSets
        template.defaultReps = sharedTemplate.defaultReps
        modelContext.insert(template)

        dismiss()
    }
}
