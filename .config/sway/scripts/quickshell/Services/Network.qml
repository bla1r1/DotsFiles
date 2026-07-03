pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

// =============================================================================
// Owner of the Wi-Fi and Bluetooth polling.
//
// Holds the raw state the two shell scripts report plus the busy-task set that
// paces them. Deriving display rows from that stays in the view — the point
// here is that only one poller exists no matter how many places show network
// status, not to move the whole popup into a singleton.
//
// The adaptive interval is kept: 1s while something is connecting, 3s at rest.
// It belongs with the busy set that drives it, which is why that set moved too.
//
// Refcounted like the other services — see Services/Audio.qml.
// =============================================================================

Singleton {
    id: root

    /** Last parsed payload from wifi_panel_logic.sh / bluetooth_panel_logic.sh. */
    property var wifi: ({})
    property var bluetooth: ({})

    signal wifiUpdated(var data)
    signal bluetoothUpdated(var data)

    readonly property string _dir: Quickshell.env("HOME") + "/.config/sway/scripts/quickshell/network"

    // ── Consumers ────────────────────────────────────────────────────────────

    property int _users: 0
    function acquire() { root._users++; }
    function release() { if (root._users > 0) root._users--; }

    // ── In-flight operations ─────────────────────────────────────────────────
    // Connecting, disconnecting, toggling a radio. While any of these is open
    // the poller runs faster so the UI catches up quickly.

    property var busy: ({})

    function setBusy(id, on) {
        let b = Object.assign({}, root.busy);
        if (on) b[id] = true;
        else delete b[id];
        root.busy = b;
    }

    function isBusy(id) { return root.busy[id] === true; }

    readonly property bool anyBusy: Object.keys(root.busy).length > 0
    readonly property int pollInterval: root.anyBusy ? 1000 : 3000

    function refresh() {
        wifiPoller.running = true;
        btPoller.running = true;
    }

    // ── Polling ──────────────────────────────────────────────────────────────

    Settings {
        id: cache
        property string lastWifiJson: ""
        property string lastBtJson: ""
    }

    Component.onCompleted: {
        if (cache.lastWifiJson !== "") root._applyWifi(cache.lastWifiJson);
        if (cache.lastBtJson !== "") root._applyBt(cache.lastBtJson);
    }

    function _applyWifi(text) {
        if (!text) return;
        try {
            root.wifi = JSON.parse(text);
            root.wifiUpdated(root.wifi);
        } catch (e) {}
    }

    function _applyBt(text) {
        if (!text) return;
        try {
            root.bluetooth = JSON.parse(text);
            root.bluetoothUpdated(root.bluetooth);
        } catch (e) {}
    }

    Process {
        id: wifiPoller
        command: ["bash", root._dir + "/wifi_panel_logic.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                cache.lastWifiJson = this.text.trim();
                root._applyWifi(cache.lastWifiJson);
            }
        }
    }

    Process {
        id: btPoller
        command: ["bash", root._dir + "/bluetooth_panel_logic.sh", "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                cache.lastBtJson = this.text.trim();
                root._applyBt(cache.lastBtJson);
            }
        }
    }

    Timer {
        interval: root.pollInterval
        repeat: true
        triggeredOnStart: true
        running: root._users > 0
        onTriggered: root.refresh()
    }
}
