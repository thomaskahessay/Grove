# Issues Log

## Finding 1 (Grove/Views/Workout/WorkoutCreationView.swift:8) [added]
[P3] Workout creation uses global templates/exercises

`allTemplates`/`allExercises` are queried globally, then filtered only by `isBuiltIn`/`isArchived`. If multiple users exist, the template picker can show other users' custom templates and exercises. Filter by `template.user == currentUser` (or by user id) for custom entries.

## Finding 2 (Grove/Services/PRDetectionService.swift:112) [added]
[P2] PR queries ignore user scope

Both `getCurrentPR` and `getPRs` take a `user` parameter but never filter by it. This can pull PRs from other users and corrupt PR detection or history displays if multiple users exist (e.g., CloudKit shared data or test users). Add a user predicate (e.g., `pr.user?.id == user.id`) alongside the exercise filter.

## Finding 3 (Grove/Services/AchievementService.swift:100) [added]
[P2] Achievement progress not user-scoped

Progress counts are computed from unfiltered `Workout`/`PersonalRecord` fetches, which will include data from all users. If more than one user exists, the progress UI becomes incorrect. Filter by `user` (or user id) in those fetch predicates.

## Finding 4 (Grove/Views/Home/HomeView.swift:7) [added]
[P2] Home data not user-scoped

HomeView queries `WorkoutPlan`, `Workout`, `Achievement`, and `Exercise` without a user predicate. If multiple users exist, the UI will mix data and compute streaks/plans from other users. Add filters by the current user's ID to these `@Query` properties (and to any on-demand fetches like `getLastSetsForExercise`).

## Finding 5 (Grove/Services/StreakManager.swift:17) [added]
[P3] Streak gap logic ignores rest-day tracking

For gaps of 2–4 days, the streak is incremented unconditionally. But `consecutiveRestDays` is never checked here and `recordRestDay` is not called anywhere, so streaks will grow even without recorded rest days. Either enforce rest-day accounting or remove the rest-day claim from comments to avoid misleading logic.
