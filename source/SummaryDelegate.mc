// ==========================================================================
// SummaryDelegate.mc — Input delegate for the post-workout summary screen
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 2.0.0
//
// Handles user input on the paginated summary screen.
// UP/DOWN cycle through stat pages. START saves, BACK discards.
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Attention as Attention;
using Toybox.Application as App;

class SummaryDelegate extends Ui.BehaviorDelegate {

    // Reference to the SessionManager for save/discard operations
    var _sessionManager;

    // Reference to the SummaryView for page navigation
    var _summaryView;

    function initialize(sessionManager, summaryView) {
        BehaviorDelegate.initialize();
        _sessionManager = sessionManager;
        _summaryView = summaryView;
    }

    // Handles physical key presses.
    // KEY_ENTER (START) saves the session; KEY_ESC (BACK) discards.
    // KEY_UP / KEY_DOWN cycle pages.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();

        if (key == Ui.KEY_ENTER) {
            _exitToIdle();
            return true;
        }

        if (key == Ui.KEY_ESC) {
            _exitToIdle();
            return true;
        }

        if (key == Ui.KEY_UP) {
            _summaryView.prevPage();
            return true;
        }

        if (key == Ui.KEY_DOWN) {
            _summaryView.nextPage();
            return true;
        }

        return false;
    }

    // Behavior delegate: next page on DOWN/swipe-up
    function onNextPage() {
        _summaryView.nextPage();
        return true;
    }

    // Behavior delegate: previous page on UP/swipe-down
    function onPreviousPage() {
        _summaryView.prevPage();
        return true;
    }

    // Behavior delegate: back action exits
    function onBack() {
        _exitToIdle();
        return true;
    }

    // Exit summary back to idle screen. Session is already saved
    // from the pause menu, so just pop the view.
    hidden function _exitToIdle() {
        Sys.println("SummaryDelegate: Exiting to idle");
        App.getApp().appState = Constants.STATE_IDLE;
        Ui.popView(Ui.SLIDE_RIGHT);
    }

}
