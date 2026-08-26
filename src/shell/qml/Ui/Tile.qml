import QtQuick

// =============================================================================
// A Control Center tile: rounded raised block, optionally openable.
//
// Not `Card` — Card is a titled container for a settings page. A tile is a
// control in its own right: it shows a value, it reacts to the pointer, and
// clicking it may open the full view of whatever it summarises.
// =============================================================================

Rectangle {
    id: root

    property bool interactive: false
    property bool on: false
    property color activeColor: Design.accent
    // Not accentText: a tile can be blue, mauve or peach, and on-primary is only
    // guaranteed to be readable on primary.
    property color activeTextColor: Design.contrastOn(root.activeColor)
    signal activated()

    radius: Design.s(Design.radius.card)
    color: root.on ? root.activeColor
                   : (root.interactive && ma.containsMouse ? Design.hover : Design.glassTile)

    border.color: root.on ? Design.tint(root.activeColor, 0.6)
                          : (root.interactive && ma.containsMouse ? Design.glassBorder : Design.tint(Design.line, 0.45))
    border.width: 1

    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

    scale: root.interactive && ma.pressed ? 0.98 : (root.interactive && ma.containsMouse ? 1.01 : 1.0)
    Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Design.easing } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
