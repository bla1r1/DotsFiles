import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Startup & Services Manager
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property var autostartApps: Settings.autostartApps || ["waybar", "polkit", "quickshell", "mako"]
    property var autostartCustom: Settings.autostartCustom || []
    property bool openGuideAtStartup: Settings.openGuideAtStartup || false
    property bool guideShortcut: Settings.topbarHelpIcon !== undefined ? Settings.topbarHelpIcon : true

    function isAppEnabled(id) {
        return (section.autostartApps || []).indexOf(id) !== -1;
    }

    function toggleApp(id) {
        var list = (section.autostartApps || []).slice();
        var idx = list.indexOf(id);
        if (idx === -1) {
            list.push(id);
        } else {
            list.splice(idx, 1);
        }
        section.autostartApps = list;
        Settings.set("autostartApps", list);
    }

    function addCustomApp(name, cmd) {
        if (!name.trim() || !cmd.trim()) return;
        var list = (section.autostartCustom || []).slice();
        list.push({
            name: name.trim(),
            command: cmd.trim(),
            enabled: true
        });
        section.autostartCustom = list;
        Settings.set("autostartCustom", list);
        customNameInput.text = "";
        customCmdInput.text = "";
    }

    function toggleCustomApp(index) {
        var list = (section.autostartCustom || []).slice();
        if (index >= 0 && index < list.length) {
            list[index].enabled = !list[index].enabled;
            section.autostartCustom = list;
            Settings.set("autostartCustom", list);
        }
    }

    function removeCustomApp(index) {
        var list = (section.autostartCustom || []).slice();
        if (index >= 0 && index < list.length) {
            list.splice(index, 1);
            section.autostartCustom = list;
            Settings.set("autostartCustom", list);
        }
    }

    // ── 1. Core Desktop Services ─────────────────────────────────────────────
    Card {
        title: "Desktop Environment Services"
        subtitle: "Core system components loaded automatically on login"
        icon: "\u{f0459}"
        accentColor: Design.sapphire

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰚰"; role: "title"; color: Design.sapphire }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Quickshell Desktop Shell"; weight: Design.weight.semibold }
                    Label { text: "Renders Control Center, Spotlight Launcher, and widgets"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("quickshell")
                    onToggled: section.toggleApp("quickshell")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰃚"; role: "title"; color: Design.blue }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Waybar Top Bar"; weight: Design.weight.semibold }
                    Label { text: "Status bar with workspaces, clock, and hardware monitors"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("waybar")
                    onToggled: section.toggleApp("waybar")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰌾"; role: "title"; color: Design.peach }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Polkit Authentication Agent"; weight: Design.weight.semibold }
                    Label { text: "Handles graphical sudo and privileged permission prompts"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("polkit")
                    onToggled: section.toggleApp("polkit")
                }
            }
        }
    }

    // ── 2. Applications Autostart ────────────────────────────────────────────
    Card {
        title: "Background Applications"
        subtitle: "Launch your favourite messaging, gaming, and media apps on startup"
        icon: "\u{f009}"
        accentColor: Design.mauve

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰭹"; role: "title"; color: Design.teal }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Telegram Desktop"; weight: Design.weight.semibold }
                    Label { text: "Start minimized to system tray"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("telegram")
                    onToggled: section.toggleApp("telegram")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰙯"; role: "title"; color: Design.lavender }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Discord / Vesktop"; weight: Design.weight.semibold }
                    Label { text: "Launch in background on startup"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("discord")
                    onToggled: section.toggleApp("discord")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰓇"; role: "title"; color: Design.green }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Spotify Music Player"; weight: Design.weight.semibold }
                    Label { text: "Open background music daemon"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("spotify")
                    onToggled: section.toggleApp("spotify")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰓓"; role: "title"; color: Design.sapphire }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Steam Gaming Client"; weight: Design.weight.semibold }
                    Label { text: "Silent startup in background"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("steam")
                    onToggled: section.toggleApp("steam")
                }
            }
        }
    }

    // ── 3. Custom Autostart Commands & Binaries ──────────────────────────────
    Card {
        title: "Custom Startup Binaries & Scripts"
        subtitle: "Add custom executable binaries, shell scripts, or background daemons"
        icon: "\u{f120}"
        accentColor: Design.teal

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Input Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.sm)

                Rectangle {
                    Layout.preferredWidth: Design.s(150)
                    Layout.preferredHeight: Design.s(36)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.surface
                    border.color: customNameInput.activeFocus ? Design.teal : Design.tint(Design.line, 0.4)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Design.s(Design.space.sm)
                        TextInput {
                            id: customNameInput
                            Layout.fillWidth: true
                            color: Design.text
                            font.pixelSize: Design.font.caption
                            clip: true
                            selectByMouse: true
                            Text {
                                text: "App Name..."
                                color: Design.textDim
                                visible: !customNameInput.text && !customNameInput.activeFocus
                                anchors.fill: parent
                                font: customNameInput.font
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(36)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.surface
                    border.color: customCmdInput.activeFocus ? Design.teal : Design.tint(Design.line, 0.4)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Design.s(Design.space.sm)
                        TextInput {
                            id: customCmdInput
                            Layout.fillWidth: true
                            color: Design.text
                            font.pixelSize: Design.font.caption
                            clip: true
                            selectByMouse: true
                            Text {
                                text: "Binary or command (e.g. syncthing, /opt/app/bin)..."
                                color: Design.textDim
                                visible: !customCmdInput.text && !customCmdInput.activeFocus
                                anchors.fill: parent
                                font: customCmdInput.font
                            }
                            onAccepted: section.addCustomApp(customNameInput.text, customCmdInput.text)
                        }
                    }
                }

                ActionButton {
                    icon: "󰐕"
                    label: "Add"
                    tone: Design.teal
                    onActivated: section.addCustomApp(customNameInput.text, customCmdInput.text)
                }
            }

            // Custom Apps List
            Repeater {
                model: section.autostartCustom || []
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4); visible: index > 0 }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(44)
                        spacing: Design.s(Design.space.md)

                        Icon { text: "󰄛"; role: "title"; color: Design.teal }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: modelData.name || "Custom App"; weight: Design.weight.semibold }
                            Label { text: modelData.command || ""; role: "caption"; isMono: true; dim: true }
                        }

                        Toggle {
                            checked: modelData.enabled !== false
                            onToggled: section.toggleCustomApp(index)
                        }

                        ActionButton {
                            icon: "󰆴"
                            tone: Design.danger
                            onActivated: section.removeCustomApp(index)
                        }
                    }
                }
            }
        }
    }

    // ── 4. Welcome & User Guide ──────────────────────────────────────────────
    Card {
        title: "Session Hints & Welcome Guide"
        subtitle: "Preferences for onboarding prompts and keybinding guides"
        icon: "\u{f02d}"
        accentColor: Design.yellow

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰋖"; role: "title"; color: Design.yellow }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Open Guide on Login"; weight: Design.weight.semibold }
                    Label { text: "Displays the keybinding and tips modal after desktop loads"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.openGuideAtStartup
                    onToggled: {
                        const next = !section.openGuideAtStartup;
                        section.openGuideAtStartup = next;
                        Settings.set("openGuideAtStartup", next);
                    }
                }
            }
        }
    }
}
