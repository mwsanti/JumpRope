// ==========================================================================
// MainView.mc -- Primary workout screen view
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 1.0.0
//
// Displays real-time jump rope workout metrics: jump count, elapsed timer,
// jumps per minute (JPM), and heart rate. Manages the lifecycle of the
// JumpDetector (accelerometer-based jump detection) and SessionManager
// (FIT activity recording). Called by MainDelegate for state transitions
// (start, pause, resume, stop).
//
// Layout element IDs from MainLayout.xml:
//   StatusLabel  -- recording/paused indicator (top)
//   JumpCount    -- large centered jump count number
//   TimerLabel   -- MM:SS elapsed time
//   JPMValue     -- current jumps per minute
//   HRValue      -- current heart rate BPM
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Timer as Timer;
using Toybox.Sensor as Sensor;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Attention as Attention;

class MainView extends Ui.View {

    // -- Instance variables ------------------------------------------------

    // JumpDetector instance -- accelerometer jump detection engine
    var _jumpDetector;

    // SessionManager instance -- FIT recording and metrics
    var _sessionManager;

    // Timer.Timer for periodic 1-second UI refresh
    var _updateTimer;

    // Latest heart rate reading from sensor (Number or null)
    var _currentHR;

    // Current app state (mirrors JumpRopeApp.appState)
    var _appState;

    // Milestone vibration interval (0 = disabled, from properties)
    var _milestoneInterval;

    // Countdown timer target in seconds (0 = count up mode, from properties)
    var _countdownSeconds;

    // Whether the countdown timer has already expired this session
    var _countdownExpired;

    // ======================================================================
    // Constructor
    //
    // Initializes the view with fresh JumpDetector and SessionManager
    // instances. Timer and heart rate are null/default until onShow().
    // ======================================================================
    function initialize() {
        View.initialize();
        _jumpDetector = new JumpDetector(method(:onJumpDetected));
        _sessionManager = new SessionManager();
        _updateTimer = null;
        _currentHR = null;
        _appState = Constants.STATE_IDLE;

        // Read milestone interval from properties (0 = disabled, clamp 0-1000)
        var mi = App.getApp().getProperty("milestoneInterval");
        if (mi == null || !(mi instanceof Lang.Number)) {
            mi = Constants.MILESTONE_INTERVAL;
        }
        if (mi < 0) { mi = 0; }
        if (mi > 1000) { mi = 1000; }
        _milestoneInterval = mi;

        // Read countdown seconds from properties (0 = count up, clamp 0-3600)
        var cd = App.getApp().getProperty("countdownSeconds");
        if (cd == null || !(cd instanceof Lang.Number)) {
            cd = 0;
        }
        if (cd < 0) { cd = 0; }
        if (cd > Constants.MAX_COUNTDOWN_SECONDS) { cd = Constants.MAX_COUNTDOWN_SECONDS; }
        _countdownSeconds = cd;
        _countdownExpired = false;
    }

    // ======================================================================
    // onLayout -- Inflate the XML layout
    //
    // Called by the framework when the view needs its layout. Inflates
    // MainLayout.xml so elements are available via findDrawableById().
    //
    // @param dc [Gfx.Dc] Device context for layout inflation
    // ======================================================================
    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    // ======================================================================
    // onShow -- View is becoming visible
    //
    // Enables heart rate sensor, registers sensor event callback, and
    // starts the 1-second UI update timer. Restarts jump detection if
    // the app state is RECORDING but the detector was stopped (e.g.
    // after returning from another view).
    // ======================================================================
    function onShow() {
        // Sync local state from global app state (may have changed while
        // this view was hidden, e.g. after returning from SummaryView)
        _appState = App.getApp().appState;

        // Enable heart rate sensor
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensorInfo));

        // Start periodic 1-second UI refresh timer
        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onTimerTick), Constants.TIMER_UPDATE_MS, true);

        // If we are recording but detector got stopped (e.g. view was
        // hidden and re-shown), restart the detector
        if (_appState == Constants.STATE_RECORDING && !_jumpDetector.isActive()) {
            _jumpDetector.start();
        }
    }

    // ======================================================================
    // onHide -- View is no longer visible
    //
    // Stops the update timer to prevent leaks, stops the jump detector
    // if active, and disables sensor events.
    // ======================================================================
    function onHide() {
        // Stop the update timer
        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }

        // Stop jump detector if active
        if (_jumpDetector.isActive()) {
            _jumpDetector.stop();
        }

        // Disable sensor events
        Sensor.enableSensorEvents(null);
    }

    // ======================================================================
    // onUpdate -- Render the view
    //
    // Draws the base layout then updates all dynamic labels with current
    // state: status indicator, jump count, timer, JPM, and heart rate.
    // All findDrawableById() results are null-checked before use.
    //
    // @param dc [Gfx.Dc] Device context for rendering
    // ======================================================================
    function onUpdate(dc) {
        // Draw the base layout (labels, background, etc.)
        View.onUpdate(dc);

        // -- StatusLabel: recording state indicator --
        var statusLabel = findDrawableById("StatusLabel");
        if (statusLabel != null) {
            if (_appState == Constants.STATE_RECORDING) {
                statusLabel.setText("RECORDING");
                statusLabel.setColor(Constants.COLOR_RECORDING);
            } else if (_appState == Constants.STATE_PAUSED) {
                statusLabel.setText("PAUSED");
                statusLabel.setColor(Constants.COLOR_PAUSED);
            } else {
                statusLabel.setText("PRESS START");
                statusLabel.setColor(Constants.COLOR_TEXT_SECONDARY);
            }
        }

        // -- JumpCount: total jumps detected --
        var jumpCountLabel = findDrawableById("JumpCount");
        if (jumpCountLabel != null) {
            jumpCountLabel.setText(_jumpDetector.getJumpCount().toString());
        }

        // -- TimerLabel: elapsed time or countdown remaining MM:SS --
        var timerLabel = findDrawableById("TimerLabel");
        if (timerLabel != null) {
            if (_countdownSeconds > 0) {
                // Countdown mode: show remaining time
                var elapsedMs = _sessionManager.getElapsedMs();
                var remaining = _countdownSeconds - (elapsedMs / 1000);
                if (remaining < 0) { remaining = 0; }
                var remainInt = remaining.toNumber();
                var mins = remainInt / 60;
                var secs = remainInt % 60;
                var timeStr = mins.format("%02d") + ":" + secs.format("%02d");
                timerLabel.setText(timeStr);
                if (_countdownExpired) {
                    timerLabel.setColor(Constants.COLOR_STOPPED);
                }
            } else {
                // Count-up mode: show elapsed time
                timerLabel.setText(_sessionManager.getElapsedFormatted());
            }
        }

        // -- JPMValue: current jumps per minute --
        var jpmValue = findDrawableById("JPMValue");
        if (jpmValue != null) {
            jpmValue.setText(_jumpDetector.getJumpsPerMinute().toString());
        }

        // -- HRValue: current heart rate --
        var hrValue = findDrawableById("HRValue");
        if (hrValue != null) {
            if (_currentHR != null) {
                hrValue.setText(_currentHR.toString());
            } else {
                hrValue.setText("--");
            }
        }
    }

    // ======================================================================
    // onJumpDetected -- Callback from JumpDetector
    //
    // Invoked each time a jump is detected. Requests an immediate UI
    // update so the jump count display is responsive.
    //
    // @param jumpCount [Number] Total jumps detected so far
    // ======================================================================
    function onJumpDetected(jumpCount) {
        // Vibrate at milestone intervals (e.g. every 100 jumps)
        if (_milestoneInterval > 0 && jumpCount > 0 && jumpCount % _milestoneInterval == 0) {
            try {
                Attention.vibrate([new Attention.VibeProfile(Constants.MILESTONE_VIBE_DUTY, Constants.MILESTONE_VIBE_DURATION)]);
            } catch (e) {
                // Attention API may not be available on all devices
            }
        }
        Ui.requestUpdate();
    }

    // ======================================================================
    // onSensorInfo -- Callback from Sensor.enableSensorEvents
    //
    // Updates the cached heart rate value from the sensor payload.
    //
    // @param sensorInfo [Sensor.Info] Sensor data (may be null)
    // ======================================================================
    function onSensorInfo(sensorInfo) {
        if (sensorInfo != null && sensorInfo.heartRate != null) {
            _currentHR = sensorInfo.heartRate;
        } else {
            _currentHR = null;
        }
    }

    // ======================================================================
    // onTimerTick -- Callback from Timer.Timer (every 1 second)
    //
    // When recording, updates the SessionManager with current metrics
    // from the JumpDetector and heart rate sensor. Always requests a
    // UI refresh to keep the timer display current.
    // ======================================================================
    function onTimerTick() {
        if (_appState == Constants.STATE_RECORDING) {
            _sessionManager.updateMetrics(
                _jumpDetector.getJumpCount(),
                _jumpDetector.getJumpsPerMinute(),
                _jumpDetector.getPeakJpm(),
                _currentHR
            );

            // Check countdown expiry
            if (_countdownSeconds > 0 && !_countdownExpired) {
                var elapsedMs = _sessionManager.getElapsedMs();
                var remaining = _countdownSeconds - (elapsedMs / 1000);
                if (remaining <= 0) {
                    _countdownExpired = true;
                    try {
                        Attention.vibrate([new Attention.VibeProfile(Constants.COUNTDOWN_VIBE_DUTY, Constants.COUNTDOWN_VIBE_DURATION)]);
                    } catch (e) {
                        // Attention API may not be available on all devices
                    }
                    pauseRecording();
                }
            }
        }
        Ui.requestUpdate();
    }

    // ======================================================================
    // PUBLIC METHODS -- Called by MainDelegate for state transitions
    // ======================================================================

    // ----------------------------------------------------------------------
    // startRecording -- Begin a new jump rope session
    //
    // Resets and starts the jump detector, starts a new FIT recording
    // session, and transitions the app to RECORDING state.
    // ----------------------------------------------------------------------
    function startRecording() {
        _jumpDetector.reset();
        _jumpDetector.start();
        _sessionManager.startSession();
        _countdownExpired = false;
        _appState = Constants.STATE_RECORDING;
        App.getApp().appState = Constants.STATE_RECORDING;
        Ui.requestUpdate();
    }

    // ----------------------------------------------------------------------
    // pauseRecording -- Pause the current session
    //
    // Stops jump detection and pauses the FIT recording. Timer display
    // freezes. Transitions to PAUSED state.
    // ----------------------------------------------------------------------
    function pauseRecording() {
        _jumpDetector.stop();
        _sessionManager.pauseSession();
        _appState = Constants.STATE_PAUSED;
        App.getApp().appState = Constants.STATE_PAUSED;
        Ui.requestUpdate();
    }

    // ----------------------------------------------------------------------
    // resumeRecording -- Resume from paused state
    //
    // Restarts jump detection and resumes FIT recording. Transitions
    // back to RECORDING state.
    // ----------------------------------------------------------------------
    function resumeRecording() {
        _jumpDetector.start();
        _sessionManager.resumeSession();
        _appState = Constants.STATE_RECORDING;
        App.getApp().appState = Constants.STATE_RECORDING;
        Ui.requestUpdate();
    }

    // ----------------------------------------------------------------------
    // stopAndShowSummary -- End session and show summary screen
    //
    // Stops jump detection and FIT recording, transitions to SUMMARY
    // state, and pushes the SummaryView onto the view stack.
    // ----------------------------------------------------------------------
    function stopAndShowSummary() {
        _jumpDetector.stop();
        _sessionManager.stopSession();
        _appState = Constants.STATE_SUMMARY;
        App.getApp().appState = Constants.STATE_SUMMARY;
        Ui.pushView(
            new SummaryView(_sessionManager),
            new SummaryDelegate(_sessionManager),
            Ui.SLIDE_LEFT
        );
    }

    // ----------------------------------------------------------------------
    // getAppState -- Return the current app state
    //
    // @return [Number] One of Constants.STATE_IDLE/RECORDING/PAUSED/SUMMARY
    // ----------------------------------------------------------------------
    function getAppState() {
        return _appState;
    }

    // ----------------------------------------------------------------------
    // getSessionManager -- Return the SessionManager instance
    //
    // Used by MainDelegate or other components that need session access.
    //
    // @return [SessionManager] The session manager
    // ----------------------------------------------------------------------
    function getSessionManager() {
        return _sessionManager;
    }
}
