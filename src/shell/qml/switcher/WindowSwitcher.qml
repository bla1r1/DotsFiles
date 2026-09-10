import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Ui"
import "../Services" as Services

// =============================================================================
// Visual Window Switcher (Alt+Tab) Overlay
// =============================================================================

Rectangle {
    id: switcherRoot

    implicitWidth: Design.s(760)
    implicitHeight: Design.s(240)
    radius: Design.s(Design.radius.card)
    color: Design.tint(Design.ground, 0.95)
    border.color: Design.tint(Design.sapphire, 0.4)
    border.width: 1

    property int selectedIndex: 0
    readonly property ListModel windowsList: ListModel {}

    Process {
        id: windowScanner
        running: true
        command: ["b1air-daemon", "window", "open"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text);
                    switcherRoot.windowsList.clear();
                    for (let win of items) {
                        switcherRoot.windowsList.append({
                            id: win.id,
                            name: win.name || "Window",
                            app_id: win.app_id || "application",
                            focused: win.focused || false
                        });
                    }
                    if (switcherRoot.windowsList.count > 1) {
                        switcherRoot.selectedIndex = 1;
                    } else {
                        switcherRoot.selectedIndex = 0;
                    }
                    winListView.currentIndex = switcherRoot.selectedIndex;
                } catch (e) {}
            }
        }
    }

    function activateCurrent() {
        if (switcherRoot.windowsList.count > 0 && switcherRoot.selectedIndex >= 0 && switcherRoot.selectedIndex < switcherRoot.windowsList.count) {
            let win = switcherRoot.windowsList.get(switcherRoot.selectedIndex);
            if (win && win.id) {
                Quickshell.execDetached(["swaymsg", "[con_id=" + win.id + "] focus"]);
            }
        }
        if (typeof masterWindow !== "undefined" && masterWindow.handleIpcCommand) {
            masterWindow.handleIpcCommand("close", true);
        }
    }

    function nextWindow() {
        if (switcherRoot.windowsList.count === 0) return;
        switcherRoot.selectedIndex = (switcherRoot.selectedIndex + 1) % switcherRoot.windowsList.count;
        winListView.currentIndex = switcherRoot.selectedIndex;
    }

    function prevWindow() {
        if (switcherRoot.windowsList.count === 0) return;
        switcherRoot.selectedIndex = (switcherRoot.selectedIndex - 1 + switcherRoot.windowsList.count) % switcherRoot.windowsList.count;
        winListView.currentIndex = switcherRoot.selectedIndex;
    }

    focus: true
    Keys.onTabPressed: nextWindow()
    Keys.onRightPressed: nextWindow()
    Keys.onBacktabPressed: prevWindow()
    Keys.onLeftPressed: prevWindow()
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onSpacePressed: activateCurrent()
    Keys.onEscapePressed: {
        if (typeof masterWindow !== "undefined" && masterWindow.handleIpcCommand) {
            masterWindow.handleIpcCommand("close", true);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Design.s(Design.space.md)
        spacing: Design.s(Design.space.sm)

        // ── Top Header ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Icon {
                text: "󰖯"
                role: "subhead"
                color: Design.sapphire
            }

            Label {
                text: "Running Tasks & Windows"
                weight: Design.weight.bold
                role: "subhead"
                Layout.fillWidth: true
            }

            Label {
                text: switcherRoot.windowsList.count + " Active"
                role: "caption"
                dim: true
            }
        }

        // ── Empty State ──────────────────────────────────────────────────────
        Item {
            visible: switcherRoot.windowsList.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Design.s(Design.space.xs)

                Icon {
                    text: "󰖰"
                    role: "hero"
                    color: Design.textDim
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    text: "No open application windows found"
                    role: "body"
                    dim: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ── Horizontal Cards Carousel ────────────────────────────────────────
        ListView {
            id: winListView
            visible: switcherRoot.windowsList.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            orientation: ListView.Horizontal
            spacing: Design.s(Design.space.md)
            model: switcherRoot.windowsList

            delegate: Rectangle {
                id: winCard
                required property var model
                required property int index

                width: Design.s(160)
                height: winListView.height
                radius: Design.s(Design.radius.ctl)

                readonly property bool isSelected: switcherRoot.selectedIndex === winCard.index

                color: isSelected ? Design.tint(Design.sapphire, 0.22) : (cardMa.containsMouse ? Design.glassHover : Design.surface)
                border.color: isSelected ? Design.sapphire : (cardMa.containsMouse ? Design.tint(Design.line, 0.6) : Design.glassBorder)
                border.width: isSelected ? 2 : 1

                scale: isSelected ? 1.03 : 1.0
                Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(6)

                    // App Icon
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(64)

                        Image {
                            anchors.centerIn: parent
                            width: Design.s(48)
                            height: Design.s(48)
                            // The desktop entry knows the icon; the app_id on
                            // its own is not one. Falls back to the old guess
                            // for windows with no entry installed.
                            source: {
                                const id = winCard.model.app_id || "";
                                if (id === "") return "";
                                const found = Services.Apps.iconFor(id);
                                if (found === "") return "image://icon/" + id;
                                return found.startsWith("/") ? "file://" + found : "image://icon/" + found;
                            }
                            fillMode: Image.PreserveAspectFit
                            visible: source.toString() !== ""
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !parent.children[0].visible
                            text: "󰖯"
                            role: "hero"
                            color: winCard.isSelected ? Design.sapphire : Design.textDim
                        }
                    }

                    // App Title
                    Label {
                        Layout.fillWidth: true
                        text: winCard.model.name
                        weight: winCard.isSelected ? Design.weight.bold : Design.weight.semibold
                        role: "caption"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: winCard.isSelected ? Design.sapphire : Design.text
                    }

                    // App ID / Class
                    Label {
                        Layout.fillWidth: true
                        text: winCard.model.app_id
                        role: "caption"
                        horizontalAlignment: Text.AlignHCenter
                        dim: true
                        isMono: true
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        switcherRoot.selectedIndex = winCard.index;
                        switcherRoot.activateCurrent();
                    }
                }
            }
        }
    }
}
