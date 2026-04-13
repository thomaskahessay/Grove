import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand Colors (non-adaptive)
    static let groveSage = Color(hex: "87A878")        // Primary: buttons, highlights, progress
    static let groveTerracotta = Color(hex: "C4785B")  // Secondary: accents, success, completed
    static let groveWarmSand = Color(hex: "D4C4A8")    // Accent: card backgrounds, dividers
    static let groveMutedRust = Color(hex: "A65E4E")   // Alerts: skipped exercises, warnings

    // MARK: - Raw Colors (for reference)
    static let groveCharcoal = Color(hex: "3D3229")    // Dark brown
    static let groveCream = Color(hex: "F5F1EB")       // Light cream

    // MARK: - Adaptive Colors (light/dark mode)
    static let groveBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: "1C1917"))  // Dark warm gray
                : UIColor(Color(hex: "F5F1EB"))  // Cream
        }
    )

    static let groveCardBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: "292524"))  // Dark card
                : UIColor.white
        }
    )

    static let groveText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: "F5F1EB"))  // Cream text on dark
                : UIColor(Color(hex: "3D3229"))  // Charcoal text on light
        }
    )

    static let groveTextSecondary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: "A8A29E"))  // Muted light
                : UIColor(Color(hex: "78716C"))  // Muted dark
        }
    )

    // MARK: - Grove Network Window (light-mode "window" effect)
    static let groveGroveWindowBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: "1C1917"))  // Match page background — canvas provides contrast
                : UIColor(Color(hex: "FFFDF8"))  // Slightly warmer/lighter than cream page — subtle lift
        }
    )

    static let groveGroveWindowBorder = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: "3D3229")).withAlphaComponent(0.5)  // Subtle charcoal frame
                : UIColor(Color(hex: "C4B99A")).withAlphaComponent(0.6)  // Warm sand border — visible frame
        }
    )

    // MARK: - Semantic Aliases
    static let grovePrimary = groveSage
    static let groveSecondary = groveTerracotta

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
