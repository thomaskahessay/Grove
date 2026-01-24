import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @State private var showingWorkoutCreation = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

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
                    ProfileView()
                }
            }
            .tint(.groveSage)

            // Floating Action Button (hidden when workout is active)
            if !sessionManager.hasActiveWorkout {
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

            // Minimized workout card
            if sessionManager.isMinimized {
                MinimizedWorkoutCardView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingWorkoutCreation) {
            WorkoutCreationView()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { sessionManager.isFullScreenPresented },
                set: { sessionManager.isFullScreenPresented = $0 }
            )
        ) {
            if let workout = sessionManager.activeWorkout {
                ActiveWorkoutView(workout: workout)
            }
        }
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    ContentView()
        .environment(WorkoutSessionManager())
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
