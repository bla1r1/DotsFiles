import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property var wifiNetworksModel
    property string wifiPower: "off"
    property string wifiConnectedName: ""
    property string btPower: "off"
    property int btConnectedCount: 0
    property color surface0Color: "#313244"
    property color surface1Color: "#45475a"
    property color surface2Color: "#585b70"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color wifiColor: "#74c7ec"
    property color btColor: "#89b4fa"
    property color dangerColor: "#f38ba8"
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
    backgroundColor: Qt.alpha(section.surface0Color, 0.5)
    borderColor: section.surface1Color
    titleColor: section.textColor
    subtitleColor: section.mutedColor

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
        spacing: 6 * section.scaleFactor

        Repeater {
            model: [
                { id: "wifi", label: "Wi-Fi", icon: "󰤨", color: section.wifiColor },
                { id: "bluetooth", label: "Bluetooth", icon: "󰂯", color: section.btColor },
                { id: "devices", label: "Devices", icon: "󰓃", color: section.btColor }
            ]

            delegate: Rectangle {
                id: networkTab
                Layout.fillWidth: true
                Layout.preferredHeight: 34 * section.scaleFactor
                radius: 9 * section.scaleFactor
                property bool active: section.activeNetworkTab === modelData.id
                color: active ? Qt.alpha(modelData.color, 0.22) : (tabArea.containsMouse ? Qt.alpha(section.surface2Color, 0.35) : section.surface0Color)
                border.color: active ? modelData.color : section.surface1Color
                border.width: 1
                scale: tabArea.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7 * section.scaleFactor

                    Text { text: modelData.icon; color: networkTab.active ? modelData.color : section.mutedColor; font.family: "Iosevka Nerd Font"; font.pixelSize: 15 * section.scaleFactor }
                    Text { text: modelData.label; color: networkTab.active ? section.textColor : section.mutedColor; font.family: "JetBrains Mono"; font.weight: networkTab.active ? Font.Bold : Font.Medium; font.pixelSize: 11 * section.scaleFactor }
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
        spacing: 8 * section.scaleFactor
        opacity: section.contentIntro
        scale: 0.985 + (0.015 * section.contentIntro)

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        RowLayout {
            visible: section.activeNetworkTab === "wifi"
            Layout.fillWidth: true
            SettingsUi.DeviceRow { title: "Wi-Fi"; subtitle: section.wifiConnectedName.length > 0 ? section.wifiConnectedName : "Not connected"; value: section.wifiPower; scaleFactor: section.scaleFactor; backgroundColor: Qt.alpha(section.surface0Color, 0.7); borderColor: section.wifiPower === "on" ? section.wifiColor : section.surface1Color; titleColor: section.textColor; subtitleColor: section.mutedColor; valueColor: section.wifiPower === "on" ? section.wifiColor : section.dangerColor; Layout.fillWidth: true }
            SettingsUi.PillButton { label: section.wifiPower === "on" ? "Turn Off" : "Turn On"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.wifiColor; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.wifiPowerToggled() }
        }

        Repeater {
            model: section.activeNetworkTab === "wifi" && section.wifiNetworksModel ? Math.min(section.wifiNetworksModel.count, 5) : 0
            delegate: SettingsUi.DeviceRow {
                property var itemData: section.wifiNetworksModel.get(index)
                title: itemData.ssid || "Network"
                subtitle: itemData.security || ""
                value: (itemData.signal || "--") + "%"
                scaleFactor: section.scaleFactor
                backgroundColor: Qt.alpha(section.surface0Color, 0.55)
                borderColor: section.surface1Color
                titleColor: section.textColor
                subtitleColor: section.mutedColor
                valueColor: section.wifiColor
            }
        }

        RowLayout {
            visible: section.activeNetworkTab === "bluetooth"
            Layout.fillWidth: true
            SettingsUi.DeviceRow { title: "Bluetooth"; subtitle: section.btConnectedCount > 0 ? section.btConnectedCount + " connected" : "No connected devices"; value: section.btPower; scaleFactor: section.scaleFactor; backgroundColor: Qt.alpha(section.surface0Color, 0.7); borderColor: section.btPower === "on" ? section.btColor : section.surface1Color; titleColor: section.textColor; subtitleColor: section.mutedColor; valueColor: section.btPower === "on" ? section.btColor : section.dangerColor; Layout.fillWidth: true }
            SettingsUi.PillButton { label: section.btPower === "on" ? "Turn Off" : "Turn On"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.btColor; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.bluetoothPowerToggled() }
        }

        Repeater {
            model: (section.activeNetworkTab === "bluetooth" || section.activeNetworkTab === "devices") && section.bluetoothDevicesModel ? Math.min(section.bluetoothDevicesModel.count, 6) : 0
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
                valueColor: section.btColor
            }
        }

        Text {
            visible: section.activeNetworkTab === "devices" && (!section.bluetoothDevicesModel || section.bluetoothDevicesModel.count === 0)
            text: "No connected Bluetooth devices listed"
            font.family: "JetBrains Mono"
            font.pixelSize: 10 * section.scaleFactor
            color: section.mutedColor
            Layout.fillWidth: true
        }
    }
}
