// ==========================================================================
// SessionManager.mc — FIT activity recording and metrics manager
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 1.0.0
//
// Manages the Garmin FIT activity recording session for jump rope workouts.
// Handles session lifecycle (start/pause/resume/stop/save/discard),
// elapsed time tracking with pause support, MET-based calorie calculation,
// heart rate statistics, and custom FIT fields for jump-specific data.
// ==========================================================================

using Toybox.ActivityRecording as Record;
using Toybox.FitContributor as Fit;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.UserProfile as Profile;
using Toybox.Lang as Lang;

class SessionManager {

    // ActivityRecording.Session instance (null when not recording)
    var _session;

    // FitContributor fields for custom jump metrics
    var _jumpField;
    var _avgJpmField;
    var _peakJpmField;

    // Timing state
    var _startTime;
    var _pauseTime;
    var _totalPausedMs;

    // Recording state flags
    var _isRecording;
    var _isPaused;

    // Jump metrics
    var _totalJumps;
    var _avgJpm;
    var _peakJpm;

    // Calorie calculation
    var _userWeight;
    var _calories;

    // Heart rate statistics
    var _hrSum;
    var _hrCount;
    var _maxHr;

    // Initializes all state to defaults and reads user weight from
    // profile or app properties.
    function initialize() {
        _session = null;
        _jumpField = null;
        _avgJpmField = null;
        _peakJpmField = null;

        _startTime = 0;
        _pauseTime = 0;
        _totalPausedMs = 0;

        _isRecording = false;
        _isPaused = false;

        _totalJumps = 0;
        _avgJpm = 0;
        _peakJpm = 0;

        _calories = 0.0;

        _hrSum = 0;
        _hrCount = 0;
        _maxHr = 0;

        _userWeight = _loadUserWeight();
    }

    // Reads user weight in kg. Tries Garmin user profile first (stored
    // in grams), then app property, then falls back to default.
    // Clamps result to 20-300 kg range.
    hidden function _loadUserWeight() {
        var weight = null;

        // Try user profile (weight is in grams in CIQ)
        try {
            var profile = Profile.getProfile();
            if (profile != null) {
                var profileWeight = profile.weight;
                if (profileWeight != null && profileWeight > 0) {
                    weight = profileWeight / 1000.0;
                }
            }
        } catch (e) {
            // Profile not available, continue to fallback
        }

        // Try app property
        if (weight == null) {
            try {
                var propWeight = App.getApp().getProperty("userWeightKg");
                if (propWeight != null && propWeight > 0) {
                    weight = propWeight.toFloat();
                }
            } catch (e) {
                // Property not available, continue to fallback
            }
        }

        // Final fallback
        if (weight == null) {
            return Constants.DEFAULT_USER_WEIGHT_KG;
        }

        // Clamp to 20-300 kg
        if (weight < 20.0) {
            weight = 20.0;
        } else if (weight > 300.0) {
            weight = 300.0;
        }

        return weight;
    }

    // Creates and starts a new FIT activity recording session with
    // custom fields for jump count, average JPM, and peak JPM.
    // Wraps session creation in try/catch for robustness.
    function startSession() {
        try {
            _session = Record.createSession({
                :name => Constants.SESSION_NAME,
                :sport => Record.SPORT_TRAINING,
                :subSport => Record.SUB_SPORT_CARDIO_TRAINING
            });
        } catch (e) {
            Sys.println("SessionManager: Failed to create session");
            _session = null;
            return;
        }

        if (_session == null) {
            return;
        }

        // Create custom FIT fields for jump metrics
        try {
            _jumpField = _session.createField(
                "total_jumps",
                Constants.FIELD_TOTAL_JUMPS,
                Fit.DATA_TYPE_UINT16,
                {:mesgType => Fit.MESG_TYPE_SESSION, :units => "jumps"}
            );

            _avgJpmField = _session.createField(
                "avg_jpm",
                Constants.FIELD_AVG_JPM,
                Fit.DATA_TYPE_UINT16,
                {:mesgType => Fit.MESG_TYPE_SESSION, :units => "jpm"}
            );

            _peakJpmField = _session.createField(
                "peak_jpm",
                Constants.FIELD_PEAK_JPM,
                Fit.DATA_TYPE_UINT16,
                {:mesgType => Fit.MESG_TYPE_SESSION, :units => "jpm"}
            );
        } catch (e) {
            Sys.println("SessionManager: Failed to create FIT fields");
        }

        // Start the FIT recording
        _session.start();

        // Reset all metric state
        _startTime = Sys.getTimer();
        _pauseTime = 0;
        _totalPausedMs = 0;
        _isRecording = true;
        _isPaused = false;
        _totalJumps = 0;
        _avgJpm = 0;
        _peakJpm = 0;
        _calories = 0.0;
        _hrSum = 0;
        _hrCount = 0;
        _maxHr = 0;

        Sys.println("SessionManager: Session started");
    }

    // Pauses the FIT recording and records the pause timestamp.
    // No-op if not currently recording or already paused.
    function pauseSession() {
        if (!_isRecording || _isPaused) {
            return;
        }

        if (_session != null) {
            _session.stop();
        }

        _pauseTime = Sys.getTimer();
        _isPaused = true;
        _isRecording = false;
    }

    // Resumes the FIT recording from a paused state. Accumulates
    // the paused duration so elapsed time calculations remain accurate.
    function resumeSession() {
        if (!_isPaused) {
            return;
        }

        // Accumulate paused duration
        _totalPausedMs += (Sys.getTimer() - _pauseTime);

        if (_session != null) {
            _session.start();
        }

        _isPaused = false;
        _isRecording = true;
    }

    // Stops the FIT recording. Updates final FIT field values.
    // Does not save or discard — call saveSession() or discardSession() after.
    function stopSession() {
        if (_session == null) {
            return;
        }

        if (_isRecording) {
            _session.stop();
        }

        // If stopping from paused state, accumulate the final pause
        // duration so getElapsedMs() returns correct active time in
        // the summary view.
        if (_isPaused && _pauseTime > 0) {
            _totalPausedMs += (Sys.getTimer() - _pauseTime);
        }

        _isRecording = false;
        _isPaused = false;

        // Write final field values
        _updateFitFields();
    }

    // Saves the FIT session to device storage. Updates final FIT field
    // values before saving. Returns true if saved successfully.
    function saveSession() {
        if (_session == null) {
            return false;
        }

        // Final update of FIT fields
        _updateFitFields();

        _session.save();
        _session = null;
        _jumpField = null;
        _avgJpmField = null;
        _peakJpmField = null;

        Sys.println("SessionManager: Session saved");
        return true;
    }

    // Discards the FIT session without saving. Resets all session state.
    function discardSession() {
        if (_session == null) {
            return;
        }

        _session.discard();
        _session = null;
        _jumpField = null;
        _avgJpmField = null;
        _peakJpmField = null;

        _isRecording = false;
        _isPaused = false;
        _startTime = 0;
        _pauseTime = 0;
        _totalPausedMs = 0;
        _totalJumps = 0;
        _avgJpm = 0;
        _peakJpm = 0;
        _calories = 0.0;
        _hrSum = 0;
        _hrCount = 0;
        _maxHr = 0;

        Sys.println("SessionManager: Session discarded");
    }

    // Called periodically (~1 second) by MainView to update jump metrics,
    // heart rate stats, and calorie estimates. Writes to FIT fields if
    // the session is active.
    //
    // jumpCount — total jumps from JumpDetector
    // currentJpm — current jumps per minute (unused for avg calc)
    // peakJpm — peak JPM from JumpDetector
    // heartRate — current HR reading (may be null)
    function updateMetrics(jumpCount, currentJpm, peakJpm, heartRate) {
        _totalJumps = jumpCount;

        // Update peak JPM
        if (peakJpm > _peakJpm) {
            _peakJpm = peakJpm;
        }

        // Calculate average JPM from total jumps and elapsed time
        var elapsedMs = getElapsedMs();
        if (elapsedMs > 0) {
            _avgJpm = (jumpCount * 60000) / elapsedMs;
        } else {
            _avgJpm = 0;
        }

        // Clamp average JPM
        if (_avgJpm < 0) {
            _avgJpm = 0;
        } else if (_avgJpm > Constants.MAX_JPM) {
            _avgJpm = Constants.MAX_JPM;
        }

        // Update heart rate statistics
        if (heartRate != null && heartRate > 0) {
            _hrSum += heartRate;
            _hrCount += 1;
            if (heartRate > _maxHr) {
                _maxHr = heartRate;
            }
        }

        // Calculate calories using MET formula:
        // cal/min = METs * 3.5 * weight_kg / 200
        var elapsedMin = elapsedMs / 60000.0;
        _calories = Constants.JUMP_ROPE_METS * Constants.CALORIES_CONSTANT
                    * _userWeight * elapsedMin / Constants.CALORIES_DIVISOR;

        // Update FIT fields while session is active
        _updateFitFields();
    }

    // Writes current metric values to the custom FIT fields.
    // Clamps totalJumps to UINT16 max (65535) to prevent FIT field overflow.
    hidden function _updateFitFields() {
        if (_jumpField != null) {
            var jumps = _totalJumps;
            if (jumps > 65535) {
                jumps = 65535;
            }
            _jumpField.setData(jumps);
        }
        if (_avgJpmField != null) {
            _avgJpmField.setData(_avgJpm);
        }
        if (_peakJpmField != null) {
            _peakJpmField.setData(_peakJpm);
        }
    }

    // Returns the elapsed active time in milliseconds, excluding paused
    // duration. Returns 0 if no session has been started.
    function getElapsedMs() {
        if (_startTime == 0) {
            return 0;
        }

        var now = Sys.getTimer();
        var elapsed = now - _startTime - _totalPausedMs;

        // If currently paused, subtract the ongoing pause duration
        if (_isPaused && _pauseTime > 0) {
            elapsed -= (now - _pauseTime);
        }

        // Clamp to non-negative
        if (elapsed < 0) {
            elapsed = 0;
        }

        return elapsed;
    }

    // Returns elapsed active time as a formatted "MM:SS" string
    // with zero-padded minutes and seconds.
    function getElapsedFormatted() {
        var totalSec = getElapsedMs() / 1000;
        var min = totalSec / 60;
        var sec = totalSec % 60;

        return Lang.format("$1$:$2$", [min.format("%02d"), sec.format("%02d")]);
    }

    // Returns the total jump count.
    function getTotalJumps() {
        return _totalJumps;
    }

    // Returns the average jumps per minute.
    function getAvgJpm() {
        return _avgJpm;
    }

    // Returns the peak jumps per minute.
    function getPeakJpm() {
        return _peakJpm;
    }

    // Returns estimated calories burned as an integer.
    function getCalories() {
        return _calories.toNumber();
    }

    // Returns the average heart rate, or 0 if no readings taken.
    function getAvgHr() {
        if (_hrCount > 0) {
            return (_hrSum / _hrCount).toNumber();
        }
        return 0;
    }

    // Returns the maximum heart rate recorded.
    function getMaxHr() {
        return _maxHr;
    }

    // Returns true if the session is actively recording.
    function isRecording() {
        return _isRecording;
    }

    // Returns true if the session is currently paused.
    function isPaused() {
        return _isPaused;
    }

    // Returns true if a session object exists (started but not yet saved/discarded).
    function hasSession() {
        return _session != null;
    }
}
