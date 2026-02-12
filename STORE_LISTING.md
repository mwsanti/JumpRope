# JumpRope - Connect IQ Store Listing

## App Name
JumpRope

## Short Description (60 characters max)
Track your jump rope workouts with automatic jump counting

## Full Description

Transform your Garmin watch into a dedicated jump rope tracker! JumpRope automatically counts your jumps using the built-in accelerometer, so you can focus on your workout without manual counting.

**Key Features:**
- ✓ Automatic jump detection - no manual counting needed
- ✓ Real-time jump count display
- ✓ Jumps per minute (JPM) tracking
- ✓ Heart rate monitoring during workout
- ✓ Elapsed time or countdown timer
- ✓ Milestone vibration alerts (every 100 jumps)
- ✓ Complete workout summary with stats
- ✓ Saves workouts to Garmin Connect

**Perfect for:**
- Jump rope training and conditioning
- Cardio workouts
- CrossFit and HIIT sessions
- Boxing/MMA training
- Fitness challenges

**How It Works:**
1. Press START to begin your workout
2. Jump rope naturally - the app detects each jump automatically
3. Monitor your jump count, JPM, and heart rate in real-time
4. Press START again to pause and access the menu
5. Save your workout to review stats and sync to Garmin Connect

**What You'll See:**
- Large jump count (primary display)
- Current jumps per minute (JPM)
- Heart rate (BPM)
- Elapsed timer or countdown
- Summary screen with: Total Jumps, Duration, Avg/Peak JPM, Avg/Max HR, Calories

**Settings (configure in Garmin Connect Mobile):**
- Jump detection sensitivity
- Milestone vibration interval
- Countdown timer duration

**Supported Devices:**
- Garmin Forerunner 235

Start tracking your jump rope progress today!

## Category
Health & Fitness

## Tags
- jump rope
- fitness
- workout
- cardio
- training
- activity tracker
- heart rate
- exercise

## Version
1.0.0

## What's New (Changelog)
- Initial release
- Automatic jump detection using accelerometer
- Real-time jump count and JPM tracking
- Heart rate monitoring
- Workout summaries with stats
- Milestone vibration alerts
- Countdown timer support
- Saves to Garmin Connect

## Privacy Policy
This app does not collect, store, or transmit any personal data. All workout data is processed locally on your device and saved to your Garmin Connect account using the standard Garmin FIT activity format.

## Support Contact
https://github.com/mwsanti/JumpRope/issues

## Screenshots Needed
Please capture the following screenshots from your watch:

1. **Main screen during workout**
   - Shows jump count, timer, JPM, HR
   - While actively jumping (showing real numbers)

2. **Pause menu**
   - Shows Resume/Save/Discard options

3. **Summary screen - Page 1**
   - Total Jumps and Duration

4. **Summary screen - Page 2**
   - Avg JPM and Peak JPM

5. **Summary screen - Page 3**
   - Avg HR and Max HR

**To capture screenshots:**
1. Install the app on your watch
2. Do a short workout (30-50 jumps)
3. Take photos of the watch screen at each stage
4. Or use the simulator with `connectiq` command

## Marketing Assets

### Icon
- File: `resources/drawables/launcher_icon.png`
- Size: 80x80px
- Shows: Stick figure jumping rope

### Color Scheme
- Background: Black (#000000)
- Primary text: White (#FFFFFF)
- Accent (recording): Green (#00FF00)
- Heart rate: Red (#FF0000)
- Secondary text: Light gray (#AAAAAA)

## Technical Details

### Minimum CIQ Version
1.3.0

### Target Devices
- Forerunner 235 (fr235)

### App Type
Watch App

### Permissions Required
- Sensor (accelerometer, heart rate)
- FIT (save activities)

### File Size
~50KB compiled

## Testing Notes

The app has been tested with:
- 30-jump calibration sets (±15% accuracy)
- 10-minute continuous workouts
- Pause/resume functionality
- Save/discard workflows
- Countdown timer mode
- Milestone vibrations

Detection accuracy: ~85% at typical jump rope cadence (120 JPM)
