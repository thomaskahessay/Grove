import Foundation
import SwiftData

@Model
class CreatineLog {
    var date: Date
    var user: User?

    init(date: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
    }
}
