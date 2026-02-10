# Build and Test Guide -- Jump Rope for Garmin Forerunner 235

Complete guide for setting up, building, testing, deploying, and publishing the Jump Rope Connect IQ app.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [SDK Setup](#2-sdk-setup)
3. [Building the Project](#3-building-the-project)
4. [Simulator Testing](#4-simulator-testing)
5. [Device Deployment (Side-loading)](#5-device-deployment-side-loading)
6. [Accelerometer Threshold Tuning](#6-accelerometer-threshold-tuning)
7. [Properties / Settings Reference](#7-properties--settings-reference)
8. [Garmin Connect Integration](#8-garmin-connect-integration)
9. [Publishing to Connect IQ Store](#9-publishing-to-connect-iq-store)
10. [Troubleshooting](#10-troubleshooting)
11. [Architecture Overview](#11-architecture-overview)

---

## 1. Prerequisites

Before you begin, ensure you have the following installed and configured:

| Requirement | Details |
|---|---|
| **Java JDK 8+** | Full JDK required (not JRE). The Monkey C compiler runs on the JVM. Verify with `java -version` and `javac -version`. |
| **Visual Studio Code** | Recommended IDE. Download from https://code.visualstudio.com/ |
| **Connect IQ VS Code Extension** | Publisher: Garmin. Install from the VS Code Extensions marketplace (search "Monkey C"). |
| **Garmin Developer Account** | Free registration at https://developer.garmin.com/connect-iq/ |
| **Connect IQ SDK 4.x+** | Downloaded and managed via the Connect IQ SDK Manager (installed with the VS Code extension). |

### Verify Java Installation

```bash
java -version
# Expected: java version "1.8.0_xxx" or higher (11, 17, 21 all work)

javac -version
# Expected: javac 1.8.0_xxx or higher
```

If Java is not installed, install OpenJDK:

```bash
# Debian/Ubuntu/Kali
sudo apt install openjdk-17-jdk

# macOS (Homebrew)
brew install openjdk@17

# Windows: download from https://adoptium.net/
```

---

## 2. SDK Setup

### Step 1: Install the Connect IQ VS Code Extension

1. Open VS Code.
2. Go to Extensions (Ctrl+Shift+X).
3. Search for "Monkey C" (publisher: Garmin).
4. Click **Install**.

The extension includes the SDK Manager, syntax highlighting, build tasks, and simulator integration.

### Step 2: Download the SDK via SDK Manager

1. Open the VS Code command palette (Ctrl+Shift+P).
2. Run **Monkey C: Open SDK Manager**.
3. The SDK Manager window opens. Click **Download** next to the latest stable SDK (4.x recommended).
4. Wait for the download and extraction to complete.

### Step 3: Install Forerunner 235 Device Support

1. In the SDK Manager, go to the **Devices** tab.
2. Find **Forerunner 235** in the device list.
3. Click **Install** to download the device simulator files.
4. The FR235 has a semi-round display (215x180 pixels) with Connect IQ 1.3 support.

### Step 4: Configure the SDK Path

1. Open VS Code Settings (Ctrl+,).
2. Search for "Monkey C SDK".
3. Set the SDK path to your downloaded SDK directory (e.g., `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-xxx`).
4. Alternatively, set the `GARMIN_HOME` environment variable.

### Step 5: Verify Installation

```bash
# Navigate to the SDK bin directory and verify
monkeyc --version
# Expected output: Monkey C Compiler x.x.x

# Or from the SDK path directly:
~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-xxx/bin/monkeyc --version
```

If `monkeyc` is not on your PATH, add the SDK `bin/` directory:

```bash
export PATH="$PATH:$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-xxx/bin"
```

---

## 3. Building the Project

### Project Structure

```
JumpRope/
  manifest.xml              -- App metadata, permissions, device targets
  monkey.jungle             -- Build configuration (source + resource paths)
  source/
    JumpRopeApp.mc          -- App entry point and lifecycle
    MainView.mc             -- Primary workout display screen
    MainDelegate.mc         -- Button input handler for workout screen
    JumpDetector.mc         -- Accelerometer-based jump detection engine
    SessionManager.mc       -- FIT activity recording and metrics
    SummaryView.mc          -- Post-workout summary display
    SummaryDelegate.mc      -- Button input handler for summary screen
    Constants.mc            -- All tunable parameters and constants
  resources/
    layouts/
      MainLayout.xml        -- Workout screen UI layout
      SummaryLayout.xml     -- Summary screen UI layout
    strings/
      strings.xml           -- All user-visible strings (English)
    drawables/
      drawables.xml         -- Drawable resource definitions
      launcher_icon.png     -- App icon (80x80 PNG)
  properties/
    properties.xml          -- User-configurable settings (thresholds, weight, milestones, countdown)
```

### Build via VS Code (Recommended)

1. Open the `/home/kali/JumpRope/` directory in VS Code (**File > Open Folder**).
2. VS Code should automatically detect `monkey.jungle` and `manifest.xml`.
3. Build the project:
   - Press **Ctrl+Shift+B** (Build), or
   - Open the command palette (Ctrl+Shift+P) and run **Monkey C: Build for Device**.
4. Select **forerunner235** as the target device when prompted.
5. The compiled output is written to `bin/JumpRope.prg`.

### Build via Command Line

```bash
cd /home/kali/JumpRope

monkeyc \
  -d forerunner235 \
  -f monkey.jungle \
  -o bin/JumpRope.prg \
  -y /path/to/developer_key.der
```

**Parameters:**
- `-d forerunner235` -- Target device identifier.
- `-f monkey.jungle` -- Build configuration file.
- `-o bin/JumpRope.prg` -- Output binary path.
- `-y /path/to/developer_key.der` -- Your developer signing key (generated during Garmin developer account setup). Required for device deployment; optional for simulator-only builds.

### Generate a Developer Key

If you do not have a developer key:

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

Or use the Connect IQ SDK tool:

```bash
connectiq keygen developer_key
```

### Expected Build Output

A successful build produces `bin/JumpRope.prg` with no errors. Typical output:

```
BUILD: Loading monkey.jungle
BUILD: Compiling resources
BUILD: Compiling sources
BUILD: Linking
BUILD: Output -> bin/JumpRope.prg
```

### Common Build Errors

| Error | Cause | Fix |
|---|---|---|
| `Cannot find symbol` | Missing class or method reference | Check `using` statements and verify all `.mc` files are in `source/` |
| `Could not find jungle file` | Wrong working directory | Run from the project root containing `monkey.jungle` |
| `Unsupported device` | FR235 support not installed | Install device files via SDK Manager |
| `Invalid resource` | Malformed XML in layouts/strings | Validate XML syntax in `resources/` files |
| `Memory exceeded` | App too large for device | FR235 has ~60KB usable memory; check for large arrays or string allocations |
| `API level` errors | Using API features above CIQ 1.3 | This app targets `minApiLevel="1.3.0"` -- verify any new code uses only CIQ 1.3 APIs |

---

## 4. Simulator Testing

### Launch the Simulator

**From VS Code:**
1. Open the command palette (Ctrl+Shift+P).
2. Run **Monkey C: Build and Run** (or **Monkey C: Run**).
3. Select **forerunner235** as the device.
4. The Connect IQ Simulator opens with the FR235 display.

**From command line:**
```bash
# Start the simulator
connectiq &

# Load the built app
monkeydo bin/JumpRope.prg forerunner235
```

### UI Navigation

The FR235 has two relevant buttons simulated as keyboard shortcuts in the simulator:

| Watch Button | Simulator Key | Action |
|---|---|---|
| **START/STOP** (top-right) | Enter | Start / Pause / Resume recording |
| **BACK/LAP** (bottom-right) | Escape | Stop workout / Exit app |

### Workout Flow Walkthrough

**Starting a workout:**
1. App launches showing "PRESS START" status, jump count 0, timer 00:00.
2. Press **Enter** (START) -- status changes to green "RECORDING", timer begins, jump detection activates.

**During recording:**
- Jump count updates in real time from accelerometer data.
- Timer counts up in MM:SS format (1-second refresh), or counts down if `countdownSeconds` is configured.
- JPM (jumps per minute) updates every 5 seconds using a 10-second sliding window.
- Heart rate displays if the sensor provides data ("--" otherwise).
- Vibration milestone alerts trigger at configurable intervals (default: every 100 jumps).
- If countdown mode is active, the timer turns red and the session auto-pauses when the countdown reaches zero.

**Pausing:**
1. Press **Enter** (START) while recording -- status changes to amber "PAUSED".
2. Timer freezes. Jump detection stops.
3. Press **Enter** again to resume -- status returns to green "RECORDING", timer continues from where it left off.

**Stopping and summary:**
1. Press **Escape** (BACK) while recording or paused.
2. The summary screen slides in from the right showing:
   - Total Jumps
   - Duration (MM:SS, excludes paused time)
   - Avg JPM
   - Peak JPM
   - Calories
   - Avg HR / Max HR (or "--" if no HR data)
3. Bottom hint shows: "START=Save  BACK=Discard"

**Saving or discarding:**
- Press **Enter** (START) on summary -- saves the FIT session, vibrates, returns to main screen in IDLE state.
- Press **Escape** (BACK) on summary -- discards the session, returns to main screen in IDLE state.

### Simulating Sensor Data

The Connect IQ Simulator has limited accelerometer simulation:

1. **Sensor simulation panel**: In the simulator menu, go to **Simulation > Sensor Data** to inject sensor values.
2. **Accelerometer data**: You can set Z-axis values manually. To simulate jumps, alternate between high values (>1800 milliG for takeoff) and low values (<500 milliG for landing) with at least 150ms between transitions.
3. **Heart rate**: Set a simulated HR value in the sensor panel to verify the HR display updates.

**Note:** Real jump detection accuracy can only be validated on a physical device with actual jump rope activity. The simulator is best for verifying UI flow, state transitions, and session lifecycle.

### Checking Memory Usage

- The simulator status bar shows current memory usage.
- The FR235 allows approximately 60KB for Connect IQ apps.
- Monitor memory during workout simulation to ensure no leaks over extended sessions.
- In the simulator menu, check **View > Memory** for a detailed breakdown.

### Expected Behavior Summary

| State | Display | START Button | BACK Button |
|---|---|---|---|
| IDLE | "PRESS START", count=0, timer=00:00 | Begin recording | Exit app |
| RECORDING | Green "RECORDING", live count/timer/JPM/HR | Pause | Stop, show summary |
| PAUSED | Amber "PAUSED", frozen count/timer | Resume | Stop, show summary |
| SUMMARY | Workout stats, save/discard hint | Save session | Discard session |

---

## 5. Device Deployment (Side-loading)

### Step 1: Build for Device

Ensure the app is built with a developer key (see Section 3):

```bash
monkeyc -d forerunner235 -f monkey.jungle -o bin/JumpRope.prg -y developer_key.der
```

### Step 2: Connect the Watch

1. Power on the Forerunner 235.
2. Connect it to your computer via the USB charging/data cable.
3. The watch should appear as a USB mass storage device.
4. If it does not mount automatically, you may need to accept a prompt on the watch or wait a few seconds.

### Step 3: Copy the App

1. Open the mounted watch filesystem.
2. Navigate to the `GARMIN/APPS/` directory.
3. Copy `bin/JumpRope.prg` into `GARMIN/APPS/`.

```bash
# Linux example (adjust mount point as needed)
cp bin/JumpRope.prg /media/$USER/GARMIN/GARMIN/APPS/

# macOS example
cp bin/JumpRope.prg /Volumes/GARMIN/GARMIN/APPS/
```

### Step 4: Safely Eject and Launch

1. Safely eject the watch (unmount the USB drive).
2. Disconnect the cable.
3. On the watch, navigate to the activity list or app drawer.
4. Find "JumpRope" in the list.
5. On first launch, the watch may prompt you to accept permissions (Sensor, FitContributor).

### Permissions

The app requires two permissions defined in `manifest.xml`:

| Permission | Purpose |
|---|---|
| **Sensor** | Access to accelerometer data for jump detection and heart rate sensor |
| **FitContributor** | Write custom FIT fields (total_jumps, avg_jpm, peak_jpm) to activity files |

These permissions are declared at install time:
```xml
<iq:permissions>
    <iq:uses-permission id="Sensor" />
    <iq:uses-permission id="FitContributor" />
</iq:permissions>
```

---

## 6. Accelerometer Threshold Tuning

This is the most critical calibration step for accurate jump counting. The default values work for average-speed jump rope with a standard rope and wrist-mounted watch, but individual variation in jump style, rope weight, and wrist movement will affect accuracy.

### How the Detection Algorithm Works

The jump detector uses a two-threshold state machine on the Z-axis (vertical) accelerometer:

```
              smoothedZ > jumpThreshold
GROUND  ---------------------------------------->  AIR
   ^                                                 |
   |            smoothedZ < landingThreshold          |
   <--------------------------------------------------
              (jump counted, debounce enforced)
```

1. **Takeoff**: When the smoothed Z-axis acceleration exceeds `jumpThreshold` (default 1800 milliG = 1.8G), the detector transitions from GROUND to AIR state.
2. **Landing**: When the smoothed Z-axis drops below `landingThreshold` (default 500 milliG = 0.5G), it transitions back to GROUND and increments the jump counter.
3. **Debounce**: A minimum of `debounceMs` (default 150ms) must elapse between consecutive jump detections, preventing double-counting from sensor bounce.
4. **Smoothing**: A rolling average over `SMOOTHING_WINDOW_SIZE` samples (5 samples = 200ms at 25Hz) filters out high-frequency noise.

### Default Values

| Parameter | Default | Unit | Description |
|---|---|---|---|
| `jumpThreshold` | 1800 | milliG | Takeoff detection (1.8G) |
| `landingThreshold` | 500 | milliG | Landing detection (0.5G) |
| `debounceMs` | 150 | ms | Minimum time between jumps |
| `sampleRate` | 25 | Hz | Accelerometer polling rate |

### Tuning Procedure

**Calibration test protocol:**

1. Set the watch on your wrist, start the app, and begin recording.
2. Jump rope at a **steady, moderate pace** (~120 JPM / 2 jumps per second).
3. **Count 100 jumps manually** while the app is recording.
4. Stop the session and compare your manual count to the app's count.

**Interpreting results:**

| Symptom | App shows fewer jumps than manual count | App shows more jumps than manual count |
|---|---|---|
| **Likely cause** | `jumpThreshold` too high (missing soft jumps) | `jumpThreshold` too low (arm movements or noise triggering false positives) |
| **Adjustment** | Lower `jumpThreshold` by 100-200 (try 1600, then 1400) | Raise `jumpThreshold` by 100-200 (try 2000, then 2200) |

| Symptom | Double-counting (jumps counted 2x) | No jumps detected at all |
|---|---|---|
| **Likely cause** | `debounceMs` too low, or `landingThreshold` too high | Sensor not active, permissions missing, or threshold way too high |
| **Adjustment** | Increase `debounceMs` by 25-50 (try 175, then 200) | Check Sensor permission; try lowering `jumpThreshold` to 1400 |

**Target accuracy: 95% or better** (e.g., app counts 95-105 when you manually count 100).

### Recommended Test Scenarios

Run each scenario for 1 minute and compare manual vs app count:

| Scenario | Expected JPM | Purpose |
|---|---|---|
| **Basic singles** (relaxed pace) | ~60 JPM | Verify detection at low cadence |
| **Moderate singles** (normal pace) | ~120 JPM | Primary calibration target |
| **Fast singles** (high pace) | ~180+ JPM | Stress test; ensure no missed jumps |
| **Standing still** | 0 JPM | Verify no false positives at rest |
| **Walking normally** | 0 JPM | Verify walking does not trigger jumps |
| **Waving arms without jumping** | 0 JPM | Verify wrist motion alone does not trigger |
| **Single high jump** | 1 jump | Verify single jumps register correctly |

### How to Change Threshold Settings

Settings are changed via the Garmin Connect Mobile app or Garmin Express:

1. Open **Garmin Connect Mobile** on your phone.
2. Go to **Devices** > **Forerunner 235** > **Activities & Apps**.
3. Find **JumpRope** in the app list.
4. Tap **Settings**.
5. Adjust `jumpThreshold`, `landingThreshold`, `debounceMs`, `sampleRate`, `userWeightKg`, `milestoneInterval`, and `countdownSeconds`.
6. Sync the watch to apply the new settings.

The new values take effect the next time the app is launched. The `JumpDetector` reads properties at construction time and clamps them to safe ranges (see Section 7).

---

## 7. Properties / Settings Reference

All configurable properties are defined in `properties/properties.xml` and read at app startup by `JumpDetector` and `SessionManager`. Each property is validated and clamped to a safe range.

### Property Definitions

| Property | Type | Default | Min | Max | Description |
|---|---|---|---|---|---|
| `jumpThreshold` | Number | 1800 | 1200 | 3000 | Takeoff detection threshold in milliG. Higher = less sensitive (fewer false positives but may miss soft jumps). |
| `landingThreshold` | Number | 500 | 200 | 800 | Landing detection threshold in milliG. Lower = less sensitive (fewer false landings). |
| `debounceMs` | Number | 150 | 50 | 500 | Minimum milliseconds between detected jumps. Higher = prevents double-counting at the cost of capping maximum detectable JPM. At 150ms, max theoretical JPM is ~400. |
| `sampleRate` | Number | 25 | 10 | 50 | Accelerometer polling rate in Hz. 25Hz is the maximum reliable rate for the FR235. Lower rates save battery but reduce detection accuracy. |
| `userWeightKg` | Number | 70 | 20 | 300 | User's body weight in kilograms for MET-based calorie calculation. The app first checks the Garmin user profile (weight in grams / 1000); this property is the fallback. |
| `milestoneInterval` | Number | 100 | 0 | 1000 | Number of jumps between vibration milestone alerts. Set to 0 to disable milestone vibrations. When enabled, the watch vibrates (50% duty, 300ms pulse) each time the jump count reaches a multiple of this value (e.g., at 100, 200, 300...). |
| `countdownSeconds` | Number | 0 | 0 | 3600 | Countdown timer duration in seconds. Set to 0 for count-up mode (default). When set to a positive value, the timer counts down from this duration. When the countdown reaches zero, the watch vibrates strongly (100% duty, 1000ms pulse) and the session auto-pauses. Maximum: 3600 seconds (1 hour). |

### Validation Rules

Applied in `JumpDetector.initialize()` via `_clampInt()` and in `MainView.initialize()`:

1. If a property value is `null` or not a `Number`, the compiled default from `Constants.mc` is used.
2. If the value is outside `[min, max]`, it is clamped to the nearest boundary.
3. If `jumpThreshold <= landingThreshold` after clamping, both reset to compiled defaults (1800 / 500). This prevents the state machine from stalling.
4. `milestoneInterval` is clamped to 0-1000 in `MainView.initialize()`. A value of 0 disables milestone vibrations.
5. `countdownSeconds` is clamped to 0-3600 in `MainView.initialize()`. A value of 0 selects count-up mode.

### How to Access Settings

**Via Garmin Connect Mobile (phone):**
1. Open Garmin Connect Mobile.
2. Navigate to: Devices > Forerunner 235 > Activities & Apps > JumpRope > Settings.
3. Edit the desired values.
4. Sync the watch to push changes.

**Via Garmin Express (desktop):**
1. Connect the watch to your computer.
2. Open Garmin Express.
3. Navigate to the device, then IQ Apps > JumpRope > Settings.
4. Edit and sync.

**Changes take effect on next app launch** -- `JumpDetector` reads detection properties and `MainView` reads milestone/countdown properties once during initialization.

---

## 8. Garmin Connect Integration

### Activity Recording

The app records activities as FIT files using the Garmin `ActivityRecording` API. When you save a session (press START on the summary screen), the FIT file is written to the watch's activity storage.

**Session metadata:**
- **Activity type**: Training > Cardio Training
- **Name**: "Jump Rope"
- **Sport**: `SPORT_TRAINING`
- **Sub-sport**: `SUB_SPORT_CARDIO_TRAINING`

### Syncing to Garmin Connect

1. After saving a workout, sync the watch with your phone (via Bluetooth and Garmin Connect Mobile) or computer (via USB and Garmin Express).
2. The activity appears in Garmin Connect under **Activities** as a "Training" activity named "Jump Rope".

### Custom FIT Fields

The app writes three custom FIT fields to each session:

| Field Name | Field ID | Data Type | Unit | Description |
|---|---|---|---|---|
| `total_jumps` | 0 | UINT16 | jumps | Total jump count (capped at 65,535) |
| `avg_jpm` | 1 | UINT16 | jpm | Average jumps per minute over the session |
| `peak_jpm` | 2 | UINT16 | jpm | Highest JPM achieved during the session |

These appear as custom/developer fields in Garmin Connect and are visible when viewing the activity details.

### Standard Fields

The following standard metrics are automatically recorded by the Garmin framework:

- **Duration**: Total active time (excludes paused time)
- **Heart Rate**: Continuous HR from the wrist-based sensor (avg, max, HR graph)
- **Calories**: MET-based estimate using the formula: `cal/min = 12.0 * 3.5 * weight_kg / 200`

### Calorie Calculation Details

The calorie estimate uses a fixed MET value of 12.0 (moderate-intensity jump rope, from the Compendium of Physical Activities code 15552):

```
calories = METs * 3.5 * weight_kg * elapsed_minutes / 200
```

At default 70kg weight, this yields approximately 14.7 calories per minute.

---

## 9. Publishing to Connect IQ Store

### Step 1: Generate a Unique App UUID

The `manifest.xml` contains a placeholder UUID. You **must** replace it with a unique one before publishing:

```xml
<!-- Current placeholder in manifest.xml -->
<iq:application id="a1b2c3d4-e5f6-7890-abcd-ef1234567890" ...>
```

Generate a new UUID:

```bash
# Linux/macOS
uuidgen
# Example output: 3f8a1b2c-9d4e-5f67-8901-abc234567def

# Python
python3 -c "import uuid; print(uuid.uuid4())"
```

Replace the `id` attribute in `manifest.xml` with your generated UUID.

### Step 2: Create App Assets

**Launcher icon:**
- The current `launcher_icon.png` is a placeholder.
- Create an 80x80 pixel PNG-8 icon with a transparent background.
- Design for a round display context; keep important content within the center 60x60 area.
- Replace `resources/drawables/launcher_icon.png`.

**Store screenshots:**
1. Run the app in the simulator.
2. Take screenshots of each screen state:
   - Main screen in IDLE state ("PRESS START")
   - Main screen while RECORDING (with non-zero jump count)
   - Main screen while PAUSED
   - Summary screen with sample workout data
3. Capture using your OS screenshot tool or the simulator's built-in screenshot feature.
4. Recommended: 215x180 pixel PNG images matching the FR235 display.

### Step 3: Write the Store Description

Suggested template:

```
Jump Rope -- Track your jump rope workouts with real-time metrics.

Features:
- Real-time jump counting using wrist accelerometer
- Jumps per minute (JPM) with 10-second rolling average
- Elapsed time with pause/resume support
- Countdown timer mode with auto-pause at expiry
- Vibration milestone alerts (configurable interval, e.g., every 100 jumps)
- Heart rate monitoring (wrist-based)
- MET-based calorie estimation
- Post-workout summary with save/discard option
- Custom FIT fields synced to Garmin Connect (total jumps, avg JPM, peak JPM)
- Configurable detection thresholds for different jump styles

Designed for the Forerunner 235. Adjustable sensitivity settings
available via Garmin Connect Mobile or Garmin Express.
```

### Step 4: Submit to the Store

1. Log in at https://developer.garmin.com/connect-iq/.
2. Go to **My Apps** > **Create New App**.
3. Fill in the app details:
   - Name: JumpRope
   - Type: Watch App
   - Description: (use the template above or your own)
   - Supported devices: Forerunner 235
   - Minimum API level: 1.3.0
4. Upload:
   - The built `.prg` file (or an `.iq` package if required).
   - Launcher icon.
   - Store screenshots.
5. Submit for review.

### Review Timeline

Garmin typically reviews Connect IQ Store submissions within 3-7 business days. You will receive email notification when the app is approved or if changes are required.

---

## 10. Troubleshooting

### Build Issues

| Problem | Solution |
|---|---|
| `monkeyc: command not found` | Add the SDK `bin/` directory to your PATH. See Section 2, Step 5. |
| `Java not found` | Install JDK 8+ (see Section 1). |
| `Cannot find project manifest` | Ensure you are running `monkeyc` from the directory containing `monkey.jungle`. |
| `Type check` errors | This app targets CIQ 1.3 (no type checker). If using SDK 4.x with type checking enabled, add `--warn` flag or disable type checking in project settings. |

### Runtime Issues on Device

| Problem | Likely Cause | Solution |
|---|---|---|
| **"IQ!" error on watch** | App crash (out of memory, unhandled exception) | Check memory usage in the simulator. The FR235 has ~60KB available. Review the crash log via Garmin Express (Settings > Device > Debug Logs). |
| **No jump detection** | Sensor permission not granted, or thresholds too high | Verify the Sensor permission was accepted at install. Try lowering `jumpThreshold` to 1400. Ensure the watch is worn snugly on the wrist. |
| **Jump count too high** | Threshold too low (false positives from arm motion) | Raise `jumpThreshold` by 200 increments (try 2000, 2200). Increase `debounceMs` to 200. |
| **Double-counting jumps** | Debounce too short, or landing threshold too high | Increase `debounceMs` by 25-50ms. Lower `landingThreshold` by 100 (try 400, then 300). |
| **No heart rate displayed ("--")** | Watch not worn properly, or HR sensor issue | Ensure the watch is worn snugly 1-2 fingers above the wrist bone. Check that the Sensor permission is granted. The optical HR sensor needs skin contact. |
| **Session not saving** | FitContributor permission not granted | Reinstall the app and accept the FitContributor permission. Verify the permission is listed in `manifest.xml`. |
| **App won't install** | Insufficient storage on watch | Delete unused apps or activities from the watch to free space. The FR235 has limited storage. |
| **Activity not appearing in Garmin Connect** | Sync not completed | Force a sync via Garmin Connect Mobile (pull down to refresh) or connect via USB with Garmin Express. |
| **Custom fields not visible in Garmin Connect** | Normal -- custom fields may be under "Developer Fields" | In the activity details on Garmin Connect web, scroll to the bottom or check "More Data" for developer/custom fields. |
| **Timer shows negative or incorrect time** | Pause/resume timing bug | The `getElapsedMs()` method clamps to non-negative values. If this occurs, file a bug with steps to reproduce. |
| **JPM shows 0 while jumping** | Below the MIN_JPM threshold (10 JPM) | The app suppresses JPM values below 10 to avoid displaying noise. Jump at a pace of at least 10 per minute for JPM to register. |
| **No milestone vibrations** | `milestoneInterval` set to 0, or Attention API not available | Check that `milestoneInterval` is set to a positive value (e.g., 100) in app settings. Some devices may not support haptic feedback. |
| **Countdown not working** | `countdownSeconds` set to 0 | Set `countdownSeconds` to a positive value (e.g., 180 for 3 minutes) in app settings via Garmin Connect Mobile. |
| **Countdown auto-paused unexpectedly** | Countdown reached zero | This is expected behavior. When the countdown expires, the session auto-pauses and the watch vibrates. Press START to resume or BACK to stop. |

### Retrieving Crash Logs

1. Connect the watch via USB.
2. Navigate to `GARMIN/APPS/LOGS/` on the mounted filesystem.
3. Look for `CIQ_LOG.yml` or similar log files.
4. The log contains stack traces and error codes from CIQ runtime crashes.

---

## 11. Architecture Overview

### Source Files and Responsibilities

| File | Class | Role |
|---|---|---|
| `JumpRopeApp.mc` | `JumpRopeApp` | App entry point. Creates the initial MainView and MainDelegate. Holds global `appState`. |
| `MainView.mc` | `MainView` | Primary workout UI. Owns `JumpDetector` and `SessionManager`. Updates display labels every second. Manages sensor lifecycle, milestone vibration alerts, and countdown timer with auto-pause. |
| `MainDelegate.mc` | `MainDelegate` | Input handler for workout screen. Routes START/BACK button presses to MainView methods based on app state. |
| `JumpDetector.mc` | `JumpDetector` | Core detection engine. Two-threshold state machine on smoothed Z-axis accelerometer data. Tracks JPM via circular timestamp buffer. |
| `SessionManager.mc` | `SessionManager` | FIT activity recording. Manages session lifecycle (start/pause/resume/stop/save/discard). Calculates calories, tracks HR stats, writes custom FIT fields. |
| `SummaryView.mc` | `SummaryView` | Post-workout summary display. Reads final metrics from SessionManager and populates layout labels. |
| `SummaryDelegate.mc` | `SummaryDelegate` | Input handler for summary screen. START saves the FIT session (with haptic vibration); BACK discards it. |
| `Constants.mc` | `Constants` (module) | All tunable parameters, color definitions, FIT field IDs, state machine values. Central reference for magic numbers. |

### Data Flow

```
                        Accelerometer Hardware
                               |
                               v
                     Sensor.registerSensorDataListener()
                               |
                               v
                    +---------------------+
                    |    JumpDetector      |
                    |                     |
                    |  Z-axis samples     |
                    |       |             |
                    |       v             |
                    |  Smoothing buffer   |
                    |  (5-sample avg)     |
                    |       |             |
                    |       v             |
                    |  State machine      |
                    |  GROUND <-> AIR     |
                    |       |             |
                    |  Jump detected!     |
                    |  _jumpCount++       |
                    +--------+------------+
                             |
                     callback(jumpCount)
                             |
                             v
                    +---------------------+
                    |     MainView        |
                    |                     |
                    |  onJumpDetected()   |
                    |  requestUpdate()    |
                    |  milestone vibe?    |--> Attention.vibrate()
                    |                     |
                    |  Every 1 second:    |
                    |  updateMetrics() -->+--------+
                    |  countdown check   |        |
                    |  requestUpdate()    |        |
                    +---------------------+        v
                                          +---------------------+
                                          |  SessionManager     |
                                          |                     |
                                          |  FIT recording      |
                                          |  Elapsed time       |
                                          |  Calorie calc       |
                                          |  HR statistics      |
                                          |  Custom FIT fields  |
                                          +--------+------------+
                                                   |
                                              save() / discard()
                                                   |
                                                   v
                                          +---------------------+
                                          |   FIT File          |
                                          |   (on watch)        |
                                          +--------+------------+
                                                   |
                                              Bluetooth/USB sync
                                                   |
                                                   v
                                          +---------------------+
                                          |   Garmin Connect    |
                                          |   (cloud)           |
                                          +---------------------+
```

### State Machine

The app uses a simple four-state machine managed via `JumpRopeApp.appState`:

```
          START            BACK
IDLE  ---------->  RECORDING  ---------->  SUMMARY
                      |   ^                   |
                START  |   |  START            |  START=Save
                      v   |                   |  BACK=Discard
                    PAUSED                    |
                                              v
                                            IDLE
```

| State | Value | Description |
|---|---|---|
| `STATE_IDLE` | 0 | App launched, not recording. Waiting for START. |
| `STATE_RECORDING` | 1 | Actively detecting jumps and recording FIT session. |
| `STATE_PAUSED` | 2 | Recording paused. Timer frozen, detection stopped. |
| `STATE_SUMMARY` | 3 | Workout stopped. Showing summary, awaiting save/discard. |

### Jump Detection State Machine (Internal)

Within `JumpDetector`, a two-state machine processes each accelerometer sample:

| State | Value | Transition Condition | Action |
|---|---|---|---|
| `JUMP_STATE_GROUND` | 0 | `smoothedZ > jumpThreshold` AND debounce elapsed | Transition to AIR |
| `JUMP_STATE_AIR` | 1 | `smoothedZ < landingThreshold` | Transition to GROUND, increment jump count, fire callback |

### Memory Considerations

The FR235 has approximately 60KB available for Connect IQ apps. Key memory-conscious design decisions in this codebase:

- **Fixed-size arrays**: The smoothing buffer (5 elements) and JPM timestamp buffer (60 elements) are pre-allocated and reused via circular indexing. No dynamic allocation during the workout loop.
- **Integer state constants**: The app uses `const` integer values instead of enums for full CIQ 1.3 compatibility and minimal overhead.
- **No string interpolation in hot paths**: The detection loop (`_processSample`) does not allocate strings or objects.
- **Null-guarded UI updates**: All `findDrawableById()` calls are null-checked to prevent crashes from layout inflation failures.

---

## Quick Reference Card

```
BUILD:    monkeyc -d forerunner235 -f monkey.jungle -o bin/JumpRope.prg -y key.der
RUN SIM:  connectiq && monkeydo bin/JumpRope.prg forerunner235
DEPLOY:   Copy bin/JumpRope.prg to GARMIN/APPS/ on mounted watch
SETTINGS: Garmin Connect Mobile > Devices > FR235 > Apps > JumpRope > Settings
LOGS:     GARMIN/APPS/LOGS/CIQ_LOG.yml on mounted watch
```
