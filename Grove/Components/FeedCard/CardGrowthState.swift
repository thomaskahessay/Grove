import Foundation
import SwiftUI

/// Maps social interaction counts to visual parameters for the evolving card background scene.
struct CardGrowthState: Equatable {
    /// 0.0 (dry sand) to 1.0 (rich dark soil) — driven by water count
    let soilMoisture: CGFloat
    /// 0 to 6 grass tufts — driven by water count
    let grassDensity: Int
    /// 0.0 (nothing) to 4.0 (full bush) — driven by seed count
    let plantStage: CGFloat
    /// 0.0 (no flowers) to 1.0 (full bloom) — driven by sunlight count
    let bloomProgress: CGFloat
    /// 0.0 to 1.0 overall vibrancy multiplier — combined score
    let lushness: CGFloat

    /// Whether the scene has any visible growth beyond bare soil
    var hasGrowth: Bool {
        soilMoisture > 0 || plantStage > 0 || bloomProgress > 0
    }

    /// Bare scene — no interactions at all
    static let empty = CardGrowthState(
        soilMoisture: 0, grassDensity: 0,
        plantStage: 0, bloomProgress: 0, lushness: 0
    )

    init(soilMoisture: CGFloat, grassDensity: Int, plantStage: CGFloat, bloomProgress: CGFloat, lushness: CGFloat) {
        self.soilMoisture = soilMoisture
        self.grassDensity = grassDensity
        self.plantStage = plantStage
        self.bloomProgress = bloomProgress
        self.lushness = lushness
    }

    init(from summary: InteractionSummary?) {
        guard let summary else {
            self = .empty
            return
        }

        let water = summary.waterCount
        // Use unique senders for plant growth — one person spamming seeds
        // shouldn't max out the plant; it should reflect community engagement
        let uniqueSeedSenders = Set(summary.seeds.map(\.senderID))
        let seeds = uniqueSeedSenders.count
        let sunlight = summary.sunlightCount

        // Water → soil moisture + grass
        soilMoisture = min(CGFloat(water) * 0.25, 1.0)
        grassDensity = min(water, 6)

        // Seeds → plant growth stage (continuous)
        var seedPlantStage: CGFloat
        switch seeds {
        case 0: seedPlantStage = 0
        case 1: seedPlantStage = 1.0
        case 2: seedPlantStage = 2.0
        case 3: seedPlantStage = 2.5
        case 4: seedPlantStage = 3.0
        case 5: seedPlantStage = 3.3
        case 6: seedPlantStage = 3.5
        default: seedPlantStage = 4.0
        }

        // Sunlight → bloom progress
        switch sunlight {
        case 0: bloomProgress = 0
        case 1: bloomProgress = 0.5
        default: bloomProgress = 1.0
        }

        // Sunlight guarantees a minimum bush so flowers have branches to grow on
        if bloomProgress > 0 && seedPlantStage < 3.0 {
            plantStage = 3.0
        } else {
            plantStage = seedPlantStage
        }

        // Combined lushness
        let rawScore = water + seeds * 2 + sunlight * 3
        let totalScore = CGFloat(rawScore)
        lushness = min(totalScore / 20.0, 1.0)
    }
}
