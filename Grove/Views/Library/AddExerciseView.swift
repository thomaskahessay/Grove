import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @Query private var existingExercises: [Exercise]

    /// Called with the newly created exercise just before the sheet dismisses.
    var onCreated: ((Exercise) -> Void)?

    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var muscleSubgroup = ""
    @State private var isBodyweight = false
    @State private var isCompound = false

    init(
        prefillName: String = "",
        initialMuscleGroup: MuscleGroup = .chest,
        onCreated: ((Exercise) -> Void)? = nil
    ) {
        _name = State(initialValue: prefillName)
        _muscleGroup = State(initialValue: initialMuscleGroup)
        self.onCreated = onCreated
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicate: Bool {
        existingExercises.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)

                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }

                    TextField("Subgroup (optional)", text: $muscleSubgroup)

                    Toggle("Bodyweight exercise", isOn: $isBodyweight)

                    Toggle("Compound lift", isOn: $isCompound)
                } header: {
                    Text("Exercise Details")
                } footer: {
                    if isDuplicate {
                        Text("An exercise named \"\(trimmedName)\" already exists.")
                            .foregroundStyle(Color.groveMutedRust)
                    } else {
                        Text("Bodyweight exercises track reps only by default, with options for weighted or assisted variants. Compound lifts are placed first when Grove builds a workout.")
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.groveSage)
                        Text("Examples of subgroups: Upper Chest, Long Head, Quads, Obliques")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addExercise()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addExercise() {
        let subgroup = muscleSubgroup.trimmingCharacters(in: .whitespaces)
        let exercise = Exercise(
            name: trimmedName,
            muscleGroup: muscleGroup,
            muscleSubgroup: subgroup.isEmpty ? nil : subgroup,
            isBuiltIn: false,
            isCompound: isCompound,
            sortPriority: isCompound ? 30 : 60,
            isBodyweight: isBodyweight
        )
        exercise.createdBy = users.first
        modelContext.insert(exercise)
        onCreated?(exercise)
        dismiss()
    }
}

#Preview {
    AddExerciseView()
        .modelContainer(for: [Exercise.self, User.self])
}
