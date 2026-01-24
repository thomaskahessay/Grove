import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var workout: Workout

    @State private var currentExerciseIndex = 0
    @State private var showingCardView = false
    @State private var showingEndWorkoutAlert = false
    @State private var showingAddExercise = false
    @State private var restTimerSeconds: Int = 0
    @State private var restTimerActive = false
    @State private var restTimerDuration: Int = 90 // Default 90 seconds

    private var exercises: [ExerciseLog] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var currentExercise: ExerciseLog? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    private var progress: String {
        "\(currentExerciseIndex + 1)/\(exercises.count)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.groveBackground
                    .ignoresSafeArea()

                if showingCardView {
                    cardView
                } else {
                    fullScreenView
                }

                // Rest Timer Overlay
                if restTimerActive {
                    restTimerOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") {
                        showingEndWorkoutAlert = true
                    }
                    .foregroundStyle(Color.groveMutedRust)
                }

                ToolbarItem(placement: .principal) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCardView.toggle()
                    } label: {
                        Image(systemName: showingCardView ? "rectangle.expand.vertical" : "list.bullet")
                    }
                    .tint(Color.groveSage)
                }
            }
            .alert("End Workout?", isPresented: $showingEndWorkoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End", role: .destructive) {
                    endWorkout()
                }
            } message: {
                Text("Your progress will be saved.")
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseToWorkoutView(workout: workout)
            }
        }
    }

    // MARK: - Full Screen View

    private var fullScreenView: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack {
                Text(progress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                }
                .tint(Color.groveSage)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Exercise content with swipe
            TabView(selection: $currentExerciseIndex) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exerciseLog in
                    ExerciseFullScreenCard(
                        exerciseLog: exerciseLog,
                        onStartTimer: { startRestTimer() }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Navigation buttons
            navigationButtons
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation {
                    if currentExerciseIndex > 0 {
                        currentExerciseIndex -= 1
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
            .disabled(currentExerciseIndex == 0)

            Button {
                withAnimation {
                    if currentExerciseIndex < exercises.count - 1 {
                        currentExerciseIndex += 1
                    }
                }
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(currentExerciseIndex >= exercises.count - 1)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Card View

    private var cardView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exerciseLog in
                    ExerciseCardRow(
                        exerciseLog: exerciseLog,
                        isActive: index == currentExerciseIndex,
                        onTap: {
                            currentExerciseIndex = index
                            showingCardView = false
                        }
                    )
                }

                // Add exercise button
                Button {
                    showingAddExercise = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.groveCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.groveSage)
            }
            .padding()
        }
    }

    // MARK: - Rest Timer

    private var restTimerOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    restTimerActive = false
                }

            VStack(spacing: 24) {
                Text("Rest")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Text(formatTime(restTimerSeconds))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                HStack(spacing: 20) {
                    Button {
                        restTimerSeconds = max(0, restTimerSeconds - 30)
                    } label: {
                        Text("-30s")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    Button {
                        restTimerSeconds += 30
                    } label: {
                        Text("+30s")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.white)

                Button {
                    restTimerActive = false
                } label: {
                    Text("Skip")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            startTimerCountdown()
        }
    }

    private func startRestTimer() {
        restTimerSeconds = restTimerDuration
        restTimerActive = true
    }

    private func startTimerCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restTimerSeconds > 0 && restTimerActive {
                restTimerSeconds -= 1
            } else {
                timer.invalidate()
                if restTimerSeconds == 0 {
                    restTimerActive = false
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Actions

    private func endWorkout() {
        workout.completedAt = Date()

        // Mark any in-progress exercises as completed
        for exercise in exercises {
            if exercise.status == .inProgress {
                exercise.status = .completed
            }
        }

        dismiss()
    }
}

// MARK: - Exercise Full Screen Card

struct ExerciseFullScreenCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exerciseLog: ExerciseLog
    let onStartTimer: () -> Void

    private var sortedSets: [SetLog] {
        exerciseLog.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private var firstSet: SetLog? {
        sortedSets.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Exercise header
                VStack(spacing: 8) {
                    Text(exerciseLog.exercise?.name ?? "Exercise")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)
                        .multilineTextAlignment(.center)

                    Text(exerciseLog.exercise?.muscleGroup.rawValue ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Sets
                VStack(spacing: 12) {
                    ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, setLog in
                        SetRowView(
                            setLog: setLog,
                            setNumber: index + 1,
                            onComplete: onStartTimer,
                            onRemove: sortedSets.count > 1 ? {
                                removeSet(setLog)
                            } : nil,
                            onWeightChanged: index == 0 ? { newWeight in
                                autofillWeight(newWeight)
                            } : nil,
                            onRepsChanged: index == 0 ? { newReps in
                                autofillReps(newReps)
                            } : nil
                        )
                    }

                    // Add set button
                    Button {
                        addSet()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Set")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.groveSage)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.groveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Rest timer button
                Button {
                    onStartTimer()
                } label: {
                    HStack {
                        Image(systemName: "timer")
                        Text("Start Rest Timer")
                    }
                }
                .buttonStyle(.secondary)
                .padding(.horizontal)

                // Skip exercise button
                if exerciseLog.status != .skipped {
                    Button {
                        exerciseLog.status = .skipped
                    } label: {
                        Text("Skip Exercise")
                            .font(.subheadline)
                            .foregroundStyle(Color.groveMutedRust)
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func addSet() {
        let newSetNumber = exerciseLog.sets.count + 1
        let lastSet = exerciseLog.sets.last
        let newSet = SetLog(
            setNumber: newSetNumber,
            weight: lastSet?.weight,
            reps: lastSet?.reps
        )
        newSet.exerciseLog = exerciseLog
        exerciseLog.sets.append(newSet)
        modelContext.insert(newSet)
    }

    private func removeSet(_ setLog: SetLog) {
        withAnimation {
            exerciseLog.sets.removeAll { $0.id == setLog.id }
            modelContext.delete(setLog)

            // Renumber remaining sets
            for (index, set) in exerciseLog.sets.sorted(by: { $0.setNumber < $1.setNumber }).enumerated() {
                set.setNumber = index + 1
            }
        }
    }

    private func autofillWeight(_ newWeight: Double?) {
        // Fill subsequent incomplete sets with the first set's weight
        for set in sortedSets.dropFirst() where !set.isCompleted {
            set.weight = newWeight
        }
    }

    private func autofillReps(_ newReps: Int?) {
        // Fill subsequent incomplete sets with the first set's reps
        for set in sortedSets.dropFirst() where !set.isCompleted {
            set.reps = newReps
        }
    }
}

// MARK: - Set Row View

struct SetRowView: View {
    @Bindable var setLog: SetLog
    let setNumber: Int
    let onComplete: () -> Void
    let onRemove: (() -> Void)?
    var onWeightChanged: ((Double?) -> Void)? = nil
    var onRepsChanged: ((Int?) -> Void)? = nil

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(setNumber)")
                .font(.headline)
                .foregroundStyle(setLog.isCompleted ? Color.groveSage : .secondary)
                .frame(width: 24)

            // Weight stepper with editable field
            VStack(spacing: 4) {
                Text("Weight")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Button {
                        decrementWeight()
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(Color.groveWarmSand.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    TextField("0", text: $weightText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                        .onSubmit { syncWeightFromText() }
                        .onChange(of: weightFocused) { _, focused in
                            if !focused { syncWeightFromText() }
                        }

                    Button {
                        incrementWeight()
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(Color.groveWarmSand.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Reps stepper with editable field
            VStack(spacing: 4) {
                Text("Reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Button {
                        decrementReps()
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(Color.groveWarmSand.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    TextField("0", text: $repsText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(width: 36)
                        .keyboardType(.numberPad)
                        .focused($repsFocused)
                        .onSubmit { syncRepsFromText() }
                        .onChange(of: repsFocused) { _, focused in
                            if !focused { syncRepsFromText() }
                        }

                    Button {
                        incrementReps()
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(Color.groveWarmSand.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Complete checkbox
            Button {
                toggleComplete()
            } label: {
                Image(systemName: setLog.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(setLog.isCompleted ? Color.groveSage : .secondary)
            }
            .buttonStyle(.plain)

            // Remove set button
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveMutedRust.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(setLog.isCompleted ? Color.groveSage.opacity(0.1) : Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            syncTextFromSetLog()
        }
        .onChange(of: setLog.weight) { _, _ in
            if !weightFocused { syncTextFromSetLog() }
        }
        .onChange(of: setLog.reps) { _, _ in
            if !repsFocused { syncTextFromSetLog() }
        }
    }

    private func syncTextFromSetLog() {
        if let weight = setLog.weight {
            // Show decimal only if needed (e.g., 135 vs 137.5)
            if weight.truncatingRemainder(dividingBy: 1) == 0 {
                weightText = String(Int(weight))
            } else {
                weightText = String(format: "%.1f", weight)
            }
        } else {
            weightText = ""
        }
        repsText = setLog.reps.map { String($0) } ?? ""
    }

    private func syncWeightFromText() {
        if let value = Double(weightText) {
            setLog.weight = value
            onWeightChanged?(value)
        } else if weightText.isEmpty {
            setLog.weight = nil
            onWeightChanged?(nil)
        }
    }

    private func syncRepsFromText() {
        if let value = Int(repsText) {
            setLog.reps = value
            onRepsChanged?(value)
        } else if repsText.isEmpty {
            setLog.reps = nil
            onRepsChanged?(nil)
        }
    }

    private func incrementWeight() {
        let current = setLog.weight ?? 0
        let newWeight = current + 5
        setLog.weight = newWeight
        syncTextFromSetLog()
        onWeightChanged?(newWeight)
    }

    private func decrementWeight() {
        let current = setLog.weight ?? 0
        let newWeight = max(0, current - 5)
        setLog.weight = newWeight
        syncTextFromSetLog()
        onWeightChanged?(newWeight)
    }

    private func incrementReps() {
        let current = setLog.reps ?? 0
        let newReps = current + 1
        setLog.reps = newReps
        syncTextFromSetLog()
        onRepsChanged?(newReps)
    }

    private func decrementReps() {
        let current = setLog.reps ?? 0
        let newReps = max(0, current - 1)
        setLog.reps = newReps
        syncTextFromSetLog()
        onRepsChanged?(newReps)
    }

    private func toggleComplete() {
        setLog.isCompleted.toggle()
        if setLog.isCompleted {
            setLog.completedAt = Date()
            onComplete()
        } else {
            setLog.completedAt = nil
        }
    }
}

// MARK: - Exercise Card Row (for card view)

struct ExerciseCardRow: View {
    let exerciseLog: ExerciseLog
    let isActive: Bool
    let onTap: () -> Void

    private var completedSets: Int {
        exerciseLog.sets.filter { $0.isCompleted }.count
    }

    private var statusIcon: String {
        switch exerciseLog.status {
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "xmark.circle.fill"
        case .inProgress: return "circle.lefthalf.filled"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch exerciseLog.status {
        case .completed: return .groveSage
        case .skipped: return .groveMutedRust
        case .inProgress: return .groveTerracotta
        default: return .secondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exerciseLog.exercise?.name ?? "Exercise")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(exerciseLog.status == .skipped ? .secondary : Color.groveText)
                        .strikethrough(exerciseLog.status == .skipped)

                    Text("\(completedSets)/\(exerciseLog.sets.count) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.groveSage)
                }
            }
            .padding()
            .background(isActive ? Color.groveSage.opacity(0.1) : Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.groveSage : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Exercise to Workout View

struct AddExerciseToWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let workout: Workout

    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return allExercises
        }
        return allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button {
                    addExercise(exercise)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .foregroundStyle(Color.groveText)
                            Text(exercise.muscleGroup.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let newIndex = workout.exercises.count
        let exerciseLog = ExerciseLog(
            exercise: exercise,
            orderIndex: newIndex,
            targetSets: 3,
            targetReps: 10
        )
        exerciseLog.workout = workout

        // Create default sets
        for i in 1...3 {
            let setLog = SetLog(setNumber: i)
            setLog.exerciseLog = exerciseLog
            exerciseLog.sets.append(setLog)
        }

        modelContext.insert(exerciseLog)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, ExerciseLog.self, SetLog.self, Exercise.self,
        configurations: config
    )

    let workout = Workout(name: "Push Day")
    container.mainContext.insert(workout)

    let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, muscleSubgroup: "Middle")
    container.mainContext.insert(exercise)

    let exerciseLog = ExerciseLog(exercise: exercise, orderIndex: 0, targetSets: 3, targetReps: 10)
    exerciseLog.workout = workout
    container.mainContext.insert(exerciseLog)

    for i in 1...3 {
        let setLog = SetLog(setNumber: i, weight: 135, reps: 8)
        setLog.exerciseLog = exerciseLog
        container.mainContext.insert(setLog)
    }

    return ActiveWorkoutView(workout: workout)
        .modelContainer(container)
}
