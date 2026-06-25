import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property var bluetoothDevicesModel
    property string keyboardLayouts: ""
    property string keyboardShortcutLabel: ""

    title: "Devices"
    subtitle: "Input and connected device summary"

    DeviceRow { title: "Keyboard layouts"; subtitle: section.keyboardShortcutLabel; value: section.keyboardLayouts; valueTone: Design.ok }

    Repeater {
        model: section.bluetoothDevicesModel ? Math.min(section.bluetoothDevicesModel.count, 5) : 0
        delegate: DeviceRow {
            property var itemData: section.bluetoothDevicesModel.get(index)
            title: itemData.name || "Bluetooth device"
            subtitle: itemData.profile || itemData.action || itemData.mac || ""
            value: itemData.battery && itemData.battery !== "0" ? itemData.battery + "%" : ""
            valueColor: Design.accent
        }
    }

    Text { visible: !section.bluetoothDevicesModel || section.bluetoothDevicesModel.count === 0; text: "No Bluetooth devices listed"; font.family: Design.font.mono; font.pixelSize: Design.s(10); color: Design.textDim; Layout.fillWidth: true }
}
