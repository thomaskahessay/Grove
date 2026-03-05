import Foundation
import SwiftData

struct ExerciseSeeds {

    struct SeedExercise {
        let name: String
        let group: MuscleGroup
        let subgroup: String?
        let isCompound: Bool
        let sortPriority: Int
    }

    static let builtInExercises: [SeedExercise] = [
        // MARK: - Chest (~18)
        SeedExercise(name: "Barbell Bench Press", group: .chest, subgroup: "Middle", isCompound: true, sortPriority: 10),
        SeedExercise(name: "Incline Barbell Press", group: .chest, subgroup: "Upper", isCompound: true, sortPriority: 12),
        SeedExercise(name: "Decline Barbell Press", group: .chest, subgroup: "Lower", isCompound: true, sortPriority: 14),
        SeedExercise(name: "Dumbbell Bench Press", group: .chest, subgroup: "Middle", isCompound: true, sortPriority: 20),
        SeedExercise(name: "Incline Dumbbell Press", group: .chest, subgroup: "Upper", isCompound: true, sortPriority: 22),
        SeedExercise(name: "Decline Dumbbell Press", group: .chest, subgroup: "Lower", isCompound: true, sortPriority: 24),
        SeedExercise(name: "Dumbbell Flyes", group: .chest, subgroup: "Inner", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Incline Dumbbell Flyes", group: .chest, subgroup: "Upper", isCompound: false, sortPriority: 62),
        SeedExercise(name: "Cable Crossover", group: .chest, subgroup: "Inner", isCompound: false, sortPriority: 65),
        SeedExercise(name: "Low Cable Crossover", group: .chest, subgroup: "Upper", isCompound: false, sortPriority: 66),
        SeedExercise(name: "Push-Ups", group: .chest, subgroup: "Middle", isCompound: true, sortPriority: 30),
        SeedExercise(name: "Wide Grip Push-Ups", group: .chest, subgroup: "Outer", isCompound: true, sortPriority: 32),
        SeedExercise(name: "Chest Dips", group: .chest, subgroup: "Lower", isCompound: true, sortPriority: 25),
        SeedExercise(name: "Machine Chest Press", group: .chest, subgroup: "Middle", isCompound: true, sortPriority: 35),
        SeedExercise(name: "Pec Deck", group: .chest, subgroup: "Inner", isCompound: false, sortPriority: 70),
        SeedExercise(name: "Landmine Press", group: .chest, subgroup: "Upper", isCompound: true, sortPriority: 28),
        SeedExercise(name: "Svend Press", group: .chest, subgroup: "Inner", isCompound: false, sortPriority: 72),
        SeedExercise(name: "Floor Press", group: .chest, subgroup: "Middle", isCompound: true, sortPriority: 26),

        // MARK: - Back (~22+)
        SeedExercise(name: "Deadlift", group: .back, subgroup: "Lower Back", isCompound: true, sortPriority: 10),
        SeedExercise(name: "Barbell Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 12),
        SeedExercise(name: "Pendlay Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 14),
        SeedExercise(name: "Dumbbell Row", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 20),
        SeedExercise(name: "Kroc Row", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 22),
        SeedExercise(name: "Pull-Ups", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 15),
        SeedExercise(name: "Chin-Ups", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 16),
        SeedExercise(name: "Wide Grip Pull-Ups", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 17),
        SeedExercise(name: "Neutral Grip Pull-Ups", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 18),
        SeedExercise(name: "Lat Pulldown", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 25),
        SeedExercise(name: "Close Grip Lat Pulldown", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 26),
        SeedExercise(name: "Seated Cable Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 28),
        SeedExercise(name: "Single Arm Cable Row", group: .back, subgroup: "Lats", isCompound: false, sortPriority: 50),
        SeedExercise(name: "T-Bar Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 19),
        SeedExercise(name: "Face Pulls", group: .back, subgroup: "Upper Back", isCompound: false, sortPriority: 55),
        SeedExercise(name: "Hyperextensions", group: .back, subgroup: "Lower Back", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Back Extensions", group: .back, subgroup: "Lower Back", isCompound: false, sortPriority: 62),
        SeedExercise(name: "Reverse Hyperextension", group: .back, subgroup: "Lower Back", isCompound: false, sortPriority: 64),
        SeedExercise(name: "Good Mornings", group: .back, subgroup: "Lower Back", isCompound: true, sortPriority: 30),
        SeedExercise(name: "Straight Arm Pulldown", group: .back, subgroup: "Lats", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Meadows Row", group: .back, subgroup: "Lats", isCompound: true, sortPriority: 24),
        SeedExercise(name: "Chest Supported Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 23),
        SeedExercise(name: "Inverted Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 32),
        SeedExercise(name: "Rack Pulls", group: .back, subgroup: "Lower Back", isCompound: true, sortPriority: 13),
        SeedExercise(name: "Snatch Grip Deadlift", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 11),
        SeedExercise(name: "Seal Row", group: .back, subgroup: "Upper Back", isCompound: true, sortPriority: 21),

        // MARK: - Shoulders (~18)
        SeedExercise(name: "Overhead Press", group: .shoulders, subgroup: "Front Delts", isCompound: true, sortPriority: 10),
        SeedExercise(name: "Dumbbell Shoulder Press", group: .shoulders, subgroup: "Front Delts", isCompound: true, sortPriority: 12),
        SeedExercise(name: "Arnold Press", group: .shoulders, subgroup: "Front Delts", isCompound: true, sortPriority: 14),
        SeedExercise(name: "Seated Dumbbell Press", group: .shoulders, subgroup: "Front Delts", isCompound: true, sortPriority: 13),
        SeedExercise(name: "Push Press", group: .shoulders, subgroup: "Front Delts", isCompound: true, sortPriority: 11),
        SeedExercise(name: "Lateral Raises", group: .shoulders, subgroup: "Side Delts", isCompound: false, sortPriority: 50),
        SeedExercise(name: "Front Raises", group: .shoulders, subgroup: "Front Delts", isCompound: false, sortPriority: 55),
        SeedExercise(name: "Rear Delt Flyes", group: .shoulders, subgroup: "Rear Delts", isCompound: false, sortPriority: 52),
        SeedExercise(name: "Upright Row", group: .shoulders, subgroup: "Side Delts", isCompound: true, sortPriority: 25),
        SeedExercise(name: "Shrugs", group: .shoulders, subgroup: "Traps", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Dumbbell Shrugs", group: .shoulders, subgroup: "Traps", isCompound: false, sortPriority: 62),
        SeedExercise(name: "Cable Lateral Raise", group: .shoulders, subgroup: "Side Delts", isCompound: false, sortPriority: 51),
        SeedExercise(name: "Machine Shoulder Press", group: .shoulders, subgroup: "Front Delts", isCompound: true, sortPriority: 30),
        SeedExercise(name: "Reverse Pec Deck", group: .shoulders, subgroup: "Rear Delts", isCompound: false, sortPriority: 54),
        SeedExercise(name: "Lu Raises", group: .shoulders, subgroup: "Front Delts", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Cable Face Pull", group: .shoulders, subgroup: "Rear Delts", isCompound: false, sortPriority: 53),
        SeedExercise(name: "Plate Front Raise", group: .shoulders, subgroup: "Front Delts", isCompound: false, sortPriority: 57),
        SeedExercise(name: "Band Pull Apart", group: .shoulders, subgroup: "Rear Delts", isCompound: false, sortPriority: 58),

        // MARK: - Biceps (~14)
        SeedExercise(name: "Barbell Curl", group: .biceps, subgroup: "Both Heads", isCompound: false, sortPriority: 50),
        SeedExercise(name: "Dumbbell Curl", group: .biceps, subgroup: "Both Heads", isCompound: false, sortPriority: 52),
        SeedExercise(name: "Hammer Curl", group: .biceps, subgroup: "Long Head", isCompound: false, sortPriority: 54),
        SeedExercise(name: "Preacher Curl", group: .biceps, subgroup: "Short Head", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Incline Dumbbell Curl", group: .biceps, subgroup: "Long Head", isCompound: false, sortPriority: 58),
        SeedExercise(name: "Cable Curl", group: .biceps, subgroup: "Both Heads", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Concentration Curl", group: .biceps, subgroup: "Short Head", isCompound: false, sortPriority: 62),
        SeedExercise(name: "EZ Bar Curl", group: .biceps, subgroup: "Both Heads", isCompound: false, sortPriority: 51),
        SeedExercise(name: "Spider Curl", group: .biceps, subgroup: "Short Head", isCompound: false, sortPriority: 64),
        SeedExercise(name: "Reverse Curl", group: .biceps, subgroup: "Brachialis", isCompound: false, sortPriority: 66),
        SeedExercise(name: "Zottman Curl", group: .biceps, subgroup: "Both Heads", isCompound: false, sortPriority: 55),
        SeedExercise(name: "Bayesian Curl", group: .biceps, subgroup: "Long Head", isCompound: false, sortPriority: 68),
        SeedExercise(name: "Cable Hammer Curl", group: .biceps, subgroup: "Long Head", isCompound: false, sortPriority: 61),
        SeedExercise(name: "Machine Curl", group: .biceps, subgroup: "Both Heads", isCompound: false, sortPriority: 70),

        // MARK: - Triceps (~14)
        SeedExercise(name: "Tricep Pushdown", group: .triceps, subgroup: "Lateral Head", isCompound: false, sortPriority: 50),
        SeedExercise(name: "Rope Pushdown", group: .triceps, subgroup: "Lateral Head", isCompound: false, sortPriority: 52),
        SeedExercise(name: "Overhead Tricep Extension", group: .triceps, subgroup: "Long Head", isCompound: false, sortPriority: 54),
        SeedExercise(name: "Skull Crushers", group: .triceps, subgroup: "All Heads", isCompound: false, sortPriority: 51),
        SeedExercise(name: "Close Grip Bench Press", group: .triceps, subgroup: "All Heads", isCompound: true, sortPriority: 10),
        SeedExercise(name: "Tricep Dips", group: .triceps, subgroup: "All Heads", isCompound: true, sortPriority: 15),
        SeedExercise(name: "Diamond Push-Ups", group: .triceps, subgroup: "All Heads", isCompound: true, sortPriority: 20),
        SeedExercise(name: "Cable Overhead Extension", group: .triceps, subgroup: "Long Head", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Tricep Kickbacks", group: .triceps, subgroup: "Lateral Head", isCompound: false, sortPriority: 65),
        SeedExercise(name: "JM Press", group: .triceps, subgroup: "All Heads", isCompound: true, sortPriority: 18),
        SeedExercise(name: "Dumbbell Skull Crushers", group: .triceps, subgroup: "All Heads", isCompound: false, sortPriority: 53),
        SeedExercise(name: "Single Arm Pushdown", group: .triceps, subgroup: "Lateral Head", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Bench Dips", group: .triceps, subgroup: "All Heads", isCompound: true, sortPriority: 25),
        SeedExercise(name: "Overhead Rope Extension", group: .triceps, subgroup: "Long Head", isCompound: false, sortPriority: 55),

        // MARK: - Legs (~35)
        SeedExercise(name: "Barbell Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 10),
        SeedExercise(name: "Front Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 11),
        SeedExercise(name: "Leg Press", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 20),
        SeedExercise(name: "Hack Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 22),
        SeedExercise(name: "Goblet Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 25),
        SeedExercise(name: "Bulgarian Split Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 18),
        SeedExercise(name: "Lunges", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 24),
        SeedExercise(name: "Walking Lunges", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 26),
        SeedExercise(name: "Reverse Lunges", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 27),
        SeedExercise(name: "Leg Extension", group: .legs, subgroup: "Quads", isCompound: false, sortPriority: 50),
        SeedExercise(name: "Sissy Squat", group: .legs, subgroup: "Quads", isCompound: false, sortPriority: 55),
        SeedExercise(name: "Pistol Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 28),
        SeedExercise(name: "Smith Machine Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 23),
        SeedExercise(name: "Belt Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 21),
        SeedExercise(name: "Romanian Deadlift", group: .legs, subgroup: "Hamstrings", isCompound: true, sortPriority: 12),
        SeedExercise(name: "Stiff Leg Deadlift", group: .legs, subgroup: "Hamstrings", isCompound: true, sortPriority: 14),
        SeedExercise(name: "Single Leg Romanian Deadlift", group: .legs, subgroup: "Hamstrings", isCompound: true, sortPriority: 19),
        SeedExercise(name: "Leg Curl", group: .legs, subgroup: "Hamstrings", isCompound: false, sortPriority: 52),
        SeedExercise(name: "Seated Leg Curl", group: .legs, subgroup: "Hamstrings", isCompound: false, sortPriority: 53),
        SeedExercise(name: "Nordic Hamstring Curl", group: .legs, subgroup: "Hamstrings", isCompound: false, sortPriority: 54),
        SeedExercise(name: "Glute Ham Raise", group: .legs, subgroup: "Hamstrings", isCompound: true, sortPriority: 30),
        SeedExercise(name: "Hip Thrust", group: .legs, subgroup: "Glutes", isCompound: true, sortPriority: 15),
        SeedExercise(name: "Barbell Hip Thrust", group: .legs, subgroup: "Glutes", isCompound: true, sortPriority: 13),
        SeedExercise(name: "Glute Bridge", group: .legs, subgroup: "Glutes", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Cable Kickback", group: .legs, subgroup: "Glutes", isCompound: false, sortPriority: 65),
        SeedExercise(name: "Cable Pull Through", group: .legs, subgroup: "Glutes", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Step Ups", group: .legs, subgroup: "Glutes", isCompound: true, sortPriority: 29),
        SeedExercise(name: "Sumo Deadlift", group: .legs, subgroup: "Glutes", isCompound: true, sortPriority: 16),
        SeedExercise(name: "Kickbacks (Machine)", group: .legs, subgroup: "Glutes", isCompound: false, sortPriority: 66),
        SeedExercise(name: "Calf Raises", group: .legs, subgroup: "Calves", isCompound: false, sortPriority: 70),
        SeedExercise(name: "Seated Calf Raise", group: .legs, subgroup: "Calves", isCompound: false, sortPriority: 72),
        SeedExercise(name: "Donkey Calf Raise", group: .legs, subgroup: "Calves", isCompound: false, sortPriority: 74),
        SeedExercise(name: "Single Leg Calf Raise", group: .legs, subgroup: "Calves", isCompound: false, sortPriority: 76),
        SeedExercise(name: "Adductor Machine", group: .legs, subgroup: "Adductors", isCompound: false, sortPriority: 80),
        SeedExercise(name: "Abductor Machine", group: .legs, subgroup: "Abductors", isCompound: false, sortPriority: 82),
        SeedExercise(name: "Copenhagen Plank", group: .legs, subgroup: "Adductors", isCompound: false, sortPriority: 84),
        SeedExercise(name: "Box Squat", group: .legs, subgroup: "Quads", isCompound: true, sortPriority: 17),

        // MARK: - Core (~18)
        SeedExercise(name: "Crunches", group: .core, subgroup: "Upper Abs", isCompound: false, sortPriority: 50),
        SeedExercise(name: "Sit-Ups", group: .core, subgroup: "Upper Abs", isCompound: false, sortPriority: 52),
        SeedExercise(name: "Leg Raises", group: .core, subgroup: "Lower Abs", isCompound: false, sortPriority: 54),
        SeedExercise(name: "Hanging Leg Raise", group: .core, subgroup: "Lower Abs", isCompound: false, sortPriority: 51),
        SeedExercise(name: "Hanging Knee Raise", group: .core, subgroup: "Lower Abs", isCompound: false, sortPriority: 53),
        SeedExercise(name: "Plank", group: .core, subgroup: "All", isCompound: false, sortPriority: 55),
        SeedExercise(name: "Side Plank", group: .core, subgroup: "Obliques", isCompound: false, sortPriority: 58),
        SeedExercise(name: "Russian Twist", group: .core, subgroup: "Obliques", isCompound: false, sortPriority: 60),
        SeedExercise(name: "Cable Woodchop", group: .core, subgroup: "Obliques", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Ab Wheel Rollout", group: .core, subgroup: "All", isCompound: false, sortPriority: 50),
        SeedExercise(name: "Dead Bug", group: .core, subgroup: "All", isCompound: false, sortPriority: 57),
        SeedExercise(name: "Mountain Climbers", group: .core, subgroup: "All", isCompound: false, sortPriority: 62),
        SeedExercise(name: "Bicycle Crunches", group: .core, subgroup: "Obliques", isCompound: false, sortPriority: 59),
        SeedExercise(name: "Cable Crunch", group: .core, subgroup: "Upper Abs", isCompound: false, sortPriority: 55),
        SeedExercise(name: "Pallof Press", group: .core, subgroup: "All", isCompound: false, sortPriority: 52),
        SeedExercise(name: "Decline Sit-Ups", group: .core, subgroup: "Upper Abs", isCompound: false, sortPriority: 56),
        SeedExercise(name: "Dragon Flag", group: .core, subgroup: "All", isCompound: false, sortPriority: 51),
        SeedExercise(name: "Toe Touches", group: .core, subgroup: "Upper Abs", isCompound: false, sortPriority: 64),
        SeedExercise(name: "Flutter Kicks", group: .core, subgroup: "Lower Abs", isCompound: false, sortPriority: 63),
        SeedExercise(name: "V-Ups", group: .core, subgroup: "All", isCompound: false, sortPriority: 54),

        // MARK: - Full Body (~14)
        SeedExercise(name: "Clean and Press", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 10),
        SeedExercise(name: "Thrusters", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 12),
        SeedExercise(name: "Burpees", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 30),
        SeedExercise(name: "Kettlebell Swing", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 15),
        SeedExercise(name: "Turkish Get Up", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 20),
        SeedExercise(name: "Man Makers", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 25),
        SeedExercise(name: "Battle Ropes", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 35),
        SeedExercise(name: "Farmer's Walk", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 18),
        SeedExercise(name: "Power Clean", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 11),
        SeedExercise(name: "Hang Clean", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 13),
        SeedExercise(name: "Snatch", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 14),
        SeedExercise(name: "Devil Press", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 28),
        SeedExercise(name: "Sled Push", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 22),
        SeedExercise(name: "Sled Pull", group: .fullBody, subgroup: nil, isCompound: true, sortPriority: 24),
    ]

    /// Seeds the database with built-in exercises, adding any new ones that don't already exist
    static func seedExercises(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        let existingExercises = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingExercises.map { $0.name })

        // Update compound/sortPriority on existing exercises that haven't been tagged yet
        let seedLookup = Dictionary(uniqueKeysWithValues: builtInExercises.map { ($0.name, $0) })
        for exercise in existingExercises {
            if let seed = seedLookup[exercise.name] {
                if exercise.sortPriority == 50 && seed.sortPriority != 50 {
                    exercise.isCompound = seed.isCompound
                    exercise.sortPriority = seed.sortPriority
                }
            }
        }

        var added = 0
        for exerciseData in builtInExercises {
            guard !existingNames.contains(exerciseData.name) else { continue }
            let exercise = Exercise(
                name: exerciseData.name,
                muscleGroup: exerciseData.group,
                muscleSubgroup: exerciseData.subgroup,
                isBuiltIn: true,
                isCompound: exerciseData.isCompound,
                sortPriority: exerciseData.sortPriority
            )
            context.insert(exercise)
            added += 1
        }

        if added > 0 || !existingExercises.isEmpty {
            try? context.save()
        }
    }

    /// Returns exercises filtered by muscle group
    static func exercises(for muscleGroup: MuscleGroup) -> [SeedExercise] {
        builtInExercises.filter { $0.group == muscleGroup }
    }

    /// Returns a random selection of exercises for a given muscle group
    static func randomExercises(for muscleGroup: MuscleGroup, count: Int = 5) -> [SeedExercise] {
        Array(exercises(for: muscleGroup).shuffled().prefix(count))
    }
}
