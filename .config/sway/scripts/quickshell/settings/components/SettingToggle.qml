import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool checked: false
    property real scaleFactor: 1.0
    property color accentColor: "#89b4fa"
    property color surface2Color: "#45475a"
    property color baseColor: "#11111b"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    signal toggled()

    Layout.fillWidth: true
    spacing: 14 * scaleFactor

    Text {
        Layout.preferredWidth: 24 * row.scaleFactor
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 2 * row.scaleFactor
        horizontalAlignment: Text.AlignHCenter
        text: row.icon
        font.family: "Iosevka Nerd Font"
        font.pixelSize: 20 * row.scaleFactor
        color: row.accentColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4 * row.scaleFactor

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: row.label
                color: row.textColor
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: 13 * row.scaleFactor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 40 * row.scaleFactor
                Layout.preferredHeight: 24 * row.scaleFactor
                radius: 12 * row.scaleFactor
                color: row.checked ? row.accentColor : row.surface2Color

                Behavior on color { ColorAnimation { duration: 180 } }

                Rectangle {
                    width: 18 * row.scaleFactor
                    height: 18 * row.scaleFactor
                    radius: 9 * row.scaleFactor
                    color: row.baseColor
                    y: 3 * row.scaleFactor
                    x: row.checked ? 19 * row.scaleFactor : 3 * row.scaleFactor
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.toggled()
                }
            }
        }

        Text {
            text: row.subtitle
            visible: row.subtitle.length > 0
            color: row.mutedColor
            font.family: "JetBrains Mono"
            font.pixelSize: 11 * row.scaleFactor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
