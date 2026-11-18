import SwiftUI
import SwiftData
import UIKit
import Combine
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(CloudKitSocialService.self) private var socialService
    @Environment(\.scenePhase) private var scenePhase
    @Query private var users: [User]
    @Query(sort: \WorkoutPlan.date, order: .reverse) private var workoutPlans: [WorkoutPlan]
    @Query private var creatineLogs: [CreatineLog]
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

    private var hasLoggedCreatineToday: Bool {
        creatineLogs.contains { Calendar.current.isDateInToday($0.date) }
    }

    /// Everything the scheduled reminders depend on. Reminders are rescheduled whenever
    /// this changes — plan edits, workout completion, creatine logging, settings,
    /// permission changes, a new day, or the app returning to the foreground.
    private var reminderScheduleKey: String {
        guard let user = users.first else { return "" }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let upcomingPlans = workoutPlans
            .filter { $0.date >= today }
            .map { plan in
                "\(plan.date.timeIntervalSince1970)|\(plan.isRestDay)|\(plan.template?.name ?? "")|\(plan.completedWorkout != nil)"
            }
            .joined(separator: ",")
        let quietHours = [user.quietHoursStart, user.quietHoursEnd]
            .map { $0.map { "\(calendar.component(.hour, from: $0)):\(calendar.component(.minute, from: $0))" } ?? "-" }
            .joined(separator: "-")
        return [
            "\(scenePhase == .active)",
            "\(today.timeIntervalSince1970)",
            "\(NotificationService.shared.authorizationStatus.rawValue)",
            "\(user.notifyWorkoutReminder)|\(user.notifyWeeklySummary)|\(user.trackCreatine)|\(user.notifyCreatineReminder)",
            "\(user.preferredReminderHour):\(user.preferredReminderMinute)",
            "\(user.preferredEveningReminderHour):\(user.preferredEveningReminderMinute)",
            "\(user.preferredCreatineReminderHour):\(user.preferredCreatineReminderMinute)",
            quietHours,
            "\(hasLoggedCreatineToday)",
            upcomingPlans
        ].joined(separator: "#")
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
                    // Before the profile sync, so friends get today's streak, not yesterday's.
                    refreshStreak(syncToFriends: false)
                    await socialService.refreshAll(user: user)

                    // Schedule watering reminder if there are un-watered posts today
                    let hasUnwatered = socialService.feedItems.contains { item in
                        let interactions = socialService.interactionsByWorkout[item.id]
                        return interactions?.iWatered != true
                            && Calendar.current.isDateInToday(item.completedAt)
                    }
                    NotificationService.shared.scheduleWateringReminder(hasUnwateredPosts: hasUnwatered, user: user)

                    // Check for connection milestones (persisted diff — safe to also run
                    // from the push handler without double-notifying, see checkAndNotifyMilestones)
                    await socialService.checkAndNotifyMilestones(user: user, context: modelContext)
                }

                // Prompt existing users who haven't been asked yet
                let notificationService = NotificationService.shared
                await notificationService.checkAuthorizationStatus()
                // Not while the first-run tour is pending or showing: it starts a few seconds
                // after launch, so `isActive` alone is still false at this point.
                if users.first != nil, !notificationPromptShown,
                   CoachMarkManager.hasSeenTour, !coachMarkManager.isActive,
                   notificationService.authorizationStatus == .notDetermined {
                    showNotificationPrompt = true
                }
            }
            .task(id: reminderScheduleKey) {
                guard scenePhase == .active, let user = users.first else { return }
                await NotificationService.shared.refreshReminders(
                    plans: workoutPlans,
                    user: user,
                    hasLoggedCreatineToday: hasLoggedCreatineToday
                )
            }
            .onChange(of: users.first?.appleUserID) {
                sessionManager.user = users.first
            }
            // A streak can break overnight while the app sits in memory, so check it
            // whenever the app comes back and when the day rolls over while it's open.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshStreak() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
                refreshStreak()
            }
        } else {
            OnboardingContainerView()
        }
    }

    /// Recalculates the streak (wilting the plant if it broke) and, when it changed,
    /// saves, refreshes the widget and tells friends. HomeView also does this on appear.
    private func refreshStreak(syncToFriends: Bool = true) {
        guard let user = users.first else { return }
        // Right after a workout the streak was just set by endWorkout(); the relationship
        // may not include the new workout yet, which would briefly reset it.
        guard sessionManager.completedWorkout == nil,
              !sessionManager.showingSummary,
              !sessionManager.showingStreakMoment else { return }

        let before = (user.currentStreak, user.isStreakWilted)
        // Same set HomeView uses: every completed workout.
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.completedAt != nil })
        // A failed fetch must not read as "no workouts", which would wilt the plant.
        guard let workouts = try? modelContext.fetch(descriptor) else { return }
        StreakManager.recalculateStreak(for: user, workouts: workouts, plans: workoutPlans)
        guard (user.currentStreak, user.isStreakWilted) != before else { return }

        do {
            try modelContext.save()
        } catch {
            print("[Grove] ERROR: Failed to save streak refresh: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        if syncToFriends {
            Task { await socialService.updateMyStats(user: user) }
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

    /// Friends' posts since you last looked at the Grove tab (none while you're on it).
    private var newGrovePosts: Int {
        guard selectedTab != 2 else { return 0 }
        let since = users.first?.lastFeedCheckDate ?? .distantPast
        let me = socialService.currentUserID
        return socialService.feedItems.filter { $0.userID != me && $0.completedAt > since }.count
    }

    @ViewBuilder
    private var mainAppView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Today", systemImage: "sun.horizon.fill", value: 0) {
                    HomeView()
                }

                Tab("Progress", systemImage: "chart.bar.fill", value: 1) {
                    ProgressView()
                }

                Tab("Grove", systemImage: "tree.fill", value: 2) {
                    SocialFeedView()
                }
                .badge(newGrovePosts)

                Tab(value: 3) {
                    ProfileView()
                } label: {
                    Label {
                        Text("You")
                    } icon: {
                        if let avatar = TabAvatar.image(for: users.first?.profileImageData) {
                            Image(uiImage: avatar)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                        }
                    }
                }
            }
            .tint(.groveSage)
            // Kept expanded during the tour: its spotlights point at the tab buttons.
            .tabBarMinimizeBehavior(coachMarkManager.isActive ? .never : .onScrollDown)
            .modifier(WorkoutAccessoryModifier(isActive: sessionManager.isMinimized))
            .background {
                TabBarFrameReader(titles: ["Progress", "Grove"]) { frames in
                    if let frame = frames["Progress"] {
                        coachMarkManager.registerFrame(.progressTab, frame: frame)
                    }
                    if let frame = frames["Grove"] {
                        coachMarkManager.registerFrame(.socialTab, frame: frame)
                    }
                }
            }

            // Minimized workout card (before iOS 26.1, which has the tab bar accessory)
            if sessionManager.isMinimized && !WorkoutAccessoryModifier.isSupported {
                MinimizedWorkoutCardView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
                    // Only its Finish button may close it: that's what posts the workout,
                    // queues the streak moment and clears the just-finished state.
                    .interactiveDismissDisabled()
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
            ),
            // Swiping it away does the same cleanup as its button (safe to run twice).
            onDismiss: { sessionManager.dismissStreakMoment() }
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
                // Granting updates authorizationStatus, which reschedules via reminderScheduleKey.
                Task {
                    _ = await NotificationService.shared.requestAuthorization()
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
        .onChange(of: coachMarkManager.isActive) { _, active in
            // A replay from Settings starts from the Profile tab.
            if active, selectedTab != 0 {
                withAnimation { selectedTab = 0 }
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

// MARK: - Tab bar extras

/// Shows the minimized workout in the tab bar's bottom accessory where available.
private struct WorkoutAccessoryModifier: ViewModifier {
    let isActive: Bool

    static var isSupported: Bool {
        if #available(iOS 26.1, *) { return true }
        return false
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isActive) {
                WorkoutAccessoryView()
            }
        } else {
            content
        }
    }
}

/// Your profile photo as a small round tab icon, drawn in its own colours (tab icons
/// are otherwise tinted as templates). Cached so it isn't redrawn on every update.
@MainActor
private enum TabAvatar {
    private static var cache: (key: Int, image: UIImage)?

    static func image(for data: Data?) -> UIImage? {
        guard let data else { return nil }
        let key = data.hashValue
        if let cache, cache.key == key { return cache.image }
        guard let source = UIImage(data: data) else { return nil }
        let side: CGFloat = 26
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            UIBezierPath(ovalIn: rect).addClip()
            let scale = max(side / source.size.width, side / source.size.height)
            let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                                   width: size.width, height: size.height))
        }.withRenderingMode(.alwaysOriginal)
        cache = (key, image)
        return image
    }
}

// MARK: - Tab Bar Frame Reader

private struct TabBarFrameReader: UIViewRepresentable {
    /// Tab titles to locate, as shown under the icons.
    let titles: [String]
    let onFrames: ([String: CGRect]) -> Void

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
            let barFrame = tabBar.convert(tabBar.bounds, to: nil)
            guard barFrame.width > 0 && barFrame.height > 0 else { return }

            var frames: [String: CGRect] = [:]
            for (index, title) in titles.enumerated() {
                if let item = Self.findItem(titled: title, in: tabBar, barWidth: barFrame.width) {
                    frames[title] = item.convert(item.bounds, to: nil)
                } else {
                    frames[title] = Self.estimatedFrame(index: index, of: titles, in: barFrame)
                }
            }
            MainActor.assumeIsolated {
                onFrames(frames)
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

    /// The tab's own button view. On iOS 26 the bar floats inset from the screen edges,
    /// so slicing the UITabBar's bounds into equal parts lands the spotlight off target.
    private static func findItem(titled title: String, in view: UIView, barWidth: CGFloat) -> UIView? {
        var best: UIView?
        func visit(_ v: UIView) {
            if !v.isHidden, v.alpha > 0,
               let label = v.accessibilityLabel, label.hasPrefix(title),
               v.bounds.width > 20, v.bounds.width < barWidth * 0.6,
               v.bounds.width > (best?.bounds.width ?? 0) {
                best = v
            }
            v.subviews.forEach(visit)
        }
        visit(view)
        return best
    }

    /// Fallback when no item view is found: the floating bar inset from the UITabBar's bounds.
    /// Assumes the four tabs Grove has; `titles` are looked up in that order.
    private static func estimatedFrame(index: Int, of titles: [String], in barFrame: CGRect) -> CGRect? {
        let allTabs = ["Today", "Progress", "Grove", "You"]
        guard let position = allTabs.firstIndex(of: titles[index]) else { return nil }
        let platter = CGRect(x: barFrame.minX + 21, y: barFrame.minY + 8,
                             width: barFrame.width - 42, height: 62)
        let width = platter.width / CGFloat(allTabs.count)
        return CGRect(x: platter.minX + width * CGFloat(position), y: platter.minY,
                      width: width, height: platter.height)
    }
}

#Preview {
    ContentView()
        .environment(WorkoutSessionManager())
        .environment(CloudKitSocialService())
        .modelContainer(.preview)
}
