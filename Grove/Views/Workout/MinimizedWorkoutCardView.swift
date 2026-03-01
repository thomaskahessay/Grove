import SwiftUI

struct MinimizedWorkoutCardView: View {
    @Environment(WorkoutSessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color.clear
                    Capsule()
                        .fill(Color.groveSage)
                        .frame(width: geo.size.width * sessionManager.workoutProgressFraction)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionManager.workoutProgressFraction)
                }
            }
            .frame(height: 3)
            .background(Color.groveSage.opacity(0.15))
            .clipShape(Capsule())

            HStack(spacing: 12) {
                // Workout indicator
                Circle()
                    .fill(Color.groveSage)
                    .frame(width: 8, height: 8)

                // Workout name
                Text(sessionManager.activeWorkout?.name ?? "Workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)

                Spacer()

                // Expand indicator
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveSage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.groveSage.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sessionManager.expandWorkout()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.height
                    if value.translation.height < -20 || velocity < -200 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            sessionManager.expandWorkout()
                        }
                    }
                }
        )
    }
}

#Preview {
    MinimizedWorkoutCardView()
        .environment(WorkoutSessionManager())
        .padding()
}
