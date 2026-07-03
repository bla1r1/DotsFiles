pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Owner of the player and equaliser state.
//
// Lifted out of MusicPopup so a media card can appear anywhere in the Control
// Center without starting a second poller.
//
// Also retires MusicPopup's execCmd(), which built a QML Process out of an
// interpolated source string on every button press:
//
//     Qt.createQmlObject(`... command: ["bash", "-c", \`${safeCmd}\`] ...`)
//
// That compiles QML at runtime to run a fixed command, and escapes the string
// by hand to stay safe. execDetached does the same work with neither problem.
//
// Refcounted like the other services — see Services/Audio.qml.
// =============================================================================

Singleton {
    id: root

    /** Whatever music_info.sh reports: title, artist, status, art, colours. */
    property var track: ({})
    /** Whatever equalizer.sh reports. */
    property var eq: ({})

    readonly property string status: track && track.status ? track.status : ""
    readonly property bool playing: status === "Playing"
    readonly property bool hasPlayer: !!(track && track.title)

    property int pollInterval: 1000

    readonly property string _dir: Quickshell.env("HOME") + "/.config/sway/scripts/quickshell/music"

    // ── Consumers ────────────────────────────────────────────────────────────

    property int _users: 0
    function acquire() { root._users++; }
    function release() { if (root._users > 0) root._users--; }

    // ── Transport ────────────────────────────────────────────────────────────
    // The optimistic flip is here rather than in the view: the poller is what
    // it protects against, and the poller lives here too.

    property bool _optimistic: false
    Timer { id: settle; interval: 1200; onTriggered: root._optimistic = false }

    function playPause() {
        root._optimistic = true;
        root.track = Object.assign({}, root.track, { status: root.playing ? "Paused" : "Playing" });
        settle.restart();
        Quickshell.execDetached(["playerctl", "play-pause"]);
    }

    function next()     { Quickshell.execDetached(["playerctl", "next"]);     root.refresh(); }
    function previous() { Quickshell.execDetached(["playerctl", "previous"]); root.refresh(); }

    function seek(seconds) {
        Quickshell.execDetached(["playerctl", "position", String(seconds)]);
    }

    // ── Equaliser ────────────────────────────────────────────────────────────

    property real _lastEqWrite: 0

    function setEqBands(bands) {
        root.eq = Object.assign({}, root.eq, { bands: bands });
        root._lastEqWrite = Date.now();
        Quickshell.execDetached([root._dir + "/equalizer.sh", "set"].concat(bands.map(String)));
    }

    function setEqPreset(name, bands) {
        root.eq = Object.assign({}, root.eq, { preset: name, bands: bands });
        root._lastEqWrite = Date.now();
        Quickshell.execDetached([root._dir + "/equalizer.sh", "preset", name]);
    }

    function refresh() {
        musicProc.running = true;
        eqProc.running = true;
    }

    // ── Polling ──────────────────────────────────────────────────────────────

    Process {
        id: musicProc
        command: [root._dir + "/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = (this.text || "").trim();
                if (!out) return;
                try {
                    const data = JSON.parse(out);
                    // A press already moved the button; do not let the poller
                    // bounce it back before the player has caught up.
                    if (root._optimistic && root.track)
                        data.status = root.track.status;
                    root.track = data;
                } catch (e) {}
            }
        }
    }

    Process {
        id: eqProc
        command: [root._dir + "/equalizer.sh", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - root._lastEqWrite < 2000) return;
                const out = (this.text || "").trim();
                if (!out) return;
                try { root.eq = JSON.parse(out); } catch (e) {}
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
