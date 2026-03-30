import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var cameraImage: UIImage? = nil
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingDeleteConfirm = false
    @State private var showingSignOutConfirm = false
    @State private var isConnectingHealthKit = false
    @State private var showingPlanEditor = false

    private var user: User? { users.first }

    private var selectedMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        List {
            profilePhotoSection
            accountSection
            preferencesSection
            trainingPlanSection
            sharingSection
            linksSection
            appearanceSection
            dataSection
            appInfoSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.groveBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    user?.profileImageData = processImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView(selectedImage: $cameraImage, onDismiss: { showingCamera = false })
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                user?.profileImageData = processImage(image)
                cameraImage = nil
            }
        }
        .alert("Sign Out?", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                if let user = user {
                    user.appleUserID = "signed-out-\(UUID().uuidString)"
                    user.onboardingCompletedAt = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be signed out and returned to the sign-in screen. Your data will be kept and linked when you sign back in.")
        }
        .alert("Delete Account?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let user = user {
                    modelContext.delete(user)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, workouts, and all data. This cannot be undone.")
        }
        .sheet(isPresented: $showingPlanEditor) {
            if let user = user {
                NavigationStack {
                    SmartBuilderView(
                        user: user,
                        isEditMode: true,
                        onComplete: { showingPlanEditor = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingPlanEditor = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Profile Photo

    private var profilePhotoSection: some View {
        Section {
            if let user = user {
                HStack(spacing: 16) {
                    Menu {
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.groveSage.opacity(0.15))
                                .frame(width: 72, height: 72)
                                .overlay {
                                    if let data = user.profileImageData, let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(Circle())
                                    } else {
                                        Text(initials(for: user))
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.groveSage)
                                    }
                                }

                            Circle()
                                .fill(Color.groveSage)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 2, y: 2)
                        }
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile Photo")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Tap to change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section("Account") {
            if let user = user {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Your name", text: Binding(
                        get: { user.displayName ?? "" },
                        set: { user.displayName = $0.isEmpty ? nil : $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                }

                Picker("Fitness Goal", selection: Binding(
                    get: { user.fitnessGoal },
                    set: { user.fitnessGoal = $0 }
                )) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Text(goal.rawValue).tag(goal)
                    }
                }

                Picker("Experience Level", selection: Binding(
                    get: { user.experienceLevel },
                    set: { user.experienceLevel = $0 }
                )) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section("Preferences") {
            if let user = user {
                Picker("Weight Units", selection: Binding(
                    get: { user.preferredUnits },
                    set: { user.preferredUnits = $0 }
                )) {
                    Text("lbs (Imperial)").tag(UnitSystem.imperial)
                    Text("kg (Metric)").tag(UnitSystem.metric)
                }

                Toggle("Vacation Mode", isOn: Binding(
                    get: { user.vacationModeEnabled },
                    set: { enabled in
                        user.vacationModeEnabled = enabled
                        if enabled {
                            if user.vacationStartDate == nil {
                                user.vacationStartDate = Date()
                            }
                            if user.vacationEndDate == nil {
                                user.vacationEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
                            }
                        }
                    }
                ))

                if user.vacationModeEnabled {
                    DatePicker("Start Date", selection: Binding(
                        get: { user.vacationStartDate ?? Date() },
                        set: { user.vacationStartDate = $0 }
                    ), displayedComponents: .date)

                    DatePicker("End Date", selection: Binding(
                        get: { user.vacationEndDate ?? Date() },
                        set: { user.vacationEndDate = $0 }
                    ), in: (user.vacationStartDate ?? Date())..., displayedComponents: .date)
                }
            }
        }
    }

    // MARK: - Training Plan

    private var trainingPlanSection: some View {
        Section("Training Plan") {
            Button {
                showingPlanEditor = true
            } label: {
                HStack {
                    Label("Edit Training Plan", systemImage: "calendar.badge.plus")
                        .foregroundStyle(Color.groveText)
                    Spacer()
                    if let user = user {
                        Text("\(user.preferredDaysPerWeek) days/week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Sharing Defaults

    private var sharingSection: some View {
        Section {
            if let user = user {
                Toggle("Share Workout Name", isOn: Binding(
                    get: { user.shareWorkoutName },
                    set: { user.shareWorkoutName = $0 }
                ))
                Toggle("Share Duration", isOn: Binding(
                    get: { user.shareDuration },
                    set: { user.shareDuration = $0 }
                ))
                Toggle("Share Exercises", isOn: Binding(
                    get: { user.shareExercises },
                    set: { user.shareExercises = $0 }
                ))
                Toggle("Share Weights", isOn: Binding(
                    get: { user.shareWeights },
                    set: { user.shareWeights = $0 }
                ))
            }
        } header: {
            Text("Sharing Defaults")
        } footer: {
            Text("These defaults apply when sharing workouts to the social feed.")
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        Section {
            Button {
                if HealthKitManager.shared.isAuthorized {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                } else {
                    isConnectingHealthKit = true
                    Task {
                        _ = await HealthKitManager.shared.requestAuthorization()
                        isConnectingHealthKit = false
                    }
                }
            } label: {
                HStack {
                    Label("Apple Health", systemImage: "heart.text.square.fill")
                        .foregroundStyle(Color.groveText)
                    Spacer()
                    if isConnectingHealthKit {
                        ProgressView()
                    } else {
                        Text(healthKitStatusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("Notifications", systemImage: "bell.fill")
            }

            NavigationLink {
                AchievementsGalleryView()
            } label: {
                Label("Achievements", systemImage: "trophy.fill")
            }
        }
    }

    private var healthKitStatusLabel: String {
        if !HealthKitManager.shared.isAvailable {
            return "Not Available"
        } else if HealthKitManager.shared.isAuthorized {
            return "Connected"
        } else {
            return "Not Connected"
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                Button {
                    appearanceMode = mode.rawValue
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                            .foregroundStyle(mode == selectedMode ? Color.groveSage : .secondary)
                            .frame(width: 24)

                        Text(mode.rawValue)
                            .foregroundStyle(Color.groveText)

                        Spacer()

                        if mode == selectedMode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.groveSage)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            HStack {
                Label("Export History", systemImage: "square.and.arrow.up")
                Spacer()
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)

            Button {
                showingSignOutConfirm = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }

            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete Account", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        Section {
            Text("Grove v\(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Helpers

    private func initials(for user: User) -> String {
        let name = user.displayName ?? ""
        if name.isEmpty { return "G" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func processImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 512
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
        let targetSize: CGSize
        if ratio >= 1 {
            targetSize = image.size
        } else {
            targetSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(.preview)
}
