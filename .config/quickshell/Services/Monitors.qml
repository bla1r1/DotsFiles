pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Owner of display layout and external-monitor brightness.
//
// The state and the two scripts were locked inside MonitorPopup, which is why
// the settings window had a Displays page that could only render empty: the
// section wanted a model and nothing in the shell owned one. It does now, and
// the popup is gone.
//
// Reads `swaymsg -t get_outputs`, writes through tools/monitors.sh (which
// applies and remembers the layout) and controls/monitor-brightness.sh (DDC).
// =============================================================================

Singleton {
    id: root

    // {name, make, model, resW, resH, rate, sysScale, x, y, focused, active,
    //  modes: [{w, h, rate}]}
    property var outputs: []

    // {id, name, type, brightness} — external panels that answer DDC/CI.
    property var brightness: []

    readonly property bool hasBrightness: root.brightness.length > 0

    readonly property string scriptDir: (Quickshell.env("QS_SCRIPT_DIR")
        || (Quickshell.env("HOME") + "/.config/quickshell")).replace(/\/quickshell\/?$/, "")

    // ── Consumers ────────────────────────────────────────────────────────────
    // Only the settings page reads this, and only while it is open: probing DDC
    // spawns ddcutil, which is slow and wakes the panel's i2c bus.
    property int _users: 0
    function acquire() {
        root._users++;
        if (root._users === 1)
            root.refresh();
    }
    function release() { if (root._users > 0) root._users--; }

    // ── Reads ────────────────────────────────────────────────────────────────

    function refresh() {
        outputReader.running = true;
        brightnessReader.running = true;
    }

    // swaymsg does not go looking for its socket: without SWAYSOCK in the
    // environment it just fails, and a shell started outside sway's own
    // environment then reports no displays at all. Find the socket first.
    readonly property string swaymsg:
        "SWAYSOCK=${SWAYSOCK:-$(ls -t ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-ipc.*.sock 2>/dev/null | head -1)} swaymsg"

    Process {
        id: outputReader
        command: ["sh", "-c", root.swaymsg + " -t get_outputs"]
        stdout: StdioCollector {
            onStreamFinished: root._parseOutputs(this.text)
        }
    }

    Process {
        id: brightnessReader
        command: ["b1air-daemon", "ddc", "list"]
        stdout: StdioCollector {
            onStreamFinished: root._parseBrightness(this.text)
        }
    }

    // Re-read while the page is open: sway is the authority, and a monitor can
    // be plugged in while you are looking at the list.
    Timer {
        interval: 5000
        repeat: true
        running: root._users > 0
        onTriggered: outputReader.running = true
    }

    function _parseOutputs(txt) {
        let data;
        try {
            data = JSON.parse((txt || "").trim() || "[]");
        } catch (e) {
            console.warn("Monitors: cannot parse outputs —", e);
            return;
        }

        const list = data.map(o => {
            const rect = o.rect || { x: 0, y: 0, width: 0, height: 0 };
            const mode = o.current_mode || { width: rect.width, height: rect.height, refresh: 60000 };
            const modes = (o.modes || []).map(m => ({
                w: m.width,
                h: m.height,
                rate: Math.round((m.refresh || 60000) / 1000)
            }));
            return {
                name: o.name,
                make: o.make || "",
                model: o.model || "",
                resW: mode.width,
                resH: mode.height,
                rate: Math.round((mode.refresh || 60000) / 1000),
                sysScale: o.scale !== undefined ? o.scale : 1.0,
                x: rect.x,
                y: rect.y,
                focused: !!o.focused,
                active: o.active !== false,
                transform: o.transform || "normal",
                modes: modes
            };
        });

        root.outputs = list;
    }

    function _parseBrightness(txt) {
        try {
            const data = JSON.parse((txt || "").trim() || "[]");
            root.brightness = data.map(d => ({
                id: d.id || "",
                name: d.name || "Display",
                type: d.type || "ddc",
                brightness: Math.max(1, Math.min(100, parseInt(d.brightness) || 50))
            }));
        } catch (e) {
            root.brightness = [];
        }
    }

    // ── Writes ───────────────────────────────────────────────────────────────

    /** layout: [{name, resW, resH, rate, sysScale, x, y, transform, active}] — the daemon normalises. */
    function apply(layout) {
        if (!layout || layout.length === 0)
            return;
        Quickshell.execDetached(["b1air-daemon", "monitors", "apply", JSON.stringify(layout)]);
        applyRecheck.restart();
    }

    function setEnabled(name, enabled) {
        Quickshell.execDetached(["swaymsg", "output", name, enabled ? "enable" : "disable"]);
        applyRecheck.restart();
    }

    function setTransform(name, rot) {
        Quickshell.execDetached(["swaymsg", "output", name, "transform", String(rot)]);
        applyRecheck.restart();
    }

    function identify() {
        Quickshell.execDetached(["notify-send", "-t", "4000", "Display Identification", "Active displays: " + root.outputs.map((o, idx) => "[" + (idx + 1) + "] " + o.name + " (" + o.resW + "x" + o.resH + "@" + o.rate + "Hz)").join("\n")]);
    }

    Timer {
        id: applyRecheck
        interval: 1200
        onTriggered: outputReader.running = true
    }

    function setBrightness(id, pct) {
        const v = Math.max(1, Math.min(100, Math.round(pct)));
        // Optimistic: ddcutil takes the better part of a second to answer.
        root.brightness = root.brightness.map(d => d.id === id ? Object.assign({}, d, { brightness: v }) : d);
        Quickshell.execDetached(["b1air-daemon", "ddc", "set", id, String(v)]);
    }

    function redetect() {
        redetector.running = true;
    }

    Process {
        id: redetector
        command: ["b1air-daemon", "ddc", "refresh"]
        stdout: StdioCollector {
            onStreamFinished: root._parseBrightness(this.text)
        }
    }
}
