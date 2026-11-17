import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(CloudKitSocialService.self) private var socialService
    @Query private var users: [User]
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]

    let workout: Workout

    private var user: User? { users.first }
    @State private var showSharingOptions = false

    private var prExerciseNames: Set<String> {
        Set(sessionManager.newPRs.map { $0.exercise.name })
    }

    private var totalVolume: Double {
        Self.volume(of: workout)
    }

    private var completedSetsCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted && !$0.isWarmup }.count }
    }

    private var warmupSetsCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted && $0.isWarmup }.count }
    }

    /// Weighted volume (weight × reps) of completed working sets, excluding assisted sets.
    private static func volume(of workout: Workout) -> Double {
        workout.exercises.reduce(0) { exerciseTotal, exerciseLog in
            exerciseTotal + exerciseLog.sets.reduce(0) { setTotal, setLog in
                guard setLog.isCompleted,
                      !setLog.isWarmup,
                      setLog.bodyweightModifier != .assisted,
                      let weight = setLog.weight,
                      let reps = setLog.reps else { return setTotal }
                return setTotal + (weight * Double(reps))
            }
        }
    }

    /// Volume of the most recent earlier workout with the same name that has any weighted
    /// volume. Workouts with none (bodyweight-only, or sets logged without weights) are
    /// skipped: a 0 baseline can't give a percentage and used to leave the section empty.
    private var previousVolume: Double? {
        allWorkouts.lazy
            .filter { $0.id != workout.id && $0.name == workout.name && $0.completedAt != nil }
            .map(Self.volume(of:))
            .first { $0 > 0 }
    }

    private var volumeChange: Double? {
        // No comparison on a day with no weighted volume (e.g. bodyweight only): it would read -100%.
        guard totalVolume > 0, let prev = previousVolume, prev > 0 else { return nil }
        return ((totalVolume - prev) / prev) * 100
    }

    private var hasNewPRs: Bool {
        !sessionManager.newPRs.isEmpty
    }

    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Stats cards
                    statsSection

                    // Apple Watch data (if connected)
                    if workout.healthKitWorkoutID != nil {
                        appleWatchSection
                    }

                    // Comparison (if available)
                    if volumeChange != nil {
                        comparisonSection
                    }

                    // Personal records (if any)
                    if hasNewPRs {
                        prSection
                    }

                    // Achievements (if any newly earned)
                    if !sessionManager.newAchievements.isEmpty {
                        achievementSection
                    }

                    // Exercise breakdown
                    exerciseBreakdownSection

                    // Workout notes
                    notesSection
                }
                .padding()
            }
            .background(Color.groveBackground)
            // Posting, sunlight and finishing stay pinned so they never need a scroll.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                postBar
            }
            .sheet(isPresented: $showSharingOptions) {
                sharingOptionsSheet
                    .presentationDetents([.medium])
            }
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if showConfetti {
                    ConfettiView()
                }
            }
            .onAppear {
                showConfetti = true
                if let user, user.autoShareWorkouts, !workout.isShared {
                    workout.isShared = true
                    workout.shareWorkoutName = user.shareWorkoutName
                    workout.shareDuration = user.shareDuration
                    workout.shareExercises = user.shareExercises
                    workout.shareWeights = user.shareWeights
                    workout.sharePRs = user.sharePRs
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.groveSage)

            Text(workout.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)

            Text(formattedDate(workout.startedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(completionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var completionSummary: String {
        let total = workout.exercises.count
        let completed = exerciseCount
        return "\(completed) of \(total) exercises completed"
    }

    /// Exercises with at least one logged set. Untouched exercises stay `.planned`, not
    /// `.skipped`, so status alone overcounts ("6 of 6 completed" with one exercise done).
    private func wasDone(_ log: ExerciseLog) -> Bool {
        log.status != .skipped && log.sets.contains { $0.isCompleted }
    }

    private var exerciseCount: Int {
        workout.exercises.filter(wasDone).count
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "figure.strengthtraining.traditional",
                value: "\(exerciseCount)",
                label: "Exercises"
            )

            StatCard(
                icon: "scalemass.fill",
                value: formatVolume(totalVolume),
                label: "Volume"
            )

            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(completedSetsCount)",
                label: warmupSetsCount > 0 ? "Sets (+\(warmupSetsCount)W)" : "Sets"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var appleWatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Watch", systemImage: "applewatch")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            HStack(spacing: 16) {
                if let avgHR = workout.heartRateAvg {
                    StatCard(
                        icon: "heart.fill",
                        value: "\(Int(avgHR))",
                        label: "Avg BPM"
                    )
                }

                if let minHR = workout.heartRateMin, let maxHR = workout.heartRateMax {
                    StatCard(
                        icon: "waveform.path.ecg",
                        value: "\(Int(minHR))-\(Int(maxHR))",
                        label: "HR Range"
                    )
                }

                if let cal = workout.caloriesBurned {
                    StatCard(
                        icon: "flame.fill",
                        value: "\(Int(cal))",
                        label: "kcal"
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("vs Last \(workout.name)")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            if let change = volumeChange {
                ComparisonCard(
                    label: "Volume",
                    change: change,
                    isPositive: change >= 0
                )
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("New Personal Records", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(Color.groveTerracotta)

                Spacer()

                Text("\(prCards.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(prCards, id: \.id) { card in
                        SummaryPRCard(
                            exerciseName: card.exerciseName,
                            typeLabel: card.typeLabel,
                            displayValue: card.displayValue
                        )
                    }
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -16)
        }
    }

    private var prCards: [PRCardData] {
        sessionManager.newPRs.map { result -> PRCardData in
            let pr = result.newPR
            if pr.type == .maxReps {
                return PRCardData(
                    id: "\(result.exercise.id)-pr",
                    exerciseName: result.exercise.name,
                    typeLabel: "New PR",
                    displayValue: "\(pr.reps) reps"
                )
            } else {
                let w = pr.weight == floor(pr.weight) ? "\(Int(pr.weight))" : String(format: "%.1f", pr.weight)
                let units = workout.user?.preferredUnits == .metric ? "kg" : "lbs"
                return PRCardData(
                    id: "\(result.exercise.id)-pr",
                    exerciseName: result.exercise.name,
                    typeLabel: "New PR",
                    displayValue: "\(w) \(units) x \(pr.reps)"
                )
            }
        }
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Achievement Unlocked!", systemImage: "trophy.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.groveTerracotta)

            VStack(spacing: 8) {
                ForEach(sessionManager.newAchievements, id: \.type) { result in
                    AchievementRow(type: result.type, relatedData: result.achievement.relatedData)
                }
            }
        }
    }

    // MARK: - Post bar

    @State private var sunlightTargetID: String?

    private var shareBinding: Binding<Bool> {
        Binding(
            get: { workout.isShared },
            set: { newValue in
                workout.isShared = newValue
                if newValue, let user {
                    workout.shareWorkoutName = user.shareWorkoutName
                    workout.shareDuration = user.shareDuration
                    workout.shareExercises = user.shareExercises
                    workout.shareWeights = user.shareWeights
                    workout.sharePRs = user.sharePRs
                }
            }
        )
    }

    /// What the post will include, e.g. "Name, duration, exercises, PRs".
    private var shareContentsSummary: String {
        var parts: [String] = []
        if workout.shareWorkoutName { parts.append("name") }
        if workout.shareDuration { parts.append("duration") }
        if workout.shareExercises { parts.append(workout.shareWeights ? "exercises with weights" : "exercises") }
        if workout.sharePRs && !prExerciseNames.isEmpty { parts.append("PRs") }
        guard let first = parts.first else { return "Set count only" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + parts.dropFirst()).joined(separator: ", ")
    }

    private var sunlightCandidates: [SharedWorkoutItem] {
        socialService.sunlightCandidates
    }

    private var postBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Post to feed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveText)
                    if workout.isShared {
                        Button {
                            showSharingOptions = true
                        } label: {
                            (Text(shareContentsSummary + " · ").foregroundStyle(.secondary)
                             + Text("Customize").foregroundStyle(Color.groveSage))
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Only you will see this workout")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("Post to feed", isOn: shareBinding)
                    .labelsHidden()
                    .tint(.groveSage)
            }

            // Sunlight comes from a shared workout, so it's only offered when posting.
            if workout.isShared && !sunlightCandidates.isEmpty {
                SunlightPromptCard(
                    candidates: sunlightCandidates,
                    alreadySunlitIDs: Set(sunlightCandidates.lazy
                        .filter { socialService.interactionsByWorkout[$0.id]?.iSunlit == true }
                        .map(\.id)),
                    selectedItemID: $sunlightTargetID
                )
            }

            finishButton
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.groveBackground)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeInOut(duration: 0.2), value: workout.isShared)
    }

    private var sharingOptionsSheet: some View {
        NavigationStack {
            Form {
                Toggle("Workout name", isOn: Binding(
                    get: { workout.shareWorkoutName },
                    set: { workout.shareWorkoutName = $0 }
                ))
                Toggle("Duration", isOn: Binding(
                    get: { workout.shareDuration },
                    set: { workout.shareDuration = $0 }
                ))
                Toggle("Exercises", isOn: Binding(
                    get: { workout.shareExercises },
                    set: { workout.shareExercises = $0 }
                ))
                Toggle("Weights", isOn: Binding(
                    get: { workout.shareWeights },
                    set: { workout.shareWeights = $0 }
                ))
                .disabled(!workout.shareExercises)
                if !prExerciseNames.isEmpty {
                    Toggle("Personal records", isOn: Binding(
                        get: { workout.sharePRs },
                        set: { workout.sharePRs = $0 }
                    ))
                }
            }
            .tint(.groveSage)
            .navigationTitle("What to post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSharingOptions = false }
                }
            }
        }
    }

    private var finishButton: some View {
        Button {
            finish()
        } label: {
            Text(workout.isShared ? "Post and finish" : "Finish")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.groveSage)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func finish() {
        if let user {
            // The toggle remembers your last choice for the next workout.
            user.autoShareWorkouts = workout.isShared
        }
        if workout.isShared, let user {
            // Re-check at send time: interactions may have loaded since the pick.
            let target = sunlightCandidates.first {
                $0.id == sunlightTargetID && socialService.interactionsByWorkout[$0.id]?.iSunlit != true
            }
            let prNames = workout.sharePRs ? prExerciseNames : []
            Task {
                // Post first: the sunlight must come from this workout's post, which only
                // exists once the upload finishes.
                if let postID = await socialService.shareWorkout(workout, user: user, prExerciseNames: prNames),
                   let target {
                    _ = await socialService.sendSunlight(
                        to: target.id,
                        recipientID: target.userID,
                        fromWorkoutRecordName: postID
                    )
                }
                await socialService.updateMyStats(user: user)
                await socialService.checkAvailableSunlight()
            }
        }
        sessionManager.dismissSummary()
    }

    private var exerciseBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Breakdown")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            VStack(spacing: 8) {
                let sorted = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
                let done = sorted.filter(wasDone)
                let notDone = sorted.filter { !wasDone($0) }

                ForEach(done) { exerciseLog in
                    summaryRow(exerciseLog)
                }

                if !notDone.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showSkippedExercises.toggle() }
                    } label: {
                        HStack {
                            Text("\(notDone.count) \(notDone.count == 1 ? "exercise" : "exercises") skipped")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showSkippedExercises ? 180 : 0))
                        }
                        .padding()
                        .background(Color.groveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showSkippedExercises {
                        ForEach(notDone) { exerciseLog in
                            summaryRow(exerciseLog)
                        }
                    }
                }
            }
        }
    }

    @State private var showSkippedExercises = false

    private func summaryRow(_ exerciseLog: ExerciseLog) -> some View {
        let exerciseID = exerciseLog.exercise?.id
        let pr = sessionManager.newPRs.first { $0.exercise.id == exerciseID }
        return ExerciseSummaryRow(exerciseLog: exerciseLog, prSetID: pr?.newPR.setLogID)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            TextEditor(text: Binding(
                get: { workout.notes ?? "" },
                set: { workout.notes = $0.isEmpty ? nil : $0 }
            ))
            .font(.subheadline)
            .foregroundStyle(Color.groveText)
            .frame(minHeight: 60, maxHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if (workout.notes ?? "").isEmpty {
                    Text("How did this workout feel?")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 16)
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.groveSage)
                .frame(height: 28)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ComparisonCard: View {
    let label: String
    let change: Double
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.subheadline)
                .foregroundStyle(isPositive ? Color.groveSage : Color.groveMutedRust)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%+.1f%%", change))
                    .font(.headline)
                    .foregroundStyle(isPositive ? Color.groveSage : Color.groveMutedRust)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExerciseSummaryRow: View {
    let exerciseLog: ExerciseLog
    /// The set that set a new PR, from `PRDetectionService` (all-time best, baselines
    /// excluded), so the row matches the PR cards above it. Nil when there's no new PR.
    let prSetID: UUID?

    private var isPR: Bool { prSetID != nil }

    private var isBodyweightExercise: Bool {
        exerciseLog.exercise?.isBodyweight ?? false
    }

    private var completedSets: [SetLog] {
        exerciseLog.sets.filter { $0.isCompleted && !$0.isWarmup }.sorted { $0.setNumber < $1.setNumber }
    }

    private var warmupSets: [SetLog] {
        exerciseLog.sets.filter { $0.isCompleted && $0.isWarmup }.sorted { $0.setNumber < $1.setNumber }
    }

    private var totalReps: Int {
        completedSets.compactMap(\.reps).reduce(0, +)
    }

    private var exerciseVolume: Double {
        completedSets.reduce(0) { total, set in
            guard set.bodyweightModifier != .assisted,
                  let weight = set.weight, let reps = set.reps else { return total }
            return total + (weight * Double(reps))
        }
    }

    private var bestSet: SetLog? {
        completedSets.max { a, b in
            let aVolume = (a.weight ?? 0) * Double(a.reps ?? 0)
            let bVolume = (b.weight ?? 0) * Double(b.reps ?? 0)
            return aVolume < bVolume
        }
    }

    private var setsVary: Bool {
        guard completedSets.count > 1 else { return false }
        let volumes = completedSets.map { ($0.weight ?? 0) * Double($0.reps ?? 0) }
        return Set(volumes).count > 1
    }

    /// The starred set: the PR set when there's a new PR, otherwise the highest-volume set.
    private func isBestSet(_ set: SetLog) -> Bool {
        if let prSetID { return set.id == prSetID }
        guard setsVary, let best = bestSet else { return false }
        return set.setNumber == best.setNumber
    }

    private var targetComparison: String? {
        let completedSetCount = completedSets.count
        guard completedSetCount > 0 else { return nil }
        let targetSetCount = exerciseLog.targetSets
        let targetRepCount = exerciseLog.targetReps
        guard targetSetCount != nil || targetRepCount != nil else { return nil }

        var parts: [String] = []
        if let target = targetSetCount, target > 0 {
            var label = "\(completedSetCount)/\(target) target sets"
            if !warmupSets.isEmpty {
                label += " (+\(warmupSets.count)W)"
            }
            parts.append(label)
        }
        if let targetReps = targetRepCount, targetReps > 0 {
            let actualTotalReps = completedSets.compactMap(\.reps).reduce(0, +)
            let expectedTotalReps = targetReps * (targetSetCount ?? completedSetCount)
            if expectedTotalReps > 0 {
                let pct = Int((Double(actualTotalReps) / Double(expectedTotalReps)) * 100)
                parts.append("\(pct)% of target reps")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var targetMet: Bool {
        let completedSetCount = completedSets.count
        if let target = exerciseLog.targetSets, target > 0 {
            return completedSetCount >= target
        }
        return true
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exerciseLog.exercise?.name ?? "Exercise")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(exerciseLog.status == .skipped ? .secondary : Color.groveText)
                        .strikethrough(exerciseLog.status == .skipped)

                    if isPR {
                        Text("PR")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.groveTerracotta)
                            .clipShape(Capsule())
                    }
                }

                if exerciseLog.status != .skipped {
                    setsSummaryLine

                    if let targetComparison = targetComparison {
                        Text(targetComparison)
                            .font(.caption2)
                            .foregroundStyle(targetMet ? Color.groveSage : .secondary)
                    }
                }
            }

            Spacer()

            // Volume or total reps
            if exerciseLog.status != .skipped {
                if isBodyweightExercise && exerciseVolume == 0 {
                    Text("\(totalReps) reps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveText)
                } else {
                    Text(formatVolume(exerciseVolume))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.groveText)
                }
            }
        }
        .padding()
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch exerciseLog.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.groveSage)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .foregroundStyle(.secondary)
        default:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var setsSummaryLine: some View {
        let sets = completedSets
        if sets.isEmpty && warmupSets.isEmpty {
            Text("No sets completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if !warmupSets.isEmpty {
                    HStack(spacing: 0) {
                        Text("W: ")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary.opacity(0.6))
                        ForEach(Array(warmupSets.enumerated()), id: \.element.id) { index, set in
                            if index > 0 {
                                Text(", ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                            Text(formatSetDescription(set))
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                    }
                }
                if !sets.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            if index > 0 {
                                Text(", ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if isBestSet(set) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.groveTerracotta)
                                Text(" \(formatSetDescription(set))")
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(formatSetDescription(set))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatSetDescription(_ set: SetLog) -> String {
        guard let reps = set.reps else { return "—" }
        if let weight = set.weight, set.bodyweightModifier != .bodyweight {
            let prefix = set.bodyweightModifier == .weighted ? "+" : (set.bodyweightModifier == .assisted ? "-" : "")
            if weight.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(prefix)\(Int(weight))×\(reps)"
            }
            return String(format: "%@%.1f×%d", prefix, weight, reps)
        }
        return "\(reps) reps"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }
}

// MARK: - PR Card Data

private struct PRCardData {
    let id: String
    let exerciseName: String
    let typeLabel: String
    let displayValue: String
}

// MARK: - Summary PR Card

private struct SummaryPRCard: View {
    let exerciseName: String
    let typeLabel: String
    let displayValue: String

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

// MARK: - PR Row

struct PRRow: View {
    let exerciseName: String
    let type: String
    var weight: Double?
    var reps: Int?
    var value: Double?

    private var displayValue: String {
        if let value = value {
            // Estimated 1RM - show calculated value
            if value == floor(value) {
                return "\(Int(value)) lbs"
            }
            return String(format: "%.1f lbs", value)
        } else if let weight = weight, let reps = reps {
            // Max weight - show weight × reps
            if weight == floor(weight) {
                return "\(Int(weight)) × \(reps)"
            }
            return String(format: "%.1f × %d", weight, reps)
        }
        return "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Color.groveTerracotta)

            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                Text(type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(displayValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveTerracotta)
        }
        .padding()
        .background(Color.groveTerracotta.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let type: AchievementType
    var relatedData: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundStyle(Color.groveTerracotta)
                .frame(width: 40, height: 40)
                .background(Color.groveTerracotta.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(type.rawValue)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.groveText)

                Text(relatedData ?? type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.groveSage)
        }
        .padding()
        .background(Color.groveTerracotta.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, ExerciseLog.self, SetLog.self, Exercise.self,
        configurations: config
    )
    let ctx = container.mainContext

    // Exercises
    let bench = Exercise(name: "Bench Press", muscleGroup: .chest, muscleSubgroup: "Middle")
    let ohp = Exercise(name: "Overhead Press", muscleGroup: .shoulders, muscleSubgroup: "Front")
    let laterals = Exercise(name: "Lateral Raises", muscleGroup: .shoulders, muscleSubgroup: "Side")
    ctx.insert(bench)
    ctx.insert(ohp)
    ctx.insert(laterals)

    // --- Previous workout (for PR comparison) ---
    let prevWorkout = Workout(name: "Push Day")
    prevWorkout.startedAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    prevWorkout.completedAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    ctx.insert(prevWorkout)

    let prevBenchLog = ExerciseLog(exercise: bench, orderIndex: 0, targetSets: 3, targetReps: 8)
    prevBenchLog.workout = prevWorkout
    prevBenchLog.status = .completed
    ctx.insert(prevBenchLog)
    for i in 1...3 {
        let s = SetLog(setNumber: i, weight: 125, reps: 8)
        s.isCompleted = true
        s.exerciseLog = prevBenchLog
        ctx.insert(s)
    }

    let prevOHPLog = ExerciseLog(exercise: ohp, orderIndex: 1, targetSets: 3, targetReps: 10)
    prevOHPLog.workout = prevWorkout
    prevOHPLog.status = .completed
    ctx.insert(prevOHPLog)
    for i in 1...3 {
        let s = SetLog(setNumber: i, weight: 85, reps: 10)
        s.isCompleted = true
        s.exerciseLog = prevOHPLog
        ctx.insert(s)
    }

    // --- Current workout ---
    let workout = Workout(name: "Push Day")
    workout.completedAt = Date()
    ctx.insert(workout)

    // Bench Press: varying sets (star on set 2), PR vs previous 125
    let benchLog = ExerciseLog(exercise: bench, orderIndex: 0, targetSets: 3, targetReps: 8)
    benchLog.workout = workout
    benchLog.status = .completed
    ctx.insert(benchLog)
    let benchWeights: [(Double, Int)] = [(135, 8), (145, 8), (135, 6)]
    for (i, (w, r)) in benchWeights.enumerated() {
        let s = SetLog(setNumber: i + 1, weight: w, reps: r)
        s.isCompleted = true
        s.exerciseLog = benchLog
        ctx.insert(s)
    }

    // Overhead Press: varying sets (star on set 1), PR vs previous 85
    let ohpLog = ExerciseLog(exercise: ohp, orderIndex: 1, targetSets: 3, targetReps: 10)
    ohpLog.workout = workout
    ohpLog.status = .completed
    ctx.insert(ohpLog)
    let ohpWeights: [(Double, Int)] = [(95, 10), (105, 8), (105, 6)]
    for (i, (w, r)) in ohpWeights.enumerated() {
        let s = SetLog(setNumber: i + 1, weight: w, reps: r)
        s.isCompleted = true
        s.exerciseLog = ohpLog
        ctx.insert(s)
    }

    // Lateral Raises: skipped
    let lateralLog = ExerciseLog(exercise: laterals, orderIndex: 2, targetSets: 3, targetReps: 12)
    lateralLog.workout = workout
    lateralLog.status = .skipped
    ctx.insert(lateralLog)

    return WorkoutSummaryView(workout: workout)
        .environment(WorkoutSessionManager())
        .environment(CloudKitSocialService())
        .modelContainer(container)
}
