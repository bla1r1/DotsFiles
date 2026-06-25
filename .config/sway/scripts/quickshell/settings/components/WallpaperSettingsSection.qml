import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property string wallpaperDir: ""
    property var suggestionsModel
    signal wallpaperDirChangedByUser(string value)
    signal pathQueryRequested(string value)
    signal accepted()
    signal suggestionsCleared()

    title: "Wallpaper directory"
    subtitle: "Absolute source path"

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.s(14)

        Text {
            Layout.preferredWidth: Design.s(24)
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Design.s(2)
            horizontalAlignment: Text.AlignHCenter
            text: ""
            font.family: Design.font.icon
            font.pixelSize: Design.s(20)
            color: Design.accentAlt
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(8)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(6)
                color: Design.surface
                border.color: pathInput.activeFocus ? Design.accentAlt : Design.hover
                border.width: 1

                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.margins: Design.s(10)
                    verticalAlignment: TextInput.AlignVCenter
                    text: section.wallpaperDir
                    font.family: Design.font.mono
                    font.pixelSize: Design.s(12)
                    color: Design.text
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
                Layout.preferredHeight: pathInput.activeFocus && section.suggestionsModel && section.suggestionsModel.count > 0 ? section.suggestionsModel.count * Design.s(30) : 0
                radius: Design.s(6)
                color: Design.surface
                border.color: Design.accentAlt
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.suggestionsModel
                    interactive: false

                    delegate: Rectangle {
                        width: parent.width
                        height: Design.s(30)
                        color: suggestionArea.containsMouse ? Design.hover : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Design.s(12)
                            text: model.path
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(11)
                            color: Design.text
                            elide: Text.ElideMiddle
                            width: parent.width - (Design.s(24))
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
