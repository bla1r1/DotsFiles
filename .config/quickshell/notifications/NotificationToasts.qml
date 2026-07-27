import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Ui"
import "../Services"

// =============================================================================
// Toast Notification Overlay
//
// Renders live desktop notifications in top-right corner with auto-dismiss.
// =============================================================================

PanelWindow {
    id: toastWindow

    anchors {
        top: true
        right: true
    }

    margins {
        top: Design.s(48)
        right: Design.s(16)
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0
    color: "transparent"

    implicitWidth: Design.s(360)
    implicitHeight: toastColumn.implicitHeight + Design.s(20)

    visible: Notifications.activeToasts.count > 0

    ColumnLayout {
        id: toastColumn
        width: parent.width
        spacing: Design.s(Design.space.sm)

        Repeater {
            model: Notifications.activeToasts

            Rectangle {
                id: toastCard
                required property var model
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: contentCol.implicitHeight + Design.s(Design.space.md)
                radius: Design.s(Design.radius.card)
                color: Design.glassBg
                border.color: Design.glassBorder
                border.width: 1
                clip: true

                // Urgency indicator stripe
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Design.s(4)
                    color: toastCard.model.urgency === 2 ? Design.danger : (toastCard.model.urgency === 0 ? Design.textDim : Design.sapphire)
                }

                Timer {
                    id: dismissTimer
                    interval: Notifications.toastTimeoutMs
                    running: !toastMa.containsMouse
                    onTriggered: Notifications.dismissToast(toastCard.index)
                }

                RowLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.md)
                    anchors.rightMargin: Design.s(Design.space.sm)
                    anchors.topMargin: Design.s(Design.space.sm)
                    anchors.bottomMargin: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.sm)

                    // App icon
                    Rectangle {
                        Layout.preferredWidth: Design.s(36)
                        Layout.preferredHeight: Design.s(36)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        Layout.alignment: Qt.AlignTop

                        Icon {
                            anchors.centerIn: parent
                            text: toastCard.model.icon ? toastCard.model.icon : "\u{f009a}"
                            role: "body"
                            color: Design.sapphire
                        }
                    }

                    // Content
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: toastCard.model.appName
                                role: "caption"
                                dim: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: toastCard.model.time
                                role: "caption"
                                dim: true
                            }
                        }

                        Label {
                            text: toastCard.model.summary
                            weight: Design.weight.semibold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: toastCard.model.body !== ""
                            text: toastCard.model.body
                            role: "caption"
                            dim: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Close button
                    Rectangle {
                        Layout.preferredWidth: Design.s(24)
                        Layout.preferredHeight: Design.s(24)
                        radius: width / 2
                        color: closeMa.containsMouse ? Design.raised : "transparent"
                        Layout.alignment: Qt.AlignTop

                        Icon {
                            anchors.centerIn: parent
                            text: "\u{f0156}"
                            role: "caption"
                            color: closeMa.containsMouse ? Design.danger : Design.textDim
                        }

                        Clickable {
                            id: closeMa
                            onClicked: Notifications.dismissToast(toastCard.index)
                        }
                    }
                }

                MouseArea {
                    id: toastMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
