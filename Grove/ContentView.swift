import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                Text("Progress")
            }

            Tab("Social", systemImage: "person.2.fill") {
                Text("Social")
            }

            Tab("Profile", systemImage: "person.fill") {
                Text("Profile")
            }
        }
        .tint(.groveSage)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            User.self,
            Exercise.self,
            Workout.self,
            ExerciseLog.self,
            SetLog.self,
            WorkoutTemplate.self,
            WorkoutPlan.self,
            Achievement.self
        ])
}
