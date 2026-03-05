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
        case .threeDay: return "Mon / Wed / Fri"
        case .fourDay: return "Mon / Tue / Thu / Fri"
        case .fiveDay: return "Mon - Fri"
        case .sixDay: return "Mon - Sat"
        }
    }

    var detailLine: String {
        switch self {
        case .threeDay: return "Rest days in between"
        case .fourDay: return "Upper/Lower alternating"
        case .fiveDay: return "Each muscle group once"
        case .sixDay: return "Maximum volume split"
        }
    }

    var icon: String {
        switch self {
        case .threeDay: return "figure.walk"
        case .fourDay: return "figure.strengthtraining.traditional"
        case .fiveDay: return "figure.highintensity.intervaltraining"
        case .sixDay: return "flame.fill"
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

    var dayCount: Int {
        switch self {
        case .threeDay: return 3
        case .fourDay: return 4
        case .fiveDay: return 5
        case .sixDay: return 6
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
    @State private var appeared = false
    @State private var previewAppeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.groveBackground, Color.groveWarmSand.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Plan Your Week")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.groveText)
                    Text("Choose a training schedule to get started")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 56) // Extra top padding for progress bar
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4), value: appeared)

                VStack(spacing: 12) {
                    ForEach(Array(PresetSplit.allCases.enumerated()), id: \.element.title) { index, preset in
                        PresetCard(preset: preset) {
                            selectedPreset = preset
                            previewAppeared = false
                            withAnimation(.easeInOut(duration: 0.35)) {
                                phase = .preview
                            }
                            // Trigger staggered animation after transition
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                previewAppeared = true
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(0.1 + Double(index) * 0.06), value: appeared)
                    }
                }

                Button("Skip for now") {
                    onContinue()
                }
                .font(.subheadline)
                .foregroundStyle(Color.groveTextSecondary)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            appeared = true
        }
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Here's Your Week")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.groveText)
                        if let preset = selectedPreset {
                            Text(preset.title)
                                .font(.subheadline)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                    }
                    .padding(.top, 56)
                    .opacity(previewAppeared ? 1 : 0)
                    .offset(y: previewAppeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4), value: previewAppeared)

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
                            HStack(spacing: 8) {
                                Text("Confirm")
                                    .font(.headline)
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                        }
                    }
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
                .disabled(isApplying)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        phase = .selection
                    }
                } label: {
                    Text("Choose Different")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
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
                        .foregroundStyle(Color.groveText)
                        .frame(width: 40, alignment: .leading)

                    Spacer()

                    if let name = entry.templateName {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(preset.accentColor)
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.groveText)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.groveTextSecondary.opacity(0.6))
                            Text("Rest")
                                .font(.subheadline)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(index % 2 == 0 ? Color.groveCardBackground.opacity(0.6) : Color.clear)
                .opacity(previewAppeared ? 1 : 0)
                .offset(x: previewAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.3).delay(0.1 + Double(index) * 0.05), value: previewAppeared)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
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
            HStack(spacing: 14) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(preset.accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: preset.icon)
                        .font(.title3)
                        .foregroundStyle(preset.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)

                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary)

                    Text(preset.detailLine)
                        .font(.caption)
                        .foregroundStyle(Color.groveTextSecondary.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.groveTextSecondary.opacity(0.5))
            }
            .padding(16)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.groveSage.opacity(0.1), lineWidth: 1)
            )
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
