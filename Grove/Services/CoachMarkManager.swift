import SwiftUI

@MainActor
@Observable
class CoachMarkManager {
    // MARK: - Tour Definition

    enum TourStep: Int, CaseIterable {
        case todaysWorkout = 0
        case streakPlant = 1
        case planMyWeek = 2
        case progressTab = 3
        case socialTab = 4
        /// Back on Today, pointing at the workout card again: the tour ends on doing something.
        case firstWorkout = 5
    }

    struct StepContent {
        let title: String
        let description: String
        let tooltipEdge: Edge
    }

    // MARK: - State

    var isActive: Bool = false
    var currentStep: TourStep = .todaysWorkout
    var anchorFrames: [TourStep: CGRect] = [:]

    // MARK: - Computed

    var currentStepContent: StepContent { stepContent(for: currentStep) }
    var currentFrame: CGRect? { anchorFrames[anchorStep(for: currentStep)] }
    var stepIndex: Int { currentStep.rawValue }
    var totalSteps: Int { TourStep.allCases.count }
    var isLastStep: Bool { currentStep == TourStep.allCases.last }

    // MARK: - Actions

    func startTourIfNeeded() {
        guard !Self.hasSeenTour else { return }
        start()
    }

    /// Runs the tour again from the start (Settings → Show App Tour).
    func replay() {
        guard !isActive else { return }
        start()
    }

    private func start() {
        currentStep = .todaysWorkout
        Task {
            // Poll briefly for the first step's frame (max ~1 second)
            for _ in 0..<10 {
                if anchorFrames[.todaysWorkout] != nil { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            withAnimation(.easeIn(duration: 0.4)) {
                isActive = true
                currentStep = .todaysWorkout
            }
        }
    }

    func advance() {
        guard let nextRaw = TourStep(rawValue: currentStep.rawValue + 1) else {
            completeTour()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = nextRaw
        }
    }

    func skip() {
        completeTour()
    }

    func registerFrame(_ step: TourStep, frame: CGRect) {
        anchorFrames[step] = frame
    }

    // MARK: - Persistence

    @ObservationIgnored
    static var hasSeenTour: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenHomeTour") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenHomeTour") }
    }

    // MARK: - Private

    /// Steps that point at a view another step already registered.
    private func anchorStep(for step: TourStep) -> TourStep {
        step == .firstWorkout ? .todaysWorkout : step
    }

    private func completeTour() {
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }
        Self.hasSeenTour = true
    }

    private func stepContent(for step: TourStep) -> StepContent {
        switch step {
        case .todaysWorkout:
            StepContent(
                title: "Today's Workout",
                description: "Your plan for today lives here. Tap Start Workout to follow it, or pick something else if you'd rather.",
                tooltipEdge: .bottom
            )
        case .streakPlant:
            StepContent(
                title: "Your Streak Plant",
                description: "Every day you work out, your plant grows. It only wilts if a whole week goes by with no workouts, so rest days are safe.",
                tooltipEdge: .bottom
            )
        case .planMyWeek:
            StepContent(
                title: "Your Week",
                description: "Each icon is the workout planned that day, and a moon is a rest day. Tap a day to change it, or use Plan My Week.",
                tooltipEdge: .top
            )
        case .progressTab:
            StepContent(
                title: "Progress",
                description: "After your first workout, your personal records and strength trends show up here.",
                tooltipEdge: .top
            )
        case .socialTab:
            StepContent(
                title: "Your Grove",
                description: "Everyone's workouts land here. Cheer them on with water, seeds, and sunlight.",
                tooltipEdge: .top
            )
        case .firstWorkout:
            StepContent(
                title: "You're Ready",
                description: "That's it! Tap Start Workout whenever you're ready, and log each set as you go.",
                tooltipEdge: .bottom
            )
        }
    }
}
