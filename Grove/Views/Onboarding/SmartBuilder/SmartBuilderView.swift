import SwiftUI
import SwiftData

struct SmartBuilderView: View {
    var user: User
    var isEditMode: Bool = false
    var onBack: (() -> Void)?
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    /// Built-in and the user's own: their custom lifts belong in their routine too.
    /// (Suggestions still come from built-ins only; see SmartBuilderEngine.pickExercises.)
    @Query private var exercises: [Exercise]
    @State private var state = SmartBuilderState()
    @State private var didInitState = false

    var body: some View {
        ZStack {
            // Background — use solid color to match container (gradient gets clipped by parent)
            Color.groveBackground
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                // Top bar: internal back + step dots
                topBar
                    .padding(.top, isEditMode ? 16 : 52)
                    .padding(.horizontal, 24)

                // Step content — using Group + switch for clean transitions
                Group {
                    switch state.currentStepKind {
                    case .days:
                        DaysPerWeekStep(state: state)
                            .transition(stepTransition)
                    case .setupChoice:
                        SetupChoiceStep(state: state)
                            .transition(stepTransition)
                    case .length:
                        WorkoutLengthStep(state: state)
                            .transition(stepTransition)
                    case .split:
                        SplitAndStyleStep(state: state)
                            .transition(stepTransition)
                    case .customSplit:
                        CustomSplitConfigStep(state: state)
                            .transition(stepTransition)
                    case .dayNames:
                        DayNamesStep(state: state)
                            .transition(stepTransition)
                    case .exercises:
                        ExerciseSelectionStep(state: state, exercises: exercises)
                            .transition(stepTransition)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: state.currentStep)

                // Bottom button
                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            if isEditMode && !didInitState {
                state = SmartBuilderState(from: user)
                didInitState = true
            }
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Back button — step 0 goes back to profile setup (onboarding) or is hidden (edit mode)
            if state.currentStep > 0 || (!isEditMode && onBack != nil) {
                Button {
                    if state.currentStep == 0 {
                        onBack?()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Generated defaults are rebuilt from the answers on the way back in;
                            // exercises someone entered themselves are kept.
                            if state.currentStepKind == .exercises && !state.isOwnRoutine {
                                state.dayExerciseSelections.removeAll()
                            }
                            state.goBack()
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.groveTextSecondary)
                        .frame(width: 32, height: 32)
                }
                .transition(.opacity)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer()

            // Step indicator
            HStack(spacing: 6) {
                ForEach(0...state.totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= state.currentStep ? Color.groveSage : Color.groveSage.opacity(0.2))
                        .frame(width: step == state.currentStep ? 20 : 8, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: state.currentStep)
                }
            }

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
    }

    // MARK: - Bottom Button

    private var isLastStep: Bool { state.currentStepKind == .exercises }

    /// Why Continue is unavailable right now, shown as the button's label.
    private var blockedReason: String? {
        switch state.currentStepKind {
        case .setupChoice where state.setupMode == nil:
            return "Pick one to continue"
        case .customSplit where !state.isCustomConfigValid:
            return "Name each day and pick its muscles"
        case .dayNames where !state.areDayNamesValid:
            return "Name each day to continue"
        case .exercises:
            if let empty = state.firstEmptyDayIndex, empty < state.displayDayLabels.count {
                return "Add exercises to \(state.displayDayLabels[empty])"
            }
            return nil
        default:
            return nil
        }
    }

    private var bottomButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 8) {
                Text(blockedReason ?? (isLastStep ? (isEditMode ? "Save Changes" : "Looks Good") : "Continue"))
                    .font(.headline)

                if isLastStep && blockedReason == nil {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.groveSage, Color.groveSage.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.groveSage.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(blockedReason != nil)
        .opacity(blockedReason != nil ? 0.5 : 1.0)
    }

    /// Fetches the user's current weekly templates in order, for reuse in edit mode
    private func fetchExistingTemplates() -> [WorkoutTemplate] {
        let templateIDs = user.weeklyTemplateIDs
        guard !templateIDs.isEmpty else { return [] }

        let allTemplates: [WorkoutTemplate]
        do {
            allTemplates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
        } catch { return [] }

        let byID = Dictionary(uniqueKeysWithValues: allTemplates.compactMap { ($0.id, $0) })
        return templateIDs.compactMap { byID[$0] }
    }

    private func handleContinue() {
        guard blockedReason == nil else { return }

        if isLastStep {
            if state.isOwnRoutine {
                state.finalizeOwnRoutine()
            }
            if let mode = state.setupMode {
                UserDefaults.standard.set(mode.rawValue, forKey: PlanSetupMode.defaultsKey)
            }
            if isEditMode {
                SmartBuilderEngine.updatePlan(state: state, user: user, context: modelContext)
            } else {
                SmartBuilderEngine.createPlan(state: state, user: user, context: modelContext)
            }
            onComplete()
            return
        }

        switch state.currentStepKind {
        case .split where state.isOwnRoutine:
            // Editing with the same split and days: start from their current workouts.
            let unchanged = isEditMode
                && state.selectedSplit == user.preferredSplit
                && state.daysPerWeek == user.preferredDaysPerWeek
            let templates = unchanged ? fetchExistingTemplates() : []
            state.prepareDayNames(existingNames: templates.count == state.daysPerWeek ? templates.map(\.name) : nil)
        case .split where state.selectedSplit == .custom:
            // Initialize day configs for the custom split step
            state.syncCustomDayCount()
        case .dayNames:
            prepareOwnRoutineExercises()
        default:
            break
        }

        // Generated path: build the suggested exercises right before the editor
        if state.nextStepKind == .exercises && !state.isOwnRoutine {
            if isEditMode {
                state.dayExerciseSelections = SmartBuilderEngine.generateDefaultsForEdit(
                    state: state,
                    allExercises: exercises,
                    existingTemplates: fetchExistingTemplates()
                )
            } else {
                state.dayExerciseSelections = SmartBuilderEngine.generateDefaults(
                    state: state,
                    allExercises: exercises
                )
            }
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            state.advance()
        }
    }

    /// Own-routine days start empty, except when editing: then each day keeps the
    /// exercises of the workout it replaces, so changing one lift isn't a rebuild.
    private func prepareOwnRoutineExercises() {
        // Drop selections for days that no longer exist (day count went down).
        state.dayExerciseSelections = state.dayExerciseSelections.filter { $0.key < state.daysPerWeek }

        // Only carry their current exercises over when the days still line up.
        guard isEditMode,
              state.selectedSplit == user.preferredSplit,
              state.daysPerWeek == user.preferredDaysPerWeek else { return }
        let templates = fetchExistingTemplates()
        let byID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        for index in 0..<state.daysPerWeek where (state.dayExerciseSelections[index] ?? []).isEmpty {
            guard index < templates.count else { continue }
            state.dayExerciseSelections[index] = templates[index].exerciseIDs.compactMap { byID[$0] }
        }
    }
}
