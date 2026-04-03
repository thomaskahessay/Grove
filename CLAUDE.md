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
│   ├── CreatineLog.swift          # @Model - daily creatine intake log
│   ├── PlantStage.swift           # Enum: 10 growth stages with streak thresholds
│   ├── Enums.swift                # All enums (MuscleGroup, FitnessGoal, etc.)
│   └── InteractionTypes.swift     # InteractionType, InteractionSummary, SeedMessage, RootConnection, etc.
├── Services/
│   ├── AuthService.swift          # Sign in with Apple handling
│   ├── HealthKitManager.swift     # HealthKit authorization and queries
│   ├── NotificationService.swift  # Local notification scheduling
│   ├── StreakManager.swift        # Streak calculation logic (static methods) + wilting
│   ├── SmartBuilderEngine.swift   # Smart Builder: exercise selection, template/plan generation, auto-extend
│   ├── PRDetectionService.swift   # PR detection after workout completion
│   ├── AchievementService.swift   # Achievement detection + progress tracking
│   ├── MotivationalMessages.swift # Plant-themed motivational messages
│   ├── WorkoutSessionManager.swift # @MainActor @Observable - active workout + streak moment state + shared createAndStartWorkout helper
│   ├── CloudKitSocialService.swift # @MainActor @Observable - social feed, interactions, friends, invite codes
│   ├── InviteCodeGenerator.swift  # Generates unique invite codes
│   ├── SeedMessages.swift         # Preset seed message options
│   └── ProgressInsightsEngine.swift # Auto-generated progress insights (volume trends, PR momentum, consistency)
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingContainerView.swift  # 7-step onboarding flow container
│   │   ├── SignInView.swift
│   │   ├── ProfileSetupView.swift
│   │   ├── WelcomeCarouselView.swift       # 3-slide intro carousel
│   │   ├── OnboardingReadyView.swift       # Final "You're all set" screen
│   │   ├── WeeklyPlanSetupView.swift      # Legacy (replaced by SmartBuilder)
│   │   ├── HealthKitOnboardingView.swift  # Optional Apple Health connection during onboarding
│   │   ├── NotificationOnboardingView.swift # Optional notification setup during onboarding
│   │   └── SmartBuilder/
│   │       ├── SmartBuilderView.swift     # 4/5-step workout builder container
│   │       ├── SmartBuilderState.swift    # @Observable state for builder flow
│   │       ├── DaysPerWeekStep.swift      # Step 1: training days selection
│   │       ├── WorkoutLengthStep.swift    # Step 2: workout duration
│   │       ├── SplitAndStyleStep.swift    # Step 3: split type + rep range
│   │       ├── CustomSplitConfigStep.swift # Step 4 (custom only): name days + pick muscle groups
│   │       └── ExerciseSelectionStep.swift # Step 4/5: per-day exercise customization
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
│   │   ├── WorkoutDetailView.swift         # Past workout detail view + PR display + share
│   │   ├── WorkoutShareCardView.swift     # Rendered share image (compact/detailed modes)
│   │   ├── StreakMomentView.swift          # Post-workout streak celebration screen
│   │   ├── HealthKitConnectView.swift     # Post-workout Apple Watch data connect sheet
│   │   └── ExercisePickerView.swift       # Exercise browser for adding to workouts
│   ├── Progress/
│   │   ├── ProgressView.swift                 # Dashboard: weekly summary, PRs, exercises, consistency, program, insights, achievements
│   │   └── ExerciseProgressDetailView.swift   # Drill-down: exercise chart, stats, filters, recent workouts
│   ├── Social/
│   │   ├── SocialFeedView.swift           # Main activity feed (Canopy/Soil filter)
│   │   ├── FeedItemCard.swift             # Feed card with evolving plant background
│   │   ├── InteractionBar.swift           # Water/Seed/Sunlight action buttons
│   │   ├── CanopySoilToggle.swift         # Feed filter toggle
│   │   ├── SunlightPromptCard.swift       # Sunlight availability prompt
│   │   ├── WorkoutInteractionDetailView.swift # Detailed view of post interactions
│   │   ├── SeedPickerSheet.swift          # Seed message picker
│   │   ├── FriendProfileView.swift        # Friend profile page
│   │   ├── GroveNetworkView.swift         # Root connection visualization
│   │   ├── InteractionBreakdownSheet.swift # Bidirectional interaction detail
│   │   ├── AddFriendSheet.swift           # Add friend via invite code
│   │   └── InviteCodeCard.swift           # Invite code display/generate
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── SettingsView.swift             # Full settings: account, preferences, vacation, appearance
│   │   ├── AchievementsGalleryView.swift  # Achievement gallery with progress
│   │   ├── PersonalRecordsView.swift      # Personal records list
│   │   └── NotificationSettingsView.swift
│   └── Library/
│       ├── ExerciseLibraryView.swift
│       └── AddExerciseView.swift
├── Components/
│   ├── GlassCard.swift            # Reusable Liquid Glass components
│   ├── GlassButton.swift
│   ├── ConfettiView.swift         # Celebratory confetti animation
│   ├── ColorExtensions.swift      # Color palette extension
│   ├── StreakPlant/
│   │   ├── PlantCanvasRenderer.swift  # Canvas drawing logic for all plant stages
│   │   ├── StreakPlantView.swift       # Reusable animated plant view
│   │   └── EvolutionTimelineView.swift # Horizontal stage progression timeline
│   └── FeedCard/
│       ├── CardGrowthState.swift          # Maps interaction counts → visual growth params
│       ├── CardSceneRenderer.swift        # Canvas: soil, grass, plant, flowers for card bg
│       ├── CardSceneBackgroundView.swift   # SwiftUI wrapper with TimelineView (20fps sway)
│       ├── WaterTapAnimation.swift        # Particle drops + ripple splash animation
│       ├── SeedTapAnimation.swift         # Seed drop from above + sprout unfurl animation
│       └── SunlightTapAnimation.swift     # Golden light rays + bloom animation
├── Data/
│   ├── ExerciseSeeds.swift        # ~100 built-in exercises
│   ├── PreviewSampleData.swift    # Sample data for SwiftUI previews
│   └── SocialPreviewData.swift    # Mock social data (friends, feed items, interactions)
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
  - FAB context menu (Menu with contextual options: Start [planned template], Add to Plan, New Workout)
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
  - Inline rest timer row below completed sets (replaces overlay)
  - Per-set history hints showing previous workout's weight/reps
  - Add exercise mid-workout
  - Skip/unskip exercise functionality
  - End workout with save or discard options (Menu dropdown)
  - Minimize workout to floating card (swipe down or button)
  - Exercise auto-completes when all sets marked done
  - Last exercise shows disabled "Done" button (not disabled "Next")
- [x] Minimized workout card (MinimizedWorkoutCardView.swift)
  - Floating card above tab bar showing workout name + progress bar (fills as exercises complete/skip)
  - Tap or swipe up to return to full workout (lower minimum distance + velocity-based trigger)
  - Live drag tracking on swipe-down gesture with resistance and velocity threshold
  - WorkoutSessionManager for app-wide active workout state
- [x] Workout session resume on app relaunch
  - `resumeIncompleteWorkout()` queries for workouts with `completedAt == nil`
  - Resumes as minimized floating card (all set/rep data persists via SwiftData)
- [x] Profile view with light/dark mode toggle

**Phase 3a: Weekly Planning & Streaks**
- [x] Workout summary screen (post-workout stats + PR callout + confetti celebration)
- [x] Weekly calendar planning view (WeeklyPlanView.swift)
  - Full-screen week planner with Mon–Sun layout
  - Week navigator (< This Week >) with chevron buttons
  - Summary bar (X workouts, Y rest days, Z unplanned)
  - Tap day to open DayPlanSheet (completed days locked from editing)
  - Completed days show category icon (filled green) instead of checkmark
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
  - Completed days show category icon (filled green) matching planned day icon
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
  - All cards use glassEffect (liquid glass) with shadow for light mode visibility

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
  - Templates shown only after category is selected (not before)
  - Edit template support (rename, add/remove exercises from existing templates)
- [x] Active workout improvements
  - End button uses Menu dropdown (Save/Discard options appear below button)
  - Discard workout option deletes all workout data without saving
  - WorkoutSessionManager.discardWorkout() handles cleanup
  - Done button correctly appears when last exercise is skipped

**Phase 3c: Progress Dashboard**
- [x] Progress dashboard (ProgressView.swift) — single scrollable page with 7 sections:
  1. **Weekly Summary**: day-by-day indicators (completed/planned/rest/missed), workout count, total volume
  2. **Personal Records showcase**: horizontal scroll of PR cards with "NEW" badge, tap → exercise chart, "See All" → PersonalRecordsView
  3. **Exercise Progress**: top 5 exercises by workout count with mini sparklines, tap → ExerciseProgressDetailView, "View All Exercises" picker
  4. **Consistency**: plan adherence ring (last 4 weeks), weekly frequency bar chart (8 weeks) with goal line, current/longest streak row
  5. **Your Program**: split name, days/week, rep range, weekday training slot indicators, template-to-day mapping
  6. **Insights**: 1-2 auto-generated contextual messages via ProgressInsightsEngine (volume trends, PR momentum, consistency, streak milestones)
  7. **Achievements**: compact icon row (7 types), "X/7 earned", closest-to-unlock "Next up" card, "See All" → AchievementsGalleryView
- [x] ExerciseProgressDetailView (drill-down from exercise list or PR card tap)
  - Exercise picker header with workout count
  - Three metrics via dropdown: Max Weight, Best Set, Total Volume
  - Time range picker: 1M / 3M / 6M / All
  - Swift Charts with line + area + point marks
  - Interactive tooltips on tap/drag showing value and date
  - Stats row: Current, Change, Best, Max
  - Recent workouts section for selected exercise
  - glassEffect applied to exercise header, stats card, recent workouts section, and tooltip
- [x] ProgressInsightsEngine (Services/ProgressInsightsEngine.swift)
  - Static computation of contextual insights from workout data
  - Volume trend (week-over-week), PR momentum, consistency, streak milestones
  - Returns top 2 most relevant insights
- [x] PRs moved from Profile to Progress tab (PR showcase section)
  - ProfileView quick access cards simplified to Achievements only (full-width card)
  - PR count still shown in Profile stats card for quick reference

**Phase 3d: Personal Records**
- [x] PersonalRecord model (simplified: highest weight only)
  - PR = highest weight ever lifted for an exercise, regardless of reps
  - PRType enum retains `.estimatedOneRM` case for legacy data compatibility but no longer creates them
  - Tracks weight, reps, value (always equals weight), setLogID link
- [x] PRDetectionService (Services/PRDetectionService.swift)
  - Detects highest-weight PRs on workout completion (not per-set)
  - First workout establishes baseline (not flagged as PR)
  - Subsequent workouts that beat baseline are flagged as new PRs
  - Only `.maxWeight` type records are created going forward
- [x] PR display in workout summary (WorkoutSummaryView)
  - Trophy-styled section with terracotta accent
  - Shows "New PR" with weight value
- [x] PR display in past workout detail (WorkoutDetailView)
  - Queries PersonalRecords by matching setLogID to workout's sets
  - Sorted by achievedAt to prevent reordering
  - Filters to `.maxWeight` type only (ignores legacy `.estimatedOneRM` records)
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
  - glassEffect card styling throughout
- [x] Achievements in Progress tab (segmented picker: Exercises / Achievements)
- [x] Latest achievement card on Home screen (links to gallery)
- [x] Workout linked to user on completion (WorkoutSessionManager.endWorkout)

**Phase 3f: Streak Plant ("Your Grove")**
- [x] PlantStage enum (Models/PlantStage.swift)
  - 10 stages: Seed (0), Sprout (1-2), Seedling (3-6), Young Plant (7-13), Bush (14-20), Flowering Bush (21-29), Sapling (30-44), Young Tree (45-59), Tree (60-99), Grove Tree (100+)
  - Progress calculation, stage-up detection, display names
- [x] User model additions: previousStreak, lastSeenPlantStage, isStreakWilted, wiltedAtStage
- [x] StreakManager wilting support
  - Records previousStreak on streak reset, sets wiltedAtStage/isStreakWilted on breaks
- [x] PlantCanvasRenderer (Components/StreakPlant/PlantCanvasRenderer.swift)
  - SwiftUI Canvas API with Bezier curves for all 10 stages + wilted variants
  - Height-based quadratic sway: base stays planted, flex increases upward
  - Gradient fills, teardrop leaves, curved trunks with bark texture
  - Roots, fruits with highlights, 5-petal flowers, layered soil, multi-shade canopy
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

**Phase 3g: Workout Sharing**
- [x] WorkoutShareCardView (Views/Workout/WorkoutShareCardView.swift)
  - Two modes: Compact (340pt wide) and Detailed (390pt wide)
  - Compact: header bar, title, stats row, all exercises with smart set summaries, footer
  - Detailed: full date, title + duration, divider, stats row, exercises with individual set rows, footer
  - Smart compact summaries: same sets → "3×10 @ 135 lbs", same weight → "135 lbs · 10,8,6", varying → "3 sets · 135-155 lbs"
  - PR count in stats row (terracotta accent, conditional)
  - Star icon beside PR sets in detailed view (matched via setLogID)
  - Color scheme passed via .environment(\.colorScheme) for ImageRenderer compatibility
  - No @Query or @Environment(\.modelContext) — all data passed as parameters
- [x] Share button in WorkoutDetailView toolbar (square.and.arrow.up)
  - ImageRenderer at screen scale, deferred to next run loop tick to avoid blank first render
  - Custom WorkoutShareSheet with image preview, compact/detailed toggle, Share + Save to Photos buttons
  - LPLinkMetadata via UIActivityItemSource for native share sheet image preview
  - NSPhotoLibraryAddUsageDescription in Info.plist for Save to Photos

**Phase 4: HealthKit & Social**
- [x] HealthKit integration (read-only)
  - HealthKitManager: @Observable singleton with HKHealthStore
  - Read-only access: workouts, heart rate, active energy burned
  - `requestAuthorization()` + `checkAuthorizationStatus()` with UserDefaults persistence
  - `findOverlappingWorkouts()`: queries HKWorkouts in ±30min overlap window
  - `fetchWorkoutsForDay()`: queries all workouts on a specific date for manual browsing
  - `bestOverlapMatch()`: picks workout with most time overlap
  - `getHeartRateStats()`: min/avg/max BPM via HKStatisticsQuery
  - `getCalories()`: kcal via HKStatisticsQuery with cumulativeSum
  - `populateWorkout()`: orchestrates queries and writes to Workout model
  - `HKHealthStore.isHealthDataAvailable()` guard on all calls
- [x] HealthKit onboarding screen (HealthKitOnboardingView)
  - Inserted between `.weeklyPlan` and `.ready` in OnboardingContainerView
  - Apple Health icon, benefits list, "Connect Apple Health" button
  - "Not Now" skip — never gates onboarding progress
  - Checkmark confirmation on success, auto-continues after 1s
- [x] Post-workout HealthKit connect flow (HealthKitConnectView)
  - Pre-checks for overlapping workouts before showing sheet (no blank flash)
  - Auto-matched view: shows best match preview with "Connect" button
  - Browse view: same-day Apple Watch workouts with Grove-styled card list
  - "Choose Different" to switch between matches
  - Empty state when no workouts found on that day
- [x] HealthKit data display
  - WorkoutSummaryView: Apple Watch section with avg BPM, HR range, kcal StatCards
  - WorkoutDetailView: HR/calories row with red heart + orange flame icons, system background
  - WorkoutDetailView: Apple Watch toolbar button for retroactive connect on past workouts
  - WorkoutShareCardView: kcal/HR as subtitle (compact: under date, detailed: beside duration)
  - PR star indicator on sets in workout detail view
- [x] Apple Health in Settings
  - Taps to request authorization (if not connected) or open Apple Health app (if connected)
  - Status label: Connected / Not Connected / Not Available
- [x] Workout session resume cleanup
  - Old abandoned workouts (>24h) automatically deleted on app launch
  - Only workouts started within 24 hours are resumed as minimized card
- [x] All Workouts history view
  - Accessible via chevron on "Recent Workouts" header in HomeView
  - Full workout history grouped by month (e.g. "March 2026")
  - Each workout tappable → WorkoutDetailView
- [x] Social feed UI
  - SocialFeedView with Canopy (all posts) / Soil (interacted-only) filter toggle
  - GroveNetworkView: visual root connection graph between friends
  - FeedItemCard with evolving plant background (Canvas API)
    - Background grows based on interactions: soil (water) → grass → plant (seeds) → flowers (sunlight)
    - Sunlight guarantees a minimum bush (plantStage 3.0) so flowers always have a plant to bloom on
    - Permanent golden light rays from top-right corner when sunlight is given (rendered in separate Canvas at full opacity)
    - Seed growth uses unique senders (not total count) to reflect community engagement
    - CardSceneRenderer draws landscape scene at 35% opacity with gradient scrim for text readability
    - CardSceneRenderer.draw() accepts soilPosition parameter (default 0.85) to control soil line placement
    - CardSceneBackgroundView uses TimelineView at 20fps with drawingGroup() for scroll performance
  - Three Canvas-based tap animations replacing placeholder overlays:
    - Water: particle droplets fall with gravity, splash ripples on soil, soil darkens at impact
    - Seed: seed drops from above card with spin + shadow, burrows into soil, sprout unfurls with spring animation, sparkle particles
    - Sunlight: 6 golden light rays fan from top, bloom glow at plant, warm rising particles
  - Each animation has distinct haptic feedback (light/medium/rigid)
  - InteractionBar hides used buttons (water hidden after watering, sunlight hidden after sunlit)
  - Interaction counters hidden from feed cards, shown only in detail view (showCounts parameter)
  - Seed animation triggers optimistically on picker selection (before CloudKit round-trip)
  - Own posts appear in feed with "Your Workout" header (sage-colored), no interaction buttons
  - Own posts: detail view hides bottom action bar (can't interact with yourself)
  - CloudKitSocialService.fetchFeed() includes myAppleUserID in query
  - Invite code system: generate/copy code, add friend via code
  - Root connections with 4 levels (Scattered → Growing → Intertwined → Deep Roots)
  - WorkoutInteractionDetailView: full interaction breakdown (waterers, sunlighters, seeds with messages)
    - Hero section with CardSceneBackgroundView (soilPosition 0.55) behind header + stats
    - Header (avatar, name, date) at top; stats card at bottom with plants sprouting between them
    - PR border, waterShimmer, sunlightGlow modifiers match feed card styling
  - Profile: "Shared Workouts" section shows own posts with mini plant preview + interaction icons
  - SeedPickerSheet for choosing/writing seed messages
  - InteractionBreakdownSheet for bidirectional interaction stats between two users
- [x] Creatine tracking (opt-in)
  - `CreatineLog` model with date + user relationship
  - User model: `trackCreatine: Bool`, `notifyCreatineReminder: Bool`
  - ProfileSetupView: opt-in toggle during onboarding (between units and continue)
  - SettingsView: toggle in Preferences section
  - HomeView: compact tappable pill (one tap to log, shows streak counter)
  - ProgressView: monthly consistency card with progress bar + daily dot grid
  - NotificationService: daily 9 AM reminder if not logged yet
  - NotificationSettingsView: toggle (only visible when tracking enabled)
  - Zero footprint when disabled — no UI shown anywhere
- [ ] Sharing preferences

### 📋 Remaining

**Phase 5: Polish & Launch**
- [x] Sign in with Apple + Onboarding flow
  - WelcomeCarouselView (3-slide carousel → Get Started, icon bounce on page change)
  - SignInView (Sign in with Apple + Debug skip button)
  - ProfileSetupView (animated: typing "What should I call you?" bubble, photo, unit buttons)
  - SmartBuilderView (4/5-step: Days → Length → Split+RepRange → [Custom Config] → Exercises with plan summary)
  - HealthKitOnboardingView (optional Apple Health connection)
  - OnboardingReadyView ("You're all set! Let's grow." → sets onboardingCompletedAt)
  - OnboardingContainerView: back navigation on all steps (SmartBuilder step 0 → ProfileSetup)
  - All onboarding screens use Color.groveBackground with ignoresSafeArea (no white bars)
  - Resume logic: relaunch after sign-in but before completion resumes at ProfileSetup
  - Plans only created from today onward; rest days created with isRestDay=true
- [x] Auto-extend weekly plans
  - `SmartBuilderEngine.extendPlansIfNeeded()` called on HomeView appear
  - Saves user preferences: `preferredSplit`, `preferredTrainingSlots`, `weeklyTemplateIDs`
  - Generates plans for current week + next week when no plans exist
  - Only fills days from today onward that don't already have a plan (respects manual edits)
  - Template-to-slot mapping preserved via ordered UUID array on User model
- [x] Notification system (NotificationService.swift + NotificationOnboardingView.swift)
  - Daily workout reminders (user-preferred morning time, default 8 AM)
  - Weekly planning nudges (user-preferred evening/morning times)
  - Abandoned workout reminders (15 min after starting)
  - Quiet hours support (custom time ranges)
  - Smart rescheduling respects user preference toggles
  - User-configurable reminder times: `preferredReminderHour/Minute`, `preferredCreatineReminderHour/Minute`, `preferredEveningReminderHour/Minute`
  - NotificationOnboardingView: hero bell icon, benefits list, enable/skip → time pickers after granting permission
  - NotificationSettingsView: "Reminder Times" section with morning/evening DatePickers
  - Inserted as step 5 in OnboardingContainerView (between HealthKit and Ready)
- [x] Profile/Settings screen
  - Profile header with photo, name, streak, workout count
  - Current Program card (replaces old Fitness Profile card)
  - Account: inline name edit, fitness goal + experience level pickers
  - Preferences: weight units, vacation mode with date pickers
  - Sharing Defaults: 4 toggles for social feed sharing
  - Links: Apple Health (connect/open), Notifications (→ NotificationSettingsView), Achievements (→ AchievementsGalleryView)
  - Appearance: System/Light/Dark with checkmark indicator
  - Data: Export History (coming soon), Delete Account with confirmation
  - NotificationSettingsView: 5 notification toggles + quiet hours (From/To DatePickers)
- [x] Pause Streak
  - Simple toggle in Settings (Preferences section)
  - When paused: streak value is frozen (recalculation returns current value unchanged)
  - When paused: `extendPlansIfNeeded()` skips plan generation
  - User model property: `streakPaused: Bool`
- [ ] Data export (CSV/PDF)

### Known Issues & Fixes
- [x] Streak badge — now wired to StreakManager with recalculation on app launch
- [x] Workout completion crash — fullScreenCover dismissal + sheet presentation conflict; fixed with 0.5s delay before showing summary
- [x] PR predicate crash — SwiftData #Predicate cannot use .rawValue on enum properties; fixed by comparing enum directly
- [x] PR predicate silent failure — SwiftData #Predicate cannot serialize captured enum values; fixed by filtering enum type in memory instead of in predicate
- [x] Workouts not linked to user — workout.user was never set at creation time; now set in endWorkout()
- [x] WorkoutSessionManager concurrency — added @MainActor for Swift 6 strict concurrency
- [x] FAB visible on all tabs — now hidden on Progress/Social/Profile; only shown on Home tab via TabView(selection:)
- [x] FAB refactored to context Menu — shows "Start [Template]" (when today has actionable plan), "Add to Plan", "New Workout"; workout-from-template logic consolidated into WorkoutSessionManager.createAndStartWorkout()
- [x] Streak badge not showing on first login — added .navigationTitle("") to force nav bar render
- [x] Welcome message width — added .frame(maxWidth: .infinity, alignment: .leading) to match card widths
- [x] Home nav bar clutter — removed Grove logo from .principal and redundant profile button from toolbar
- [x] Profile background grey in light mode — added .scrollContentBackground(.hidden) + .background(Color.groveBackground)
- [x] Done button missing when last exercise skipped — fixed condition in ActiveWorkoutView
- [x] Streak not updating after workout following a rest day — replaced recordWorkout with recalculateStreak in endWorkout(); recordWorkout relied on consecutiveRestDays which was 0 when rest days came from the plan system
- [x] Stat cards unequal heights in workout detail/summary — fixed with frame alignment in WorkoutDetailView and WorkoutSummaryView
- [x] HealthKit connect sheet blank flash — pre-query overlapping workouts before presenting sheet; show browse view for manual selection when no auto-match
- [x] HealthKit authorization status not persisting — requestAuthorization() now calls markAuthorized() immediately on success instead of relying on checkAuthorizationStatus()
- [x] Old abandoned workouts resuming — resumeIncompleteWorkout() now deletes workouts >24h old and only resumes recent ones
- [x] FAB square highlight artifact — added .menuStyle(.button) + .buttonStyle(.plain) to suppress iOS 26 Liquid Glass Menu chrome
- [x] PR cards reordering in workout detail — sorted by exercise name (stable) instead of achievedAt (identical timestamps cause non-deterministic order)
- [x] Onboarding white bars at top/bottom — all onboarding views now use `.background(Color.groveBackground).ignoresSafeArea()` or container-level background
- [x] Onboarding transition bleed-through — `.clipped()` on content Group in OnboardingContainerView prevents outgoing views from rendering during slide transitions
- [x] ProfileSetupView speech bubble expanding bar — used ZStack with invisible full-text placeholder to reserve layout size before typing animation
- [x] WelcomeCarousel icon bounce not firing on Next — `.symbolEffect(.bounce, value: Bool)` doesn't retrigger; fixed with bounceCounter that increments on page change
- [x] SmartBuilder no back to ProfileSetup — added `onBack` callback; step 0 back button returns to ProfileSetup via OnboardingContainerView
- [x] Weekly plans not extending past first week — `SmartBuilderEngine.extendPlansIfNeeded()` auto-generates plans for current + next week on HomeView appear

### SwiftData Gotchas
- **Never use `.rawValue` in `#Predicate`** — SwiftData stores enums natively; `.rawValue` causes runtime crash
- **Never compare captured enum variables in `#Predicate`** — SwiftData cannot serialize them; fetch broader results and filter in memory
- **PR system uses highest weight only** — no 1RM calculations; `PRType.estimatedOneRM` exists for legacy data but is never created; all new PRs use `.maxWeight`
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
 ├── customExercises: [Exercise]
 └── creatineLogs: [CreatineLog]

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
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Grove needs access to save your workout summary images to your photo library.</string>
```

---

## 💡 Future Ideas

### ~~Streak Plant Expansion~~ (Completed)
- Expanded from 5 to 10 stages: Seed, Sprout, Seedling, Young Plant, Bush, Flowering Bush, Sapling, Young Tree, Tree, Grove Tree
