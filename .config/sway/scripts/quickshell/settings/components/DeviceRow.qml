import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row

    property string title: ""
    property string subtitle: ""
    property string value: ""
    property real scaleFactor: 1.0
    property color backgroundColor: "#181825"
    property color borderColor: "#313244"
    property color titleColor: "#cdd6f4"
    property color subtitleColor: "#a6adc8"
    property color valueColor: "#89b4fa"

    Layout.fillWidth: true
    Layout.preferredHeight: 46 * scaleFactor
    radius: 9 * scaleFactor
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12 * row.scaleFactor
        anchors.rightMargin: 12 * row.scaleFactor
        spacing: 10 * row.scaleFactor

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * row.scaleFactor

            Text {
                text: row.title
                color: row.titleColor
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: 11 * row.scaleFactor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: row.subtitle
                visible: text.length > 0
                color: row.subtitleColor
                font.family: "JetBrains Mono"
                font.pixelSize: 9 * row.scaleFactor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Text {
            text: row.value
            color: row.valueColor
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: 10 * row.scaleFactor
        }
    }
}
