# Security Review -- Phase 2 Files

**Project**: JumpRope (Garmin Connect IQ App)
**Target Device**: Forerunner 235 (Connect IQ 1.3)
**Review Date**: 2026-02-09
**Reviewer**: security-agent
**Overall Security Posture**: **PASS**

---

## Files Reviewed

| # | File | Lines |
|---|------|-------|
| 1 | `source/JumpDetector.mc` | 439 |
| 2 | `source/SessionManager.mc` | 437 |

**Reference files consulted**: `source/Constants.mc`, `properties/properties.xml`, `SECURITY_REVIEW_PHASE1.md`

---

## Phase 1 Finding Resolution

### M-1: Unbounded User-Configurable Properties -- RESOLVED

**Original finding**: Properties (`jumpThreshold`, `landingThreshold`, `debounceMs`, `sampleRate`, `userWeightKg`) had no runtime bounds enforcement. Risk of division-by-zero, runaway loops, and inverted thresholds.

**Resolution verified in Phase 2 code**:

| Property | File | Clamping | Range |
|----------|------|----------|-------|
| `jumpThreshold` | `JumpDetector.mc:135-138` | `_clampInt()` | 1200--3000 milliG |
| `landingThreshold` | `JumpDetector.mc:139-142` | `_clampInt()` | 200--800 milliG |
| `debounceMs` | `JumpDetector.mc:143-146` | `_clampInt()` | 50--500 ms |
| `sampleRate` | `JumpDetector.mc:147-150` | `_clampInt()` | 10--50 Hz |
| `userWeightKg` | `SessionManager.mc:117-122` | Explicit clamp | 20.0--300.0 kg |

**Additional safeguards implemented**:
- `_clampInt()` (line 426) rejects `null` and non-Number types, returning compiled defaults.
- Invariant check (line 155): `jumpThreshold > landingThreshold` enforced; both reset to defaults on violation.
- Weight loading (line 84): Three-tier fallback (profile -> property -> default) with try/catch at each level.

**Verdict**: M-1 is **fully resolved**. All five properties are validated, clamped, and safe from adversarial or accidental misconfiguration.

---

## Findings Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 0 | -- |
| High | 0 | -- |
| Medium | 2 | Both fixed in this review |
| Low | 2 | Acceptable risk |
| Info | 4 | Informational |

---

## Detailed Findings

### MEDIUM Findings

#### M-1: Missing Exception Handling on Sensor Registration

**File**: `JumpDetector.mc`, line 166 (original)
**Description**: `Sensor.registerSensorDataListener()` was called without a try/catch. If the sensor subsystem is unavailable or throws an exception (e.g., hardware fault, permissions revoked), the app would crash with an unhandled exception.

**Impact**: App crash on sensor failure, requiring force-close. No data loss (session not yet started), but poor user experience.

**Fix applied**: Wrapped `registerSensorDataListener()` in try/catch. On failure, `_isActive` is set to `false` and a diagnostic message is logged (no sensitive data).

**Status**: FIXED.

---

#### M-2: FIT Field UINT16 Overflow for Total Jumps

**File**: `SessionManager.mc`, line 344 (original `_updateFitFields`)
**Description**: The `total_jumps` FIT field uses `DATA_TYPE_UINT16` (max 65,535). The `_totalJumps` counter is an unbounded integer that could exceed 65,535 in long sessions. At 200 JPM, overflow occurs after ~5.5 hours. When the FIT SDK receives a value > 65,535 for a UINT16 field, behavior is undefined -- it may silently truncate, wrap around, or corrupt the FIT file.

**Impact**: Corrupted jump count in Garmin Connect for marathon jump rope sessions. Incorrect fitness data displayed to user.

**Fix applied**: Added explicit clamp to 65,535 in `_updateFitFields()` before calling `setData()`. The internal `_totalJumps` counter remains unbounded (for correct display on-device), but the FIT field value is safely capped.

**Status**: FIXED.

---

### LOW Findings

#### L-1: Debug Logging Statements Present

**Files**: `JumpDetector.mc` (lines 178, 189), `SessionManager.mc` (lines 138, 170, 190, 261, 290)
**Description**: Seven `Sys.println()` calls log lifecycle events ("started", "stopped", "saved", etc.) to the simulator console.

**Risk assessment**: MINIMAL.
- No health data is logged (no HR, calories, jump counts, or weight values appear in any log message).
- On physical hardware, `Sys.println()` output is not accessible to other apps or transmitted off-device.
- Messages contain only static strings and the sample rate integer (not PII).

**Recommendation**: Consider removing or gating behind a debug flag before store submission for marginal performance improvement.

**Status**: Acceptable. No action required.

---

#### L-2: Heart Rate Sum Could Theoretically Overflow in Extreme Sessions

**File**: `SessionManager.mc`, lines 326-327
**Description**: `_hrSum` accumulates HR values without bounds. At maximum HR (220 bpm) logged every second for 24 hours, the sum reaches ~19 million -- well within 32-bit signed integer range (~2.1 billion). Overflow would require ~2,710+ hours of continuous recording.

**Risk assessment**: NEGLIGIBLE. No realistic workout session approaches this duration. The Garmin device battery would be depleted long before overflow.

**Status**: Acceptable. No action required.

---

### INFORMATIONAL Findings

#### I-1: Input Validation Is Comprehensive

**Assessment**: Both files demonstrate defense-in-depth input validation:
- **Sensor data**: Four-level null-check cascade in `onSensorData()` -- `sensorData`, `accelerometerData`, `z`, and individual array elements (lines 208-229).
- **Properties**: Type-safe clamping via `_clampInt()` with null/non-Number rejection.
- **User profile**: Three-tier fallback with try/catch at each level.
- **Heart rate**: Null and positivity check before accumulation (line 325).
- **Callback**: Null-check before invocation (line 391).

**Result**: PASS.

---

#### I-2: Division-by-Zero Is Fully Guarded

**Assessment**: All division operations are protected:
- Rolling average: `count == 0` guard at line 364 (JumpDetector.mc).
- JPM calculation: Divides by constant `JPM_MOVING_WINDOW_MS` (10000) -- never zero.
- Average JPM: `elapsedMs > 0` guard at line 311 (SessionManager.mc).
- Average HR: `_hrCount > 0` guard at line 411 (SessionManager.mc).
- Calories: Divides by constant `CALORIES_DIVISOR` (200.0) -- never zero.

**Result**: PASS.

---

#### I-3: Buffer Management Is Sound

**Assessment**: All circular buffers use modular arithmetic with fixed-size arrays:
- Smoothing buffer: Index `% SMOOTHING_WINDOW_SIZE` (5). Pre-allocated, zero-filled.
- Timestamp buffer: Index `% 60`. Count capped at 60 with explicit check.
- No dynamic allocation in hot paths. No unbounded growth.
- Iteration bounds are always capped by count or array size constants.

**Result**: PASS -- No buffer overflow or underflow possible.

---

#### I-4: No Data Privacy Violations

**Assessment**: Health data handling is appropriate:
- Heart rate values are accumulated numerically (`_hrSum`, `_hrCount`, `_maxHr`) but never logged via `Sys.println()`.
- Calorie values are computed and stored in-memory but never logged.
- Jump counts are not logged.
- User weight is read from profile/properties but not logged.
- FIT data is written through the standard Garmin `ActivityRecording` API, which handles encryption and access control.
- No network permissions are requested; data cannot leave the device except through Garmin Connect sync (standard, encrypted channel).

**Result**: PASS -- Health data is processed in-memory only, persisted through official FIT API, never logged or exposed.

---

## Category-by-Category Assessment

| Security Criterion | Result | Notes |
|---------------------|--------|-------|
| Input validation (properties) | PASS | All 5 properties clamped. M-1 resolved. |
| Sensor data null checks | PASS | Four-level null cascade, per-element checks |
| Integer overflow | PASS | All counters safe within realistic usage bounds |
| Division by zero | PASS | All divisions guarded or use non-zero constants |
| Resource management | PASS | Sensor listener registered/unregistered symmetrically; FIT session nulled on save/discard |
| Buffer overflow/underflow | PASS | Fixed-size circular buffers with modular indexing |
| Denial of service | PASS | Hot path is O(1); no loops over unbounded data |
| Data privacy | PASS | No health data logged; FIT API handles secure storage |
| FIT data integrity | PASS | UINT16 overflow fixed; JPM values clamped to MAX_JPM |
| Exception handling | PASS | Session creation, FIT fields, profile access, and sensor registration all wrapped in try/catch |

---

## Fixes Applied

| # | Severity | File | Fix |
|---|----------|------|-----|
| 1 | Medium | `JumpDetector.mc:166-181` | Added try/catch around `registerSensorDataListener()` |
| 2 | Medium | `SessionManager.mc:344-354` | Added UINT16 clamp (65535) before writing `total_jumps` to FIT field |

---

## Sign-Off

Both Phase 2 source files (`JumpDetector.mc` and `SessionManager.mc`) have been reviewed against all 10 security criteria defined in the task specification. The Phase 1 M-1 finding (unbounded properties) is confirmed fully resolved. Two medium-severity issues were identified and fixed directly in the source files. No critical or high-severity vulnerabilities were found.

The codebase demonstrates strong security practices: comprehensive input validation, defense-in-depth null checking, fixed-size data structures, guarded arithmetic, proper exception handling, and appropriate health data privacy.

**Verdict**: Phase 2 files **PASS** security review.

**Signed**: security-agent, 2026-02-09
