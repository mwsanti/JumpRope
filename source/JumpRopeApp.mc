//
// JumpRopeApp.mc
//
// Main application entry point for the Jump Rope app.
// Manages the Connect IQ app lifecycle: start, stop, and
// initial view creation. Keeps constructor light and defers
// all business logic to views and services.
//
// Target: Garmin Forerunner 235 (Connect IQ 1.3)
//

using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;

class JumpRopeApp extends App.AppBase {

    // Current application state (idle, recording, paused, summary)
    var appState;

    //
    // Constructor. Calls parent initializer and sets the default
    // app state to idle. No heavy work here — keep it light.
    //
    function initialize() {
        AppBase.initialize();
        appState = Constants.STATE_IDLE;
    }

    //
    // Called when the application starts (or returns from background).
    // The state parameter is a Dictionary that may contain saved state
    // from a previous session, or null on a fresh launch.
    //
    // @param state [Dictionary or null] Saved application state
    //
    function onStart(state) {
        Sys.println("JumpRopeApp: onStart");
    }

    //
    // Called when the application is stopping. Use this for any
    // final cleanup. Sensor unregistration is handled by views,
    // so this method just logs the shutdown.
    //
    // @param state [Dictionary or null] State dictionary for saving
    //
    function onStop(state) {
        Sys.println("JumpRopeApp: onStop");
    }

    //
    // Returns the initial view and its input delegate.
    // Launches the main workout screen when the app starts.
    //
    // @return [Array] Array containing [MainView, MainDelegate]
    //
    function getInitialView() {
        var view = new MainView();
        return [view, new MainDelegate(view)];
    }

}
