import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import B1Air.Term 1.0
import Ui

Window {
    id: window
    title: termView.title.length > 0 ? termView.title : "Terminal"
    width: Design.s(820)
    height: Design.s(520)
    minimumWidth: Design.s(450)
    minimumHeight: Design.s(300)
    visible: true
    color: "transparent"

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

            // ── Ultra-Compact Headerbar (36px) ──────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                color: Design.surface
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(14)
                    anchors.rightMargin: Design.s(14)
                    spacing: Design.s(8)

                    // Terminal Icon
                    Label {
                        text: "\u{f120}" // 
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Design.s(15)
                        color: Design.sapphire
                    }

                    // Window Title / Process Name
                    Label {
                        text: window.title
                        font.pixelSize: Design.s(12)
                        font.bold: true
                        color: Design.text
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: Design.s(280)
                    }

                    // Grid Size Pill (e.g. 80×24)
                    Rectangle {
                        Layout.preferredHeight: Design.s(20)
                        Layout.preferredWidth: sizeLabel.implicitWidth + Design.s(12)
                        radius: Design.s(10)
                        color: Qt.rgba(Design.subtext0.r, Design.subtext0.g, Design.subtext0.b, 0.12)

                        Label {
                            id: sizeLabel
                            anchors.centerIn: parent
                            text: termView.cols + " × " + termView.rows
                            font.pixelSize: Design.s(10)
                            font.family: "JetBrainsMono Nerd Font"
                            color: Design.subtext0
                        }
                    }

                    Item { Layout.fillWidth: true } // Spacer

                    // Zoom Out
                    Rectangle {
                        Layout.preferredWidth: Design.s(24)
                        Layout.preferredHeight: Design.s(24)
                        radius: Design.s(6)
                        color: zoomOutHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u{f068}" //  (minus)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Design.s(11)
                            color: Design.subtext0
                        }

                        HoverHandler { id: zoomOutHover }
                        TapHandler { onTapped: termView.zoomOut() }
                    }

                    // Zoom Reset / Percent
                    Rectangle {
                        Layout.preferredHeight: Design.s(22)
                        Layout.preferredWidth: zoomLabel.implicitWidth + Design.s(10)
                        radius: Design.s(6)
                        color: zoomResetHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Label {
                            id: zoomLabel
                            anchors.centerIn: parent
                            text: termView.fontSize + "pt"
                            font.pixelSize: Design.s(10)
                            font.family: "JetBrainsMono Nerd Font"
                            color: Design.subtext1
                        }

                        HoverHandler { id: zoomResetHover }
                        TapHandler { onTapped: termView.resetZoom() }
                    }

                    // Zoom In
                    Rectangle {
                        Layout.preferredWidth: Design.s(24)
                        Layout.preferredHeight: Design.s(24)
                        radius: Design.s(6)
                        color: zoomInHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u{f067}" //  (plus)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Design.s(11)
                            color: Design.subtext0
                        }

                        HoverHandler { id: zoomInHover }
                        TapHandler { onTapped: termView.zoomIn() }
                    }

                    // Divider
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: Design.s(16)
                        color: Qt.rgba(1, 1, 1, 0.1)
                    }

                    // Copy Selection
                    Rectangle {
                        Layout.preferredWidth: Design.s(26)
                        Layout.preferredHeight: Design.s(24)
                        radius: Design.s(6)
                        color: copyHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u{f0c5}" // 
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Design.s(12)
                            color: Design.subtext0
                        }

                        HoverHandler { id: copyHover }
                        TapHandler { onTapped: termView.copySelection() }
                    }

                    // Paste Clipboard
                    Rectangle {
                        Layout.preferredWidth: Design.s(26)
                        Layout.preferredHeight: Design.s(24)
                        radius: Design.s(6)
                        color: pasteHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u{f0ea}" // 
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Design.s(12)
                            color: Design.subtext0
                        }

                        HoverHandler { id: pasteHover }
                        TapHandler { onTapped: termView.pasteClipboard() }
                    }

                    // Clear Screen
                    Rectangle {
                        Layout.preferredWidth: Design.s(26)
                        Layout.preferredHeight: Design.s(24)
                        radius: Design.s(6)
                        color: clearHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u{f1f8}" // 
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Design.s(12)
                            color: Design.subtext0
                        }

                        HoverHandler { id: clearHover }
                        TapHandler { onTapped: termView.clear() }
                    }
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Design.glassBorder
            }

            // ── Terminal Surface ─────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TerminalView {
                    id: termView
                    anchors.fill: parent
                    anchors.margins: Design.s(6)
                    focus: true

                    Component.onCompleted: {
                        var cmd = (typeof InitialCommand !== "undefined") ? InitialCommand : "";
                        var dir = (typeof InitialDir !== "undefined") ? InitialDir : "";
                        launch(cmd, dir);
                        forceActiveFocus();
                    }

                    onProcessFinished: {
                        window.close();
                    }
                }
            }
        }
    }

    // Global Shortcuts
    Shortcut {
        sequences: ["Ctrl+Shift+C"]
        onActivated: termView.copySelection()
    }
    Shortcut {
        sequences: ["Ctrl+Shift+V"]
        onActivated: termView.pasteClipboard()
    }
    Shortcut {
        sequences: ["Ctrl+Plus", "Ctrl+="]
        onActivated: termView.zoomIn()
    }
    Shortcut {
        sequences: ["Ctrl+Minus"]
        onActivated: termView.zoomOut()
    }
    Shortcut {
        sequences: ["Ctrl+0"]
        onActivated: termView.resetZoom()
    }
}
