import QtQuick

// =============================================================================
// Horizontal fill slider — volume, brightness, anything 0..100.
//
// Written once for the three hand-rolled copies in VolumePopup, BatteryPopup
// and MonitorPopup. They were structurally identical: a 50ms throttle Timer, a
// track, a gradient fill, a MouseArea calling update(mouse.x), a dragging flag
// and a settle Timer so the poller does not yank the handle back mid-drag.
// Only the command and the colours ever differed.
//
// The component owns the mechanics. The popup owns the command:
//
//   Slider {
//       value: window.activeVol
//       tone: window.tabColor
//       muted: window.activeMute
//       onMoved: pct => Quickshell.execDetached([script, "set-volume", id, pct])
//   }
//
// `value` may keep updating from a poller while the user drags — `shown` holds
// the local position until the drag settles, so the fill never jumps back.
// =============================================================================

Item {
    id: root

    // ── In ───────────────────────────────────────────────────────────────────
    property int value: 0                    // from the poller, clamped to the range
    property color tone: Design.accent       // gradient base
    property bool muted: false

    // ── Out ──────────────────────────────────────────────────────────────────
    // Throttled to `throttleInterval` so a drag does not spawn a process per
    // pixel. Always fires once more on release with the final value.
    signal moved(int pct)

    // True from press until `settleDelay` after release. Popups use it to skip
    // model updates for this control while the user is on it.
    readonly property bool active: _dragging || settle.running

    readonly property int shown: root.active ? _local : Math.max(root.minimum, Math.min(root.maximum, root.value))

    // ── Tuning ───────────────────────────────────────────────────────────────
    // A monitor at 0 brightness is simply a black screen, so some sliders must
    // not be draggable all the way down.
    property int minimum: 0
    property int maximum: 100

    property int throttleInterval: 50   // process spawn rate ceiling
    property int settleDelay: 600       // poller round-trip allowance
    property int cornerRadius: Design.radius.card

    implicitHeight: Design.s(24)

    // ── Internals ────────────────────────────────────────────────────────────
    property int _local: 0
    property bool _dragging: false

    Timer {
        id: throttle
        interval: root.throttleInterval
        property int pending: -1
        onTriggered: {
            if (pending >= 0) {
                root.moved(pending);
                pending = -1;
            }
        }
    }

    Timer { id: settle; interval: root.settleDelay }

    function _emit(pct) {
        throttle.pending = pct;
        if (!throttle.running)
            throttle.start();
    }

    Rectangle {
        anchors.fill: parent
        radius: Design.s(root.cornerRadius)
        color: Design.sunken
        border.color: Design.line
        border.width: Design.border
        clip: true

        Rectangle {
            height: parent.height
            width: parent.width * (root.shown / root.maximum)
            radius: Design.s(root.cornerRadius)

            opacity: root.muted ? Design.opacity.disabled : (ma.containsMouse ? Design.opacity.full : 0.85)
            Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

            // Following the pointer must be instant; catching up to the poller
            // should glide.
            Behavior on width {
                enabled: !root._dragging
                NumberAnimation { duration: Design.duration.base; easing.type: Design.easing }
            }

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: root.muted ? Design.active : root.tone
                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                }
                GradientStop {
                    position: 1.0
                    color: root.muted ? Qt.lighter(Design.active, 1.15) : Qt.lighter(root.tone, 1.25)
                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function at(mx) {
            const pct = Math.round((mx / width) * root.maximum);
            return Math.max(root.minimum, Math.min(root.maximum, pct));
        }

        onPressed: mouse => {
            settle.stop();
            root._dragging = true;
            root._local = at(mouse.x);
            root._emit(root._local);
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root._local = at(mouse.x);
            root._emit(root._local);
        }

        onReleased: {
            root._dragging = false;
            // Throttle may be mid-cycle holding a newer value than the last
            // emit; flush it so the final position is never dropped.
            throttle.stop();
            if (throttle.pending >= 0) {
                root.moved(throttle.pending);
                throttle.pending = -1;
            }
            settle.restart();
        }
    }
}
