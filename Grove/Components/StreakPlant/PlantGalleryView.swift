import SwiftUI

#if DEBUG
/// Debug-only review screen: every stage for every species, plus wilted and small sizes.
/// Launch with `-GrovePlantGallery`.
struct PlantGalleryView: View {
    // Launch arguments (e.g. `-GrovePlantGallery cherry pink wilted`) preselect the controls.
    @State private var species: PlantSpecies = ProcessInfo.processInfo.arguments.compactMap(PlantSpecies.init(rawValue:)).first ?? .oak
    @State private var blossom: BlossomColor = ProcessInfo.processInfo.arguments.compactMap(BlossomColor.init(rawValue:)).first ?? .cream
    @State private var wilted = ProcessInfo.processInfo.arguments.contains("wilted")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Species", selection: $species) {
                    ForEach(PlantSpecies.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    ForEach(BlossomColor.allCases) { color in
                        Circle().fill(color.petal).frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.primary, lineWidth: blossom == color ? 2 : 0))
                            .onTapGesture { blossom = color }
                    }
                    Spacer()
                    Toggle("Wilted", isOn: $wilted).fixedSize()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(PlantStage.allCases, id: \.self) { stage in
                        VStack(spacing: 2) {
                            StreakPlantView(streak: wilted ? 0 : stage.minStreak, isWilted: wilted, wiltedAtStage: stage,
                                            style: PlantStyle(species: species, blossom: blossom, seed: 2), size: 170, showLabel: false)
                            Text(stage.displayName).font(.caption2)
                        }
                    }
                }
                Text("Small sizes (feed grove strip)").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(PlantStage.allCases, id: \.self) { stage in
                        StreakPlantView(streak: stage.minStreak, style: PlantStyle(species: species, blossom: blossom, seed: 2), size: 36, showLabel: false)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 50)
        }
        .background(Color.groveBackground)
    }
}
#endif
