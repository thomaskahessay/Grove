import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingWorkoutCreation = false

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // Floating Action Button
            HStack {
                Spacer()
                Button {
                    showingWorkoutCreation = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.groveSage.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90) // Above tab bar
            }
        }
        .sheet(isPresented: $showingWorkoutCreation) {
            WorkoutCreationView()
        }
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
