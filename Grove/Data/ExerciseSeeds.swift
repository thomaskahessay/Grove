import Foundation
import SwiftData

struct ExerciseSeeds {

    static let builtInExercises: [(name: String, group: MuscleGroup, subgroup: String?)] = [
        // MARK: - Chest (~18)
        ("Barbell Bench Press", .chest, "Middle"),
        ("Incline Barbell Press", .chest, "Upper"),
        ("Decline Barbell Press", .chest, "Lower"),
        ("Dumbbell Bench Press", .chest, "Middle"),
        ("Incline Dumbbell Press", .chest, "Upper"),
        ("Decline Dumbbell Press", .chest, "Lower"),
        ("Dumbbell Flyes", .chest, "Inner"),
        ("Incline Dumbbell Flyes", .chest, "Upper"),
        ("Cable Crossover", .chest, "Inner"),
        ("Low Cable Crossover", .chest, "Upper"),
        ("Push-Ups", .chest, "Middle"),
        ("Wide Grip Push-Ups", .chest, "Outer"),
        ("Chest Dips", .chest, "Lower"),
        ("Machine Chest Press", .chest, "Middle"),
        ("Pec Deck", .chest, "Inner"),
        ("Landmine Press", .chest, "Upper"),
        ("Svend Press", .chest, "Inner"),
        ("Floor Press", .chest, "Middle"),

        // MARK: - Back (~22)
        ("Deadlift", .back, "Lower Back"),
        ("Barbell Row", .back, "Upper Back"),
        ("Pendlay Row", .back, "Upper Back"),
        ("Dumbbell Row", .back, "Lats"),
        ("Kroc Row", .back, "Lats"),
        ("Pull-Ups", .back, "Lats"),
        ("Chin-Ups", .back, "Lats"),
        ("Wide Grip Pull-Ups", .back, "Lats"),
        ("Neutral Grip Pull-Ups", .back, "Lats"),
        ("Lat Pulldown", .back, "Lats"),
        ("Close Grip Lat Pulldown", .back, "Lats"),
        ("Seated Cable Row", .back, "Upper Back"),
        ("Single Arm Cable Row", .back, "Lats"),
        ("T-Bar Row", .back, "Upper Back"),
        ("Face Pulls", .back, "Upper Back"),
        ("Hyperextensions", .back, "Lower Back"),
        ("Back Extensions", .back, "Lower Back"),
        ("Reverse Hyperextension", .back, "Lower Back"),
        ("Good Mornings", .back, "Lower Back"),
        ("Straight Arm Pulldown", .back, "Lats"),
        ("Meadows Row", .back, "Lats"),
        ("Chest Supported Row", .back, "Upper Back"),
        ("Inverted Row", .back, "Upper Back"),
        ("Rack Pulls", .back, "Lower Back"),
        ("Snatch Grip Deadlift", .back, "Upper Back"),
        ("Seal Row", .back, "Upper Back"),

        // MARK: - Shoulders (~18)
        ("Overhead Press", .shoulders, "Front Delts"),
        ("Dumbbell Shoulder Press", .shoulders, "Front Delts"),
        ("Arnold Press", .shoulders, "Front Delts"),
        ("Seated Dumbbell Press", .shoulders, "Front Delts"),
        ("Push Press", .shoulders, "Front Delts"),
        ("Lateral Raises", .shoulders, "Side Delts"),
        ("Front Raises", .shoulders, "Front Delts"),
        ("Rear Delt Flyes", .shoulders, "Rear Delts"),
        ("Upright Row", .shoulders, "Side Delts"),
        ("Shrugs", .shoulders, "Traps"),
        ("Dumbbell Shrugs", .shoulders, "Traps"),
        ("Cable Lateral Raise", .shoulders, "Side Delts"),
        ("Machine Shoulder Press", .shoulders, "Front Delts"),
        ("Reverse Pec Deck", .shoulders, "Rear Delts"),
        ("Lu Raises", .shoulders, "Front Delts"),
        ("Cable Face Pull", .shoulders, "Rear Delts"),
        ("Plate Front Raise", .shoulders, "Front Delts"),
        ("Band Pull Apart", .shoulders, "Rear Delts"),

        // MARK: - Biceps (~14)
        ("Barbell Curl", .biceps, "Both Heads"),
        ("Dumbbell Curl", .biceps, "Both Heads"),
        ("Hammer Curl", .biceps, "Long Head"),
        ("Preacher Curl", .biceps, "Short Head"),
        ("Incline Dumbbell Curl", .biceps, "Long Head"),
        ("Cable Curl", .biceps, "Both Heads"),
        ("Concentration Curl", .biceps, "Short Head"),
        ("EZ Bar Curl", .biceps, "Both Heads"),
        ("Spider Curl", .biceps, "Short Head"),
        ("Reverse Curl", .biceps, "Brachialis"),
        ("Zottman Curl", .biceps, "Both Heads"),
        ("Bayesian Curl", .biceps, "Long Head"),
        ("Cable Hammer Curl", .biceps, "Long Head"),
        ("Machine Curl", .biceps, "Both Heads"),

        // MARK: - Triceps (~14)
        ("Tricep Pushdown", .triceps, "Lateral Head"),
        ("Rope Pushdown", .triceps, "Lateral Head"),
        ("Overhead Tricep Extension", .triceps, "Long Head"),
        ("Skull Crushers", .triceps, "All Heads"),
        ("Close Grip Bench Press", .triceps, "All Heads"),
        ("Tricep Dips", .triceps, "All Heads"),
        ("Diamond Push-Ups", .triceps, "All Heads"),
        ("Cable Overhead Extension", .triceps, "Long Head"),
        ("Tricep Kickbacks", .triceps, "Lateral Head"),
        ("JM Press", .triceps, "All Heads"),
        ("Dumbbell Skull Crushers", .triceps, "All Heads"),
        ("Single Arm Pushdown", .triceps, "Lateral Head"),
        ("Bench Dips", .triceps, "All Heads"),
        ("Overhead Rope Extension", .triceps, "Long Head"),

        // MARK: - Legs (~35)
        ("Barbell Squat", .legs, "Quads"),
        ("Front Squat", .legs, "Quads"),
        ("Leg Press", .legs, "Quads"),
        ("Hack Squat", .legs, "Quads"),
        ("Goblet Squat", .legs, "Quads"),
        ("Bulgarian Split Squat", .legs, "Quads"),
        ("Lunges", .legs, "Quads"),
        ("Walking Lunges", .legs, "Quads"),
        ("Reverse Lunges", .legs, "Quads"),
        ("Leg Extension", .legs, "Quads"),
        ("Sissy Squat", .legs, "Quads"),
        ("Pistol Squat", .legs, "Quads"),
        ("Smith Machine Squat", .legs, "Quads"),
        ("Belt Squat", .legs, "Quads"),
        ("Romanian Deadlift", .legs, "Hamstrings"),
        ("Stiff Leg Deadlift", .legs, "Hamstrings"),
        ("Single Leg Romanian Deadlift", .legs, "Hamstrings"),
        ("Leg Curl", .legs, "Hamstrings"),
        ("Seated Leg Curl", .legs, "Hamstrings"),
        ("Nordic Hamstring Curl", .legs, "Hamstrings"),
        ("Glute Ham Raise", .legs, "Hamstrings"),
        ("Hip Thrust", .legs, "Glutes"),
        ("Barbell Hip Thrust", .legs, "Glutes"),
        ("Glute Bridge", .legs, "Glutes"),
        ("Cable Kickback", .legs, "Glutes"),
        ("Cable Pull Through", .legs, "Glutes"),
        ("Step Ups", .legs, "Glutes"),
        ("Sumo Deadlift", .legs, "Glutes"),
        ("Kickbacks (Machine)", .legs, "Glutes"),
        ("Calf Raises", .legs, "Calves"),
        ("Seated Calf Raise", .legs, "Calves"),
        ("Donkey Calf Raise", .legs, "Calves"),
        ("Single Leg Calf Raise", .legs, "Calves"),
        ("Adductor Machine", .legs, "Adductors"),
        ("Abductor Machine", .legs, "Abductors"),
        ("Copenhagen Plank", .legs, "Adductors"),
        ("Box Squat", .legs, "Quads"),

        // MARK: - Core (~18)
        ("Crunches", .core, "Upper Abs"),
        ("Sit-Ups", .core, "Upper Abs"),
        ("Leg Raises", .core, "Lower Abs"),
        ("Hanging Leg Raise", .core, "Lower Abs"),
        ("Hanging Knee Raise", .core, "Lower Abs"),
        ("Plank", .core, "All"),
        ("Side Plank", .core, "Obliques"),
        ("Russian Twist", .core, "Obliques"),
        ("Cable Woodchop", .core, "Obliques"),
        ("Ab Wheel Rollout", .core, "All"),
        ("Dead Bug", .core, "All"),
        ("Mountain Climbers", .core, "All"),
        ("Bicycle Crunches", .core, "Obliques"),
        ("Cable Crunch", .core, "Upper Abs"),
        ("Pallof Press", .core, "All"),
        ("Decline Sit-Ups", .core, "Upper Abs"),
        ("Dragon Flag", .core, "All"),
        ("Toe Touches", .core, "Upper Abs"),
        ("Flutter Kicks", .core, "Lower Abs"),
        ("V-Ups", .core, "All"),

        // MARK: - Full Body (~14)
        ("Clean and Press", .fullBody, nil),
        ("Thrusters", .fullBody, nil),
        ("Burpees", .fullBody, nil),
        ("Kettlebell Swing", .fullBody, nil),
        ("Turkish Get Up", .fullBody, nil),
        ("Man Makers", .fullBody, nil),
        ("Battle Ropes", .fullBody, nil),
        ("Farmer's Walk", .fullBody, nil),
        ("Power Clean", .fullBody, nil),
        ("Hang Clean", .fullBody, nil),
        ("Snatch", .fullBody, nil),
        ("Devil Press", .fullBody, nil),
        ("Sled Push", .fullBody, nil),
        ("Sled Pull", .fullBody, nil),
    ]

    /// Seeds the database with built-in exercises, adding any new ones that don't already exist
    static func seedExercises(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        let existingExercises = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingExercises.map { $0.name })

        var added = 0
        for exerciseData in builtInExercises {
            guard !existingNames.contains(exerciseData.name) else { continue }
            let exercise = Exercise(
                name: exerciseData.name,
                muscleGroup: exerciseData.group,
                muscleSubgroup: exerciseData.subgroup,
                isBuiltIn: true
            )
            context.insert(exercise)
            added += 1
        }

        if added > 0 {
            try? context.save()
        }
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
