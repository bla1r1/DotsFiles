import QtQuick
import Quickshell
import B1air.Daemon

// =============================================================================
// Surfaces B1air.Daemon failures.
//
// The D-Bus calls carry a real reason for failing — "b1air-daemon is not
// running", "accepts calls only from the session user" — which the old
// `execDetached(["b1air-daemon", ...])` route threw away along with the exit
// code. Instantiate this once and every failure reaches the user.
// =============================================================================

Scope {
    Connections {
        target: Daemon
        function onFailed(method, message) {
            Quickshell.execDetached(["notify-send", "-a", "b1air", "-u", "critical",
                                     method + " failed", message]);
        }
    }
}
