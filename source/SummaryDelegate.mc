// ==========================================================================
// SummaryDelegate.mc — Input delegate for the post-workout summary screen
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 1.0.0
//
// Handles user input on the summary screen. START button saves the FIT
// session; BACK button discards it. Both return the user to the main view.
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Attention as Attention;
using Toybox.Application as App;

class SummaryDelegate extends Ui.BehaviorDelegate {

    // Reference to the SessionManager for save/discard operations
    var _sessionManager;

    // Stores the SessionManager reference for session lifecycle control.
    function initialize(sessionManager) {
        BehaviorDelegate.initialize();
        _sessionManager = sessionManager;
    }

    // Handles physical key presses.
    // KEY_ENTER (START) saves the session; KEY_ESC (BACK) discards it.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();

        if (key == Ui.KEY_ENTER) {
            // SAVE the workout session
            _saveAndExit();
            return true;
        }

        if (key == Ui.KEY_ESC) {
            // DISCARD the workout session
            _discardAndExit();
            return true;
        }

        return false;
    }

    // Handles the behavior delegate back action (swipe or BACK button).
    // Discards the session and returns to the main view.
    function onBack() {
        _discardAndExit();
        return true;
    }

    // Saves the FIT session, provides haptic feedback, pops the view,
    // and resets the app state to idle.
    hidden function _saveAndExit() {
        _sessionManager.saveSession();
        Sys.println("SummaryDelegate: Session saved");

        // Haptic feedback — Attention may not be available on all devices
        try {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        } catch (e) {
            // Attention not available, skip vibration
        }

        // Reset state BEFORE popView so MainView.onShow() sees STATE_IDLE
        App.getApp().appState = Constants.STATE_IDLE;
        Ui.popView(Ui.SLIDE_RIGHT);
    }

    // Discards the FIT session, pops the view, and resets the app
    // state to idle.
    hidden function _discardAndExit() {
        _sessionManager.discardSession();
        Sys.println("SummaryDelegate: Session discarded");

        // Reset state BEFORE popView so MainView.onShow() sees STATE_IDLE
        App.getApp().appState = Constants.STATE_IDLE;
        Ui.popView(Ui.SLIDE_RIGHT);
    }

}
