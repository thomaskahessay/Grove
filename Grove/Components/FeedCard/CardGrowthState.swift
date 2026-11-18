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

    /// Growth is measured against how many people could react, not fixed counts: Grove is
    /// a small group, so with two friends "everyone watered" is two waters. `audience` is
    /// the number of other people in the grove (at least 1).
    init(from summary: InteractionSummary?, audience: Int = 2) {
        guard let summary, summary.waterCount + summary.sunlightCount + summary.seeds.count > 0 else {
            self = .empty
            return
        }
        let audience = CGFloat(max(audience, 1))

        // One water / seed / sunlight per person counts; repeats from the same person
        // don't push growth further.
        let waterers = CGFloat(min(summary.waterCount, Int(audience)))
        let seeders = CGFloat(Set(summary.seeds.map(\.senderID)).count)
        let sunlighters = CGFloat(min(summary.sunlightCount, Int(audience)))

        let waterShare = min(waterers / audience, 1)
        let seedShare = min(seeders / audience, 1)
        let sunShare = min(sunlighters / audience, 1)

        // Water: any water wets the soil; everyone watering soaks it and fills the grass.
        soilMoisture = waterers > 0 ? 0.5 + 0.5 * waterShare : 0
        grassDensity = Int((6 * waterShare).rounded())

        // Plant: any water sprouts it (stage 1 with two people); everyone watering grows a
        // young plant (2); seeds grow it toward a full bush (4).
        var stage: CGFloat = max(2 * waterShare, waterers > 0 ? 1 : 0)
        if seeders > 0 { stage = max(stage, 2.5 + 1.5 * seedShare) }

        // Sunlight: flowers; anyone's sunlight gives a half bloom, everyone's a full one.
        bloomProgress = sunlighters > 0 ? 0.5 + 0.5 * sunShare : 0
        // Flowers need branches to grow on.
        if bloomProgress > 0 { stage = max(stage, 3.0) }
        plantStage = min(stage, 4.0)

        // Lushness (warm sky): how much of the group reacted, weighted like root points.
        let weighted = waterShare * 1 + seedShare * 2 + sunShare * 3
        lushness = min(weighted / 4.0, 1.0)
    }
}
