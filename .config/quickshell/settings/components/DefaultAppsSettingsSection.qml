import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Default Applications Settings
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property string defaultBrowser: Settings.defaultBrowser || "firefox"
    property string defaultTerminal: Settings.defaultTerminal || "kitty"
    property string defaultFileManager: Settings.defaultFileManager || "nautilus"
    property string defaultEditor: Settings.defaultEditor || "code"

    function setBrowser(appId) {
        if (!appId || !appId.trim()) return;
        const val = appId.trim();
        section.defaultBrowser = val;
        Settings.set("defaultBrowser", val);
        const desktopFile = val === "brave" ? "brave-browser.desktop" 
                          : (val === "firefox" ? "firefox.desktop" 
                          : (val === "zen" ? "zen.desktop" 
                          : (val === "chromium" ? "chromium.desktop" : val + ".desktop")));
        Quickshell.execDetached(["xdg-mime", "default", desktopFile, "x-scheme-handler/http", "x-scheme-handler/https", "text/html"]);
    }

    function setTerminal(appId) {
        if (!appId || !appId.trim()) return;
        const val = appId.trim();
        section.defaultTerminal = val;
        Settings.set("defaultTerminal", val);
    }

    function setFileManager(appId) {
        if (!appId || !appId.trim()) return;
        const val = appId.trim();
        section.defaultFileManager = val;
        Settings.set("defaultFileManager", val);
        const desktopFile = (val === "thunar" ? "thunar.desktop" : (val === "nautilus" ? "org.gnome.Nautilus.desktop" : (val === "dolphin" ? "org.kde.dolphin.desktop" : val + ".desktop")));
        Quickshell.execDetached(["xdg-mime", "default", desktopFile, "inode/directory"]);
    }

    function setEditor(appId) {
        if (!appId || !appId.trim()) return;
        const val = appId.trim();
        section.defaultEditor = val;
        Settings.set("defaultEditor", val);
        const desktopFile = (val === "code" ? "code.desktop" : (val === "cursor" ? "cursor.desktop" : val + ".desktop"));
        Quickshell.execDetached(["xdg-mime", "default", desktopFile, "text/plain"]);
    }

    // ── 1. Web Browser ───────────────────────────────────────────────────────
    Card {
        title: "Web Browser"
        subtitle: "Primary browser for opening URLs and web documents"
        icon: "\u{f0ac}"
        accentColor: Design.sapphire

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Repeater {
                model: [
                    { id: "brave", label: "Brave" },
                    { id: "firefox", label: "Firefox" },
                    { id: "zen", label: "Zen" },
                    { id: "chromium", label: "Chromium" }
                ]
                delegate: Pill {
                    label: modelData.label
                    active: section.defaultBrowser === modelData.id
                    onClicked: {
                        browserCustomInput.text = "";
                        section.setBrowser(modelData.id);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(Design.radius.ctl)
                color: Design.surface
                border.color: browserCustomInput.activeFocus ? Design.sapphire : Design.tint(Design.line, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon { text: "󰌹"; role: "caption"; color: Design.textDim }

                    TextInput {
                        id: browserCustomInput
                        Layout.fillWidth: true
                        color: Design.text
                        font.pixelSize: Design.font.caption
                        clip: true
                        selectByMouse: true
                        text: ["brave", "firefox", "zen", "chromium"].includes(section.defaultBrowser) ? "" : section.defaultBrowser
                        Text {
                            text: "Custom binary / executable (e.g. librewolf, floorp, qutebrowser)..."
                            color: Design.textDim
                            visible: !browserCustomInput.text && !browserCustomInput.activeFocus
                            anchors.fill: parent
                            font: browserCustomInput.font
                        }
                        onAccepted: section.setBrowser(text)
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.sapphire
                onActivated: section.setBrowser(browserCustomInput.text)
            }
        }
    }

    // ── 2. Terminal Emulator ─────────────────────────────────────────────────
    Card {
        title: "Terminal Emulator"
        subtitle: "Default command-line shell launcher"
        icon: "\u{f120}"
        accentColor: Design.green

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Repeater {
                model: [
                    { id: "kitty", label: "Kitty" },
                    { id: "foot", label: "Foot" },
                    { id: "alacritty", label: "Alacritty" }
                ]
                delegate: Pill {
                    label: modelData.label
                    active: section.defaultTerminal === modelData.id
                    onClicked: {
                        termCustomInput.text = "";
                        section.setTerminal(modelData.id);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(Design.radius.ctl)
                color: Design.surface
                border.color: termCustomInput.activeFocus ? Design.green : Design.tint(Design.line, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon { text: "󰌹"; role: "caption"; color: Design.textDim }

                    TextInput {
                        id: termCustomInput
                        Layout.fillWidth: true
                        color: Design.text
                        font.pixelSize: Design.font.caption
                        clip: true
                        selectByMouse: true
                        text: ["kitty", "foot", "alacritty"].includes(section.defaultTerminal) ? "" : section.defaultTerminal
                        Text {
                            text: "Custom binary / executable (e.g. wezterm, ghostty, xterm)..."
                            color: Design.textDim
                            visible: !termCustomInput.text && !termCustomInput.activeFocus
                            anchors.fill: parent
                            font: termCustomInput.font
                        }
                        onAccepted: section.setTerminal(text)
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.green
                onActivated: section.setTerminal(termCustomInput.text)
            }
        }
    }

    // ── 3. File Manager ──────────────────────────────────────────────────────
    Card {
        title: "File Manager"
        subtitle: "Default application for opening folders and directories"
        icon: "\u{f07c}"
        accentColor: Design.peach

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Repeater {
                model: [
                    { id: "thunar", label: "Thunar" },
                    { id: "nautilus", label: "Nautilus" },
                    { id: "dolphin", label: "Dolphin" }
                ]
                delegate: Pill {
                    label: modelData.label
                    active: section.defaultFileManager === modelData.id
                    onClicked: {
                        fmCustomInput.text = "";
                        section.setFileManager(modelData.id);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(Design.radius.ctl)
                color: Design.surface
                border.color: fmCustomInput.activeFocus ? Design.peach : Design.tint(Design.line, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon { text: "󰌹"; role: "caption"; color: Design.textDim }

                    TextInput {
                        id: fmCustomInput
                        Layout.fillWidth: true
                        color: Design.text
                        font.pixelSize: Design.font.caption
                        clip: true
                        selectByMouse: true
                        text: ["thunar", "nautilus", "dolphin"].includes(section.defaultFileManager) ? "" : section.defaultFileManager
                        Text {
                            text: "Custom binary / executable (e.g. pcmanfm, nemo, yazi, ranger)..."
                            color: Design.textDim
                            visible: !fmCustomInput.text && !fmCustomInput.activeFocus
                            anchors.fill: parent
                            font: fmCustomInput.font
                        }
                        onAccepted: section.setFileManager(text)
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.peach
                onActivated: section.setFileManager(fmCustomInput.text)
            }
        }
    }

    // ── 4. Code Editor ───────────────────────────────────────────────────────
    Card {
        title: "Code & Text Editor"
        subtitle: "Application for editing text and source files"
        icon: "\u{f121}"
        accentColor: Design.mauve

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Repeater {
                model: [
                    { id: "code", label: "VS Code" },
                    { id: "cursor", label: "Cursor" },
                    { id: "nvim", label: "Neovim" },
                    { id: "zed", label: "Zed" }
                ]
                delegate: Pill {
                    label: modelData.label
                    active: section.defaultEditor === modelData.id
                    onClicked: {
                        editorCustomInput.text = "";
                        section.setEditor(modelData.id);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(Design.radius.ctl)
                color: Design.surface
                border.color: editorCustomInput.activeFocus ? Design.mauve : Design.tint(Design.line, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon { text: "󰌹"; role: "caption"; color: Design.textDim }

                    TextInput {
                        id: editorCustomInput
                        Layout.fillWidth: true
                        color: Design.text
                        font.pixelSize: Design.font.caption
                        clip: true
                        selectByMouse: true
                        text: ["code", "cursor", "nvim", "zed"].includes(section.defaultEditor) ? "" : section.defaultEditor
                        Text {
                            text: "Custom binary / executable (e.g. helix, emacs, gedit, sublime)..."
                            color: Design.textDim
                            visible: !editorCustomInput.text && !editorCustomInput.activeFocus
                            anchors.fill: parent
                            font: editorCustomInput.font
                        }
                        onAccepted: section.setEditor(text)
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.mauve
                onActivated: section.setEditor(editorCustomInput.text)
            }
        }
    }
}
