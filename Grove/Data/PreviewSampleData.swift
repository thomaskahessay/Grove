import Foundation
import SwiftData

/// Provides a ModelContainer with sample data for SwiftUI Previews
@MainActor
struct PreviewSampleData {

    /// Shared preview container with sample data - reuse across previews
    static var shared: ModelContainer = {
        let container = try! ModelContainer(
            for: User.self, Exercise.self, Workout.self, ExerciseLog.self,
                 SetLog.self, WorkoutTemplate.self, WorkoutPlan.self, Achievement.self,
                 PersonalRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let context = container.mainContext

        // Seed exercises first
        ExerciseSeeds.seedExercises(context: context)

        // Create sample data
        createSampleData(in: context)

        return container
    }()

    /// Creates all sample data
    private static func createSampleData(in context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // MARK: - User
        let user = User(
            appleUserID: "preview-user-123",
            fitnessGoal: .buildMuscle,
            experienceLevel: .intermediate,
            preferredUnits: .imperial
        )
        user.displayName = "Thomas"
        user.currentStreak = 5
        user.longestStreak = 14
        user.lastWorkoutDate = calendar.date(byAdding: .day, value: -1, to: today)
        context.insert(user)

        // MARK: - Fetch seeded exercises
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let exercises = (try? context.fetch(exerciseDescriptor)) ?? []

        func findExercise(_ name: String) -> Exercise? {
            exercises.first { $0.name == name }
        }

        let benchPress = findExercise("Barbell Bench Press")
        let inclinePress = findExercise("Incline Dumbbell Press")
        let tricepPushdown = findExercise("Tricep Pushdown")
        let lateralRaise = findExercise("Lateral Raises")

        let barbellRow = findExercise("Barbell Row")
        let latPulldown = findExercise("Lat Pulldown")
        let seatedRow = findExercise("Seated Cable Row")
        let barbellCurl = findExercise("Barbell Curl")

        let squat = findExercise("Barbell Squat")
        let legPress = findExercise("Leg Press")
        let romanianDL = findExercise("Romanian Deadlift")
        let legCurl = findExercise("Leg Curl")

        // MARK: - Templates
        let pushTemplate = WorkoutTemplate(name: "Push Day", category: .push, isBuiltIn: false)
        pushTemplate.exerciseIDs = [benchPress?.id, inclinePress?.id, tricepPushdown?.id, lateralRaise?.id].compactMap { $0 }
        pushTemplate.usageCount = 8
        pushTemplate.user = user
        context.insert(pushTemplate)

        let pullTemplate = WorkoutTemplate(name: "Pull Day", category: .pull, isBuiltIn: false)
        pullTemplate.exerciseIDs = [barbellRow?.id, latPulldown?.id, seatedRow?.id, barbellCurl?.id].compactMap { $0 }
        pullTemplate.usageCount = 6
        pullTemplate.user = user
        context.insert(pullTemplate)

        let legsTemplate = WorkoutTemplate(name: "Leg Day", category: .legs, isBuiltIn: false)
        legsTemplate.exerciseIDs = [squat?.id, legPress?.id, romanianDL?.id, legCurl?.id].compactMap { $0 }
        legsTemplate.usageCount = 5
        legsTemplate.user = user
        context.insert(legsTemplate)

        // MARK: - Past Workouts
        createWorkout(
            name: "Push Day",
            daysAgo: 1,
            exercises: [
                (benchPress, [135, 155, 165], [10, 8, 6]),
                (inclinePress, [50, 55, 55], [10, 8, 8]),
                (tricepPushdown, [50, 55, 55], [12, 10, 10]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Pull Day",
            daysAgo: 3,
            exercises: [
                (barbellRow, [115, 135, 135], [10, 8, 8]),
                (latPulldown, [120, 130, 130], [10, 8, 8]),
                (barbellCurl, [65, 70, 70], [10, 8, 8]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Leg Day",
            daysAgo: 5,
            exercises: [
                (squat, [185, 205, 225], [8, 6, 4]),
                (legPress, [270, 320, 360], [10, 10, 8]),
                (romanianDL, [135, 155, 155], [10, 8, 8]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Push Day",
            daysAgo: 8,
            exercises: [
                (benchPress, [135, 145, 155], [8, 8, 6]),
                (inclinePress, [45, 50, 50], [10, 10, 8]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Pull Day",
            daysAgo: 10,
            exercises: [
                (barbellRow, [105, 115, 125], [10, 10, 8]),
                (latPulldown, [110, 120, 120], [10, 10, 8]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Leg Day",
            daysAgo: 12,
            exercises: [
                (squat, [175, 195, 205], [8, 6, 5]),
                (legPress, [250, 300, 340], [10, 10, 8]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Push Day",
            daysAgo: 15,
            exercises: [
                (benchPress, [125, 135, 145], [10, 8, 6]),
            ],
            user: user,
            today: today,
            context: context
        )

        createWorkout(
            name: "Pull Day",
            daysAgo: 17,
            exercises: [
                (barbellRow, [95, 105, 115], [10, 10, 8]),
            ],
            user: user,
            today: today,
            context: context
        )

        // MARK: - This Week's Plans
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        createPlan(date: monday, template: pushTemplate, isRest: false, user: user, today: today, context: context)
        createPlan(date: calendar.date(byAdding: .day, value: 1, to: monday)!, template: nil, isRest: true, user: user, today: today, context: context)
        createPlan(date: calendar.date(byAdding: .day, value: 2, to: monday)!, template: pullTemplate, isRest: false, user: user, today: today, context: context)
        createPlan(date: calendar.date(byAdding: .day, value: 3, to: monday)!, template: nil, isRest: true, user: user, today: today, context: context)
        createPlan(date: calendar.date(byAdding: .day, value: 4, to: monday)!, template: legsTemplate, isRest: false, user: user, today: today, context: context)
        createPlan(date: calendar.date(byAdding: .day, value: 5, to: monday)!, template: pushTemplate, isRest: false, user: user, today: today, context: context)
        createPlan(date: calendar.date(byAdding: .day, value: 6, to: monday)!, template: nil, isRest: true, user: user, today: today, context: context)

        // MARK: - Achievements
        let firstRepAchievement = Achievement(type: .firstRep, user: user, relatedData: "Push Day")
        firstRepAchievement.unlockedAt = calendar.date(byAdding: .day, value: -15, to: today)!
        context.insert(firstRepAchievement)

        let prCrusherAchievement = Achievement(type: .prCrusher, user: user, relatedData: "Barbell Bench Press")
        prCrusherAchievement.unlockedAt = calendar.date(byAdding: .day, value: -1, to: today)!
        context.insert(prCrusherAchievement)

        try? context.save()
    }

    private static func createWorkout(
        name: String,
        daysAgo: Int,
        exercises: [(Exercise?, [Double], [Int])],
        user: User,
        today: Date,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        let workoutDate = calendar.date(byAdding: .day, value: -daysAgo, to: today)!

        let workout = Workout(name: name, templateUsed: nil)
        workout.user = user
        workout.startedAt = workoutDate
        workout.completedAt = workoutDate.addingTimeInterval(3600)
        context.insert(workout)

        for (index, exerciseData) in exercises.enumerated() {
            guard let exercise = exerciseData.0 else { continue }
            let weights = exerciseData.1
            let reps = exerciseData.2

            let exerciseLog = ExerciseLog(
                exercise: exercise,
                orderIndex: index,
                targetSets: weights.count,
                targetReps: 10
            )
            exerciseLog.workout = workout
            exerciseLog.status = .completed
            context.insert(exerciseLog)

            for setIndex in 0..<weights.count {
                let setLog = SetLog(
                    setNumber: setIndex + 1,
                    weight: weights[setIndex],
                    reps: reps[setIndex]
                )
                setLog.isCompleted = true
                setLog.completedAt = workoutDate
                setLog.exerciseLog = exerciseLog
                exerciseLog.sets.append(setLog)
                context.insert(setLog)
            }
        }
    }

    private static func createPlan(
        date: Date,
        template: WorkoutTemplate?,
        isRest: Bool,
        user: User,
        today: Date,
        context: ModelContext
    ) {
        let plan = WorkoutPlan(date: date, template: template)
        plan.isRestDay = isRest
        plan.user = user
        context.insert(plan)
    }
}

// MARK: - Preview Convenience Extensions

extension ModelContainer {
    /// Quick access to the preview container
    @MainActor
    static var preview: ModelContainer {
        PreviewSampleData.shared
    }
}
