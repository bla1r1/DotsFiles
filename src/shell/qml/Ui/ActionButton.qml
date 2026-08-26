import QtQuick
import QtQuick.Layouts

// =============================================================================
// Wide icon + label button — the Lock / Sleep / Reboot / Off row.
//
// `destructive` adds the step that row was missing: one stray click in a popup
// that opens under the cursor should not power the machine off. The first click
// arms, the second commits, and it disarms itself after a few seconds.
// =============================================================================

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color tone: Design.text
    property color iconTone: Design.textDim
    property bool destructive: false
    property string confirmLabel: "Sure?"

    signal activated()

    property bool _armed: false

    Layout.fillWidth: true
    Layout.preferredHeight: Design.s(Design.size.action)

    radius: Design.s(Design.radius.ctl)
    color: root._armed ? Design.tint(root.tone, 0.28)
                       : (ma.containsMouse ? (root.destructive ? Design.tint(root.tone, 0.18) : Design.glassHover)
                                           : Design.glassCard)
    border.color: (root._armed || ma.containsMouse) ? Design.tint(root.tone, 0.7) : Design.tint(Design.line, 0.45)
    border.width: Design.border

    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

    scale: ma.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Design.easing } }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root._armed = false
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Design.s(Design.space.xs)

        Icon {
            text: root._armed ? "\u{f0e60}" : root.icon   // alert glyph while armed
            role: "caption"
            color: root._armed ? root.tone : root.iconTone
        }

        Label {
            text: root._armed ? root.confirmLabel : root.label
            role: "caption"
            weight: root._armed ? Design.weight.bold : Design.weight.medium
            color: root._armed ? root.tone : root.tone
        }
    }

    Clickable {
        id: ma
        onClicked: {
            if (!root.destructive || root._armed) {
                root._armed = false;
                disarm.stop();
                root.activated();
                return;
            }
            root._armed = true;
            disarm.restart();
        }
    }

    onVisibleChanged: if (!visible) { _armed = false; disarm.stop(); }
}
