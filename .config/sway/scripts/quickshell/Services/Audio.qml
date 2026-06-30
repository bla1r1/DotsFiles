pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

// =============================================================================
// Owner of the audio state.
//
// Volume had two owners reading it two different ways: VolumePopup via
// get_audio_state.py, BatteryPopup via raw `wpctl get-volume`. Two sources of
// truth for one number, free to disagree on screen. This is the one source;
// every write goes through audio_control.sh.
//
//   Audio.setVolume("sink", id, 42)
//   Audio.defaultSink.volume
//
// POLLING IS REFCOUNTED. A singleton that polls unconditionally would run
// python3 once a second for the whole session — today the poller only lives as
// long as the popup does. Consumers must bracket their use:
//
//   Component.onCompleted: Audio.acquire()
//   Component.onDestruction: Audio.release()
// =============================================================================

Singleton {
    id: root

    readonly property ListModel outputs: ListModel {}
    readonly property ListModel inputs: ListModel {}
    readonly property ListModel apps: ListModel {}

    // Assigned explicitly at the end of every sync, NOT bound: a ListModel
    // mutation does not re-evaluate a binding that calls into it, so a bound
    // version would silently keep returning the first device it ever saw.
    property var defaultSink: null
    property var defaultSource: null

    property int pollInterval: 1000

    readonly property string _scriptsDir: Quickshell.env("HOME") + "/.config/sway/scripts/quickshell/volume"

    // ── Consumers ────────────────────────────────────────────────────────────

    property int _users: 0
    function acquire() { root._users++; }
    function release() { if (root._users > 0) root._users--; }

    // ── Writes ───────────────────────────────────────────────────────────────
    // `type` is "sink" | "source" | "sink-input", matching audio_control.sh.

    function setVolume(type, id, pct) {
        if (!id) return;
        Quickshell.execDetached([root._scriptsDir + "/audio_control.sh", "set-volume", type, id, pct]);
    }

    function toggleMute(type, id) {
        if (!id) return;
        Quickshell.execDetached([root._scriptsDir + "/audio_control.sh", "toggle-mute", type, id]);
    }

    function setDefault(type, name) {
        if (!name) return;
        Quickshell.execDetached([root._scriptsDir + "/audio_control.sh", "set-default", type, name]);
    }

    // Raising a muted device should unmute it — otherwise the slider moves and
    // nothing is heard. Both popups had this rule; now it lives in one place.
    function applyVolume(type, device, pct) {
        if (!device || !device.id) return;
        if (pct > 0 && device.mute)
            root.toggleMute(type, device.id);
        root.setVolume(type, device.id, pct);
    }

    /** Ask the poller to refresh now rather than waiting out the interval. */
    function refresh() { poller.running = true; }

    // ── Drag protection ──────────────────────────────────────────────────────
    // While a slider is held, the poller must not overwrite that device's
    // volume. This lived in each popup as `draggingNodes`; it is a property of
    // the data, not of the view, so it belongs here.

    property var _held: ({})

    function hold(id, holding) {
        let h = Object.assign({}, root._held);
        if (holding) h[id] = true;
        else delete h[id];
        root._held = h;
    }

    function isHeld(id) { return root._held[id] === true; }

    // ── Polling ──────────────────────────────────────────────────────────────

    Settings {
        id: cache
        property string lastAudioJson: ""
    }

    Component.onCompleted: if (cache.lastAudioJson !== "") root._apply(cache.lastAudioJson)

    Process {
        id: poller
        command: ["python3", root._scriptsDir + "/get_audio_state.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                cache.lastAudioJson = this.text.trim();
                root._apply(cache.lastAudioJson);
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

    // ── Model sync ───────────────────────────────────────────────────────────

    function _apply(text) {
        if (!text) return;
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            // Keep the last good state rather than emptying the lists.
            console.warn("Audio: cannot parse state —", e);
            return;
        }
        _sync(root.outputs, data.outputs || []);
        _sync(root.inputs, data.inputs || []);
        _sync(root.apps, data.apps || []);
        root.defaultSink = _pick(root.outputs);
        root.defaultSource = _pick(root.inputs);
    }

    /** In-place reconcile: keeps delegates alive so rows do not flash. */
    function _sync(model, rows) {
        for (let i = model.count - 1; i >= 0; i--) {
            const id = model.get(i).id;
            if (!rows.some(r => r.id === id))
                model.remove(i);
        }

        for (let i = 0; i < rows.length; i++) {
            const d = rows[i];
            let at = -1;
            for (let j = i; j < model.count; j++) {
                if (model.get(j).id === d.id) { at = j; break; }
            }

            const obj = {
                id: d.id, name: d.name, description: d.description,
                volume: d.volume, mute: d.mute, is_default: d.is_default, icon: d.icon
            };

            if (at === -1) {
                model.insert(i, obj);
                continue;
            }
            if (at !== i)
                model.move(at, i, 1);
            for (const key in obj) {
                if (key === "volume" && root.isHeld(d.id))
                    continue;
                if (model.get(i)[key] !== obj[key])
                    model.setProperty(i, key, obj[key]);
            }
        }
    }

    function _pick(model) {
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).is_default)
                return model.get(i);
        }
        return model.count > 0 ? model.get(0) : null;
    }
}
