# Security Review -- Phase 3 (View & Delegate Layer)

**Reviewer:** security-agent
**Date:** 2026-02-09
**Scope:** MainView.mc, MainDelegate.mc, SummaryView.mc, SummaryDelegate.mc, JumpRopeApp.mc
**Supporting files reviewed:** Constants.mc, JumpDetector.mc, SessionManager.mc

---

## Summary

The Phase 3 view and delegate layer is **well-structured and secure**. All eight security criteria were evaluated. One state-synchronization issue was identified and already fixed. No critical or high-severity issues remain. The codebase follows defensive coding practices throughout.

**Overall Posture: PASS**

---

## Criteria Evaluation

### 1. Resource Management (Timer / Sensor Leaks)

**Status: PASS**

- `MainView.onHide()` (line 109) stops the update timer, nulls the reference, stops the jump detector if active, and disables HR sensor events. All three resource types (Timer, accelerometer listener, HR sensor) are properly released.
- `MainView.onShow()` (line 83) re-creates the timer and re-enables sensors on each show, so hide/show cycles do not accumulate leaked resources.
- `SummaryView` has no timers or sensor registrations -- no cleanup needed.
- `JumpDetector.start()` wraps `registerSensorDataListener` in try/catch and sets `_isActive = false` on failure, preventing phantom listeners.

No resource leaks found.

### 2. State Integrity (Button Mashing)

**Status: PASS**

- `MainDelegate.onKey()` reads the canonical state from `App.getApp().appState` before acting. State transitions in `MainView` (startRecording, pauseRecording, resumeRecording, stopAndShowSummary) update both `_appState` and `App.getApp().appState` atomically (single-threaded execution guarantees this).
- Double-press of BACK during recording: first press transitions to STATE_SUMMARY, second press hits the state guard (state is no longer RECORDING/PAUSED) and falls through. Safe.
- Double-press of START/BACK on SummaryDelegate: `saveSession()` and `discardSession()` check `_session != null` and set it to null after operating, so the second call is a no-op. Safe.
- `SessionManager.pauseSession()` guards with `!_isRecording || _isPaused` check. `resumeSession()` guards with `!_isPaused`. Rapid pause/resume toggling cannot corrupt state.

No state integrity issues found.

### 3. Data Privacy (Health Data Logging)

**Status: PASS**

All `Sys.println()` calls across the five reviewed files log only:
- State transition labels (e.g., "IDLE -> RECORDING")
- Lifecycle events (e.g., "Session started", "Session saved")
- Configuration values (e.g., sample rate)

**No health data values are logged.** Heart rate, calorie counts, jump counts, and other biometric data are never passed to `Sys.println()`. This is important because debug logs on Garmin devices can be accessed via USB.

Files checked:
- `MainDelegate.mc`: Lines 50, 54, 58, 68, 89 -- state labels only
- `JumpDetector.mc`: Lines 179, 182, 194 -- start/stop/failure labels only
- `SessionManager.mc`: Lines 138, 190, 261, 290 -- lifecycle labels only
- `JumpRopeApp.mc`: Lines 38, 49 -- start/stop labels only

### 4. Null Safety

**Status: PASS**

- All `findDrawableById()` calls in `MainView.onUpdate()` (lines 135-175) and `SummaryView.onUpdate()` (lines 44-93) are wrapped in `!= null` guards.
- `MainView.onSensorInfo()` (line 198) null-checks both `sensorInfo` and `sensorInfo.heartRate`.
- `JumpDetector.onSensorData()` (lines 208-226) null-checks `sensorData`, `accelerometerData`, and `zData` with early returns.
- `JumpDetector._processSample()` (line 396) null-checks `_callback` before invoking.
- `SessionManager` methods (`pauseSession`, `resumeSession`, `stopSession`, `saveSession`, `discardSession`) all guard on `_session != null`.
- `SummaryView._sessionManager` is not explicitly null-checked, but it is only constructed via `MainView.stopAndShowSummary()` which always passes a non-null instance. Acceptable risk.

### 5. Exception Handling (Attention API and Optional APIs)

**Status: PASS**

- `SummaryDelegate._saveAndExit()` (line 61) wraps `Attention.vibrate()` in try/catch. The Attention API is not available on all devices; the catch block silently degrades. Correct behavior.
- `JumpDetector.start()` (line 167) wraps `Sensor.registerSensorDataListener()` in try/catch and logs failure.
- `SessionManager.startSession()` (line 131) wraps `Record.createSession()` in try/catch and returns early on failure.
- `SessionManager._loadUserWeight()` (lines 88, 103) wraps both `Profile.getProfile()` and `getProperty()` in try/catch with fallback to default weight.
- FIT field creation (line 148) is wrapped in try/catch -- fields may be null but `_updateFitFields()` null-checks each field before use.

### 6. View Stack Safety (Push/Pop Balance)

**Status: PASS**

- `MainView.stopAndShowSummary()` pushes `SummaryView` onto the stack (line 282).
- `SummaryDelegate._saveAndExit()` and `_discardAndExit()` each call `Ui.popView()` exactly once (lines 67, 77).
- The push/pop pair is balanced: one push in MainView, one pop in SummaryDelegate.
- After pop, MainView's `onShow()` fires and syncs `_appState` from `App.getApp().appState` (line 86), ensuring correct state display.
- No scenario exists where the view stack can grow unbounded or pop below the initial view.

### 7. Race Conditions (Timer Callback During View Transition)

**Status: PASS**

- Monkey C is single-threaded; timer callbacks, sensor callbacks, and UI events are dispatched sequentially on the main thread. True concurrency races are not possible.
- `onTimerTick()` accesses `_jumpDetector` and `_sessionManager`, which are initialized in the constructor and never set to null. Safe even if called between `onHide()` and garbage collection.
- `JumpDetector.onSensorData()` checks `_isActive` as a first guard (line 208), so callbacks that arrive after `stop()` are ignored.
- `onHide()` stops the timer before hiding, so no timer ticks fire while the view is hidden.

### 8. Input Validation (Key Event Default Fallback)

**Status: PASS**

- `MainDelegate.onKey()` handles `KEY_ENTER` and `KEY_ESC` with explicit `if` blocks. All other keys fall through to `return false` at line 77. Correct default fallback.
- `SummaryDelegate.onKey()` handles `KEY_ENTER` and `KEY_ESC`, returns `false` for all other keys at line 44. Correct default fallback.
- State guards within each key handler ensure that actions are only performed in valid states. Invalid state + valid key combinations fall through to `return false`.

---

## Issues Found and Resolved

### S-1: State Desync After SummaryView Pop (MEDIUM -- FIXED)

**File:** `MainView.mc`, `onShow()` method
**Description:** When SummaryDelegate pops the SummaryView and sets `App.getApp().appState = STATE_IDLE`, the MainView's local `_appState` field remained at `STATE_SUMMARY`. This caused a cosmetic desync where `_appState` would not reflect the true idle state until the next button press triggered a state transition method.

**Impact:** Low functional impact (MainDelegate reads from `App.getApp().appState`, not `_appState`), but `onUpdate()` renders based on `_appState`, and `onShow()` uses `_appState` for the recording-restart check. In the specific SUMMARY->IDLE case the else branch in onUpdate displays "PRESS START" (correct behavior by coincidence), and the RECORDING restart check correctly does not fire. However, the desync is a latent bug that could cause issues if future code reads `_appState` for other decisions.

**Fix applied:** Added `_appState = App.getApp().appState;` at the top of `onShow()` (line 86) to sync local state from the canonical global state on every show. Already present in the reviewed code.

---

## Additional Observations (Informational)

1. **Debug logging in production:** The `Sys.println()` calls across MainDelegate, JumpDetector, SessionManager, and JumpRopeApp are useful for development but should be removed or gated behind a debug flag before production release. They carry no privacy risk (no health data logged) but consume minor CPU cycles.

2. **SessionManager shared reference:** Both SummaryView and SummaryDelegate receive the same SessionManager instance. Since Monkey C is single-threaded, there is no concurrent access risk. The shared reference pattern is appropriate here.

3. **Calorie calculation runs even when paused:** `onTimerTick()` only calls `updateMetrics()` when `_appState == STATE_RECORDING`, so calories are not accumulated during paused periods. Correct.

---

## Sign-Off

All eight security criteria have been evaluated. One medium-severity state synchronization issue was identified and is resolved. No critical, high, or unresolved issues remain.

**Security Posture: PASS**
**Recommendation: Approved for merge.**

Signed: security-agent, 2026-02-09
