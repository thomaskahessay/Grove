# Grove - Product Specification

**Version:** 1.0  
**Last Updated:** January 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Technology Stack](#2-technology-stack)
3. [Color System & Design](#3-color-system--design)
4. [Data Models](#4-data-models)
5. [User Flows](#5-user-flows)
6. [Screen Specifications](#6-screen-specifications)
7. [Feature Specifications](#7-feature-specifications)
8. [HealthKit Integration](#8-healthkit-integration)
9. [Notifications](#9-notifications)
10. [Development Roadmap](#10-development-roadmap)

---

## 1. Executive Summary

### Overview

Grove is a native iOS workout tracking application built exclusively on Apple technologies. Designed for a small group of 5-10 friends and family members, the app focuses on strength training with future expansion planned for cardio and marathon training.

### Core Value Proposition

- Track strength training workouts with detailed exercise logging
- View progress over time with charts showing estimated 1RM and weight/rep progression
- Plan weekly workouts with a visual calendar
- Connect Apple Watch health data for heart rate, calories, and duration metrics
- Share activity with friends through an opt-in social feed

### Target Users

5-10 friends and family members who primarily do strength training and want a simple, native iOS experience without third-party dependencies.

### Platform Requirements

- iOS 26.0 minimum deployment target
- iPhone required; Apple Watch optional but supported for health data
- Sign in with Apple for authentication
- iCloud for cross-device sync (via SwiftData + CloudKit)

---

## 2. Technology Stack

Grove is built entirely on Apple-native frameworks with zero third-party dependencies.

| Layer | Technology | Purpose |
|-------|------------|---------|
| UI Framework | SwiftUI + iOS 26 Liquid Glass | Native declarative UI with new glass materials |
| Data Persistence | SwiftData | Local storage with automatic iCloud sync |
| Health Data | HealthKit + HealthKitUI | Apple Watch metrics and workout data |
| Authentication | AuthenticationServices | Sign in with Apple |
| Cloud Sync | CloudKit (via SwiftData) | Cross-device data synchronization |
| Notifications | UserNotifications | Local and push notifications |
| Charts | Swift Charts | Progress visualization |

### Project Structure

```
Grove/
├── GroveApp.swift
├── Models/
│   ├── User.swift
│   ├── Exercise.swift
│   ├── Workout.swift
│   ├── ExerciseLog.swift
│   ├── SetLog.swift
│   ├── WorkoutTemplate.swift
│   ├── WorkoutPlan.swift
│   └── Enums.swift
├── Services/
│   ├── AuthService.swift
│   ├── HealthKitManager.swift
│   └── NotificationService.swift
├── Views/
│   ├── Onboarding/
│   ├── Home/
│   ├── Workout/
│   ├── Progress/
│   ├── Social/
│   ├── Profile/
│   └── Library/
├── Components/
│   ├── GlassCard.swift
│   ├── GlassButton.swift
│   └── ColorExtensions.swift
└── Data/
    └── ExerciseSeeds.swift
```

---

## 3. Color System & Design

Grove uses an earthy color palette that works beautifully with iOS 26 Liquid Glass materials.

### Primary Palette

| Role | Color Name | Hex Code | Usage |
|------|------------|----------|-------|
| Primary | Sage | #87A878 | Buttons, highlights, progress indicators, active states |
| Secondary | Terracotta | #C4785B | Accents, success states, completed sets, achievements |
| Accent | Warm Sand | #D4C4A8 | Card backgrounds, subtle highlights, dividers |
| Neutral Dark | Charcoal Brown | #3D3229 | Primary text (light mode), backgrounds (dark mode) |
| Neutral Light | Cream | #F5F1EB | Backgrounds (light mode), secondary text (dark mode) |
| Alert | Muted Rust | #A65E4E | Skipped exercises, warnings, destructive actions |

### Swift Implementation

```swift
import SwiftUI

extension Color {
    static let groveTerracotta = Color(hex: "C4785B")
    static let groveSage = Color(hex: "87A878")
    static let groveWarmSand = Color(hex: "D4C4A8")
    static let groveCharcoal = Color(hex: "3D3229")
    static let groveCream = Color(hex: "F5F1EB")
    static let groveMutedRust = Color(hex: "A65E4E")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### Design Principles

- **Minimalistic but motivating**: Clean layouts with purposeful use of color
- **Liquid Glass for navigation layer only**: Tab bars, toolbars, floating buttons
- **Content remains solid**: List items, cards, and data displays use solid backgrounds
- **Follow system appearance**: Automatic light/dark mode switching
- **Large touch targets**: Minimum 44pt for all interactive elements

### Liquid Glass Usage

**Apply `.glassEffect()` to:**
- Tab bar and navigation elements
- Floating action buttons (start workout, add exercise)
- Bottom sheets and modal backgrounds
- Control buttons during active workout

**Never apply glass to:**
- List rows or table cells
- Exercise cards in workout view
- Progress charts or data visualizations
- Form inputs and text fields

---

## 4. Data Models

All models use SwiftData with the @Model macro for automatic persistence and iCloud sync.

### Enums

```swift
enum FitnessGoal: String, Codable, CaseIterable {
    case buildMuscle = "Build Muscle"
    case loseWeight = "Lose Weight"
    case stayActive = "Stay Active"
    case trainForEvent = "Train for Event"
}

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum UnitSystem: String, Codable, CaseIterable {
    case imperial = "Imperial (lbs)"
    case metric = "Metric (kg)"
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
}

enum TemplateCategory: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case upper = "Upper"
    case lower = "Lower"
    case fullBody = "Full Body"
    case custom = "Custom"
}

enum ExerciseStatus: String, Codable {
    case planned
    case inProgress
    case completed
    case skipped
}

enum PlanStatus: String, Codable {
    case planned
    case completed
    case incomplete
    case rest
}
```

### User Model

```swift
@Model
class User {
    @Attribute(.unique) var appleUserID: String
    var displayName: String?
    var fitnessGoal: FitnessGoal
    var experienceLevel: ExperienceLevel
    var preferredUnits: UnitSystem
    
    // Vacation mode
    var vacationModeEnabled: Bool = false
    var vacationStartDate: Date?
    var vacationEndDate: Date?
    
    // Sharing preferences (defaults)
    var shareWorkoutName: Bool = true
    var shareDuration: Bool = true
    var shareExercises: Bool = false
    var shareWeights: Bool = false
    
    // Notification preferences
    var notifyWorkoutReminder: Bool = true
    var notifyStreakAtRisk: Bool = true
    var notifyFriendActivity: Bool = true
    var notifyPersonalRecord: Bool = true
    var notifyWeeklySummary: Bool = true
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
    
    // Streak tracking
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWorkoutDate: Date?
    var consecutiveRestDays: Int = 0
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Workout.user)
    var workouts: [Workout] = []
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutPlan.user)
    var plans: [WorkoutPlan] = []
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.user)
    var customTemplates: [WorkoutTemplate] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Exercise.createdBy)
    var customExercises: [Exercise] = []
    
    var createdAt: Date = Date()
    
    init(appleUserID: String, fitnessGoal: FitnessGoal = .stayActive, experienceLevel: ExperienceLevel = .beginner, preferredUnits: UnitSystem = .imperial) {
        self.appleUserID = appleUserID
        self.fitnessGoal = fitnessGoal
        self.experienceLevel = experienceLevel
        self.preferredUnits = preferredUnits
    }
}
```

### Exercise Model

```swift
@Model
class Exercise {
    var id: UUID = UUID()
    var name: String
    var muscleGroup: MuscleGroup
    var muscleSubgroup: String?  // e.g., "Quads", "Hamstrings" for legs
    var isBuiltIn: Bool = true
    var createdBy: User?
    
    // For smart suggestions - track if user consistently removes this
    var removalCount: Int = 0
    
    init(name: String, muscleGroup: MuscleGroup, muscleSubgroup: String? = nil, isBuiltIn: Bool = true) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.muscleSubgroup = muscleSubgroup
        self.isBuiltIn = isBuiltIn
    }
}
```

### Workout Model

```swift
@Model
class Workout {
    var id: UUID = UUID()
    var user: User?
    var name: String
    var templateUsed: WorkoutTemplate?
    
    var startedAt: Date = Date()
    var completedAt: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.workout)
    var exercises: [ExerciseLog] = []
    
    // HealthKit data (linked after workout)
    var healthKitWorkoutID: UUID?
    var heartRateMin: Double?
    var heartRateMax: Double?
    var heartRateAvg: Double?
    var caloriesBurned: Double?
    
    // Social sharing
    var isShared: Bool = false
    var shareWorkoutName: Bool = true
    var shareDuration: Bool = true
    var shareExercises: Bool = false
    var shareWeights: Bool = false
    
    var notes: String?
    
    // Computed properties
    var duration: TimeInterval {
        guard let end = completedAt else { return Date().timeIntervalSince(startedAt) }
        return end.timeIntervalSince(startedAt)
    }
    
    var completedExerciseCount: Int {
        exercises.filter { $0.status == .completed }.count
    }
    
    var skippedExerciseCount: Int {
        exercises.filter { $0.status == .skipped }.count
    }
    
    var totalExerciseCount: Int {
        exercises.count
    }
    
    init(name: String, user: User? = nil, templateUsed: WorkoutTemplate? = nil) {
        self.name = name
        self.user = user
        self.templateUsed = templateUsed
    }
}
```

### ExerciseLog Model

```swift
@Model
class ExerciseLog {
    var id: UUID = UUID()
    var exercise: Exercise?
    var workout: Workout?
    var orderIndex: Int
    
    @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
    var sets: [SetLog] = []
    
    var targetSets: Int?
    var targetReps: Int?
    var status: ExerciseStatus = .planned
    
    // For pre-filling from last session
    var lastWeight: Double?
    var lastReps: Int?
    
    init(exercise: Exercise, orderIndex: Int, targetSets: Int? = nil, targetReps: Int? = nil) {
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
    }
}
```

### SetLog Model

```swift
@Model
class SetLog {
    var id: UUID = UUID()
    var exerciseLog: ExerciseLog?
    var setNumber: Int
    var weight: Double?
    var reps: Int?
    var isCompleted: Bool = false
    var completedAt: Date?
    
    init(setNumber: Int, weight: Double? = nil, reps: Int? = nil) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
    }
}
```

### WorkoutTemplate Model

```swift
@Model
class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String
    var category: TemplateCategory
    var isBuiltIn: Bool = true
    var user: User?  // nil for built-in templates
    
    // Exercises in this template (stored as exercise IDs for flexibility)
    var exerciseIDs: [UUID] = []
    var defaultSets: Int = 3
    var defaultReps: Int = 10
    
    // For smart suggestions
    var usageCount: Int = 0
    var lastUsedDate: Date?
    
    // Exercises user consistently removes from this template
    var excludedExerciseIDs: [UUID] = []
    
    init(name: String, category: TemplateCategory, isBuiltIn: Bool = true) {
        self.name = name
        self.category = category
        self.isBuiltIn = isBuiltIn
    }
}
```

### WorkoutPlan Model

```swift
@Model
class WorkoutPlan {
    var id: UUID = UUID()
    var user: User?
    var date: Date
    var template: WorkoutTemplate?
    var isRestDay: Bool = false
    var completedWorkout: Workout?
    
    var status: PlanStatus {
        if isRestDay { return .rest }
        if completedWorkout != nil { return .completed }
        if date < Calendar.current.startOfDay(for: Date()) { return .incomplete }
        return .planned
    }
    
    init(date: Date, user: User? = nil, template: WorkoutTemplate? = nil, isRestDay: Bool = false) {
        self.date = date
        self.user = user
        self.template = template
        self.isRestDay = isRestDay
    }
}
```

### Achievement Model

```swift
@Model
class Achievement {
    var id: UUID = UUID()
    var user: User?
    var type: AchievementType
    var unlockedAt: Date = Date()
    var relatedData: String?  // e.g., exercise name for PR
    
    init(type: AchievementType, user: User? = nil, relatedData: String? = nil) {
        self.type = type
        self.user = user
        self.relatedData = relatedData
    }
}

enum AchievementType: String, Codable, CaseIterable {
    case firstRep = "First Rep"
    case weekWarrior = "Week Warrior"
    case consistent = "Consistent"
    case prCrusher = "PR Crusher"
    case planner = "Planner"
    case centuryClub = "Century Club"
    case ironWill = "Iron Will"
    
    var description: String {
        switch self {
        case .firstRep: return "Log your first workout"
        case .weekWarrior: return "Achieve a 7-day streak"
        case .consistent: return "Log 50 workouts"
        case .prCrusher: return "Set a personal record"
        case .planner: return "Complete a full planned week"
        case .centuryClub: return "Log 100 workouts"
        case .ironWill: return "Achieve a 30-day streak"
        }
    }
    
    var icon: String {
        switch self {
        case .firstRep: return "leaf.fill"
        case .weekWarrior: return "flame.fill"
        case .consistent: return "calendar"
        case .prCrusher: return "trophy.fill"
        case .planner: return "checkmark.calendar"
        case .centuryClub: return "medal.fill"
        case .ironWill: return "mountain.2.fill"
        }
    }
}
```

---

## 5. User Flows

### Onboarding Flow

1. **Launch** → Sign in with Apple button
2. **Profile Setup**:
   - Enter display name (can use Apple ID name as default)
   - Select fitness goal (build muscle, lose weight, stay active, train for event)
   - Select experience level (beginner, intermediate, advanced)
   - Select preferred units (imperial/metric)
3. **Weekly Plan Setup**:
   - Choose a workout split OR skip
   - Options: Push/Pull/Legs, Upper/Lower, Full Body 3x, Custom
   - If chosen → Assign workouts to days, mark rest days
4. **Complete** → Navigate to Home

### Workout Creation Flow

1. Tap planned workout from calendar OR tap + to create new
2. If new:
   - Select template category (Legs, Push, Pull, etc.) OR start blank
   - View randomized suggested exercises for category
3. Modify as needed:
   - Add exercises from library
   - Remove exercises (swipe to delete)
   - Reorder exercises (drag handles)
4. Optionally set target sets/reps per exercise
5. Tap **Start Workout**

### Active Workout Flow

1. Full-screen view showing current exercise
2. Display: Exercise name, set checkboxes with weight/rep inputs
3. Weight/reps pre-filled from last session's values for this exercise
4. Tap checkbox to mark set complete (turns sage green)
5. Swipe or tap arrow to move to next exercise
6. Option to minimize to card view (shows all exercises as scrollable list)
7. Mid-workout options:
   - Add exercise (opens library picker)
   - Skip exercise (marks with strikethrough, still visible)
   - Reorder exercises
8. Tap **End Workout**
9. Prompt: "Connect Apple Watch health data?" (if overlapping workout detected)
10. Summary screen with stats → **Save**

### Weekly Planning Flow

1. Home screen shows calendar strip for current week
2. Tap any day to:
   - Assign a workout template
   - Create custom workout for that day
   - Mark as rest day
3. Incomplete past days show visual indicator (muted rust)
4. Can plan unlimited days ahead
5. Swipe to see future weeks

---

## 6. Screen Specifications

### Home Screen

The primary hub users see after login.

**Layout (top to bottom):**

1. **Header**
   - Grove logo (left)
   - Streak count with flame icon (center-right)
   - Profile icon (right)

2. **Quick Start Section**
   - Horizontal scroll of workout buttons
   - Based on: today's plan, recent templates, suggested based on split
   - Each button shows template name and primary muscle group icon

3. **Calendar Strip**
   - 7-day view, horizontally scrollable, centered on today
   - Each day shows:
     - Date number
     - Day abbreviation (M, T, W...)
     - Status indicator:
       - Completed: Sage checkmark
       - Planned: Template name abbreviated
       - Rest: Moon icon
       - Incomplete past: Muted rust dot
   - Tap day to view/edit plan

4. **Today's Workout Card** (if planned)
   - Template/workout name
   - Exercise count
   - Estimated duration (based on template)
   - Large "Start" button with terracotta background

5. **Recent Activity** (bottom, less prominent)
   - "Friends" section header
   - Compact list of shared workouts
   - Each shows: Avatar, name, workout name, time ago
   - View-only, no interactions

### Active Workout Screen - Full View

**Default state (one exercise at a time):**

```
┌────────────────────────────────────┐
│  ← Back              3/6 exercises │
├────────────────────────────────────┤
│                                    │
│         BENCH PRESS                │
│         Chest                      │
│                                    │
├────────────────────────────────────┤
│  Set 1    [135] lbs   [8] reps  ☑  │
│  Set 2    [135] lbs   [8] reps  ☑  │
│  Set 3    [135] lbs   [_] reps  ☐  │
│  Set 4    [___] lbs   [_] reps  ☐  │
│                                    │
│           [+ Add Set]              │
│                                    │
├────────────────────────────────────┤
│    ←  Previous    Next  →          │
├────────────────────────────────────┤
│ ┌──────┐  ┌──────┐  ┌──────────┐  │
│ │ Skip │  │ Add  │  │   End    │  │
│ └──────┘  └──────┘  └──────────┘  │
│        ~~~~ glass effect ~~~~      │
└────────────────────────────────────┘
```

**Behaviors:**
- Checkboxes: Tap to toggle, sage when complete
- Weight/rep inputs: Tap to edit, numeric keyboard
- Pre-filled values from last time user did this exercise
- Swipe left/right or use arrows to navigate
- Bottom toolbar has glass effect

### Active Workout Screen - Card View

**Minimized view (all exercises visible):**

```
┌────────────────────────────────────┐
│  ← Back              3/6 exercises │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ ☑ Bench Press     3/4 sets    │◀│
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ ☑ Incline DB Press  4/4 sets  │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ ▶ Cable Flyes     0/3 sets    │ │ ← Current
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ ○ Tricep Pushdown 0/3 sets    │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ ✕ Dips (skipped)              │ │ ← Strikethrough
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ ○ Overhead Extension          │ │
│ └────────────────────────────────┘ │
├────────────────────────────────────┤
│       [Expand]  [End Workout]      │
└────────────────────────────────────┘
```

**Behaviors:**
- Tap any card to expand to full view for that exercise
- Drag handles on left to reorder
- Skipped exercises show strikethrough but remain visible
- Current exercise highlighted with border

### Workout Summary Screen

```
┌────────────────────────────────────┐
│           WORKOUT COMPLETE         │
│              Push Day              │
├────────────────────────────────────┤
│                                    │
│         ⏱ 47 minutes              │
│                                    │
│    Exercises: 5 of 6 completed     │
│    (1 skipped)                     │
│                                    │
├────────────────────────────────────┤
│  Connect Apple Watch Data?         │
│  ┌────────────────────────────────┐│
│  │ Workout detected: 45 min       ││
│  │ Avg HR: 128 bpm                ││
│  │         [Connect]              ││
│  └────────────────────────────────┘│
├────────────────────────────────────┤
│  Share with friends?               │
│  [Toggle: ON]                      │
│  Sharing: Name, Duration           │
│  [Customize...]                    │
├────────────────────────────────────┤
│                                    │
│         [Save Workout]             │
│                                    │
└────────────────────────────────────┘
```

### Progress Screen

```
┌────────────────────────────────────┐
│            PROGRESS                │
├────────────────────────────────────┤
│  Exercise: [Bench Press      ▼]   │
│  Period:   [Last 90 Days     ▼]   │
├────────────────────────────────────┤
│  Estimated 1RM                     │
│  ┌────────────────────────────────┐│
│  │     📈 Chart showing          ││
│  │     1RM trend over time       ││
│  │     Current: 185 lbs          ││
│  └────────────────────────────────┘│
├────────────────────────────────────┤
│  Weight × Reps                     │
│  ┌────────────────────────────────┐│
│  │     📈 Chart showing          ││
│  │     weight and reps over time ││
│  └────────────────────────────────┘│
├────────────────────────────────────┤
│  🏆 Personal Records               │
│  ┌────────────────────────────────┐│
│  │ Heaviest: 175 lbs × 6 (Jan 15)││
│  │ Most Reps: 135 lbs × 12 (Jan 8)│
│  └────────────────────────────────┘│
└────────────────────────────────────┘
```

### Social Feed Screen

```
┌────────────────────────────────────┐
│            FRIENDS                 │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ 🟤 Alex                        │ │
│ │ Push Day • 45 min • 2h ago     │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 🟢 Jordan                      │ │
│ │ Leg Day • 52 min • 5h ago      │ │
│ │ 6 exercises                    │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 🔵 Sam                         │ │
│ │ Pull Day • 38 min • Yesterday  │ │
│ └────────────────────────────────┘ │
│                                    │
│         (View only - no likes      │
│          or comments)              │
└────────────────────────────────────┘
```

### Profile Screen

```
┌────────────────────────────────────┐
│            PROFILE                 │
├────────────────────────────────────┤
│  ACCOUNT                           │
│  Display Name         [Edit →]     │
│  Fitness Goal         [Edit →]     │
│  Experience Level     [Edit →]     │
├────────────────────────────────────┤
│  PREFERENCES                       │
│  Units               [Imperial ▼]  │
│  Vacation Mode           [OFF]     │
├────────────────────────────────────┤
│  SHARING DEFAULTS                  │
│  Share workout name      [ON]      │
│  Share duration          [ON]      │
│  Share exercises         [OFF]     │
│  Share weights           [OFF]     │
├────────────────────────────────────┤
│  NOTIFICATIONS           [→]       │
├────────────────────────────────────┤
│  DATA                              │
│  Export History          [→]       │
│  Delete Account          [→]       │
├────────────────────────────────────┤
│  Grove v1.0                        │
└────────────────────────────────────┘
```

---

## 7. Feature Specifications

### Exercise Library

Approximately 100 built-in exercises distributed across muscle groups:

| Muscle Group | Count | Example Subgroups |
|--------------|-------|-------------------|
| Chest | ~12 | Upper, Lower, Inner |
| Back | ~15 | Lats, Upper Back, Lower Back |
| Shoulders | ~12 | Front Delts, Side Delts, Rear Delts |
| Biceps | ~8 | Long Head, Short Head |
| Triceps | ~8 | Long Head, Lateral Head |
| Legs | ~25 | Quads, Hamstrings, Glutes, Calves |
| Core | ~12 | Upper Abs, Lower Abs, Obliques |
| Full Body | ~8 | Compound movements |

**Custom Exercises:**
- Required: Name, Muscle Group
- Optional: Subgroup
- Custom exercises are private to the user who created them

### Workout Templates

**Built-in categories:**

| Category | Muscles Included | Default Exercises |
|----------|------------------|-------------------|
| Push | Chest, Shoulders, Triceps | 6-8 exercises |
| Pull | Back, Biceps | 6-8 exercises |
| Legs | Quads, Hamstrings, Glutes, Calves | 8-10 exercises |
| Upper | Chest, Back, Shoulders, Arms | 8-10 exercises |
| Lower | Legs, Core | 8-10 exercises |
| Full Body | All muscle groups | 6-8 compound exercises |
| Custom | User-defined | User-selected |

**Smart Suggestions:**
- When user selects a category, show randomized subset (5-6 exercises) from that category's pool
- User can refresh for new suggestions
- Track which exercises user consistently removes → stop suggesting those for this template
- Pre-fill weight/reps from last session

### Streak System

**Rules:**
- Any logged workout increments consecutive day count
- Rest days preserve streak (do not break it)
- Maximum 3 consecutive rest days before streak resets
- Vacation mode: Unlimited rest days without breaking streak

**Vacation Mode:**
- Toggle on/off manually, OR
- Set date range in advance
- No limit on duration
- Streak frozen during vacation

**Design Philosophy:** Motivating, never punishing. Streaks celebrate consistency without creating anxiety.

### Achievements

| Achievement | Criteria | Icon |
|-------------|----------|------|
| First Rep | Log first workout | leaf.fill |
| Week Warrior | 7-day streak | flame.fill |
| Consistent | Log 50 workouts | calendar |
| PR Crusher | Set any personal record | trophy.fill |
| Planner | Complete a full planned week | checkmark.calendar |
| Century Club | Log 100 workouts | medal.fill |
| Iron Will | 30-day streak | mountain.2.fill |

### Personal Records

**Tracked per exercise:**
- Heaviest weight (with rep count)
- Most reps (with weight)
- Estimated 1RM (calculated)

**1RM Formula (Brzycki):**
```
1RM = weight × (36 / (37 - reps))
```

**PR Detection:**
- After each set is logged, compare to stored PRs
- If new PR, show notification/badge
- Store PR history (not just current best)

### Data Export

**Formats:**
- CSV: All workouts with exercises, sets, weights, reps
- PDF: Formatted summary report

**Contents:**
- Workout history (date, name, duration, exercises)
- Personal records per exercise
- Progress data (for charts)

---

## 8. HealthKit Integration

### Data Types Requested

| Type | Permission | Purpose |
|------|------------|---------|
| HKWorkoutType | Read | Detect Apple Fitness workouts to link |
| Heart Rate | Read | Display min/avg/max during workout |
| Active Energy Burned | Read | Show calories in workout summary |

**Note:** Grove does NOT write workouts to HealthKit. It only reads data from workouts started in Apple's native Fitness app.

### Integration Flow

1. User completes workout in Grove and taps "End Workout"
2. App queries HealthKit for recent workouts:
   ```swift
   let workoutType = HKObjectType.workoutType()
   let predicate = HKQuery.predicateForSamples(
       withStart: groveWorkout.startedAt.addingTimeInterval(-1800), // 30 min before
       end: Date(),
       options: .strictStartDate
   )
   ```
3. If overlapping workout found (within 30 min window):
   - Show prompt: "Connect health data from Apple Watch?"
   - Display preview: Duration, average heart rate
4. User confirms → Link HealthKit workout ID to Grove workout
5. Query heart rate samples for that workout period:
   ```swift
   let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
   // Query samples, calculate min/avg/max
   ```
6. Query active calories
7. Store in Grove workout record

### HealthKit Manager

```swift
import HealthKit

@Observable
class HealthKitManager {
    private let healthStore = HKHealthStore()
    
    var isAuthorized = false
    
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    ]
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        isAuthorized = true
    }
    
    func findOverlappingWorkout(start: Date, end: Date) async throws -> HKWorkout? {
        // Query for workouts in time window
    }
    
    func getHeartRateStats(for workout: HKWorkout) async throws -> (min: Double, avg: Double, max: Double) {
        // Query heart rate samples, calculate stats
    }
    
    func getCalories(for workout: HKWorkout) async throws -> Double {
        // Query active energy burned
    }
}

enum HealthKitError: Error {
    case notAvailable
    case notAuthorized
    case noDataFound
}
```

### Privacy Considerations

- Request only necessary permissions (read-only)
- Explain why each data type is needed in authorization prompt
- HealthKit data stays on device (syncs only to user's own devices via iCloud)
- Never share raw health data to social feed—only aggregates if user opts in

---

## 9. Notifications

### Notification Types

| Type | Trigger | Default | Content Example |
|------|---------|---------|-----------------|
| Workout Reminder | Morning of planned workout day | On | "Push Day is on your schedule today. Ready to grow?" |
| Streak at Risk | Evening if no workout logged | On | "Don't break your 12-day streak! Log a workout or rest day." |
| Friend Activity | Friend shares a workout | On | "Alex just crushed Leg Day - 45 min" |
| Personal Record | User sets new PR | On | "New PR! Bench Press: 185 lbs × 8 reps 🏆" |
| Weekly Summary | Sunday evening | On | "This week: 4 workouts, 2 PRs. Keep it up!" |

### User Configuration

**Profile → Notifications:**
- Master toggle: All notifications on/off
- Per-type toggles for granular control
- Quiet hours: Start time, end time
- Workout reminder time: Default 8:00 AM, customizable

### Implementation

```swift
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted
    }
    
    func scheduleWorkoutReminder(for date: Date, workoutName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Train"
        content.body = "\(workoutName) is on your schedule today. Ready to grow?"
        content.sound = .default
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 8  // Or user's preferred time
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleStreakReminder() {
        // Schedule for 8 PM if no workout logged today
    }
    
    func sendPRNotification(exercise: String, weight: Double, reps: Int, units: UnitSystem) {
        let unitLabel = units == .imperial ? "lbs" : "kg"
        let content = UNMutableNotificationContent()
        content.title = "New Personal Record! 🏆"
        content.body = "\(exercise): \(Int(weight)) \(unitLabel) × \(reps) reps"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
```

---

## 10. Development Roadmap

### Phase 1: Foundation (Week 1-2)

| Task | Priority | Notes |
|------|----------|-------|
| Xcode project setup | High | Enable all capabilities |
| SwiftData models | High | All models from Section 4 |
| Color system + extensions | High | ColorExtensions.swift |
| Sign in with Apple | High | AuthService.swift |
| Basic tab navigation | High | Home, Progress, Social, Profile tabs |
| Liquid Glass components | Medium | GlassCard, GlassButton |
| Exercise seed data | Medium | ~100 exercises in ExerciseSeeds.swift |

**Deliverable:** App launches, user can sign in, see empty home screen with tabs.

### Phase 2: Core Workout Features (Week 3-4)

| Task | Priority | Notes |
|------|----------|-------|
| Home screen UI | High | Calendar strip, quick start, today's card |
| Exercise library view | High | Browse by muscle group, search |
| Workout creation flow | High | Template selection, exercise picker |
| Active workout - full view | High | Single exercise display, set logging |
| Active workout - card view | Medium | Minimized scrollable list |
| Set completion (checkmarks) | High | Tap to complete, sage color |
| Workout summary screen | High | Stats display, save functionality |

**Deliverable:** User can create and complete a workout, log sets.

### Phase 3: Progress & Planning (Week 5-6)

| Task | Priority | Notes |
|------|----------|-------|
| Weekly calendar view | High | 7-day strip, tap to assign |
| Workout planning | High | Assign templates to days |
| Rest day marking | Medium | Moon icon, streak preservation |
| Progress charts | High | 1RM chart, weight×reps chart |
| Personal record detection | Medium | Compare after each set |
| Streak tracking logic | Medium | In User model |
| Achievements system | Low | Check criteria after workouts |

**Deliverable:** User can plan week, view progress charts, see streak.

### Phase 4: HealthKit & Social (Week 7-8)

| Task | Priority | Notes |
|------|----------|-------|
| HealthKit authorization | High | Request read permissions |
| Workout detection | High | Find overlapping Apple workouts |
| Heart rate integration | High | Query samples, calc stats |
| Calorie integration | Medium | Query active energy |
| Social feed UI | Medium | List of shared workouts |
| Sharing preferences | Medium | Per-workout and defaults |
| Friend activity display | Low | On home screen |

**Deliverable:** User can connect Watch data, see friends' activity.

### Phase 5: Polish & Launch (Week 9-10)

| Task | Priority | Notes |
|------|----------|-------|
| Notification system | Medium | All notification types |
| Profile screen | Medium | All preferences |
| Onboarding flow polish | High | Smooth, welcoming |
| Crash recovery | High | Auto-save mid-workout |
| Vacation mode | Low | Toggle and date range |
| Data export | Low | CSV and PDF |
| TestFlight setup | High | Distribute to beta users |
| Bug fixes | High | Ongoing |

**Deliverable:** App ready for friends/family beta.

### Future Enhancements (Post-Launch)

- Cardio workout support
- Marathon training plans
- AI-generated workout plans
- Apple Watch companion app
- Home Screen widgets
- Siri Shortcuts integration

---

## Appendix A: Xcode Configuration

### Capabilities to Enable

1. **Sign in with Apple**
2. **HealthKit** (uncheck Clinical Health Records)
3. **iCloud** → CloudKit (create container: iCloud.com.yourname.Grove)
4. **Push Notifications**
5. **Background Modes** (optional, for notification scheduling)

### Info.plist Keys

```xml
<key>NSHealthShareUsageDescription</key>
<string>Grove reads your workout data to track heart rate and calories during your strength training sessions.</string>
```

### App Entry Point

```swift
import SwiftUI
import SwiftData

@main
struct GroveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
}
```

---

## Appendix B: Sample Exercise Data

```swift
// ExerciseSeeds.swift

let builtInExercises: [(name: String, group: MuscleGroup, subgroup: String?)] = [
    // Chest (~12)
    ("Barbell Bench Press", .chest, "Middle"),
    ("Incline Barbell Press", .chest, "Upper"),
    ("Decline Barbell Press", .chest, "Lower"),
    ("Dumbbell Bench Press", .chest, "Middle"),
    ("Incline Dumbbell Press", .chest, "Upper"),
    ("Dumbbell Flyes", .chest, "Inner"),
    ("Cable Crossover", .chest, "Inner"),
    ("Push-Ups", .chest, "Middle"),
    ("Chest Dips", .chest, "Lower"),
    ("Machine Chest Press", .chest, "Middle"),
    ("Pec Deck", .chest, "Inner"),
    ("Landmine Press", .chest, "Upper"),
    
    // Back (~15)
    ("Deadlift", .back, "Lower Back"),
    ("Barbell Row", .back, "Upper Back"),
    ("Dumbbell Row", .back, "Lats"),
    ("Pull-Ups", .back, "Lats"),
    ("Chin-Ups", .back, "Lats"),
    ("Lat Pulldown", .back, "Lats"),
    ("Seated Cable Row", .back, "Upper Back"),
    ("T-Bar Row", .back, "Upper Back"),
    ("Face Pulls", .back, "Upper Back"),
    ("Hyperextensions", .back, "Lower Back"),
    ("Good Mornings", .back, "Lower Back"),
    ("Straight Arm Pulldown", .back, "Lats"),
    ("Meadows Row", .back, "Lats"),
    ("Chest Supported Row", .back, "Upper Back"),
    ("Inverted Row", .back, "Upper Back"),
    
    // Shoulders (~12)
    ("Overhead Press", .shoulders, "Front Delts"),
    ("Dumbbell Shoulder Press", .shoulders, "Front Delts"),
    ("Arnold Press", .shoulders, "Front Delts"),
    ("Lateral Raises", .shoulders, "Side Delts"),
    ("Front Raises", .shoulders, "Front Delts"),
    ("Rear Delt Flyes", .shoulders, "Rear Delts"),
    ("Upright Row", .shoulders, "Side Delts"),
    ("Shrugs", .shoulders, "Traps"),
    ("Face Pulls", .shoulders, "Rear Delts"),
    ("Cable Lateral Raise", .shoulders, "Side Delts"),
    ("Machine Shoulder Press", .shoulders, "Front Delts"),
    ("Reverse Pec Deck", .shoulders, "Rear Delts"),
    
    // Biceps (~8)
    ("Barbell Curl", .biceps, "Both Heads"),
    ("Dumbbell Curl", .biceps, "Both Heads"),
    ("Hammer Curl", .biceps, "Long Head"),
    ("Preacher Curl", .biceps, "Short Head"),
    ("Incline Dumbbell Curl", .biceps, "Long Head"),
    ("Cable Curl", .biceps, "Both Heads"),
    ("Concentration Curl", .biceps, "Short Head"),
    ("EZ Bar Curl", .biceps, "Both Heads"),
    
    // Triceps (~8)
    ("Tricep Pushdown", .triceps, "Lateral Head"),
    ("Overhead Tricep Extension", .triceps, "Long Head"),
    ("Skull Crushers", .triceps, "All Heads"),
    ("Close Grip Bench Press", .triceps, "All Heads"),
    ("Tricep Dips", .triceps, "All Heads"),
    ("Diamond Push-Ups", .triceps, "All Heads"),
    ("Cable Overhead Extension", .triceps, "Long Head"),
    ("Tricep Kickbacks", .triceps, "Lateral Head"),
    
    // Legs (~25)
    ("Barbell Squat", .legs, "Quads"),
    ("Front Squat", .legs, "Quads"),
    ("Leg Press", .legs, "Quads"),
    ("Hack Squat", .legs, "Quads"),
    ("Goblet Squat", .legs, "Quads"),
    ("Bulgarian Split Squat", .legs, "Quads"),
    ("Lunges", .legs, "Quads"),
    ("Walking Lunges", .legs, "Quads"),
    ("Leg Extension", .legs, "Quads"),
    ("Romanian Deadlift", .legs, "Hamstrings"),
    ("Stiff Leg Deadlift", .legs, "Hamstrings"),
    ("Leg Curl", .legs, "Hamstrings"),
    ("Seated Leg Curl", .legs, "Hamstrings"),
    ("Nordic Hamstring Curl", .legs, "Hamstrings"),
    ("Hip Thrust", .legs, "Glutes"),
    ("Glute Bridge", .legs, "Glutes"),
    ("Cable Kickback", .legs, "Glutes"),
    ("Step Ups", .legs, "Glutes"),
    ("Sumo Deadlift", .legs, "Glutes"),
    ("Calf Raises", .legs, "Calves"),
    ("Seated Calf Raise", .legs, "Calves"),
    ("Donkey Calf Raise", .legs, "Calves"),
    ("Adductor Machine", .legs, "Adductors"),
    ("Abductor Machine", .legs, "Abductors"),
    ("Box Squat", .legs, "Quads"),
    
    // Core (~12)
    ("Crunches", .core, "Upper Abs"),
    ("Sit-Ups", .core, "Upper Abs"),
    ("Leg Raises", .core, "Lower Abs"),
    ("Hanging Leg Raise", .core, "Lower Abs"),
    ("Plank", .core, "All"),
    ("Side Plank", .core, "Obliques"),
    ("Russian Twist", .core, "Obliques"),
    ("Cable Woodchop", .core, "Obliques"),
    ("Ab Wheel Rollout", .core, "All"),
    ("Dead Bug", .core, "All"),
    ("Mountain Climbers", .core, "All"),
    ("Bicycle Crunches", .core, "Obliques"),
    
    // Full Body (~8)
    ("Deadlift", .fullBody, nil),
    ("Clean and Press", .fullBody, nil),
    ("Thrusters", .fullBody, nil),
    ("Burpees", .fullBody, nil),
    ("Kettlebell Swing", .fullBody, nil),
    ("Turkish Get Up", .fullBody, nil),
    ("Man Makers", .fullBody, nil),
    ("Battle Ropes", .fullBody, nil),
]
```

---

*End of Product Specification*
