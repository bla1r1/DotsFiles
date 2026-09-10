import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"
import "../../Services" as Services

// =============================================================================
// Default Applications Settings (Dynamic Desktop App Discovery)
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property string defaultBrowser: Settings.defaultBrowser || "firefox"
    property string defaultTerminal: Settings.defaultTerminal || "b1air-term"
    property string defaultFileManager: Settings.defaultFileManager || "b1air-files"
    property string defaultEditor: Settings.defaultEditor || "code"
    property string defaultPlayer: Settings.defaultPlayer || "mpv"

    // ── Dynamic App Scanner Models ───────────────────────────────────────────
    readonly property ListModel browserList: ListModel {}
    readonly property ListModel terminalList: ListModel {}
    readonly property ListModel fileManagerList: ListModel {}
    readonly property ListModel editorList: ListModel {}
    readonly property ListModel playerList: ListModel {}

    Process {
        id: defaultDetector
        running: true
        command: ["bash", "-c", "echo BROWSER=$(xdg-settings get default-web-browser 2>/dev/null || xdg-mime query default x-scheme-handler/http 2>/dev/null); echo TERM=$(xdg-mime query default x-scheme-handler/terminal 2>/dev/null); echo FM=$(xdg-mime query default inode/directory 2>/dev/null); echo EDIT=$(xdg-mime query default text/plain 2>/dev/null); echo PLAY=$(xdg-mime query default video/mp4 2>/dev/null)"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n");
                for (let line of lines) {
                    if (line.startsWith("BROWSER=")) {
                        let v = line.slice(8).trim();
                        if (v) section.defaultBrowser = v;
                    } else if (line.startsWith("TERM=")) {
                        let v = line.slice(5).trim();
                        if (v) section.defaultTerminal = v;
                    } else if (line.startsWith("FM=")) {
                        let v = line.slice(3).trim();
                        if (v) section.defaultFileManager = v;
                    } else if (line.startsWith("EDIT=")) {
                        let v = line.slice(5).trim();
                        if (v) section.defaultEditor = v;
                    } else if (line.startsWith("PLAY=")) {
                        let v = line.slice(5).trim();
                        if (v) section.defaultPlayer = v;
                    }
                }
            }
        }
    }

    // ── Classification ───────────────────────────────────────────────────────
    //
    // The scan itself is shared with the launchers through Services/Apps; this
    // page used to spawn its own `b1air-daemon apps all` on top of theirs.
    //
    // Two things were wrong with the matching it did. It searched the whole
    // Exec line for a substring, so anything whose command happened to contain
    // "code" — qrencode, for one — was offered as a code editor. And the lists
    // knew about b1air-term but not about b1air-files or b1air-text, so the
    // desktop's own file manager and editor could not be chosen as the default
    // for the very categories they exist to fill, even though the settings
    // themselves default to them.
    //
    // Now the match is against the command's binary name, and our apps are in
    // the lists. b1air-view is deliberately not among the players: it is an
    // image viewer, and this row is the handler for video/mp4.

    readonly property var browsers: ["firefox", "chrome", "google-chrome", "chromium",
        "brave", "brave-browser", "zen", "zen-browser", "vivaldi", "librewolf",
        "floorp", "qutebrowser", "epiphany"]
    readonly property var terminals: ["b1air-term", "foot", "alacritty", "ghostty",
        "wezterm", "konsole", "xterm", "kitty", "gnome-terminal"]
    readonly property var fileManagers: ["b1air-files", "thunar", "nautilus", "dolphin",
        "nemo", "pcmanfm", "pcmanfm-qt", "yazi", "ranger"]
    readonly property var editors: ["b1air-text", "code", "codium", "vscodium", "cursor",
        "nvim", "vim", "gvim", "zed", "kate", "gedit", "micro", "subl", "sublime_text"]
    readonly property var players: ["mpv", "vlc", "spotify", "celluloid", "audacious",
        "totem", "haruna"]

    /** The command's binary name: "/usr/bin/foo --bar %U" -> "foo". */
    function execBinary(exec) {
        const first = String(exec || "").trim().split(/\s+/)[0] || "";
        return first.split("/").pop().toLowerCase();
    }

    function matches(bin, names) {
        if (bin === "") return false;
        for (const n of names)
            if (bin === n) return true;
        return false;
    }
    function rebuildDefaults() {
        try {
            const items = Services.Apps.list;
            section.browserList.clear();
            section.terminalList.clear();
            section.fileManagerList.clear();
            section.editorList.clear();
            section.playerList.clear();

            for (let app of items) {
                const bin = section.execBinary(app.exec);
                const row = { name: app.name, exec: app.exec, desktopFile: app.desktopFile, icon: app.icon };

                if (section.matches(bin, section.browsers))     section.browserList.append(row);
                if (section.matches(bin, section.terminals))    section.terminalList.append(row);
                if (section.matches(bin, section.fileManagers)) section.fileManagerList.append(row);
                if (section.matches(bin, section.editors))      section.editorList.append(row);
                if (section.matches(bin, section.players))      section.playerList.append(row);
            }
        } catch (err) {}
    }

    Component.onCompleted: section.rebuildDefaults()

    Connections {
        target: Services.Apps
        function onListChanged() { section.rebuildDefaults(); }
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
            visible: section.browserList.count === 0
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)
            Icon { text: "\u{f071}"; role: "caption"; color: Design.yellow }
            Label { text: "No web browser installed on system. Install with: sudo pacman -S firefox"; role: "caption"; dim: true }
        }

        RowLayout {
            visible: section.browserList.count > 0
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

            // Sized to its own text: it shares the row with the custom-binary
            // field, and at half the row the field could not show its own
            // placeholder — every one of these five rows had the example
            // command cut off mid-word.
            ActionButton {
                Layout.fillWidth: false
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
            visible: section.terminalList.count === 0
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)
            Icon { text: "\u{f071}"; role: "caption"; color: Design.yellow }
            Label { text: "No b1air terminal installed on system. Build and install b1air-term first."; role: "caption"; dim: true }
        }

        RowLayout {
            visible: section.terminalList.count > 0
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

            // Sized to its own text: it shares the row with the custom-binary
            // field, and at half the row the field could not show its own
            // placeholder — every one of these five rows had the example
            // command cut off mid-word.
            ActionButton {
                Layout.fillWidth: false
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
            visible: section.fileManagerList.count === 0
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)
            Icon { text: "\u{f071}"; role: "caption"; color: Design.yellow }
            Label { text: "No file manager installed on system. Install with: sudo pacman -S thunar"; role: "caption"; dim: true }
        }

        RowLayout {
            visible: section.fileManagerList.count > 0
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

            // Sized to its own text: it shares the row with the custom-binary
            // field, and at half the row the field could not show its own
            // placeholder — every one of these five rows had the example
            // command cut off mid-word.
            ActionButton {
                Layout.fillWidth: false
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
            visible: section.editorList.count === 0
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)
            Icon { text: "\u{f071}"; role: "caption"; color: Design.yellow }
            Label { text: "No GUI text editor installed on system. Install with: sudo pacman -S code (or vim)"; role: "caption"; dim: true }
        }

        RowLayout {
            visible: section.editorList.count > 0
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

            // Sized to its own text: it shares the row with the custom-binary
            // field, and at half the row the field could not show its own
            // placeholder — every one of these five rows had the example
            // command cut off mid-word.
            ActionButton {
                Layout.fillWidth: false
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
            visible: section.playerList.count === 0
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)
            Icon { text: "\u{f071}"; role: "caption"; color: Design.yellow }
            Label { text: "No media player installed on system. Install with: sudo pacman -S mpv"; role: "caption"; dim: true }
        }

        RowLayout {
            visible: section.playerList.count > 0
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

            // Sized to its own text: it shares the row with the custom-binary
            // field, and at half the row the field could not show its own
            // placeholder — every one of these five rows had the example
            // command cut off mid-word.
            ActionButton {
                Layout.fillWidth: false
                icon: "󰄬"
                label: "Set"
                tone: Design.teal
                onActivated: section.setPlayer(playerCustomInput.text, "")
            }
        }
    }
}
