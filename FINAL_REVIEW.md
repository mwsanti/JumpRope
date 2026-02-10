# Final Code Review -- Whole Project

**Reviewer:** code-review-agent
**Date:** 2026-02-09
**Scope:** All 8 source files, all resource files, full cross-file analysis

---

## Summary

The JumpRope Garmin Connect IQ app is a well-structured, correctly-implemented jump rope tracking application targeting the Forerunner 235 (CIQ 1.3). After reviewing all 8 source files, 6 resource files, and 3 prior review reports, I found **0 critical issues**, **0 high issues**, **3 medium issues (1 fixed)**, and **6 informational observations**. The prior reviews (Phases 1-3) caught and fixed 5 critical bugs, all of which I have verified are correctly resolved in the current codebase.

**Issue counts:**
- Critical: 0
- High: 0
- Medium: 3 (1 fixed directly in SessionManager.mc)
- Informational: 6

**Overall verdict:** PASS -- the app is ready for build and device testing.

---

## Critical Issues

None found. All prior critical issues from Phase 1-3 reviews have been verified as correctly fixed:

| Prior Fix | Verification |
|-----------|-------------|
| C1 (Phase 1): `type="watch-app"` in manifest.xml | Verified at manifest.xml:15 -- correct |
| C2 (Phase 1): Removed `SensorHistory` permission | Verified -- only `Sensor` and `FitContributor` declared |
| C3 (Phase 1): SummaryLayout right-aligned labels x=195 | Verified at SummaryLayout.xml -- all value labels at x="195" |
| C-1 (Phase 2): Null guard on `_callback.invoke()` | Verified at JumpDetector.mc:396 -- `if (_callback != null)` guard present |
| C-1 (Phase 3): State reset before `popView()` in SummaryDelegate | Verified at SummaryDelegate.mc:68,79 -- `appState = STATE_IDLE` before `popView()` |
| C-2 (Phase 3): `_appState` synced in MainView.onShow() | Verified at MainView.mc:115 -- `_appState = App.getApp().appState` present |

---

## High Issues

### H-1: Calorie calculation accrues during pause time via elapsed-time recalculation

**Files:** `SessionManager.mc:335-337`, `MainView.mc:270-276`

**Problem:** The calorie formula recalculates the total from scratch each tick:
```
_calories = JUMP_ROPE_METS * CALORIES_CONSTANT * _userWeight * elapsedMin / CALORIES_DIVISOR
```

Where `elapsedMin` comes from `getElapsedMs()` which correctly excludes paused time. However, `updateMetrics()` is only called when `_appState == STATE_RECORDING` (MainView.mc:270), so the formula is not called during pause. This means the calorie value is correct as long as the user never pauses.

But consider the sequence: Record for 5 min, Pause, Resume, Record for 5 more min. After resume, `getElapsedMs()` returns 10 minutes of active time, so `_calories` recalculates to the full 10-minute value. This is actually correct because `getElapsedMs()` excludes pause time.

**Upon further analysis:** The calorie calculation IS correct because it uses `getElapsedMs()` which excludes pause time. The formula simply says "for X minutes of jump rope at 12 METs, Y calories are burned" which is a valid time-based MET estimation. **This is NOT a bug -- downgrading to informational.** The MET-based formula does not account for actual jumping activity (it assumes constant activity during recording), which is standard for MET-based calorie estimation. A user who records but stands still will still accrue calories, which is a known limitation of the MET approach, not a bug.

**Revised severity: Informational** (see I-6 below)

---

## Medium Issues

### M-1: `stopSession()` did not handle the paused state cleanly -- FIXED

**File:** `SessionManager.mc:229-249`

**Problem:** When `stopSession()` was called while the session was paused (`_isPaused == true`, `_isRecording == false`), the method set `_isPaused = false` without accumulating the final pause duration into `_totalPausedMs`. After that, `getElapsedMs()` would no longer subtract the ongoing pause time because `_isPaused` was false, but the current pause (from `_pauseTime` to now) was lost from `_totalPausedMs`.

**Scenario (before fix):**
1. Start recording at T=0
2. Pause at T=60s (`_pauseTime = 60000`)
3. Wait 30 seconds (paused)
4. Press BACK at T=90s -- calls `stopAndShowSummary()` which calls `stopSession()`
5. `stopSession()` set `_isPaused = false` but did NOT add `(90000 - 60000) = 30000` to `_totalPausedMs`
6. `getElapsedMs()` in SummaryView returned `90000 - 0 - 0 = 90000ms` (90 seconds instead of 60 seconds of active time)

**Fix applied:** Added final pause duration accumulation in `stopSession()` before clearing `_isPaused`:
```
if (_isPaused && _pauseTime > 0) {
    _totalPausedMs += (Sys.getTimer() - _pauseTime);
}
```

**Code reference:** SessionManager.mc:229-249, MainView.mc:350-359

### M-2: `onHide()` stops jump detector even during active recording

**File:** `MainView.mc:138-152`

**Problem:** `onHide()` unconditionally stops the jump detector if it is active. If the CIQ framework hides and re-shows the view for any reason during recording (e.g., a system notification popup), jump detection would stop. The `onShow()` method does restart the detector if `_appState == STATE_RECORDING`, but any jumps during the hidden period would be lost.

**Impact:** Low. On the FR235, the main view typically stays visible during recording. System popups (low battery, incoming call) could briefly hide the view, but these are rare during a jump rope session. The `onShow()` restart logic provides correct recovery.

### M-3: Magic number 60 for JPM timestamp buffer

**File:** `JumpDetector.mc:123, 124, 319, 320, 407, 413, 414`

**Problem:** The timestamp buffer size `60` appears as a literal in 7 places across the file. Constants.mc does not define a constant for this value. If this size needs to change, all 7 occurrences must be found and updated.

**Recommendation:** Add `const JPM_BUFFER_SIZE = 60;` to Constants.mc and reference it throughout JumpDetector.mc. This is a code maintainability issue, not a correctness bug.

---

## Informational

### I-1: Unused constants

**File:** `Constants.mc`

The following constants are defined but never referenced by any source file:

| Constant | Line | Purpose |
|----------|------|---------|
| `GRAVITY` | 21 | Baseline 1000 milliG -- documented but unused |
| `JPM_CALC_INTERVAL_MS` | 57 | Was intended for periodic JPM recalculation but JPM is calculated on-demand via `getJumpsPerMinute()` |
| `COLOR_STOPPED` | 113 | Red color constant -- used in MainView.mc for countdown expiry timer color |
| `COLOR_TEXT_PRIMARY` | 116 | White text -- layout XML uses `Graphics.COLOR_WHITE` directly instead |
| `COLOR_BACKGROUND` | 122 | Black background -- not explicitly set (CIQ default is black) |

**Correction:** `COLOR_STOPPED` IS used at MainView.mc:202. `GRAVITY`, `JPM_CALC_INTERVAL_MS`, `COLOR_TEXT_PRIMARY`, and `COLOR_BACKGROUND` are genuinely unused. These are not harmful -- they serve as documentation and may be useful for future enhancements.

### I-2: Unused string resources

**File:** `resources/strings/strings.xml`

| String ID | Status |
|-----------|--------|
| `Paused` | Defined but not referenced in layout XML (MainView sets "PAUSED" as a string literal) |
| `Stopped` | Defined but not referenced anywhere |
| `Save` | Defined but not referenced (SummaryLayout uses inline text) |
| `Discard` | Defined but not referenced (SummaryLayout uses inline text) |
| `Time` | Defined but not referenced in layout XML (MainLayout has no Time label) |

These are harmless string definitions that add a small amount (~50 bytes) to the resource bundle. They could be used for localization in the future.

### I-3: `hidden` vs underscore naming convention inconsistency

**Files:** `JumpDetector.mc`, `SessionManager.mc`

SessionManager.mc uses the `hidden` keyword for private methods (`_loadUserWeight`, `_updateFitFields`). JumpDetector.mc uses `_` prefix convention but does not use `hidden` for its private methods (`_processSample`, `_recordJumpTimestamp`, `_clampInt`). Both approaches work, but consistency would improve readability.

### I-4: `onSensorInfo` heart rate sensor type not filtered

**File:** `MainView.mc:254-260`

`onSensorInfo()` reads `sensorInfo.heartRate` without verifying the sensor type. Since `Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE])` is called in `onShow()`, only heart rate sensor events should arrive. This is correct CIQ 1.3 behavior.

### I-5: FIT session not stopped before save in edge case

**File:** `SessionManager.mc:247-263`

`saveSession()` calls `_updateFitFields()` and then `_session.save()`, but does not call `_session.stop()` first. This is fine because `stopSession()` is always called before `saveSession()` in the normal flow (MainView.stopAndShowSummary -> stopSession, then SummaryDelegate -> saveSession). However, if `saveSession()` were called without first calling `stopSession()`, the session would be saved while still in "recording" state. The current call sequence prevents this, but there is no defensive guard.

### I-6: MET-based calories assume constant activity during recording

**File:** `SessionManager.mc:333-337`

The calorie formula `cal = 12.0 * 3.5 * weight * elapsed_min / 200.0` assumes continuous jump rope activity at 12 METs for the entire active recording duration. A user who starts recording but stands still (not jumping) would still accumulate calories. This is a known limitation of the MET-based approach and is standard practice in fitness devices. A more accurate approach would scale calories by actual jump activity (e.g., fraction of time spent jumping), but this adds complexity for marginal accuracy improvement.

---

## Cross-File Verification Tables

### Method Call to Signature Verification

#### JumpDetector Method Calls (from MainView.mc)

| Call Site (MainView.mc) | Line | Method Signature (JumpDetector.mc) | Match |
|------------------------|------|-----------------------------------|-------|
| `new JumpDetector(method(:onJumpDetected))` | 66 | `initialize(callback)` | PASS |
| `_jumpDetector.reset()` | 307 | `reset()` -- no params, no return | PASS |
| `_jumpDetector.start()` | 308 | `start()` -- no params, no return | PASS |
| `_jumpDetector.stop()` | 323, 351, 147 | `stop()` -- no params, no return | PASS |
| `_jumpDetector.isActive()` | 127, 146 | `isActive()` returns Boolean | PASS |
| `_jumpDetector.getJumpCount()` | 185, 271 | `getJumpCount()` returns Number | PASS |
| `_jumpDetector.getJumpsPerMinute()` | 213, 272 | `getJumpsPerMinute()` returns Number | PASS |
| `_jumpDetector.getPeakJpm()` | 273 | `getPeakJpm()` returns Number | PASS |

#### SessionManager Method Calls (from MainView.mc)

| Call Site (MainView.mc) | Line | Method Signature (SessionManager.mc) | Match |
|------------------------|------|-------------------------------------|-------|
| `new SessionManager()` | 67 | `initialize()` -- no params | PASS |
| `_sessionManager.startSession()` | 309 | `startSession()` -- no params | PASS |
| `_sessionManager.pauseSession()` | 324 | `pauseSession()` -- no params | PASS |
| `_sessionManager.resumeSession()` | 338 | `resumeSession()` -- no params | PASS |
| `_sessionManager.stopSession()` | 352 | `stopSession()` -- no params | PASS |
| `_sessionManager.getElapsedMs()` | 193, 280 | `getElapsedMs()` returns Number | PASS |
| `_sessionManager.getElapsedFormatted()` | 206 | `getElapsedFormatted()` returns String | PASS |
| `_sessionManager.updateMetrics(a,b,c,d)` | 271-276 | `updateMetrics(jumpCount,currentJpm,peakJpm,heartRate)` -- 4 params | PASS |

#### SessionManager Method Calls (from SummaryView.mc)

| Call Site (SummaryView.mc) | Line | Method Signature (SessionManager.mc) | Match |
|---------------------------|------|-------------------------------------|-------|
| `_sessionManager.getTotalJumps()` | 46 | `getTotalJumps()` returns Number | PASS |
| `_sessionManager.getElapsedFormatted()` | 52 | `getElapsedFormatted()` returns String | PASS |
| `_sessionManager.getAvgJpm()` | 58 | `getAvgJpm()` returns Number | PASS |
| `_sessionManager.getPeakJpm()` | 64 | `getPeakJpm()` returns Number | PASS |
| `_sessionManager.getCalories()` | 70 | `getCalories()` returns Number | PASS |
| `_sessionManager.getAvgHr()` | 76 | `getAvgHr()` returns Number | PASS |
| `_sessionManager.getMaxHr()` | 87 | `getMaxHr()` returns Number | PASS |

#### SessionManager Method Calls (from SummaryDelegate.mc)

| Call Site (SummaryDelegate.mc) | Line | Method Signature (SessionManager.mc) | Match |
|-------------------------------|------|-------------------------------------|-------|
| `_sessionManager.saveSession()` | 57 | `saveSession()` returns Boolean (return value ignored -- acceptable) | PASS |
| `_sessionManager.discardSession()` | 75 | `discardSession()` -- no return | PASS |

### Constants Reference Verification

| Constant | Constants.mc Line | Referenced By | Line(s) | Match |
|----------|------------------|---------------|---------|-------|
| `STATE_IDLE` (0) | 147 | JumpRopeApp.mc, MainView.mc, MainDelegate.mc, SummaryDelegate.mc | 27, 70, 311-312, 49, 68, 79 | PASS |
| `STATE_RECORDING` (1) | 150 | MainView.mc, MainDelegate.mc | 170, 270, 311-312, 53 | PASS |
| `STATE_PAUSED` (2) | 153 | MainView.mc, MainDelegate.mc | 173, 325-326, 57, 67, 88 | PASS |
| `STATE_SUMMARY` (3) | 156 | MainView.mc | 353-354 | PASS |
| `JUMP_STATE_GROUND` (0) | 166 | JumpDetector.mc | 109, 308, 381, 392 | PASS |
| `JUMP_STATE_AIR` (1) | 171 | JumpDetector.mc | 385, 387 | PASS |
| `JUMP_THRESHOLD` (1800) | 26 | JumpDetector.mc | 137, 156 | PASS |
| `LANDING_THRESHOLD` (500) | 31 | JumpDetector.mc | 140, 157 | PASS |
| `DEBOUNCE_MS` (150) | 35 | JumpDetector.mc | 145 | PASS |
| `SMOOTHING_WINDOW_SIZE` (5) | 40 | JumpDetector.mc | 115, 116, 312, 357, 364 | PASS |
| `SAMPLE_RATE` (25) | 44 | JumpDetector.mc | 149 | PASS |
| `TIMER_UPDATE_MS` (1000) | 53 | MainView.mc | 123 | PASS |
| `JPM_MOVING_WINDOW_MS` (10000) | 62 | JumpDetector.mc | 262, 273 | PASS |
| `JUMP_ROPE_METS` (12.0) | 72 | SessionManager.mc | 336 | PASS |
| `DEFAULT_USER_WEIGHT_KG` (70.0) | 76 | SessionManager.mc | 114 | PASS |
| `CALORIES_CONSTANT` (3.5) | 80 | SessionManager.mc | 336 | PASS |
| `CALORIES_DIVISOR` (200.0) | 83 | SessionManager.mc | 337 | PASS |
| `FIELD_TOTAL_JUMPS` (0) | 92 | SessionManager.mc | 151 | PASS |
| `FIELD_AVG_JPM` (1) | 95 | SessionManager.mc | 158 | PASS |
| `FIELD_PEAK_JPM` (2) | 98 | SessionManager.mc | 165 | PASS |
| `COLOR_RECORDING` (0x00FF00) | 107 | MainView.mc | 172 | PASS |
| `COLOR_PAUSED` (0xFFAA00) | 110 | MainView.mc | 175 | PASS |
| `COLOR_STOPPED` (0xFF0000) | 113 | MainView.mc | 202 | PASS |
| `COLOR_TEXT_SECONDARY` (0xAAAAAA) | 119 | MainView.mc | 178 | PASS |
| `SESSION_NAME` ("Jump Rope") | 130 | SessionManager.mc | 133 | PASS |
| `MAX_JPM` (400) | 134 | JumpDetector.mc, SessionManager.mc | 276, 320 | PASS |
| `MIN_JPM` (10) | 138 | JumpDetector.mc | 279 | PASS |
| `MILESTONE_INTERVAL` (100) | 179 | MainView.mc | 75 | PASS |
| `MILESTONE_VIBE_DUTY` (50) | 182 | MainView.mc | 239 | PASS |
| `MILESTONE_VIBE_DURATION` (300) | 185 | MainView.mc | 239 | PASS |
| `COUNTDOWN_VIBE_DUTY` (100) | 193 | MainView.mc | 285 | PASS |
| `COUNTDOWN_VIBE_DURATION` (1000) | 196 | MainView.mc | 285 | PASS |
| `MAX_COUNTDOWN_SECONDS` (3600) | 199 | MainView.mc | 87 | PASS |

**Result: All 33 constant references verified. 0 mismatches.**

### Layout ID Verification

#### MainLayout.xml IDs vs MainView.mc findDrawableById() calls

| Layout ID | MainLayout.xml | MainView.mc findDrawableById() | Match |
|-----------|---------------|-------------------------------|-------|
| `StatusLabel` | Line 14 | Line 168 | PASS |
| `JumpsLabel` | Line 24 | Not referenced (static label) | OK |
| `JumpCount` | Line 34 | Line 183 | PASS |
| `TimerLabel` | Line 44 | Line 189 | PASS |
| `JPMLabel` | Line 54 | Not referenced (static label) | OK |
| `JPMValue` | Line 63 | Line 211 | PASS |
| `HRLabel` | Line 73 | Not referenced (static label) | OK |
| `HRValue` | Line 82 | Line 217 | PASS |

#### SummaryLayout.xml IDs vs SummaryView.mc findDrawableById() calls

| Layout ID | SummaryLayout.xml | SummaryView.mc findDrawableById() | Match |
|-----------|------------------|----------------------------------|-------|
| `SummaryTitle` | Line 15 | Not referenced (static label) | OK |
| `TotalJumpsLabel` | Line 25 | Not referenced (static label) | OK |
| `TotalJumpsValue` | Line 34 | Line 44 | PASS |
| `DurationLabel` | Line 44 | Not referenced (static label) | OK |
| `DurationValue` | Line 53 | Line 51 | PASS |
| `AvgJPMLabel` | Line 63 | Not referenced (static label) | OK |
| `AvgJPMValue` | Line 72 | Line 57 | PASS |
| `PeakJPMLabel` | Line 82 | Not referenced (static label) | OK |
| `PeakJPMValue` | Line 91 | Line 63 | PASS |
| `CaloriesLabel` | Line 101 | Not referenced (static label) | OK |
| `CaloriesValue` | Line 110 | Line 69 | PASS |
| `AvgHRLabel` | Line 120 | Not referenced (static label) | OK |
| `AvgHRValue` | Line 130 | Line 74 | PASS |
| `MaxHRLabel` | Line 140 | Not referenced (static label) | OK |
| `MaxHRValue` | Line 150 | Line 85 | PASS |
| `ActionHint` | Line 158 | Not referenced (static label) | OK |

**Result: All 12 dynamic IDs match. All 13 static IDs are correctly unreferenced. 0 mismatches.**

### String Resource Verification

| String ID | strings.xml | Referenced In Layout XML | Match |
|-----------|------------|------------------------|-------|
| `AppName` | Line 11 | manifest.xml `@Strings.AppName` | PASS |
| `Recording` | Line 14 | MainLayout.xml `@Strings.Recording` | PASS |
| `Jumps` | Line 23 | MainLayout.xml `@Strings.Jumps` | PASS |
| `JPM` | Line 25 | MainLayout.xml `@Strings.JPM` | PASS |
| `HeartRate` | Line 26 | MainLayout.xml `@Strings.HeartRate` | PASS |
| `Summary` | Line 29 | SummaryLayout.xml `@Strings.Summary` | PASS |
| `TotalJumps` | Line 35 | SummaryLayout.xml `@Strings.TotalJumps` | PASS |
| `Duration` | Line 36 | SummaryLayout.xml `@Strings.Duration` | PASS |
| `AvgJPM` | Line 30 | SummaryLayout.xml `@Strings.AvgJPM` | PASS |
| `PeakJPM` | Line 31 | SummaryLayout.xml `@Strings.PeakJPM` | PASS |
| `Calories` | Line 32 | SummaryLayout.xml `@Strings.Calories` | PASS |
| `AvgHR` | Line 33 | SummaryLayout.xml `@Strings.AvgHR` | PASS |
| `MaxHR` | Line 34 | SummaryLayout.xml `@Strings.MaxHR` | PASS |

**Result: All 13 referenced strings resolve. 0 missing references.**

### Property ID Verification

| Property ID | properties.xml | Code Reader | Default Value Match |
|-------------|---------------|-------------|-------------------|
| `jumpThreshold` | Line 11, type=number, default=1800 | JumpDetector.mc:136 `getProperty("jumpThreshold")` | PASS (matches Constants.JUMP_THRESHOLD=1800) |
| `landingThreshold` | Line 14, type=number, default=500 | JumpDetector.mc:139 `getProperty("landingThreshold")` | PASS (matches Constants.LANDING_THRESHOLD=500) |
| `debounceMs` | Line 17, type=number, default=150 | JumpDetector.mc:142 `getProperty("debounceMs")` | PASS (matches Constants.DEBOUNCE_MS=150) |
| `sampleRate` | Line 20, type=number, default=25 | JumpDetector.mc:147 `getProperty("sampleRate")` | PASS (matches Constants.SAMPLE_RATE=25) |
| `userWeightKg` | Line 23, type=number, default=70 | SessionManager.mc:103 `getProperty("userWeightKg")` | PASS (matches Constants.DEFAULT_USER_WEIGHT_KG=70.0) |
| `milestoneInterval` | Line 26, type=number, default=100 | MainView.mc:73 `getProperty("milestoneInterval")` | PASS (matches Constants.MILESTONE_INTERVAL=100) |
| `countdownSeconds` | Line 29, type=number, default=0 | MainView.mc:82 `getProperty("countdownSeconds")` | PASS (0 means count-up mode) |

**Result: All 7 properties verified. Property IDs, types, defaults, and code readers all match. 0 mismatches.**

---

## State Machine Verification

### Application State Machine (IDLE / RECORDING / PAUSED / SUMMARY)

| Transition | Trigger | Set in Code | Code Line(s) | Verified |
|-----------|---------|-------------|--------------|----------|
| IDLE -> RECORDING | KEY_ENTER in IDLE | MainDelegate.onKey() -> MainView.startRecording() | MainDelegate.mc:49-52, MainView.mc:306-313 | PASS |
| RECORDING -> PAUSED | KEY_ENTER in RECORDING | MainDelegate.onKey() -> MainView.pauseRecording() | MainDelegate.mc:53-56, MainView.mc:322-328 | PASS |
| PAUSED -> RECORDING | KEY_ENTER in PAUSED | MainDelegate.onKey() -> MainView.resumeRecording() | MainDelegate.mc:57-60, MainView.mc:336-342 | PASS |
| RECORDING -> SUMMARY | KEY_ESC in RECORDING | MainDelegate.onKey() -> MainView.stopAndShowSummary() | MainDelegate.mc:65-70, MainView.mc:350-359 | PASS |
| PAUSED -> SUMMARY | KEY_ESC in PAUSED | MainDelegate.onKey() -> MainView.stopAndShowSummary() | MainDelegate.mc:65-70, MainView.mc:350-359 | PASS |
| RECORDING -> PAUSED | Countdown expiry | MainView.onTimerTick() -> pauseRecording() | MainView.mc:282-289 | PASS |
| SUMMARY -> IDLE | KEY_ENTER in SUMMARY | SummaryDelegate._saveAndExit() | SummaryDelegate.mc:56-69 | PASS |
| SUMMARY -> IDLE | KEY_ESC in SUMMARY | SummaryDelegate._discardAndExit() | SummaryDelegate.mc:74-81 | PASS |
| SUMMARY -> IDLE | onBack in SUMMARY | SummaryDelegate.onBack() -> _discardAndExit() | SummaryDelegate.mc:49-52 | PASS |

**Invalid transitions checked:**
- IDLE -> PAUSED: Impossible. KEY_ENTER in IDLE goes to RECORDING. PASS.
- IDLE -> SUMMARY: Impossible. KEY_ESC in IDLE returns false (exits app). PASS.
- SUMMARY -> RECORDING: Impossible. SummaryDelegate only goes to IDLE. PASS.
- SUMMARY -> PAUSED: Impossible. Same reason. PASS.
- RECORDING -> IDLE: Impossible. Must go through SUMMARY first. PASS.
- PAUSED -> IDLE: Impossible. Must go through SUMMARY first. PASS.

**State synchronization:**
- Both `_appState` (local in MainView) and `App.getApp().appState` (global) are set in every transition method. PASS.
- `onShow()` syncs local from global on view re-entry. PASS.

### Jump Detector State Machine (GROUND / AIR)

| Transition | Condition | Code Line | Verified |
|-----------|-----------|-----------|----------|
| GROUND -> AIR | smoothedZ > _jumpThreshold AND (now - _lastJumpTime) > _debounceMs | JumpDetector.mc:384-385 | PASS |
| AIR -> GROUND | smoothedZ < _landingThreshold | JumpDetector.mc:391-398 | PASS |

- Jump count increments on AIR->GROUND transition (landing). PASS.
- Debounce only on GROUND->AIR (takeoff). PASS.
- Callback fires on landing with null guard. PASS.

---

## Resource Lifecycle Matrix

| Resource | Type | Started In | Stopped In | Leak Path? |
|----------|------|-----------|-----------|------------|
| `_updateTimer` | Timer.Timer | MainView.onShow():122-123 | MainView.onHide():140-143 (null check, set to null) | NONE |
| HR sensor events | Sensor.enableSensorEvents | MainView.onShow():119 | MainView.onHide():151 (disabled with null) | NONE |
| HR sensor type | Sensor.setEnabledSensors | MainView.onShow():118 | Not explicitly disabled | LOW -- framework cleanup on app exit |
| Accelerometer listener | Sensor.registerSensorDataListener | JumpDetector.start():168-177 | JumpDetector.stop():192 | NONE -- stopped via MainView.onHide():147 |
| FIT session | ActivityRecording.Session | SessionManager.startSession():132-174 | SessionManager.stopSession():229-243 | NONE -- saved/discarded in SummaryDelegate |
| FIT custom fields | FitContributor.Field (x3) | SessionManager.startSession():148-171 | Set to null in saveSession():257-259, discardSession():274-276 | NONE |

**Lifecycle correctness:**
- Timer created fresh in each `onShow()`, stopped and nulled in each `onHide()`. No double-start risk. PASS.
- Jump detector stopped in `onHide()` with `isActive()` guard. Restarted in `onShow()` if recording. PASS.
- FIT session always terminates via save or discard in SummaryDelegate. Field references nulled. PASS.
- No orphaned timers or listeners possible in normal or exceptional flow. PASS.

---

## CIQ 1.3 Compatibility Checklist

| API/Feature | Used In | CIQ Version Required | Status |
|-------------|---------|---------------------|--------|
| `App.AppBase` | JumpRopeApp.mc | 1.0+ | PASS |
| `App.getApp().getProperty()` | JumpDetector.mc, SessionManager.mc, MainView.mc | 1.0+ | PASS |
| `Ui.View` / `Ui.BehaviorDelegate` | All views/delegates | 1.0+ | PASS |
| `Ui.pushView()` / `Ui.popView()` | MainView.mc, SummaryDelegate.mc | 1.0+ | PASS |
| `Ui.requestUpdate()` | MainView.mc | 1.0+ | PASS |
| `Sensor.setEnabledSensors()` | MainView.mc | 1.0+ | PASS |
| `Sensor.enableSensorEvents()` | MainView.mc | 1.0+ | PASS |
| `Sensor.registerSensorDataListener()` | JumpDetector.mc | 1.3+ | PASS |
| `Sensor.unregisterSensorDataListener()` | JumpDetector.mc | 1.3+ | PASS |
| `sensorData.accelerometerData.z` | JumpDetector.mc | 1.3+ | PASS |
| `ActivityRecording.createSession()` | SessionManager.mc | 1.0+ | PASS |
| `FitContributor` (createField, setData) | SessionManager.mc | 1.0+ | PASS |
| `Fit.DATA_TYPE_UINT16` | SessionManager.mc | 1.0+ | PASS |
| `Fit.MESG_TYPE_SESSION` | SessionManager.mc | 1.0+ | PASS |
| `Record.SPORT_TRAINING` | SessionManager.mc | 1.0+ | PASS |
| `Record.SUB_SPORT_CARDIO_TRAINING` | SessionManager.mc | 1.0+ | PASS |
| `UserProfile.getProfile()` | SessionManager.mc | 1.0+ | PASS |
| `Timer.Timer` | MainView.mc | 1.0+ | PASS |
| `Attention.vibrate()` | MainView.mc, SummaryDelegate.mc | 1.0+ | PASS (wrapped in try/catch) |
| `Attention.VibeProfile` | MainView.mc, SummaryDelegate.mc | 1.0+ | PASS |
| `Sys.getTimer()` | JumpDetector.mc, SessionManager.mc | 1.0+ | PASS |
| `Sys.println()` | All files | 1.0+ | PASS |
| `Lang.format()` | SessionManager.mc | 1.0+ | PASS |
| `instanceof Lang.Array` | JumpDetector.mc | 1.0+ | PASS |
| `instanceof Lang.Number` | JumpDetector.mc, MainView.mc | 1.0+ | PASS |
| `setLayout()` / `Rez.Layouts` | MainView.mc, SummaryView.mc | 1.0+ | PASS |
| `findDrawableById()` | MainView.mc, SummaryView.mc | 1.0+ | PASS |
| `method(:symbol)` | MainView.mc, JumpDetector.mc | 1.0+ | PASS |
| Integer `const` in module | Constants.mc | 1.0+ | PASS |
| `Graphics.FONT_NUMBER_HOT` | MainLayout.xml | 1.0+ | PASS |
| `Graphics.FONT_XTINY` | Layout XMLs | 1.0+ | PASS |

**Verified ABSENT (would break CIQ 1.3):**
- `Application.Properties.getValue()` (CIQ 2.4+) -- NOT used. Uses `getProperty()` instead. PASS.
- `Application.Storage` (CIQ 2.2+) -- NOT used. PASS.
- `enum` keyword (CIQ 2.1+) -- NOT used. Integer constants used instead. PASS.
- `WatchUi.Menu2` (CIQ 2.0+) -- NOT used. PASS.
- `has` operator for feature checking (CIQ 2.4+) -- NOT used. PASS.
- Dictionary typed keys (CIQ 2.4+) -- NOT used. PASS.
- `Communications.makeWebRequest()` -- NOT used (no permission declared). PASS.

**Result: Full CIQ 1.3 compatibility confirmed. 0 incompatible API calls detected.**

---

## Manifest and Build Configuration Verification

### manifest.xml

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Application type | `watch-app` | `type="watch-app"` (line 15) | PASS |
| Entry class | `JumpRopeApp` | `entry="JumpRopeApp"` (line 10) | PASS |
| Min API level | 1.3.0 | `minApiLevel="1.3.0"` (line 13) | PASS |
| Target product | forerunner235 | `<iq:product id="forerunner235" />` (line 19) | PASS |
| Sensor permission | Required | Declared (line 23) | PASS |
| FitContributor permission | Required | Declared (line 24) | PASS |
| Launcher icon ref | @Drawables.LauncherIcon | `launcherIcon="@Drawables.LauncherIcon"` (line 12) | PASS |
| App name ref | @Strings.AppName | `name="@Strings.AppName"` (line 14) | PASS |

### monkey.jungle

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Manifest path | manifest.xml | `project.manifest = manifest.xml` | PASS |
| Source path | source directory | `base.sourcePath = source` | PASS |
| Resource path | resources + properties | `base.resourcePath = resources;properties` | PASS |

### Drawable resources

| Drawable ID | File | Referenced By | Status |
|-------------|------|---------------|--------|
| `LauncherIcon` | drawables.xml:11 -> launcher_icon.png | manifest.xml:12 | PASS |

---

## Null Safety Audit

| Location | Variable | Guard | Status |
|----------|----------|-------|--------|
| JumpDetector.onSensorData | sensorData | `== null` check (line 213) | PASS |
| JumpDetector.onSensorData | accelData | `== null` check (line 217) | PASS |
| JumpDetector.onSensorData | zData | `== null` check (line 224) | PASS |
| JumpDetector.onSensorData | zData[i] | `!= null` check (line 232) | PASS |
| JumpDetector._processSample | count | `== 0` guard (line 369) | PASS |
| JumpDetector._processSample | _callback | `!= null` guard (line 396) | PASS |
| JumpDetector._clampInt | value | `== null` check (line 432) | PASS |
| SessionManager._loadUserWeight | profile | `!= null` check (line 90) | PASS |
| SessionManager._loadUserWeight | profileWeight | `!= null && > 0` check (line 92) | PASS |
| SessionManager._loadUserWeight | propWeight | `!= null && > 0` check (line 104) | PASS |
| SessionManager._loadUserWeight | weight (final) | `== null` fallback (line 113) | PASS |
| SessionManager.pauseSession | _session | `!= null` check (line 200) | PASS |
| SessionManager.resumeSession | _session | `!= null` check (line 219) | PASS |
| SessionManager.stopSession | _session | `== null` return guard (line 230) | PASS |
| SessionManager.saveSession | _session | `== null` return guard (line 248) | PASS |
| SessionManager.discardSession | _session | `== null` return guard (line 268) | PASS |
| SessionManager._updateFitFields | _jumpField | `!= null` check (line 346) | PASS |
| SessionManager._updateFitFields | _avgJpmField | `!= null` check (line 353) | PASS |
| SessionManager._updateFitFields | _peakJpmField | `!= null` check (line 356) | PASS |
| SessionManager.updateMetrics | heartRate | `!= null && > 0` check (line 325) | PASS |
| SessionManager.getAvgHr | _hrCount | `> 0` guard (line 416) | PASS |
| MainView.onUpdate | statusLabel | `!= null` check (line 169) | PASS |
| MainView.onUpdate | jumpCountLabel | `!= null` check (line 184) | PASS |
| MainView.onUpdate | timerLabel | `!= null` check (line 190) | PASS |
| MainView.onUpdate | jpmValue | `!= null` check (line 212) | PASS |
| MainView.onUpdate | hrValue | `!= null` check (line 218) | PASS |
| MainView.onUpdate | _currentHR | `!= null` check (line 219) | PASS |
| MainView.onSensorInfo | sensorInfo | `!= null` check (line 255) | PASS |
| MainView.initialize | mi (property) | `== null` check (line 74) | PASS |
| MainView.initialize | cd (property) | `== null` check (line 83) | PASS |
| MainView.onHide | _updateTimer | `!= null` check (line 140) | PASS |
| SummaryView.onUpdate | all 7 labels | `!= null` checks (lines 45,51,57,63,69,75,85) | PASS |
| SummaryView.onUpdate | avgHr/maxHr | `> 0` checks with "--" fallback | PASS |

**Result: 33 null-safety points verified. 0 unguarded nullable accesses found.**

---

## Error Handling Audit

| Fallible Operation | File | Line | Guard | Status |
|-------------------|------|------|-------|--------|
| Sensor.registerSensorDataListener() | JumpDetector.mc | 167-183 | try/catch, sets _isActive=false | PASS |
| UserProfile.getProfile() | SessionManager.mc | 88-98 | try/catch, falls through to next source | PASS |
| App.getApp().getProperty("userWeightKg") | SessionManager.mc | 102-109 | try/catch, falls through to default | PASS |
| Record.createSession() | SessionManager.mc | 131-141 | try/catch, sets _session=null and returns | PASS |
| session.createField() (x3) | SessionManager.mc | 148-171 | try/catch, logs error (session continues without fields) | PASS |
| Attention.vibrate() (milestone) | MainView.mc | 238-242 | try/catch | PASS |
| Attention.vibrate() (countdown) | MainView.mc | 284-288 | try/catch | PASS |
| Attention.vibrate() (save feedback) | SummaryDelegate.mc | 61-64 | try/catch | PASS |

**Result: All 8 fallible API calls are wrapped in try/catch. 0 unprotected fallible calls.**

---

## Property Validation Audit

| Property | Reader | Validation | Range | Default Fallback | Status |
|----------|--------|-----------|-------|-----------------|--------|
| `jumpThreshold` | JumpDetector._clampInt() | null check, instanceof Number, clamp | 1200-3000 | Constants.JUMP_THRESHOLD (1800) | PASS |
| `landingThreshold` | JumpDetector._clampInt() | null check, instanceof Number, clamp | 200-800 | Constants.LANDING_THRESHOLD (500) | PASS |
| `debounceMs` | JumpDetector._clampInt() | null check, instanceof Number, clamp | 50-500 | Constants.DEBOUNCE_MS (150) | PASS |
| `sampleRate` | JumpDetector._clampInt() | null check, instanceof Number, clamp | 10-50 | Constants.SAMPLE_RATE (25) | PASS |
| `jumpThreshold > landingThreshold` | JumpDetector.initialize() | Cross-field invariant check | N/A | Both reset to defaults | PASS |
| `userWeightKg` | SessionManager._loadUserWeight() | null check, > 0, toFloat(), clamp | 20-300 kg | Constants.DEFAULT_USER_WEIGHT_KG (70.0) | PASS |
| `milestoneInterval` | MainView.initialize() | null check, instanceof Number, clamp | 0-1000 | Constants.MILESTONE_INTERVAL (100) | PASS |
| `countdownSeconds` | MainView.initialize() | null check, instanceof Number, clamp | 0-3600 | 0 (count-up mode) | PASS |

**Result: All 7 properties validated with type checks, range clamping, and default fallbacks. Cross-field invariant (jump > landing) enforced. 0 unvalidated properties.**

---

## Calorie/Metric Accuracy Verification

### MET-Based Calorie Formula

**Standard formula:** `calories_per_minute = METs * 3.5 * weight_kg / 200`

**Code implementation (SessionManager.mc:335-337):**
```
var elapsedMin = elapsedMs / 60000.0;
_calories = Constants.JUMP_ROPE_METS * Constants.CALORIES_CONSTANT
            * _userWeight * elapsedMin / Constants.CALORIES_DIVISOR;
```

**Expanding:** `_calories = 12.0 * 3.5 * weight * (elapsed_ms / 60000.0) / 200.0`

This is equivalent to `cal_per_min * elapsed_minutes` which correctly computes total calories burned. The float literals ensure floating-point arithmetic throughout (no integer truncation). PASS.

**MET value validation:** 12.0 METs for jump rope is sourced from the Compendium of Physical Activities (code 15552, "rope jumping, moderate pace"). This is the standard reference value used in fitness applications. PASS.

### Average JPM Calculation

**Code (SessionManager.mc:310-315):**
```
_avgJpm = (jumpCount * 60000) / elapsedMs;
```

This computes `jumps / elapsed_minutes` using integer arithmetic. For the expected range (10-400 JPM, 60-3600s sessions), integer precision is adequate. Division by zero guarded by `elapsedMs > 0` check. Clamped to [0, MAX_JPM]. PASS.

### Current JPM (Sliding Window)

**Code (JumpDetector.mc:260-288):**
- Counts timestamps in last 10 seconds (JPM_MOVING_WINDOW_MS)
- Scales: `jpm = (recentJumps * 60000) / 10000 = recentJumps * 6`
- Clamped to [0, MAX_JPM], filtered below MIN_JPM (10)

At 200 JPM, ~33 jumps in 10 seconds, JPM = 33 * 6 = 198. Correct approximation. PASS.

### Elapsed Time with Pause Support

**Code (SessionManager.mc:363-382):**
- `elapsed = now - _startTime - _totalPausedMs`
- If currently paused: `elapsed -= (now - _pauseTime)`
- Clamped to non-negative

This correctly accounts for accumulated pause time and ongoing pause. The M-1 issue above notes that `stopSession()` from paused state fails to accumulate the final pause duration. See Medium Issues section.

---

## Memory Safety Verification

| Check | Status | Notes |
|-------|--------|-------|
| Smoothing buffer: fixed size | PASS | `new [SMOOTHING_WINDOW_SIZE]` (5 elements), pre-allocated |
| Timestamp buffer: fixed size | PASS | `new [60]` (60 elements), pre-allocated |
| No hot-path allocations (onSensorData/processSample) | PASS | No `new`, no strings, no arrays created |
| Circular buffer bounds | PASS | Modular arithmetic (`% SMOOTHING_WINDOW_SIZE`, `% 60`) |
| Buffer initialization | PASS | Zero-filled in constructor and reset() |
| No unbounded growth | PASS | All arrays fixed-size, all counters bounded |
| FIT field UINT16 overflow | PASS | Clamped to 65535 in _updateFitFields() |
| String allocations in onUpdate | OK | 3-4 small strings per 1Hz frame, within GC budget |
| No circular references | PASS | SessionManager passed by reference to SummaryView/Delegate, no back-references |

---

## Code Quality Assessment

### Naming Consistency

- Classes: PascalCase (JumpRopeApp, JumpDetector, SessionManager, MainView, etc.) -- **Consistent**
- Methods: camelCase (startRecording, getJumpCount, onSensorData) -- **Consistent**
- Constants: UPPER_SNAKE_CASE (JUMP_THRESHOLD, STATE_RECORDING) -- **Consistent**
- Private members: `_` prefix (\_jumpCount, \_session, \_callback) -- **Consistent**
- Private methods: `_` prefix (\_processSample, \_clampInt) -- **Consistent** (but see I-3 re: `hidden` keyword)

### Dead Code

- `Constants.GRAVITY` (line 21) -- unused but serves as documentation
- `Constants.JPM_CALC_INTERVAL_MS` (line 57) -- design artifact, unused
- `Constants.COLOR_TEXT_PRIMARY` (line 116) -- replaced by direct `Graphics.COLOR_WHITE` in layouts
- `Constants.COLOR_BACKGROUND` (line 122) -- CIQ default background is black
- Strings: `Paused`, `Stopped`, `Save`, `Discard`, `Time` -- defined but unreferenced

None of these cause any functional issues. They add minimal overhead (~100 bytes total).

### Code Organization

- Clean separation of concerns: detection (JumpDetector), recording (SessionManager), display (MainView/SummaryView), input (MainDelegate/SummaryDelegate), configuration (Constants)
- No business logic in delegates (correct MVC pattern)
- No view logic in models
- Single-responsibility for each class

---

## Conclusion

The JumpRope Garmin Connect IQ app is a well-engineered, production-ready application. The codebase demonstrates careful attention to:

1. **CIQ 1.3 compatibility** -- No APIs from later CIQ versions are used. The avoidance of enums, Storage API, Properties.getValue(), and Menu2 is correct.

2. **Memory safety** -- All buffers are fixed-size and pre-allocated. No unbounded growth. No hot-path allocations in the sensor callback. Circular buffers use modular arithmetic correctly.

3. **Null safety** -- 33 null-safety points verified across all files. Every nullable value is checked before use.

4. **Error handling** -- All 8 fallible API calls are wrapped in try/catch with graceful fallbacks.

5. **Property validation** -- All 7 user-configurable properties are validated with type checks, range clamping, and cross-field invariant enforcement.

6. **Resource lifecycle** -- All timers, sensors, and listeners are properly started and stopped with no leak paths.

7. **State machine correctness** -- All 9 valid transitions verified. No invalid transitions possible through the input handlers.

**One medium issue found and fixed:**
- **M-1 (FIXED):** When stopping a session from the PAUSED state, the final pause duration was not accumulated into `_totalPausedMs`, causing the summary screen to display inflated elapsed time. Fixed by adding final pause accumulation in `stopSession()` before clearing the paused flag.

**Overall verdict:** PASS. The app is ready for simulator testing and device deployment.
