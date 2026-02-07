# Onboarding Implementation Plan

## Overview

Full onboarding flow: Welcome carousel → Sign in with Apple → Profile setup → Weekly plan setup → Ready screen → Main app. Sign in is mandatory. Skip onboarding if CloudKit sync finds existing user data.

## Flow Diagram

```
App Launch
    │
    ├── Existing User data found (CloudKit) → Main App
    │
    └── No User data → Onboarding Flow
         │
         ├── Step 1: Welcome Carousel (3 slides)
         │     Slide 1: "Easy Workout Logging" — track sets, reps, weight
         │     Slide 2: "Auto-fill & PR Detection" — smart features
         │     Slide 3: "Share With Friends" — social/accountability
         │     → "Get Started" button on last slide
         │
         ├── Step 2: Sign in with Apple (mandatory)
         │     → Uses AuthenticationServices framework
         │     → Creates User model with appleUserID
         │     → Failure/decline shows error, stays on sign-in
         │
         ├── Step 3: Profile Setup (multi-field form)
         │     - Display name (pre-filled from Apple ID if available)
         │     - Profile photo (PhotosPicker + Camera + skip to initials default)
         │     - Preferred units (lbs / kg toggle)
         │     - Fitness goal picker (Strength, Hypertrophy, General Fitness)
         │     - Experience level (Beginner, Intermediate, Advanced)
         │     → "Continue" button
         │
         ├── Step 4: Weekly Plan Setup
         │     - Preset split patterns organized by frequency:
         │       • 3-day: Full Body (Mon/Wed/Fri)
         │       • 4-day: Upper/Lower (Mon/Tue/Thu/Fri)
         │       • 5-day: Bro Split (Mon–Fri, Chest&Tri/Back&Bi/Shoulders/Legs/Arms)
         │       • 6-day: Push/Pull/Legs ×2 (Mon–Sat)
         │       • Custom: create templates + assign to days manually
         │     - After choosing a preset:
         │       → Show generated templates assigned to days (Mon–Sun)
         │       → User can tweak/reassign before confirming
         │     - Custom option:
         │       → Create new templates (name + category + exercises)
         │       → Assign templates to days via DayPlanSheet-like UI
         │     - "Skip" option available (plan later from home screen)
         │     → "Continue" button
         │
         ├── Step 5: Ready Screen
         │     - Motivational message: "You're all set! Let's grow."
         │     - Grove logo/branding
         │     - "Start" button → transitions to main app
         │
         └── Main App (ContentView)
```

## Visual Style

- **Match app style**: earthy tones, cream backgrounds, sage accents
- Consistent with existing Grove color palette throughout
- No dark/immersive departure — seamless visual transition into the app

## Files to Create / Modify

### New Files

```
Grove/Views/Onboarding/
├── OnboardingContainerView.swift   # Manages onboarding step progression
├── WelcomeCarouselView.swift       # 3-slide TabView with page indicators
├── SignInView.swift                 # Sign in with Apple button + branding
├── ProfileSetupView.swift          # Name, photo, units, goal, experience
├── WeeklyPlanSetupView.swift       # Preset splits + custom option
└── OnboardingReadyView.swift       # "You're all set" completion screen
```

### Files to Modify

- **`GroveApp.swift` or `ContentView.swift`** — Check for existing User on launch; show onboarding or main app
- **`Models/User.swift`** — Ensure all profile fields exist (displayName, profileImageData, preferredUnits, fitnessGoal, experienceLevel)
- **`Models/Enums.swift`** — Add FitnessGoal and ExperienceLevel enums if not present
- **`Services/AuthService.swift`** — Implement Sign in with Apple handler

## Implementation Details

### Step 1: Welcome Carousel

- `TabView` with `.tabViewStyle(.page)` and page indicator dots
- 3 slides, each with an SF Symbol icon, title, and subtitle
- "Get Started" button appears on the last slide (or available on all slides)
- Slide content:
  1. Icon: `dumbbell.fill` — "Easy Workout Logging" / "Track your sets, reps, and weight with a clean, intuitive interface"
  2. Icon: `bolt.fill` — "Smart & Automatic" / "Auto-fill from previous workouts and detect new personal records"
  3. Icon: `person.2.fill` — "Train Together" / "Share progress and stay accountable with friends and family"

### Step 2: Sign in with Apple

- Use `SignInWithAppleButton` from AuthenticationServices
- On success: extract `userIdentifier`, `fullName`, `email`
- Create `User` model with `appleUserID = userIdentifier`
- Pre-fill `displayName` from `fullName` (Apple only provides this on first sign-in)
- Store credential in Keychain for session persistence
- On failure: show alert, stay on sign-in screen

### Step 3: Profile Setup

- **Photo**: `PhotosPicker` for library, camera button for live capture, default to initials circle (from display name)
- Store photo as `Data?` on User model (`profileImageData`)
- **Units**: segmented picker — Imperial (lbs) / Metric (kg)
- **Fitness Goal**: picker or selection cards — Strength, Hypertrophy, General Fitness
- **Experience Level**: picker or selection cards — Beginner, Intermediate, Advanced
- All fields save to the User model

### Step 4: Weekly Plan Setup

**Preset Patterns** (organized by training frequency):

| Preset | Days | Schedule |
|--------|------|----------|
| 3-day Full Body | Mon, Wed, Fri | Full Body × 3, rest days between |
| 4-day Upper/Lower | Mon, Tue, Thu, Fri | Upper, Lower, Upper, Lower |
| 5-day Bro Split | Mon–Fri | Chest & Tri, Back & Bi, Shoulders, Legs, Full Body |
| 6-day PPL | Mon–Sat | Push, Pull, Legs, Push, Pull, Legs |

- User selects a preset → we generate WorkoutTemplates + WorkoutPlans for the current week
- After selection, show Mon–Sun grid with assigned templates
- User can tap days to reassign before confirming
- **Custom option**: flows into template creation (name, category, exercise picker) then day assignment
- **Skip option**: no plans created, user can use "Plan My Week" from home later

### Step 5: Ready Screen

- Large checkmark or Grove logo animation
- Text: "You're all set! Let's grow."
- Single "Start" button
- Subtle entry animation (fade in / scale up)

### Launch Logic (GroveApp / ContentView)

```swift
// Pseudocode
if existingUser != nil {
    // User exists (fresh install with CloudKit data, or returning)
    show ContentView
} else {
    // No user — first time
    show OnboardingContainerView
    // On completion, OnboardingContainerView sets a flag or the User now exists
    // Transition to ContentView
}
```

- Use `@Query` to check for User existence
- OnboardingContainerView creates the User during sign-in step
- After onboarding completes, the `@Query` updates and ContentView shows naturally
- Remove the auto-created "local-user" logic from ContentView.task

### Existing Code Status

- **Onboarding views**: None exist yet (folder is empty)
- **User model**: `fitnessGoal` (FitnessGoal), `experienceLevel` (ExperienceLevel), `preferredUnits` already exist
- **Missing on User**: `profileImageData: Data?` field for photo storage — needs to be added
- **Enums**: `FitnessGoal` (.buildMuscle, .loseWeight, .stayActive) and `ExperienceLevel` (.beginner, .intermediate, .advanced) already defined in Enums.swift
- **AuthService.swift**: Listed in project structure but check if it has implementation
- **ContentView.swift**: Currently auto-creates a local user in `.task {}` — this needs to be replaced with onboarding check

## Preset Template Details

When a preset is selected, create these `WorkoutTemplate` entries:

**3-day Full Body:**
- "Full Body A" (category: .fullBody) — compound-focused
- "Full Body B" (category: .fullBody) — accessory-focused
- "Full Body C" (category: .fullBody) — mixed

**4-day Upper/Lower:**
- "Upper A" (category: .upper)
- "Lower A" (category: .lower)
- "Upper B" (category: .upper)
- "Lower B" (category: .lower)

**5-day Bro Split:**
- "Chest & Triceps" (category: .chestTriceps)
- "Back & Biceps" (category: .backBiceps)
- "Shoulders" (category: .shoulders)
- "Legs" (category: .legs)
- "Full Body" (category: .fullBody)

**6-day PPL:**
- "Push" (category: .push)
- "Pull" (category: .pull)
- "Legs" (category: .legs)

Templates should include suggested exercises from ExerciseSeeds matching their category (6-8 exercises per template).

## Testing Checklist

- [ ] Fresh install → onboarding shows
- [ ] Welcome carousel swipe + page indicators
- [ ] Sign in with Apple success → proceeds to profile
- [ ] Sign in with Apple cancel/fail → stays on sign-in with error
- [ ] Profile setup saves all fields to User model
- [ ] Photo from library, camera, and initials default all work
- [ ] Preset selection generates correct templates + plans
- [ ] Custom plan creation works (create templates, assign days)
- [ ] Skip plan step works (no plans created)
- [ ] Ready screen → transitions to main app
- [ ] Returning user with CloudKit data → skips onboarding
- [ ] App remembers sign-in state on relaunch (no re-onboarding)
