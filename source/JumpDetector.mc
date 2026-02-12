// ==========================================================================
// JumpDetector.mc -- Core jump detection engine
// Target: Garmin Forerunner 235 (Connect IQ 1.3+)
// Author: JumpRope Team
// Version: 3.0.0
//
// Uses Sensor.Info accelerometer data (via enableSensorEvents callback)
// since registerSensorDataListener is NOT available on FR235.
//
// Detection: total acceleration magnitude threshold crossing with debounce.
// Orientation-independent — works regardless of wrist position.
// ==========================================================================

using Toybox.Sensor as Sensor;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;

class JumpDetector {

    var _jumpCount;
    var _jumpState;
    var _lastJumpTime;
    var _isActive;
    var _peakJpm;

    // Half-jump accumulator for 2.5x multiplier (5 half-jumps per reading)
    var _halfJumpAccum;

    // Debug counters
    var _sampleCount;
    var _accelAvailable;

    // Smoothing buffer
    var _smoothingBuffer;
    var _bufferIndex;
    var _bufferFilled;

    // Callback
    var _callback;

    // Thresholds
    var _jumpThreshold;
    var _debounceMs;

    // JPM tracking
    var _jumpTimestamps;
    var _timestampIndex;
    var _timestampCount;

    function initialize(callback) {
        _callback = callback;
        _jumpCount = 0;
        _jumpState = Constants.JUMP_STATE_GROUND;
        _lastJumpTime = 0;
        _isActive = false;
        _peakJpm = 0;
        _halfJumpAccum = 0;
        _sampleCount = 0;
        _accelAvailable = false;

        _smoothingBuffer = new [Constants.SMOOTHING_WINDOW_SIZE];
        for (var i = 0; i < Constants.SMOOTHING_WINDOW_SIZE; i++) {
            _smoothingBuffer[i] = 0;
        }
        _bufferIndex = 0;
        _bufferFilled = false;

        _jumpTimestamps = new [60];
        for (var i = 0; i < 60; i++) {
            _jumpTimestamps[i] = 0;
        }
        _timestampIndex = 0;
        _timestampCount = 0;

        var appRef = App.getApp();
        _jumpThreshold = _clampInt(
            appRef.getProperty("jumpThreshold"),
            1050, 3000, Constants.JUMP_THRESHOLD
        );
        _debounceMs = _clampInt(
            appRef.getProperty("debounceMs"),
            50, 500, Constants.DEBOUNCE_MS
        );
    }

    // start/stop just control the active flag.
    // Sensor registration is handled by MainView via enableSensorEvents.
    function start() {
        _isActive = true;
    }

    function stop() {
        _isActive = false;
    }

    // Called from MainView.onSensorInfo when accel data is available
    function processReading(x, y, z) {
        if (!_isActive) {
            return;
        }
        _sampleCount++;
        _accelAvailable = true;

        // Total acceleration magnitude squared (orientation-independent)
        var totalMagSq = x * x + y * y + z * z;

        // Insert into smoothing buffer
        _smoothingBuffer[_bufferIndex] = totalMagSq;
        _bufferIndex = (_bufferIndex + 1) % Constants.SMOOTHING_WINDOW_SIZE;
        if (_bufferIndex == 0) {
            _bufferFilled = true;
        }

        // Rolling average
        var count = _bufferFilled
            ? Constants.SMOOTHING_WINDOW_SIZE
            : _bufferIndex;
        if (count == 0) { count = 1; }

        var sum = 0;
        for (var i = 0; i < count; i++) {
            sum += _smoothingBuffer[i];
        }
        var smoothed = sum / count;

        // Simple threshold detection — no state machine needed at ~1Hz.
        // Every above-threshold reading counts as JUMPS_PER_SAMPLE jumps.
        var threshSq = _jumpThreshold * _jumpThreshold;
        var now = Sys.getTimer();

        if (smoothed > threshSq && (now - _lastJumpTime) > _debounceMs) {
            // Accumulate 5 half-jumps (= 2.5 jumps) per reading.
            // Integer division by 2 gives alternating +2, +3 pattern.
            _halfJumpAccum = _halfJumpAccum + 5;
            var newTotal = _halfJumpAccum / 2;
            var jumpsAdded = newTotal - _jumpCount;
            _jumpCount = newTotal;
            _lastJumpTime = now;
            for (var j = 0; j < jumpsAdded; j++) {
                _recordJumpTimestamp(now);
            }
            if (_callback != null) {
                _callback.invoke(_jumpCount);
            }
        }
    }

    function getJumpCount() {
        return _jumpCount;
    }

    function getJumpsPerMinute() {
        var now = Sys.getTimer();
        var windowStart = now - Constants.JPM_MOVING_WINDOW_MS;
        var recentJumps = 0;
        for (var i = 0; i < _timestampCount; i++) {
            if (_jumpTimestamps[i] >= windowStart) {
                recentJumps++;
            }
        }
        var jpm = (recentJumps * 60000) / Constants.JPM_MOVING_WINDOW_MS;
        if (jpm > Constants.MAX_JPM) { jpm = Constants.MAX_JPM; }
        if (jpm < Constants.MIN_JPM) { jpm = 0; }
        if (jpm > _peakJpm) { _peakJpm = jpm; }
        return jpm;
    }

    function getPeakJpm() {
        return _peakJpm;
    }

    function getSampleCount() {
        return _sampleCount;
    }

    function isAccelAvailable() {
        return _accelAvailable;
    }

    function reset() {
        _jumpCount = 0;
        _jumpState = Constants.JUMP_STATE_GROUND;
        _lastJumpTime = 0;
        _halfJumpAccum = 0;
        _sampleCount = 0;
        _accelAvailable = false;

        for (var i = 0; i < Constants.SMOOTHING_WINDOW_SIZE; i++) {
            _smoothingBuffer[i] = 0;
        }
        _bufferIndex = 0;
        _bufferFilled = false;

        for (var i = 0; i < 60; i++) {
            _jumpTimestamps[i] = 0;
        }
        _timestampIndex = 0;
        _timestampCount = 0;
        _peakJpm = 0;
    }

    function isActive() {
        return _isActive;
    }

    function _recordJumpTimestamp(timestamp) {
        _jumpTimestamps[_timestampIndex] = timestamp;
        _timestampIndex = (_timestampIndex + 1) % 60;
        if (_timestampCount < 60) {
            _timestampCount++;
        }
    }

    function _clampInt(value, min, max, defaultVal) {
        if (value == null || !(value instanceof Lang.Number)) {
            return defaultVal;
        }
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }
}
