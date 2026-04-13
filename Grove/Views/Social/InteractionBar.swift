import SwiftUI

struct InteractionBar: View {
    let summary: InteractionSummary?
    let showSunlight: Bool
    let onWater: () -> Void
    let onSeed: () -> Void
    let onSunlight: () -> Void

    /// When true, shows counters inline (used in detail view action bar).
    /// When false, hides counters to keep the feed card clean.
    var showCounts: Bool = false

    private var waterCount: Int { summary?.waterCount ?? 0 }
    private var seedCount: Int { summary?.seeds.count ?? 0 }
    private var sunlightCount: Int { summary?.sunlightCount ?? 0 }
    private var iWatered: Bool { summary?.iWatered ?? false }
    private var iSunlit: Bool { summary?.iSunlit ?? false }

    var body: some View {
        VStack(spacing: 8) {
            // Interaction counts (only in detail view mode)
            if showCounts && (waterCount > 0 || seedCount > 0 || sunlightCount > 0) {
                HStack(spacing: 12) {
                    if waterCount > 0 {
                        interactionCount(icon: "drop.fill", count: waterCount, color: .blue)
                    }
                    if sunlightCount > 0 {
                        interactionCount(icon: "sun.max.fill", count: sunlightCount, color: .orange)
                    }
                    if seedCount > 0 {
                        interactionCount(icon: "leaf.fill", count: seedCount, color: .groveSage)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }

            // Action buttons — only show actions the user hasn't taken yet
            HStack(spacing: 0) {
                // Water button — hidden if already watered
                if !iWatered {
                    Button {
                        onWater()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "drop")
                                .font(.caption)
                                .foregroundStyle(Color.groveTextSecondary)
                            Text("Water")
                                .font(.caption)
                                .foregroundStyle(Color.groveTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                }

                // Seed button — always available (can send multiple seeds)
                Button {
                    onSeed()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf")
                            .font(.caption)
                            .foregroundStyle(Color.groveTextSecondary)
                        Text("Seed")
                            .font(.caption)
                            .foregroundStyle(Color.groveTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }

                // Sunlight button — hidden if already sunlit or unavailable
                if showSunlight && !iSunlit {
                    Button {
                        onSunlight()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Sunlight")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func interactionCount(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.7))
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.groveTextSecondary)
        }
    }
}
