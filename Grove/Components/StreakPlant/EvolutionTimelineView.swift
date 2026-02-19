import SwiftUI

struct EvolutionTimelineView: View {
    let currentStage: PlantStage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(PlantStage.allCases, id: \.rawValue) { stage in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(stage <= currentStage ? Color.groveSage : Color.groveWarmSand.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: iconFor(stage))
                                    .font(.system(size: 14))
                                    .foregroundStyle(stage <= currentStage ? .white : .secondary)
                            }

                        Text(stage.displayName)
                            .font(.caption2)
                            .foregroundStyle(stage <= currentStage ? Color.groveText : .secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }

                    if stage != PlantStage.allCases.last {
                        Rectangle()
                            .fill(stage < currentStage ? Color.groveSage : Color.groveWarmSand.opacity(0.3))
                            .frame(width: 20, height: 2)
                            .offset(y: -12)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func iconFor(_ stage: PlantStage) -> String {
        switch stage {
        case .seed: return "circle.fill"
        case .sprout: return "leaf"
        case .seedling: return "leaf.fill"
        case .youngPlant: return "tree"
        case .tree: return "tree.fill"
        }
    }
}

#Preview {
    EvolutionTimelineView(currentStage: .seedling)
}
