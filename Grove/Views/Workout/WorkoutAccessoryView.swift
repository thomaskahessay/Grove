import SwiftUI

/// The minimized workout, shown in the tab bar's bottom accessory (iOS 26.1+), like
/// Music's Now Playing bar. Tap to reopen the workout. When the tab bar collapses on
/// scroll, the system shows it inline and it drops to just the name and rest timer.
@available(iOS 26.1, *)
struct WorkoutAccessoryView: View {
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isInline: Bool { placement == .inline }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sessionManager.expandWorkout()
            }
        } label: {
            HStack(spacing: 10) {
                if !isInline {
                    progressRing
                }

                Text(sessionManager.activeWorkout?.name ?? "Workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Rest countdown keeps running while minimized
                if let endDate = sessionManager.restTimerEndDate {
                    Label {
                        Text(timerInterval: Date()...max(Date(), endDate), countsDown: true)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.groveSage)
                    .labelStyle(.titleAndIcon)
                    .transition(.opacity)
                }

                if !isInline {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.groveSage)
                }
            }
            .padding(.horizontal, isInline ? 12 : 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sessionManager.activeWorkout?.name ?? "Workout") in progress")
        .accessibilityHint("Opens the workout")
    }

    /// How far through the workout's sets you are.
    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.groveSage.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: sessionManager.workoutProgressFraction)
                .stroke(Color.groveSage, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionManager.workoutProgressFraction)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.groveSage)
        }
        .frame(width: 24, height: 24)
    }
}
