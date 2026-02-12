// ==========================================================================
// SummaryView.mc — Post-workout summary screen (paginated)
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 2.2.0
//
// Displays workout statistics across 4 pages (2 stats each), navigated
// with UP/DOWN. Custom-drawn using dc.drawText() for full control on the
// 215x180 semi-round display. No XML layout dependency.
//
// Button hints are placed on the right edge aligned with the physical
// START (upper-right) and BACK (lower-right) buttons on the FR235.
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

class SummaryView extends Ui.View {

    // Reference to the SessionManager holding final workout metrics
    var _sessionManager;

    // Current page index (0-based)
    var _currentPage;
    var _totalPages;

    function initialize(sessionManager) {
        View.initialize();
        _sessionManager = sessionManager;
        _currentPage = 0;
        _totalPages = 4;
    }

    // Skip XML layout — we custom-draw everything
    function onLayout(dc) {
    }

    function onShow() {
    }

    // Navigate to the next page (wraps around)
    function nextPage() {
        _currentPage = (_currentPage + 1) % _totalPages;
        Ui.requestUpdate();
    }

    // Navigate to the previous page (wraps around)
    function prevPage() {
        _currentPage = _currentPage - 1;
        if (_currentPage < 0) {
            _currentPage = _totalPages - 1;
        }
        Ui.requestUpdate();
    }

    // Draws the current page with title, stats, button hints, and page dots
    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Clear background
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        // Draw page title
        var pageNum = _currentPage + 1;
        var title = "Summary " + pageNum + "/" + _totalPages;
        dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 8, Gfx.FONT_SMALL, title, Gfx.TEXT_JUSTIFY_CENTER);

        // Button hint: Back exits to main screen
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - 8, 132, Gfx.FONT_XTINY, "Back", Gfx.TEXT_JUSTIFY_RIGHT);

        // Draw stats for current page (centered, between the button hints)
        if (_currentPage == 0) {
            _drawPage1(dc, w, h);
        } else if (_currentPage == 1) {
            _drawPage2(dc, w, h);
        } else if (_currentPage == 2) {
            _drawPage3(dc, w, h);
        } else {
            _drawPage4(dc, w, h);
        }

        // Draw page indicator dots
        _drawPageDots(dc, w, h);
    }

    // Page 1: Total Jumps, Duration
    hidden function _drawPage1(dc, w, h) {
        var cx = w / 2;
        _drawStatRow(dc, cx, 52, "Total Jumps",
            _sessionManager.getTotalJumps().toString(), Gfx.COLOR_WHITE);
        _drawStatRow(dc, cx, 100, "Duration",
            _sessionManager.getElapsedFormatted(), Gfx.COLOR_WHITE);
    }

    // Page 2: Avg JPM, Peak JPM
    hidden function _drawPage2(dc, w, h) {
        var cx = w / 2;
        _drawStatRow(dc, cx, 52, "Avg JPM",
            _sessionManager.getAvgJpm().toString(), Gfx.COLOR_WHITE);
        _drawStatRow(dc, cx, 100, "Peak JPM",
            _sessionManager.getPeakJpm().toString(), Gfx.COLOR_WHITE);
    }

    // Page 3: Avg HR, Max HR
    hidden function _drawPage3(dc, w, h) {
        var cx = w / 2;
        var avgHr = _sessionManager.getAvgHr();
        var avgHrStr = (avgHr > 0) ? avgHr.toString() : "--";
        _drawStatRow(dc, cx, 52, "Avg HR", avgHrStr, Gfx.COLOR_RED);

        var maxHr = _sessionManager.getMaxHr();
        var maxHrStr = (maxHr > 0) ? maxHr.toString() : "--";
        _drawStatRow(dc, cx, 100, "Max HR", maxHrStr, Gfx.COLOR_RED);
    }

    // Page 4: Calories
    hidden function _drawPage4(dc, w, h) {
        var cx = w / 2;
        _drawStatRow(dc, cx, 75, "Calories",
            _sessionManager.getCalories().toString(), Gfx.COLOR_WHITE);
    }

    // Draws a single stat row: label (gray, small) above value (colored, large), centered
    hidden function _drawStatRow(dc, centerX, y, label, value, valueColor) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_CENTER);

        dc.setColor(valueColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(centerX, y + 16, Gfx.FONT_MEDIUM, value, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // Draws page indicator dots at the bottom
    hidden function _drawPageDots(dc, w, h) {
        var dotRadius = 4;
        var dotSpacing = 14;
        var totalWidth = (_totalPages - 1) * dotSpacing;
        var startX = (w - totalWidth) / 2;
        var dotY = h - 22;

        for (var i = 0; i < _totalPages; i++) {
            var x = startX + (i * dotSpacing);
            if (i == _currentPage) {
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, dotRadius);
            } else {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, dotRadius - 1);
            }
        }
    }

}
