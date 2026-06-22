import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property string wallpaperDir: ""
    property var suggestionsModel
    property color surface0Color: "#1e1e2e"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color accentColor: "#cba6f7"
    signal wallpaperDirChangedByUser(string value)
    signal pathQueryRequested(string value)
    signal accepted()
    signal suggestionsCleared()

    title: "Wallpaper directory"
    subtitle: "Absolute source path"
    backgroundColor: Qt.alpha(surface0Color, 0.5)
    borderColor: pathInput.activeFocus ? accentColor : surface1Color
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
            text: ""
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 20 * section.scaleFactor
            color: section.accentColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8 * section.scaleFactor

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * section.scaleFactor
                radius: 6 * section.scaleFactor
                color: section.surface0Color
                border.color: pathInput.activeFocus ? section.accentColor : section.surface2Color
                border.width: 1

                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.margins: 10 * section.scaleFactor
                    verticalAlignment: TextInput.AlignVCenter
                    text: section.wallpaperDir
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12 * section.scaleFactor
                    color: section.textColor
                    clip: true
                    selectByMouse: true
                    onTextChanged: {
                        section.wallpaperDirChangedByUser(text);
                        if (activeFocus)
                            section.pathQueryRequested(text);
                    }
                    onAccepted: section.accepted()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: pathInput.activeFocus && section.suggestionsModel && section.suggestionsModel.count > 0 ? section.suggestionsModel.count * 30 * section.scaleFactor : 0
                radius: 6 * section.scaleFactor
                color: section.surface0Color
                border.color: section.accentColor
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.suggestionsModel
                    interactive: false

                    delegate: Rectangle {
                        width: parent.width
                        height: 30 * section.scaleFactor
                        color: suggestionArea.containsMouse ? section.surface2Color : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12 * section.scaleFactor
                            text: model.path
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11 * section.scaleFactor
                            color: section.textColor
                            elide: Text.ElideMiddle
                            width: parent.width - (24 * section.scaleFactor)
                        }

                        MouseArea {
                            id: suggestionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pathInput.text = model.path;
                                section.suggestionsCleared();
                                pathInput.focus = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
