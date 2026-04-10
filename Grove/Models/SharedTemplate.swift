import Foundation

struct SharedTemplate: Codable, Identifiable, Sendable {
    var id: UUID

    let name: String
    let category: String           // TemplateCategory.rawValue
    let exerciseNames: [String]    // ordered, matched by name on import
    let defaultSets: Int
    let defaultReps: Int
    let sharedBy: String?          // attribution ("Sarah"), nil for direct shares

    enum CodingKeys: String, CodingKey {
        case name, category, exerciseNames, defaultSets, defaultReps, sharedBy
    }

    init(name: String, category: String, exerciseNames: [String], defaultSets: Int, defaultReps: Int, sharedBy: String?) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.exerciseNames = exerciseNames
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.sharedBy = sharedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.category = try container.decode(String.self, forKey: .category)
        self.exerciseNames = try container.decode([String].self, forKey: .exerciseNames)
        self.defaultSets = try container.decode(Int.self, forKey: .defaultSets)
        self.defaultReps = try container.decode(Int.self, forKey: .defaultReps)
        self.sharedBy = try container.decodeIfPresent(String.self, forKey: .sharedBy)
    }

    // MARK: - URL Encoding / Decoding

    func toURL() -> URL? {
        guard let data = try? JSONEncoder().encode(self),
              let base64 = data.base64EncodedString()
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "grove://template?data=\(base64)")
    }

    static func from(url: URL) -> SharedTemplate? {
        guard url.scheme == "grove", url.host == "template",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base64 = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(SharedTemplate.self, from: data)
    }

    // MARK: - From Feed Item

    static func from(feedItem: SharedWorkoutItem) -> SharedTemplate {
        let exercises = feedItem.parsedExercises
        let category = feedItem.templateCategory ?? inferCategory(from: exercises.map(\.name))
        return SharedTemplate(
            name: feedItem.workoutName,
            category: category,
            exerciseNames: exercises.map(\.name),
            defaultSets: 3,
            defaultReps: 10,
            sharedBy: feedItem.friendName
        )
    }

    // MARK: - Category Inference

    static func inferCategory(from exerciseNames: [String]) -> String {
        let seedLookup = Dictionary(
            ExerciseSeeds.builtInExercises.map { ($0.name.lowercased(), $0.group) },
            uniquingKeysWith: { first, _ in first }
        )

        let groups = exerciseNames.compactMap { seedLookup[$0.lowercased()] }
        guard !groups.isEmpty else { return TemplateCategory.custom.rawValue }

        let groupSet = Set(groups)

        // Match against known category muscle group patterns (order matters — more specific first)
        let patterns: [(TemplateCategory, Set<MuscleGroup>)] = [
            (.legs, [.legs]),
            (.legs, [.legs, .core]),
            (.shoulders, [.shoulders]),
            (.chestTriceps, [.chest, .triceps]),
            (.backBiceps, [.back, .biceps]),
            (.push, [.chest, .shoulders, .triceps]),
            (.pull, [.back, .biceps]),
            (.lower, [.legs, .core]),
            (.upper, [.chest, .back, .shoulders, .biceps, .triceps]),
        ]

        for (category, muscles) in patterns {
            if groupSet.isSubset(of: muscles) {
                return category.rawValue
            }
        }

        return TemplateCategory.custom.rawValue
    }
}
