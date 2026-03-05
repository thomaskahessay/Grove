# Smart Workout Builder — Feature Spec

## Overview

The Smart Workout Builder replaces the current fitness goal/experience level questions AND the preset weekly plan picker in onboarding. Instead of classifying themselves, users build a personalized workout program through a guided flow. This is the core onboarding experience — it's how users go from "I just downloaded the app" to "I have a full week of workouts ready."

Onboarding-only for now, but designed to be promotable to a standalone feature later (e.g., "Rebuild My Plan" from home screen).

## Target Audience

5-10 friends/family with mixed experience levels. Some experienced lifters who know exactly what they want, some newer lifters who need strong defaults and guidance.

## User Mental Model

The natural thought process (confirmed via interview):
1. "How many days can I consistently get to the gym?"
2. "What split fits that schedule?"
3. "What exercises do I want to do?"

The builder mirrors this exact flow.

## Onboarding Flow (Updated)

1. Welcome carousel (unchanged)
2. Sign in (unchanged)
3. **Simplified profile** — name, photo, weight units only (drop fitness goal + experience level from this step)
4. **Smart Workout Builder** (new — replaces goal/experience AND WeeklyPlanSetupView)
5. HealthKit connect (unchanged)
6. Ready screen (unchanged)

## Smart Builder Steps

### Step 1: Days Per Week
- "How many days do you train?"
- Horizontal selector: 2 / 3 / 4 / 5 / 6 days
- Visual week bar (Mon-Sun) that lights up days as the count changes
  - Days should auto-distribute sensibly (e.g., 3 days = Mon/Wed/Fri, 4 days = Mon/Tue/Thu/Fri)
  - Users don't pick specific days at this step — just the count

### Step 2: Workout Length
- "How long are your workouts?"
- Selector: 30 / 45 / 60 / 75 / 90 minutes
- This determines the suggested exercise count per session (~10 min per exercise)
  - 30 min = ~3 exercises
  - 45 min = ~4-5 exercises
  - 60 min = ~6 exercises
  - 75 min = ~7-8 exercises
  - 90 min = ~9 exercises
- This is a **soft guide** — users can add more exercises later with a time estimate warning

### Step 3: Split + Rep Range
Two choices on one screen:

**Split selection:**
- Options are filtered by the day count from Step 1:
  - 2 days: Full Body, Upper/Lower
  - 3 days: Full Body, Push/Pull/Legs, Upper/Lower (with one full body day)
  - 4 days: Upper/Lower, Push/Pull (2x each)
  - 5 days: Bro Split, Push/Pull/Legs + Upper/Lower, Arnold Split
  - 6 days: Push/Pull/Legs (2x), Arnold Split
- Each option shows a mini inline preview of the week (e.g., "Mon: Push / Tue: Pull / Wed: Legs / ...")

**Rep range preference:**
- Strength: 3-5 reps (heavier weight, longer rest)
- Hypertrophy: 8-12 reps (moderate weight, standard)
- Endurance: 15+ reps (lighter weight, shorter rest)
- This preference is applied to the generated templates as default sets/reps:
  - Strength: 5 sets x 5 reps for compounds, 3 sets x 8 reps for isolations
  - Hypertrophy: 4 sets x 10 reps for compounds, 3 sets x 12 reps for isolations
  - Endurance: 3 sets x 15 reps for compounds, 3 sets x 15 reps for isolations

### Step 4: Exercise Selection
- **Hybrid approach**: smart defaults pre-selected + full library available below
- Layout per training day (or per muscle group, grouped by the split):
  - "Recommended" section at top with pre-selected exercises (based on split + muscle groups)
  - "More exercises" expandable section below with the full library for that muscle group
  - Tap to toggle exercises on/off
- Running indicator at top: "8 exercises selected — ~80 min" with a warning tint if exceeding the time budget from Step 2
- Exercise count per muscle group is guided by the time budget
- Pre-selected defaults should favor common compound movements that both beginners and experienced lifters would recognize (bench press, squat, deadlift, overhead press, rows, etc.)

### Step 5: Review & Confirm
- Full week view with each day expanded showing its exercises
- Exercises are **auto-sorted**: compounds first, isolations last
- **Drag-to-reorder** available — user can rearrange exercise order within a day
- Each exercise shows the default sets x reps (from the rep range preference)
- "Looks good" button → creates templates + plans
- "Back" to go adjust exercises

## Builder Logic

```
Inputs:
  - daysPerWeek: Int (2-6)
  - minutesPerWorkout: Int (30-90)
  - split: SplitType
  - repRange: RepRangePreference
  - selectedExercises: [Exercise] (user's final selection)

Processing:
  1. Map split → which muscle groups on which days
  2. exerciseBudget = minutesPerWorkout / 10
  3. Distribute selectedExercises across days by muscle group mapping
  4. Sort within each day: compounds first → isolations last
     (Use Exercise.isCompound or infer from equipment/muscle group)
  5. Apply rep range defaults to each exercise

Output:
  - [WorkoutTemplate] with exerciseIDs and default set/rep config
  - [WorkoutPlan] for the current week (today onward)
```

## Data Model Considerations

### New fields on User model
- `preferredDaysPerWeek: Int` (default 3)
- `preferredWorkoutMinutes: Int` (default 60)
- `preferredRepRange: RepRangePreference` (new enum)

### New enum: RepRangePreference
```swift
enum RepRangePreference: String, Codable, CaseIterable {
    case strength = "Strength"      // 3-5 reps
    case hypertrophy = "Hypertrophy" // 8-12 reps
    case endurance = "Endurance"     // 15+ reps
}
```

### Exercise model
- May need an `isCompound: Bool` property (or derive from muscle group / exercise name)
- Used for auto-sorting: compounds before isolations within a day

### Existing fields to remove from onboarding (keep in Settings)
- `fitnessGoal: FitnessGoal` — still stored on User, still editable in Settings, just not asked during onboarding
- `experienceLevel: ExperienceLevel` — same

## Time Estimation

- Base rate: ~10 minutes per exercise
- This accounts for warm-up sets, 3-4 working sets, and ~90s rest between sets
- Displayed as a running estimate during exercise selection
- **Soft enforcement**: if user exceeds their stated time budget, show a subtle warning (e.g., orange tint on the time indicator, "This may run over 60 min") but don't prevent adding more exercises

## Auto-Sort Rules

Within each day's workout, exercises are ordered:
1. Barbell compounds (squat, bench, deadlift, OHP, rows)
2. Other compounds (dips, pull-ups, lunges)
3. Cable/machine compounds
4. Dumbbell accessories
5. Isolation exercises (curls, extensions, raises, flyes)

This can be simplified to a `sortPriority: Int` on Exercise or derived from equipment + muscle group.

## Split Definitions

### Full Body (2-3 days)
Each day hits all major muscle groups. Exercises distributed evenly.
- Day structure: 1-2 push + 1-2 pull + 1-2 legs + 1 accessory

### Upper/Lower (4 days)
- Upper: chest, back, shoulders, biceps, triceps
- Lower: quads, hamstrings, glutes, calves, core

### Push/Pull/Legs (3 or 6 days)
- Push: chest, shoulders, triceps
- Pull: back, biceps, rear delts
- Legs: quads, hamstrings, glutes, calves

### Bro Split (5 days)
- Chest, Back, Shoulders, Legs, Arms (biceps + triceps)

### Arnold Split (5-6 days)
- Chest + Back, Shoulders + Arms, Legs (repeated for 6-day)

## UI/UX Notes

- Each step should feel like a single focused decision, not a form to fill out
- Transitions between steps should be smooth (same pattern as current onboarding)
- Progress bar in OnboardingContainerView should account for the builder sub-steps (or show a separate internal progress indicator within the builder)
- The builder should feel fast — a user who knows what they want should be able to get through all 5 steps in under 2 minutes
- For mixed-experience audiences: smart defaults carry beginners, while the hybrid exercise picker gives experienced users full control

## Future Expansion (v2 — not for now)

- **Adaptive adjustments**: Analyze workout history to suggest program changes
  - Plateau detection (same weight 3+ weeks) → suggest weight increase or exercise swap
  - Volume adjustment based on completion rate (always skipping last 2 exercises = workout too long)
  - Exercise swap suggestions based on skip patterns
- **"Rebuild My Plan" button**: Accessible from home screen, re-runs the builder with user's history informing the defaults
- **Periodization**: Auto-cycle between strength/hypertrophy phases
- **Deload week detection**: Suggest lighter weeks after sustained intensity

## What This Replaces

| Current | New |
|---------|-----|
| ProfileSetupView: fitness goal picker | Removed from onboarding (kept in Settings) |
| ProfileSetupView: experience level picker | Removed from onboarding (kept in Settings) |
| WeeklyPlanSetupView: preset split picker | Replaced by Smart Builder Steps 1-5 |
| WeeklyPlanSetupView: schedule preview | Replaced by Smart Builder Step 5 (review) |

## Files That Will Change

- `OnboardingContainerView.swift` — update step enum, wire in builder
- `ProfileSetupView.swift` — remove goal/experience sections
- `WeeklyPlanSetupView.swift` — major rewrite or replace entirely
- `User.swift` — add preferredDaysPerWeek, preferredWorkoutMinutes, preferredRepRange
- `Enums.swift` — add RepRangePreference enum
- `Exercise.swift` — possibly add isCompound/sortPriority
- `ExerciseSeeds.swift` — tag exercises as compound/isolation if adding that field
- New file: `SmartBuilderView.swift` (or split into sub-step views)
