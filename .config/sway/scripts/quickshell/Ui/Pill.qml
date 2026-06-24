import QtQuick

// =============================================================================
// Small pill button, optionally part of a mutually exclusive group.
//
// Promoted from settings/components/PillButton.qml, plus the `active` state it
// never had — tab strips and option groups need it, and without it every caller
// would rebuild the same selected look by hand.
// =============================================================================

Rectangle {
    id: button

    property string label: ""
    property bool active: false
    signal clicked()

    implicitWidth: text.implicitWidth + Design.s(Design.space.xl)
    implicitHeight: Design.s(30)
    radius: height / 2

    color: button.active ? Design.accent : (area.containsMouse ? Design.hover : "transparent")
    border.color: button.active ? Design.accent : Design.line
    border.width: Design.border

    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

    Label {
        id: text
        anchors.centerIn: parent
        text: button.label
        role: "caption"
        weight: button.active ? Design.weight.semibold : Design.weight.medium
        color: button.active ? Design.onAccent : (area.containsMouse ? Design.text : Design.textDim)
        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
    }

    Clickable { id: area; onClicked: button.clicked() }
}
