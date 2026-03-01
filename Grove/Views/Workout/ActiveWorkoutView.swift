import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager

    @Bindable var workout: Workout

    @State private var currentExerciseIndex = 0
    @State private var showingCardView = false
    @State private var showingAddExercise = false
    @State private var restTimerSeconds: Int = 0
    @State private var restTimerActive = false
    @State private var restTimerDuration: Int = 90 // Default 90 seconds
    @State private var exerciseNameVisible = true
    @State private var keyboardVisible = false
    @State private var dragOffset: CGFloat = 0

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
                    Menu {
                        Button("Save Workout", systemImage: "checkmark.circle") {
                            endWorkout()
                        }
                        Button("Discard Workout", systemImage: "trash", role: .destructive) {
                            discardWorkout()
                        }
                    } label: {
                        Text("End")
                            .foregroundStyle(Color.groveMutedRust)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(!exerciseNameVisible && !showingCardView
                         ? (currentExercise?.exercise?.name ?? workout.name)
                         : workout.name)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                        .animation(.easeInOut(duration: 0.2), value: exerciseNameVisible)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingCardView.toggle()
                        } label: {
                            Image(systemName: showingCardView ? "rectangle.expand.vertical" : "list.bullet")
                        }
                        .tint(Color.groveSage)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sessionManager.minimizeWorkout()
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                        }
                        .tint(Color.groveSage)
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseToWorkoutView(workout: workout)
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let dy = value.translation.height
                        let dx = value.translation.width
                        guard dy > abs(dx) else { return }
                        dragOffset = dy * 0.6
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height
                        if value.translation.height > 80 || velocity > 300 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                sessionManager.minimizeWorkout()
                            }
                            dragOffset = 0
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onChange(of: currentExerciseIndex) {
                exerciseNameVisible = true
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

            // Exercise content with swipe (disabled when keyboard is showing)
            TabView(selection: $currentExerciseIndex) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exerciseLog in
                    ExerciseFullScreenCard(
                        exerciseLog: exerciseLog,
                        onStartTimer: { startRestTimer() },
                        onNameVisibilityChanged: index == currentExerciseIndex ? { visible in
                            exerciseNameVisible = visible
                        } : nil
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Navigation buttons (hidden when keyboard is showing)
            if !keyboardVisible {
                navigationButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: keyboardVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    private var isLastExercise: Bool {
        currentExerciseIndex >= exercises.count - 1
    }

    private var lastExerciseCompleted: Bool {
        guard let lastExercise = exercises.last else { return false }
        if lastExercise.status == .skipped { return true }
        return lastExercise.sets.allSatisfy { $0.isCompleted } && !lastExercise.sets.isEmpty
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

            if isLastExercise && lastExerciseCompleted {
                Button {
                    endWorkout()
                } label: {
                    HStack {
                        Text("Done")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            } else {
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
                .disabled(isLastExercise)
            }
        }
        .padding()
        .background(Color.groveBackground)
    }

    // MARK: - Card View

    @State private var draggingExerciseID: UUID?

    private var cardView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exerciseLog in
                    ExerciseCardRowDraggable(
                        exerciseLog: exerciseLog,
                        isActive: index == currentExerciseIndex,
                        isDragging: draggingExerciseID == exerciseLog.id,
                        onTap: {
                            currentExerciseIndex = index
                            showingCardView = false
                        }
                    )
                    .onDrag {
                        draggingExerciseID = exerciseLog.id
                        return NSItemProvider(object: exerciseLog.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ExerciseDropDelegate(
                        exerciseLog: exerciseLog,
                        exercises: exercises,
                        draggingExerciseID: $draggingExerciseID,
                        currentExerciseIndex: $currentExerciseIndex
                    ))
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
        .onDrop(of: [.text], isTargeted: nil) { _ in
            // Reset dragging state when dropped anywhere
            DispatchQueue.main.async {
                draggingExerciseID = nil
            }
            return true
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
        sessionManager.endWorkout(context: modelContext)
    }

    private func discardWorkout() {
        sessionManager.discardWorkout(context: modelContext)
    }
}

// MARK: - Exercise Full Screen Card

struct ExerciseFullScreenCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exerciseLog: ExerciseLog
    let onStartTimer: () -> Void
    var onNameVisibilityChanged: ((Bool) -> Void)? = nil

    @State private var focusedSetID: UUID?

    private var sortedSets: [SetLog] {
        exerciseLog.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private var firstSet: SetLog? {
        sortedSets.first
    }

    private var isSkipped: Bool {
        exerciseLog.status == .skipped
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Exercise header
                    VStack(spacing: 8) {
                        Text(exerciseLog.exercise?.name ?? "Exercise")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(isSkipped ? .secondary : Color.groveText)
                            .strikethrough(isSkipped)
                            .multilineTextAlignment(.center)
                            .onScrollVisibilityChange { visible in
                                onNameVisibilityChanged?(visible)
                            }

                        Text(exerciseLog.exercise?.muscleGroup.rawValue ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if isSkipped {
                            // Skipped badge
                            HStack(spacing: 6) {
                                Image(systemName: "forward.fill")
                                    .font(.caption)
                                Text("Skipped")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(Color.groveMutedRust)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.groveMutedRust.opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                        } else {
                            // Set progress bar
                            HStack(spacing: 8) {
                                let completed = sortedSets.filter(\.isCompleted).count
                                let total = sortedSets.count

                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.groveWarmSand.opacity(0.3))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.groveSage)
                                                .frame(width: total > 0 ? geo.size.width * CGFloat(completed) / CGFloat(total) : 0)
                                                .animation(.easeInOut(duration: 0.3), value: completed)
                                        }
                                }
                                .frame(width: 120, height: 6)

                                Text("\(sortedSets.filter(\.isCompleted).count)/\(sortedSets.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 20)

                    if isSkipped {
                        // Skipped state: prominent message instead of sets
                        VStack(spacing: 16) {
                            Image(systemName: "forward.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.groveWarmSand)

                            Text("This exercise has been skipped")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    exerciseLog.status = .planned
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Unskip Exercise")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveSage)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.groveSage.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
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
                                    } : nil,
                                    onSetStatusChanged: {
                                        updateExerciseStatus()
                                    },
                                    onFocused: {
                                        focusedSetID = setLog.id
                                    }
                                )
                                .id(setLog.id)
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

                        // Skip exercise button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                exerciseLog.status = .skipped
                            }
                        } label: {
                            Text("Skip Exercise")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveMutedRust)
                        }
                    }

                }
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedSetID) { _, newID in
                if let newID {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
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

    private func updateExerciseStatus() {
        let allSetsCompleted = exerciseLog.sets.allSatisfy { $0.isCompleted }
        let anySetsCompleted = exerciseLog.sets.contains { $0.isCompleted }

        if allSetsCompleted && !exerciseLog.sets.isEmpty {
            exerciseLog.status = .completed
        } else if anySetsCompleted {
            exerciseLog.status = .inProgress
        } else {
            exerciseLog.status = .planned
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
    var onSetStatusChanged: (() -> Void)? = nil
    var onFocused: (() -> Void)? = nil

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    private var isEditing: Bool {
        weightFocused || repsFocused
    }

    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(setNumber)")
                .font(.headline)
                .foregroundStyle(setLog.isCompleted ? Color.groveSage : .secondary)
                .frame(width: 24)

            // Weight input
            VStack(spacing: 4) {
                Text("Weight")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    if weightFocused {
                        Button {
                            decrementWeight()
                        } label: {
                            Text("-5")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.groveText)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    }

                    TextField("0", text: $weightText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                        .onSubmit { syncWeightFromText() }
                        .onChange(of: weightFocused) { _, focused in
                            if focused { onFocused?() }
                            else { syncWeightFromText() }
                        }

                    if weightFocused {
                        Button {
                            incrementWeight()
                        } label: {
                            Text("+5")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.groveText)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(height: 34)
                .background(Color.groveWarmSand.opacity(weightFocused ? 0.25 : 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(weightFocused ? Color.groveSage.opacity(0.5) : Color.groveWarmSand.opacity(0.4), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)

            // Reps input
            VStack(spacing: 4) {
                Text("Reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    if repsFocused {
                        Button {
                            decrementReps()
                        } label: {
                            Text("-1")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.groveText)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    }

                    TextField("0", text: $repsText)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($repsFocused)
                        .onSubmit { syncRepsFromText() }
                        .onChange(of: repsFocused) { _, focused in
                            if focused { onFocused?() }
                            else { syncRepsFromText() }
                        }

                    if repsFocused {
                        Button {
                            incrementReps()
                        } label: {
                            Text("+1")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.groveText)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(height: 34)
                .background(Color.groveWarmSand.opacity(repsFocused ? 0.25 : 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(repsFocused ? Color.groveSage.opacity(0.5) : Color.groveWarmSand.opacity(0.4), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)

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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(setLog.isCompleted ? Color.groveSage.opacity(0.1) : Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: weightFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: repsFocused)
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
        onSetStatusChanged?()
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
        case .skipped: return "forward.circle.fill"
        case .inProgress: return "circle.lefthalf.filled"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch exerciseLog.status {
        case .completed: return .groveSage
        case .skipped: return .secondary
        case .inProgress: return .groveTerracotta
        default: return .secondary
        }
    }

    var showDragHandle: Bool = true

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if showDragHandle {
                    Image(systemName: "line.3.horizontal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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

// MARK: - Draggable Exercise Card Row

struct ExerciseCardRowDraggable: View {
    let exerciseLog: ExerciseLog
    let isActive: Bool
    let isDragging: Bool
    let onTap: () -> Void

    private var completedSets: Int {
        exerciseLog.sets.filter { $0.isCompleted }.count
    }

    private var statusIcon: String {
        switch exerciseLog.status {
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "forward.circle.fill"
        case .inProgress: return "circle.lefthalf.filled"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch exerciseLog.status {
        case .completed: return .groveSage
        case .skipped: return .secondary
        case .inProgress: return .groveTerracotta
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle on the left
            Image(systemName: "line.3.horizontal")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Exercise info
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

            // Status icon on the right
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
        }
        .padding()
        .background(isActive ? Color.groveSage.opacity(0.1) : Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.groveSage : Color.clear, lineWidth: 2)
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Exercise Drop Delegate

struct ExerciseDropDelegate: DropDelegate {
    let exerciseLog: ExerciseLog
    let exercises: [ExerciseLog]
    @Binding var draggingExerciseID: UUID?
    @Binding var currentExerciseIndex: Int

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            draggingExerciseID = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingExerciseID,
              draggingID != exerciseLog.id,
              let sourceIndex = exercises.firstIndex(where: { $0.id == draggingID }),
              let destIndex = exercises.firstIndex(where: { $0.id == exerciseLog.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            // Swap the orderIndex values
            let sourceExercise = exercises[sourceIndex]
            let destExercise = exercises[destIndex]

            let tempIndex = sourceExercise.orderIndex
            sourceExercise.orderIndex = destExercise.orderIndex
            destExercise.orderIndex = tempIndex

            // Update currentExerciseIndex if needed
            if currentExerciseIndex == sourceIndex {
                currentExerciseIndex = destIndex
            } else if currentExerciseIndex == destIndex {
                currentExerciseIndex = sourceIndex
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // Don't reset here as user might be moving to another card
    }
}

// MARK: - Add Exercise to Workout View

struct AddExerciseToWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let workout: Workout

    @State private var searchText = ""

    private var existingExerciseIDs: Set<UUID> {
        Set(workout.exercises.compactMap { $0.exercise?.id })
    }

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
                let alreadyAdded = existingExerciseIDs.contains(exercise.id)
                Button {
                    addExercise(exercise)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .foregroundStyle(alreadyAdded ? .secondary : Color.groveText)
                            Text(exercise.muscleGroup.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(alreadyAdded ? .secondary : Color.groveSage)
                    }
                }
                .disabled(alreadyAdded)
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
        .environment(WorkoutSessionManager())
        .modelContainer(container)
}
