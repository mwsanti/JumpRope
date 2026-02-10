// ==========================================================================
// SummaryView.mc — Post-workout summary screen
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
// Author: JumpRope Team
// Version: 1.0.0
//
// Displays workout statistics after the user stops recording. Reads final
// metrics from a SessionManager reference and populates layout labels.
// ==========================================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

class SummaryView extends Ui.View {

    // Reference to the SessionManager holding final workout metrics
    var _sessionManager;

    // Receives the SessionManager instance with completed workout data.
    function initialize(sessionManager) {
        View.initialize();
        _sessionManager = sessionManager;
    }

    // Loads the SummaryLayout resource for this view.
    function onLayout(dc) {
        setLayout(Rez.Layouts.SummaryLayout(dc));
    }

    // No special setup needed — data is already in SessionManager.
    function onShow() {
    }

    // Draws the summary layout and populates all metric labels from
    // SessionManager data. Null-checks every findDrawableById() result
    // before calling setText() for robustness.
    function onUpdate(dc) {
        // Draw the base layout
        View.onUpdate(dc);

        // Total Jumps
        var totalJumpsLabel = findDrawableById("TotalJumpsValue");
        if (totalJumpsLabel != null) {
            totalJumpsLabel.setText(_sessionManager.getTotalJumps().toString());
        }

        // Duration (MM:SS)
        var durationLabel = findDrawableById("DurationValue");
        if (durationLabel != null) {
            durationLabel.setText(_sessionManager.getElapsedFormatted());
        }

        // Average JPM
        var avgJpmLabel = findDrawableById("AvgJPMValue");
        if (avgJpmLabel != null) {
            avgJpmLabel.setText(_sessionManager.getAvgJpm().toString());
        }

        // Peak JPM
        var peakJpmLabel = findDrawableById("PeakJPMValue");
        if (peakJpmLabel != null) {
            peakJpmLabel.setText(_sessionManager.getPeakJpm().toString());
        }

        // Calories
        var caloriesLabel = findDrawableById("CaloriesValue");
        if (caloriesLabel != null) {
            caloriesLabel.setText(_sessionManager.getCalories().toString());
        }

        // Average Heart Rate (show "--" if no HR data)
        var avgHrLabel = findDrawableById("AvgHRValue");
        if (avgHrLabel != null) {
            var avgHr = _sessionManager.getAvgHr();
            if (avgHr > 0) {
                avgHrLabel.setText(avgHr.toString());
            } else {
                avgHrLabel.setText("--");
            }
        }

        // Max Heart Rate (show "--" if no HR data)
        var maxHrLabel = findDrawableById("MaxHRValue");
        if (maxHrLabel != null) {
            var maxHr = _sessionManager.getMaxHr();
            if (maxHr > 0) {
                maxHrLabel.setText(maxHr.toString());
            } else {
                maxHrLabel.setText("--");
            }
        }
    }

}
