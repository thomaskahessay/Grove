import SwiftUI

/// Own-routine path: what each training day is called. Prefilled with the usual split
/// for their day count, so most people only tap Continue or a chip or two.
struct DayNamesStep: View {
    @Bindable var state: SmartBuilderState
    @State private var appeared = false

    private static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("Name your days")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.groveText)

                    Text(state.selectedSplit == .custom
                         ? "Type a name or pick one"
                         : "Filled in from \(state.selectedSplit.rawValue). Rename any day")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4), value: appeared)

                ForEach(Array(state.customDayConfigs.indices), id: \.self) { index in
                    dayCard(index: index)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.05 + Double(index) * 0.05), value: appeared)
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { appeared = true }
    }

    private func weekdayLabel(for index: Int) -> String? {
        guard index < state.trainingDaySlots.count else { return nil }
        let slot = state.trainingDaySlots[index]
        return slot < Self.weekdayNames.count ? Self.weekdayNames[slot] : nil
    }

    private func dayCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("DAY \(index + 1)")
                if let weekday = weekdayLabel(for: index) {
                    Text("·")
                    Text(weekday.uppercased())
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.groveTextSecondary)
            .tracking(0.5)

            TextField("e.g. Chest & Triceps", text: $state.customDayConfigs[index].name)
                .font(.headline)
                .foregroundStyle(Color.groveText)
                .submitLabel(.done)
                .padding(12)
                .background(Color.groveCardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
                )

            FlowLayout(spacing: 8) {
                ForEach(SmartBuilderState.dayNameSuggestions, id: \.self) { name in
                    nameChip(name, dayIndex: index)
                }
            }
        }
        .padding(16)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.groveSage.opacity(0.12), lineWidth: 1)
        )
    }

    private func nameChip(_ name: String, dayIndex: Int) -> some View {
        let current = SmartBuilderState.baseName(state.customDayConfigs[dayIndex].name)
        let isSelected = current.caseInsensitiveCompare(name) == .orderedSame
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                state.customDayConfigs[dayIndex].name = name
                state.disambiguateDayNames()
            }
        } label: {
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : Color.groveText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.groveSage : Color.groveCardBackground.opacity(0.5))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.groveSage.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
