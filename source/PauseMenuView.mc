// ==========================================================================
// PauseMenuView.mc — Pause menu screen with Resume/Save/Discard options
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
//
// Custom-drawn menu shown when the user pauses a jump session.
// UP/DOWN navigate options, START selects the highlighted option.
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class PauseMenuView extends Ui.View {

    // Currently highlighted menu index (0=Resume, 1=Save, 2=Discard)
    var _selectedIndex;

    function initialize() {
        View.initialize();
        _selectedIndex = 0;
    }

    function onLayout(dc) {
    }

    function onShow() {
    }

    // Move selection up (wraps)
    function moveUp() {
        _selectedIndex = _selectedIndex - 1;
        if (_selectedIndex < 0) {
            _selectedIndex = 2;
        }
        Ui.requestUpdate();
    }

    // Move selection down (wraps)
    function moveDown() {
        _selectedIndex = (_selectedIndex + 1) % 3;
        Ui.requestUpdate();
    }

    // Return the currently selected index
    function getSelectedIndex() {
        return _selectedIndex;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();

        // Clear background
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Constants.COLOR_PAUSED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 12, Gfx.FONT_SMALL, "PAUSED", Gfx.TEXT_JUSTIFY_CENTER);

        // Menu items
        var labels = ["Resume", "Save", "Discard"];
        var startY = 55;
        var rowHeight = 38;

        for (var i = 0; i < 3; i++) {
            var y = startY + (i * rowHeight);

            if (i == _selectedIndex) {
                // Highlight bar
                dc.setColor(Gfx.COLOR_DK_BLUE, Gfx.COLOR_DK_BLUE);
                dc.fillRectangle(20, y - 2, w - 40, 30);

                // Selected text
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, Gfx.FONT_MEDIUM, "> " + labels[i], Gfx.TEXT_JUSTIFY_CENTER);
            } else {
                // Unselected text
                dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, Gfx.FONT_MEDIUM, labels[i], Gfx.TEXT_JUSTIFY_CENTER);
            }
        }
    }
}
