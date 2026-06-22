import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row

    property string label: ""
    property string valueText: ""
    property real scaleFactor: 1.0
    property color accentColor: "#89b4fa"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    signal decrement()
    signal increment()

    Layout.fillWidth: true
    spacing: 10 * scaleFactor

    Text {
        text: row.label
        color: row.mutedColor
        font.family: "JetBrains Mono"
        font.pixelSize: 12 * row.scaleFactor
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    Rectangle {
        Layout.preferredWidth: 30 * row.scaleFactor
        Layout.preferredHeight: 30 * row.scaleFactor
        radius: 8 * row.scaleFactor
        color: minusArea.pressed ? row.surface2Color : row.surface1Color
        border.color: minusArea.containsMouse ? row.accentColor : "transparent"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "-"
            color: row.textColor
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: 16 * row.scaleFactor
        }

        MouseArea {
            id: minusArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.decrement()
        }
    }

    Text {
        text: row.valueText
        color: row.accentColor
        font.family: "JetBrains Mono"
        font.weight: Font.Bold
        font.pixelSize: 12 * row.scaleFactor
        Layout.minimumWidth: 44 * row.scaleFactor
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        Layout.preferredWidth: 30 * row.scaleFactor
        Layout.preferredHeight: 30 * row.scaleFactor
        radius: 8 * row.scaleFactor
        color: plusArea.pressed ? row.surface2Color : row.surface1Color
        border.color: plusArea.containsMouse ? row.accentColor : "transparent"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "+"
            color: row.textColor
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: 16 * row.scaleFactor
        }

        MouseArea {
            id: plusArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.increment()
        }
    }
}
