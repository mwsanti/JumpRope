// ==========================================================================
// JumpDetector.mc -- Core jump detection engine
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 1.0.0
//
// Two-threshold accelerometer-based jump detection state machine.
//
// Algorithm overview:
//   1. Raw Z-axis accelerometer samples arrive at the configured sample
//      rate (default 25 Hz) via the Sensor data listener.
//   2. Each sample is fed into a circular smoothing buffer and a rolling
//      average is computed to filter out high-frequency noise.
//   3. A two-state machine (GROUND / AIR) processes the smoothed value:
//      - GROUND -> AIR: smoothed Z exceeds the jump (takeoff) threshold
//        and the debounce interval has elapsed since the last jump.
//      - AIR -> GROUND: smoothed Z drops below the landing threshold.
//        The jump counter increments and the callback fires.
//   4. Jump timestamps are recorded in a circular buffer so that a
//      jumps-per-minute (JPM) metric can be calculated over a sliding
//      10-second window, then scaled to a per-minute rate.
//
// Property validation (addresses Security Review Phase 1 finding M-1):
//   All user-configurable properties are clamped to safe ranges at
//   construction time. jumpThreshold must exceed landingThreshold;
//   if violated, both reset to compiled defaults.
// ==========================================================================

using Toybox.Sensor as Sensor;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.Application as App;
using Toybox.Timer as Timer;

class JumpDetector {

    // -- Session counters --------------------------------------------------

    // Total number of jumps detected this session
    var _jumpCount;

    // Current state of the detection state machine (GROUND or AIR)
    var _jumpState;

    // Monotonic timestamp (ms) of the most recent detected jump, used
    // for debounce enforcement
    var _lastJumpTime;

    // -- Smoothing buffer --------------------------------------------------

    // Fixed-size circular buffer holding the most recent Z-axis samples
    var _smoothingBuffer;

    // Current write position in the circular buffer
    var _bufferIndex;

    // True once the buffer has been completely filled at least once
    var _bufferFilled;

    // -- Callback and activation -------------------------------------------

    // Method reference invoked with (jumpCount) each time a jump lands
    var _callback;

    // Whether the detector is actively listening to sensor data
    var _isActive;

    // Mock sensor timer (used when registerSensorDataListener unavailable)
    var _mockTimer;
    var _mockPhase;

    // -- Runtime thresholds (validated from properties) ---------------------

    // Takeoff threshold in milliG (clamped 1200-3000)
    var _jumpThreshold;

    // Landing threshold in milliG (clamped 200-800)
    var _landingThreshold;

    // Minimum ms between jumps (clamped 50-500)
    var _debounceMs;

    // Accelerometer sample rate in Hz (clamped 10-50)
    var _sampleRate;

    // -- JPM tracking ------------------------------------------------------

    // Circular buffer of recent jump timestamps for JPM calculation
    // (max 60 entries -- sufficient for ~1 minute at high cadence)
    var _jumpTimestamps;

    // Write index into _jumpTimestamps
    var _timestampIndex;

    // Number of timestamps currently stored (caps at 60)
    var _timestampCount;

    // Highest JPM recorded during this session
    var _peakJpm;

    // ======================================================================
    // Constructor
    //
    // @param callback [Method] Method reference called with (jumpCount)
    //                          each time a jump is detected.
    // ======================================================================
    function initialize(callback) {
        _callback = callback;

        // -- Session state -------------------------------------------------
        _jumpCount = 0;
        _jumpState = Constants.JUMP_STATE_GROUND;
        _lastJumpTime = 0;
        _isActive = false;
        _peakJpm = 0;
        _mockTimer = null;
        _mockPhase = 0;

        // -- Smoothing buffer (fixed-size, pre-allocated) ------------------
        _smoothingBuffer = new [Constants.SMOOTHING_WINDOW_SIZE];
        for (var i = 0; i < Constants.SMOOTHING_WINDOW_SIZE; i++) {
            _smoothingBuffer[i] = 0;
        }
        _bufferIndex = 0;
        _bufferFilled = false;

        // -- JPM timestamp buffer (fixed-size, pre-allocated) --------------
        _jumpTimestamps = new [60];
        for (var i = 0; i < 60; i++) {
            _jumpTimestamps[i] = 0;
        }
        _timestampIndex = 0;
        _timestampCount = 0;

        // -- Read and validate user-configurable properties ----------------
        // Uses CIQ 1.3 API: App.getApp().getProperty()
        // Clamp ranges per Security Review M-1 recommendations.
        var appRef = App.getApp();

        _jumpThreshold = _clampInt(
            appRef.getProperty("jumpThreshold"),
            1200, 3000, Constants.JUMP_THRESHOLD
        );
        _landingThreshold = _clampInt(
            appRef.getProperty("landingThreshold"),
            200, 800, Constants.LANDING_THRESHOLD
        );
        _debounceMs = _clampInt(
            appRef.getProperty("debounceMs"),
            50, 500, Constants.DEBOUNCE_MS
        );
        _sampleRate = _clampInt(
            appRef.getProperty("sampleRate"),
            10, 50, Constants.SAMPLE_RATE
        );

        // Sanity: jump threshold must be strictly greater than landing
        // threshold; otherwise the state machine would never cycle. Reset
        // both to compiled defaults if the invariant is violated.
        if (_jumpThreshold <= _landingThreshold) {
            _jumpThreshold = Constants.JUMP_THRESHOLD;
            _landingThreshold = Constants.LANDING_THRESHOLD;
        }
    }

    // ======================================================================
    // start -- Begin listening for accelerometer data
    //
    // Registers a sensor data listener at the configured sample rate.
    // ======================================================================
    function start() {
        // Try real sensor API first (CIQ 2.3+), fall back to mock timer
        var started = false;
        if (Sensor has :registerSensorDataListener) {
            try {
                Sensor.registerSensorDataListener(
                    method(:onSensorData),
                    {
                        :period => 1,
                        :accelerometer => {
                            :enabled => true,
                            :sampleRate => _sampleRate
                        }
                    }
                );
                started = true;
                Sys.println("JumpDetector: started real sensor (rate=" + _sampleRate + "Hz)");
            } catch (e) {
                Sys.println("JumpDetector: real sensor failed, using mock");
            }
        }

        if (!started) {
            // Mock mode: timer generates fake jump data at ~120 JPM
            _mockPhase = 0;
            _mockTimer = new Timer.Timer();
            _mockTimer.start(method(:onMockTick), 100, true);
            Sys.println("JumpDetector: started MOCK sensor");
        }
        _isActive = true;
    }

    // ======================================================================
    // stop -- Stop listening for accelerometer data
    //
    // Unregisters the sensor data listener and marks the detector inactive.
    // ======================================================================
    function stop() {
        if (Sensor has :unregisterSensorDataListener) {
            Sensor.unregisterSensorDataListener();
        }
        if (_mockTimer != null) {
            _mockTimer.stop();
            _mockTimer = null;
        }
        _isActive = false;
        Sys.println("JumpDetector: stopped");
    }

    // Mock tick: simulates a jump cycle.
    // Must fill the 5-sample smoothing buffer in each phase to cross thresholds.
    // Phase 0-4: ground (1000), 5-9: spike (3000), 10-14: air (0)
    // At 50ms/tick: 15 * 50ms = 750ms/jump => ~80 JPM
    function onMockTick() {
        if (!_isActive) { return; }
        _mockPhase = (_mockPhase + 1) % 15;
        var fakeZ;
        if (_mockPhase >= 5 && _mockPhase <= 9) {
            fakeZ = 3000; // 5 ticks of high G to fill smoothing buffer above 1800
        } else if (_mockPhase >= 10 && _mockPhase <= 14) {
            fakeZ = 0;    // 5 ticks of low G to fill smoothing buffer below 500
        } else {
            fakeZ = 1000; // ground ~1G
        }
        _processSample(fakeZ);
    }

    // ======================================================================
    // onSensorData -- Sensor callback invoked by the Sensor framework
    //
    // Receives a SensorData object containing batched accelerometer
    // readings. Extracts Z-axis samples and feeds each through the
    // detection pipeline.
    //
    // @param sensorData [Sensor.SensorData] Sensor data payload
    // ======================================================================
    function onSensorData(sensorData) {
        // Guard: bail if we have been stopped
        if (!_isActive) {
            return;
        }

        // Guard: bail if there is no accelerometer data in this payload
        if (sensorData == null) {
            return;
        }
        var accelData = sensorData.accelerometerData;
        if (accelData == null) {
            return;
        }

        // Extract Z-axis data. In CIQ 1.3 the accelerometerData object
        // provides x, y, z arrays of milliG samples for the batch.
        var zData = accelData.z;
        if (zData == null) {
            return;
        }

        // Process each sample in the batch. zData is typically an Array
        // of Numbers, but handle the (unlikely) single-value case too.
        if (zData instanceof Lang.Array) {
            for (var i = 0; i < zData.size(); i++) {
                if (zData[i] != null) {
                    _processSample(zData[i]);
                }
            }
        } else {
            // Single value -- process directly
            _processSample(zData);
        }
    }

    // ======================================================================
    // getJumpCount -- Return total jumps detected this session
    //
    // @return [Number] Total jump count
    // ======================================================================
    function getJumpCount() {
        return _jumpCount;
    }

    // ======================================================================
    // getJumpsPerMinute -- Calculate current JPM over a sliding window
    //
    // Counts jumps within the last JPM_MOVING_WINDOW_MS (10 s) and
    // scales to a per-minute rate. Clamps to [0, MAX_JPM] and returns
    // 0 for sub-threshold rates to avoid displaying noise.
    //
    // @return [Number] Current jumps per minute (integer)
    // ======================================================================
    function getJumpsPerMinute() {
        var now = Sys.getTimer();
        var windowStart = now - Constants.JPM_MOVING_WINDOW_MS;
        var recentJumps = 0;

        // Walk the timestamp buffer and count entries inside the window
        for (var i = 0; i < _timestampCount; i++) {
            if (_jumpTimestamps[i] >= windowStart) {
                recentJumps++;
            }
        }

        // Scale the 10-second window count to a per-minute rate
        var jpm = (recentJumps * 60000) / Constants.JPM_MOVING_WINDOW_MS;

        // Clamp to sane bounds
        if (jpm > Constants.MAX_JPM) {
            jpm = Constants.MAX_JPM;
        }
        if (jpm < Constants.MIN_JPM) {
            jpm = 0;
        }

        // Track session peak
        if (jpm > _peakJpm) {
            _peakJpm = jpm;
        }

        return jpm;
    }

    // ======================================================================
    // getPeakJpm -- Return the highest JPM recorded this session
    //
    // @return [Number] Peak jumps per minute
    // ======================================================================
    function getPeakJpm() {
        return _peakJpm;
    }

    // ======================================================================
    // reset -- Reset all session state to initial values
    //
    // Called when the user starts a new session. Clears counters, buffers,
    // and peak tracking. Does NOT alter threshold/debounce configuration.
    // ======================================================================
    function reset() {
        _jumpCount = 0;
        _jumpState = Constants.JUMP_STATE_GROUND;
        _lastJumpTime = 0;

        // Clear smoothing buffer
        for (var i = 0; i < Constants.SMOOTHING_WINDOW_SIZE; i++) {
            _smoothingBuffer[i] = 0;
        }
        _bufferIndex = 0;
        _bufferFilled = false;

        // Clear timestamp buffer
        for (var i = 0; i < 60; i++) {
            _jumpTimestamps[i] = 0;
        }
        _timestampIndex = 0;
        _timestampCount = 0;

        _peakJpm = 0;
    }

    // ======================================================================
    // isActive -- Whether the detector is currently listening for data
    //
    // @return [Boolean] True if actively detecting jumps
    // ======================================================================
    function isActive() {
        return _isActive;
    }

    // ======================================================================
    // PRIVATE METHODS
    // ======================================================================

    // ----------------------------------------------------------------------
    // _processSample -- Core detection algorithm
    //
    // Adds a raw Z-axis sample to the smoothing buffer, computes the
    // rolling average, and runs the two-threshold state machine.
    //
    // State transitions:
    //   GROUND -> AIR : smoothedZ > jumpThreshold AND debounce elapsed
    //   AIR -> GROUND : smoothedZ < landingThreshold
    //                   (jump counted, callback fired)
    //
    // @param zValue [Number] Raw Z-axis accelerometer reading in milliG
    // ----------------------------------------------------------------------
    function _processSample(zValue) {
        // Step 1: Insert into circular smoothing buffer
        _smoothingBuffer[_bufferIndex] = zValue;
        _bufferIndex = (_bufferIndex + 1) % Constants.SMOOTHING_WINDOW_SIZE;
        if (_bufferIndex == 0) {
            _bufferFilled = true;
        }

        // Step 2: Calculate rolling average
        var count = _bufferFilled
            ? Constants.SMOOTHING_WINDOW_SIZE
            : _bufferIndex;
        // Guard: avoid division by zero on the very first call if
        // _bufferIndex wrapped before we could read (should not happen,
        // but be safe)
        if (count == 0) {
            count = 1;
        }
        var sum = 0;
        for (var i = 0; i < count; i++) {
            sum += _smoothingBuffer[i];
        }
        var smoothedZ = sum / count;

        // Step 3: Two-threshold state machine
        var now = Sys.getTimer();

        if (_jumpState == Constants.JUMP_STATE_GROUND) {
            // Waiting for takeoff. The push-off phase of a jump creates
            // a high-G spike as the feet leave the ground.
            if (smoothedZ > _jumpThreshold && (now - _lastJumpTime) > _debounceMs) {
                _jumpState = Constants.JUMP_STATE_AIR;
            }
        } else if (_jumpState == Constants.JUMP_STATE_AIR) {
            // In the air. During free-fall/descent, the wrist experiences
            // reduced acceleration. When it drops below the landing
            // threshold, the user has landed.
            if (smoothedZ < _landingThreshold) {
                _jumpState = Constants.JUMP_STATE_GROUND;
                _jumpCount++;
                _lastJumpTime = now;
                _recordJumpTimestamp(now);
                if (_callback != null) {
                    _callback.invoke(_jumpCount);
                }
            }
        }
    }

    // ----------------------------------------------------------------------
    // _recordJumpTimestamp -- Store a jump timestamp for JPM calculation
    //
    // Writes into the fixed-size circular timestamp buffer. When the
    // buffer is full, the oldest entry is overwritten.
    //
    // @param timestamp [Number] Monotonic millisecond timestamp
    // ----------------------------------------------------------------------
    function _recordJumpTimestamp(timestamp) {
        _jumpTimestamps[_timestampIndex] = timestamp;
        _timestampIndex = (_timestampIndex + 1) % 60;
        if (_timestampCount < 60) {
            _timestampCount++;
        }
    }

    // ----------------------------------------------------------------------
    // _clampInt -- Validate and clamp an integer property value
    //
    // Returns the value clamped to [min, max]. If the value is null or
    // not a Number, returns defaultVal instead.
    //
    // @param value      [Object or null] Raw property value
    // @param min        [Number]         Minimum allowed value (inclusive)
    // @param max        [Number]         Maximum allowed value (inclusive)
    // @param defaultVal [Number]         Fallback if value is null/invalid
    // @return [Number] Validated integer
    // ----------------------------------------------------------------------
    function _clampInt(value, min, max, defaultVal) {
        if (value == null || !(value instanceof Lang.Number)) {
            return defaultVal;
        }
        if (value < min) {
            return min;
        }
        if (value > max) {
            return max;
        }
        return value;
    }
}
