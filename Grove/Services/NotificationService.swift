import Foundation
import UserNotifications

@MainActor @Observable
class NotificationService {
    static let shared = NotificationService()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Notification Identifiers

    private static let dailyWorkoutID = "grove.daily.workout"
    private static let weeklyPlanSundayID = "grove.weekly.plan.sunday"
    private static let weeklyPlanMondayID = "grove.weekly.plan.monday"
    private static let abandonedWorkoutID = "grove.abandoned.workout"
    private static let creatineReminderID = "grove.creatine.reminder"
    private static let wateringReminderID = "grove.social.watering"
    private static let seedReceivedID = "grove.social.seed"
    private static let connectionMilestoneID = "grove.social.milestone"

    private init() {}

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

    // MARK: - Daily Workout Reminder (8 AM)

    func scheduleDailyWorkoutReminder(plans: [WorkoutPlan], user: User) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyWorkoutID])

        guard authorizationStatus == .authorized,
              user.notifyWorkoutReminder else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find today's actionable plan
        guard let todaysPlan = plans.first(where: {
            calendar.isDate($0.date, inSameDayAs: today)
            && !$0.isRestDay
            && $0.completedWorkout == nil
            && $0.template != nil
        }) else { return }

        let templateName = todaysPlan.template?.name ?? "Workout"

        // Check if preferred time today is in quiet hours
        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: today)
        triggerComponents.hour = user.preferredReminderHour
        triggerComponents.minute = user.preferredReminderMinute
        guard let triggerDate = calendar.date(from: triggerComponents) else { return }

        if isInQuietHours(triggerDate, user: user) { return }

        // If preferred time already passed today, skip
        if triggerDate < Date() { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        content.body = "Today's workout: \(templateName). Let's grow!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: user.preferredReminderHour, minute: user.preferredReminderMinute),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Self.dailyWorkoutID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Weekly Planning Nudge (Sunday 6 PM + Monday 8 AM)

    func scheduleWeeklyPlanningNudge(plans: [WorkoutPlan], user: User) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.weeklyPlanSundayID,
            Self.weeklyPlanMondayID
        ])

        guard authorizationStatus == .authorized,
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

        guard authorizationStatus == .authorized else { return }

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

    // MARK: - Creatine Reminder (9 AM)

    func scheduleCreatineReminder(hasLoggedToday: Bool, user: User) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.creatineReminderID])

        guard authorizationStatus == .authorized,
              user.trackCreatine,
              user.notifyCreatineReminder,
              !hasLoggedToday else { return }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = user.preferredCreatineReminderHour
        components.minute = user.preferredCreatineReminderMinute

        guard let triggerDate = calendar.date(from: components),
              triggerDate > Date(),
              !isInQuietHours(triggerDate, user: user) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        content.body = "Don't forget your creatine today!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: user.preferredCreatineReminderHour, minute: user.preferredCreatineReminderMinute),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Self.creatineReminderID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Watering Reminder (7 PM)

    func scheduleWateringReminder(hasUnwateredPosts: Bool, user: User) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.wateringReminderID])

        guard authorizationStatus == .authorized,
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

    // MARK: - Seed Received Notification

    func scheduleSeedReceivedNotification(senderName: String, message: String, user: User) {
        let center = UNUserNotificationCenter.current()

        guard authorizationStatus == .authorized,
              user.notifySeedReceived else { return }

        if isInQuietHours(Date(), user: user) { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        content.body = "\(senderName) planted a seed: \"\(message)\""
        content.sound = .default

        // Fire immediately (1 second delay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let id = "\(Self.seedReceivedID).\(UUID().uuidString.prefix(8))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Connection Milestone Notification

    func scheduleConnectionMilestone(friendName: String, level: RootLevel, user: User) {
        let center = UNUserNotificationCenter.current()

        guard authorizationStatus == .authorized,
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

    // MARK: - Friend Activity Notification

    private static let friendActivityID = "grove.social.friendActivity"

    func scheduleFriendActivityNotification(friendName: String, workoutName: String, duration: TimeInterval, user: User) {
        let center = UNUserNotificationCenter.current()

        guard authorizationStatus == .authorized,
              user.notifyFriendActivity else { return }

        if isInQuietHours(Date(), user: user) { return }

        let content = UNMutableNotificationContent()
        content.title = "Grove"
        let minutes = Int(duration / 60)
        if minutes > 0 {
            content.body = "\(friendName) just crushed \(workoutName) — \(minutes) min"
        } else {
            content.body = "\(friendName) just crushed \(workoutName)"
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let id = "\(Self.friendActivityID).\(UUID().uuidString.prefix(8))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Reschedule All (called from settings toggle changes)

    func rescheduleAll(plans: [WorkoutPlan], user: User, hasLoggedCreatineToday: Bool = false) {
        scheduleDailyWorkoutReminder(plans: plans, user: user)
        scheduleWeeklyPlanningNudge(plans: plans, user: user)
        scheduleCreatineReminder(hasLoggedToday: hasLoggedCreatineToday, user: user)
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
