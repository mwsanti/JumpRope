//
// MainDelegate.mc
//
// Input delegate for the main workout screen. Handles physical
// button presses to control the workout state machine: start,
// pause, resume, and stop recording. Routes input events to
// MainView methods — no business logic lives here.
//
// Button mapping (Forerunner 235):
//   START/STOP (top-right) = KEY_ENTER  → start/pause/resume
//   BACK/LAP  (bottom-right) = KEY_ESC → stop workout / exit app
//
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
//

using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Attention as Attention;

class MainDelegate extends Ui.BehaviorDelegate {

    // Reference to the MainView instance for calling recording methods
    var _view;

    //
    // Constructor. Stores a reference to the MainView so we can
    // call startRecording, pauseRecording, etc. on button press.
    //
    // @param view [MainView] The main workout view instance
    //
    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    //
    // Handle physical key press events. Routes KEY_ENTER and KEY_ESC
    // to the appropriate MainView method based on the current app state.
    //
    // @param keyEvent [KeyEvent] The key event from the system
    // @return [Boolean] true if the event was consumed, false to pass through
    //
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        var state = App.getApp().appState;

        if (key == Ui.KEY_ENTER) {
            // START button: start or pause+menu
            if (state == Constants.STATE_IDLE) {
                Sys.println("MainDelegate: START pressed — IDLE -> RECORDING");
                // Tone + vibrate on start
                try {
                    Attention.playTone(Attention.TONE_KEY);
                    Attention.vibrate([new Attention.VibeProfile(50, 200)]);
                } catch (e) {
                    // Attention API may not be available
                }
                _view.startRecording();
                return true;
            } else if (state == Constants.STATE_RECORDING) {
                Sys.println("MainDelegate: START pressed — RECORDING -> PAUSE MENU");
                // Tone only on pause
                try {
                    Attention.playTone(Attention.TONE_KEY);
                } catch (e) {
                    // Attention API may not be available
                }
                _view.pauseAndShowMenu();
                return true;
            }
            return false;
        }

        if (key == Ui.KEY_ESC) {
            // BACK button: stop workout or exit app
            if (state == Constants.STATE_RECORDING || state == Constants.STATE_PAUSED) {
                Sys.println("MainDelegate: BACK pressed — stopping workout");
                _view.stopAndShowSummary();
                return true;
            }
            // IDLE state: return false to let system handle (exits app)
            return false;
        }

        // All other keys: pass through to system
        return false;
    }

    //
    // Behavior delegate back handler. Called by the system for the
    // back action (swipe or button). Same logic as KEY_ESC handling.
    //
    // @return [Boolean] true if consumed, false to let system exit app
    //
    function onBack() {
        var state = App.getApp().appState;
        if (state == Constants.STATE_RECORDING || state == Constants.STATE_PAUSED) {
            Sys.println("MainDelegate: onBack — stopping workout");
            _view.stopAndShowSummary();
            return true;
        }
        // IDLE state: return false to exit the app
        return false;
    }

}
