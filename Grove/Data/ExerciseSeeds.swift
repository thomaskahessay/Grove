import Foundation
import SwiftData

struct ExerciseSeeds {

    static let builtInExercises: [(name: String, group: MuscleGroup, subgroup: String?)] = [
        // MARK: - Chest (~12)
        ("Barbell Bench Press", .chest, "Middle"),
        ("Incline Barbell Press", .chest, "Upper"),
        ("Decline Barbell Press", .chest, "Lower"),
        ("Dumbbell Bench Press", .chest, "Middle"),
        ("Incline Dumbbell Press", .chest, "Upper"),
        ("Dumbbell Flyes", .chest, "Inner"),
        ("Cable Crossover", .chest, "Inner"),
        ("Push-Ups", .chest, "Middle"),
        ("Chest Dips", .chest, "Lower"),
        ("Machine Chest Press", .chest, "Middle"),
        ("Pec Deck", .chest, "Inner"),
        ("Landmine Press", .chest, "Upper"),

        // MARK: - Back (~15)
        ("Deadlift", .back, "Lower Back"),
        ("Barbell Row", .back, "Upper Back"),
        ("Dumbbell Row", .back, "Lats"),
        ("Pull-Ups", .back, "Lats"),
        ("Chin-Ups", .back, "Lats"),
        ("Lat Pulldown", .back, "Lats"),
        ("Seated Cable Row", .back, "Upper Back"),
        ("T-Bar Row", .back, "Upper Back"),
        ("Face Pulls", .back, "Upper Back"),
        ("Hyperextensions", .back, "Lower Back"),
        ("Good Mornings", .back, "Lower Back"),
        ("Straight Arm Pulldown", .back, "Lats"),
        ("Meadows Row", .back, "Lats"),
        ("Chest Supported Row", .back, "Upper Back"),
        ("Inverted Row", .back, "Upper Back"),

        // MARK: - Shoulders (~12)
        ("Overhead Press", .shoulders, "Front Delts"),
        ("Dumbbell Shoulder Press", .shoulders, "Front Delts"),
        ("Arnold Press", .shoulders, "Front Delts"),
        ("Lateral Raises", .shoulders, "Side Delts"),
        ("Front Raises", .shoulders, "Front Delts"),
        ("Rear Delt Flyes", .shoulders, "Rear Delts"),
        ("Upright Row", .shoulders, "Side Delts"),
        ("Shrugs", .shoulders, "Traps"),
        ("Cable Lateral Raise", .shoulders, "Side Delts"),
        ("Machine Shoulder Press", .shoulders, "Front Delts"),
        ("Reverse Pec Deck", .shoulders, "Rear Delts"),
        ("Lu Raises", .shoulders, "Front Delts"),

        // MARK: - Biceps (~8)
        ("Barbell Curl", .biceps, "Both Heads"),
        ("Dumbbell Curl", .biceps, "Both Heads"),
        ("Hammer Curl", .biceps, "Long Head"),
        ("Preacher Curl", .biceps, "Short Head"),
        ("Incline Dumbbell Curl", .biceps, "Long Head"),
        ("Cable Curl", .biceps, "Both Heads"),
        ("Concentration Curl", .biceps, "Short Head"),
        ("EZ Bar Curl", .biceps, "Both Heads"),

        // MARK: - Triceps (~8)
        ("Tricep Pushdown", .triceps, "Lateral Head"),
        ("Overhead Tricep Extension", .triceps, "Long Head"),
        ("Skull Crushers", .triceps, "All Heads"),
        ("Close Grip Bench Press", .triceps, "All Heads"),
        ("Tricep Dips", .triceps, "All Heads"),
        ("Diamond Push-Ups", .triceps, "All Heads"),
        ("Cable Overhead Extension", .triceps, "Long Head"),
        ("Tricep Kickbacks", .triceps, "Lateral Head"),

        // MARK: - Legs (~25)
        ("Barbell Squat", .legs, "Quads"),
        ("Front Squat", .legs, "Quads"),
        ("Leg Press", .legs, "Quads"),
        ("Hack Squat", .legs, "Quads"),
        ("Goblet Squat", .legs, "Quads"),
        ("Bulgarian Split Squat", .legs, "Quads"),
        ("Lunges", .legs, "Quads"),
        ("Walking Lunges", .legs, "Quads"),
        ("Leg Extension", .legs, "Quads"),
        ("Romanian Deadlift", .legs, "Hamstrings"),
        ("Stiff Leg Deadlift", .legs, "Hamstrings"),
        ("Leg Curl", .legs, "Hamstrings"),
        ("Seated Leg Curl", .legs, "Hamstrings"),
        ("Nordic Hamstring Curl", .legs, "Hamstrings"),
        ("Hip Thrust", .legs, "Glutes"),
        ("Glute Bridge", .legs, "Glutes"),
        ("Cable Kickback", .legs, "Glutes"),
        ("Step Ups", .legs, "Glutes"),
        ("Sumo Deadlift", .legs, "Glutes"),
        ("Calf Raises", .legs, "Calves"),
        ("Seated Calf Raise", .legs, "Calves"),
        ("Donkey Calf Raise", .legs, "Calves"),
        ("Adductor Machine", .legs, "Adductors"),
        ("Abductor Machine", .legs, "Abductors"),
        ("Box Squat", .legs, "Quads"),

        // MARK: - Core (~12)
        ("Crunches", .core, "Upper Abs"),
        ("Sit-Ups", .core, "Upper Abs"),
        ("Leg Raises", .core, "Lower Abs"),
        ("Hanging Leg Raise", .core, "Lower Abs"),
        ("Plank", .core, "All"),
        ("Side Plank", .core, "Obliques"),
        ("Russian Twist", .core, "Obliques"),
        ("Cable Woodchop", .core, "Obliques"),
        ("Ab Wheel Rollout", .core, "All"),
        ("Dead Bug", .core, "All"),
        ("Mountain Climbers", .core, "All"),
        ("Bicycle Crunches", .core, "Obliques"),

        // MARK: - Full Body (~8)
        ("Clean and Press", .fullBody, nil),
        ("Thrusters", .fullBody, nil),
        ("Burpees", .fullBody, nil),
        ("Kettlebell Swing", .fullBody, nil),
        ("Turkish Get Up", .fullBody, nil),
        ("Man Makers", .fullBody, nil),
        ("Battle Ropes", .fullBody, nil),
        ("Farmer's Walk", .fullBody, nil),
    ]

    /// Seeds the database with built-in exercises if they don't already exist
    static func seedExercises(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else {
            return
        }

        for exerciseData in builtInExercises {
            let exercise = Exercise(
                name: exerciseData.name,
                muscleGroup: exerciseData.group,
                muscleSubgroup: exerciseData.subgroup,
                isBuiltIn: true
            )
            context.insert(exercise)
        }

        try? context.save()
    }

    /// Returns exercises filtered by muscle group
    static func exercises(for muscleGroup: MuscleGroup) -> [(name: String, group: MuscleGroup, subgroup: String?)] {
        builtInExercises.filter { $0.group == muscleGroup }
    }

    /// Returns a random selection of exercises for a given muscle group
    static func randomExercises(for muscleGroup: MuscleGroup, count: Int = 5) -> [(name: String, group: MuscleGroup, subgroup: String?)] {
        Array(exercises(for: muscleGroup).shuffled().prefix(count))
    }
}
