# Connect IQ Store Submission Instructions

## ✅ Your App is Ready!

The `.iq` package file has been generated and is ready to upload:
- **File**: `bin/Jumpr.iq` (84KB)
- **Contains**: Binaries for all supported devices (currently: Forerunner 235)

---

## Step-by-Step Submission Process

### 1. Go to Connect IQ Developer Portal
Navigate to: https://apps.garmin.com/developer

### 2. Sign In
- Click "Sign In" (top right)
- Use your Garmin account credentials
- If you don't have a developer account, click "Register" (it's free)

### 3. Upload Your App
- Click **"Manage My Apps"**
- Click **"Upload New App"**
- Click **"Choose File"** and select: `bin/Jumpr.iq`
- Click **"Upload"**

The system will validate your .iq file. Once validated, you'll be able to add descriptions and screenshots.

---

## 4. Fill Out App Information

### Basic Info
- **App Name**: `Jumpr`
- **Category**: `Health & Fitness`
- **App Type**: `Watch App` (auto-detected from manifest)

### Description

**Short Description** (60 chars max):
```
Track jump rope workouts with automatic jump counting
```

**Full Description** (copy from below):
```
Transform your Garmin watch into a dedicated jump rope tracker! Jumpr automatically counts your jumps using the built-in accelerometer, so you can focus on your workout without manual counting.

Key Features:
- Automatic jump detection - no manual counting needed
- Real-time jump count display
- Jumps per minute (JPM) tracking
- Heart rate monitoring during workout
- Elapsed time or countdown timer
- Milestone vibration alerts (every 100 jumps)
- Complete workout summaries with stats
- Saves workouts to Garmin Connect

Perfect for:
- Jump rope training and conditioning
- Cardio workouts
- CrossFit and HIIT sessions
- Boxing/MMA training
- Fitness challenges

How It Works:
1. Press START to begin your workout
2. Jump rope naturally - the app detects each jump automatically
3. Monitor your jump count, JPM, and heart rate in real-time
4. Press START again to pause and access the menu
5. Save your workout to review stats and sync to Garmin Connect

What You'll See:
- Large jump count (primary display)
- Current jumps per minute (JPM)
- Heart rate (BPM)
- Elapsed timer or countdown
- Summary screen with: Total Jumps, Duration, Avg/Peak JPM, Avg/Max HR, Calories

Settings (configure in Garmin Connect Mobile):
- Jump detection sensitivity
- Milestone vibration interval
- Countdown timer duration

Start tracking your jump rope progress today!
```

### Version Info
- **Version**: `1.0.0`
- **What's New**: `Initial release - automatic jump counting, real-time stats, workout summaries`

---

## 5. Upload Screenshots

Upload the following files from `screenshots/` folder (in order):

1. **`2_active_workout.png`** - Main screen during active jumping
2. **`3_pause_menu.png`** - Pause menu with options
3. **`4_summary_page1.png`** - Summary: Total Jumps & Duration
4. **`5_summary_page2.png`** - Summary: Avg/Peak JPM
5. **`6_summary_page3.png`** - Summary: Avg/Max HR

*(Upload at least 2, maximum 5)*

---

## 6. Additional Information

### Pricing
- Select: **Free**

### Privacy Policy
```
This app does not collect, store, or transmit any personal data. All workout data is processed locally on your device and saved to your Garmin Connect account using the standard Garmin FIT activity format.
```

Or provide URL: `https://github.com/mwsanti/JumpRope#privacy`

### Support Contact
- **Email**: Your email address
- **Support URL**: `https://github.com/mwsanti/JumpRope/issues`

### Tags/Keywords
```
jump rope, fitness, workout, cardio, training, activity tracker, heart rate, exercise, jumps, conditioning
```

### Languages
- **Primary Language**: English

### Age Rating
- **Rating**: Everyone

---

## 7. Review and Submit

1. Review all information for accuracy
2. Agree to Connect IQ Developer Agreement
3. Click **"Submit for Review"**

---

## What Happens Next?

### Review Process
- **Timeline**: 1-2 weeks typically
- **Garmin Reviews**:
  - App functionality (no crashes)
  - UI/UX guidelines compliance
  - Privacy/data handling
  - Store listing accuracy

### You'll Receive:
- Email confirmation of submission
- Updates during review process
- Approval or change requests

### After Approval:
- App goes live in Connect IQ Store
- Users can find and install via:
  - Garmin Connect Mobile app
  - Garmin Express (desktop)
  - Connect IQ Store website
- You can track downloads and ratings

---

## Troubleshooting

### If Upload Fails:
- Verify you selected the `.iq` file (not `.prg`)
- Check file size (should be ~84KB)
- Ensure you're using Connect IQ SDK 8.4.1 or later
- Try uploading from a different browser

### If Review Requests Changes:
- Garmin will provide specific feedback
- Make requested changes
- Rebuild `.iq` file with: `monkeyc -e -o bin/Jumpr.iq -f monkey.jungle -y developer_key.der -w -l 0`
- Re-upload updated version

---

## Quick Reference

**Files to Upload:**
- ✅ `bin/Jumpr.iq` (app package - 84KB)
- ✅ 5 screenshots from `screenshots/` folder

**Links:**
- Upload: https://apps.garmin.com/developer
- Documentation: https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/
- Your GitHub: https://github.com/mwsanti/JumpRope

---

Good luck with your submission! 🚀
