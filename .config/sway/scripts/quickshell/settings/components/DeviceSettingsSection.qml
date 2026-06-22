import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property var bluetoothDevicesModel
    property string keyboardLayouts: ""
    property string keyboardShortcutLabel: ""
    property color surface0Color: "#313244"
    property color surface1Color: "#45475a"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color keyboardColor: "#a6e3a1"
    property color deviceColor: "#89b4fa"

    title: "Devices"
    subtitle: "Input and connected device summary"
    backgroundColor: Qt.alpha(section.surface0Color, 0.5)
    borderColor: section.surface1Color
    titleColor: section.textColor
    subtitleColor: section.mutedColor

    SettingsUi.DeviceRow { title: "Keyboard layouts"; subtitle: section.keyboardShortcutLabel; value: section.keyboardLayouts; scaleFactor: section.scaleFactor; backgroundColor: Qt.alpha(section.surface0Color, 0.7); borderColor: section.keyboardColor; titleColor: section.textColor; subtitleColor: section.mutedColor; valueColor: section.keyboardColor }

    Repeater {
        model: section.bluetoothDevicesModel ? Math.min(section.bluetoothDevicesModel.count, 5) : 0
        delegate: SettingsUi.DeviceRow {
            property var itemData: section.bluetoothDevicesModel.get(index)
            title: itemData.name || "Bluetooth device"
            subtitle: itemData.profile || itemData.action || itemData.mac || ""
            value: itemData.battery && itemData.battery !== "0" ? itemData.battery + "%" : ""
            scaleFactor: section.scaleFactor
            backgroundColor: Qt.alpha(section.surface0Color, 0.55)
            borderColor: section.surface1Color
            titleColor: section.textColor
            subtitleColor: section.mutedColor
            valueColor: section.deviceColor
        }
    }

    Text { visible: !section.bluetoothDevicesModel || section.bluetoothDevicesModel.count === 0; text: "No Bluetooth devices listed"; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor; color: section.mutedColor; Layout.fillWidth: true }
}
