import QtQuick

Rectangle {
    id: button

    property string label: ""
    property real scaleFactor: 1.0
    property color baseColor: "#313244"
    property color hoverColor: "#45475a"
    property color borderColor: "#585b70"
    property color textColor: "#cdd6f4"
    signal clicked()

    implicitWidth: buttonText.implicitWidth + (22 * scaleFactor)
    implicitHeight: 30 * scaleFactor
    radius: 8 * scaleFactor
    color: area.containsMouse ? hoverColor : baseColor
    border.color: borderColor
    border.width: 1

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: button.label
        color: button.textColor
        font.family: "JetBrains Mono"
        font.weight: Font.Bold
        font.pixelSize: 11 * button.scaleFactor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
