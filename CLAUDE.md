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
│   ├── User.swift                 # @Model - user profile, preferences, streak, plant state
│   ├── Exercise.swift             # @Model - exercise library items
│   ├── Workout.swift              # @Model - completed workout sessions
│   ├── ExerciseLog.swift          # @Model - exercise within a workout
│   ├── SetLog.swift               # @Model - individual set record
│   ├── WorkoutTemplate.swift      # @Model - reusable workout templates
│   ├── WorkoutPlan.swift          # @Model - scheduled workouts on calendar
│   ├── PersonalRecord.swift       # @Model - PR tracking (max weight, est. 1RM)
│   ├── PlantStage.swift           # Enum: 5 growth stages with streak thresholds
│   └── Enums.swift                # All enums (MuscleGroup, FitnessGoal, etc.)
├── Services/
│   ├── AuthService.swift          # Sign in with Apple handling
│   ├── HealthKitManager.swift     # HealthKit authorization and queries
│   ├── NotificationService.swift  # Local notification scheduling
│   ├── StreakManager.swift        # Streak calculation logic (static methods) + wilting
│   ├── PRDetectionService.swift   # PR detection after workout completion
│   ├── AchievementService.swift   # Achievement detection + progress tracking
│   ├── MotivationalMessages.swift # Plant-themed motivational messages
│   └── WorkoutSessionManager.swift # @MainActor @Observable - active workout + streak moment state
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
│   │   ├── WeeklyPlanView.swift       # Full-screen weekly planner
│   │   └── StreakDetailView.swift     # Full streak detail: plant, stats, progress, timeline
│   ├── Workout/
│   │   ├── WorkoutCreationView.swift
│   │   ├── ActiveWorkoutView.swift
│   │   ├── MinimizedWorkoutCardView.swift  # Floating card for minimized workouts
│   │   ├── ExerciseFullScreenView.swift
│   │   ├── SetRowView.swift
│   │   ├── WorkoutSummaryView.swift         # Post-workout stats + PR celebration
│   │   ├── WorkoutDetailView.swift         # Past workout detail view + PR display
│   │   └── StreakMomentView.swift          # Post-workout streak celebration screen
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ExerciseChartView.swift
│   ├── Social/
│   │   └── SocialFeedView.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── AchievementsGalleryView.swift  # Achievement gallery with progress
│   │   └── NotificationSettingsView.swift
│   └── Library/
│       ├── ExerciseLibraryView.swift
│       └── AddExerciseView.swift
├── Components/
│   ├── GlassCard.swift            # Reusable Liquid Glass components
│   ├── GlassButton.swift
│   ├── ConfettiView.swift         # Celebratory confetti animation
│   ├── ColorExtensions.swift      # Color palette extension
│   └── StreakPlant/
│       ├── PlantCanvasRenderer.swift  # Canvas drawing logic for all plant stages
│       ├── StreakPlantView.swift       # Reusable animated plant view
│       └── EvolutionTimelineView.swift # Horizontal stage progression timeline
├── Data/
│   ├── ExerciseSeeds.swift        # ~100 built-in exercises
│   └── PreviewSampleData.swift    # Sample data for SwiftUI previews
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
  - "Your Templates" section showing saved user templates (tap to load exercises)
  - Suggested exercises based on category (tap to add, stable until refresh)
  - ExercisePickerView modal for browsing full library
  - FAB (floating action button) with liquid glass styling
  - Quick start buttons with category pre-selection
  - Categories: Push, Pull, Legs, Upper, Lower, Full Body, Chest & Triceps, Back & Biceps, Shoulders, Custom
  - Custom category uses slider icon (consistent across app)
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
  - End workout with save or discard options (Menu dropdown)
  - Minimize workout to floating card (swipe down or button)
  - Exercise auto-completes when all sets marked done
- [x] Minimized workout card (MinimizedWorkoutCardView.swift)
  - Floating card above tab bar showing workout name + progress
  - Tap or swipe up to return to full workout
  - WorkoutSessionManager for app-wide active workout state
- [x] Profile view with light/dark mode toggle

**Phase 3a: Weekly Planning & Streaks**
- [x] Workout summary screen (post-workout stats + PR callout + confetti celebration)
- [x] Weekly calendar planning view (WeeklyPlanView.swift)
  - Full-screen week planner with Mon–Sun layout
  - Week navigator (< This Week >) with chevron buttons
  - Summary bar (X workouts, Y rest days, Z unplanned)
  - Tap day to open DayPlanSheet (completed days locked from editing)
  - Completed days show checkmark icon (including today)
- [x] Day plan sheet (DayPlanSheet.swift)
  - Assign workout template or rest day to any date
  - Rest day toggle with moon icon
  - Template picker (user templates + category grid with filter)
  - Multiple templates per category supported (+ New button in header)
  - Template deletion from row
  - New template creation with exercise picker + suggested exercises
  - Suggested exercises stay stable until refresh button tapped
  - Duplicate template name validation (case-insensitive)
  - Cancelling template creation resets category selection
  - Clear plan option for existing plans
- [x] Assign workouts to days via calendar strip tap or weekly planner
- [x] Calendar strip with week navigation (CalendarStripView.swift)
  - Chevron buttons and swipe gesture to navigate between weeks
  - Week label: "This Week" / "Last Week" / "Next Week" / date range
  - Today highlight only shows on current week
  - Past completed days tap → WorkoutDetailView (navigation push)
  - Past rest/empty days → no action
  - Current/future days tap → DayPlanSheet (same as before)
  - Month view toggle: tap the center label to switch between week strip and full month grid
  - Month grid: LazyVGrid with M–S header, day circles (30×30), status dots (14×14)
  - Chevrons and swipe navigate months when in month mode
  - Week↔month offset sync keeps displayed time range consistent when toggling
  - Same tap behavior and status indicators in both views
- [x] Streak tracking logic (StreakManager.swift)
  - recordWorkout: increments streak; user has until end of next calendar day to act
  - recordRestDay: preserves streak without incrementing (max 3 consecutive)
  - recalculateStreak: full audit on app launch with today as grace period
  - Streak breaks at midnight if user doesn't complete a workout or mark rest day
  - Vacation mode support
- [x] Streak wired into workout completion (WorkoutSessionManager)
- [x] Plan linking: completed workouts auto-link to today's plan
- [x] Home screen improvements
  - Weekly stats card with progress bar
  - Next workout preview (replaces empty card)
  - Plan My Week button
  - Rest day card
  - Completed workout card with "what's next" section (tomorrow's plan or plan nudge)
  - Start workout from today's plan card
  - App logo in navigation bar (replaces text)
  - Recent workouts tappable → WorkoutDetailView

**Phase 3b: Workout History & Auto-fill**
- [x] WorkoutDetailView (Views/Workout/WorkoutDetailView.swift)
  - Shows workout date, duration, total volume
  - Stats grid: exercises completed, total sets, total volume
  - Exercise list with sets (weight × reps for each)
  - Status icons for completed/skipped exercises
- [x] Auto-fill from previous workouts
  - When starting a workout, weight/reps pre-filled from last completed session for each exercise
  - Number of sets matches previous session (or defaults to 3 if no history)
  - Works for both quick start and planned workouts
- [x] Missed workout day restrictions
  - Past days with incomplete workouts can only be changed to rest days
  - Cannot reassign missed days to different workout templates
  - Info message explains user can mark as rest to preserve streak
- [x] Day plan sheet improvements
  - When template selected, shows exercise list instead of categories
  - "Change" button to switch back to template picker
- [x] Active workout improvements
  - End button uses Menu dropdown (Save/Discard options appear below button)
  - Discard workout option deletes all workout data without saving
  - WorkoutSessionManager.discardWorkout() handles cleanup

**Phase 3c: Progress Charts**
- [x] Progress charts (ProgressView.swift)
  - Exercise picker modal with search (sorted by workout count)
  - Large exercise name header with workout count, tap to open picker
  - Three metrics via dropdown menu: Estimated 1RM (Brzycki/Epley), Best Set, Total Volume
  - Time range picker via dropdown: 1M / 3M / 6M / All
  - Swift Charts with line + area + point marks
  - Interactive tooltips on tap/drag showing value and date
  - Stats card: Current, Change, Best, Max (highest weight ever)
  - Pill-style filter buttons with subtle background
  - Empty states for no data

**Phase 3d: Personal Records**
- [x] PersonalRecord model (PRType: maxWeight, estimatedOneRM)
  - Brzycki formula for ≤10 reps, Epley for >10 reps
  - Tracks weight, reps, calculated value, setLogID link
- [x] PRDetectionService (Services/PRDetectionService.swift)
  - Detects all-time PRs on workout completion (not per-set)
  - Compares against stored PRs per exercise
  - Saves new PersonalRecord entries to SwiftData
  - First workout saves baselines only (not flagged as PRs)
  - Only flags as "new PR" when beating an existing record
- [x] PR display in workout summary (WorkoutSummaryView)
  - Trophy-styled section with terracotta accent
  - Shows both Max Weight and Est. 1RM PRs
  - PRRow reusable component
- [x] PR display in past workout detail (WorkoutDetailView)
  - Queries PersonalRecords by matching setLogID to workout's sets
  - Section appears between header stats and exercise list
- [x] User ↔ PersonalRecord relationship (cascade delete)

**Phase 3e: Achievements**
- [x] Achievement model (Models/Achievement.swift)
  - AchievementType enum: firstRep, weekWarrior, consistent, prCrusher, planner, centuryClub, ironWill
  - User ↔ Achievement relationship (cascade delete)
- [x] AchievementService (Services/AchievementService.swift)
  - Checks all achievement conditions on workout completion
  - Progress tracking for gallery (current/target values per type)
  - prCrusher requires beating a previous record (not first-time baselines)
- [x] Achievement display in workout summary (WorkoutSummaryView)
  - Trophy-styled section for newly unlocked achievements
  - AchievementRow reusable component
- [x] AchievementsGalleryView (Views/Profile/AchievementsGalleryView.swift)
  - Summary header (X/7 earned)
  - Progress bars for locked achievements
  - Completed achievements: green filled icon + checkmark badge
  - Earned date display
- [x] Achievements in Progress tab (segmented picker: Exercises / Achievements)
- [x] Latest achievement card on Home screen (links to gallery)
- [x] Workout linked to user on completion (WorkoutSessionManager.endWorkout)

**Phase 3f: Streak Plant ("Your Grove")**
- [x] PlantStage enum (Models/PlantStage.swift)
  - 5 stages: Seed (0), Sprout (1-2), Seedling (3-6), Young Plant (7-59), Tree (60+)
  - Progress calculation, stage-up detection, display names
- [x] User model additions: previousStreak, lastSeenPlantStage, isStreakWilted, wiltedAtStage
- [x] StreakManager wilting support
  - Records previousStreak on streak reset, sets wiltedAtStage/isStreakWilted on breaks
- [x] PlantCanvasRenderer (Components/StreakPlant/PlantCanvasRenderer.swift)
  - SwiftUI Canvas API with Bezier curves for all 5 stages + wilted variants
  - Sage green leaves, terracotta trunk, warm sand soil
  - swayOffset parameter for ambient leaf animation
- [x] StreakPlantView (Components/StreakPlant/StreakPlantView.swift)
  - TimelineView(.animation) for efficient ambient sway (sin wave)
  - Stage-up pop animation, celebration pulse, configurable size/label
- [x] MotivationalMessages (Services/MotivationalMessages.swift)
  - Three categories: continuing, stageUp, streakBroken (~5-6 each)
  - Day-of-year seeded selection (consistent within a day)
- [x] EvolutionTimelineView (Components/StreakPlant/EvolutionTimelineView.swift)
  - Horizontal scroll with colored stage circles and connector lines
- [x] StreakDetailView (Views/Home/StreakDetailView.swift)
  - Large plant (300pt), stage name, progress bar, stats row, evolution timeline, motivational message
- [x] StreakMomentView (Views/Workout/StreakMomentView.swift)
  - Post-workout celebration: plant (250pt), streak title, stage-up callout, dismiss button
- [x] WorkoutSessionManager streak moment flow
  - Captures pre/post PlantStage in endWorkout(), builds StreakMomentData
  - Chains: summary dismiss → 0.5s delay → streak moment sheet → dismiss → update lastSeenPlantStage
- [x] HomeView integration
  - Hero StreakPlantView (200pt) between welcome and today's card
  - NavigationLink to StreakDetailView (replaces old StreakBadge)
- [x] ContentView integration: streak moment sheet after summary sheet
- [x] ProfileView integration: leaf icon streak label → NavigationLink to StreakDetailView

### 📋 Not Started

**Phase 4: HealthKit & Social**
- [ ] HealthKit authorization
- [ ] Workout detection from Apple Watch
- [ ] Heart rate / calorie integration
- [ ] Social feed UI
- [ ] Sharing preferences

**Phase 5: Polish & Launch**
- [x] Sign in with Apple + Onboarding flow
  - WelcomeCarouselView (3-slide carousel → Get Started)
  - SignInView (Sign in with Apple + Debug skip button)
  - ProfileSetupView (photo, name, units, fitness goal 2×2 grid, experience level)
  - WeeklyPlanSetupView (preset split picker → schedule preview → template + plan creation)
  - OnboardingReadyView ("You're all set! Let's grow." → sets onboardingCompletedAt)
  - Resume logic: relaunch after sign-in but before completion resumes at ProfileSetup
  - Plans only created from today onward; rest days created with isRestDay=true
- [ ] Notification system
- [x] Profile/Settings screen
  - Profile header with photo, name, streak, workout count
  - Account: inline name edit, fitness goal + experience level pickers
  - Preferences: weight units, vacation mode with date pickers
  - Sharing Defaults: 4 toggles for social feed sharing
  - Links: Notifications (→ NotificationSettingsView), Achievements (→ AchievementsGalleryView)
  - Appearance: System/Light/Dark with checkmark indicator
  - Data: Export History (coming soon), Delete Account with confirmation
  - NotificationSettingsView: 5 notification toggles + quiet hours (From/To DatePickers)
- [ ] Data export (CSV/PDF)
- [ ] Vacation mode

### Known Issues & Fixes
- [x] Streak badge — now wired to StreakManager with recalculation on app launch
- [x] Workout completion crash — fullScreenCover dismissal + sheet presentation conflict; fixed with 0.5s delay before showing summary
- [x] PR predicate crash — SwiftData #Predicate cannot use .rawValue on enum properties; fixed by comparing enum directly
- [x] PR predicate silent failure — SwiftData #Predicate cannot serialize captured enum values; fixed by filtering enum type in memory instead of in predicate
- [x] Workouts not linked to user — workout.user was never set at creation time; now set in endWorkout()
- [x] WorkoutSessionManager concurrency — added @MainActor for Swift 6 strict concurrency
- [x] FAB visible on all tabs — now hidden on Progress/Social/Profile; only shown on Home tab via TabView(selection:)
- [x] Streak badge not showing on first login — added .navigationTitle("") to force nav bar render
- [x] Welcome message width — added .frame(maxWidth: .infinity, alignment: .leading) to match card widths
- [x] Home nav bar clutter — removed Grove logo from .principal and redundant profile button from toolbar
- [x] Profile background grey in light mode — added .scrollContentBackground(.hidden) + .background(Color.groveBackground)

### SwiftData Gotchas
- **Never use `.rawValue` in `#Predicate`** — SwiftData stores enums natively; `.rawValue` causes runtime crash
- **Never compare captured enum variables in `#Predicate`** — SwiftData cannot serialize them; fetch broader results and filter in memory
- **Use `try?` carefully** — it silently swallows predicate validation errors; prefer fetching broader and filtering in Swift when enum types are involved

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
 ├── personalRecords: [PersonalRecord]
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

PersonalRecord
 ├── user: User
 ├── exercise: Exercise
 └── setLogID: UUID? (links to SetLog that achieved the PR)

Achievement
 ├── user: User
 ├── type: AchievementType
 ├── unlockedAt: Date
 └── relatedData: String?
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

---

## 💡 Future Ideas

### Streak Plant Expansion
- Add 3 more growth stages: Bush (14-29), Sapling (30-59), Grove Tree (100+)
  - Currently 5 stages implemented; PlantStage enum is extensible (insert cases + update thresholds)
  - PlantCanvasRenderer needs new draw methods for each additional stage
