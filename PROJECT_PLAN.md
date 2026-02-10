# Garmin Forerunner 235 — Jump Rope App Plan

## Context

You want a jump rope app for your Garmin Forerunner 235. This is **fully feasible** — the FR235 supports Connect IQ 1.3 apps, has a built-in accelerometer with API access, and jump rope apps already exist on the Connect IQ store proving the concept works. The app will be written in **Monkey C** using the Garmin Connect IQ SDK.

## Key Device Facts

| Spec | Value |
|------|-------|
| Platform | Connect IQ 1.3 |
| Screen | 215x180 px, semi-round, color |
| Sensors | Accelerometer, optical HR, GPS |
| App memory | ~64KB limit (CIQ 1.3 device) |
| Language | Monkey C |
| IDE | VS Code + Connect IQ extension |

## Dev Environment Setup

1. Install **Java 8+** (required by SDK)
2. Install **VS Code** + **Monkey C / Connect IQ extension**
3. Download **Connect IQ SDK** via SDK Manager (developer.garmin.com)
4. Target device: `forerunner235` in manifest
5. Use the built-in **simulator** for initial testing; real device for accelerometer tuning

## Project Structure

```
JumpRopeApp/
├── manifest.xml                 # Permissions: Sensor, FitContributor
├── monkey.jungle                # Build config
├── resources/
│   ├── layouts/
│   │   ├── MainLayout.xml       # Workout screen
│   │   └── SummaryLayout.xml    # Post-workout summary
│   ├── strings/strings.xml
│   └── drawables/launcher_icon.png  # 80x80 PNG-8
├── source/
│   ├── JumpRopeApp.mc           # AppBase entry point
│   ├── MainView.mc              # Workout screen (jump count, timer, HR, JPM)
│   ├── MainDelegate.mc          # Button handling (start/pause/stop)
│   ├── SummaryView.mc           # Post-workout stats display
│   ├── SummaryDelegate.mc       # Save/discard actions
│   ├── JumpDetector.mc          # Accelerometer-based jump detection
│   ├── SessionManager.mc        # ActivityRecording + FIT file + metrics
│   └── Constants.mc             # Thresholds, colors, field IDs
└── properties/properties.xml
```

## App Type

Full **App** (not widget/data field) — runs until manually stopped, full sensor access, can record activities.

## Core Algorithm: Jump Detection

Two-threshold state machine on accelerometer Z-axis (vertical):

```
State: ON_GROUND
  → If smoothed Z > 1800 milliG AND debounce passed → State: IN_AIR

State: IN_AIR
  → If smoothed Z < 500 milliG → State: ON_GROUND, jumpCount++
```

Key parameters (tunable via real-device testing):

| Parameter | Initial Value | Purpose |
|-----------|--------------|---------|
| JUMP_THRESHOLD | 1800 milliG | Takeoff detection (>1.8G) |
| LANDING_THRESHOLD | 500 milliG | Landing detection (<0.5G) |
| DEBOUNCE_MS | 150ms | Min time between jumps (max ~400 JPM) |
| WINDOW_SIZE | 5 samples | Rolling average smoothing |
| SAMPLE_RATE | 25 Hz | Accelerometer polling rate |

**Why this works**: Jump rope creates a distinctive vertical acceleration signature — a spike above gravity on takeoff, then a dip below gravity on landing. The two-threshold state machine prevents double-counting, and the debounce filters noise.

## Features

### Main Workout Screen
- **Jump count** (large, center) — updates on each detected jump
- **Timer** (MM:SS) — updates every second
- **Jumps per minute** — recalculated every 5 seconds
- **Heart rate** (BPM) — from wrist optical sensor
- **Status indicator** — Recording (green) / Paused (yellow)

### Controls
- **START**: Begin/resume recording
- **STOP**: Pause recording
- **BACK**: Stop workout → show summary

### Summary Screen
- Total jumps, duration, avg JPM, peak JPM, calories, avg HR, max HR
- Save (writes FIT file to Garmin Connect) or Discard

### Activity Recording
- Uses `ActivityRecording.createSession()` with sport type TRAINING
- Custom FIT fields: total_jumps, avg_jpm, peak_jpm
- HR recorded automatically by session
- Calories estimated from MET value (12.0 for jump rope)

## Implementation Phases

### Phase 1: Scaffold
- `manifest.xml` with permissions (Sensor, FitContributor)
- `JumpRopeApp.mc` — AppBase lifecycle
- `Constants.mc` — all tunable values
- `monkey.jungle` build config

### Phase 2: Jump Detection (critical path)
- `JumpDetector.mc` — register accelerometer listener, implement state machine
- Smoothing buffer, debounce, callback system

### Phase 3: Workout UI
- `MainView.mc` — render jump count, timer, HR, JPM
- `MainDelegate.mc` — START/STOP/BACK button handling
- `MainLayout.xml` — layout for 215x180 semi-round screen

### Phase 4: Activity Recording
- `SessionManager.mc` — create session, custom FIT fields, metrics calc
- Wire up to MainView for periodic updates

### Phase 5: Summary Screen
- `SummaryView.mc` + `SummaryDelegate.mc` — stats display, save/discard
- `SummaryLayout.xml`

### Phase 6: Testing & Tuning
- Simulator testing for UI/logic
- **Real FR235 testing is mandatory** for accelerometer tuning
- Count 100 jumps manually, compare to app count, adjust thresholds
- Target: 95%+ accuracy for single jumps

## Memory Budget (~40-58 KB, well under 64KB limit)

| Component | Est. Size |
|-----------|----------|
| Source code (8 .mc files) | 25-35 KB |
| Layouts + strings | 3-5 KB |
| Launcher icon | 2-3 KB |
| Runtime overhead | 10-15 KB |

## Known Limitations

- Wrist position affects accuracy — watch must be snug
- Optimized for standard single jumps; double-unders may need separate detection
- Very slow (<40 JPM) or very fast (>300 JPM) jumps may be less accurate
- No gyroscope on FR235, so detection relies on accelerometer only

## Future Ideas (v2)
- Interval timer (work/rest rounds)
- Double-under detection
- Calibration mode (user does 20 jumps to personalize thresholds)
- Vibration alerts at milestones

## Verification
1. Build with `monkeyc` via VS Code extension — confirm no compile errors
2. Run in Connect IQ simulator — verify UI renders, buttons work, timer counts
3. Side-load to FR235 via USB — verify accelerometer data flows
4. Do a real jump rope session — compare app count to manual count
5. Save session — confirm it appears in Garmin Connect with custom fields
