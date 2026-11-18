import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Query private var users: [User]
    @Environment(CloudKitSocialService.self) private var socialService

    @State private var diagnostics: CloudKitSocialService.PushDiagnostics?
    @State private var isCheckingAlerts = false
    @State private var testResult: String?
    @State private var isSendingTest = false

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
                        }
                    ), displayedComponents: .hourAndMinute)

                    DatePicker("Evening", selection: Binding(
                        get: { eveningDate(for: user) },
                        set: { newDate in
                            let cal = Calendar.current
                            user.preferredEveningReminderHour = cal.component(.hour, from: newDate)
                            user.preferredEveningReminderMinute = cal.component(.minute, from: newDate)
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
                        set: {
                            user.notifyFriendActivity = $0
                            socialService.updatePushPreferences(from: user)
                        }
                    ))
                    Toggle("Weekly Summary", isOn: Binding(
                        get: { user.notifyWeeklySummary },
                        set: {
                            user.notifyWeeklySummary = $0
                        }
                    ))

                    if user.trackCreatine {
                        Toggle("Creatine Reminder", isOn: Binding(
                            get: { user.notifyCreatineReminder },
                            set: {
                                user.notifyCreatineReminder = $0
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
                        set: {
                            user.notifySeedReceived = $0
                            socialService.updatePushPreferences(from: user)
                        }
                    ))
                    Toggle("Connection Milestones", isOn: Binding(
                        get: { user.notifyConnectionMilestone },
                        set: { user.notifyConnectionMilestone = $0 }
                    ))
                }
            } header: {
                Text("Social")
            } footer: {
                Text("Watering Reminders send one evening nudge if friends posted today and you haven't watered yet. Instant alerts when a friend finishes come from Friend Activity. Seed Received alerts you when someone plants a seed on your post. Connection Milestones celebrate when your roots grow deeper.")
            }

            friendAlertStatusSection

            Section {
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
                            set: {
                                user.quietHoursStart = $0
                            }
                        ), displayedComponents: .hourAndMinute)

                        DatePicker("To", selection: Binding(
                            get: { user.quietHoursEnd ?? Date() },
                            set: {
                                user.quietHoursEnd = $0
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            } header: {
                Text("Quiet Hours")
            } footer: {
                Text("Friend Activity and Seed Received are delivered instantly by iCloud, so quiet hours don't apply to them. Use a Focus mode to silence them.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationService.checkAuthorizationStatus()
        }
        .task {
            await checkFriendAlerts()
        }
    }

    // MARK: - Friend Alert Status

    private var friendAlertStatusSection: some View {
        Section {
            if let diagnostics {
                LabeledContent("Build", value: diagnostics.isDevelopmentBuild ? "Xcode (Development)" : "TestFlight / App Store")
                LabeledContent("iCloud") {
                    Text(diagnostics.iCloudStatus)
                        .foregroundStyle(diagnostics.iCloudReady ? Color.groveSage : Color.groveMutedRust)
                }
                LabeledContent("Push registration") {
                    Text(diagnostics.isRegisteredForPush ? "Registered" : "Not registered")
                        .foregroundStyle(diagnostics.isRegisteredForPush ? Color.groveSage : Color.groveMutedRust)
                }
                subscriptionRows(diagnostics.subscriptions)
                if let error = diagnostics.lastSyncError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last error")
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.groveMutedRust)
                    }
                }
            } else {
                HStack {
                    Text("Checking iCloud…")
                    Spacer()
                    ProgressView()
                }
            }

            Button {
                Task { await checkFriendAlerts() }
            } label: {
                HStack {
                    Text("Check again")
                    if isCheckingAlerts && diagnostics != nil {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isCheckingAlerts)

            Menu {
                if let myID = socialService.currentUserID {
                    Button("This phone") { sendTest(to: myID) }
                }
                if !socialService.friends.isEmpty {
                    Section("A friend") {
                        ForEach(socialService.friends) { friend in
                            Button(friend.displayName) { sendTest(to: friend.id) }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Send test alert")
                    if isSendingTest {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isSendingTest || socialService.currentUserID == nil)

            if let testResult {
                Text(testResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Friend Alert Status")
        } footer: {
            Text("Friend workout alerts are sent by iCloud the moment a friend posts. Each friend needs an alert set up on this phone. A test alert to a friend shows up on their phone and confirms their alerts work.")
        }
    }

    @ViewBuilder
    private func subscriptionRows(_ subscriptions: CloudKitSocialService.PushDiagnostics.Subscriptions) -> some View {
        switch subscriptions {
        case .friendActivityOff:
            LabeledContent("Workout alerts", value: "Off (Friend Activity)")
        case .notReady(let reason):
            LabeledContent("Workout alerts") {
                Text(reason).foregroundStyle(Color.groveMutedRust)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout alerts")
                Text("Couldn't check: \(message)")
                    .font(.footnote)
                    .foregroundStyle(Color.groveMutedRust)
            }
        case .checked(let active, let expected, let missingNames, let selfTestActive):
            LabeledContent("Workout alerts") {
                Text(expected == 0 ? "No friends yet" : "\(active) of \(expected) friends")
                    .foregroundStyle(active == expected ? Color.groveSage : Color.groveMutedRust)
            }
            if !missingNames.isEmpty {
                Text("Missing: \(missingNames.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(Color.groveMutedRust)
            }
            LabeledContent("Test alerts") {
                Text(selfTestActive ? "Ready" : "Not set up")
                    .foregroundStyle(selfTestActive ? Color.groveSage : Color.groveMutedRust)
            }
        }
    }

    private func checkFriendAlerts() async {
        guard !isCheckingAlerts else { return }
        isCheckingAlerts = true
        diagnostics = await socialService.pushDiagnostics()
        isCheckingAlerts = false
    }

    private func sendTest(to recipientID: String) {
        let isSelf = recipientID == socialService.currentUserID
        let name = socialService.friends.first { $0.id == recipientID }?.displayName ?? "your friend"
        isSendingTest = true
        testResult = nil
        Task {
            if let error = await socialService.sendTestPush(to: recipientID) {
                testResult = "Couldn't send: \(error)"
            } else if isSelf {
                testResult = "Sent. It should arrive within a few seconds, even with Grove closed. If it doesn't, ask a friend to send you one: iCloud may skip the phone that sent it."
            } else {
                testResult = "Sent. Ask \(name) whether it arrived. If not, their app needs updating or opening once."
            }
            isSendingTest = false
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
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .environment(CloudKitSocialService())
}
