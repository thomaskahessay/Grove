import SwiftUI

struct CustomSplitConfigStep: View {
    @Bindable var state: SmartBuilderState
    @State private var appeared = false

    /// Muscle groups available for selection (excludes fullBody — users pick individual groups)
    private let selectableGroups: [MuscleGroup] = [
        .chest, .back, .shoulders, .biceps, .triceps, .legs, .core
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    Text("Design your split")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.groveText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Name each day and pick its muscle groups")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                }
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4), value: appeared)

                // Day cards
                ForEach(Array(state.customDayConfigs.indices), id: \.self) { index in
                    dayCard(index: index)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.1 + Double(index) * 0.05), value: appeared)
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear { appeared = true }
    }

    // MARK: - Day Card

    private func dayCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Day header
            Text("DAY \(index + 1)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveTextSecondary)
                .tracking(0.5)

            // Name text field
            TextField("e.g. Chest + Triceps", text: $state.customDayConfigs[index].name)
                .font(.headline)
                .foregroundStyle(Color.groveText)
                .padding(12)
                .background(Color.groveCardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.groveSage.opacity(0.15), lineWidth: 1)
                )

            // Muscle group chips
            FlowLayout(spacing: 8) {
                ForEach(selectableGroups, id: \.self) { group in
                    muscleGroupChip(group: group, dayIndex: index)
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

    // MARK: - Muscle Group Chip

    private func muscleGroupChip(group: MuscleGroup, dayIndex: Int) -> some View {
        let isSelected = state.customDayConfigs[dayIndex].muscleGroups.contains(group)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    state.customDayConfigs[dayIndex].muscleGroups.removeAll { $0 == group }
                } else {
                    state.customDayConfigs[dayIndex].muscleGroups.append(group)
                }
            }
        } label: {
            Text(group.rawValue)
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
                .shadow(
                    color: isSelected ? Color.groveSage.opacity(0.2) : .clear,
                    radius: 4, y: 2
                )
        }
    }
}

// MARK: - Flow Layout

/// Simple flow layout that wraps chips to the next line
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (positions, CGSize(width: totalWidth, height: currentY + lineHeight))
    }
}
