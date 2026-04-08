import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    let workout: Workout

    @State private var shareData: ShareableData?
    @State private var showingHealthKitConnect = false
    @State private var showingShareToFeed = false

    private var workoutExercises: [ExerciseLog] {
        workout.exercises
    }

    private var formattedDate: String {
        guard let completedAt = workout.completedAt else { return "In Progress" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }

    private var formattedDuration: String {
        let totalSeconds = Int(workout.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }

    private var totalVolume: Double {
        workoutExercises.reduce(0) { exerciseTotal, exerciseLog in
            exerciseTotal + exerciseLog.sets.reduce(0) { setTotal, setLog in
                guard setLog.isCompleted,
                      setLog.bodyweightModifier != .assisted,
                      let weight = setLog.weight,
                      let reps = setLog.reps else { return setTotal }
                return setTotal + (weight * Double(reps))
            }
        }
    }

    private var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk lbs", totalVolume / 1000)
        } else {
            return String(format: "%.0f lbs", totalVolume)
        }
    }

    private var totalSets: Int {
        workoutExercises.reduce(0) { total, exerciseLog in
            total + exerciseLog.sets.filter { $0.isCompleted }.count
        }
    }

    private var sortedExercises: [ExerciseLog] {
        workoutExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var workoutPRs: [PersonalRecord] {
        let setIDs = Set(workout.exercises.flatMap { $0.sets.map { $0.id } })
        let descriptor = FetchDescriptor<PersonalRecord>()
        guard let allPRs = try? modelContext.fetch(descriptor) else { return [] }
        return allPRs
            .filter { pr in
                pr.type == .maxWeight &&
                pr.setLogID != nil &&
                setIDs.contains(pr.setLogID!)
            }
            .sorted { a, b in
                let nameA = a.exercise?.name ?? ""
                let nameB = b.exercise?.name ?? ""
                return nameA < nameB
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Stats
                headerSection

                // Notes (if any)
                if let notes = workout.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                            .foregroundStyle(Color.groveText)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(Color.groveText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.groveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Personal Records (if any)
                if !workoutPRs.isEmpty {
                    prSection
                }

                // Exercises
                exercisesSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color.groveBackground)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if workout.healthKitWorkoutID == nil && HealthKitManager.shared.isAuthorized {
                        Button {
                            showingHealthKitConnect = true
                        } label: {
                            Image(systemName: "applewatch")
                        }
                    }

                    if !workout.isShared && workout.completedAt != nil {
                        Button {
                            showingShareToFeed = true
                        } label: {
                            Image(systemName: "person.2.fill")
                        }
                    }

                    Button {
                        prepareShareImage()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $shareData) { data in
            WorkoutShareSheet(data: data)
        }
        .sheet(isPresented: $showingShareToFeed) {
            ShareToFeedSheet(workout: workout)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingHealthKitConnect) {
            HealthKitConnectView(
                workout: workout,
                onConnect: { _ in
                    showingHealthKitConnect = false
                },
                onSkip: {
                    showingHealthKitConnect = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Share Image Rendering

    private func prepareShareImage() {
        let unitLabel = workout.user?.preferredUnits == .metric ? "kg" : "lbs"
        let prs = workoutPRs
        let prSetIDs = Set(prs.compactMap(\.setLogID))
        let card = WorkoutShareCardView(
            workout: workout,
            prCount: prs.count,
            prSetIDs: prSetIDs,
            unitLabel: unitLabel,
            colorScheme: colorScheme
        )
        let scale = displayScale
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        DispatchQueue.main.async {
            if let uiImage = renderer.uiImage {
                shareData = ShareableData(
                    workout: workout,
                    prCount: prs.count,
                    prSetIDs: prSetIDs,
                    unitLabel: unitLabel,
                    colorScheme: colorScheme,
                    displayScale: scale,
                    initialImage: uiImage
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Date and Duration
            HStack {
                Label(formattedDate, systemImage: "calendar")
                Spacer()
                Label(formattedDuration, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Stats Grid
            HStack(spacing: 16) {
                StatBox(
                    title: "Exercises",
                    value: "\(workout.completedExerciseCount)",
                    icon: "figure.strengthtraining.traditional"
                )

                StatBox(
                    title: "Sets",
                    value: "\(totalSets)",
                    icon: "repeat"
                )

                StatBox(
                    title: "Volume",
                    value: formattedVolume,
                    icon: "scalemass"
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            // Apple Watch data
            if workout.healthKitWorkoutID != nil {
                HStack(spacing: 16) {
                    if let avgHR = workout.heartRateAvg {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("\(Int(avgHR)) bpm")
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                    }

                    if let cal = workout.caloriesBurned {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(Int(cal)) kcal")
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                    }

                    if let minHR = workout.heartRateMin, let maxHR = workout.heartRateMax {
                        Text("\(Int(minHR))–\(Int(maxHR)) bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - PR Section

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Personal Records", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(Color.groveTerracotta)

                Spacer()

                Text("\(workoutPRs.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(workoutPRs, id: \.id) { pr in
                        PRCard(pr: pr)
                    }
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -16)
        }
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 0) {
                let prSetIDSet = Set(workoutPRs.compactMap(\.setLogID))
                ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, exerciseLog in
                    ExerciseDetailRow(exerciseLog: exerciseLog, prSetIDs: prSetIDSet)

                    if index < sortedExercises.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.groveSage)
                .frame(height: 24)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .background(Color.groveWarmSand.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - PR Card

private struct PRCard: View {
    let pr: PersonalRecord

    private var exerciseName: String {
        pr.exercise?.name ?? "Unknown"
    }

    private var typeLabel: String {
        "Personal Record"
    }

    private var displayValue: String {
        let w = pr.weight == floor(pr.weight) ? "\(Int(pr.weight))" : String(format: "%.1f", pr.weight)
        return "\(w) lbs x \(pr.reps)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Color.groveTerracotta)

            Text(exerciseName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)

            Text(typeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(displayValue)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveTerracotta)
        }
        .padding(12)
        .frame(width: 140, alignment: .leading)
        .background(Color.groveTerracotta.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exercise Detail Row

private struct ExerciseDetailRow: View {
    let exerciseLog: ExerciseLog
    var prSetIDs: Set<UUID> = []

    private var exerciseName: String {
        exerciseLog.exercise?.name ?? "Unknown Exercise"
    }

    private var completedSets: [SetLog] {
        exerciseLog.sets
            .filter { $0.isCompleted }
            .sorted { $0.setNumber < $1.setNumber }
    }

    private var statusIcon: String {
        switch exerciseLog.status {
        case .completed:
            return "checkmark.circle.fill"
        case .skipped:
            return "forward.fill"
        case .inProgress:
            return "circle.dotted"
        case .planned:
            return "circle"
        }
    }

    private var statusColor: Color {
        switch exerciseLog.status {
        case .completed:
            return Color.groveSage
        case .skipped:
            return Color.groveMutedRust
        case .inProgress:
            return Color.groveTerracotta
        case .planned:
            return Color.groveWarmSand
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise Name and Status
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)

                Spacer()

                if exerciseLog.status == .skipped {
                    Text("Skipped")
                        .font(.caption)
                        .foregroundStyle(Color.groveMutedRust)
                }
            }

            // Sets
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(completedSets, id: \.id) { setLog in
                        SetDetailRow(setLog: setLog, isPR: prSetIDs.contains(setLog.id))
                    }
                }
                .padding(.leading, 28)
            } else if exerciseLog.status != .skipped {
                Text("No sets completed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 28)
            }
        }
        .padding(16)
    }
}

// MARK: - Set Detail Row

private struct SetDetailRow: View {
    let setLog: SetLog
    var isPR: Bool = false

    private var weightText: String {
        guard let weight = setLog.weight else { return "-" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        } else {
            return String(format: "%.1f", weight)
        }
    }

    private var repsText: String {
        guard let reps = setLog.reps else { return "-" }
        return "\(reps)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("Set \(setLog.setNumber):")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text("\(weightText) lbs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveText)

            Text("×")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(repsText) reps")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveText)

            if isPR {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTerracotta)
            }

            Spacer()
        }
    }
}

// MARK: - Shareable Data

private struct ShareableData: Identifiable {
    let id = UUID()
    let workout: Workout
    let prCount: Int
    let prSetIDs: Set<UUID>
    let unitLabel: String
    let colorScheme: ColorScheme
    let displayScale: CGFloat
    let initialImage: UIImage
}

// MARK: - Workout Share Sheet

private struct WorkoutShareSheet: View {
    let data: ShareableData
    @Environment(\.dismiss) private var dismiss
    @State private var detailed = false
    @State private var currentImage: UIImage
    @State private var showSystemShare = false
    @State private var savedToPhotos = false

    init(data: ShareableData) {
        self.data = data
        _currentImage = State(initialValue: data.initialImage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // View mode toggle
                    Picker("View", selection: $detailed) {
                        Text("Compact").tag(false)
                        Text("Detailed").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Image(uiImage: currentImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.horizontal)
                        .animation(.default, value: detailed)

                    VStack(spacing: 12) {
                        Button {
                            showSystemShare = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.groveSage)

                        Button {
                            UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
                            withAnimation { savedToPhotos = true }
                        } label: {
                            Label(savedToPhotos ? "Saved" : "Save to Photos",
                                  systemImage: savedToPhotos ? "checkmark" : "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(savedToPhotos ? Color.groveSage : Color.groveTerracotta)
                        .disabled(savedToPhotos)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.groveBackground)
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSystemShare) {
                ActivitySheet(image: currentImage, title: data.workout.name)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: detailed) {
                savedToPhotos = false
                renderImage()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func renderImage() {
        let card = WorkoutShareCardView(
            workout: data.workout,
            prCount: data.prCount,
            prSetIDs: data.prSetIDs,
            unitLabel: data.unitLabel,
            colorScheme: data.colorScheme,
            detailed: detailed
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = data.displayScale
        DispatchQueue.main.async {
            if let uiImage = renderer.uiImage {
                currentImage = uiImage
            }
        }
    }
}

// MARK: - Activity Sheet

private struct ActivitySheet: UIViewControllerRepresentable {
    let image: UIImage
    let title: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = ImageItemSource(image: image, title: title)
        return UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Image Item Source (provides LPLinkMetadata for share sheet preview)

import LinkPresentation

private class ImageItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

private struct WorkoutDetailPreview: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workout: Workout?

    var body: some View {
        NavigationStack {
            if let workout {
                WorkoutDetailView(workout: workout)
            } else {
                ProgressView()
                    .onAppear { setupPreviewData() }
            }
        }
    }

    private func setupPreviewData() {
        let exercise1 = Exercise(name: "Bench Press", muscleGroup: .chest)
        let exercise2 = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        let exercise3 = Exercise(name: "Cable Flyes", muscleGroup: .chest)

        modelContext.insert(exercise1)
        modelContext.insert(exercise2)
        modelContext.insert(exercise3)

        let newWorkout = Workout(name: "Push Day")
        newWorkout.startedAt = Date().addingTimeInterval(-3600)
        newWorkout.completedAt = Date()
        modelContext.insert(newWorkout)

        let log1 = ExerciseLog(exercise: exercise1, orderIndex: 0)
        log1.workout = newWorkout
        log1.status = ExerciseStatus.completed
        modelContext.insert(log1)

        for i in 1...4 {
            let set = SetLog(setNumber: i, weight: 135, reps: 10)
            set.isCompleted = true
            set.exerciseLog = log1
            log1.sets.append(set)
            modelContext.insert(set)
        }

        let log2 = ExerciseLog(exercise: exercise2, orderIndex: 1)
        log2.workout = newWorkout
        log2.status = ExerciseStatus.completed
        modelContext.insert(log2)

        for i in 1...3 {
            let set = SetLog(setNumber: i, weight: 50, reps: 12)
            set.isCompleted = true
            set.exerciseLog = log2
            log2.sets.append(set)
            modelContext.insert(set)
        }

        let log3 = ExerciseLog(exercise: exercise3, orderIndex: 2)
        log3.workout = newWorkout
        log3.status = ExerciseStatus.skipped
        modelContext.insert(log3)

        workout = newWorkout
    }
}

#Preview {
    WorkoutDetailPreview()
        .modelContainer(for: [User.self, Workout.self, ExerciseLog.self, SetLog.self, Exercise.self], inMemory: true)
}
