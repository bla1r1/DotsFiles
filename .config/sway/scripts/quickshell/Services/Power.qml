pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Owner of battery, power profile, uptime and laptop backlight.
//
// Lifted out of BatteryPopup's inline sysPoller so the Control Center pages can
// share one reading instead of each starting their own. Same combined bash
// call as before — one process per tick, not one per value.
//
// Refcounted like Services/Audio: a singleton polling unconditionally would run
// for the whole session, where the popup's poller only lived while it was open.
//
//   Component.onCompleted: Power.acquire()
//   Component.onDestruction: Power.release()
// =============================================================================

Singleton {
    id: root

    // ── Battery ──────────────────────────────────────────────────────────────
    property int capacity: 0
    property string status: "Unknown"
    readonly property bool charging: status === "Charging"

    // ── Profile ──────────────────────────────────────────────────────────────
    property string profile: "balanced"

    // ── Uptime ───────────────────────────────────────────────────────────────
    property int upHours: 0
    property int upMins: 0

    // ── Backlight ────────────────────────────────────────────────────────────
    // The laptop panel, via brightnessctl. External monitors are a different
    // device on a different protocol (DDC) and stay with MonitorPopup.
    property int brightness: 0

    property int pollInterval: 1500

    // ── Consumers ────────────────────────────────────────────────────────────

    property int _users: 0
    function acquire() { root._users++; }
    function release() { if (root._users > 0) root._users--; }

    // ── Writes ───────────────────────────────────────────────────────────────

    function setProfile(name) {
        root.profile = name;                       // optimistic, poller confirms
        Quickshell.execDetached(["powerprofilesctl", "set", name]);
    }

    function setBrightness(pct) {
        root.brightness = pct;
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
    }

    function refresh() { poller.running = true; }

    // ── Drag protection ──────────────────────────────────────────────────────
    // Held while a brightness slider is under the pointer, so the 1.5s poller
    // cannot yank it back mid-drag.
    property bool brightnessHeld: false

    // ── Polling ──────────────────────────────────────────────────────────────

    Process {
        id: poller
        command: ["bash", "-c",
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '0'; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'Unknown'; " +
            "powerprofilesctl get 2>/dev/null || echo 'balanced'; " +
            "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'; " +
            "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' || echo '0'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length < 5)
                    return;

                root.capacity = parseInt(lines[0]) || 0;
                root.status = lines[1];
                root.profile = lines[2];

                const up = lines[3].split("h ");
                if (up.length === 2) {
                    root.upHours = parseInt(up[0]) || 0;
                    root.upMins = parseInt(up[1].replace("m", "")) || 0;
                }

                if (!root.brightnessHeld)
                    root.brightness = parseInt(lines[4]) || 0;
            }
        }
    }

    Timer {
        interval: root.pollInterval
        repeat: true
        triggeredOnStart: true
        running: root._users > 0
        onTriggered: poller.running = true
    }
}
