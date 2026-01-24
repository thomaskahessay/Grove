import SwiftUI

struct MinimizedWorkoutCardView: View {
    @Environment(WorkoutSessionManager.self) private var sessionManager

    var body: some View {
        HStack(spacing: 12) {
            // Workout indicator
            Circle()
                .fill(Color.groveSage)
                .frame(width: 8, height: 8)

            // Workout info
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionManager.activeWorkout?.name ?? "Workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)

                Text(sessionManager.workoutProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Expand indicator
            Image(systemName: "chevron.up")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.groveSage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.groveSage.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                sessionManager.expandWorkout()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -30 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
