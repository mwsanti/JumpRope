# JumpRope - Connect IQ Store Listing

## Store Submission Package
- **File**: `bin/JumpRope.iq` (84KB)
- **Upload to**: https://apps.garmin.com/developer

---

## App Information

### App Name
**JumpRope**

### Category
**Health & Fitness**

### App Type
**Watch App**

### Short Description (60 characters max)
```
Track jump rope workouts with automatic jump counting
```

### Full Description
```
Transform your Garmin watch into a dedicated jump rope tracker! JumpRope automatically counts your jumps using the built-in accelerometer, so you can focus on your workout without manual counting.

🎯 Key Features:
• Automatic jump detection - no manual counting needed
• Real-time jump count display
• Jumps per minute (JPM) tracking
• Heart rate monitoring during workout
• Elapsed time or countdown timer
• Milestone vibration alerts (every 100 jumps)
• Complete workout summaries with stats
• Saves workouts to Garmin Connect

Perfect for:
✓ Jump rope training and conditioning
✓ Cardio workouts
✓ CrossFit and HIIT sessions
✓ Boxing/MMA training
✓ Fitness challenges

How It Works:
1. Press START to begin your workout
2. Jump rope naturally - the app detects each jump automatically
3. Monitor your jump count, JPM, and heart rate in real-time
4. Press START again to pause and access the menu
5. Save your workout to review stats and sync to Garmin Connect

What You'll See:
• Large jump count (primary display)
• Current jumps per minute (JPM)
• Heart rate (BPM)
• Elapsed timer or countdown
• Summary screen with: Total Jumps, Duration, Avg/Peak JPM, Avg/Max HR, Calories

Settings (configure in Garmin Connect Mobile):
• Jump detection sensitivity
• Milestone vibration interval
• Countdown timer duration

Start tracking your jump rope progress today!
```

---

## Version Information

### Version Number
**1.0.0**

### What's New (Changelog)
```
Initial release - automatic jump counting, real-time stats, workout summaries
```

### Release Notes (detailed)
- Automatic jump detection using accelerometer
- Real-time jump count and JPM tracking
- Heart rate monitoring during workouts
- Complete workout summaries with 4 pages of stats
- Milestone vibration alerts (configurable)
- Countdown timer support
- Audio and haptic feedback on key actions
- Saves activities to Garmin Connect via FIT format

---

## Screenshots

Upload the following files from `screenshots/` folder:

1. **`2_active_workout.png`** - Active workout showing jump count, JPM, heart rate
2. **`3_pause_menu.png`** - Pause menu with Resume/Save/Discard options
3. **`4_summary_page1.png`** - Summary showing Total Jumps (87) and Duration (01:45)
4. **`5_summary_page2.png`** - Summary showing Avg JPM (124) and Peak JPM (148)
5. **`6_summary_page3.png`** - Summary showing Avg HR (142) and Max HR (158)

---

## Tags / Keywords
```
jump rope, fitness, workout, cardio, training, activity tracker, heart rate, exercise, jumps, conditioning
```

---

## Supported Devices
- **Forerunner 235** (fr235)

---

## Privacy Policy

### Privacy Statement
```
This app does not collect, store, or transmit any personal data. All workout data is processed locally on your device and saved to your Garmin Connect account using the standard Garmin FIT activity format.
```

### Privacy Policy URL (optional)
```
https://github.com/mwsanti/JumpRope#privacy
```

---

## Support & Contact

### Support Email
[Your email address]

### Support URL
```
https://github.com/mwsanti/JumpRope/issues
```

### Source Code (optional)
```
https://github.com/mwsanti/JumpRope
```

---

## Pricing
**Free**

---

## Languages
- **Primary Language**: English (eng)

---

## Age Rating
**Everyone**

---

## Technical Details

### Minimum CIQ API Level
**1.3.0**

### Permissions Required
- **Sensor** - Access accelerometer and heart rate sensor
- **FIT** - Save workout activities to Garmin Connect
- **FitContributor** - Add custom data fields to FIT files
- **UserProfile** - Read user weight for calorie calculation

### App Size
- **IQ Package**: 84KB
- **Installed Size**: ~50KB

### Color Scheme
- Background: Black (#000000)
- Primary text: White (#FFFFFF)
- Recording status: Green (#00FF00)
- Heart rate: Red (#FF0000)
- Secondary text: Light gray (#AAAAAA)
- Paused status: Amber (#FFAA00)

---

## Testing & Quality Assurance

### Tested Scenarios
✅ 30-jump calibration sets (~85% accuracy)
✅ 10-minute continuous workouts
✅ Pause/resume functionality
✅ Save/discard workflows
✅ Countdown timer mode
✅ Milestone vibrations (every 100 jumps)
✅ Heart rate monitoring
✅ FIT file generation and sync

### Performance
- Jump detection accuracy: ~85% at typical jump rope cadence (120 JPM)
- Detection method: Total acceleration magnitude (orientation-independent)
- Sensor rate: ~1Hz (Sensor.Info.accel on FR235)
- Jump multiplier: 2.5x (30 actual jumps → ~35 counted)

### Known Limitations
- Accuracy depends on consistent jumping cadence
- Wrist-based detection (not as accurate as foot pod)
- Best accuracy at 100-150 JPM cadence
- May overcount during very high intensity (200+ JPM)

---

## Marketing Assets

### App Icon
- **File**: `resources/drawables/launcher_icon.png`
- **Size**: 80x80 pixels
- **Design**: Stick figure jumping rope on transparent background

### Promotional Images
All screenshots available in `screenshots/` folder (215x180 px, FR235 native resolution)

---

## Developer Notes

### Build Information
- **SDK**: Connect IQ SDK 8.4.1
- **Build Command**: `monkeyc -e -o bin/JumpRope.iq -f monkey.jungle -y developer_key.der -w -l 0`
- **Compiler Flags**: `-l 0` (type check disabled for CIQ 1.3 compatibility)

### Future Enhancements (Post v1.0)
- Support for additional Garmin devices
- Configurable jump multiplier
- Training plans and challenges
- Social features (leaderboards, sharing)
- Advanced analytics
