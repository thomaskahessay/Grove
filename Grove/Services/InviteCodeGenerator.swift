import Foundation

enum InviteCodeGenerator {
    // Excludes ambiguous characters: 0/O, 1/I/L
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let codeLength = 4
    static let prefix = "GROVE-"

    static func generate() -> String {
        let code = String((0..<codeLength).map { _ in characters.randomElement()! })
        return "\(prefix)\(code)"
    }

    static func normalize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix(prefix) {
            return trimmed
        }
        return "\(prefix)\(trimmed)"
    }

    static func codeOnly(_ fullCode: String) -> String {
        if fullCode.hasPrefix(prefix) {
            return String(fullCode.dropFirst(prefix.count))
        }
        return fullCode
    }
}
