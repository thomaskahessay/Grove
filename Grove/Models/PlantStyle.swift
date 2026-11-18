import SwiftUI

/// Tree species the renderer can draw. Everyone grows an Oak for now; the others are
/// kept for later customization and the debug plant gallery.
enum PlantSpecies: String, CaseIterable, Codable, Sendable, Identifiable {
    case oak, cherry, pine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oak: "Oak"
        case .cherry: "Cherry"
        case .pine: "Pine"
        }
    }

    var tagline: String {
        switch self {
        case .oak: "Sturdy, with acorns"
        case .cherry: "Covered in blossoms"
        case .pine: "Evergreen, with cones"
        }
    }
}

/// Colour of the plant's buds and flowers.
enum BlossomColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case cream, pink, gold, lilac, coral

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var petal: Color {
        switch self {
        case .cream: Color(red: 0.98, green: 0.95, blue: 0.90)
        case .pink: Color(red: 0.95, green: 0.72, blue: 0.78)
        case .gold: Color(red: 0.96, green: 0.82, blue: 0.43)
        case .lilac: Color(red: 0.74, green: 0.66, blue: 0.89)
        case .coral: Color(red: 0.92, green: 0.55, blue: 0.43)
        }
    }

    var center: Color {
        switch self {
        case .cream: Color(red: 0.91, green: 0.64, blue: 0.50)
        case .pink: Color(red: 0.80, green: 0.40, blue: 0.50)
        case .gold: Color(red: 0.78, green: 0.52, blue: 0.20)
        case .lilac: Color(red: 0.50, green: 0.40, blue: 0.70)
        case .coral: Color(red: 0.98, green: 0.85, blue: 0.55)
        }
    }
}

/// Everything that makes one person's plant look like theirs: a species and blossom
/// (the same for everyone for now) plus a stable seed from their account for small
/// automatic variation in lean, leaf shade and leaf layout, so no two plants match.
struct PlantStyle: Hashable, Sendable {
    var species: PlantSpecies
    var blossom: BlossomColor
    var seed: UInt64

    static let `default` = PlantStyle()

    init(species: PlantSpecies = .oak, blossom: BlossomColor = .cream, seed: UInt64 = 0) {
        self.species = species
        self.blossom = blossom
        self.seed = seed
    }

    /// The style for a person, from their Apple user ID (stable across devices, and
    /// already on every friend profile, so nothing extra needs syncing).
    init(identity: String?) {
        self.init(seed: identity.map(Self.stableHash) ?? 0)
    }

    /// FNV-1a: stable across launches and devices, unlike `hashValue`.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
