import QtQuick
import "../../Ui"
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: section

    property string language: ""
    property string kbOptions: "grp:alt_shift_toggle"
    property string shortcutLabel: ""
    property var langSearchModel
    property var toggleOptions: []
    signal languageRemoved(int index)
    signal languageAdded(string code)
    signal searchChanged(string query)
    signal kbOptionsChangedByUser(string value)
    signal accepted()

    property bool shortcutOpen: false

    title: "Keyboard"
    subtitle: "Layouts and switch shortcut"

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.s(14)

        Text {
            Layout.preferredWidth: Design.s(24)
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Design.s(2)
            horizontalAlignment: Text.AlignHCenter
            text: "󰌌"
            font.family: Design.font.icon
            font.pixelSize: Design.s(20)
            color: Design.ok
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(8)

            Text {
                text: "Keyboard layouts"
                color: Design.text
                font.family: Design.font.mono
                font.weight: Design.weight.semibold
                font.pixelSize: Design.s(13)
                Layout.fillWidth: true
            }

            Text {
                text: "Matches config. Click X to remove."
                color: Design.textDim
                font.family: Design.font.mono
                font.pixelSize: Design.s(11)
                Layout.fillWidth: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: Design.s(8)

                Repeater {
                    model: section.language ? section.language.split(",").filter(x => x.trim() !== "") : []

                    Rectangle {
                        width: chipLayout.implicitWidth + Design.s(24)
                        height: Design.s(28)
                        radius: Design.s(14)
                        color: Design.raised
                        border.color: chipArea.containsMouse ? Design.danger : Design.hover
                        border.width: 1

                        RowLayout {
                            id: chipLayout
                            anchors.centerIn: parent
                            spacing: Design.s(8)

                            Text {
                                text: modelData
                                color: chipArea.containsMouse ? Design.danger : Design.text
                                font.family: Design.font.mono
                                font.weight: Design.weight.semibold
                                font.pixelSize: Design.s(12)
                            }

                            Text {
                                text: "x"
                                color: chipArea.containsMouse ? Design.danger : Design.textDim
                                font.family: Design.font.mono
                                font.pixelSize: Design.s(13)
                            }
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.languageRemoved(index)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(6)
                color: Design.surface
                border.color: langInput.activeFocus ? Design.ok : Design.hover
                border.width: 1

                TextInput {
                    id: langInput
                    anchors.fill: parent
                    anchors.margins: Design.s(10)
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Design.font.mono
                    font.pixelSize: Design.s(12)
                    color: Design.text
                    clip: true
                    selectByMouse: true
                    onTextChanged: section.searchChanged(text)
                    onAccepted: section.accepted()

                    Text {
                        text: "Search to add..."
                        color: Design.textDim
                        visible: !parent.text && !parent.activeFocus
                        font: parent.font
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: langInput.activeFocus && section.langSearchModel && section.langSearchModel.count > 0 ? Math.min(Design.s(150), section.langSearchModel.count * Design.s(32)) : 0
                radius: Design.s(6)
                color: Design.surface
                border.color: Design.ok
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.langSearchModel
                    interactive: true
                    ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: parent.width
                        height: Design.s(32)
                        color: searchArea.containsMouse ? Design.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(12)
                            anchors.rightMargin: Design.s(12)
                            spacing: Design.s(10)

                            Text {
                                text: model.code
                                color: Design.text
                                font.family: Design.font.mono
                                font.weight: Design.weight.semibold
                                font.pixelSize: Design.s(12)
                            }

                            Text {
                                text: model.name
                                color: Design.textDim
                                font.family: Design.font.mono
                                font.pixelSize: Design.s(11)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: searchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                section.languageAdded(model.code);
                                langInput.text = "";
                                langInput.focus = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.alpha(Design.raised, 0.5)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.s(14)

        Text {
            Layout.preferredWidth: Design.s(24)
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Design.s(2)
            horizontalAlignment: Text.AlignHCenter
            text: "󰯍"
            font.family: Design.font.icon
            font.pixelSize: Design.s(20)
            color: Qt.alpha(Design.ok, 0.7)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(8)

            Text {
                text: "Layout shortcut"
                color: Design.text
                font.family: Design.font.mono
                font.weight: Design.weight.semibold
                font.pixelSize: Design.s(13)
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(6)
                color: Design.surface
                border.color: section.shortcutOpen ? Design.ok : Design.hover
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(10)

                    Text {
                        text: section.shortcutLabel
                        color: Design.text
                        font.family: Design.font.mono
                        font.pixelSize: Design.s(12)
                        Layout.fillWidth: true
                    }

                    Text {
                        text: section.shortcutOpen ? "^" : "v"
                        color: Design.textDim
                        font.pixelSize: Design.s(14)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.shortcutOpen = !section.shortcutOpen
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: section.shortcutOpen ? section.toggleOptions.length * Design.s(32) : 0
                radius: Design.s(6)
                color: Design.surface
                border.color: Design.ok
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.toggleOptions
                    interactive: false

                    delegate: Rectangle {
                        width: parent.width
                        height: Design.s(32)
                        color: toggleArea.containsMouse ? Design.hover : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Design.s(12)
                            text: modelData.label
                            color: section.kbOptions === modelData.val ? Design.ok : Design.text
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(12)
                        }

                        MouseArea {
                            id: toggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                section.kbOptionsChangedByUser(modelData.val);
                                section.shortcutOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
