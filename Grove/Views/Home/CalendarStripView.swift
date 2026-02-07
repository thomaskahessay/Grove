import SwiftUI
import SwiftData

struct CalendarStripView: View {
    @Query private var workoutPlans: [WorkoutPlan]

    @State private var weekOffset: Int = 0
    @State private var selectedDayForPlan: IdentifiableDate?
    @State private var selectedWorkoutForDetail: Workout?

    private let calendar = Calendar.current

    private var weekStartDate: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
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
        workoutPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Week navigator
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

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let isCurrentWeek = weekOffset == 0
                    CalendarDayCell(
                        date: date,
                        isSelected: isCurrentWeek && calendar.isDateInToday(date),
                        isToday: isCurrentWeek && calendar.isDateInToday(date),
                        plan: plan(for: date)
                    )
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        let dayPlan = plan(for: date)
                        let isPast = date < calendar.startOfDay(for: Date())

                        if isPast {
                            if let completedWorkout = dayPlan?.completedWorkout {
                                selectedWorkoutForDetail = completedWorkout
                            }
                        } else {
                            guard dayPlan?.status != .completed else { return }
                            selectedDayForPlan = IdentifiableDate(date: date)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width < -30 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                weekOffset += 1
                            }
                        } else if value.translation.width > 30 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                weekOffset -= 1
                            }
                        }
                    }
            )
        }
        .sheet(item: $selectedDayForPlan) { identifiableDate in
            DayPlanSheet(
                date: identifiableDate.date,
                existingPlan: plan(for: identifiableDate.date)
            )
        }
        .navigationDestination(item: $selectedWorkoutForDetail) { workout in
            WorkoutDetailView(workout: workout)
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let plan: WorkoutPlan?

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var isPast: Bool {
        date < calendar.startOfDay(for: Date())
    }

    private var statusColor: Color {
        guard let plan = plan else {
            return .clear
        }

        if plan.isRestDay {
            return Color.groveWarmSand
        }

        switch plan.status {
        case .completed:
            return Color.groveSage
        case .incomplete:
            return Color.groveMutedRust
        case .planned:
            return Color.groveTerracotta.opacity(0.6)
        case .rest:
            return Color.groveWarmSand
        }
    }

    private var statusIcon: String? {
        guard let plan = plan else { return nil }

        if plan.isRestDay {
            return "moon.fill"
        }

        switch plan.status {
        case .completed:
            return "checkmark"
        case .incomplete:
            return "exclamationmark"
        case .planned:
            return categoryIconName(for: plan.template?.category) ?? "dumbbell.fill"
        case .rest:
            return "moon.fill"
        }
    }

    private func categoryIconName(for category: TemplateCategory?) -> String? {
        guard let category else { return nil }
        switch category {
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .legs: return "figure.run"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.walk"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "slider.horizontal.3"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isToday ? Color.groveSage : .secondary)

            ZStack {
                Circle()
                    .fill(isSelected ? Color.groveSage : Color.clear)
                    .frame(width: 40, height: 40)

                Text(dayNumber)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(isSelected ? .white : (isPast ? .secondary : Color.groveText))
            }

            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 20, height: 20)

                if let icon = statusIcon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .opacity(plan != nil ? 1 : 0)
        }
        .frame(width: 48)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.groveSage.opacity(0.1) : Color.clear)
        )
    }
}

#Preview {
    NavigationStack {
        CalendarStripView()
            .padding()
    }
    .modelContainer(for: [WorkoutPlan.self, WorkoutTemplate.self], inMemory: true)
}
