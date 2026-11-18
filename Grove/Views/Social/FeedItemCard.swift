import SwiftUI

struct FeedItemCard: View {
    let item: SharedWorkoutItem
    let interactions: InteractionSummary?
    let showSunlight: Bool
    var isOwnPost: Bool = false
    var onUseTemplate: (() -> Void)? = nil
    @Binding var triggerSeedAnimation: Bool
    let onProfileTap: () -> Void
    let onWater: () -> Void
    let onSeed: () -> Void
    let onSunlight: () -> Void

    @State private var showWaterAnimation = false
    @State private var showSunlightAnimation = false
    @State private var showSeedAnimation = false

    private var exercises: [SharedExercise] { item.parsedExercises }

    /// Exercises shown on the card; the rest are summarized as "+N more" (tap for detail).
    private static let visibleExerciseCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // Workout title + category + PR pill
            HStack(spacing: 6) {
                Text(item.workoutName)
                    .font(.headline)
                    .foregroundStyle(Color.groveText)
                    .lineLimit(1)

                if let category = item.templateCategory,
                   let tc = TemplateCategory(rawValue: category),
                   category != item.workoutName {
                    Label(category, systemImage: tc.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.groveSage)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.groveSage.opacity(0.12))
                        .clipShape(Capsule())
                }

                if item.hasPRs {
                    Label(item.prCount == 1 ? "PR" : "\(item.prCount) PRs", systemImage: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.groveTerracotta)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.groveTerracotta.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // One quiet stats line instead of a boxed grid
            if !statsLine.isEmpty {
                Text(statsLine)
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
            }

            if !exercises.isEmpty {
                exerciseList
            }

            // Who reacted, by name (shown on your own posts too)
            if let reactions = reactionSummary {
                Text(reactions)
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
                    .lineLimit(2)
            }

            // Interaction bar — hidden on own posts
            if !isOwnPost {
                InteractionBar(
                    summary: interactions,
                    showSunlight: showSunlight,
                    onWater: {
                        showWaterAnimation = true
                        onWater()
                    },
                    onSeed: {
                        onSeed()
                    },
                    onSunlight: {
                        showSunlightAnimation = true
                        onSunlight()
                    }
                )
            }
        }
        .padding(14)
        // One accent: the growing scene behind the card reflects water and sunlight.
        // PRs are marked with the pill above rather than a border/glow/shimmer as well.
        .background {
            CardSceneBackgroundView(interactions: interactions, hasPRs: item.hasPRs)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay {
            if showWaterAnimation {
                WaterTapAnimation {
                    showWaterAnimation = false
                }
            }
            if showSunlightAnimation {
                SunlightTapAnimation {
                    showSunlightAnimation = false
                }
            }
            if showSeedAnimation {
                SeedTapAnimation {
                    showSeedAnimation = false
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if let onUseTemplate, !exercises.isEmpty {
                Button("Use as template", systemImage: "doc.badge.plus", action: onUseTemplate)
            }
        }
        .onChange(of: triggerSeedAnimation) { _, shouldAnimate in
            if shouldAnimate {
                showSeedAnimation = true
                // Reset the trigger so it can fire again
                triggerSeedAnimation = false
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Group {
                if isOwnPost {
                    Text("Your workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                } else {
                    HStack(spacing: 8) {
                        avatarView
                        Text(item.friendName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.groveText)
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        onProfileTap()
                    })
                }
            }

            Spacer()

            Text(item.timeAgo)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Side actions live here instead of a full-width button.
            if let onUseTemplate, !exercises.isEmpty {
                Menu {
                    Button("Use as template", systemImage: "doc.badge.plus", action: onUseTemplate)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(Color.groveTextSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityLabel("More actions")
            }
        }
    }

    /// e.g. "5 exercises · 15 sets · 52 min".
    private var statsLine: String {
        var parts: [String] = []
        if item.exerciseCount > 0 { parts.append(item.exerciseCount == 1 ? "1 exercise" : "\(item.exerciseCount) exercises") }
        if item.totalSets > 0 { parts.append(item.totalSets == 1 ? "1 set" : "\(item.totalSets) sets") }
        if item.duration > 0 { parts.append(item.durationText) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Reactions

    /// e.g. "Watered by Sam and Alex · Sunlight from Mika · Jo: “Strong start”".
    private var reactionSummary: String? {
        guard let interactions else { return nil }
        var parts: [String] = []
        let waterers = interactions.waterers.map(\.displayName)
        if !waterers.isEmpty { parts.append("Watered by " + Self.nameList(waterers)) }
        let sunlighters = interactions.sunlighters.map(\.senderName)
        if !sunlighters.isEmpty { parts.append("Sunlight from " + Self.nameList(sunlighters)) }
        if let seed = interactions.seeds.last {
            let extra = interactions.seeds.count > 1 ? " +\(interactions.seeds.count - 1)" : ""
            parts.append("\(Self.firstName(seed.senderName)): “\(seed.message)”\(extra)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Sam", "Sam and Alex", "Sam, Alex and 2 others" — "You" listed first.
    static func nameList(_ names: [String]) -> String {
        var unique: [String] = []
        for name in names.map(firstName) where !unique.contains(name) { unique.append(name) }
        if let i = unique.firstIndex(of: "You") { unique.insert(unique.remove(at: i), at: 0) }
        switch unique.count {
        case 0: return ""
        case 1: return unique[0]
        case 2: return "\(unique[0]) and \(unique[1])"
        case 3: return "\(unique[0]), \(unique[1]) and \(unique[2])"
        default: return "\(unique[0]), \(unique[1]) and \(unique.count - 2) others"
        }
    }

    private static func firstName(_ name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        // PR exercises first so they're never hidden behind "+N more".
        let ordered = exercises.filter(\.isPR) + exercises.filter { !$0.isPR }
        let shown = ordered.prefix(Self.visibleExerciseCount)
        let hiddenCount = ordered.count - shown.count
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, exercise in
                exerciseRow(exercise)
            }
            if hiddenCount > 0 {
                Text("+\(hiddenCount) more")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
                    .padding(.leading, 20)
            }
        }
    }

    private func exerciseRow(_ exercise: SharedExercise) -> some View {
        HStack(spacing: 6) {
            Image(systemName: exercise.isPR ? "star.fill" : "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(exercise.isPR ? Color.groveTerracotta : Color.groveSage)
                .frame(width: 14)

            Text(exercise.name)
                .font(.caption)
                .fontWeight(exercise.isPR ? .semibold : .regular)
                .foregroundStyle(Color.groveText)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let summary = exercise.summary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
                    .fixedSize()
            } else if exercise.setCount > 0 {
                Text("\(exercise.setCount) sets")
                    .font(.caption2)
                    .foregroundStyle(Color.groveTextSecondary)
                    .fixedSize()
            }
        }
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Circle()
            .fill(Color.groveSage.opacity(0.15))
            .frame(width: 32, height: 32)
            .overlay {
                if let data = item.friendProfileImageData,
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials(for: item.friendName))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                }
            }
    }

    private func initials(for name: String) -> String {
        if name.isEmpty { return "G" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

// Animation overlays moved to:
// - Components/FeedCard/WaterTapAnimation.swift
// - Components/FeedCard/SeedTapAnimation.swift
// - Components/FeedCard/SunlightTapAnimation.swift

// MARK: - Previews

#Preview("PR + Watered + Sunlit + Seeds") {
    let items = SocialPreviewData.feedItems
    let interactions = SocialPreviewData.interactionsByWorkout
    ScrollView {
        VStack(spacing: 16) {
            // Sarah's Push Day — PR, watered, sunlit, 3 seeds
            FeedItemCard(
                item: items[0],
                interactions: interactions["workout_1"],
                showSunlight: true,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
            // Alex's Leg Day — 2 PRs, 5 waters, 2 sunlights, 4 seeds
            FeedItemCard(
                item: items[2],
                interactions: interactions["workout_3"],
                showSunlight: false,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
        }
        .padding()
    }
    .background(Color.groveBackground)
}

#Preview("Lightly Interacted") {
    let items = SocialPreviewData.feedItems
    let interactions = SocialPreviewData.interactionsByWorkout
    ScrollView {
        VStack(spacing: 16) {
            // Mike's Pull Day — 2 waters, 1 seed, no sunlight
            FeedItemCard(
                item: items[1],
                interactions: interactions["workout_2"],
                showSunlight: true,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
            // Jordan's Upper Body — 1 water only
            FeedItemCard(
                item: items[3],
                interactions: interactions["workout_4"],
                showSunlight: false,
                triggerSeedAnimation: .constant(false),
                onProfileTap: {},
                onWater: {},
                onSeed: {},
                onSunlight: {}
            )
        }
        .padding()
    }
    .background(Color.groveBackground)
}

#Preview("No Interactions") {
    let items = SocialPreviewData.feedItems
    ScrollView {
        FeedItemCard(
            item: items[5],
            interactions: .empty(for: "workout_6"),
            showSunlight: true,
            triggerSeedAnimation: .constant(false),
            onProfileTap: {},
            onWater: {},
            onSeed: {},
            onSunlight: {}
        )
        .padding()
    }
    .background(Color.groveBackground)
}
