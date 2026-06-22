import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    property real scaleFactor: 1.0
    property color backgroundColor: "#1e1e2e"
    property color borderColor: "#313244"
    property color titleColor: "#cdd6f4"
    property color subtitleColor: "#a6adc8"
    default property alias content: body.data

    Layout.fillWidth: true
    Layout.preferredHeight: contentColumn.implicitHeight + (28 * scaleFactor)
    radius: 12 * scaleFactor
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14 * card.scaleFactor
        spacing: 10 * card.scaleFactor

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3 * card.scaleFactor

            Text {
                text: card.title
                visible: text.length > 0
                color: card.titleColor
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: 13 * card.scaleFactor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: card.subtitle
                visible: text.length > 0
                color: card.subtitleColor
                font.family: "JetBrains Mono"
                font.pixelSize: 10 * card.scaleFactor
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 8 * card.scaleFactor
        }
    }
}
