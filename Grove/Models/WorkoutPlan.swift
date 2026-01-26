import Foundation
import SwiftData

@Model
class WorkoutPlan {
    var id: UUID = UUID()
    var user: User?
    var date: Date
    var template: WorkoutTemplate?
    var isRestDay: Bool = false
    var completedWorkout: Workout?

    var status: PlanStatus {
        if completedWorkout != nil { return .completed }
        if isRestDay { return .rest }
        if date < Calendar.current.startOfDay(for: Date()) { return .incomplete }
        return .planned
    }

    init(
        date: Date,
        user: User? = nil,
        template: WorkoutTemplate? = nil,
        isRestDay: Bool = false
    ) {
        self.date = date
        self.user = user
        self.template = template
        self.isRestDay = isRestDay
    }
}
