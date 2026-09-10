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
    property string icon: ""
    property bool active: false
    property color activeColor: Design.accent
    property color activeTextColor: Design.accentText
    signal clicked()

    implicitWidth: contentRow.implicitWidth + Design.s(Design.space.lg)
    implicitHeight: Design.s(Design.size.field)
    radius: height / 2

    color: button.active ? button.activeColor : (area.containsMouse ? Design.glassHover : Design.glassCard)
    border.color: button.active ? button.activeColor : (area.containsMouse ? Design.glassBorder : Design.tint(Design.line, 0.45))
    border.width: 1

    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

    scale: area.pressed ? 0.96 : (area.containsMouse ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Design.easing } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Design.s(Design.space.xs)

        Icon {
            visible: button.icon !== ""
            text: button.icon
            role: "caption"
            anchors.verticalCenter: parent.verticalCenter
            color: button.active ? button.activeTextColor : (area.containsMouse ? Design.text : Design.textDim)
            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
        }

        Label {
            id: text
            text: button.label
            role: "caption"
            anchors.verticalCenter: parent.verticalCenter
            weight: button.active ? Design.weight.bold : Design.weight.medium
            color: button.active ? button.activeTextColor : (area.containsMouse ? Design.text : Design.textDim)
            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
        }
    }

    Clickable { id: area; onClicked: button.clicked() }
}
