import SwiftUI
import SwiftData
import PhotosUI

struct ProfileSetupView: View {
    var user: User
    var onContinue: () -> Void

    @State private var displayName: String
    @State private var selectedUnits: UnitSystem
    @State private var trackCreatine: Bool
    @State private var selectedImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showingImageSource = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false

    // Animation states
    @State private var showPlant = false
    @State private var showGreeting = false
    @State private var showNameBubble = false
    @State private var showPhoto = false
    @State private var showUnits = false
    @State private var showCreatine = false
    @State private var showButton = false
    @State private var photoRingPulse = false
    @State private var typedText = ""
    @FocusState private var nameFieldFocused: Bool

    private let greetingQuestion = "What should I call you?"

    init(user: User, onContinue: @escaping () -> Void) {
        self.user = user
        self.onContinue = onContinue
        _displayName = State(initialValue: user.displayName ?? "")
        _selectedUnits = State(initialValue: user.preferredUnits)
        _trackCreatine = State(initialValue: user.trackCreatine)
    }

    private var initials: String {
        let name = displayName.isEmpty ? (user.displayName ?? "") : displayName
        let parts = name.split(separator: " ")
        let result = parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
        return result.isEmpty ? "?" : result
    }

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // Animated seedling
                StreakPlantView(
                    streak: 1,
                    size: 100,
                    showLabel: false
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(showPlant ? 1 : 0)
                .offset(y: showPlant ? 0 : 20)

                // Conversational greeting bubble
                if showGreeting {
                    VStack(spacing: 20) {
                        // Speech bubble with typed question
                        VStack(spacing: 0) {
                            ZStack(alignment: .leading) {
                                // Invisible full text to reserve layout space
                                Text(greetingQuestion)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .opacity(0)

                                // Visible typed text
                                Text(typedText)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.groveText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
                            )

                            // Bubble tail
                            Triangle()
                                .fill(Color.groveCardBackground)
                                .frame(width: 16, height: 10)
                                .offset(x: -40)
                        }
                        .shadow(color: Color.groveSage.opacity(0.08), radius: 12, y: 4)

                        // Name input (appears after typing finishes)
                        if showNameBubble {
                            TextField("Your name", text: $displayName)
                                .font(.title3)
                                .fontWeight(.medium)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(Color.groveCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            nameFieldFocused ? Color.groveSage.opacity(0.5) : Color.groveSage.opacity(0.15),
                                            lineWidth: nameFieldFocused ? 2 : 1
                                        )
                                        .animation(.easeInOut(duration: 0.2), value: nameFieldFocused)
                                )
                                .focused($nameFieldFocused)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }

                // Profile photo
                if showPhoto {
                    VStack(spacing: 10) {
                        Text("Add a photo")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveTextSecondary)

                        Button {
                            showingImageSource = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.groveSage.opacity(0.3), lineWidth: 2)
                                        .frame(width: 104, height: 104)
                                        .scaleEffect(photoRingPulse ? 1.08 : 1.0)
                                        .opacity(photoRingPulse ? 0 : 0.6)

                                    Circle()
                                        .fill(Color.groveSage.opacity(0.1))
                                        .frame(width: 96, height: 96)
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
                                                VStack(spacing: 4) {
                                                    Image(systemName: "camera.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(Color.groveSage)
                                                    Text(initials == "?" ? "Tap" : initials)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(Color.groveSage.opacity(0.7))
                                                }
                                            }
                                        }
                                }

                                Circle()
                                    .fill(Color.groveSage)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: Color.groveSage.opacity(0.3), radius: 4, y: 2)
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Weight units
                if showUnits {
                    VStack(spacing: 10) {
                        Text("I prefer to track in")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.groveTextSecondary)

                        HStack(spacing: 12) {
                            unitButton(.imperial, label: "lbs", icon: "scalemass.fill")
                            unitButton(.metric, label: "kg", icon: "scalemass.fill")
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Creatine tracking opt-in
                if showCreatine {
                    VStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                                trackCreatine.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: trackCreatine ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(trackCreatine ? Color.groveSage : Color.groveTextSecondary.opacity(0.5))
                                    .contentTransition(.symbolEffect(.replace))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("I take creatine daily")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.groveText)
                                    Text("We'll add a daily check-in to your home screen")
                                        .font(.caption)
                                        .foregroundStyle(Color.groveTextSecondary)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(
                                trackCreatine
                                    ? Color.groveSage.opacity(0.08)
                                    : Color.groveCardBackground
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        trackCreatine ? Color.groveSage.opacity(0.3) : Color.groveSage.opacity(0.15),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Continue button
                if showButton {
                    Button(action: handleContinue) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.groveSage, Color.groveSage.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.groveSage.opacity(0.3), radius: 8, y: 4)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: geometry.size.height)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(Color.groveBackground)
        .onAppear { startAnimationSequence() }
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
        } // GeometryReader
    }

    // MARK: - Unit Button

    private func unitButton(_ unit: UnitSystem, label: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                selectedUnits = unit
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.headline)
            }
            .foregroundStyle(selectedUnits == unit ? .white : Color.groveText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                selectedUnits == unit
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.groveSage, Color.groveSage.opacity(0.85)],
                        startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.groveCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedUnits == unit ? Color.clear : Color.groveSage.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: selectedUnits == unit ? Color.groveSage.opacity(0.2) : .clear,
                radius: 6, y: 3
            )
        }
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // 1. Plant bounces in
        withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
            showPlant = true
        }

        // 2. Greeting bubble appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                showGreeting = true
            }
            // Start typing effect
            typeText()
        }
    }

    private func typeText() {
        typedText = ""
        for (index, char) in greetingQuestion.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04) {
                typedText.append(char)

                // After typing finishes, show the rest
                if index == greetingQuestion.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                            showNameBubble = true
                        }
                        nameFieldFocused = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                            showPhoto = true
                        }
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            photoRingPulse = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                            showUnits = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                            showCreatine = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                            showButton = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            user.displayName = trimmed
        }
        user.preferredUnits = selectedUnits
        user.trackCreatine = trackCreatine

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

// MARK: - Speech Bubble Tail

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
        path.closeSubpath()
        return path
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
