import SwiftUI
import SwiftData

// Wrapper to use with .sheet(item:) for reliable category passing
struct WorkoutCreationConfig: Identifiable {
    let id = UUID()
    let category: TemplateCategory?
}

struct QuickStartSection: View {
    @Query(sort: \WorkoutTemplate.usageCount, order: .reverse)
    private var templates: [WorkoutTemplate]

    @State private var workoutConfig: WorkoutCreationConfig?

    private var suggestedTemplates: [WorkoutTemplate] {
        // Show up to 5 most used templates, or built-in categories if none
        Array(templates.prefix(5))
    }

    private var defaultCategories: [TemplateCategory] {
        [.push, .pull, .legs, .chestTriceps, .backBiceps, .shoulders]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
                .foregroundStyle(Color.groveText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Empty workout button
                    QuickStartButton(
                        title: "Empty",
                        subtitle: "Blank workout",
                        icon: "plus.circle.fill",
                        color: Color.groveWarmSand
                    ) {
                        workoutConfig = WorkoutCreationConfig(category: nil)
                    }

                    if suggestedTemplates.isEmpty {
                        // Show default category buttons if no templates
                        ForEach(defaultCategories, id: \.self) { category in
                            QuickStartButton(
                                title: category.rawValue,
                                subtitle: "Quick start",
                                icon: iconName(for: category),
                                color: Color.groveSage
                            ) {
                                workoutConfig = WorkoutCreationConfig(category: category)
                            }
                        }
                    } else {
                        // Show user's templates
                        ForEach(suggestedTemplates) { template in
                            QuickStartButton(
                                title: template.name,
                                subtitle: "\(template.exerciseIDs.count) exercises",
                                icon: iconName(for: template.category),
                                color: Color.groveSage
                            ) {
                                workoutConfig = WorkoutCreationConfig(category: template.category)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $workoutConfig) { config in
            WorkoutCreationView(initialCategory: config.category)
        }
    }

    private func iconName(for category: TemplateCategory) -> String {
        switch category {
        case .push: return "arrow.up.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .legs: return "figure.walk.circle.fill"
        case .upper: return "figure.arms.open"
        case .lower: return "figure.run.circle.fill"
        case .fullBody: return "figure.mixed.cardio"
        case .chestTriceps: return "arrowtriangle.down.fill"
        case .backBiceps: return "dumbbell.fill"
        case .shoulders: return "figure.boxing"
        case .custom: return "star.circle.fill"
        }
    }
}

// MARK: - Quick Start Button

struct QuickStartButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 100, height: 90, alignment: .topLeading)
            .padding(12)
            .background(Color.groveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickStartSection()
        .padding()
        .background(Color.groveBackground)
        .modelContainer(for: [WorkoutTemplate.self])
}
