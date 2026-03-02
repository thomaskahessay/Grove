import SwiftUI
import SwiftData

struct WeeklyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlans: [WorkoutPlan]

    @State private var weekOffset: Int = 0
    @State private var selectedDay: IdentifiableDate?

    private let calendar = Calendar.current

    private var weekStartDate: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Start on Monday (weekday 2). Adjust if Sunday-start locale.
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStartDate)
        }
    }

    private var weekLabel: String {
        if weekOffset == 0 {
            return "This Week"
        } else if weekOffset == 1 {
            return "Next Week"
        } else if weekOffset == -1 {
            return "Last Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let start = weekDates.first ?? Date()
            let end = weekDates.last ?? Date()
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
    }

    private func plan(for date: Date) -> WorkoutPlan? {
        allPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: date)
        }
    }

    private var summaryText: String {
        let plans = weekDates.compactMap { plan(for: $0) }
        let workoutCount = plans.filter { !$0.isRestDay }.count
        let restCount = plans.filter { $0.isRestDay }.count
        let unplanned = 7 - plans.count
        return "\(workoutCount) workouts, \(restCount) rest days, \(unplanned) unplanned"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week navigator
                weekNavigator
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Summary
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                Divider()

                // Day list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(weekDates, id: \.self) { date in
                            WeekDayRow(
                                date: date,
                                plan: plan(for: date),
                                isToday: calendar.isDateInToday(date)
                            )
                            .onTapGesture {
                                let isPast = date < calendar.startOfDay(for: Date())
                                guard !isPast else { return }
                                guard plan(for: date)?.status != .completed else { return }
                                selectedDay = IdentifiableDate(date: date)
                            }

                            if date != weekDates.last {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 40)
                }
            }
            .background(Color.groveBackground)
            .navigationTitle("Plan My Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedDay) { identifiableDate in
                DayPlanSheet(
                    date: identifiableDate.date,
                    existingPlan: plan(for: identifiableDate.date)
                )
            }
        }
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    weekOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Color.groveSage)
            }

            Spacer()

            Text(weekLabel)
                .font(.headline)
                .foregroundStyle(Color.groveText)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    weekOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Color.groveSage)
            }
        }
    }
}

// MARK: - Week Day Row

struct WeekDayRow: View {
    let date: Date
    let plan: WorkoutPlan?
    let isToday: Bool

    private let calendar = Calendar.current

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private var isPast: Bool {
        date < calendar.startOfDay(for: Date())
    }

    private var planDescription: String {
        guard let plan = plan else {
            return isPast ? "No plan" : "Tap to plan"
        }
        if plan.isRestDay {
            return "Rest Day"
        }
        if let template = plan.template {
            return template.name
        }
        return "Planned"
    }

    private var statusIcon: String? {
        guard let plan = plan else { return nil }
        if plan.status == .completed { return "checkmark.circle.fill" }
        guard isPast else { return nil }
        switch plan.status {
        case .incomplete: return "exclamationmark.circle.fill"
        case .rest: return "moon.fill"
        default: return nil
        }
    }

    private var statusColor: Color {
        guard let plan = plan else { return .clear }
        switch plan.status {
        case .completed: return Color.groveSage
        case .incomplete: return Color.groveMutedRust
        case .rest: return Color.groveWarmSand
        case .planned: return Color.groveTerracotta.opacity(0.6)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Day info
            VStack(spacing: 2) {
                Text(dayName.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isToday ? Color.groveSage : .secondary)

                Text(dayNumber)
                    .font(.title3)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(isToday ? Color.groveSage : Color.groveText)
            }
            .frame(width: 44)

            // Today badge
            if isToday {
                Text("Today")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.groveSage)
                    .clipShape(Capsule())
            }

            // Plan description
            VStack(alignment: .leading, spacing: 2) {
                Text(planDescription)
                    .font(.body)
                    .fontWeight(plan != nil ? .medium : .regular)
                    .foregroundStyle(plan != nil ? Color.groveText : .secondary)

                if let plan = plan, plan.isRestDay {
                    Text("Recovery day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status icon for past days
            if let icon = statusIcon {
                Image(systemName: icon)
                    .foregroundStyle(statusColor)
                    .font(.body)
            }

            if plan?.status != .completed && !isPast {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isPast && !isToday ? 0.7 : 1.0)
        .contentShape(Rectangle())
    }
}

// MARK: - Identifiable Date Wrapper

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

#Preview {
    WeeklyPlanView()
        .modelContainer(for: [WorkoutPlan.self, WorkoutTemplate.self], inMemory: true)
}
