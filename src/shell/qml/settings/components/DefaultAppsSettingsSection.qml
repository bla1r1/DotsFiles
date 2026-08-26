import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"

// =============================================================================
// Default Applications Settings (Dynamic Desktop App Discovery)
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property string defaultBrowser: Settings.defaultBrowser || "firefox"
    property string defaultTerminal: Settings.defaultTerminal || "kitty"
    property string defaultFileManager: Settings.defaultFileManager || "thunar"
    property string defaultEditor: Settings.defaultEditor || "code"
    property string defaultPlayer: Settings.defaultPlayer || "mpv"

    // ── Dynamic App Scanner Models ───────────────────────────────────────────
    readonly property ListModel browserList: ListModel {}
    readonly property ListModel terminalList: ListModel {}
    readonly property ListModel fileManagerList: ListModel {}
    readonly property ListModel editorList: ListModel {}
    readonly property ListModel playerList: ListModel {}

    Process {
        id: appScanner
        running: true
        command: ["b1air-daemon", "apps", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text);
                    section.browserList.clear();
                    section.terminalList.clear();
                    section.fileManagerList.clear();
                    section.editorList.clear();
                    section.playerList.clear();

                    // Standard fallbacks if system scan is empty
                    let bFound = false, tFound = false, fFound = false, eFound = false, pFound = false;

                    for (let app of items) {
                        let e = (app.exec || "").toLowerCase();
                        let n = (app.name || "").toLowerCase();
                        let f = (app.desktopFile || "").toLowerCase();

                        if (e.includes("firefox") || e.includes("chrome") || e.includes("chromium") || e.includes("brave") || e.includes("zen") || e.includes("vivaldi") || e.includes("librewolf") || e.includes("floorp") || e.includes("qutebrowser")) {
                            section.browserList.append({ name: app.name, exec: app.exec, desktopFile: app.desktopFile, icon: app.icon });
                            bFound = true;
                        }
                        if (e.includes("kitty") || e.includes("foot") || e.includes("alacritty") || e.includes("ghostty") || e.includes("wezterm") || e.includes("konsole") || e.includes("xterm")) {
                            section.terminalList.append({ name: app.name, exec: app.exec, desktopFile: app.desktopFile, icon: app.icon });
                            tFound = true;
                        }
                        if (e.includes("thunar") || e.includes("nautilus") || e.includes("dolphin") || e.includes("nemo") || e.includes("pcmanfm") || e.includes("yazi") || e.includes("ranger")) {
                            section.fileManagerList.append({ name: app.name, exec: app.exec, desktopFile: app.desktopFile, icon: app.icon });
                            fFound = true;
                        }
                        if (e.includes("code") || e.includes("cursor") || e.includes("nvim") || e.includes("zed") || e.includes("kate") || e.includes("gedit") || e.includes("micro") || e.includes("sublime")) {
                            section.editorList.append({ name: app.name, exec: app.exec, desktopFile: app.desktopFile, icon: app.icon });
                            eFound = true;
                        }
                        if (e.includes("mpv") || e.includes("vlc") || e.includes("spotify") || e.includes("celluloid") || e.includes("audacious")) {
                            section.playerList.append({ name: app.name, exec: app.exec, desktopFile: app.desktopFile, icon: app.icon });
                            pFound = true;
                        }
                    }

                    // Pre-populate if empty
                    if (!bFound) {
                        section.browserList.append({ name: "Firefox", exec: "firefox", desktopFile: "firefox.desktop", icon: "firefox" });
                        section.browserList.append({ name: "Chromium", exec: "chromium", desktopFile: "chromium.desktop", icon: "chromium" });
                    }
                    if (!tFound) {
                        section.terminalList.append({ name: "Kitty", exec: "kitty", desktopFile: "kitty.desktop", icon: "kitty" });
                        section.terminalList.append({ name: "Foot", exec: "foot", desktopFile: "foot.desktop", icon: "foot" });
                    }
                    if (!fFound) {
                        section.fileManagerList.append({ name: "Thunar", exec: "thunar", desktopFile: "thunar.desktop", icon: "thunar" });
                        section.fileManagerList.append({ name: "Nautilus", exec: "nautilus", desktopFile: "org.gnome.Nautilus.desktop", icon: "org.gnome.Nautilus" });
                    }
                    if (!eFound) {
                        section.editorList.append({ name: "VS Code", exec: "code", desktopFile: "code.desktop", icon: "code" });
                        section.editorList.append({ name: "Neovim", exec: "nvim", desktopFile: "nvim.desktop", icon: "nvim" });
                    }
                    if (!pFound) {
                        section.playerList.append({ name: "MPV", exec: "mpv", desktopFile: "mpv.desktop", icon: "mpv" });
                    }
                } catch (err) {}
            }
        }
    }

    function setBrowser(appExec, desktopFile) {
        if (!appExec || !appExec.trim()) return;
        const val = appExec.trim();
        section.defaultBrowser = val;
        Settings.set("defaultBrowser", val);
        const df = desktopFile || (val.endsWith(".desktop") ? val : val + ".desktop");
        Quickshell.execDetached(["xdg-mime", "default", df, "x-scheme-handler/http", "x-scheme-handler/https", "text/html"]);
    }

    function setTerminal(appExec, desktopFile) {
        if (!appExec || !appExec.trim()) return;
        const val = appExec.trim();
        section.defaultTerminal = val;
        Settings.set("defaultTerminal", val);
        const df = desktopFile || (val.endsWith(".desktop") ? val : val + ".desktop");
        Quickshell.execDetached(["xdg-mime", "default", df, "x-scheme-handler/terminal"]);
    }

    function setFileManager(appExec, desktopFile) {
        if (!appExec || !appExec.trim()) return;
        const val = appExec.trim();
        section.defaultFileManager = val;
        Settings.set("defaultFileManager", val);
        const df = desktopFile || (val.endsWith(".desktop") ? val : val + ".desktop");
        Quickshell.execDetached(["xdg-mime", "default", df, "inode/directory"]);
    }

    function setEditor(appExec, desktopFile) {
        if (!appExec || !appExec.trim()) return;
        const val = appExec.trim();
        section.defaultEditor = val;
        Settings.set("defaultEditor", val);
        const df = desktopFile || (val.endsWith(".desktop") ? val : val + ".desktop");
        Quickshell.execDetached(["xdg-mime", "default", df, "text/plain", "text/markdown", "application/json"]);
    }

    function setPlayer(appExec, desktopFile) {
        if (!appExec || !appExec.trim()) return;
        const val = appExec.trim();
        section.defaultPlayer = val;
        Settings.set("defaultPlayer", val);
        const df = desktopFile || (val.endsWith(".desktop") ? val : val + ".desktop");
        Quickshell.execDetached(["xdg-mime", "default", df, "video/mp4", "video/mkv", "audio/mpeg", "audio/flac"]);
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
                model: section.browserList
                delegate: Pill {
                    required property var model
                    label: model.name
                    active: section.defaultBrowser.toLowerCase().includes(model.exec.toLowerCase()) || model.exec.toLowerCase().includes(section.defaultBrowser.toLowerCase())
                    onClicked: {
                        browserCustomInput.text = "";
                        section.setBrowser(model.exec, model.desktopFile);
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
                        Text {
                            text: "Custom binary / executable (e.g. librewolf, floorp, qutebrowser)..."
                            color: Design.textDim
                            visible: !browserCustomInput.text && !browserCustomInput.activeFocus
                            anchors.fill: parent
                            font: browserCustomInput.font
                        }
                        onAccepted: section.setBrowser(text, "")
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.sapphire
                onActivated: section.setBrowser(browserCustomInput.text, "")
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
                model: section.terminalList
                delegate: Pill {
                    required property var model
                    label: model.name
                    active: section.defaultTerminal.toLowerCase().includes(model.exec.toLowerCase()) || model.exec.toLowerCase().includes(section.defaultTerminal.toLowerCase())
                    onClicked: {
                        termCustomInput.text = "";
                        section.setTerminal(model.exec, model.desktopFile);
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
                        Text {
                            text: "Custom binary / executable (e.g. wezterm, ghostty, xterm)..."
                            color: Design.textDim
                            visible: !termCustomInput.text && !termCustomInput.activeFocus
                            anchors.fill: parent
                            font: termCustomInput.font
                        }
                        onAccepted: section.setTerminal(text, "")
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.green
                onActivated: section.setTerminal(termCustomInput.text, "")
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
                model: section.fileManagerList
                delegate: Pill {
                    required property var model
                    label: model.name
                    active: section.defaultFileManager.toLowerCase().includes(model.exec.toLowerCase()) || model.exec.toLowerCase().includes(section.defaultFileManager.toLowerCase())
                    onClicked: {
                        fmCustomInput.text = "";
                        section.setFileManager(model.exec, model.desktopFile);
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
                        Text {
                            text: "Custom binary / executable (e.g. pcmanfm, nemo, yazi, ranger)..."
                            color: Design.textDim
                            visible: !fmCustomInput.text && !fmCustomInput.activeFocus
                            anchors.fill: parent
                            font: fmCustomInput.font
                        }
                        onAccepted: section.setFileManager(text, "")
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.peach
                onActivated: section.setFileManager(fmCustomInput.text, "")
            }
        }
    }

    // ── 4. Code & Text Editor ────────────────────────────────────────────────
    Card {
        title: "Code & Text Editor"
        subtitle: "Application for editing text and source files"
        icon: "\u{f121}"
        accentColor: Design.mauve

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Repeater {
                model: section.editorList
                delegate: Pill {
                    required property var model
                    label: model.name
                    active: section.defaultEditor.toLowerCase().includes(model.exec.toLowerCase()) || model.exec.toLowerCase().includes(section.defaultEditor.toLowerCase())
                    onClicked: {
                        editorCustomInput.text = "";
                        section.setEditor(model.exec, model.desktopFile);
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
                        Text {
                            text: "Custom binary / executable (e.g. helix, emacs, gedit, sublime)..."
                            color: Design.textDim
                            visible: !editorCustomInput.text && !editorCustomInput.activeFocus
                            anchors.fill: parent
                            font: editorCustomInput.font
                        }
                        onAccepted: section.setEditor(text, "")
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.mauve
                onActivated: section.setEditor(editorCustomInput.text, "")
            }
        }
    }

    // ── 5. Media Player ──────────────────────────────────────────────────────
    Card {
        title: "Media Player"
        subtitle: "Application for playing audio, video, and stream files"
        icon: "\u{f008}"
        accentColor: Design.teal

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Repeater {
                model: section.playerList
                delegate: Pill {
                    required property var model
                    label: model.name
                    active: section.defaultPlayer.toLowerCase().includes(model.exec.toLowerCase()) || model.exec.toLowerCase().includes(section.defaultPlayer.toLowerCase())
                    onClicked: {
                        playerCustomInput.text = "";
                        section.setPlayer(model.exec, model.desktopFile);
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
                border.color: playerCustomInput.activeFocus ? Design.teal : Design.tint(Design.line, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon { text: "󰌹"; role: "caption"; color: Design.textDim }

                    TextInput {
                        id: playerCustomInput
                        Layout.fillWidth: true
                        color: Design.text
                        font.pixelSize: Design.font.caption
                        clip: true
                        selectByMouse: true
                        Text {
                            text: "Custom binary / executable (e.g. celluloid, vlc, mpv)..."
                            color: Design.textDim
                            visible: !playerCustomInput.text && !playerCustomInput.activeFocus
                            anchors.fill: parent
                            font: playerCustomInput.font
                        }
                        onAccepted: section.setPlayer(text, "")
                    }
                }
            }

            ActionButton {
                icon: "󰄬"
                label: "Set"
                tone: Design.teal
                onActivated: section.setPlayer(playerCustomInput.text, "")
            }
        }
    }
}
