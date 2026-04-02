import SwiftUI
import SwiftData

struct SmartBuilderView: View {
    var user: User
    var isEditMode: Bool = false
    var onBack: (() -> Void)?
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { $0.isBuiltIn }) private var exercises: [Exercise]
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
                    switch state.currentStep {
                    case 0:
                        DaysPerWeekStep(state: state)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 1:
                        WorkoutLengthStep(state: state)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 2:
                        SplitAndStyleStep(state: state)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 3 where state.selectedSplit == .custom:
                        CustomSplitConfigStep(state: state)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    default:
                        ExerciseSelectionStep(state: state, exercises: exercises)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
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
                            if state.currentStep == state.totalSteps {
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

    private var bottomButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 8) {
                Text(state.currentStep == state.totalSteps ? (isEditMode ? "Save Changes" : "Looks Good") : "Continue")
                    .font(.headline)

                if state.currentStep == state.totalSteps {
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
        .disabled(!state.isCustomConfigValid && state.selectedSplit == .custom && state.currentStep == 3)
        .opacity(!state.isCustomConfigValid && state.selectedSplit == .custom && state.currentStep == 3 ? 0.5 : 1.0)
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
        if state.currentStep == state.totalSteps {
            if isEditMode {
                SmartBuilderEngine.updatePlan(state: state, user: user, context: modelContext)
            } else {
                SmartBuilderEngine.createPlan(state: state, user: user, context: modelContext)
            }
            onComplete()
        } else {
            // When leaving split selection with custom selected, initialize day configs
            if state.currentStep == 2 && state.selectedSplit == .custom {
                state.syncCustomDayCount()
            }

            // Generate exercise defaults on the step just before exercise selection
            let preExerciseStep = state.totalSteps - 1
            if state.currentStep == preExerciseStep {
                if isEditMode {
                    let existingTemplates = fetchExistingTemplates()
                    state.dayExerciseSelections = SmartBuilderEngine.generateDefaultsForEdit(
                        state: state,
                        allExercises: exercises,
                        existingTemplates: existingTemplates
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
    }
}
