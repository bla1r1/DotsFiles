import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import B1Air.Term 1.0
import Ui

Window {
    id: window
    title: "b1air-term"
    width: Design.s(840)
    height: Design.s(540)
    minimumWidth: Design.s(450)
    minimumHeight: Design.s(300)
    visible: true
    color: "transparent"

    property int currentTabIndex: 0

    ListModel {
        id: tabsModel
    ListElement { tabTitle: "fish"; initialCmd: ""; initialDir: "" }
    }

    function createNewTab(cmd, dir) {
        tabsModel.append({
            tabTitle: "fish",
            initialCmd: cmd || "",
            initialDir: dir || ""
        });
        window.currentTabIndex = tabsModel.count - 1;
    }

    function closeTab(index) {
        if (tabsModel.count > 1) {
            tabsModel.remove(index);
            if (window.currentTabIndex >= tabsModel.count) {
                window.currentTabIndex = tabsModel.count - 1;
            }
        } else {
            window.close();
        }
    }

    onClosing: Qt.quit()

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: (window.visibility === Window.Maximized) ? 0 : Design.s(14)
        color: Design.base
        border.color: (window.visibility === Window.Maximized) ? "transparent" : Design.glassBorder
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Ultra-Compact Headerbar (36px) with Multi-Tabs ──────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                color: Design.surface
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(10)
                    anchors.rightMargin: Design.s(10)
                    spacing: Design.s(6)

                    // Terminal App Icon
                    Label {
                        text: "\u{f120}" // 
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Design.s(14)
                        color: Design.sapphire
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Tabs Strip
                    RowLayout {
                        spacing: Design.s(4)
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: tabsModel
                            delegate: Rectangle {
                                id: tabPill
                                Layout.preferredHeight: Design.s(24)
                                Layout.preferredWidth: Math.min(Design.s(140), tabRow.implicitWidth + Design.s(16))
                                radius: Design.s(6)
                                color: window.currentTabIndex === index
                                    ? Qt.rgba(Design.sapphire.r, Design.sapphire.g, Design.sapphire.b, 0.25)
                                    : (tabArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                border.color: window.currentTabIndex === index ? Design.sapphire : Design.glassBorder
                                border.width: 1

                                RowLayout {
                                    id: tabRow
                                    anchors.fill: parent
                                    anchors.leftMargin: Design.s(6)
                                    anchors.rightMargin: Design.s(4)
                                    spacing: Design.s(4)

                                    Label {
                                        text: (index + 1) + ": " + (model.tabTitle || "fish")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Design.s(10)
                                        font.bold: window.currentTabIndex === index
                                        color: window.currentTabIndex === index ? Design.text : Design.subtext0
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Close Tab Button (×)
                                    Rectangle {
                                        Layout.preferredWidth: Design.s(14)
                                        Layout.preferredHeight: Design.s(14)
                                        radius: Design.s(3)
                                        color: closeHover.hovered ? Qt.rgba(1, 0, 0, 0.25) : "transparent"
                                        visible: tabsModel.count > 1

                                        Label {
                                            anchors.centerIn: parent
                                            text: "×"
                                            font.pixelSize: Design.s(11)
                                            font.bold: true
                                            color: Design.subtext0
                                        }

                                        HoverHandler { id: closeHover }
                                        TapHandler { onTapped: window.closeTab(index) }
                                    }
                                }

                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.currentTabIndex = index
                                }
                            }
                        }

                        // Add Tab Button (+)
                        Rectangle {
                            Layout.preferredWidth: Design.s(22)
                            Layout.preferredHeight: Design.s(22)
                            radius: Design.s(5)
                            color: addHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                            border.color: Design.glassBorder
                            border.width: 1

                            Label {
                                anchors.centerIn: parent
                                text: "+"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Design.s(13)
                                font.bold: true
                                color: Design.sapphire
                            }

                            HoverHandler { id: addHover }
                            TapHandler { onTapped: window.createNewTab("", "") }
                        }
                    }

                    Item { Layout.fillWidth: true } // Spacer

                    // Zoom Controls & Actions
                    Row {
                        spacing: Design.s(4)
                        Layout.alignment: Qt.AlignVCenter

                        // Zoom Out
                        Rectangle {
                            width: Design.s(22); height: Design.s(22); radius: Design.s(5)
                            color: zmOutH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Label { anchors.centerIn: parent; text: "−"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Design.s(12); color: Design.subtext0 }
                            HoverHandler { id: zmOutH }
                            TapHandler { onTapped: currentTermView().zoomOut() }
                        }

                        // Zoom In
                        Rectangle {
                            width: Design.s(22); height: Design.s(22); radius: Design.s(5)
                            color: zmInH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Label { anchors.centerIn: parent; text: "+"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Design.s(12); color: Design.subtext0 }
                            HoverHandler { id: zmInH }
                            TapHandler { onTapped: currentTermView().zoomIn() }
                        }

                        // Divider
                        Rectangle { width: 1; height: Design.s(14); color: Qt.rgba(1, 1, 1, 0.1); anchors.verticalCenter: parent.verticalCenter }

                        // Copy Selection
                        Rectangle {
                            width: Design.s(22); height: Design.s(22); radius: Design.s(5)
                            color: cpH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Label { anchors.centerIn: parent; text: "\u{f0c5}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Design.s(11); color: Design.subtext0 }
                            HoverHandler { id: cpH }
                            TapHandler { onTapped: currentTermView().copySelection() }
                        }

                        // Paste Clipboard
                        Rectangle {
                            width: Design.s(22); height: Design.s(22); radius: Design.s(5)
                            color: pstH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Label { anchors.centerIn: parent; text: "\u{f0ea}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Design.s(11); color: Design.subtext0 }
                            HoverHandler { id: pstH }
                            TapHandler { onTapped: currentTermView().pasteClipboard() }
                        }

                        // Clear
                        Rectangle {
                            width: Design.s(22); height: Design.s(22); radius: Design.s(5)
                            color: clrH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Label { anchors.centerIn: parent; text: "\u{f1f8}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Design.s(11); color: Design.subtext0 }
                            HoverHandler { id: clrH }
                            TapHandler { onTapped: currentTermView().clear() }
                        }
                    }
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Design.glassBorder
            }

            // ── Terminal Views Stack ─────────────────────────────────────────
            StackLayout {
                id: termStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.currentTabIndex

                Repeater {
                    model: tabsModel
                    delegate: Item {
                        id: tabItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TerminalView {
                            id: singleTermView
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            focus: window.currentTabIndex === index

                            Component.onCompleted: {
                                var cmd = model.initialCmd || ((typeof InitialCommand !== "undefined" && index === 0) ? InitialCommand : "");
                                var dir = model.initialDir || ((typeof InitialDir !== "undefined" && index === 0) ? InitialDir : "");
                                launch(cmd, dir);
                                forceActiveFocus();
                            }

                            onTitleChanged: {
                                if (title && title.length > 0) {
                                    model.tabTitle = title;
                                }
                            }

                            onProcessFinished: {
                                window.closeTab(index);
                            }
                        }
                    }
                }
            }
        }
    }

    function currentTermView() {
        if (termStack.children.length > window.currentTabIndex && termStack.children[window.currentTabIndex].children.length > 0) {
            return termStack.children[window.currentTabIndex].children[0];
        }
        return null;
    }

    // Global Shortcuts
    Shortcut {
        sequences: ["Ctrl+Shift+T"]
        onActivated: window.createNewTab("", "")
    }
    Shortcut {
        sequences: ["Ctrl+Shift+W"]
        onActivated: window.closeTab(window.currentTabIndex)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+C"]
        onActivated: currentTermView() && currentTermView().copySelection()
    }
    Shortcut {
        sequences: ["Ctrl+Shift+V"]
        onActivated: currentTermView() && currentTermView().pasteClipboard()
    }
    Shortcut {
        sequences: ["Ctrl+Plus", "Ctrl+="]
        onActivated: currentTermView() && currentTermView().zoomIn()
    }
    Shortcut {
        sequences: ["Ctrl+Minus"]
        onActivated: currentTermView() && currentTermView().zoomOut()
    }
    Shortcut {
        sequences: ["Ctrl+0"]
        onActivated: currentTermView() && currentTermView().resetZoom()
    }
}
