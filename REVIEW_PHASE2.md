# Phase 2 Code Review: JumpDetector.mc and SessionManager.mc

**Reviewer**: review-agent
**Date**: 2026-02-09
**Files Reviewed**:
- `/home/kali/JumpRope/source/JumpDetector.mc`
- `/home/kali/JumpRope/source/SessionManager.mc`

**Cross-Referenced Against**:
- `/home/kali/JumpRope/source/Constants.mc`
- `/home/kali/JumpRope/properties/properties.xml`
- `/home/kali/JumpRope/manifest.xml`
- `/home/kali/JumpRope/source/JumpRopeApp.mc`

---

## Summary

Both files are well-structured, correctly use CIQ 1.3 APIs, and implement their algorithms soundly. One critical null-safety issue was found and fixed directly. The remaining findings are warnings and suggestions for robustness.

**Verdict**: PASS (with 1 critical fix applied)

---

## Critical Issues (Fixed)

### C-1: Missing null check on `_callback.invoke()` (JumpDetector.mc:391)

**Severity**: Critical
**Status**: FIXED

`_callback.invoke(_jumpCount)` was called without a null guard. While the constructor requires a callback parameter, Monkey C does not enforce non-null arguments. If `null` were passed (or if the callback reference became invalid), this would crash the app during jump detection -- the hottest code path.

**Fix applied**: Added `if (_callback != null)` guard before `.invoke()` at line 391.

---

## Warnings

### W-1: FIT UINT16 overflow for extreme sessions (SessionManager.mc:152)

`_totalJumps` is stored as `Fit.DATA_TYPE_UINT16` (max 65535). At 400 JPM (the configured MAX_JPM), this overflows after ~163 minutes. Unlikely for jump rope, but worth noting. The in-memory `_jumpCount` (Number) is unaffected.

**Recommendation**: Acceptable for v1.0. If longer sessions are supported later, switch to `DATA_TYPE_UINT32`.

### W-2: Sys.getTimer() wrap-around (JumpDetector.mc:374, SessionManager.mc:363)

`Sys.getTimer()` returns milliseconds since boot as a signed 32-bit integer, wrapping at ~24.8 days. Timestamp comparisons in `getJumpsPerMinute()` and `getElapsedMs()` would produce incorrect results if the timer wraps mid-session. Practically impossible for a jump rope workout.

**Recommendation**: No action needed for v1.0.

### W-3: Integer division in avgJpm (SessionManager.mc:312)

`_avgJpm = (jumpCount * 60000) / elapsedMs` uses integer division. For low jump counts early in a session (e.g., 1 jump at 2 minutes elapsed), the result rounds to 0. This is mathematically correct truncation behavior and resolves itself as jump counts increase.

**Recommendation**: Acceptable. If fractional precision is desired, use `toFloat()` conversion.

### W-4: JPM timestamp buffer iterates all entries (JumpDetector.mc:261)

`getJumpsPerMinute()` iterates all `_timestampCount` entries (up to 60) to count timestamps in the window. At the ~1 Hz call rate from `updateMetrics`, this is 60 iterations max -- negligible. However, old timestamps outside the window are never evicted, meaning all 60 entries are always checked even when most are stale.

**Recommendation**: Acceptable for the 60-entry buffer size. No optimization needed.

---

## Suggestions

### S-1: Consider `hidden` for private methods (JumpDetector.mc)

Methods `_processSample`, `_recordJumpTimestamp`, and `_clampInt` are intended as private (prefixed with `_`) but are not declared `hidden`. In Monkey C, `hidden` prevents subclass access and is the closest analog to private visibility. SessionManager.mc correctly uses `hidden` for `_loadUserWeight` and `_updateFitFields`.

### S-2: Magic number 60 for timestamp buffer (JumpDetector.mc:123,314,406,407)

The timestamp buffer size `60` appears as a literal in 4 places. Constants.mc does not define a constant for this. A named constant like `JPM_BUFFER_SIZE` would improve maintainability.

### S-3: `getElapsedFormatted()` does not handle hours (SessionManager.mc:381-387)

The format is `MM:SS`. Sessions exceeding 60 minutes would show e.g. `75:30` rather than `1:15:30`. For a jump rope app this is acceptable, but worth noting if the format looks odd in Garmin Connect.

---

## CIQ 1.3 Compatibility Verification

| API Usage | File | Line(s) | CIQ Version | Status |
|---|---|---|---|---|
| `App.getApp().getProperty()` | JumpDetector.mc | 136-150 | 1.0+ | PASS |
| `App.getApp().getProperty()` | SessionManager.mc | 103 | 1.0+ | PASS |
| `Sensor.registerSensorDataListener()` | JumpDetector.mc | 167 | 1.3+ | PASS |
| `Sensor.unregisterSensorDataListener()` | JumpDetector.mc | 187 | 1.3+ | PASS |
| `sensorData.accelerometerData.z` | JumpDetector.mc | 211-218 | 1.3+ | PASS |
| `Record.createSession()` | SessionManager.mc | 132 | 1.0+ | PASS |
| `session.createField()` | SessionManager.mc | 149-167 | 1.0+ | PASS |
| `Fit.DATA_TYPE_UINT16` | SessionManager.mc | 152,159,166 | 1.0+ | PASS |
| `Fit.MESG_TYPE_SESSION` | SessionManager.mc | 153,160,167 | 1.0+ | PASS |
| `Record.SPORT_TRAINING` | SessionManager.mc | 134 | 1.0+ | PASS |
| `Record.SUB_SPORT_CARDIO_TRAINING` | SessionManager.mc | 135 | 1.0+ | PASS |
| `Profile.getProfile()` | SessionManager.mc | 89 | 1.0+ | PASS |
| `Sys.getTimer()` | JumpDetector.mc, SessionManager.mc | multiple | 1.0+ | PASS |
| `Lang.format()` | SessionManager.mc | 386 | 1.0+ | PASS |
| `instanceof Lang.Array` | JumpDetector.mc | 225 | 1.0+ | PASS |
| `instanceof Lang.Number` | JumpDetector.mc | 425 | 1.0+ | PASS |

**No CIQ 2.0+ APIs detected.** All API usage is compatible with CIQ 1.3 (minApiLevel 1.3.0 in manifest.xml).

Specifically verified ABSENT:
- `Application.Properties.getValue()` (CIQ 2.4+) -- correctly uses `App.getApp().getProperty()` instead
- `Application.Storage` (CIQ 2.2+) -- not used
- `Communications.makeWebRequest()` -- not used (no permission needed)
- `Timer.Timer` -- not used (sensor listener is used instead)

---

## Cross-Reference Verification

### Constants.mc References

| Constant | Defined In | Used In | Match |
|---|---|---|---|
| `JUMP_STATE_GROUND` (0) | Constants.mc:166 | JumpDetector.mc:109,303,376,387 | PASS |
| `JUMP_STATE_AIR` (1) | Constants.mc:171 | JumpDetector.mc:380,382 | PASS |
| `SMOOTHING_WINDOW_SIZE` (5) | Constants.mc:40 | JumpDetector.mc:115-117,307,352,359 | PASS |
| `JUMP_THRESHOLD` (1800) | Constants.mc:26 | JumpDetector.mc:137,156 | PASS |
| `LANDING_THRESHOLD` (500) | Constants.mc:31 | JumpDetector.mc:140,157 | PASS |
| `DEBOUNCE_MS` (150) | Constants.mc:35 | JumpDetector.mc:143 | PASS |
| `SAMPLE_RATE` (25) | Constants.mc:44 | JumpDetector.mc:148 | PASS |
| `JPM_MOVING_WINDOW_MS` (10000) | Constants.mc:62 | JumpDetector.mc:257,268 | PASS |
| `MAX_JPM` (400) | Constants.mc:134 | JumpDetector.mc:271, SessionManager.mc:320 | PASS |
| `MIN_JPM` (10) | Constants.mc:138 | JumpDetector.mc:275 | PASS |
| `SESSION_NAME` ("Jump Rope") | Constants.mc:130 | SessionManager.mc:133 | PASS |
| `FIELD_TOTAL_JUMPS` (0) | Constants.mc:92 | SessionManager.mc:151 | PASS |
| `FIELD_AVG_JPM` (1) | Constants.mc:95 | SessionManager.mc:158 | PASS |
| `FIELD_PEAK_JPM` (2) | Constants.mc:98 | SessionManager.mc:165 | PASS |
| `JUMP_ROPE_METS` (12.0) | Constants.mc:72 | SessionManager.mc:336 | PASS |
| `DEFAULT_USER_WEIGHT_KG` (70.0) | Constants.mc:76 | SessionManager.mc:114 | PASS |
| `CALORIES_CONSTANT` (3.5) | Constants.mc:80 | SessionManager.mc:336 | PASS |
| `CALORIES_DIVISOR` (200.0) | Constants.mc:83 | SessionManager.mc:337 | PASS |

All 18 constant references resolve correctly.

### properties.xml Consistency

| Property ID | properties.xml | Code Reference | Default Match |
|---|---|---|---|
| `jumpThreshold` | type=number, default=1800 | JumpDetector.mc:136, clamped 1200-3000 | PASS |
| `landingThreshold` | type=number, default=500 | JumpDetector.mc:139, clamped 200-800 | PASS |
| `debounceMs` | type=number, default=150 | JumpDetector.mc:142, clamped 50-500 | PASS |
| `sampleRate` | type=number, default=25 | JumpDetector.mc:147, clamped 10-50 | PASS |
| `userWeightKg` | type=number, default=70 | SessionManager.mc:103 | PASS |

All 5 property names and defaults match between properties.xml, Constants.mc, and code references.

### manifest.xml Permissions

| Permission | Required By | Declared | Status |
|---|---|---|---|
| `Sensor` | JumpDetector.mc (accelerometer listener) | manifest.xml:23 | PASS |
| `FitContributor` | SessionManager.mc (custom FIT fields) | manifest.xml:24 | PASS |

No missing permissions detected.

---

## Algorithm Correctness

### Two-Threshold State Machine (JumpDetector.mc)

The state machine correctly implements:
- **GROUND -> AIR**: smoothedZ > jumpThreshold AND debounce elapsed (line 379)
- **AIR -> GROUND**: smoothedZ < landingThreshold (line 386), then increment counter + fire callback

The debounce check is correctly applied only on the GROUND->AIR transition (takeoff), not on landing. This prevents double-counting rapid bounces but allows the landing to register freely once airborne. This is the correct design for jump detection.

### Circular Buffer (JumpDetector.mc)

The smoothing buffer uses modular arithmetic correctly:
- Write at `_bufferIndex`, then increment with modulo (line 352)
- `_bufferFilled` set when index wraps to 0 (line 353-355)
- Count calculation correct: full buffer uses `SMOOTHING_WINDOW_SIZE`, partial uses `_bufferIndex` (line 358-360)
- Division-by-zero guard at line 364-366 is a safety net for the impossible case

### JPM Calculation (JumpDetector.mc)

- Counts timestamps within `JPM_MOVING_WINDOW_MS` (10s) window (line 261-264)
- Scales to per-minute: `(recentJumps * 60000) / 10000` = `recentJumps * 6` (line 268)
- Clamped to [0, MAX_JPM] (lines 271-276)
- Integer arithmetic avoids floating point on the hot path

### Calorie Calculation (SessionManager.mc)

Formula: `cal = METs * 3.5 * weight * elapsed_min / 200`
Code: `JUMP_ROPE_METS * CALORIES_CONSTANT * _userWeight * elapsedMin / CALORIES_DIVISOR`
= `12.0 * 3.5 * weight * min / 200.0`

This correctly implements the standard MET-to-calorie conversion. The use of float constants (`12.0`, `3.5`, `200.0`) ensures floating-point arithmetic, avoiding integer truncation.

### Elapsed Time with Pause (SessionManager.mc)

`getElapsedMs()` correctly:
- Subtracts total accumulated pause time (line 364)
- If currently paused, also subtracts the ongoing pause duration (line 368-369)
- Clamps to non-negative (line 373-374)

---

## Memory Safety

| Check | Status | Notes |
|---|---|---|
| Fixed-size smoothing buffer | PASS | Pre-allocated `new [SMOOTHING_WINDOW_SIZE]` in constructor |
| Fixed-size timestamp buffer | PASS | Pre-allocated `new [60]` in constructor |
| No hot-path allocations | PASS | `_processSample` uses no `new`, no string ops, no array creation |
| Circular buffer bounds | PASS | Modular arithmetic ensures indices stay in range |
| No string operations in sensor callback | PASS | `onSensorData` and `_processSample` are string-free |
| Array initialization loops | PASS | Both buffers zero-initialized in constructor and `reset()` |

---

## Edge Cases

| Scenario | Handling | Status |
|---|---|---|
| 0 jumps | `getJumpsPerMinute()` returns 0, `getCalories()` returns 0, `getAvgJpm()` returns 0 | PASS |
| Division by zero in JPM | Window count is 0 -> `0 * 60000 / 10000 = 0` | PASS |
| Division by zero in avg JPM | `getElapsedMs() > 0` guard at line 311 | PASS |
| Division by zero in avg HR | `_hrCount > 0` guard at line 411 | PASS |
| Empty smoothing buffer | `count = 0` guard at line 364 | PASS |
| Null sensor data | Null checks at lines 208-221 | PASS |
| Null accelerometer data | Null check at lines 212-214 | PASS |
| Null z data | Null check at lines 219-221 | PASS |
| Null individual z sample | Null check at line 227 | PASS |
| Null callback | **FIXED** -- null guard added at line 391 | PASS |
| Null user profile | Try/catch at line 88 + null checks | PASS |
| Null property values | `_clampInt` returns default for null (line 425) | PASS |
| Invalid property types | `instanceof Lang.Number` check in `_clampInt` (line 425) | PASS |
| jumpThreshold <= landingThreshold | Reset both to defaults (lines 155-158) | PASS |
| Session already paused | `pauseSession()` no-op guard (line 196) | PASS |
| Resume when not paused | `resumeSession()` no-op guard (line 212) | PASS |
| Stop with no session | `stopSession()` null guard (line 230) | PASS |
| Save with no session | `saveSession()` returns false (line 248-249) | PASS |
| Discard with no session | `discardSession()` null guard (line 268) | PASS |

---

## Performance (onSensorData hot path)

`onSensorData` is called at 25 Hz. The critical path through `_processSample` performs:
1. One array write (line 351)
2. One modulo operation (line 352)
3. One comparison (line 353)
4. One loop of 5 iterations for sum (lines 368-370)
5. One division (line 371)
6. One `Sys.getTimer()` call (line 374)
7. One or two comparisons for state machine (lines 376-393)

**No allocations, no string operations, no method calls to external objects** (except `_callback.invoke` on jump detection, which is infrequent). This is well-optimized for a 25 Hz callback.

---

## Changes Made

1. **JumpDetector.mc:391** -- Added `if (_callback != null)` null guard before `_callback.invoke(_jumpCount)` to prevent potential crash if callback is null.

---

## Overall Assessment

The Phase 2 implementation is solid. The code demonstrates careful attention to:
- CIQ 1.3 API compatibility (no 2.0+ APIs used)
- Memory efficiency (fixed-size pre-allocated buffers, no hot-path allocations)
- Null safety (comprehensive null checks throughout)
- Edge case handling (division-by-zero guards, sanity clamping)
- Algorithm correctness (proper two-threshold state machine, correct MET formula)
- Consistent cross-referencing with Constants.mc and properties.xml

The single critical fix (null callback guard) has been applied. All other findings are minor warnings or style suggestions that do not affect correctness.
