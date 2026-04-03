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
├── GroveApp.swift              # @main entry point with modelContainer
├── Models/                     # @Model classes: User, Exercise, Workout, ExerciseLog, SetLog,
│                               #   WorkoutTemplate, WorkoutPlan, PersonalRecord, CreatineLog,
│                               #   PlantStage, Enums, InteractionTypes
├── Services/                   # AuthService, HealthKitManager, NotificationService, StreakManager,
│                               #   SmartBuilderEngine, PRDetectionService, AchievementService,
│                               #   WorkoutSessionManager, CloudKitSocialService, ProgressInsightsEngine
├── Views/
│   ├── Onboarding/             # 7-step flow: Carousel → SignIn → Profile → SmartBuilder → HealthKit → Notifications → Ready
│   ├── Home/                   # HomeView, CalendarStripView, DayPlanSheet, WeeklyPlanView, StreakDetailView
│   ├── Workout/                # Creation, ActiveWorkout, Summary, Detail, Share, StreakMoment, HealthKitConnect
│   ├── Progress/               # Dashboard (7 sections) + ExerciseProgressDetailView
│   ├── Social/                 # Feed, FeedItemCard, Interactions, Friends, GroveNetwork, InviteCode
│   ├── Profile/                # Profile, Settings, Achievements, PersonalRecords, NotificationSettings
│   └── Library/                # ExerciseLibrary, AddExercise
├── Components/
│   ├── GlassCard/GlassButton   # Liquid Glass components
│   ├── StreakPlant/             # PlantCanvasRenderer, StreakPlantView, EvolutionTimeline
│   └── FeedCard/               # CardSceneRenderer, tap animations (Water/Seed/Sunlight)
├── Data/                       # ExerciseSeeds (~100), PreviewSampleData, SocialPreviewData
└── docs/PRODUCT_SPEC.md        # Full product specification
```

## Key Conventions

### Liquid Glass Usage
- **DO** apply `.glassEffect()` to: tab bars, toolbars, floating action buttons, bottom sheets
- **DON'T** apply to: list rows, exercise cards, charts, form inputs

### SwiftData Patterns
```swift
@Model class Workout { /* ... */ }
@Query(sort: \Workout.startedAt, order: .reverse) var workouts: [Workout]
@Environment(\.modelContext) private var modelContext
```

### File Naming
- Views: `*View.swift` | Models: singular nouns | Services: `*Service.swift` or `*Manager.swift`

### Units
- Store weights in user's preferred unit (imperial/metric), no conversion needed

## SwiftData Gotchas (Critical)

- **Never use `.rawValue` in `#Predicate`** -- SwiftData stores enums natively; `.rawValue` causes runtime crash
- **Never compare captured enum variables in `#Predicate`** -- SwiftData cannot serialize them; fetch broader results and filter in memory
- **`try?` masks predicate failures** -- a nil result might be a predicate error, not "no results"
- **PR system**: highest weight only; `PRType.estimatedOneRM` exists for legacy data but is never created

## SwiftUI Presentation Gotchas

- Cannot dismiss `fullScreenCover` and present `sheet` in the same state update -- use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)`
- `.symbolEffect(.bounce, value: Bool)` doesn't retrigger -- use an incrementing counter
- All onboarding screens must use `Color.groveBackground` with `.ignoresSafeArea()` to avoid white bars
- FAB Menu on iOS 26 needs `.menuStyle(.button)` + `.buttonStyle(.plain)` to avoid square highlight artifact

## Key Architecture Notes

- **Concurrency**: Swift 6 strict concurrency enabled. `WorkoutSessionManager` and `HealthKitManager` are `@MainActor @Observable`
- **Workout lifecycle**: `workout.user` is set in `endWorkout()`, not at creation time
- **PR detection**: first workout establishes baseline (not flagged as PR); only beating existing records triggers celebration
- **Streak flow**: `endWorkout()` → summary sheet (0.5s delay) → streak moment sheet → update `lastSeenPlantStage`
- **Session resume**: queries `completedAt == nil` on launch; deletes >24h old workouts, resumes recent ones as minimized card
- **HealthKit**: read-only; auth tracked via UserDefaults; `requestAuthorization()` must call `markAuthorized()` on success
- **Auto-extend plans**: `SmartBuilderEngine.extendPlansIfNeeded()` on HomeView appear; fills current + next week from today onward

## Data Model Relationships

```
User ─┬─ workouts: [Workout]  ─┬─ exercises: [ExerciseLog] ── sets: [SetLog]
      ├─ plans: [WorkoutPlan]   └─ templateUsed: WorkoutTemplate?
      ├─ personalRecords: [PersonalRecord] ── exercise: Exercise, setLogID: UUID?
      ├─ customExercises: [Exercise]
      ├─ creatineLogs: [CreatineLog]
      └─ achievements: [Achievement]
```

## Common Tasks

### Starting a new view
Create `[Name]View.swift` in the appropriate `Views/` subfolder. Use Grove color palette. Reference `docs/PRODUCT_SPEC.md` Section 6.

### Adding a new model
Create `@Model` class in `Models/`. Add to `modelContainer` in `GroveApp.swift`. Reference `docs/PRODUCT_SPEC.md` Section 4.

### HealthKit
Read-only from Apple Watch workouts. Reference `docs/PRODUCT_SPEC.md` Section 8.

## Xcode Capabilities

Sign in with Apple, HealthKit, iCloud (CloudKit), Push Notifications

## Info.plist Keys

```xml
<key>NSHealthShareUsageDescription</key>
<string>Grove reads your workout data to track heart rate and calories during your strength training sessions.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Grove needs access to save your workout summary images to your photo library.</string>
```

## Current Status

All core features are implemented: onboarding, workout tracking, weekly planning, streaks with 10-stage plant visualization, personal records, achievements, HealthKit integration, social feed with interactions (water/seed/sunlight), workout sharing, creatine tracking, and notifications. See git history for details.
