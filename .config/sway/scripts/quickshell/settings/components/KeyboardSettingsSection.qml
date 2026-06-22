import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property string language: ""
    property string kbOptions: "grp:alt_shift_toggle"
    property string shortcutLabel: ""
    property var langSearchModel
    property var toggleOptions: []
    property color surface0Color: "#1e1e2e"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color accentColor: "#a6e3a1"
    property color dangerColor: "#f38ba8"
    signal languageRemoved(int index)
    signal languageAdded(string code)
    signal searchChanged(string query)
    signal kbOptionsChangedByUser(string value)
    signal accepted()

    property bool shortcutOpen: false

    title: "Keyboard"
    subtitle: "Layouts and switch shortcut"
    backgroundColor: Qt.alpha(surface0Color, 0.5)
    borderColor: surface1Color
    titleColor: textColor
    subtitleColor: mutedColor

    RowLayout {
        Layout.fillWidth: true
        spacing: 14 * section.scaleFactor

        Text {
            Layout.preferredWidth: 24 * section.scaleFactor
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2 * section.scaleFactor
            horizontalAlignment: Text.AlignHCenter
            text: "󰌌"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 20 * section.scaleFactor
            color: section.accentColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8 * section.scaleFactor

            Text {
                text: "Keyboard layouts"
                color: section.textColor
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: 13 * section.scaleFactor
                Layout.fillWidth: true
            }

            Text {
                text: "Matches config. Click X to remove."
                color: section.mutedColor
                font.family: "JetBrains Mono"
                font.pixelSize: 11 * section.scaleFactor
                Layout.fillWidth: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8 * section.scaleFactor

                Repeater {
                    model: section.language ? section.language.split(",").filter(x => x.trim() !== "") : []

                    Rectangle {
                        width: chipLayout.implicitWidth + 24 * section.scaleFactor
                        height: 28 * section.scaleFactor
                        radius: 14 * section.scaleFactor
                        color: section.surface1Color
                        border.color: chipArea.containsMouse ? section.dangerColor : section.surface2Color
                        border.width: 1

                        RowLayout {
                            id: chipLayout
                            anchors.centerIn: parent
                            spacing: 8 * section.scaleFactor

                            Text {
                                text: modelData
                                color: chipArea.containsMouse ? section.dangerColor : section.textColor
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: 12 * section.scaleFactor
                            }

                            Text {
                                text: "x"
                                color: chipArea.containsMouse ? section.dangerColor : section.mutedColor
                                font.family: "JetBrains Mono"
                                font.pixelSize: 13 * section.scaleFactor
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
                Layout.preferredHeight: 36 * section.scaleFactor
                radius: 6 * section.scaleFactor
                color: section.surface0Color
                border.color: langInput.activeFocus ? section.accentColor : section.surface2Color
                border.width: 1

                TextInput {
                    id: langInput
                    anchors.fill: parent
                    anchors.margins: 10 * section.scaleFactor
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12 * section.scaleFactor
                    color: section.textColor
                    clip: true
                    selectByMouse: true
                    onTextChanged: section.searchChanged(text)
                    onAccepted: section.accepted()

                    Text {
                        text: "Search to add..."
                        color: section.mutedColor
                        visible: !parent.text && !parent.activeFocus
                        font: parent.font
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: langInput.activeFocus && section.langSearchModel && section.langSearchModel.count > 0 ? Math.min(150 * section.scaleFactor, section.langSearchModel.count * 32 * section.scaleFactor) : 0
                radius: 6 * section.scaleFactor
                color: section.surface0Color
                border.color: section.accentColor
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
                        height: 32 * section.scaleFactor
                        color: searchArea.containsMouse ? section.surface2Color : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12 * section.scaleFactor
                            anchors.rightMargin: 12 * section.scaleFactor
                            spacing: 10 * section.scaleFactor

                            Text {
                                text: model.code
                                color: section.textColor
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: 12 * section.scaleFactor
                            }

                            Text {
                                text: model.name
                                color: section.mutedColor
                                font.family: "JetBrains Mono"
                                font.pixelSize: 11 * section.scaleFactor
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
        color: Qt.alpha(section.surface1Color, 0.5)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14 * section.scaleFactor

        Text {
            Layout.preferredWidth: 24 * section.scaleFactor
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2 * section.scaleFactor
            horizontalAlignment: Text.AlignHCenter
            text: "󰯍"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 20 * section.scaleFactor
            color: Qt.alpha(section.accentColor, 0.7)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8 * section.scaleFactor

            Text {
                text: "Layout shortcut"
                color: section.textColor
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: 13 * section.scaleFactor
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * section.scaleFactor
                radius: 6 * section.scaleFactor
                color: section.surface0Color
                border.color: section.shortcutOpen ? section.accentColor : section.surface2Color
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10 * section.scaleFactor

                    Text {
                        text: section.shortcutLabel
                        color: section.textColor
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12 * section.scaleFactor
                        Layout.fillWidth: true
                    }

                    Text {
                        text: section.shortcutOpen ? "^" : "v"
                        color: section.mutedColor
                        font.pixelSize: 14 * section.scaleFactor
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
                Layout.preferredHeight: section.shortcutOpen ? section.toggleOptions.length * 32 * section.scaleFactor : 0
                radius: 6 * section.scaleFactor
                color: section.surface0Color
                border.color: section.accentColor
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.toggleOptions
                    interactive: false

                    delegate: Rectangle {
                        width: parent.width
                        height: 32 * section.scaleFactor
                        color: toggleArea.containsMouse ? section.surface2Color : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12 * section.scaleFactor
                            text: modelData.label
                            color: section.kbOptions === modelData.val ? section.accentColor : section.textColor
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12 * section.scaleFactor
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
