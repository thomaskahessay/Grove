import SwiftUI
import SwiftData

struct CalendarStripView: View {
    @Query private var workoutPlans: [WorkoutPlan]

    @State private var weekOffset: Int = 0
    @State private var selectedDayForPlan: IdentifiableDate?
    @State private var selectedWorkoutForDetail: Workout?
    @State private var showMonthView: Bool = false
    @State private var monthOffset: Int = 0

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

    // MARK: - Month Computed Properties

    private var currentMonthFirstDay: Date {
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: today)
        let firstOfCurrentMonth = calendar.date(from: components)!
        return calendar.date(byAdding: .month, value: monthOffset, to: firstOfCurrentMonth)!
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonthFirstDay)
    }

    // MARK: - Helpers

    private func plan(for date: Date) -> WorkoutPlan? {
        workoutPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: date)
        }
    }

    private func handleDayTap(_ date: Date) {
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

    // MARK: - Sync Methods

    private func syncMonthFromWeek() {
        let midWeek = calendar.date(byAdding: .day, value: 3, to: weekStartDate)!
        let today = calendar.startOfDay(for: Date())
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: today)
        let targetMonthComponents = calendar.dateComponents([.year, .month], from: midWeek)

        let currentFirst = calendar.date(from: currentMonthComponents)!
        let targetFirst = calendar.date(from: targetMonthComponents)!

        monthOffset = calendar.dateComponents([.month], from: currentFirst, to: targetFirst).month ?? 0
    }

    private func syncWeekFromMonth() {
        let today = calendar.startOfDay(for: Date())
        let todayComponents = calendar.dateComponents([.year, .month], from: today)
        let monthComponents = calendar.dateComponents([.year, .month], from: currentMonthFirstDay)

        if todayComponents.year == monthComponents.year && todayComponents.month == monthComponents.month {
            weekOffset = 0
        } else {
            let weekday = calendar.component(.weekday, from: currentMonthFirstDay)
            let daysFromMonday = (weekday + 5) % 7
            let firstMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: currentMonthFirstDay)!

            let todayWeekday = calendar.component(.weekday, from: today)
            let todayDaysFromMonday = (todayWeekday + 5) % 7
            let currentMonday = calendar.date(byAdding: .day, value: -todayDaysFromMonday, to: today)!

            weekOffset = calendar.dateComponents([.weekOfYear], from: currentMonday, to: firstMonday).weekOfYear ?? 0
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Navigator header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if showMonthView {
                            monthOffset -= 1
                        } else {
                            weekOffset -= 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(Color.groveSage)
                }

                Spacer()

                Button {
                    if showMonthView {
                        syncWeekFromMonth()
                    } else {
                        syncMonthFromWeek()
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showMonthView.toggle()
                    }
                } label: {
                    Text(showMonthView ? monthLabel : weekLabel)
                        .font(.headline)
                        .foregroundStyle(Color.groveText)
                        .contentTransition(.numericText())
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if showMonthView {
                            monthOffset += 1
                        } else {
                            weekOffset += 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.groveSage)
                }
            }

            // Calendar content
            if showMonthView {
                MonthCalendarGridView(
                    monthFirstDay: currentMonthFirstDay,
                    plans: workoutPlans,
                    onDayTap: handleDayTap
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width < -30 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    monthOffset += 1
                                }
                            } else if value.translation.width > 30 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    monthOffset -= 1
                                }
                            }
                        }
                )
            } else {
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
                            handleDayTap(date)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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

// MARK: - Month Calendar Grid View

private struct MonthCalendarGridView: View {
    let monthFirstDay: Date
    let plans: [WorkoutPlan]
    let onDayTap: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let dayHeaders = [
        (id: "mon", label: "M"),
        (id: "tue", label: "T"),
        (id: "wed", label: "W"),
        (id: "thu", label: "T"),
        (id: "fri", label: "F"),
        (id: "sat", label: "S"),
        (id: "sun", label: "S")
    ]

    private var gridDates: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: monthFirstDay)!
        let daysInMonth = range.count

        let firstWeekday = calendar.component(.weekday, from: monthFirstDay)
        let leadingEmpty = (firstWeekday + 5) % 7 // days before Monday

        var dates: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthFirstDay) {
                dates.append(date)
            }
        }

        // Pad to complete the last row
        let remainder = dates.count % 7
        if remainder > 0 {
            dates.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return dates
    }

    private func plan(for date: Date) -> WorkoutPlan? {
        plans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: date)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Day-of-week header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(dayHeaders, id: \.id) { day in
                    Text(day.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Date grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(gridDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        MonthDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            plan: plan(for: date)
                        )
                        .onTapGesture {
                            onDayTap(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
        }
    }
}

// MARK: - Month Day Cell

private struct MonthDayCell: View {
    let date: Date
    let isToday: Bool
    let plan: WorkoutPlan?

    private let calendar = Calendar.current

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
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
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(isToday ? Color.groveSage : Color.clear)
                    .frame(width: 30, height: 30)

                Text(dayNumber)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(isToday ? .white : (isPast ? .secondary : Color.groveText))
            }

            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)

                if let icon = statusIcon {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .opacity(plan != nil ? 1 : 0)
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
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
