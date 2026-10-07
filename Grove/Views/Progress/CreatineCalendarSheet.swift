import SwiftUI
import SwiftData

struct CreatineCalendarSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var creatineLogs: [CreatineLog]

    let user: User

    @State private var displayedMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    )!

    private let calendar = Calendar.current
    private let daySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var logDates: Set<Date> {
        Set(creatineLogs.map { calendar.startOfDay(for: $0.date) })
    }

    // MARK: - Month Info

    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayedMonth)!.count
    }

    private var firstWeekday: Int {
        // 0-indexed offset: how many blank cells before day 1
        let weekday = calendar.component(.weekday, from: displayedMonth)
        return weekday - calendar.firstWeekday
    }

    private var loggedCountThisMonth: Int {
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
        return creatineLogs.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= displayedMonth && d < endOfMonth
        }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                monthHeader
                weekdayHeader
                calendarGrid
                Spacer()
            }
            .padding()
            .background(Color.groveBackground.ignoresSafeArea())
            .navigationTitle("Creatine History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.groveSage)
                }
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.groveSage)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(monthName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.groveText)
                Text("\(loggedCountThisMonth)/\(daysInMonth) days")
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
            }

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canGoForward ? Color.groveSage : Color.groveSage.opacity(0.3))
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.groveTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            // Leading blank cells
            ForEach((0..<max(firstWeekday, 0)).map { "blank-\($0)" }, id: \.self) { _ in
                Color.clear.frame(height: 40)
            }

            // Day cells
            ForEach(1...daysInMonth, id: \.self) { day in
                let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)!
                let isLogged = logDates.contains(date)
                let isFuture = date > today

                Button {
                    toggleLog(for: date)
                } label: {
                    Text("\(day)")
                        .font(.callout.weight(isLogged ? .semibold : .regular))
                        .foregroundStyle(dayTextColor(isLogged: isLogged, isFuture: isFuture))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(isLogged ? Color.groveSage : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(date == today ? Color.groveSage.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                }
                .disabled(isFuture)
            }
        }
    }

    // MARK: - Helpers

    private func dayTextColor(isLogged: Bool, isFuture: Bool) -> Color {
        if isFuture { return Color.groveTextSecondary.opacity(0.4) }
        if isLogged { return .white }
        return Color.groveText
    }

    private var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        return nextMonth <= currentMonth
    }

    private func shiftMonth(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth)!
        }
    }

    private func toggleLog(for date: Date) {
        let normalized = calendar.startOfDay(for: date)
        if let existing = creatineLogs.first(where: { calendar.startOfDay(for: $0.date) == normalized }) {
            modelContext.delete(existing)
        } else {
            let log = CreatineLog(date: normalized)
            log.user = user
            modelContext.insert(log)
        }
    }
}
