# Phase 1 Code Review Report

**Reviewer**: review-agent
**Date**: 2026-02-09
**Scope**: All Phase 1 files (manifest, build config, resources, constants, app entry point)
**Verdict**: PASS — ready for Phase 2 (after fixes applied below)

---

## Files Reviewed

| # | File | Status |
|---|------|--------|
| 1 | `manifest.xml` | Fixed (2 issues) |
| 2 | `monkey.jungle` | Clean |
| 3 | `resources/strings/strings.xml` | Clean |
| 4 | `resources/layouts/MainLayout.xml` | Clean |
| 5 | `resources/layouts/SummaryLayout.xml` | Fixed (1 issue) |
| 6 | `resources/drawables/drawables.xml` | Clean |
| 7 | `properties/properties.xml` | Clean |
| 8 | `source/Constants.mc` | Clean |
| 9 | `source/JumpRopeApp.mc` | Clean |

---

## Critical Issues (Fixed)

### C1: `manifest.xml` — Invalid application type value

**File**: `manifest.xml:15`
**Was**: `type="watchapp"`
**Fixed to**: `type="watch-app"`

The Connect IQ manifest schema requires `watch-app` (hyphenated) as the application type. The value `watchapp` is not a valid type and would cause a build failure during compilation.

### C2: `manifest.xml` — Unnecessary `SensorHistory` permission

**File**: `manifest.xml:24` (removed)
**Was**: `<iq:uses-permission id="SensorHistory" />`
**Fixed**: Removed the permission entirely.

The app uses real-time accelerometer data via `Sensor` and activity recording via `FitContributor`. It does not read stored sensor history data. Declaring `SensorHistory` unnecessarily:
- Triggers an extra permission prompt during install
- Requests access the app never uses (principle of least privilege)
- Could cause confusion during Connect IQ store review

### C3: `SummaryLayout.xml` — Semi-round display clipping

**File**: `SummaryLayout.xml` (7 labels)
**Was**: Right-aligned value labels at `x="205"`
**Fixed to**: `x="195"`

The FR235 has a 215x180 **semi-round** display where the usable pixel width narrows at the top and bottom edges. Labels placed at x=205 in rows at y=25 and y=145 risk clipping against the curved screen boundary. Moving to x=195 provides a 10px safety margin that prevents text from being cut off on the physical display.

---

## Warnings

### W1: `properties.xml` — Properties duplicate constants

The `jumpThreshold`, `landingThreshold`, `debounceMs`, `sampleRate`, and `userWeightKg` properties in `properties.xml` have the same values as the corresponding constants in `Constants.mc`. Phase 2 code should decide on a single source of truth:
- Either read values from `Application.Properties.getValue()` at runtime (making them user-configurable via Garmin Connect Mobile)
- Or use the `Constants.mc` values directly (simpler, less memory)

Using both without coordination could lead to bugs where the code reads from `Constants.mc` while the user changes a property value that has no effect.

**Recommendation**: In Phase 2, `JumpDetector.mc` should read from `Application.Properties.getValue()` to honor user-configured values, and `Constants.mc` values should serve as compile-time defaults/documentation.

### W2: `MainLayout.xml` — FR235 semi-round edge awareness for bottom labels

The JPM and HR labels at y=140-155 are positioned at x=55 and x=160 respectively. On the semi-round display, the bottom edge narrows slightly. These positions should be safe (they are well within the usable area at those y-coordinates), but should be verified in the simulator during Phase 3.

### W3: `manifest.xml` — Placeholder application ID

The `id="a1b2c3d4-e5f6-7890-abcd-ef1234567890"` is clearly a placeholder UUID. Before publishing to the Connect IQ store, this must be replaced with a unique UUID generated for the app. Not an issue during development.

---

## Suggestions

### S1: `Constants.mc` — Consider `hidden` annotation for internal constants

Constants like `JUMP_STATE_GROUND`, `JUMP_STATE_AIR`, and the color constants could be annotated with `(:hidden)` to indicate they are implementation details rather than public API. This is a minor code organization improvement and not required.

### S2: `strings.xml` — Consider adding error/edge-case strings

Future phases may need strings like "No HR Sensor", "Low Battery", or "Session Error". These can be added as needed in later phases. Not a blocker.

### S3: `SummaryLayout.xml` — Bottom hint text may be tight on semi-round

The `ActionHint` label at y=165 with text "START=Save  BACK=Discard" is near the very bottom of the 180px-tall display. On the semi-round screen this area is narrow. If it clips in the simulator, consider shortening to "START=Save / BACK=Discard" or moving up slightly.

---

## CIQ 1.3 Compatibility Verification

| Feature Used | CIQ Version Available | Status |
|---|---|---|
| `App.AppBase` | 1.0.0 | OK |
| `Ui.View` / layouts | 1.0.0 | OK |
| `Sensor` permission | 1.0.0 | OK |
| `FitContributor` permission | 1.0.0 | OK |
| `Graphics.FONT_NUMBER_HOT` | 1.0.0 | OK |
| `Graphics.FONT_XTINY` | 1.0.0 | OK |
| `Graphics.TEXT_JUSTIFY_*` | 1.0.0 | OK |
| `const` keyword | 1.0.0 | OK |
| `module` keyword | 1.0.0 | OK |
| Float literals | 1.0.0 | OK |
| Integer state constants (vs enums) | 1.0.0 | OK — enums require CIQ 2.1+ |
| `Sys.println()` | 1.0.0 | OK |
| Layout XML labels | 1.0.0 | OK |
| `<properties>` XML | 1.0.0 | OK |

No CIQ 1.3 compatibility issues found. The code correctly avoids enums (CIQ 2.1+), dictionaries with typed keys (CIQ 2.4+), and other newer features.

---

## Consistency Checks

### String ID Cross-References

| String ID in `strings.xml` | Referenced By | Match |
|---|---|---|
| `AppName` | `manifest.xml` `@Strings.AppName` | OK |
| `Recording` | `MainLayout.xml` `@Strings.Recording` | OK |
| `Jumps` | `MainLayout.xml` `@Strings.Jumps` | OK |
| `JPM` | `MainLayout.xml` `@Strings.JPM` | OK |
| `HeartRate` | `MainLayout.xml` `@Strings.HeartRate` | OK |
| `Summary` | `SummaryLayout.xml` `@Strings.Summary` | OK |
| `TotalJumps` | `SummaryLayout.xml` `@Strings.TotalJumps` | OK |
| `Duration` | `SummaryLayout.xml` `@Strings.Duration` | OK |
| `AvgJPM` | `SummaryLayout.xml` `@Strings.AvgJPM` | OK |
| `PeakJPM` | `SummaryLayout.xml` `@Strings.PeakJPM` | OK |
| `Calories` | `SummaryLayout.xml` `@Strings.Calories` | OK |
| `AvgHR` | `SummaryLayout.xml` `@Strings.AvgHR` | OK |
| `MaxHR` | `SummaryLayout.xml` `@Strings.MaxHR` | OK |
| `Paused` | Not yet referenced (Phase 3) | OK — will be used by MainView |
| `Stopped` | Not yet referenced (Phase 3) | OK — will be used by MainView |
| `Save` | Not yet referenced (Phase 5) | OK — will be used by SummaryDelegate |
| `Discard` | Not yet referenced (Phase 5) | OK — will be used by SummaryDelegate |

All string references resolve correctly. Unused strings are expected to be consumed in later phases.

### Drawable Cross-References

| Drawable ID | Referenced By | Match |
|---|---|---|
| `LauncherIcon` | `manifest.xml` `@Drawables.LauncherIcon` | OK |

### Layout Element IDs (for Phase 2-5 `findDrawableById()` calls)

**MainLayout.xml** elements:
- `StatusLabel` — for recording/paused status text and color
- `JumpsLabel` — static label
- `JumpCount` — dynamic jump count value
- `TimerLabel` — dynamic MM:SS timer
- `JPMLabel` — static label
- `JPMValue` — dynamic JPM value
- `HRLabel` — static label
- `HRValue` — dynamic heart rate value

**SummaryLayout.xml** elements:
- `SummaryTitle` — static header
- `TotalJumpsValue` — dynamic total jumps
- `DurationValue` — dynamic duration
- `AvgJPMValue` — dynamic average JPM
- `PeakJPMValue` — dynamic peak JPM
- `CaloriesValue` — dynamic calories
- `AvgHRValue` — dynamic average HR
- `MaxHRValue` — dynamic max HR
- `ActionHint` — static save/discard hint

### Constants Cross-References

| Constant | Will Be Used By | Purpose |
|---|---|---|
| `JUMP_THRESHOLD` | `JumpDetector.mc` | Takeoff detection |
| `LANDING_THRESHOLD` | `JumpDetector.mc` | Landing detection |
| `DEBOUNCE_MS` | `JumpDetector.mc` | Double-count prevention |
| `SMOOTHING_WINDOW_SIZE` | `JumpDetector.mc` | Rolling average buffer |
| `SAMPLE_RATE` | `JumpDetector.mc` | Accelerometer Hz |
| `TIMER_UPDATE_MS` | `MainView.mc` | Timer refresh rate |
| `JPM_CALC_INTERVAL_MS` | `MainView.mc` or `JumpDetector.mc` | JPM recalc timing |
| `JPM_MOVING_WINDOW_MS` | `JumpDetector.mc` | JPM smoothing window |
| `JUMP_ROPE_METS` | `SessionManager.mc` | Calorie calculation |
| `DEFAULT_USER_WEIGHT_KG` | `SessionManager.mc` | Calorie fallback weight |
| `CALORIES_CONSTANT` | `SessionManager.mc` | MET formula |
| `CALORIES_DIVISOR` | `SessionManager.mc` | MET formula |
| `FIELD_TOTAL_JUMPS` | `SessionManager.mc` | FIT field ID |
| `FIELD_AVG_JPM` | `SessionManager.mc` | FIT field ID |
| `FIELD_PEAK_JPM` | `SessionManager.mc` | FIT field ID |
| `COLOR_*` | `MainView.mc` | Status indicator colors |
| `SESSION_NAME` | `SessionManager.mc` | Activity name |
| `MAX_JPM` / `MIN_JPM` | `MainView.mc` | JPM clamping |
| `STATE_*` | `JumpRopeApp.mc`, views, delegates | App state machine |
| `JUMP_STATE_*` | `JumpDetector.mc` | Jump detector state |
| `GRAVITY` | `JumpDetector.mc` | Baseline reference |

All constants are well-defined and will be consumed by Phase 2-5 modules.

---

## Memory Assessment

| Component | Estimated Size |
|---|---|
| `Constants.mc` (compiled) | ~1-2 KB |
| `JumpRopeApp.mc` (compiled) | ~0.5 KB |
| Layout XMLs (2 layouts) | ~2-3 KB |
| `strings.xml` (17 strings) | ~0.5 KB |
| `properties.xml` (5 properties) | ~0.3 KB |
| `drawables.xml` + icon | ~2-3 KB |
| **Phase 1 Total** | **~6-9 KB** |
| **Remaining budget** (of 64 KB) | **~55-58 KB** |

Phase 1 is well within memory budget, leaving ample room for Phase 2-5 source files and runtime overhead.

---

## Conclusion

Phase 1 scaffold is solid and well-structured. Three issues were found and fixed directly:

1. **manifest.xml**: `type="watchapp"` corrected to `type="watch-app"` (build-breaking)
2. **manifest.xml**: Removed unnecessary `SensorHistory` permission (least privilege)
3. **SummaryLayout.xml**: Adjusted right-aligned labels from x=205 to x=195 (semi-round clipping)

All string references, drawable references, and constant definitions are consistent and complete. CIQ 1.3 compatibility is confirmed with no use of features from later API versions. Memory usage is well within the 64KB budget.

**Files are ready for Phase 2 (Jump Detection) development.**
