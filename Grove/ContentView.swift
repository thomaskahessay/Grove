import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(CloudKitSocialService.self) private var socialService
    @Query private var users: [User]
    @Query(sort: \WorkoutPlan.date, order: .reverse) private var workoutPlans: [WorkoutPlan]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var showingWorkoutCreation = false
    @State private var showingDayPlanSheet = false
    @State private var showNotificationPrompt = false
    @State private var selectedTab: Int = 0
    @State private var isLaunching = true
    @State private var minimumTimeElapsed = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"
    @AppStorage("notificationPromptShown") private var notificationPromptShown = false
    @State private var coachMarkManager = CoachMarkManager()

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    /// Today's plan that has an unstarted workout template (not rest, not completed).
    private var todaysActionablePlan: WorkoutPlan? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return workoutPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: today)
            && !plan.isRestDay
            && plan.completedWorkout == nil
            && plan.template != nil
        }
    }

    private var isOnboardingComplete: Bool {
        guard let user = users.first else { return false }
        return user.onboardingCompletedAt != nil
    }

    var body: some View {
        if isOnboardingComplete {
            ZStack {
                mainAppView
                    .preferredColorScheme(colorScheme)
                    .opacity(isLaunching ? 0 : 1)
                    .environment(coachMarkManager)

                CoachMarkOverlay()
                    .environment(coachMarkManager)
                    .zIndex(0.5)

                if isLaunching {
                    LaunchView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                sessionManager.user = users.first
                sessionManager.resumeIncompleteWorkout(context: modelContext)
                HealthKitManager.shared.checkAuthorizationStatus()
                sessionManager.onWorkoutCompleted = { workout in
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    if let todaysPlan = workoutPlans.first(where: { calendar.isDate($0.date, inSameDayAs: today) && !$0.isRestDay }) {
                        todaysPlan.completedWorkout = workout
                    }
                }

                // Dismiss splash after a minimum time. Deliberately does not wait on the
                // network preload below — CloudKit calls can hang indefinitely with no
                // network path at all, and that must never block getting into the app.
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    minimumTimeElapsed = true
                    dismissLaunchIfReady()
                }

                // Preload social feed in the background, independent of the splash timer.
                Task {
                    guard let user = users.first else { return }
                    await socialService.refreshAll(user: user)

                    // Schedule watering reminder if there are un-watered posts today
                    let hasUnwatered = socialService.feedItems.contains { item in
                        let interactions = socialService.interactionsByWorkout[item.id]
                        return interactions?.iWatered != true
                            && Calendar.current.isDateInToday(item.completedAt)
                    }
                    NotificationService.shared.scheduleWateringReminder(hasUnwateredPosts: hasUnwatered, user: user)

                    // Check for connection milestones
                    let milestones = socialService.checkForConnectionMilestones()
                    for (friendName, level) in milestones {
                        NotificationService.shared.scheduleConnectionMilestone(friendName: friendName, level: level, user: user)
                    }
                }

                // Schedule notifications on each app launch (local-only, not network-dependent)
                let notificationService = NotificationService.shared
                await notificationService.checkAuthorizationStatus()
                if let user = users.first {
                    notificationService.scheduleDailyWorkoutReminder(plans: workoutPlans, user: user)
                    notificationService.scheduleWeeklyPlanningNudge(plans: workoutPlans, user: user)

                    // Prompt existing users who haven't been asked yet
                    if !notificationPromptShown && !coachMarkManager.isActive && notificationService.authorizationStatus == .notDetermined {
                        showNotificationPrompt = true
                    }
                }
            }
            .onChange(of: users.first?.appleUserID) {
                sessionManager.user = users.first
            }
        } else {
            OnboardingContainerView()
        }
    }

    private func dismissLaunchIfReady() {
        guard minimumTimeElapsed, isLaunching else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            isLaunching = false
        }
        // Start guided tour after launch animation completes
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            coachMarkManager.startTourIfNeeded()
        }
    }

    @ViewBuilder
    private var mainAppView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    HomeView()
                }

                Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 1) {
                    ProgressView()
                }

                Tab("Social", systemImage: "person.2.fill", value: 2) {
                    SocialFeedView()
                }

                Tab("Profile", systemImage: "person.fill", value: 3) {
                    ProfileView()
                }
            }
            .tint(.groveSage)
            .background {
                TabBarFrameReader { tabBarFrame in
                    let tabWidth = tabBarFrame.width / 4
                    coachMarkManager.registerFrame(.progressTab, frame: CGRect(
                        x: tabWidth, y: tabBarFrame.minY,
                        width: tabWidth, height: tabBarFrame.height
                    ))
                    coachMarkManager.registerFrame(.socialTab, frame: CGRect(
                        x: tabWidth * 2, y: tabBarFrame.minY,
                        width: tabWidth, height: tabBarFrame.height
                    ))
                }
            }

            // Floating Action Button (Home tab only, hidden when workout is active)
            if !sessionManager.hasActiveWorkout && selectedTab == 0 {
                HStack {
                    Spacer()
                    Menu {
                        if let plan = todaysActionablePlan, let template = plan.template {
                            Button {
                                WorkoutSessionManager.createAndStartWorkout(
                                    from: template,
                                    allExercises: allExercises,
                                    context: modelContext,
                                    sessionManager: sessionManager
                                )
                            } label: {
                                Label("Start \(template.name)", systemImage: "play.fill")
                            }
                        }

                        Button {
                            showingDayPlanSheet = true
                        } label: {
                            Label("Add to Plan", systemImage: "calendar.badge.plus")
                        }

                        Button {
                            showingWorkoutCreation = true
                        } label: {
                            Label("New Workout", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveSage)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.groveSage.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            .coachMarkAnchor(.fab)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 90) // Above tab bar
                }
            }

            // Minimized workout card
            if sessionManager.isMinimized {
                MinimizedWorkoutCardView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingWorkoutCreation) {
            WorkoutCreationView()
        }
        .sheet(isPresented: $showingDayPlanSheet) {
            DayPlanSheet(
                date: Calendar.current.startOfDay(for: Date()),
                existingPlan: todaysActionablePlan
            )
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { sessionManager.isFullScreenPresented },
                set: { sessionManager.isFullScreenPresented = $0 }
            )
        ) {
            if let workout = sessionManager.activeWorkout {
                ActiveWorkoutView(workout: workout)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { sessionManager.showingSummary },
                set: { sessionManager.showingSummary = $0 }
            )
        ) {
            if let workout = sessionManager.completedWorkout {
                WorkoutSummaryView(workout: workout)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { sessionManager.showingHealthKitConnect },
                set: { sessionManager.showingHealthKitConnect = $0 }
            )
        ) {
            if let workout = sessionManager.pendingHealthKitWorkout {
                HealthKitConnectView(
                    workout: workout,
                    onConnect: { _ in
                        sessionManager.finishHealthKitConnect()
                    },
                    onSkip: {
                        sessionManager.finishHealthKitConnect()
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(
            isPresented: Binding(
                get: { sessionManager.showingStreakMoment },
                set: { sessionManager.showingStreakMoment = $0 }
            )
        ) {
            if let data = sessionManager.streakMomentData {
                StreakMomentView(data: data) {
                    sessionManager.dismissStreakMoment()
                }
            }
        }
        .alert("Enable Notifications?", isPresented: $showNotificationPrompt) {
            Button("Enable") {
                notificationPromptShown = true
                Task {
                    let granted = await NotificationService.shared.requestAuthorization()
                    if granted, let user = users.first {
                        NotificationService.shared.scheduleDailyWorkoutReminder(plans: workoutPlans, user: user)
                        NotificationService.shared.scheduleWeeklyPlanningNudge(plans: workoutPlans, user: user)
                    }
                }
            }
            Button("Not Now", role: .cancel) {
                notificationPromptShown = true
            }
        } message: {
            Text("Get reminders for your planned workouts and weekly check-ins.")
        }
        .onPreferenceChange(CoachMarkAnchorsKey.self) { anchors in
            for (step, frame) in anchors where frame.width > 0 && frame.height > 0 {
                coachMarkManager.registerFrame(step, frame: frame)
            }
        }
        .onChange(of: coachMarkManager.currentStep) { _, newStep in
            switch newStep {
            case .progressTab:
                withAnimation { selectedTab = 1 }
            case .socialTab:
                withAnimation { selectedTab = 2 }
            default:
                if selectedTab != 0 {
                    withAnimation { selectedTab = 0 }
                }
            }
        }
    }
}

// MARK: - Tab Bar Frame Reader

private struct TabBarFrameReader: UIViewRepresentable {
    let onFrame: (CGRect) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = uiView.window else { return }
            guard let tabBar = Self.findTabBar(in: window) else { return }
            let frame = tabBar.convert(tabBar.bounds, to: nil)
            guard frame.width > 0 && frame.height > 0 else { return }
            MainActor.assumeIsolated {
                onFrame(frame)
            }
        }
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar { return tabBar }
        for subview in view.subviews {
            if let found = findTabBar(in: subview) { return found }
        }
        return nil
    }
}

#Preview {
    ContentView()
        .environment(WorkoutSessionManager())
        .environment(CloudKitSocialService())
        .modelContainer(.preview)
}
