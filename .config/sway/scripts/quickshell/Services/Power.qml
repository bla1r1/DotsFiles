pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

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
    // From UPower rather than catting /sys/class/power_supply/BAT*/ in a bash
    // poller. UPower is already a daemon watching this hardware; asking it costs
    // a D-Bus property read, and it pushes changes instead of being asked.
    readonly property var _bat: UPower.displayDevice

    // The scale of UPowerDevice.percentage is genuinely ambiguous from outside:
    // UPower's own D-Bus Percentage is 0..100, but Quickshell binds it through a
    // dedicated `PowerPercentage` type, and a converter existing at all suggests
    // it normalises to 0..1. Getting it wrong shows either 1% or 10000%.
    //
    // Handled for both until it can be checked on a machine that runs this.
    // TO REMOVE: read the real value once, then keep only the correct branch.
    readonly property int capacity: {
        if (!root._bat)
            return 0;
        const p = root._bat.percentage;
        return Math.round(p <= 1.0 ? p * 100 : p);
    }
    readonly property bool charging: root._bat
        ? (root._bat.state === UPowerDeviceState.Charging
           || root._bat.state === UPowerDeviceState.FullyCharged)
        : false
    readonly property string status: {
        if (!root._bat) return "Unknown";
        switch (root._bat.state) {
        case UPowerDeviceState.Charging:      return "Charging";
        case UPowerDeviceState.FullyCharged:  return "Full";
        case UPowerDeviceState.Discharging:   return "Discharging";
        case UPowerDeviceState.Empty:         return "Empty";
        default:                              return "Unknown";
        }
    }

    // ── Profile ──────────────────────────────────────────────────────────────
    property string profile: "balanced"

    // ── Uptime ───────────────────────────────────────────────────────────────
    property int upHours: 0
    property int upMins: 0

    // ── Backlight ────────────────────────────────────────────────────────────
    // The laptop panel. External monitors are a different device on a different
    // protocol (DDC) and stay with MonitorPopup.
    //
    // Split on purpose: READ from sysfs, WRITE through brightnessctl.
    //
    // Reading natively takes brightness out of the 1.5s poll loop entirely —
    // sysfs emits inotify on change, so FileView sees a keypress immediately
    // instead of up to a second and a half later.
    //
    // Writing stays with the tool because `brightnessctl -e4 -n2` is not a
    // number being stored: -e4 is a logarithmic curve matching how brightness
    // is actually perceived, and -n2 keeps the panel from going fully dark.
    // Writing raw values to sysfs would silently lose both.
    property int brightness: 0
    property int brightnessRaw: 0
    property int brightnessMax: 0

    // What is left in the poller is the power profile and uptime. Battery moved
    // to UPower, brightness to inotify — neither is asked for any more. 40
    // process spawns a minute became 4.
    property int pollInterval: 15000

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
        root.brightness = pct;   // optimistic; the FileView confirms
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-e4", "-n2", "set", pct + "%"]);
    }

    function stepBrightness(delta) {
        const sign = delta >= 0 ? "+" : "-";
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-e4", "-n2",
                                 "set", Math.abs(delta) + "%" + sign]);
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
            "powerprofilesctl get 2>/dev/null || echo 'balanced'; " +
            "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length < 2)
                    return;

                root.profile = lines[0];

                const up = lines[1].split("h ");
                if (up.length === 2) {
                    root.upHours = parseInt(up[0]) || 0;
                    root.upMins = parseInt(up[1].replace("m", "")) || 0;
                }
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

    // ── Backlight, event-driven ──────────────────────────────────────────────
    // One process for the whole session to find the device, then nothing.
    // The glob has to be resolved once because FileView needs a concrete path.

    property string _backlightDir: ""

    Process {
        id: findBacklight
        running: true
        command: ["bash", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = this.text.trim();
                if (dir !== "")
                    root._backlightDir = dir.replace(/\/$/, "");
            }
        }
    }

    FileView {
        path: root._backlightDir === "" ? "" : root._backlightDir + "/max_brightness"
        printErrors: false
        onLoaded: root.brightnessMax = parseInt(text()) || 0
    }

    FileView {
        path: root._backlightDir === "" ? "" : root._backlightDir + "/brightness"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.brightnessRaw = parseInt(text()) || 0;
            if (!root.brightnessHeld && root.brightnessMax > 0)
                root.brightness = Math.round(root.brightnessRaw * 100 / root.brightnessMax);
        }
    }
}
