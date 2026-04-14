import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Query private var users: [User]
    @Query(sort: \WorkoutPlan.date, order: .reverse) private var workoutPlans: [WorkoutPlan]

    private var user: User? { users.first }
    private var notificationService: NotificationService { NotificationService.shared }

    var body: some View {
        List {
            // Permission status section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    switch notificationService.authorizationStatus {
                    case .authorized:
                        Text("Enabled")
                            .foregroundStyle(Color.groveSage)
                    case .denied:
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    case .notDetermined:
                        Button("Enable") {
                            Task {
                                _ = await notificationService.requestAuthorization()
                                reschedule()
                            }
                        }
                    default:
                        Text("Not Available")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Notification Permission")
            } footer: {
                if notificationService.authorizationStatus == .denied {
                    Text("Notifications are disabled. Open Settings to enable them.")
                }
            }

            Section {
                if let user = user {
                    DatePicker("Morning", selection: Binding(
                        get: { morningDate(for: user) },
                        set: { newDate in
                            let cal = Calendar.current
                            user.preferredReminderHour = cal.component(.hour, from: newDate)
                            user.preferredReminderMinute = cal.component(.minute, from: newDate)
                            user.preferredCreatineReminderHour = cal.component(.hour, from: newDate)
                            user.preferredCreatineReminderMinute = cal.component(.minute, from: newDate)
                            reschedule()
                        }
                    ), displayedComponents: .hourAndMinute)

                    DatePicker("Evening", selection: Binding(
                        get: { eveningDate(for: user) },
                        set: { newDate in
                            let cal = Calendar.current
                            user.preferredEveningReminderHour = cal.component(.hour, from: newDate)
                            user.preferredEveningReminderMinute = cal.component(.minute, from: newDate)
                            reschedule()
                        }
                    ), displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminder Times")
            } footer: {
                Text("Morning: workout reminders\(user?.trackCreatine == true ? ", creatine" : ""), weekly planning follow-ups. Evening: social nudges, weekly planning.")
            }

            Section {
                if let user = user {
                    Toggle("Workout Reminders", isOn: Binding(
                        get: { user.notifyWorkoutReminder },
                        set: {
                            user.notifyWorkoutReminder = $0
                            reschedule()
                        }
                    ))
                    Toggle("Streak at Risk", isOn: Binding(
                        get: { user.notifyStreakAtRisk },
                        set: { user.notifyStreakAtRisk = $0 }
                    ))
                    Toggle("Personal Records", isOn: Binding(
                        get: { user.notifyPersonalRecord },
                        set: { user.notifyPersonalRecord = $0 }
                    ))
                    Toggle("Friend Activity", isOn: Binding(
                        get: { user.notifyFriendActivity },
                        set: { user.notifyFriendActivity = $0 }
                    ))
                    Toggle("Weekly Summary", isOn: Binding(
                        get: { user.notifyWeeklySummary },
                        set: {
                            user.notifyWeeklySummary = $0
                            reschedule()
                        }
                    ))

                    if user.trackCreatine {
                        Toggle("Creatine Reminder", isOn: Binding(
                            get: { user.notifyCreatineReminder },
                            set: {
                                user.notifyCreatineReminder = $0
                                reschedule()
                            }
                        ))
                    }
                }
            } header: {
                Text("Notification Types")
            }

            Section {
                if let user = user {
                    Toggle("Watering Reminders", isOn: Binding(
                        get: { user.notifyWateringReminder },
                        set: { user.notifyWateringReminder = $0 }
                    ))
                    Toggle("Seed Received", isOn: Binding(
                        get: { user.notifySeedReceived },
                        set: { user.notifySeedReceived = $0 }
                    ))
                    Toggle("Water Received", isOn: Binding(
                        get: { user.notifyWaterReceived },
                        set: { user.notifyWaterReceived = $0 }
                    ))
                    Toggle("Sunlight Received", isOn: Binding(
                        get: { user.notifySunlightReceived },
                        set: { user.notifySunlightReceived = $0 }
                    ))
                    Toggle("Connection Milestones", isOn: Binding(
                        get: { user.notifyConnectionMilestone },
                        set: { user.notifyConnectionMilestone = $0 }
                    ))
                }
            } header: {
                Text("Social")
            } footer: {
                Text("Watering Reminders notify you when friends share workouts. Seed, Water, and Sunlight Received alert you when someone interacts with your post. Connection Milestones celebrate when your roots grow deeper.")
            }

            Section("Quiet Hours") {
                if let user = user {
                    Toggle("Enable Quiet Hours", isOn: Binding(
                        get: { user.quietHoursStart != nil },
                        set: { enabled in
                            if enabled {
                                var start = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                start.hour = 22
                                start.minute = 0
                                user.quietHoursStart = Calendar.current.date(from: start)

                                var end = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                end.hour = 7
                                end.minute = 0
                                user.quietHoursEnd = Calendar.current.date(from: end)
                            } else {
                                user.quietHoursStart = nil
                                user.quietHoursEnd = nil
                            }
                            reschedule()
                        }
                    ))

                    if user.quietHoursStart != nil {
                        DatePicker("From", selection: Binding(
                            get: { user.quietHoursStart ?? Date() },
                            set: {
                                user.quietHoursStart = $0
                                reschedule()
                            }
                        ), displayedComponents: .hourAndMinute)

                        DatePicker("To", selection: Binding(
                            get: { user.quietHoursEnd ?? Date() },
                            set: {
                                user.quietHoursEnd = $0
                                reschedule()
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationService.checkAuthorizationStatus()
        }
    }

    private func morningDate(for user: User) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = user.preferredReminderHour
        components.minute = user.preferredReminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func eveningDate(for user: User) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = user.preferredEveningReminderHour
        components.minute = user.preferredEveningReminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func reschedule() {
        guard let user = user else { return }
        notificationService.rescheduleAll(plans: workoutPlans, user: user)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
