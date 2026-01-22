import SwiftUI
import SwiftData

struct QuickStartSection: View {
    @Query(sort: \WorkoutTemplate.usageCount, order: .reverse)
    private var templates: [WorkoutTemplate]

    private var suggestedTemplates: [WorkoutTemplate] {
        // Show up to 5 most used templates, or built-in categories if none
        Array(templates.prefix(5))
    }

    private var defaultCategories: [TemplateCategory] {
        [.push, .pull, .legs, .upper, .fullBody]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
                .foregroundStyle(Color.groveCharcoal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Empty workout button
                    QuickStartButton(
                        title: "Empty",
                        subtitle: "Blank workout",
                        icon: "plus.circle.fill",
                        color: Color.groveWarmSand
                    ) {
                        // TODO: Start empty workout
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
                                // TODO: Start workout with category
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
                                // TODO: Start workout with template
                            }
                        }
                    }
                }
            }
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
                        .foregroundStyle(Color.groveCharcoal)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, alignment: .leading)
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickStartSection()
        .padding()
        .background(Color.groveCream)
        .modelContainer(for: [WorkoutTemplate.self])
}
