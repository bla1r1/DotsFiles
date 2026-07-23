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
    signal activated()

    radius: Design.s(Design.radius.card)
    color: root.on ? Design.accent
                   : (root.interactive && ma.containsMouse ? Design.hover : Design.raised)

    Behavior on color { ColorAnimation { duration: Design.duration.fast } }

    scale: root.interactive && ma.pressed ? 0.985 : 1.0
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
