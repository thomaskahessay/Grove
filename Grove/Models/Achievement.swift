import Foundation
import SwiftData

@Model
class Achievement {
    var id: UUID = UUID()
    var user: User?
    var type: AchievementType
    var unlockedAt: Date = Date()
    var relatedData: String?

    init(type: AchievementType, user: User? = nil, relatedData: String? = nil) {
        self.type = type
        self.user = user
        self.relatedData = relatedData
    }
}
