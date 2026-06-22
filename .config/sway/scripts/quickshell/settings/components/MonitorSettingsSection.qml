import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property var monitorModel
    property bool restoreSavedLayout: true
    property bool autoArrangeFallback: true
    property color baseColor: "#1e1e2e"
    property color surface0Color: "#313244"
    property color surface1Color: "#45475a"
    property color surface2Color: "#585b70"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color accentColor: "#a6e3a1"
    property string activeMonitorTab: "layout"
    signal refreshRequested()
    signal restoreSavedLayoutToggled()
    signal autoArrangeFallbackToggled()
    signal applyRequested()

    title: "Monitors"
    subtitle: "Layout moved here; the popup stays for brightness"
    backgroundColor: Qt.alpha(section.surface0Color, 0.5)
    borderColor: section.surface1Color
    titleColor: section.textColor
    subtitleColor: section.mutedColor

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Outputs"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 12 * section.scaleFactor; color: section.textColor; Layout.fillWidth: true }
        SettingsUi.PillButton { label: "Refresh"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.surface2Color; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.refreshRequested() }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Restore saved layout"; font.family: "JetBrains Mono"; font.pixelSize: 12 * section.scaleFactor; color: section.mutedColor; Layout.fillWidth: true }
        SettingsUi.PillButton { label: section.restoreSavedLayout ? "On" : "Off"; scaleFactor: section.scaleFactor; baseColor: section.restoreSavedLayout ? section.accentColor : section.surface1Color; hoverColor: section.surface2Color; borderColor: section.surface2Color; textColor: section.restoreSavedLayout ? section.baseColor : section.textColor; onClicked: section.restoreSavedLayoutToggled() }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Auto arrange fallback"; font.family: "JetBrains Mono"; font.pixelSize: 12 * section.scaleFactor; color: section.mutedColor; Layout.fillWidth: true }
        SettingsUi.PillButton { label: section.autoArrangeFallback ? "On" : "Off"; scaleFactor: section.scaleFactor; baseColor: section.autoArrangeFallback ? section.accentColor : section.surface1Color; hoverColor: section.surface2Color; borderColor: section.surface2Color; textColor: section.autoArrangeFallback ? section.baseColor : section.textColor; onClicked: section.autoArrangeFallbackToggled() }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(section.surface1Color, 0.5) }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 230 * section.scaleFactor
        radius: 12 * section.scaleFactor
        color: Qt.alpha(section.surface0Color, 0.55)
        border.color: Qt.alpha(section.surface2Color, 0.7)
        border.width: 1
        clip: true

        Grid {
            anchors.centerIn: parent
            rows: 11
            columns: 22
            spacing: 18 * section.scaleFactor
            opacity: 0.32

            Repeater {
                model: 242
                Rectangle {
                    width: 2 * section.scaleFactor
                    height: 2 * section.scaleFactor
                    radius: 1 * section.scaleFactor
                    color: Qt.alpha(section.textColor, 0.18)
                }
            }
        }

        Item {
            id: monitorMap
            anchors.fill: parent
            anchors.margins: 18 * section.scaleFactor

            property real minX: {
                if (!section.monitorModel || section.monitorModel.count === 0) return 0;
                let v = 999999;
                for (let i = 0; i < section.monitorModel.count; i++) {
                    let m = section.monitorModel.get(i);
                    v = Math.min(v, parseInt(m.x) || 0);
                }
                return v;
            }
            property real minY: {
                if (!section.monitorModel || section.monitorModel.count === 0) return 0;
                let v = 999999;
                for (let i = 0; i < section.monitorModel.count; i++) {
                    let m = section.monitorModel.get(i);
                    v = Math.min(v, parseInt(m.y) || 0);
                }
                return v;
            }
            property real maxX: {
                if (!section.monitorModel || section.monitorModel.count === 0) return 1;
                let v = -999999;
                for (let i = 0; i < section.monitorModel.count; i++) {
                    let m = section.monitorModel.get(i);
                    let scale = parseFloat(m.sysScale) || 1.0;
                    v = Math.max(v, (parseInt(m.x) || 0) + ((parseInt(m.resW) || 1920) / scale));
                }
                return v;
            }
            property real maxY: {
                if (!section.monitorModel || section.monitorModel.count === 0) return 1;
                let v = -999999;
                for (let i = 0; i < section.monitorModel.count; i++) {
                    let m = section.monitorModel.get(i);
                    let scale = parseFloat(m.sysScale) || 1.0;
                    v = Math.max(v, (parseInt(m.y) || 0) + ((parseInt(m.resH) || 1080) / scale));
                }
                return v;
            }
            property real mapScale: Math.min(width / Math.max(1, maxX - minX), height / Math.max(1, maxY - minY), 0.17 * section.scaleFactor)
            property real mapOffsetX: (width - ((maxX - minX) * mapScale)) / 2
            property real mapOffsetY: (height - ((maxY - minY) * mapScale)) / 2

            Behavior on mapOffsetX { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
            Behavior on mapOffsetY { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
            Behavior on mapScale { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }

            Repeater {
                model: section.monitorModel

                delegate: Rectangle {
                    id: previewCard
                    property real logicalW: (parseInt(model.resW) || 1920) / (parseFloat(model.sysScale) || 1.0)
                    property real logicalH: (parseInt(model.resH) || 1080) / (parseFloat(model.sysScale) || 1.0)
                    property bool focusedCard: model.focused === true

                    x: monitorMap.mapOffsetX + (((parseInt(model.x) || 0) - monitorMap.minX) * monitorMap.mapScale)
                    y: monitorMap.mapOffsetY + (((parseInt(model.y) || 0) - monitorMap.minY) * monitorMap.mapScale)
                    width: Math.max(88 * section.scaleFactor, logicalW * monitorMap.mapScale)
                    height: Math.max(50 * section.scaleFactor, logicalH * monitorMap.mapScale)
                    radius: 10 * section.scaleFactor
                    color: previewArea.drag.active ? Qt.alpha(section.accentColor, 0.22) : (previewArea.containsMouse ? Qt.alpha(section.surface2Color, 0.65) : Qt.alpha(section.baseColor, 0.88))
                    border.color: focusedCard || previewArea.containsMouse || previewArea.drag.active ? section.accentColor : section.surface2Color
                    border.width: focusedCard || previewArea.drag.active ? 2 : 1
                    z: previewArea.drag.active || focusedCard ? 10 : 1

                    Behavior on x { enabled: !previewArea.drag.active; NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                    Behavior on y { enabled: !previewArea.drag.active; NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Behavior on border.color { ColorAnimation { duration: 220 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2 * section.scaleFactor

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰍹"
                            color: previewCard.focusedCard ? section.accentColor : section.textColor
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 22 * section.scaleFactor
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: model.name
                            color: section.textColor
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 10 * section.scaleFactor
                            elide: Text.ElideRight
                            Layout.maximumWidth: previewCard.width - (18 * section.scaleFactor)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (parseInt(model.x) || 0) + "," + (parseInt(model.y) || 0)
                            color: section.mutedColor
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8 * section.scaleFactor
                        }
                    }

                    MouseArea {
                        id: previewArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.OpenHandCursor
                        drag.target: previewCard
                        drag.axis: Drag.XAndYAxis

                        onPressed: cursorShape = Qt.ClosedHandCursor
                        onReleased: {
                            cursorShape = Qt.OpenHandCursor;
                            let newX = Math.round(((previewCard.x - monitorMap.mapOffsetX) / monitorMap.mapScale) + monitorMap.minX);
                            let newY = Math.round(((previewCard.y - monitorMap.mapOffsetY) / monitorMap.mapScale) + monitorMap.minY);
                            let snap = 50;
                            section.monitorModel.setProperty(index, "x", Math.round(newX / snap) * snap);
                            section.monitorModel.setProperty(index, "y", Math.round(newY / snap) * snap);
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6 * section.scaleFactor

        Repeater {
            model: [
                { id: "layout", label: "Layout", icon: "󰍹" },
                { id: "workspaces", label: "Workspaces", icon: "󰈹" }
            ]

            delegate: Rectangle {
                id: monitorTab
                Layout.fillWidth: true
                Layout.preferredHeight: 34 * section.scaleFactor
                radius: 9 * section.scaleFactor
                property bool active: section.activeMonitorTab === modelData.id
                color: active ? Qt.alpha(section.accentColor, 0.22) : (monitorTabArea.containsMouse ? Qt.alpha(section.surface2Color, 0.35) : section.surface0Color)
                border.color: active ? section.accentColor : section.surface1Color
                border.width: 1
                scale: monitorTabArea.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7 * section.scaleFactor

                    Text {
                        text: modelData.icon
                        color: monitorTab.active ? section.accentColor : section.mutedColor
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 15 * section.scaleFactor
                    }

                    Text {
                        text: modelData.label
                        color: monitorTab.active ? section.textColor : section.mutedColor
                        font.family: "JetBrains Mono"
                        font.weight: monitorTab.active ? Font.Bold : Font.Medium
                        font.pixelSize: 11 * section.scaleFactor
                    }
                }

                MouseArea {
                    id: monitorTabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.activeMonitorTab = modelData.id
                }
            }
        }
    }

    Repeater {
        model: section.monitorModel
        delegate: Rectangle {
            id: monitorCard
            Layout.fillWidth: true
            Layout.preferredHeight: monitorEditCol.implicitHeight + (18 * section.scaleFactor)
            radius: 10 * section.scaleFactor
            color: monitorArea.containsMouse ? Qt.alpha(section.surface0Color, 0.82) : Qt.alpha(section.surface0Color, 0.65)
            border.color: model.focused || monitorArea.containsMouse ? section.accentColor : section.surface1Color
            border.width: 1
            opacity: entryIntro
            scale: 0.985 + (0.015 * entryIntro)
            property real entryIntro: 0.0

            Component.onCompleted: entryAnim.start()

            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on border.color { ColorAnimation { duration: 220 } }

            NumberAnimation {
                id: entryAnim
                target: monitorCard
                property: "entryIntro"
                from: 0.0
                to: 1.0
                duration: 420 + (index * 60)
                easing.type: Easing.OutQuint
            }

            MouseArea {
                id: monitorArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            ColumnLayout {
                id: monitorEditCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10 * section.scaleFactor
                spacing: 8 * section.scaleFactor

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: model.name; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 12 * section.scaleFactor; color: section.textColor; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { text: model.focused ? "focused" : ""; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor; color: section.accentColor }
                }

                GridLayout {
                    visible: section.activeMonitorTab === "layout"
                    Layout.fillWidth: true
                    columns: 8
                    columnSpacing: 8 * section.scaleFactor
                    rowSpacing: 6 * section.scaleFactor

                    Text { text: "W"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor }
                    TextInput { text: model.resW.toString(); color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; validator: IntValidator { bottom: 320; top: 10000 } onTextChanged: section.monitorModel.setProperty(index, "resW", parseInt(text || "1920")) }
                    Text { text: "H"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor }
                    TextInput { text: model.resH.toString(); color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; validator: IntValidator { bottom: 240; top: 10000 } onTextChanged: section.monitorModel.setProperty(index, "resH", parseInt(text || "1080")) }
                    Text { text: "Hz"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor }
                    TextInput { text: model.rate.toString(); color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; validator: IntValidator { bottom: 24; top: 500 } onTextChanged: section.monitorModel.setProperty(index, "rate", text || "60") }
                    Text { text: "Scale"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor }
                    TextInput { text: model.sysScale.toString(); color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; validator: DoubleValidator { bottom: 0.5; top: 4.0; decimals: 2 } onTextChanged: section.monitorModel.setProperty(index, "sysScale", parseFloat(text || "1")) }

                    Text { text: "X"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor }
                    TextInput { text: model.x.toString(); color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; validator: IntValidator { bottom: -20000; top: 20000 } onTextChanged: section.monitorModel.setProperty(index, "x", parseInt(text || "0")) }
                    Text { text: "Y"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor }
                    TextInput { text: model.y.toString(); color: section.textColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; validator: IntValidator { bottom: -20000; top: 20000 } onTextChanged: section.monitorModel.setProperty(index, "y", parseInt(text || "0")) }
                    Item { Layout.fillWidth: true }
                    Item { Layout.fillWidth: true }
                    Item { Layout.fillWidth: true }
                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    visible: section.activeMonitorTab === "workspaces"
                    Layout.fillWidth: true
                    spacing: 8 * section.scaleFactor

                    Text {
                        text: "Workspaces"
                        color: section.mutedColor
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10 * section.scaleFactor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32 * section.scaleFactor
                        radius: 7 * section.scaleFactor
                        color: section.surface0Color
                        border.color: workspaceInput.activeFocus ? section.accentColor : section.surface2Color
                        border.width: 1

                        TextInput {
                            id: workspaceInput
                            anchors.fill: parent
                            anchors.margins: 8 * section.scaleFactor
                            verticalAlignment: TextInput.AlignVCenter
                            text: model.workspaces || ""
                            color: section.textColor
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11 * section.scaleFactor
                            selectByMouse: true
                            clip: true
                            onTextChanged: section.monitorModel.setProperty(index, "workspaces", text)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "1,2,3"
                                color: section.mutedColor
                                font: parent.font
                                visible: !parent.text && !parent.activeFocus
                            }
                        }
                    }
                }
            }
        }
    }

    Text { visible: !section.monitorModel || section.monitorModel.count === 0; text: "No active Sway outputs found"; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor; color: section.mutedColor; Layout.fillWidth: true }

    SettingsUi.PillButton { Layout.fillWidth: true; label: "Apply Monitor Layout"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.accentColor; borderColor: section.accentColor; textColor: section.textColor; onClicked: section.applyRequested() }
}
