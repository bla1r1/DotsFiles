import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property var wifiNetworksModel
    property string wifiPower: "off"
    property string wifiConnectedName: ""
    property string btPower: "off"
    property int btConnectedCount: 0
    property var bluetoothDevicesModel
    property string activeNetworkTab: "wifi"
    property real contentIntro: 1.0
    signal wifiPowerToggled()
    signal bluetoothPowerToggled()

    onActiveNetworkTabChanged: {
        contentIntro = 0.0;
        tabAnim.restart();
    }

    title: "Connectivity"
    subtitle: "Wi-Fi, Bluetooth and connected devices"

    NumberAnimation {
        id: tabAnim
        target: section
        property: "contentIntro"
        from: 0.0
        to: 1.0
        duration: 260
        easing.type: Easing.OutQuint
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.s(6)

        Repeater {
            model: [
                { id: "wifi", label: "Wi-Fi", icon: "󰤨", color: Design.accentSoft },
                { id: "bluetooth", label: "Bluetooth", icon: "󰂯", color: Design.accent },
                { id: "devices", label: "Devices", icon: "󰓃", color: Design.accent }
            ]

            delegate: Rectangle {
                id: networkTab
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(34)
                radius: Design.s(9)
                property bool active: section.activeNetworkTab === modelData.id
                color: active ? Qt.alpha(modelData.color, 0.22) : (tabArea.containsMouse ? Qt.alpha(Design.active, 0.35) : Design.raised)
                border.color: active ? modelData.color : Design.hover
                border.width: 1
                scale: tabArea.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Design.s(7)

                    Text { text: modelData.icon; color: networkTab.active ? modelData.color : Design.textDim; font.family: Design.font.icon; font.pixelSize: Design.s(15) }
                    Text { text: modelData.label; color: networkTab.active ? Design.text : Design.textDim; font.family: Design.font.mono; font.weight: networkTab.active ? Design.weight.semibold : Design.weight.medium; font.pixelSize: Design.s(11) }
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.activeNetworkTab = modelData.id
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Design.s(8)
        opacity: section.contentIntro
        scale: 0.985 + (0.015 * section.contentIntro)

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        RowLayout {
            visible: section.activeNetworkTab === "wifi"
            Layout.fillWidth: true
            DeviceRow { title: "Wi-Fi"; subtitle: section.wifiConnectedName.length > 0 ? section.wifiConnectedName : "Not connected"; value: section.wifiPower; valueTone: section.wifiPower === "on" ? Design.accentSoft : Design.danger; Layout.fillWidth: true }
            Pill { label: section.wifiPower === "on" ? "Turn Off" : "Turn On"; onClicked: section.wifiPowerToggled() }
        }

        Repeater {
            model: section.activeNetworkTab === "wifi" && section.wifiNetworksModel ? Math.min(section.wifiNetworksModel.count, 5) : 0
            delegate: DeviceRow {
                property var itemData: section.wifiNetworksModel.get(index)
                title: itemData.ssid || "Network"
                subtitle: itemData.security || ""
                value: (itemData.signal || "--") + "%"
                valueColor: Design.accentSoft
            }
        }

        RowLayout {
            visible: section.activeNetworkTab === "bluetooth"
            Layout.fillWidth: true
            DeviceRow { title: "Bluetooth"; subtitle: section.btConnectedCount > 0 ? section.btConnectedCount + " connected" : "No connected devices"; value: section.btPower; valueTone: section.btPower === "on" ? Design.accent : Design.danger; Layout.fillWidth: true }
            Pill { label: section.btPower === "on" ? "Turn Off" : "Turn On"; onClicked: section.bluetoothPowerToggled() }
        }

        Repeater {
            model: (section.activeNetworkTab === "bluetooth" || section.activeNetworkTab === "devices") && section.bluetoothDevicesModel ? Math.min(section.bluetoothDevicesModel.count, 6) : 0
            delegate: DeviceRow {
                property var itemData: section.bluetoothDevicesModel.get(index)
                title: itemData.name || "Bluetooth device"
                subtitle: itemData.profile || itemData.action || itemData.mac || ""
                value: itemData.battery && itemData.battery !== "0" ? itemData.battery + "%" : ""
                valueColor: Design.accent
            }
        }

        Text {
            visible: section.activeNetworkTab === "devices" && (!section.bluetoothDevicesModel || section.bluetoothDevicesModel.count === 0)
            text: "No connected Bluetooth devices listed"
            font.family: Design.font.mono
            font.pixelSize: Design.s(10)
            color: Design.textDim
            Layout.fillWidth: true
        }
    }
}
