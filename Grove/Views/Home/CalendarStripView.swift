import SwiftUI
import SwiftData

struct CalendarStripView: View {
    @Query private var workoutPlans: [WorkoutPlan]

    @State private var selectedDate: Date = Date()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        // Show 3 days before today, today, and 3 days after
        return (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }

    private func plan(for date: Date) -> WorkoutPlan? {
        workoutPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 8) {
                        ForEach(weekDates, id: \.self) { date in
                            CalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                plan: plan(for: date)
                            )
                            .id(date)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = date
                                }
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to today on appear
                        let today = calendar.startOfDay(for: Date())
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
            }
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
            return nil
        case .rest:
            return "moon.fill"
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
    CalendarStripView()
        .padding()
        .modelContainer(for: [WorkoutPlan.self])
}
