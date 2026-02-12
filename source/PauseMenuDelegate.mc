// ==========================================================================
// PauseMenuDelegate.mc — Input delegate for the pause menu screen
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
//
// UP/DOWN navigate menu items. START (KEY_ENTER) selects the highlighted
// option: Resume, Save, or Discard.
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class PauseMenuDelegate extends Ui.BehaviorDelegate {

    var _menuView;
    var _mainView;

    function initialize(menuView, mainView) {
        BehaviorDelegate.initialize();
        _menuView = menuView;
        _mainView = mainView;
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();

        if (key == Ui.KEY_UP) {
            _menuView.moveUp();
            return true;
        }

        if (key == Ui.KEY_DOWN) {
            _menuView.moveDown();
            return true;
        }

        if (key == Ui.KEY_ENTER) {
            var index = _menuView.getSelectedIndex();
            if (index == 0) {
                // Resume
                Sys.println("PauseMenu: Resume selected");
                Ui.popView(Ui.SLIDE_RIGHT);
                _mainView.resumeRecording();
            } else if (index == 1) {
                // Save — save session immediately, then show read-only summary
                Sys.println("PauseMenu: Save selected");
                Ui.popView(Ui.SLIDE_RIGHT);
                _mainView.saveAndShowSummary();
            } else if (index == 2) {
                // Discard — pop pause menu, discard data, reset to idle
                Sys.println("PauseMenu: Discard selected");
                Ui.popView(Ui.SLIDE_RIGHT);
                _mainView.discardAndReset();
            }
            return true;
        }

        if (key == Ui.KEY_ESC) {
            // Back button acts as Resume
            Sys.println("PauseMenu: Back pressed — resuming");
            Ui.popView(Ui.SLIDE_RIGHT);
            _mainView.resumeRecording();
            return true;
        }

        return false;
    }

    function onBack() {
        // Back gesture acts as Resume
        Sys.println("PauseMenu: onBack — resuming");
        Ui.popView(Ui.SLIDE_RIGHT);
        _mainView.resumeRecording();
        return true;
    }

    function onNextPage() {
        _menuView.moveDown();
        return true;
    }

    function onPreviousPage() {
        _menuView.moveUp();
        return true;
    }
}
