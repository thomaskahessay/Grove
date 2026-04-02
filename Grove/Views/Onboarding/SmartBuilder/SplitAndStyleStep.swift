import SwiftUI

struct SplitAndStyleStep: View {
    @Bindable var state: SmartBuilderState
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 10) {
                    Text("Pick your\ntraining style")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.groveText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("We'll organize your exercises around this split")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4), value: appeared)

                // Split selection
                VStack(spacing: 10) {
                    ForEach(Array(state.availableSplits.enumerated()), id: \.element.id) { index, split in
                        splitCard(split: split, index: index)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                // Rep range section
                VStack(alignment: .leading, spacing: 12) {
                    Text("REP RANGE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveTextSecondary)
                        .tracking(0.5)

                    HStack(spacing: 10) {
                        ForEach(RepRangePreference.allCases, id: \.self) { range in
                            repRangeCard(range: range)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear { appeared = true }
    }

    // MARK: - Split Card

    private func splitCard(split: SplitType, index: Int) -> some View {
        let isSelected = state.selectedSplit == split
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                state.selectedSplit = split
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(split.rawValue)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : Color.groveText)

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.white.opacity(0.4) : Color.groveSage.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                        }
                    }
                }

                // Week preview
                Text(split == .custom
                    ? "You choose the muscle groups for each day"
                    : split.weekPreview(for: state.daysPerWeek))
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.groveTextSecondary)
                    .lineLimit(2)
            }
            .padding(16)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.groveSage, Color.groveSage.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(Color.groveCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.groveSage.opacity(0.12), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? Color.groveSage.opacity(0.2) : .clear,
                radius: 6, y: 3
            )
        }
    }

    // MARK: - Rep Range Card

    private func repRangeCard(range: RepRangePreference) -> some View {
        let isSelected = state.repRange == range
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                state.repRange = range
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: range.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : Color.groveSage)
                    .symbolEffect(.bounce, value: isSelected)

                Text(range.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color.groveText)

                Text(range.subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : Color.groveTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                isSelected
                    ? AnyShapeStyle(Color.groveSage)
                    : AnyShapeStyle(Color.groveCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.groveSage.opacity(0.12), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? Color.groveSage.opacity(0.2) : .clear,
                radius: 6, y: 3
            )
        }
    }
}
