import SwiftUI

struct EvolutionTimelineView: View {
    let currentStage: PlantStage
    var onStageTapped: ((PlantStage) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PlantStage.allCases, id: \.rawValue) { stage in
                    VStack(spacing: 5) {
                        Circle()
                            .fill(stage <= currentStage ? Color.groveSage : Color.groveWarmSand.opacity(0.4))
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: iconFor(stage))
                                    .font(.system(size: 12))
                                    .foregroundStyle(stage <= currentStage ? .white : .secondary)
                            }

                        Text(stage.displayName)
                            .font(.caption2)
                            .foregroundStyle(stage <= currentStage ? Color.groveText : .secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .onTapGesture {
                        onStageTapped?(stage)
                    }

                    if stage != PlantStage.allCases.last {
                        Rectangle()
                            .fill(stage < currentStage ? Color.groveSage : Color.groveWarmSand.opacity(0.3))
                            .frame(width: 14, height: 2)
                            .offset(y: -10)
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
        case .youngPlant: return "camera.macro"
        case .bush: return "tree"
        case .floweringBush: return "tree.fill"
        case .sapling: return "laurel.leading"
        case .youngTree: return "tree.circle"
        case .tree: return "tree.circle.fill"
        case .groveTree: return "sparkles"
        }
    }
}

#Preview {
    EvolutionTimelineView(currentStage: .sapling)
}
