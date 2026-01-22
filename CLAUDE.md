# Grove - Workout Tracking App

## Project Overview

Grove is a native iOS 26 workout tracking app built exclusively on Apple frameworks. Target audience is 5-10 friends/family. Focus on strength training with future expansion to cardio and marathon training.

## Tech Stack (No Third-Party Dependencies)

- **UI**: SwiftUI + iOS 26 Liquid Glass
- **Data**: SwiftData (with CloudKit sync via iCloud)
- **Auth**: Sign in with Apple (AuthenticationServices)
- **Health**: HealthKit + HealthKitUI (read-only from Apple Watch)
- **Charts**: Swift Charts
- **Notifications**: UserNotifications

## Color Palette (Earthy Tones)

```swift
extension Color {
    static let groveTerracotta = Color(hex: "C4785B")  // Primary: buttons, highlights, progress
    static let groveSage = Color(hex: "87A878")        // Secondary: success, completed, streaks
    static let groveWarmSand = Color(hex: "D4C4A8")    // Accent: card backgrounds, dividers
    static let groveCharcoal = Color(hex: "3D3229")    // Text (light mode), backgrounds (dark mode)
    static let groveCream = Color(hex: "F5F1EB")       // Backgrounds (light mode)
    static let groveMutedRust = Color(hex: "A65E4E")   // Alerts: skipped exercises, warnings
}
```

## Project Structure

```
Grove/
├── GroveApp.swift                 # @main entry point with modelContainer
├── Models/
│   ├── User.swift                 # @Model - user profile, preferences, streak
│   ├── Exercise.swift             # @Model - exercise library items
│   ├── Workout.swift              # @Model - completed workout sessions
│   ├── ExerciseLog.swift          # @Model - exercise within a workout
│   ├── SetLog.swift               # @Model - individual set record
│   ├── WorkoutTemplate.swift      # @Model - reusable workout templates
│   ├── WorkoutPlan.swift          # @Model - scheduled workouts on calendar
│   └── Enums.swift                # All enums (MuscleGroup, FitnessGoal, etc.)
├── Services/
│   ├── AuthService.swift          # Sign in with Apple handling
│   ├── HealthKitManager.swift     # HealthKit authorization and queries
│   └── NotificationService.swift  # Local notification scheduling
├── Views/
│   ├── Onboarding/
│   │   ├── SignInView.swift
│   │   ├── ProfileSetupView.swift
│   │   └── WeeklyPlanSetupView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── CalendarStripView.swift
│   │   └── QuickStartSection.swift
│   ├── Workout/
│   │   ├── WorkoutCreationView.swift
│   │   ├── ActiveWorkoutView.swift
│   │   ├── ActiveWorkoutCardView.swift
│   │   ├── ExerciseFullScreenView.swift
│   │   ├── SetRowView.swift
│   │   └── WorkoutSummaryView.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ExerciseChartView.swift
│   ├── Social/
│   │   └── SocialFeedView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── NotificationSettingsView.swift
│   └── Library/
│       ├── ExerciseLibraryView.swift
│       └── AddExerciseView.swift
├── Components/
│   ├── GlassCard.swift            # Reusable Liquid Glass components
│   ├── GlassButton.swift
│   └── ColorExtensions.swift      # Color palette extension
├── Data/
│   └── ExerciseSeeds.swift        # ~100 built-in exercises
└── docs/
    └── PRODUCT_SPEC.md            # Full product specification
```

## Key Conventions

### Liquid Glass Usage
- **DO** apply `.glassEffect()` to: tab bars, toolbars, floating action buttons, bottom sheets
- **DON'T** apply to: list rows, exercise cards, charts, form inputs

### SwiftData Patterns
```swift
// Always use @Model macro
@Model
class Workout {
    // properties...
}

// Use @Query in views
@Query(sort: \Workout.startedAt, order: .reverse) var workouts: [Workout]

// Use @Environment for modelContext
@Environment(\.modelContext) private var modelContext
```

### File Naming
- Views end in `View.swift`
- Models are singular nouns: `Workout.swift` not `Workouts.swift`
- Services end in `Service.swift` or `Manager.swift`

### Units
- Store weights in user's preferred unit (imperial/metric)
- `preferredUnits` in User model determines display
- No conversion needed—just store what user enters

## Current Phase

See `docs/PRODUCT_SPEC.md` for full specification including:
- Detailed data models with all properties
- Screen-by-screen specifications
- User flows
- HealthKit integration details
- Feature specifications
- Development roadmap

## Quick Reference: Data Model Relationships

```
User
 ├── workouts: [Workout]
 ├── plans: [WorkoutPlan]
 └── customExercises: [Exercise]

Workout
 ├── user: User
 ├── exercises: [ExerciseLog]
 └── templateUsed: WorkoutTemplate?

ExerciseLog
 ├── workout: Workout
 ├── exercise: Exercise
 └── sets: [SetLog]

WorkoutPlan
 ├── user: User
 ├── template: WorkoutTemplate?
 └── completedWorkout: Workout?
```

## Common Tasks

### Starting a new view
```
Create [ViewName]View.swift following the structure in Views/. 
Use the Grove color palette. Reference PRODUCT_SPEC.md Section 6 for screen specs.
```

### Adding a new model
```
Create the @Model class in Models/. 
Add it to the modelContainer in GroveApp.swift.
Reference PRODUCT_SPEC.md Section 4 for full property list.
```

### Implementing HealthKit
```
Reference PRODUCT_SPEC.md Section 8 for the integration flow.
Key: We READ from Apple Fitness workouts, we don't create our own HKWorkout sessions.
```

## Xcode Capabilities Required

- Sign in with Apple
- HealthKit
- iCloud (CloudKit)
- Push Notifications (for local notifications)

## Info.plist Keys

```xml
<key>NSHealthShareUsageDescription</key>
<string>Grove reads your workout data to track heart rate and calories during your strength training sessions.</string>
```
