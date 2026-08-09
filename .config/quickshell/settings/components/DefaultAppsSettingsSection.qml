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

    property string defaultBrowser: Settings.defaultBrowser || "brave"
    property string defaultTerminal: Settings.defaultTerminal || "kitty"
    property string defaultFileManager: Settings.defaultFileManager || "thunar"
    property string defaultEditor: Settings.defaultEditor || "code"

    function setBrowser(appId) {
        section.defaultBrowser = appId;
        Settings.set("defaultBrowser", appId);
        const desktopFile = appId === "brave" ? "brave-browser.desktop" 
                          : (appId === "firefox" ? "firefox.desktop" 
                          : (appId === "zen" ? "zen.desktop" : appId + ".desktop"));
        Quickshell.execDetached(["xdg-mime", "default", desktopFile, "x-scheme-handler/http", "x-scheme-handler/https", "text/html"]);
    }

    function setTerminal(appId) {
        section.defaultTerminal = appId;
        Settings.set("defaultTerminal", appId);
    }

    function setFileManager(appId) {
        section.defaultFileManager = appId;
        Settings.set("defaultFileManager", appId);
        const desktopFile = (appId === "thunar" ? "thunar.desktop" : (appId === "nautilus" ? "org.gnome.Nautilus.desktop" : appId + ".desktop"));
        Quickshell.execDetached(["xdg-mime", "default", desktopFile, "inode/directory"]);
    }

    function setEditor(appId) {
        section.defaultEditor = appId;
        Settings.set("defaultEditor", appId);
        const desktopFile = (appId === "code" ? "code.desktop" : (appId === "cursor" ? "cursor.desktop" : appId + ".desktop"));
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
                    onClicked: section.setBrowser(modelData.id)
                }
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
                    onClicked: section.setTerminal(modelData.id)
                }
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
                    onClicked: section.setFileManager(modelData.id)
                }
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
                    onClicked: section.setEditor(modelData.id)
                }
            }
        }
    }
}
