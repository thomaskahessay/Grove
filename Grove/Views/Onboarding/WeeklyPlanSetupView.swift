import SwiftUI
import SwiftData

// MARK: - Preset Split Enum

enum PresetSplit: CaseIterable {
    case threeDay, fourDay, fiveDay, sixDay

    var title: String {
        switch self {
        case .threeDay: return "3-day Full Body"
        case .fourDay: return "4-day Upper/Lower"
        case .fiveDay: return "5-day Bro Split"
        case .sixDay: return "6-day Push/Pull/Legs"
        }
    }

    var subtitle: String {
        switch self {
        case .threeDay: return "Mon / Wed / Fri · Rest in between"
        case .fourDay: return "Mon / Tue / Thu / Fri"
        case .fiveDay: return "Mon – Fri · Each muscle group once"
        case .sixDay: return "Mon – Sat · Max volume"
        }
    }

    var accentColor: Color {
        switch self {
        case .threeDay: return .groveSage
        case .fourDay: return Color(hex: "5B8FBF")
        case .fiveDay: return .groveTerracotta
        case .sixDay: return .groveMutedRust
        }
    }
}

// MARK: - WeeklyPlanSetupView

struct WeeklyPlanSetupView: View {
    var user: User
    var onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { $0.isBuiltIn }) private var exercises: [Exercise]

    private enum Phase { case selection, preview }

    @State private var phase: Phase = .selection
    @State private var selectedPreset: PresetSplit? = nil
    @State private var isApplying = false

    var body: some View {
        ZStack {
            Color.groveCream.ignoresSafeArea()

            switch phase {
            case .selection:
                selectionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            case .preview:
                previewView
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
    }

    // MARK: - Selection View

    private var selectionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Plan your week")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveCharcoal)
                    Text("Choose a training schedule to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    ForEach(PresetSplit.allCases, id: \.title) { preset in
                        PresetCard(preset: preset) {
                            selectedPreset = preset
                            withAnimation(.easeInOut(duration: 0.35)) {
                                phase = .preview
                            }
                        }
                    }
                }

                Button("Skip for now") {
                    onContinue()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Here's your week")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.groveCharcoal)
                        if let preset = selectedPreset {
                            Text(preset.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    if let preset = selectedPreset {
                        scheduleList(for: preset)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: confirmPreset) {
                    Group {
                        if isApplying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Confirm")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.groveSage)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isApplying)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        phase = .selection
                    }
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.groveCream)
        }
    }

    private func scheduleList(for preset: PresetSplit) -> some View {
        let schedule = scheduleFor(preset)
        return VStack(spacing: 0) {
            ForEach(Array(schedule.enumerated()), id: \.offset) { index, entry in
                HStack {
                    Text(entry.dayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveCharcoal)
                        .frame(width: 40, alignment: .leading)

                    Spacer()

                    if let name = entry.templateName {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(preset.accentColor)
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(Color.groveCharcoal)
                        }
                    } else {
                        Text("Rest")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(index % 2 == 0 ? Color.groveWarmSand.opacity(0.3) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.groveWarmSand, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func confirmPreset() {
        guard let preset = selectedPreset else { return }
        isApplying = true
        let templates = createTemplates(for: preset)
        createPlans(for: preset, templates: templates)
        isApplying = false
        onContinue()
    }

    // MARK: - Schedule Definition

    private func scheduleFor(_ preset: PresetSplit) -> [(dayName: String, templateName: String?)] {
        switch preset {
        case .threeDay:
            return [
                ("Mon", "Full Body"), ("Tue", nil), ("Wed", "Full Body"),
                ("Thu", nil), ("Fri", "Full Body"), ("Sat", nil), ("Sun", nil)
            ]
        case .fourDay:
            return [
                ("Mon", "Upper"), ("Tue", "Lower"), ("Wed", nil),
                ("Thu", "Upper"), ("Fri", "Lower"), ("Sat", nil), ("Sun", nil)
            ]
        case .fiveDay:
            return [
                ("Mon", "Chest & Triceps"), ("Tue", "Back & Biceps"), ("Wed", "Shoulders"),
                ("Thu", "Legs"), ("Fri", "Full Body"), ("Sat", nil), ("Sun", nil)
            ]
        case .sixDay:
            return [
                ("Mon", "Push"), ("Tue", "Pull"), ("Wed", "Legs"),
                ("Thu", "Push"), ("Fri", "Pull"), ("Sat", "Legs"), ("Sun", nil)
            ]
        }
    }

    // MARK: - Template Creation

    private func createTemplates(for preset: PresetSplit) -> [String: WorkoutTemplate] {
        var templates: [String: WorkoutTemplate] = [:]

        func make(_ name: String, _ category: TemplateCategory, _ ids: [UUID]) -> WorkoutTemplate {
            let t = WorkoutTemplate(name: name, category: category, isBuiltIn: false)
            t.exerciseIDs = ids
            t.user = user
            modelContext.insert(t)
            return t
        }

        func ids(_ group: MuscleGroup, _ count: Int) -> [UUID] {
            exercises.filter { $0.muscleGroup == group }.prefix(count).map { $0.id }
        }

        switch preset {
        case .threeDay:
            templates["Full Body"] = make("Full Body", .fullBody,
                ids(.back, 2) + ids(.chest, 2) + ids(.legs, 2) + ids(.shoulders, 1) + ids(.biceps, 1))

        case .fourDay:
            templates["Upper"] = make("Upper", .upper,
                ids(.chest, 2) + ids(.back, 2) + ids(.shoulders, 2) + ids(.biceps, 1) + ids(.triceps, 1))
            templates["Lower"] = make("Lower", .lower,
                ids(.legs, 6))

        case .fiveDay:
            templates["Chest & Triceps"] = make("Chest & Triceps", .chestTriceps,
                ids(.chest, 5) + ids(.triceps, 3))
            templates["Back & Biceps"] = make("Back & Biceps", .backBiceps,
                ids(.back, 5) + ids(.biceps, 3))
            templates["Shoulders"] = make("Shoulders", .shoulders,
                ids(.shoulders, 6))
            templates["Legs"] = make("Legs", .legs,
                ids(.legs, 6))
            templates["Full Body"] = make("Full Body", .fullBody,
                ids(.back, 2) + ids(.chest, 2) + ids(.legs, 2) + ids(.shoulders, 1) + ids(.biceps, 1))

        case .sixDay:
            templates["Push"] = make("Push", .push,
                ids(.chest, 4) + ids(.shoulders, 2) + ids(.triceps, 2))
            templates["Pull"] = make("Pull", .pull,
                ids(.back, 4) + ids(.biceps, 2))
            templates["Legs"] = make("Legs", .legs,
                ids(.legs, 6))
        }

        return templates
    }

    // MARK: - Plan Creation

    private func createPlans(for preset: PresetSplit, templates: [String: WorkoutTemplate]) {
        let schedule = scheduleFor(preset)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else { return }

        for (dayOffset, entry) in schedule.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: monday)
            else { continue }

            // Only create plans for today and future days — past days would immediately
            // show as "incomplete/missed" even though the user hadn't started yet.
            guard date >= today else { continue }

            if let templateName = entry.templateName, let template = templates[templateName] {
                let plan = WorkoutPlan(date: date, user: user, template: template)
                modelContext.insert(plan)
            } else {
                let plan = WorkoutPlan(date: date, user: user, isRestDay: true)
                modelContext.insert(plan)
            }
        }
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: PresetSplit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(preset.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .fill(preset.accentColor)
                            .frame(width: 16, height: 16)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.headline)
                        .foregroundStyle(Color.groveCharcoal)
                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.groveWarmSand.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: User.self, Exercise.self, WorkoutTemplate.self, WorkoutPlan.self,
        configurations: config
    )
    let user = User(appleUserID: "preview")
    container.mainContext.insert(user)

    return WeeklyPlanSetupView(user: user, onContinue: {})
        .modelContainer(container)
}
