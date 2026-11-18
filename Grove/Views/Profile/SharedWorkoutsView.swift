import SwiftUI

/// One of your shared workouts as a tile: its garden scene (a planted seed until someone
/// interacts), the workout type in the corner, then name, date and size.
struct SharedWorkoutTile: View {
    let item: SharedWorkoutItem
    let interactions: InteractionSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSceneBackgroundView(
                interactions: interactions,
                hasPRs: item.hasPRs,
                showsSeedWhenEmpty: true
            )
            .frame(height: 120)
            .overlay(alignment: .topLeading) {
                Image(systemName: categoryIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.groveSage)
                    .frame(width: 26, height: 26)
                    .background(Color.groveSage.opacity(0.15), in: Circle())
                    .padding(8)
                    .accessibilityHidden(true)
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 12
            ))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.workoutName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)
                    .lineLimit(1)

                Text(item.completedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 8))
                        Text("\(item.exerciseCount)")
                            .font(.system(size: 10))
                    }

                    Text("\u{00B7}")
                        .font(.system(size: 10))

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8))
                        Text("\(item.totalSets)")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryIcon: String {
        item.templateCategory.flatMap(TemplateCategory.init(rawValue:))?.icon ?? "dumbbell.fill"
    }
}

/// Every workout you've shared, newest first (the profile shows only the latest few).
struct AllSharedWorkoutsView: View {
    @Environment(CloudKitSocialService.self) private var socialService
    @State private var selected: SharedWorkoutItem?
    @State private var isLoading = true

    /// How many posts this page loads. Far more than a few friends post in a year.
    static let fetchLimit = 200

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if socialService.mySharedWorkouts.isEmpty && !isLoading {
                Text("Workouts you share show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(socialService.mySharedWorkouts) { item in
                        Button {
                            selected = item
                        } label: {
                            SharedWorkoutTile(
                                item: item,
                                interactions: socialService.interactionsByWorkout[item.id]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.groveBackground.ignoresSafeArea())
        .navigationTitle("Shared Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && socialService.mySharedWorkouts.isEmpty {
                SwiftUI.ProgressView()
            }
        }
        .task {
            await socialService.fetchMySharedWorkouts(limit: Self.fetchLimit)
            isLoading = false
        }
        .navigationDestination(item: $selected) { item in
            WorkoutInteractionDetailView(item: item)
        }
    }
}

/// A plain two-column grid of shared workouts (a friend's "See all" page).
struct SharedWorkoutsGridView: View {
    let title: String
    let items: [SharedWorkoutItem]

    @Environment(CloudKitSocialService.self) private var socialService
    @State private var selected: SharedWorkoutItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    Button {
                        selected = item
                    } label: {
                        SharedWorkoutTile(
                            item: item,
                            interactions: socialService.interactionsByWorkout[item.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.groveBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selected) { item in
            WorkoutInteractionDetailView(item: item)
        }
    }
}
