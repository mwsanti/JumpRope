// ==========================================================================
// Constants.mc — Centralized constants for the Jump Rope Connect IQ app
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 1.0.0
//
// All tunable parameters, thresholds, color definitions, FIT field IDs,
// and state values used throughout the app. Values are accessed as
// Constants.JUMP_THRESHOLD, Constants.STATE_RECORDING, etc.
// ==========================================================================

module Constants {

    // ======================================================================
    // Jump Detection Constants
    // Accelerometer-based two-threshold state machine parameters.
    // The FR235 accelerometer reports in milliG (1G = 1000 milliG).
    // ======================================================================

    // Baseline gravity in milliG (1G = 1000 milliG at rest)
    const GRAVITY = 1000;

    // Takeoff threshold in milliG. When smoothed Z-axis acceleration
    // exceeds this value (>1.8G), a takeoff is detected. The push-off
    // force during a jump creates an acceleration spike well above 1G.
    const JUMP_THRESHOLD = 1050;

    // Landing threshold in milliG (unused with Sensor.Info approach, kept for reference)
    const LANDING_THRESHOLD = 800;

    // Minimum milliseconds between detected jumps. Set low since
    // Sensor.Info fires at ~1Hz (samples are ~1000ms apart).
    const DEBOUNCE_MS = 50;

    // Smoothing window size. Set to 1 (no smoothing) because at ~1Hz
    // sample rate, smoothing causes unacceptable lag.
    const SMOOTHING_WINDOW_SIZE = 1;

    // Estimated jumps per above-threshold sensor reading.
    // At ~1Hz sample rate and ~120 JPM cadence (2 jumps/sec),
    // each elevated reading represents ~2 actual jumps.
    const JUMPS_PER_SAMPLE = 2;

    // Accelerometer polling rate in Hz. 25Hz is the maximum reliable
    // rate for the FR235's accelerometer via the Sensor API.
    const SAMPLE_RATE = 25;

    // ======================================================================
    // UI Update Intervals
    // Timer and metric refresh rates in milliseconds.
    // ======================================================================

    // Timer display refresh interval in ms. Updates the MM:SS display
    // once per second for smooth countdown/countup appearance.
    const TIMER_UPDATE_MS = 1000;

    // Jumps-per-minute recalculation interval in ms. Recalculates JPM
    // every 5 seconds to balance responsiveness with stability.
    const JPM_CALC_INTERVAL_MS = 5000;

    // Moving window duration in ms for JPM smoothing. Uses the last
    // 10 seconds of jump data to compute a smoothed JPM value,
    // preventing wild fluctuations from short bursts or pauses.
    const JPM_MOVING_WINDOW_MS = 10000;

    // ======================================================================
    // Calorie Calculation
    // MET-based calorie estimation for jump rope exercise.
    // Formula: cal/min = METs * 3.5 * weight_kg / 200
    // ======================================================================

    // Metabolic Equivalent of Task for moderate-intensity jump rope.
    // Source: Compendium of Physical Activities (code 15552).
    const JUMP_ROPE_METS = 12.0;

    // Default user weight in kilograms. Used as fallback when the user's
    // weight is not available from the Garmin user profile.
    const DEFAULT_USER_WEIGHT_KG = 70.0;

    // MET formula constant. Used in the standard MET calorie equation:
    // calories_per_min = METs * CALORIES_CONSTANT * weight_kg / CALORIES_DIVISOR
    const CALORIES_CONSTANT = 3.5;

    // MET formula divisor. Completes the standard MET-to-calorie conversion.
    const CALORIES_DIVISOR = 200.0;

    // ======================================================================
    // FIT Custom Field IDs
    // Field identifiers for ActivityRecording custom FIT fields.
    // These appear as custom metrics in Garmin Connect after sync.
    // ======================================================================

    // FIT field ID for total jump count recorded in the activity
    const FIELD_TOTAL_JUMPS = 0;

    // FIT field ID for average jumps per minute over the session
    const FIELD_AVG_JPM = 1;

    // FIT field ID for peak jumps per minute achieved during the session
    const FIELD_PEAK_JPM = 2;

    // ======================================================================
    // UI Color Constants
    // Hex color values for the FR235 color display (semi-round, 215x180).
    // Used for status indicators, text, and background rendering.
    // ======================================================================

    // Green — shown when actively recording a workout
    const COLOR_RECORDING = 0x00FF00;

    // Amber — shown when the workout is paused
    const COLOR_PAUSED = 0xFFAA00;

    // Red — shown when the workout is stopped
    const COLOR_STOPPED = 0xFF0000;

    // White — primary text color for jump count, timer, and stats
    const COLOR_TEXT_PRIMARY = 0xFFFFFF;

    // Light gray — secondary text color for labels and captions
    const COLOR_TEXT_SECONDARY = 0xAAAAAA;

    // Black — screen background color (OLED-friendly)
    const COLOR_BACKGROUND = 0x000000;

    // ======================================================================
    // Session Constants
    // Activity session metadata and sanity bounds.
    // ======================================================================

    // Activity name displayed in Garmin Connect after saving
    const SESSION_NAME = "Jump Rope";

    // Maximum plausible jumps per minute. Values above this are treated
    // as sensor noise and clamped. World record is ~330 JPM.
    const MAX_JPM = 400;

    // Minimum jumps per minute to display. Below this threshold the
    // JPM display shows 0 to avoid confusing low-noise readings.
    const MIN_JPM = 10;

    // ======================================================================
    // App State Constants
    // Application state machine values. Using integer constants instead
    // of enums for full CIQ 1.3 compatibility.
    // ======================================================================

    // App started, not yet recording. Initial state on launch.
    const STATE_IDLE = 0;

    // Actively counting jumps and recording the session.
    const STATE_RECORDING = 1;

    // Recording is paused. Timer and detection suspended.
    const STATE_PAUSED = 2;

    // Workout finished, showing the summary screen.
    const STATE_SUMMARY = 3;

    // ======================================================================
    // Jump Detector State Constants
    // Internal state machine for the two-threshold jump detection
    // algorithm. Tracks whether the user is on the ground or in the air.
    // ======================================================================

    // On the ground, waiting for acceleration to exceed JUMP_THRESHOLD
    // indicating a takeoff.
    const JUMP_STATE_GROUND = 0;

    // In the air after takeoff detected, waiting for acceleration to
    // drop below LANDING_THRESHOLD indicating a landing. On transition
    // back to GROUND, the jump counter increments.
    const JUMP_STATE_AIR = 1;

    // ======================================================================
    // Vibration Milestone Constants
    // Haptic feedback when the user reaches jump count milestones.
    // ======================================================================

    // Default jumps between vibration alerts (0 = disabled)
    const MILESTONE_INTERVAL = 100;

    // Vibration duty cycle percentage (0-100) for milestone alerts
    const MILESTONE_VIBE_DUTY = 50;

    // Vibration duration in milliseconds for milestone alerts
    const MILESTONE_VIBE_DURATION = 300;

    // ======================================================================
    // Countdown Timer Constants
    // Optional countdown mode where the timer counts down to zero.
    // ======================================================================

    // Vibration duty cycle percentage for countdown expiry (strong pulse)
    const COUNTDOWN_VIBE_DUTY = 100;

    // Vibration duration in milliseconds for countdown expiry
    const COUNTDOWN_VIBE_DURATION = 1000;

    // Maximum countdown duration in seconds (1 hour)
    const MAX_COUNTDOWN_SECONDS = 3600;

}
