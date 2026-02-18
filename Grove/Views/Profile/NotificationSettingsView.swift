import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Query private var users: [User]

    private var user: User? { users.first }

    var body: some View {
        List {
            Section {
                if let user = user {
                    Toggle("Workout Reminders", isOn: Binding(
                        get: { user.notifyWorkoutReminder },
                        set: { user.notifyWorkoutReminder = $0 }
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
                        set: { user.notifyWeeklySummary = $0 }
                    ))
                }
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Preferences will apply when notifications are enabled.")
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
                        }
                    ))

                    if user.quietHoursStart != nil {
                        DatePicker("From", selection: Binding(
                            get: { user.quietHoursStart ?? Date() },
                            set: { user.quietHoursStart = $0 }
                        ), displayedComponents: .hourAndMinute)

                        DatePicker("To", selection: Binding(
                            get: { user.quietHoursEnd ?? Date() },
                            set: { user.quietHoursEnd = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
