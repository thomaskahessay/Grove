import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var muscleSubgroup = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                } header: {
                    Text("Exercise Details")
                } footer: {
                    Text("Custom exercises are private to your account.")
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
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            muscleGroup: muscleGroup,
            muscleSubgroup: muscleSubgroup.isEmpty ? nil : muscleSubgroup.trimmingCharacters(in: .whitespaces),
            isBuiltIn: false
        )
        modelContext.insert(exercise)
        dismiss()
    }
}

#Preview {
    AddExerciseView()
        .modelContainer(for: [Exercise.self])
}
