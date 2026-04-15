import SwiftUI

@MainActor
@Observable
class CoachMarkManager {
    // MARK: - Tour Definition

    enum TourStep: Int, CaseIterable {
        case todaysWorkout = 0
        case streakPlant = 1
        case planMyWeek = 2
        case fab = 3
        case progressTab = 4
        case socialTab = 5
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
    var currentFrame: CGRect? { anchorFrames[currentStep] }
    var stepIndex: Int { currentStep.rawValue }
    var totalSteps: Int { TourStep.allCases.count }
    var isLastStep: Bool { currentStep == TourStep.allCases.last }

    // MARK: - Actions

    func startTourIfNeeded() {
        guard !Self.hasSeenTour else { return }
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
                title: "Your Daily Workout",
                description: "Today's planned workout shows up here. Tap to start training.",
                tooltipEdge: .bottom
            )
        case .streakPlant:
            StepContent(
                title: "Your Streak Plant",
                description: "Your plant grows as you build your workout streak. Keep it alive!",
                tooltipEdge: .bottom
            )
        case .planMyWeek:
            StepContent(
                title: "Plan Your Week",
                description: "Organize your training schedule and stay on track.",
                tooltipEdge: .top
            )
        case .fab:
            StepContent(
                title: "Quick Actions",
                description: "Tap here to start a workout, add to your plan, or create something new.",
                tooltipEdge: .top
            )
        case .progressTab:
            StepContent(
                title: "Track Your Progress",
                description: "View your personal records, volume trends, and training insights.",
                tooltipEdge: .top
            )
        case .socialTab:
            StepContent(
                title: "Your Grove",
                description: "See your friends' workouts and cheer them on with water, seeds, and sunlight.",
                tooltipEdge: .top
            )
        }
    }
}
