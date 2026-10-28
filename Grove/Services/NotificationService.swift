import Foundation
import UserNotifications

@MainActor @Observable
class NotificationService: NSObject {
    static let shared = NotificationService()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Notification Identifiers

    private static let dailyWorkoutID = "grove.daily.workout"
    private static let weeklyPlanSundayID = "grove.weekly.plan.sunday"
    private static let weeklyPlanMondayID = "grove.weekly.plan.monday"
    private static let abandonedWorkoutID = "grove.abandoned.workout"
    private static let creatineReminderID = "grove.creatine.reminder"
    private static let wateringReminderID = "grove.social.watering"
    private static let connectionMilestoneID = "grove.social.milestone"
    nonisolated private static let restTimerID = "grove.workout.restTimer"

    private override init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Provisional and ephemeral authorization can also deliver notifications.
    private var canDeliver: Bool {
        [.authorized, .provisional, .ephemeral].contains(authorizationStatus)
    }

    // MARK: - Refresh Scheduled Reminders

    /// How many days ahead workout and creatine reminders are scheduled. Covering a week
    /// means reminders keep firing even if the app isn't opened every day.
    private static let reminderHorizonDays = 7

    /// Single entry point for (re)scheduling the plan-driven reminders. Always refreshes
    /// the authorization status first, so a stale `.notDetermined` can't make a scheduler
    /// bail out after it has already removed the pending requests.
    func refreshReminders(plans: [WorkoutPlan], user: User, hasLoggedCreatineToday: Bool) async {
        await checkAuthorizationStatus()
        await scheduleWorkoutReminders(plans: plans, user: user)
        scheduleWeeklyPlanningNudge(plans: plans, user: user)
        await scheduleCreatineReminders(hasLoggedToday: hasLoggedCreatineToday, user: user)
    }

    /// Removes every pending request whose identifier starts with `prefix` (covers both
    /// the per-day identifiers and the legacy single-identifier requests).
    private func removePendingRequests(withPrefix prefix: String) async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Upcoming reminder times at `hour:minute` for today and the next days, skipping
    /// times already passed or inside quiet hours. `dayOffset` 0 is today.
    private func upcomingReminderDates(hour: Int, minute: Int, user: User) -> [(dayOffset: Int, date: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        return (0..<Self.reminderHorizonDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  date > now,
                  !isInQuietHours(date, user: user) else { return nil }
            return (offset, date)
        }
    }

    private func dayIdentifier(_ prefix: String, for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(prefix).\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
    }

    // MARK: - Daily Workout Reminders

    private func scheduleWorkoutReminders(plans: [WorkoutPlan], user: User) async {
        await removePendingRequests(withPrefix: Self.dailyWorkoutID)

        guard canDeliver, user.notifyWorkoutReminder else { return }

        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()

        for (_, date) in upcomingReminderDates(hour: user.preferredReminderHour, minute: user.preferredReminderMinute, user: user) {
            guard let plan = plans.first(where: {
                calendar.isDate($0.date, inSameDayAs: date)
                && !$0.isRestDay
                && $0.completedWorkout == nil
                && $0.template != nil
            }) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Grove"
            content.body = "Today's workout: \(plan.template?.name ?? "Workout"). Let's grow!"
            content.sound = .default

            try? await center.add(UNNotificationRequest(
                identifier: dayIdentifier(Self.dailyWorkoutID, for: date),
                content: content,
                trigger: calendarTrigger(for: date)
            ))
        }
    }

    // MARK: - Weekly Planning Nudge (Sunday 6 PM + Monday 8 AM)

    private func scheduleWeeklyPlanningNudge(plans: [WorkoutPlan], user: User) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.weeklyPlanSundayID,
            Self.weeklyPlanMondayID
        ])

        guard canDeliver,
              user.notifyWeeklySummary else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Compute next Monday (start of upcoming week)
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = weekday == 2 ? 7 : ((9 - weekday) % 7)
        guard let nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday, to: today),
              let nextSunday = calendar.date(byAdding: .day, value: 6, to: nextMonday) else { return }

        // Check if user has any workout plans for next week
        let hasPlansNextWeek = plans.contains { plan in
            let planDate = calendar.startOfDay(for: plan.date)
            return planDate >= nextMonday && planDate <= nextSunday
                && !plan.isRestDay
                && plan.template != nil
        }

        if hasPlansNextWeek { return }

        // Schedule Sunday evening nudge
        let sundayComponents = DateComponents(hour: user.preferredEveningReminderHour, minute: user.preferredEveningReminderMinute, weekday: 1) // Sunday = 1
        if let sundayDate = calendar.nextDate(after: Date(), matching: sundayComponents, matchingPolicy: .nextTime) {
            if !isInQuietHours(sundayDate, user: user) {
                let content = UNMutableNotificationContent()
                content.title = "Grove"
                content.body = "Plan your week ahead \u{2014} tap to set up your workouts!"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: sundayComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: Self.weeklyPlanSundayID,
                    content: content,
                    trigger: trigger
                )

                center.add(request)
            }
        }

        // Schedule Monday morning follow-up
        let mondayComponents = DateComponents(hour: user.preferredReminderHour, minute: user.preferredReminderMinute, weekday: 2) // Monday = 2
        if let mondayDate = calendar.nextDate(after: Date(), matching: mondayComponents, matchingPolicy: .nextTime) {
            if !isInQuietHours(mondayDate, user: user) {
                let content = UNMutableNotificationContent()
                content.title = "Grove"
                content.body = "You haven't planned your week yet. A few minutes now saves guesswork later!"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: mondayComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: Self.weeklyPlanMondayID,
                    content: content,
                    trigger: trigger
                )

                center.add(request)
            }
        }
    }

    // MARK: - Abandoned Workout Reminder (15 min)

    func scheduleAbandonedWorkoutReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.abandonedWorkoutID])

        guard canDeliver else { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        content.body = "You have a workout in progress \u{2014} continue or finish up?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 900, // 15 minutes
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Self.abandonedWorkoutID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelAbandonedWorkoutReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.abandonedWorkoutID])
    }

    // MARK: - Rest Timer

    /// Alerts the user when rest ends while Grove is in the background. Ignores quiet
    /// hours since the user is mid-workout. Suppressed in the foreground (see delegate),
    /// where WorkoutSessionManager plays a haptic instead.
    func scheduleRestTimerNotification(at date: Date, exerciseName: String?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.restTimerID])

        let interval = date.timeIntervalSinceNow
        guard canDeliver, interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = exerciseName.map { "Time for your next set of \($0)." } ?? "Time for your next set."
        content.sound = .default
        content.interruptionLevel = .active

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.restTimerID, content: content, trigger: trigger))
    }

    func cancelRestTimerNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.restTimerID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.restTimerID])
    }

    // MARK: - Creatine Reminders

    private func scheduleCreatineReminders(hasLoggedToday: Bool, user: User) async {
        await removePendingRequests(withPrefix: Self.creatineReminderID)

        guard canDeliver,
              user.trackCreatine,
              user.notifyCreatineReminder else { return }

        let center = UNUserNotificationCenter.current()

        for (offset, date) in upcomingReminderDates(hour: user.preferredCreatineReminderHour, minute: user.preferredCreatineReminderMinute, user: user) {
            if offset == 0 && hasLoggedToday { continue }

            let content = UNMutableNotificationContent()
            content.title = "Grove"
            content.body = "Don't forget your creatine today!"
            content.sound = .default

            try? await center.add(UNNotificationRequest(
                identifier: dayIdentifier(Self.creatineReminderID, for: date),
                content: content,
                trigger: calendarTrigger(for: date)
            ))
        }
    }

    // MARK: - Watering Reminder (7 PM)

    func scheduleWateringReminder(hasUnwateredPosts: Bool, user: User) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.wateringReminderID])

        guard canDeliver,
              user.notifyWateringReminder,
              hasUnwateredPosts else { return }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = user.preferredEveningReminderHour
        components.minute = user.preferredEveningReminderMinute

        guard let triggerDate = calendar.date(from: components),
              triggerDate > Date(),
              !isInQuietHours(triggerDate, user: user) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        content.body = "Your friends shared workouts today — water their plants!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: user.preferredEveningReminderHour, minute: user.preferredEveningReminderMinute),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Self.wateringReminderID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Connection Milestone Notification

    func scheduleConnectionMilestone(friendName: String, level: RootLevel, user: User) {
        let center = UNUserNotificationCenter.current()

        guard canDeliver,
              user.notifyConnectionMilestone else { return }

        if isInQuietHours(Date(), user: user) { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        content.body = "Your roots with \(friendName) are now \(level.rawValue)!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let id = "\(Self.connectionMilestoneID).\(UUID().uuidString.prefix(8))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Quiet Hours

    private func isInQuietHours(_ date: Date, user: User) -> Bool {
        guard let start = user.quietHoursStart,
              let end = user.quietHoursEnd else { return false }

        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)

        let checkHour = calendar.component(.hour, from: date)
        let checkMinute = calendar.component(.minute, from: date)

        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        let checkMinutes = checkHour * 60 + checkMinute

        if startMinutes <= endMinutes {
            // Same-day range (e.g. 09:00 - 17:00)
            return checkMinutes >= startMinutes && checkMinutes < endMinutes
        } else {
            // Overnight range (e.g. 22:00 - 07:00)
            return checkMinutes >= startMinutes || checkMinutes < endMinutes
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Without a delegate, iOS silently drops notifications delivered while the app
    /// is in the foreground. This is what makes foreground-fired notifications visible.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // The in-app timer handles rest completion while Grove is open.
        if notification.request.identifier == Self.restTimerID {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }
}
