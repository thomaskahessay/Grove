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
    static let groveSage = Color(hex: "87A878")        // Primary: buttons, highlights, progress
    static let groveTerracotta = Color(hex: "C4785B")  // Secondary: accents, success, completed
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
│   ├── NotificationService.swift  # Local notification scheduling
│   ├── StreakManager.swift        # Streak calculation logic (static methods)
│   └── WorkoutSessionManager.swift # @Observable - active workout state management
├── Views/
│   ├── Onboarding/
│   │   ├── SignInView.swift
│   │   ├── ProfileSetupView.swift
│   │   └── WeeklyPlanSetupView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── CalendarStripView.swift
│   │   ├── QuickStartSection.swift
│   │   ├── DayPlanSheet.swift         # Sheet for assigning workout/rest to a day
│   │   └── WeeklyPlanView.swift       # Full-screen weekly planner
│   ├── Workout/
│   │   ├── WorkoutCreationView.swift
│   │   ├── ActiveWorkoutView.swift
│   │   ├── MinimizedWorkoutCardView.swift  # Floating card for minimized workouts
│   │   ├── ExerciseFullScreenView.swift
│   │   ├── SetRowView.swift
│   │   └── WorkoutSummaryView.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ExerciseChartView.swift
│   ├── Social/
│   │   └── SocialFeedView.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
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

## Development Progress

### ✅ Completed

**Phase 1: Foundation**
- [x] Xcode project setup (iOS 26, SwiftUI, SwiftData)
- [x] SwiftData models (User, Exercise, Workout, ExerciseLog, SetLog, WorkoutTemplate, WorkoutPlan, Achievement)
- [x] Color system + ColorExtensions.swift
- [x] Liquid Glass components (GlassCard, GlassButton)
- [x] Exercise seed data (~100 exercises)
- [x] Basic tab navigation (Home, Progress, Social, Profile)

**Phase 2: Core Features**
- [x] Home screen with welcome message, calendar strip, weekly stats, next workout preview
- [x] Exercise Library (browse, search, filter by muscle group)
- [x] Add custom exercise form
- [x] Workout creation flow
  - WorkoutCreationView with category selection grid
  - Suggested exercises based on category (tap to add)
  - ExercisePickerView modal for browsing full library
  - FAB (floating action button) with liquid glass styling
  - Quick start buttons with category pre-selection
  - Categories: Push, Pull, Legs, Upper, Lower, Full Body, Chest & Triceps, Back & Biceps, Shoulders, Custom
- [x] Active workout view (ActiveWorkoutView.swift)
  - Full-screen exercise view with swipe navigation (TabView)
  - Card view toggle to see all exercises at once
  - SetRowView with editable weight/reps (text fields + ±5/±1 stepper buttons)
  - Support for decimal weights (e.g., 137.5)
  - Auto-fill subsequent sets from first set values
  - Add/remove sets during workout
  - Manual rest timer with countdown, +30s/-30s controls
  - Add exercise mid-workout
  - Skip/unskip exercise functionality
  - End workout with confirmation
  - Minimize workout to floating card (swipe down or button)
  - Exercise auto-completes when all sets marked done
- [x] Minimized workout card (MinimizedWorkoutCardView.swift)
  - Floating card above tab bar showing workout name + progress
  - Tap or swipe up to return to full workout
  - WorkoutSessionManager for app-wide active workout state
- [x] Profile view with light/dark mode toggle

**Phase 3a: Weekly Planning & Streaks**
- [x] Workout summary screen (post-workout stats + PR callout)
- [x] Weekly calendar planning view (WeeklyPlanView.swift)
  - Full-screen week planner with Mon–Sun layout
  - Week navigator (< This Week >) with chevron buttons
  - Summary bar (X workouts, Y rest days, Z unplanned)
  - Tap day to open DayPlanSheet
- [x] Day plan sheet (DayPlanSheet.swift)
  - Assign workout template or rest day to any date
  - Rest day toggle with moon icon
  - Template picker (user templates + category grid)
  - New template creation with exercise picker + suggested exercises
  - Clear plan option for existing plans
- [x] Assign workouts to days via calendar strip tap or weekly planner
- [x] Calendar strip shows fixed Mon–Sun week (rolls over on Monday)
- [x] Streak tracking logic (StreakManager.swift)
  - recordWorkout: increments/resets streak based on gap
  - recordRestDay: preserves streak (up to 3 consecutive)
  - recalculateStreak: full audit on app launch
  - Vacation mode support
- [x] Streak wired into workout completion (WorkoutSessionManager)
- [x] Plan linking: completed workouts auto-link to today's plan
- [x] Home screen improvements
  - Weekly stats card with progress bar
  - Next workout preview (replaces empty card)
  - Plan My Week button
  - Rest day card

### 📋 Not Started

**Phase 3b: Progress & Achievements**
- [ ] Progress charts (1RM, weight×reps)
- [ ] Personal record detection
- [ ] Achievements system

**Phase 4: HealthKit & Social**
- [ ] HealthKit authorization
- [ ] Workout detection from Apple Watch
- [ ] Heart rate / calorie integration
- [ ] Social feed UI
- [ ] Sharing preferences

**Phase 5: Polish & Launch**
- [ ] Sign in with Apple + Onboarding flow
- [ ] Notification system
- [ ] Profile/Settings screen
- [ ] Data export (CSV/PDF)
- [ ] Vacation mode

### Known Issues
- [x] Streak badge — now wired to StreakManager with recalculation on app launch

---

## Full Specification

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
