import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property string apiKey: ""
    property string cityId: ""
    property string unit: "metric"
    signal apiKeyChangedByUser(string value)
    signal cityIdChangedByUser(string value)
    signal unitChangedByUser(string value)

    title: "Weather"
    subtitle: "Shared weather provider settings"

    TextInput {
        Layout.fillWidth: true
        text: section.apiKey
        echoMode: TextInput.Password
        color: Design.text
        font.family: Design.font.mono
        font.pixelSize: Design.s(12)
        selectByMouse: true
        onTextChanged: section.apiKeyChangedByUser(text)
        Text { text: "OpenWeather API key"; color: Design.textDim; visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; font: parent.font }
    }

    TextInput {
        Layout.fillWidth: true
        text: section.cityId
        color: Design.text
        font.family: Design.font.mono
        font.pixelSize: Design.s(12)
        selectByMouse: true
        onTextChanged: section.cityIdChangedByUser(text)
        Text { text: "City ID"; color: Design.textDim; visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; font: parent.font }
    }

    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["metric", "imperial"]
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(30)
                radius: Design.s(8)
                color: section.unit === modelData ? Qt.alpha(Design.accentSoft, 0.25) : Design.hover
                border.color: section.unit === modelData ? Design.accentSoft : Design.active
                Text { anchors.centerIn: parent; text: modelData; color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: section.unitChangedByUser(modelData) }
            }
        }
    }
}
