import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property string apiKey: ""
    property string cityId: ""
    property string unit: "metric"
    property color surface0Color: "#313244"
    property color surface1Color: "#45475a"
    property color surface2Color: "#585b70"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color accentColor: "#74c7ec"
    signal apiKeyChangedByUser(string value)
    signal cityIdChangedByUser(string value)
    signal unitChangedByUser(string value)

    title: "Weather"
    subtitle: "Shared weather provider settings"
    backgroundColor: Qt.alpha(section.surface0Color, 0.5)
    borderColor: section.surface1Color
    titleColor: section.textColor
    subtitleColor: section.mutedColor

    TextInput {
        Layout.fillWidth: true
        text: section.apiKey
        echoMode: TextInput.Password
        color: section.textColor
        font.family: "JetBrains Mono"
        font.pixelSize: 12 * section.scaleFactor
        selectByMouse: true
        onTextChanged: section.apiKeyChangedByUser(text)
        Text { text: "OpenWeather API key"; color: section.mutedColor; visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; font: parent.font }
    }

    TextInput {
        Layout.fillWidth: true
        text: section.cityId
        color: section.textColor
        font.family: "JetBrains Mono"
        font.pixelSize: 12 * section.scaleFactor
        selectByMouse: true
        onTextChanged: section.cityIdChangedByUser(text)
        Text { text: "City ID"; color: section.mutedColor; visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; font: parent.font }
    }

    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["metric", "imperial"]
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30 * section.scaleFactor
                radius: 8 * section.scaleFactor
                color: section.unit === modelData ? Qt.alpha(section.accentColor, 0.25) : section.surface1Color
                border.color: section.unit === modelData ? section.accentColor : section.surface2Color
                Text { anchors.centerIn: parent; text: modelData; color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: section.unitChangedByUser(modelData) }
            }
        }
    }
}
