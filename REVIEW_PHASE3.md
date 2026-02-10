# Phase 3 Code Review Report

**Reviewer:** review-agent
**Date:** 2026-02-09
**Scope:** MainView.mc, MainDelegate.mc, SummaryView.mc, SummaryDelegate.mc, JumpRopeApp.mc
**Cross-referenced:** JumpDetector.mc, SessionManager.mc, Constants.mc, MainLayout.xml, SummaryLayout.xml, strings.xml

---

## Summary

Overall the Phase 3 implementation is solid. Two critical state-management bugs were found and fixed directly. The remaining findings are informational or minor.

**Stats:** 2 critical issues (FIXED), 0 high, 3 medium, 4 informational

---

## Critical Issues (FIXED)

### C-1: State reset ordering in SummaryDelegate (FIXED)

**File:** `SummaryDelegate.mc` lines 56-69, 73-79
**Problem:** Both `_saveAndExit()` and `_discardAndExit()` called `Ui.popView()` BEFORE setting `App.getApp().appState = Constants.STATE_IDLE`. When `popView()` executes, the framework immediately calls `MainView.onShow()`, which at that point would see `appState == STATE_SUMMARY` (stale). This means:
- The MainView status label would display "PRESS START" only after the next timer tick rather than immediately
- If any future logic branches on STATE_SUMMARY vs STATE_IDLE in onShow(), it would take the wrong path

**Fix applied:** Moved `App.getApp().appState = Constants.STATE_IDLE` to execute BEFORE `Ui.popView()` in both methods.

### C-2: MainView._appState never synced on re-show (FIXED)

**File:** `MainView.mc` line 83 (`onShow()`)
**Problem:** `MainView._appState` is a local copy of the app state. When the SummaryView is popped and MainView reappears, `onShow()` is called but `_appState` was still `STATE_SUMMARY` (set in `stopAndShowSummary()`). Even though `App.getApp().appState` gets reset to `STATE_IDLE` (after C-1 fix), the local `_appState` was never updated. This caused:
- `onUpdate()` would display "PRESS START" correctly (color would be COLOR_TEXT_SECONDARY) only because neither RECORDING nor PAUSED matched
- The local state inconsistency could cause subtle bugs if any method reads `_appState` instead of the global state
- `startRecording()` would still work because it unconditionally sets `_appState = STATE_RECORDING`

**Fix applied:** Added `_appState = App.getApp().appState;` as the first line of `onShow()` to sync local state from the global state.

---

## Medium Issues

### M-1: Duplicate state: local _appState vs global appState

**Files:** `MainView.mc`, `MainDelegate.mc`
**Observation:** The app maintains state in two places:
1. `App.getApp().appState` (global, used by MainDelegate)
2. `MainView._appState` (local, used by MainView.onUpdate)

MainDelegate reads from the global; MainView reads from the local. They are kept in sync by:
- MainView methods (`startRecording`, `pauseRecording`, etc.) set both
- `onShow()` now syncs local from global (C-2 fix)

This dual-state pattern is fragile. If any future code path sets one without the other, bugs result.

**Recommendation:** Consider using only `App.getApp().appState` everywhere, or making `_appState` a computed getter that reads the global. Not changed since the current code works correctly after the C-1/C-2 fixes and adding a getter adds a method call per frame.

### M-2: onUpdate() calls findDrawableById() 5 times per frame

**File:** `MainView.mc` lines 135-175
**Observation:** `findDrawableById()` performs a string-keyed lookup on every call. At 1 Hz refresh this is acceptable, but the CIQ framework can call `onUpdate()` more frequently (e.g., on `requestUpdate()` from jump callbacks). Each jump triggers `Ui.requestUpdate()` which calls `onUpdate()`, so at 200 JPM this is ~3.3 calls/second, each doing 5 lookups.

**Impact:** Low on FR235. The lookup is O(n) on the layout children count (9 elements), so 45 comparisons per frame. Acceptable but not ideal.

**Recommendation:** Cache drawable references in `onLayout()` as instance variables. Not changed since it works correctly and the FR235 handles this fine at the current call frequency.

### M-3: SummaryView.onUpdate() calls findDrawableById() 7 times per frame

**File:** `SummaryView.mc` lines 44-93
**Observation:** Same pattern as M-2 but with 7 lookups. However, SummaryView data is static (no timer tick, no jump callbacks), so `onUpdate()` is called only once when the view appears. This is a non-issue in practice.

---

## Informational

### I-1: JumpRopeApp.getInitialView() correctly passes view to delegate

**File:** `JumpRopeApp.mc` lines 58-61
**Status:** CORRECT. The view is created first, then passed to the delegate constructor. The return array `[view, new MainDelegate(view)]` matches the CIQ 1.3 API contract for `getInitialView()`.

### I-2: All findDrawableById IDs match layout XML

**Verified mappings:**

| MainView.mc reference | MainLayout.xml id | Match |
|---|---|---|
| `"StatusLabel"` | `id="StatusLabel"` | YES |
| `"JumpCount"` | `id="JumpCount"` | YES |
| `"TimerLabel"` | `id="TimerLabel"` | YES |
| `"JPMValue"` | `id="JPMValue"` | YES |
| `"HRValue"` | `id="HRValue"` | YES |

| SummaryView.mc reference | SummaryLayout.xml id | Match |
|---|---|---|
| `"TotalJumpsValue"` | `id="TotalJumpsValue"` | YES |
| `"DurationValue"` | `id="DurationValue"` | YES |
| `"AvgJPMValue"` | `id="AvgJPMValue"` | YES |
| `"PeakJPMValue"` | `id="PeakJPMValue"` | YES |
| `"CaloriesValue"` | `id="CaloriesValue"` | YES |
| `"AvgHRValue"` | `id="AvgHRValue"` | YES |
| `"MaxHRValue"` | `id="MaxHRValue"` | YES |

All 12 findDrawableById references match their layout XML counterparts exactly.

### I-3: All JumpDetector method calls match public API

| Called in MainView.mc | JumpDetector method | Signature match |
|---|---|---|
| `new JumpDetector(method(:onJumpDetected))` | `initialize(callback)` | YES |
| `_jumpDetector.isActive()` | `isActive()` returns Boolean | YES |
| `_jumpDetector.start()` | `start()` | YES |
| `_jumpDetector.stop()` | `stop()` | YES |
| `_jumpDetector.reset()` | `reset()` | YES |
| `_jumpDetector.getJumpCount()` | `getJumpCount()` returns Number | YES |
| `_jumpDetector.getJumpsPerMinute()` | `getJumpsPerMinute()` returns Number | YES |
| `_jumpDetector.getPeakJpm()` | `getPeakJpm()` returns Number | YES |

### I-4: All SessionManager method calls match public API

| Called in MainView/SummaryDelegate | SessionManager method | Signature match |
|---|---|---|
| `new SessionManager()` | `initialize()` | YES |
| `_sessionManager.startSession()` | `startSession()` | YES |
| `_sessionManager.pauseSession()` | `pauseSession()` | YES |
| `_sessionManager.resumeSession()` | `resumeSession()` | YES |
| `_sessionManager.stopSession()` | `stopSession()` | YES |
| `_sessionManager.saveSession()` | `saveSession()` returns Boolean | YES |
| `_sessionManager.discardSession()` | `discardSession()` | YES |
| `_sessionManager.getElapsedFormatted()` | `getElapsedFormatted()` returns String | YES |
| `_sessionManager.updateMetrics(c,j,p,h)` | `updateMetrics(jumpCount,currentJpm,peakJpm,heartRate)` | YES (4 args) |
| `_sessionManager.getTotalJumps()` | `getTotalJumps()` returns Number | YES |
| `_sessionManager.getAvgJpm()` | `getAvgJpm()` returns Number | YES |
| `_sessionManager.getPeakJpm()` | `getPeakJpm()` returns Number | YES |
| `_sessionManager.getCalories()` | `getCalories()` returns Number | YES |
| `_sessionManager.getAvgHr()` | `getAvgHr()` returns Number | YES |
| `_sessionManager.getMaxHr()` | `getMaxHr()` returns Number | YES |

### I-5: All Constants references verified

All constant references in Phase 3 files exist in `Constants.mc`:

- `Constants.STATE_IDLE` (0), `STATE_RECORDING` (1), `STATE_PAUSED` (2), `STATE_SUMMARY` (3)
- `Constants.COLOR_RECORDING`, `COLOR_PAUSED`, `COLOR_TEXT_SECONDARY`
- `Constants.TIMER_UPDATE_MS` (1000)

---

## CIQ 1.3 Compatibility Checklist

| Check | Result |
|---|---|
| No `has` keyword for API availability checks | PASS - not used |
| No `WatchUi.Menu2` (CIQ 2.0+) | PASS - not used |
| No `Storage.getValue()` (CIQ 2.1+) | PASS - uses `getProperty()` |
| `Sensor.setEnabledSensors()` used (CIQ 1.0+) | PASS |
| `Sensor.enableSensorEvents()` used (CIQ 1.0+) | PASS |
| `Sensor.registerSensorDataListener()` used (CIQ 1.3+) | PASS |
| `ActivityRecording.createSession()` used (CIQ 1.0+) | PASS |
| `FitContributor` used (CIQ 1.3+) | PASS |
| `Ui.BehaviorDelegate` used (CIQ 1.0+) | PASS |
| `Ui.pushView(view, delegate, transition)` (CIQ 1.0+) | PASS |
| `Ui.popView(transition)` (CIQ 1.0+) | PASS |
| `minApiLevel="1.3.0"` in manifest.xml | PASS |
| No `Attention.vibrate()` availability check | NOTE - wrapped in try/catch (acceptable) |

---

## State Machine Verification

### Valid transitions:

```
IDLE --[START]--> RECORDING
RECORDING --[START]--> PAUSED
PAUSED --[START]--> RECORDING
RECORDING --[BACK]--> SUMMARY (via stopAndShowSummary)
PAUSED --[BACK]--> SUMMARY (via stopAndShowSummary)
SUMMARY --[START/BACK]--> IDLE (via save/discard + popView)
```

### Verified in code:

- **MainDelegate.onKey()**: KEY_ENTER cycles IDLE->RECORDING->PAUSED->RECORDING. KEY_ESC from RECORDING or PAUSED goes to SUMMARY. IDLE KEY_ESC returns false (system exits app). All correct.
- **MainDelegate.onBack()**: Same logic as KEY_ESC. Correct.
- **SummaryDelegate**: KEY_ENTER saves, KEY_ESC/onBack discards. Both reset to IDLE. Correct.
- **No invalid transitions possible**: STATE_SUMMARY is only set in `stopAndShowSummary()` which pushes a new view. The summary view's delegate handles all input. No path from SUMMARY back to RECORDING without going through IDLE first. Correct.

---

## Timer/Sensor Lifecycle

| Resource | Started in | Stopped in | Leak risk |
|---|---|---|---|
| `_updateTimer` (Timer.Timer) | `onShow()` | `onHide()` (null-checked, set to null) | NONE |
| Heart rate sensor events | `onShow()` via `enableSensorEvents(method)` | `onHide()` via `enableSensorEvents(null)` | NONE |
| Sensor.setEnabledSensors | `onShow()` | Not explicitly disabled in onHide | LOW - framework handles on app exit |
| JumpDetector sensor listener | `start()` | `stop()` via `unregisterSensorDataListener()` | NONE - stopped in onHide if active |

---

## Null Safety

| Location | Check | Result |
|---|---|---|
| MainView.onUpdate - all findDrawableById | `!= null` guard | PASS |
| MainView.onSensorInfo | `sensorInfo != null && heartRate != null` | PASS |
| MainView.onUpdate - HR display | `_currentHR != null` check | PASS |
| SummaryView.onUpdate - all findDrawableById | `!= null` guard | PASS |
| SummaryView.onUpdate - avgHr/maxHr | `> 0` check with "--" fallback | PASS |
| MainView.onTimerTick | No null check on _jumpDetector | PASS - initialized in constructor, never null |
| MainView.onHide | `_updateTimer != null` check | PASS |
| SummaryDelegate._saveAndExit | Attention.vibrate in try/catch | PASS |

---

## Hot-Path Allocation Analysis (onUpdate)

### MainView.onUpdate():
- `findDrawableById("StatusLabel")` -- string literal, no alloc (interned)
- `.setText("RECORDING")` / `.setText("PAUSED")` / `.setText("PRESS START")` -- string literals, no alloc
- `.setColor(Constants.COLOR_RECORDING)` -- constant integer, no alloc
- `_jumpDetector.getJumpCount().toString()` -- **allocates a String** each frame
- `_sessionManager.getElapsedFormatted()` -- **allocates a String** (via `Lang.format`) each frame
- `_jumpDetector.getJumpsPerMinute().toString()` -- **allocates a String** each frame
- `_currentHR.toString()` -- **allocates a String** each frame (when HR available)

**Verdict:** 3-4 small String allocations per frame at 1 Hz. This is standard practice in CIQ apps and within GC budget for the FR235. The CIQ runtime's garbage collector handles short-lived strings efficiently. No action needed.

### SummaryView.onUpdate():
- Called once when view appears. 7 toString() allocations. No concern.

---

## Files Changed

1. **SummaryDelegate.mc** -- Moved `appState = STATE_IDLE` before `popView()` in both `_saveAndExit()` and `_discardAndExit()` (C-1)
2. **MainView.mc** -- Added `_appState = App.getApp().appState` sync at top of `onShow()` (C-2)

---

## Conclusion

The Phase 3 implementation is well-structured with clean separation of concerns between views and delegates. The two critical bugs (state reset ordering and stale local state) have been fixed. All API calls, layout IDs, constant references, and state transitions are correct. The code is fully compatible with CIQ 1.3. Timer and sensor lifecycles are properly managed with no leak risk.
