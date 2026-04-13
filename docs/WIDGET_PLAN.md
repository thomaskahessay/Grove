# Grove Widgets — Implementation Plan

## Context

Grove has no widgets today. Adding WidgetKit widgets lets users glance at their streak plant, today's plan, and weekly progress without opening the app — reinforcing the habit loop that drives the product. The main technical challenge is data sharing: widgets run in a separate process and can't access the main app's default SwiftData store. We'll solve this by moving the store to a shared App Group container.

---

## Phase 1: Foundation (App Group + Shared Store)

### 1a. Xcode Manual Steps (user does in Xcode)
- **Add Widget Extension target**: File → New → Target → Widget Extension
  - Product Name: `GroveWidgets`
  - Bundle ID: `com.thomaskahessay.Grove.GroveWidgets`
  - Uncheck "Include Configuration App Intent" and "Include Live Activity"
  - Set deployment target to iOS 26.0
- **Add App Group** to both targets (Grove + GroveWidgets):
  - Signing & Capabilities → + App Groups → `group.com.thomaskahessay.Grove`
- **Add shared file target membership**: Select each file below in Xcode, check `GroveWidgets` under Target Membership:
  - All 14 files in `Grove/Models/`
  - `Grove/Components/ColorExtensions.swift`
  - `Grove/Components/StreakPlant/PlantCanvasRenderer.swift`
  - `Grove/Services/SharedModelContainer.swift`

### 1b. Entitlements (we edit)
Add App Group to both entitlements files:
- `Grove/Grove.entitlements`
- `Grove/GroveRelease.entitlements`

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.thomaskahessay.Grove</string>
</array>
```

### 1c. SharedModelContainer.swift (new file — `Grove/Services/`)
Shared factory that both the main app and widget use to create a `ModelContainer` pointing to the App Group container URL.

- `static let appGroupID = "group.com.thomaskahessay.Grove"`
- `static var storeURL` → `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` + `"Grove.store"`
- `static func makeContainer() throws -> ModelContainer` — uses the shared URL with `cloudKitDatabase: .none`
- Full schema with all 10 `@Model` types (SwiftData requires the complete schema to open the store)

### 1d. Discover actual store filename (SAFETY STEP — do first)
Before writing any migration code, add a temporary `print()` in `GroveApp.init()` to log the real store path:
```swift
print("[Grove] Store URL: \(modelContainer.configurations.first?.url ?? URL(string: "unknown")!)")
```
Run the app on a device/simulator that has existing data. Record the exact filename from the console (e.g. `default.store`, `Grove.store`, etc.). Remove the print after confirming. This filename is used in 1e below.

### 1e. DataMigrator.swift (new file — `Grove/Services/`)
One-time **copy** (never move/delete) of existing SwiftData store to the shared container.

Safety guarantees:
- **Copy-only** — original files in `Application Support/` are never moved or deleted
- Copies `.store`, `.store-wal`, `.store-shm` files (using the filename confirmed in step 1d)
- Uses a `UserDefaults` flag (`Grove.SharedStoreMigrated`) to run only once
- **Skips if no existing store** (fresh install — flag is set, shared container gets a fresh store)
- **Validates after copy** — checks the copied file exists and is non-zero bytes before marking complete
- If copy fails or validation fails, does NOT set the migration flag — app falls back to opening the original default store location so no data is lost
- Logs all outcomes for debugging

Rollback plan: if anything goes wrong, revert `GroveApp.swift` to the original `ModelConfiguration` (no custom URL) and the app reads from the untouched original store.

### 1f. Modify GroveApp.swift
- `import WidgetKit`
- Call `DataMigrator.migrateIfNeeded()` before creating container
- **Only use shared store if migration succeeded** — check `DataMigrator.migrationComplete` before calling `SharedModelContainer.makeContainer()`. If migration hasn't completed (e.g. fresh install or first run), fall back to the default `ModelConfiguration` so existing data is never orphaned.
- Replace inline `ModelConfiguration` with `SharedModelContainer.makeContainer()` (only after migration confirmed)
- Keep existing fallback, seed, and migration logic unchanged
- Add `WidgetCenter.shared.reloadAllTimelines()` in the `.background` scene phase case

### 1f. Modify WorkoutSessionManager.swift
- `import WidgetKit`
- Add `WidgetCenter.shared.reloadAllTimelines()` at end of `endWorkout()` — triggers widget refresh when a workout completes

**Files modified:** `GroveApp.swift`, `WorkoutSessionManager.swift`, `Grove.entitlements`, `GroveRelease.entitlements`
**Files created:** `SharedModelContainer.swift`, `DataMigrator.swift`

---

## Phase 2: Streak Plant Widget

The most iconic widget — shows the user's plant with streak info.

### Files to create in `GroveWidgets/`:

**GroveWidgets.swift** — `@main WidgetBundle` registering all three widgets

**StreakPlantProvider.swift** — `TimelineProvider`
- `fetchEntry()`: creates `ModelContext` from `SharedModelContainer`, fetches `User`, reads `currentStreak`, `isStreakWilted`, `wiltedAtStage`
- Computes `PlantStage.from(streak:)` and `progressToNext()`
- Timeline policy: `.after(nextMidnight)` — streak changes happen daily; intra-day updates via `reloadAllTimelines()` from the app

**StreakPlantEntry.swift** — `TimelineEntry`
- `date`, `streak`, `isWilted`, `stage` (PlantStage), `progressToNext` (Double), `daysUntilNext` (Int?), `stageName` (String)

**StreakPlantWidgetView.swift** — size-specific layouts using `Canvas` + `PlantCanvasRenderer.draw()` with static params (`swayOffset: 0`, `growthProgress: 1.0`, `elapsedTime: 0`, `bloomPulse: 0.5`, `lightPhase: 0.5`)

| Size | Layout |
|------|--------|
| **Small** | Plant canvas filling widget. Streak count label at bottom ("14-day streak"). |
| **Medium** | Plant canvas left ~40%. Right side: stage name, streak count, progress bar to next stage. |
| **Large** | Tall plant canvas top ~60%. Below: stage name, streak, progress bar, days until next stage. |

- Wilted state: pass `isWilted: true` to renderer (desaturated, drooping)
- Empty state (no user): show seed with "Open Grove" label
- Deep link: `widgetURL(URL(string: "grove://streak"))`

---

## Phase 3: Today's Plan Widget

**TodaysPlanProvider.swift** — `TimelineProvider`
- Fetches `WorkoutPlan` where date matches today
- Reads template name, exercise count, category, completion status
- Falls back to "Rest Day" or "No Plan" states
- Also fetches tomorrow's plan for the large widget "Up Next" row
- Timeline policy: `.after(nextMidnight)`

**TodaysPlanEntry.swift** — `TimelineEntry`
- `date`, `planState` enum: `.workout(name, exerciseCount, category, isCompleted)`, `.restDay`, `.noPlan`
- Optional `tomorrowPlan` for large widget

**TodaysPlanWidgetView.swift**

| Size | Layout |
|------|--------|
| **Small** | Category icon, workout name (1-2 lines), exercise count. Checkmark overlay if completed. Rest day: leaf icon. |
| **Medium** | Category icon in tinted circle → workout name + exercise count → status indicator (checkmark or "Planned"). |
| **Large** | Full card: workout name, category badge, exercise count, status. If completed: duration. Bottom: "Up next" tomorrow row. |

- Colors: completed → `groveTerracotta`, planned → `groveSage`, rest → `groveWarmSand`, no plan → muted
- Deep link: `grove://todaysPlan`

---

## Phase 4: Weekly Progress Widget

**WeeklyProgressProvider.swift** — `TimelineProvider`
- Fetches `User.preferredDaysPerWeek` for goal
- Counts completed workouts (where `completedAt != nil`) in current Mon–Sun week
- Fetches `WorkoutPlan` for current week to determine day statuses
- Timeline policy: `.after(nextMidnight)`

**WeeklyProgressEntry.swift** — `TimelineEntry`
- `date`, `completedCount`, `goalCount`
- `dayStatuses: [DayStatus]` — 7 entries (Mon–Sun), each with letter + status (completed/planned/rest/today/todayDone)

**WeeklyProgressWidgetView.swift**

| Size | Layout |
|------|--------|
| **Small** | Circular progress ring (`completedCount/goalCount`). "workouts" label below. `groveSage` fill, `groveWarmSand` track. |
| **Medium** | Progress ring left + fraction. Right: 7 day-dots row (M T W T F S S) colored by status. |
| **Large** | Header + fraction. 7-column day grid with colored pills. Motivational text ("2 more to go!" / "Goal reached!"). Streak count at bottom. |

- Day dot colors: completed → `groveSage` filled, planned → `groveSage` stroke, rest → `groveWarmSand` small dot, today pending → `groveTerracotta` stroke, today done → `groveTerracotta` filled
- Deep link: `grove://weeklyProgress`

---

## Phase 5: Polish

- Handle deep links in `GroveApp.swift` `onOpenURL` (grove://streak, grove://todaysPlan, grove://weeklyProgress)
- Handle empty/pre-onboarding state in all widgets ("Open Grove to get started")
- Test light + dark mode appearance
- Test data migration (existing store → shared container)

---

## Widget Refresh Strategy

| Trigger | Mechanism |
|---------|-----------|
| Daily midnight | Each provider: `.after(nextMidnight)` |
| Workout completed | `endWorkout()` → `WidgetCenter.shared.reloadAllTimelines()` |
| App backgrounded | `scenePhase .background` → `WidgetCenter.shared.reloadAllTimelines()` |

---

## Implementation Order

1. **Phase 1** first — everything else depends on the shared store
2. **Phase 2** (Streak Plant) — tests Canvas rendering in widget context, validates data sharing works
3. **Phase 3** (Today's Plan) — builds on proven data flow
4. **Phase 4** (Weekly Progress) — most complex queries, built last
5. **Phase 5** (Polish) — deep links, edge cases, dark mode

---

## Files Summary

**New files (we create):**
- `Grove/Services/SharedModelContainer.swift`
- `Grove/Services/DataMigrator.swift`
- `GroveWidgets/GroveWidgets.swift`
- `GroveWidgets/StreakPlantProvider.swift`
- `GroveWidgets/StreakPlantEntry.swift`
- `GroveWidgets/StreakPlantWidgetView.swift`
- `GroveWidgets/TodaysPlanProvider.swift`
- `GroveWidgets/TodaysPlanEntry.swift`
- `GroveWidgets/TodaysPlanWidgetView.swift`
- `GroveWidgets/WeeklyProgressProvider.swift`
- `GroveWidgets/WeeklyProgressEntry.swift`
- `GroveWidgets/WeeklyProgressWidgetView.swift`

**Modified files:**
- `Grove/GroveApp.swift` — use SharedModelContainer, add WidgetKit reload, handle deep links
- `Grove/Services/WorkoutSessionManager.swift` — add WidgetKit reload in endWorkout()
- `Grove/Grove.entitlements` — add App Group
- `Grove/GroveRelease.entitlements` — add App Group

**Shared with widget target (via Xcode target membership):**
- All `Grove/Models/*.swift` (14 files)
- `Grove/Components/ColorExtensions.swift`
- `Grove/Components/StreakPlant/PlantCanvasRenderer.swift`
- `Grove/Services/SharedModelContainer.swift`

---

## Verification

1. Build main app — confirm it still launches, creates/reads data at the new shared store URL
2. Run on simulator — add each widget from the widget gallery, verify data appears
3. Complete a workout — confirm all widgets update within seconds
4. Test with no user data — confirm empty states render gracefully
5. Test light/dark mode — confirm earthy palette looks correct in both
6. Kill and relaunch app — confirm data persists (migration didn't break anything)
