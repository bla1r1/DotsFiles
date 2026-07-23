pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

// =============================================================================
// Owner of Wi-Fi and Bluetooth state, on NetworkManager and BlueZ directly.
//
// Was: two shell scripts on a 1-3 second timer — wifi_panel_logic.sh calling
// nmcli, bluetooth_panel_logic.sh calling bluetoothctl, both parsed from JSON.
//
// An earlier version of this file said these had no native equivalent. That was
// wrong and was written from memory: Quickshell.Networking and
// Quickshell.Bluetooth both exist and are event-driven.
//
// PUBLIC SHAPE UNCHANGED. NetworkPopup parses `{power, connected, networks}` and
// `{power, connected, devices}` out of the two signals, so the same objects are
// built here from live properties rather than from a script's stdout. That seam
// is why swapping the source did not touch the popup.
// =============================================================================

Singleton {
    id: root

    property var wifi: ({})
    property var bluetooth: ({})

    signal wifiUpdated(var data)
    signal bluetoothUpdated(var data)

    // ── Consumers ────────────────────────────────────────────────────────────
    // Nothing polls any more, so this only scopes the scan: leaving the Wi-Fi
    // scanner running all session drains battery for a list nobody is reading.

    property int _users: 0
    function acquire() { root._users++; }
    function release() { if (root._users > 0) root._users--; }

    // ── Devices ──────────────────────────────────────────────────────────────

    readonly property var wifiDevice: {
        const d = Networking.devices.values.find(x => x.type === DeviceType.Wifi);
        return d || null;
    }

    readonly property var adapter: Bluetooth.defaultAdapter

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root._users > 0
        when: root.wifiDevice !== null
    }

    // ── In-flight operations ─────────────────────────────────────────────────
    // Kept from the old file: the popup marks a row busy while a connect or a
    // radio toggle is in flight, and reads it back to show a spinner.

    property var busy: ({})

    function setBusy(id, on) {
        let b = Object.assign({}, root.busy);
        if (on) b[id] = true;
        else delete b[id];
        root.busy = b;
    }

    function isBusy(id) { return root.busy[id] === true; }
    readonly property bool anyBusy: Object.keys(root.busy).length > 0

    // ── Writes ───────────────────────────────────────────────────────────────

    function setWifiEnabled(on) { Networking.wifiEnabled = on; }

    function connectWifi(ssid, psk) {
        if (!root.wifiDevice) return;
        const n = root.wifiDevice.networks.values.find(x => x.name === ssid);
        if (!n) return;
        root.setBusy(ssid, true);
        if (psk !== undefined && psk !== "") n.connectWithPsk(psk);
        else n.connect();
    }

    function disconnectWifi() {
        if (root.wifiDevice) root.wifiDevice.disconnect();
    }

    function setBluetoothEnabled(on) {
        if (root.adapter) root.adapter.enabled = on;
    }

    function connectDevice(address) {
        const d = Bluetooth.devices.values.find(x => x.address === address);
        if (!d) return;
        root.setBusy(address, true);
        if (!d.paired) d.pair();
        else d.connect();
    }

    function disconnectDevice(address) {
        const d = Bluetooth.devices.values.find(x => x.address === address);
        if (d) d.disconnect();
    }

    function forgetDevice(address) {
        const d = Bluetooth.devices.values.find(x => x.address === address);
        if (d) d.forget();
    }

    function refresh() { root._rebuild(); }

    // ── Live state → the shape the popup reads ───────────────────────────────

    function _wifiIcon(signal) {
        if (signal >= 80) return "\u{f0928}";
        if (signal >= 60) return "\u{f0925}";
        if (signal >= 40) return "\u{f0922}";
        if (signal >= 20) return "\u{f091f}";
        return "\u{f092f}";
    }

    function _net(n) {
        return {
            id: n.name,
            ssid: n.name,
            name: n.name,
            signal: n.signalStrength,
            security: n.security,
            connected: n.connected,
            known: n.known,
            icon: root._wifiIcon(n.signalStrength)
        };
    }

    function _dev(d) {
        return {
            id: d.address,
            mac: d.address,
            name: d.deviceName || d.name || d.address,
            icon: d.icon || "",
            connected: d.connected,
            paired: d.paired,
            battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
            type: "bluetooth"
        };
    }

    function _rebuild() {
        const dev = root.wifiDevice;
        const nets = dev ? dev.networks.values.map(root._net) : [];
        root.wifi = {
            power: Networking.wifiEnabled ? "on" : "off",
            connected: nets.find(n => n.connected) || null,
            networks: nets
        };
        root.wifiUpdated(root.wifi);

        const a = root.adapter;
        const devs = a ? Bluetooth.devices.values.map(root._dev) : [];
        root.bluetooth = {
            power: (a && a.enabled) ? "on" : "off",
            connected: devs.find(d => d.connected) || null,
            devices: devs
        };
        root.bluetoothUpdated(root.bluetooth);
    }

    // Property changes on the live objects do not re-run _rebuild by themselves,
    // so a slow tick sweeps them up. Nothing forks — this is a walk over objects
    // already in memory, unlike the 1-3s nmcli and bluetoothctl calls it replaces.
    Timer {
        interval: 2000
        repeat: true
        running: root._users > 0
        onTriggered: root._rebuild()
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged() { root._rebuild(); }
        function onDevicesChanged() { root._rebuild(); }
    }

    Connections {
        target: Bluetooth
        ignoreUnknownSignals: true
        function onDevicesChanged() { root._rebuild(); }
        function onDefaultAdapterChanged() { root._rebuild(); }
    }

    Component.onCompleted: root._rebuild()
}
