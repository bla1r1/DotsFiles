import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property var monitorModel
    property bool restoreSavedLayout: true
    property bool autoArrangeFallback: true
    property string activeMonitorTab: "layout"
    signal refreshRequested()
    signal restoreSavedLayoutToggled()
    signal autoArrangeFallbackToggled()
    signal applyRequested()

    title: "Monitors"
    subtitle: "Layout moved here; the popup stays for brightness"

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Outputs"; font.family: Design.font.mono; font.weight: Design.weight.semibold; font.pixelSize: Design.s(12); color: Design.text; Layout.fillWidth: true }
        Pill { label: "Refresh"; onClicked: section.refreshRequested() }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Restore saved layout"; font.family: Design.font.mono; font.pixelSize: Design.s(12); color: Design.textDim; Layout.fillWidth: true }
        Pill { label: section.restoreSavedLayout ? "On" : "Off"; onClicked: section.restoreSavedLayoutToggled() }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Auto arrange fallback"; font.family: Design.font.mono; font.pixelSize: Design.s(12); color: Design.textDim; Layout.fillWidth: true }
        Pill { label: section.autoArrangeFallback ? "On" : "Off"; onClicked: section.autoArrangeFallbackToggled() }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Design.hover, 0.5) }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Design.s(230)
        radius: Design.s(12)
        color: Qt.alpha(Design.raised, 0.55)
        border.color: Qt.alpha(Design.active, 0.7)
        border.width: 1
        clip: true

        Grid {
            anchors.centerIn: parent
            rows: 11
            columns: 22
            spacing: Design.s(18)
            opacity: 0.32

            Repeater {
                model: 242
                Rectangle {
                    width: Design.s(2)
                    height: Design.s(2)
                    radius: Design.s(1)
                    color: Qt.alpha(Design.text, 0.18)
                }
            }
        }

        Item {
            id: monitorMap
            anchors.fill: parent
            anchors.margins: Design.s(18)

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
            property real mapScale: Math.min(width / Math.max(1, maxX - minX), height / Math.max(1, maxY - minY), Design.s(0.17))
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
                    width: Math.max(Design.s(88), logicalW * monitorMap.mapScale)
                    height: Math.max(Design.s(50), logicalH * monitorMap.mapScale)
                    radius: Design.s(10)
                    color: previewArea.drag.active ? Qt.alpha(Design.ok, 0.22) : (previewArea.containsMouse ? Qt.alpha(Design.active, 0.65) : Qt.alpha(Design.surface, 0.88))
                    border.color: focusedCard || previewArea.containsMouse || previewArea.drag.active ? Design.ok : Design.active
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
                        spacing: Design.s(2)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰍹"
                            color: previewCard.focusedCard ? Design.ok : Design.text
                            font.family: Design.font.icon
                            font.pixelSize: Design.s(22)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: model.name
                            color: Design.text
                            font.family: Design.font.mono
                            font.weight: Design.weight.semibold
                            font.pixelSize: Design.s(10)
                            elide: Text.ElideRight
                            Layout.maximumWidth: previewCard.width - (Design.s(18))
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (parseInt(model.x) || 0) + "," + (parseInt(model.y) || 0)
                            color: Design.textDim
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(8)
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
        spacing: Design.s(6)

        Repeater {
            model: [
                { id: "layout", label: "Layout", icon: "󰍹" },
                { id: "workspaces", label: "Workspaces", icon: "󰈹" }
            ]

            delegate: Rectangle {
                id: monitorTab
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(34)
                radius: Design.s(9)
                property bool active: section.activeMonitorTab === modelData.id
                color: active ? Qt.alpha(Design.ok, 0.22) : (monitorTabArea.containsMouse ? Qt.alpha(Design.active, 0.35) : Design.raised)
                border.color: active ? Design.ok : Design.hover
                border.width: 1
                scale: monitorTabArea.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Design.s(7)

                    Text {
                        text: modelData.icon
                        color: monitorTab.active ? Design.ok : Design.textDim
                        font.family: Design.font.icon
                        font.pixelSize: Design.s(15)
                    }

                    Text {
                        text: modelData.label
                        color: monitorTab.active ? Design.text : Design.textDim
                        font.family: Design.font.mono
                        font.weight: monitorTab.active ? Design.weight.semibold : Design.weight.medium
                        font.pixelSize: Design.s(11)
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
            Layout.preferredHeight: monitorEditCol.implicitHeight + (Design.s(18))
            radius: Design.s(10)
            color: monitorArea.containsMouse ? Qt.alpha(Design.raised, 0.82) : Qt.alpha(Design.raised, 0.65)
            border.color: model.focused || monitorArea.containsMouse ? Design.ok : Design.hover
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
                anchors.margins: Design.s(10)
                spacing: Design.s(8)

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: model.name; font.family: Design.font.mono; font.weight: Design.weight.semibold; font.pixelSize: Design.s(12); color: Design.text; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { text: model.focused ? "focused" : ""; font.family: Design.font.mono; font.pixelSize: Design.s(10); color: Design.ok }
                }

                GridLayout {
                    visible: section.activeMonitorTab === "layout"
                    Layout.fillWidth: true
                    columns: 8
                    columnSpacing: Design.s(8)
                    rowSpacing: Design.s(6)

                    Text { text: "W"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(10) }
                    TextInput { text: model.resW.toString(); color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11); validator: IntValidator { bottom: 320; top: 10000 } onTextChanged: section.monitorModel.setProperty(index, "resW", parseInt(text || "1920")) }
                    Text { text: "H"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(10) }
                    TextInput { text: model.resH.toString(); color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11); validator: IntValidator { bottom: 240; top: 10000 } onTextChanged: section.monitorModel.setProperty(index, "resH", parseInt(text || "1080")) }
                    Text { text: "Hz"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(10) }
                    TextInput { text: model.rate.toString(); color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11); validator: IntValidator { bottom: 24; top: 500 } onTextChanged: section.monitorModel.setProperty(index, "rate", text || "60") }
                    Text { text: "Scale"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(10) }
                    TextInput { text: model.sysScale.toString(); color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11); validator: DoubleValidator { bottom: 0.5; top: 4.0; decimals: 2 } onTextChanged: section.monitorModel.setProperty(index, "sysScale", parseFloat(text || "1")) }

                    Text { text: "X"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(10) }
                    TextInput { text: model.x.toString(); color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11); validator: IntValidator { bottom: -20000; top: 20000 } onTextChanged: section.monitorModel.setProperty(index, "x", parseInt(text || "0")) }
                    Text { text: "Y"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(10) }
                    TextInput { text: model.y.toString(); color: Design.text; font.family: Design.font.mono; font.pixelSize: Design.s(11); validator: IntValidator { bottom: -20000; top: 20000 } onTextChanged: section.monitorModel.setProperty(index, "y", parseInt(text || "0")) }
                    Item { Layout.fillWidth: true }
                    Item { Layout.fillWidth: true }
                    Item { Layout.fillWidth: true }
                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    visible: section.activeMonitorTab === "workspaces"
                    Layout.fillWidth: true
                    spacing: Design.s(8)

                    Text {
                        text: "Workspaces"
                        color: Design.textDim
                        font.family: Design.font.mono
                        font.pixelSize: Design.s(10)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(32)
                        radius: Design.s(7)
                        color: Design.raised
                        border.color: workspaceInput.activeFocus ? Design.ok : Design.active
                        border.width: 1

                        TextInput {
                            id: workspaceInput
                            anchors.fill: parent
                            anchors.margins: Design.s(8)
                            verticalAlignment: TextInput.AlignVCenter
                            text: model.workspaces || ""
                            color: Design.text
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(11)
                            selectByMouse: true
                            clip: true
                            onTextChanged: section.monitorModel.setProperty(index, "workspaces", text)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "1,2,3"
                                color: Design.textDim
                                font: parent.font
                                visible: !parent.text && !parent.activeFocus
                            }
                        }
                    }
                }
            }
        }
    }

    Text { visible: !section.monitorModel || section.monitorModel.count === 0; text: "No active Sway outputs found"; font.family: Design.font.mono; font.pixelSize: Design.s(11); color: Design.textDim; Layout.fillWidth: true }

    Pill { Layout.fillWidth: true; label: "Apply Monitor Layout"; onClicked: section.applyRequested() }
}
