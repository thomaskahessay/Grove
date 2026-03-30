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
    @State private var replacingExerciseLog: ExerciseLog?
    @State private var restTimerSeconds: Int = 0
    @State private var restTimerAfterSetID: UUID? = nil
    @State private var restTimerDuration: Int = 90 // Default 90 seconds
    @State private var timerTask: Task<Void, Never>?
    @State private var exerciseNameVisible = true
    @State private var keyboardVisible = false
    @State private var dragOffset: CGFloat = 0

    private var exercises: [ExerciseLog] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Non-skipped exercises shown in full-screen swipe view
    private var activeExercises: [ExerciseLog] {
        exercises.filter { $0.status != .skipped }
    }

    private var currentExercise: ExerciseLog? {
        guard currentExerciseIndex < activeExercises.count else { return nil }
        return activeExercises[currentExerciseIndex]
    }

    private var progress: String {
        "\(currentExerciseIndex + 1)/\(activeExercises.count)"
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
            .sheet(item: $replacingExerciseLog) { exerciseLog in
                ReplaceExerciseView(workout: workout, exerciseLog: exerciseLog)
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
            .onAppear {
                // Resume at the first incomplete exercise, or last exercise if all done
                if let resumeIndex = activeExercises.firstIndex(where: { $0.status != .completed }) {
                    currentExerciseIndex = resumeIndex
                } else if !activeExercises.isEmpty {
                    currentExerciseIndex = activeExercises.count - 1
                }
            }
            .onChange(of: currentExerciseIndex) {
                exerciseNameVisible = true
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - Full Screen View

    private var fullScreenView: some View {
        VStack(spacing: 0) {
            if activeExercises.isEmpty {
                // All exercises skipped
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "forward.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.groveWarmSand)
                    Text("All exercises skipped")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Button("View All") {
                            showingCardView = true
                        }
                        .buttonStyle(.secondary)
                        Button("End Workout") {
                            endWorkout()
                        }
                        .buttonStyle(.primary)
                    }
                }
                Spacer()
            } else {
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
                    ForEach(Array(activeExercises.enumerated()), id: \.element.id) { index, exerciseLog in
                        ExerciseFullScreenCard(
                            exerciseLog: exerciseLog,
                            onStartTimer: { setID in startRestTimer(afterSetID: setID) },
                            restTimerAfterSetID: restTimerAfterSetID,
                            restTimerSeconds: restTimerSeconds,
                            onAdjustTimer: { delta in restTimerSeconds = max(0, restTimerSeconds + delta) },
                            onSkipTimer: { dismissRestTimer() },
                            onSkip: { skipExercise(exerciseLog) },
                            onReplace: { requestReplace(exerciseLog) },
                            onRemove: { removeExercise(exerciseLog) },
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
        currentExerciseIndex >= activeExercises.count - 1
    }

    private var lastExerciseCompleted: Bool {
        guard let lastExercise = activeExercises.last else { return false }
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

            if isLastExercise {
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
                .disabled(!lastExerciseCompleted)
            } else {
                Button {
                    withAnimation {
                        currentExerciseIndex += 1
                    }
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
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
                        isActive: currentExercise?.id == exerciseLog.id,
                        isDragging: draggingExerciseID == exerciseLog.id,
                        onTap: {
                            // If skipped, unskip first so it reappears in full-screen
                            if exerciseLog.status == .skipped {
                                exerciseLog.status = .planned
                            }
                            // Find the index in activeExercises after potential unskip
                            if let activeIndex = activeExercises.firstIndex(where: { $0.id == exerciseLog.id }) {
                                currentExerciseIndex = activeIndex
                            }
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

    private func startRestTimer(afterSetID: UUID) {
        timerTask?.cancel()
        restTimerSeconds = restTimerDuration
        withAnimation(.easeInOut(duration: 0.3)) {
            restTimerAfterSetID = afterSetID
        }
        timerTask = Task { @MainActor in
            while !Task.isCancelled && restTimerAfterSetID != nil && restTimerSeconds > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }
                guard !Task.isCancelled, restTimerAfterSetID != nil else { break }
                restTimerSeconds -= 1
            }
            if !Task.isCancelled && restTimerSeconds <= 0 {
                dismissRestTimer()
            }
        }
    }

    private func dismissRestTimer() {
        timerTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            restTimerAfterSetID = nil
        }
    }

    // MARK: - Actions

    private func endWorkout() {
        sessionManager.endWorkout(context: modelContext)
    }

    private func discardWorkout() {
        sessionManager.discardWorkout(context: modelContext)
    }

    private func skipExercise(_ exerciseLog: ExerciseLog) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            exerciseLog.status = .skipped
            // Clamp index to stay within the now-smaller activeExercises list
            if currentExerciseIndex >= activeExercises.count {
                currentExerciseIndex = max(0, activeExercises.count - 1)
            }
        }
    }

    private func removeExercise(_ exerciseLog: ExerciseLog) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            // Delete sets first
            for set in exerciseLog.sets {
                modelContext.delete(set)
            }
            workout.exercises.removeAll { $0.id == exerciseLog.id }
            modelContext.delete(exerciseLog)

            // Reindex remaining exercises
            for (i, ex) in exercises.enumerated() {
                ex.orderIndex = i
            }

            // Clamp index
            if currentExerciseIndex >= activeExercises.count {
                currentExerciseIndex = max(0, activeExercises.count - 1)
            }
        }
    }

    private func requestReplace(_ exerciseLog: ExerciseLog) {
        replacingExerciseLog = exerciseLog
    }
}

// MARK: - Exercise Full Screen Card

struct ExerciseFullScreenCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exerciseLog: ExerciseLog
    let onStartTimer: (UUID) -> Void
    var restTimerAfterSetID: UUID? = nil
    var restTimerSeconds: Int = 0
    var onAdjustTimer: ((Int) -> Void)? = nil
    var onSkipTimer: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var onReplace: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil
    var onNameVisibilityChanged: ((Bool) -> Void)? = nil

    @State private var focusedSetID: UUID?
    @State private var exercisePR: PersonalRecord?

    private var sortedSets: [SetLog] {
        exerciseLog.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private var firstSet: SetLog? {
        sortedSets.first
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
                            .foregroundStyle(Color.groveText)
                            .multilineTextAlignment(.center)
                            .onScrollVisibilityChange { visible in
                                onNameVisibilityChanged?(visible)
                            }

                        Text(exerciseLog.exercise?.muscleGroup.rawValue ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let pr = exercisePR {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption)
                                Text("PR: \(pr.weight.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(pr.weight)) : String(format: "%.1f", pr.weight)) lbs x \(pr.reps)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(Color.groveTerracotta)
                        }

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
                    .padding(.top, 20)

                    // Sets
                    VStack(spacing: 12) {
                        ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, setLog in
                            SetRowView(
                                setLog: setLog,
                                setNumber: index + 1,
                                onComplete: { setID in onStartTimer(setID) },
                                onUncomplete: { setID in
                                    if restTimerAfterSetID == setID {
                                        onSkipTimer?()
                                    }
                                },
                                onRemove: sortedSets.count > 1 ? {
                                    removeSet(setLog)
                                } : nil,
                                onWeightChanged: (index == 0 && !exerciseLog.hasLastSessionData) ? { newWeight in
                                    autofillWeight(newWeight)
                                } : nil,
                                onRepsChanged: (index == 0 && !exerciseLog.hasLastSessionData) ? { newReps in
                                    autofillReps(newReps)
                                } : nil,
                                onSetStatusChanged: {
                                    updateExerciseStatus()
                                },
                                onFocused: {
                                    focusedSetID = setLog.id
                                },
                                lastSessionWeight: setLog.lastSessionWeight,
                                lastSessionReps: setLog.lastSessionReps
                            )
                            .id(setLog.id)

                            // Inline rest timer appears after the set that triggered it
                            if restTimerAfterSetID == setLog.id {
                                RestTimerRowView(
                                    seconds: restTimerSeconds,
                                    onAdjust: { delta in onAdjustTimer?(delta) },
                                    onSkip: { onSkipTimer?() }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .id("timer-\(setLog.id)")
                            }
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

                    // Exercise actions
                    HStack(spacing: 24) {
                        Button {
                            if let onSkip {
                                onSkip()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    exerciseLog.status = .skipped
                                }
                            }
                        } label: {
                            Label("Skip", systemImage: "forward.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveMutedRust)
                        }

                        Button {
                            onReplace?()
                        } label: {
                            Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveTextSecondary)
                        }

                        Button {
                            onRemove?()
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveMutedRust.opacity(0.7))
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
            .onChange(of: restTimerAfterSetID) { _, newID in
                if let newID {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("timer-\(newID)", anchor: .center)
                    }
                }
            }
        }
        .task(id: exerciseLog.exercise?.id) {
            guard let exerciseID = exerciseLog.exercise?.id else { return }
            let descriptor = FetchDescriptor<PersonalRecord>(
                predicate: #Predicate<PersonalRecord> { $0.exercise?.id == exerciseID }
            )
            let records = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.type == .maxWeight }
            exercisePR = records.max { a, b in
                if a.value != b.value { return a.value < b.value }
                return a.reps < b.reps
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
    let onComplete: (UUID) -> Void
    let onUncomplete: ((UUID) -> Void)?
    let onRemove: (() -> Void)?
    var onWeightChanged: ((Double?) -> Void)? = nil
    var onRepsChanged: ((Int?) -> Void)? = nil
    var onSetStatusChanged: (() -> Void)? = nil
    var onFocused: (() -> Void)? = nil
    var lastSessionWeight: Double? = nil
    var lastSessionReps: Int? = nil

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    private var isEditing: Bool {
        weightFocused || repsFocused
    }

    private var valuesChangedFromLastSession: Bool {
        guard lastSessionWeight != nil || lastSessionReps != nil else { return false }
        return setLog.weight != lastSessionWeight || setLog.reps != lastSessionReps
    }

    private var lastSessionHint: String {
        var parts: [String] = []
        if let w = lastSessionWeight {
            let weightStr = w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
            parts.append("\(weightStr) lbs")
        }
        if let r = lastSessionReps {
            parts.append("\(r) reps")
        }
        return "Last: " + parts.joined(separator: " x ")
    }

    var body: some View {
        VStack(spacing: 2) {
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

        if valuesChangedFromLastSession {
            HStack {
                Spacer().frame(width: 36)
                Text(lastSessionHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
                Spacer()
            }
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
            onComplete(setLog.id)
        } else {
            setLog.completedAt = nil
            onUncomplete?(setLog.id)
        }
        onSetStatusChanged?()
    }
}

// MARK: - Rest Timer Row (inline)

struct RestTimerRowView: View {
    let seconds: Int
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.headline)
                .foregroundStyle(Color.groveSage)

            Text(formatTime(seconds))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.groveText)
                .monospacedDigit()
                .frame(minWidth: 60)

            Spacer()

            Button { onAdjust(-30) } label: {
                Text("-30s")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.groveWarmSand.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.groveText)

            Button { onAdjust(30) } label: {
                Text("+30s")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.groveWarmSand.opacity(0.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.groveText)

            Button { onSkip() } label: {
                Text("Skip")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveMutedRust)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.groveSage.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.groveSage.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
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
        let lastSets = Self.getLastSetsForExercise(exercise, context: modelContext)
        let numberOfSets = lastSets.isEmpty ? 3 : lastSets.count
        let newIndex = workout.exercises.count
        let exerciseLog = ExerciseLog(
            exercise: exercise,
            orderIndex: newIndex,
            targetSets: numberOfSets,
            targetReps: 10
        )
        exerciseLog.workout = workout

        for i in 1...numberOfSets {
            let lastSetData = lastSets.indices.contains(i - 1) ? lastSets[i - 1] : nil
            let setLog = SetLog(setNumber: i, weight: lastSetData?.weight, reps: lastSetData?.reps)
            setLog.lastSessionWeight = lastSetData?.weight
            setLog.lastSessionReps = lastSetData?.reps
            setLog.exerciseLog = exerciseLog
            exerciseLog.sets.append(setLog)
        }

        modelContext.insert(exerciseLog)
        dismiss()
    }

    private static func getLastSetsForExercise(_ exercise: Exercise, context: ModelContext) -> [(weight: Double?, reps: Int?)] {
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exerciseID
            },
            sortBy: [SortDescriptor(\.workout?.completedAt, order: .reverse)]
        )

        guard let logs = try? context.fetch(descriptor) else { return [] }
        guard let lastLog = logs.first(where: { $0.workout?.completedAt != nil }) else { return [] }

        return lastLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
            .map { (weight: $0.weight, reps: $0.reps) }
    }
}

// MARK: - Replace Exercise View

struct ReplaceExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let workout: Workout
    let exerciseLog: ExerciseLog

    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        let workoutExerciseIDs = Set(workout.exercises.compactMap { $0.exercise?.id })
        let available = allExercises.filter { !workoutExerciseIDs.contains($0.id) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button {
                    replaceWith(exercise)
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
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.groveSage)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func replaceWith(_ newExercise: Exercise) {
        // Delete old sets
        for set in exerciseLog.sets {
            modelContext.delete(set)
        }
        exerciseLog.sets.removeAll()

        // Swap the exercise
        exerciseLog.exercise = newExercise
        exerciseLog.status = .planned

        // Auto-fill from last completed session
        let lastSets = getLastSetsForExercise(newExercise)
        let numberOfSets = lastSets.isEmpty ? 3 : lastSets.count

        for i in 1...numberOfSets {
            let lastSetData = lastSets.indices.contains(i - 1) ? lastSets[i - 1] : nil
            let setLog = SetLog(setNumber: i, weight: lastSetData?.weight, reps: lastSetData?.reps)
            setLog.lastSessionWeight = lastSetData?.weight
            setLog.lastSessionReps = lastSetData?.reps
            setLog.exerciseLog = exerciseLog
            exerciseLog.sets.append(setLog)
            modelContext.insert(setLog)
        }

        dismiss()
    }

    private func getLastSetsForExercise(_ exercise: Exercise) -> [(weight: Double?, reps: Int?)] {
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate<ExerciseLog> { log in
                log.exercise?.id == exerciseID
            },
            sortBy: [SortDescriptor(\.workout?.completedAt, order: .reverse)]
        )

        guard let logs = try? modelContext.fetch(descriptor) else { return [] }
        guard let lastLog = logs.first(where: { $0.workout?.completedAt != nil }) else { return [] }

        return lastLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
            .map { (weight: $0.weight, reps: $0.reps) }
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
