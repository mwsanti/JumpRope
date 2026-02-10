# Security Review -- Phase 1 Files

**Project**: JumpRope (Garmin Connect IQ App)
**Target Device**: Forerunner 235 (Connect IQ 1.3)
**Review Date**: 2026-02-09
**Reviewer**: security-agent
**Overall Security Posture**: **PASS**

---

## Files Reviewed

| # | File | Lines |
|---|------|-------|
| 1 | `manifest.xml` | 34 |
| 2 | `monkey.jungle` | 16 |
| 3 | `resources/strings/strings.xml` | 39 |
| 4 | `resources/layouts/MainLayout.xml` | 91 |
| 5 | `resources/layouts/SummaryLayout.xml` | 167 |
| 6 | `properties/properties.xml` | 26 |
| 7 | `source/Constants.mc` | 174 |
| 8 | `source/JumpRopeApp.mc` | 63 |

---

## Findings Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 0 | -- |
| High | 0 | -- |
| Medium | 2 | Noted for Phase 2 implementation |
| Low | 2 | Acceptable risk |
| Info | 3 | Informational |

---

## Detailed Findings

### MEDIUM Findings

#### M-1: Unbounded User-Configurable Properties

**File**: `properties/properties.xml`
**Description**: The five configurable properties (`jumpThreshold`, `landingThreshold`, `debounceMs`, `sampleRate`, `userWeightKg`) have no declared minimum or maximum constraints. Users can modify these values via Garmin Connect Mobile or Garmin Express.

**Risk Scenarios**:
- `sampleRate = 0`: Could cause division-by-zero if used in calculations (e.g., samples-per-second math)
- `debounceMs = 0`: Could cause rapid-fire jump detection, excessive CPU usage, and potential app hang
- `userWeightKg = 0` or negative: Could produce nonsensical or negative calorie calculations
- `jumpThreshold < landingThreshold`: Inverted thresholds would break the two-state detection algorithm

**Impact**: App crash, incorrect data, or battery drain from runaway loops.

**Remediation**: When consuming these properties in Phase 2 code (views/delegates), validate and clamp values at runtime before use. Suggested bounds:
- `jumpThreshold`: 1200--3000 milliG
- `landingThreshold`: 200--800 milliG
- `debounceMs`: 50--500 ms
- `sampleRate`: 10--50 Hz
- `userWeightKg`: 20--300 kg

**Status**: No fix applied to Phase 1 files. This is a design-time note for Phase 2 implementation. The properties file itself is declarative and does not execute logic.

---

#### M-2: Placeholder Application UUID

**File**: `manifest.xml`, line 11
**Description**: The application ID `a1b2c3d4-e5f6-7890-abcd-ef1234567890` appears to be a placeholder/sequential UUID rather than a properly generated random UUID.

**Risk**: If submitted to the Connect IQ Store with this ID, it could collide with another app using the same placeholder. This would not cause a security vulnerability but could cause installation conflicts.

**Remediation**: Generate a proper UUID v4 before store submission (e.g., via `uuidgen` or an online generator). This is not a runtime security risk.

**Status**: Acceptable for development. Must be replaced before store submission.

---

### LOW Findings

#### L-1: Debug Logging in Production Code

**File**: `source/JumpRopeApp.mc`, lines 38, 49
**Description**: `Sys.println("JumpRopeApp: onStart")` and `Sys.println("JumpRopeApp: onStop")` are present. These log lifecycle events to the simulator console.

**Risk**: Minimal. These do not log any user data (no health metrics, PII, or sensor values). On physical hardware, `Sys.println()` output is not accessible to other apps or transmitted off-device. In the simulator, this is useful for debugging.

**Remediation**: Consider wrapping in a debug flag before store release to reduce negligible overhead, but this is not a security concern.

**Status**: Acceptable. No user data exposure.

---

#### L-2: Hardcoded Default Weight

**File**: `source/Constants.mc`, line 76; `properties/properties.xml`, line 23
**Description**: Default user weight is set to 70 kg in both the constants file and the properties file.

**Risk**: If the app cannot read the user's actual weight from their Garmin profile, it falls back to 70 kg. This could produce inaccurate calorie counts. This is not a privacy or security risk -- the weight value is a fallback default, not user-entered PII being logged or transmitted.

**Status**: Acceptable. Standard practice for fitness apps.

---

### INFORMATIONAL Findings

#### I-1: Permissions Are Minimal and Appropriate

**File**: `manifest.xml`, lines 22--26
**Description**: Three permissions declared:
- `Sensor`: Required for accelerometer access (jump detection)
- `SensorHistory`: Required for accessing sensor data history
- `FitContributor`: Required for writing custom FIT fields (jump count, JPM)

**Assessment**: These are the minimum permissions needed for the app's functionality. No network, communication, GPS, positioning, or user-info permissions are requested. The app has no ability to transmit data off-device, access the internet, or read user profile data beyond what FitContributor provides.

**Result**: PASS -- Principle of least privilege is followed.

---

#### I-2: Device Scope Is Properly Constrained

**File**: `manifest.xml`, lines 18--20
**Description**: Only `forerunner235` is listed as a target product. The app is not requesting broad device compatibility that could introduce untested behavior on devices with different sensor capabilities.

**Result**: PASS -- Single-device targeting is appropriate for Phase 1.

---

#### I-3: No Network, Storage, or IPC Attack Surface

**Assessment across all files**: The app does not:
- Request any network or communication permissions
- Perform HTTP requests or Bluetooth communication
- Access the file system beyond standard FIT recording
- Use inter-process communication (IPC)
- Include any third-party libraries or external dependencies

The entire attack surface is limited to: local sensor reads, on-screen display, and standard Garmin FIT file writing. There is no remote attack vector.

**Result**: PASS -- Attack surface is minimal.

---

## Category-by-Category Assessment

| Security Criterion | Result | Notes |
|---------------------|--------|-------|
| Permissions audit | PASS | Minimum required permissions only |
| Data privacy | PASS | No PII logged, no data transmitted |
| Input validation | WARN | Properties lack bounds (M-1); enforce at runtime in Phase 2 |
| Resource safety | PASS | Fixed buffer sizes, no dynamic allocation, lightweight design |
| Hardcoded secrets | PASS | No API keys, tokens, or credentials found |
| Integer overflow/underflow | PASS | All constants within safe 32-bit ranges |
| Denial of service | WARN | Edge case with sampleRate=0 or debounceMs=0 (M-1); mitigate in Phase 2 |
| Supply chain | PASS | Single device target, no external dependencies |

---

## Remediation Applied

No critical or high-severity issues were found. No code changes were made to Phase 1 files. The two medium findings (M-1 and M-2) require action in Phase 2 implementation code and pre-release preparation, respectively -- they do not affect the correctness or security of the current Phase 1 deliverables.

---

## Sign-Off

All 8 Phase 1 files have been reviewed against the defined security criteria. The codebase demonstrates sound security practices: minimal permissions, no data exposure, no hardcoded secrets, no network attack surface, and a constrained device target. The two medium-severity findings are design notes for Phase 2 and do not block progress.

**Verdict**: Phase 1 files are **safe to proceed** to Phase 2 development.

**Signed**: security-agent, 2026-02-09
