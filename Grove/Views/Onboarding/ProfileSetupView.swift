import SwiftUI
import SwiftData
import PhotosUI

struct ProfileSetupView: View {
    var user: User
    var onContinue: () -> Void

    @State private var displayName: String
    @State private var selectedUnits: UnitSystem
    @State private var selectedGoal: FitnessGoal
    @State private var selectedLevel: ExperienceLevel
    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showingImageSource = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false

    init(user: User, onContinue: @escaping () -> Void) {
        self.user = user
        self.onContinue = onContinue
        _displayName = State(initialValue: user.displayName ?? "")
        _selectedUnits = State(initialValue: user.preferredUnits)
        _selectedGoal = State(initialValue: user.fitnessGoal)
        _selectedLevel = State(initialValue: user.experienceLevel)
    }

    private var initials: String {
        let name = user.displayName ?? displayName
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased().isEmpty
            ? "?"
            : parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveCharcoal)
                    Text("Tell us a bit about yourself")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Profile photo
                Button {
                    showingImageSource = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.groveSage.opacity(0.15))
                            .frame(width: 88, height: 88)
                            .overlay {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                } else if let data = user.profileImageData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                } else {
                                    Text(initials)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.groveSage)
                                }
                            }

                        // Camera badge
                        Circle()
                            .fill(Color.groveSage)
                            .frame(width: 26, height: 26)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 2, y: 2)
                    }
                }

                // Display name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.groveWarmSand.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Weight units
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight Units")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Picker("Units", selection: $selectedUnits) {
                        Text("lbs").tag(UnitSystem.imperial)
                        Text("kg").tag(UnitSystem.metric)
                    }
                    .pickerStyle(.segmented)
                }

                // Fitness goal
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fitness Goal")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(FitnessGoal.allCases, id: \.self) { goal in
                            GoalCard(goal: goal, isSelected: selectedGoal == goal) {
                                selectedGoal = goal
                            }
                        }
                    }
                }

                // Experience level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Experience Level")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 10) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            LevelButton(level: level, isSelected: selectedLevel == level) {
                                selectedLevel = level
                            }
                        }
                    }
                }

                // Continue button
                Button(action: handleContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.groveSage)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.groveCream)
        .confirmationDialog("Add Photo", isPresented: $showingImageSource, titleVisibility: .visible) {
            Button("Choose from Library") { showingPhotoPicker = true }
            Button("Take Photo") { showingCamera = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView(selectedImage: $selectedImage, onDismiss: { showingCamera = false })
                .ignoresSafeArea()
        }
    }

    private func handleContinue() {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            user.displayName = trimmed
        }
        user.preferredUnits = selectedUnits
        user.fitnessGoal = selectedGoal
        user.experienceLevel = selectedLevel

        if let image = selectedImage {
            user.profileImageData = processImage(image)
        }

        onContinue()
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

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch goal {
        case .buildMuscle: return "dumbbell.fill"
        case .loseWeight: return "flame.fill"
        case .stayActive: return "heart.fill"
        case .trainForEvent: return "trophy.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.groveSage)
                Text(goal.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : Color.groveCharcoal)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.groveSage : Color.groveWarmSand.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.groveSage : Color.clear, lineWidth: 2)
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Level Button

private struct LevelButton: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(level.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : Color.groveCharcoal)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Color.groveSage : Color.groveWarmSand.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        nonisolated func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            MainActor.assumeIsolated {
                parent.selectedImage = image
                parent.onDismiss()
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            MainActor.assumeIsolated {
                parent.onDismiss()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    let user = User(appleUserID: "preview")
    user.displayName = "Thomas"
    container.mainContext.insert(user)

    return ProfileSetupView(user: user, onContinue: {})
        .modelContainer(container)
}
