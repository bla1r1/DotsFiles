import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Ui"
import "../Services"

// =============================================================================
// macOS-style Launchpad (Dynamic App Discovery, Categorized Grid, Squircle Icons)
// =============================================================================

PopupShell {
    id: window

    padding: Design.space.lg
    background: Design.tint(Design.ground, 0.94)
    borderColor: Design.glassBorder
    cornerRadius: Design.radius.panel

    property string query: ""
    property string activeCategory: "All"
    property var systemApps: []

    // ── Dynamic System Applications Scanner ──────────────────────────────────
    Process {
        id: appLoader
        running: true
        command: ["b1air-daemon", "apps", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text);
                    let res = [];
                    for (let app of items) {
                        res.push({
                            name: app.name,
                            desc: app.comment || "Installed Application",
                            icon: app.iconPath || app.icon || "application-x-executable",
                            app_id: app.icon || "application-x-executable",
                            cmd: app.exec,
                            cat: window.categoryName(app.category)
                        });
                    }
                    window.systemApps = res;
                } catch (e) {}
            }
        }
    }

    // ── System Core Essentials ───────────────────────────────────────────────
    readonly property var baseApps: [
        { name: "Files", desc: "Native File Manager & Gallery", icon: "system-file-manager", app_id: "system-file-manager", cmd: "b1air-files", cat: "Utilities" },
        { name: "Terminal", desc: "Multi-tab Native Terminal", icon: "utilities-terminal", app_id: "utilities-terminal", cmd: "b1air-term", cat: "System" },
        { name: "Notes", desc: "Markdown Notes with Obsidian & Notion Sync", icon: "text-editor", app_id: "text-editor", cmd: "b1air-notes", cat: "Utilities" },
        { name: "Git", desc: "GitHub Desktop Style Git Client", icon: "git", app_id: "git", cmd: "b1air-git", cat: "Development" },
        { name: "System Monitor", desc: "Process & Hardware Monitor", icon: "utilities-system-monitor", app_id: "utilities-system-monitor", cmd: "b1air-monitor", cat: "System" },
        { name: "Media Viewer", desc: "Lightweight Image & Media Viewer", icon: "image-x-generic", app_id: "image-x-generic", cmd: "b1air-view", cat: "Utilities" },
        { name: "Text Editor", desc: "Minimal Text & Config Editor", icon: "text-editor", app_id: "text-editor", cmd: "b1air-text", cat: "Utilities" },
        { name: "Settings", desc: "Desktop Preferences & Appearance", icon: "preferences-system", app_id: "preferences-system", cmd: "b1air-settings", cat: "System" },
        { name: "Control Center", desc: "Quick toggles, volume & brightness", icon: "preferences-system", app_id: "preferences-system", cmd: "toggle:control:", cat: "System" },
        { name: "Clipboard", desc: "Search clipboard history", icon: "edit-paste", app_id: "edit-paste", cmd: "toggle:clipboard:", cat: "Utilities" },
        { name: "Calendar & Weather", desc: "Calendar, time, forecasts", icon: "x-office-calendar", app_id: "x-office-calendar", cmd: "toggle:calendar:", cat: "Utilities" },
        { name: "Spotlight", desc: "Quick search & app launcher", icon: "system-search", app_id: "system-search", cmd: "toggle:spotlight:", cat: "Utilities" },
        { name: "Color Dropper", desc: "Pick screen color hex", icon: "color-picker", app_id: "color-picker", cmd: "b1air-daemon color-picker", cat: "Utilities" },
        { name: "Lock Screen", desc: "Lock desktop session", icon: "system-lock-screen", app_id: "system-lock-screen", cmd: "b1air-daemon power lock", cat: "Session" },
        { name: "Power Menu", desc: "Shutdown, reboot, logout", icon: "system-shutdown", app_id: "system-shutdown", cmd: "toggle:session:", cat: "Session" }
    ]

    function categoryName(raw) {
        const c = (raw || "").toLowerCase();
        if (c.includes("development") || c.includes("ide") || c.includes("programming")) return "Development";
        if (c.includes("graphics") || c.includes("viewer") || c.includes("image")) return "Graphics";
        if (c.includes("audio") || c.includes("video") || c.includes("player")) return "Multimedia";
        if (c.includes("game")) return "Games";
        if (c.includes("office") || c.includes("wordprocessor")) return "Office";
        if (c.includes("system") || c.includes("settings") || c.includes("hardware")) return "System";
        return "Utilities";
    }

    function iconSource(icon) {
        const value = (icon || "application-x-executable").trim();
        if (value.startsWith("/") || value.startsWith("file://")) return value.startsWith("file://") ? value : "file://" + value;
        const legacy = {
            "utilities-terminal": "utilities-terminal.png",
            "system-file-manager": "system-file-manager.png",
            "utilities-system-monitor": "utilities-system-monitor.png",
            "preferences-system": "preferences-system.png",
            "text-editor": "accessories-text-editor.png",
            "image-x-generic": "../mimetypes/image-x-generic.png",
            "x-office-calendar": "../mimetypes/x-office-calendar.png",
            "git": "applications-development.png",
            "web-browser": "web-browser.png",
            "edit-paste": "edit-paste.png",
            "system-lock-screen": "system-lock-screen.png",
            "system-shutdown": "system-shutdown.png",
            "system-search": "system-search.png",
            "color-picker": "insert-image.png"
        };
        if (legacy[value]) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/" + legacy[value];
        return "image://icon/" + value;
    }

    function categoryColor(category) {
        switch (categoryName(category)) {
        case "System": return Design.blue;
        case "Development": return Design.teal;
        case "Graphics": return Design.peach;
        case "Multimedia": return Design.mauve;
        case "Games": return Design.red;
        case "Office": return Design.yellow;
        default: return Design.sapphire;
        }
    }

    readonly property var allApps: {
        let combined = [];
        let seen = {};
        for (let a of window.baseApps) {
            seen[a.name.toLowerCase()] = true;
            combined.push(a);
        }
        for (let a of window.systemApps) {
            if (!seen[a.name.toLowerCase()]) {
                seen[a.name.toLowerCase()] = true;
                combined.push(a);
            }
        }
        combined.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));
        return combined;
    }

    readonly property var filteredApps: {
        let list = window.allApps;
        if (window.activeCategory !== "All") {
            list = list.filter(a => (a.cat || "").toLowerCase().includes(window.activeCategory.toLowerCase()));
        }
        const q = window.query.trim().toLowerCase();
        if (q) {
            list = list.filter(a => {
                return a.name.toLowerCase().includes(q) ||
                       (a.desc && a.desc.toLowerCase().includes(q)) ||
                       (a.cmd && a.cmd.toLowerCase().includes(q));
            });
        }
        return list;
    }

    function safeLaunchCommand(cmd) {
        const value = (cmd || "").trim();
        const forbidden = [";", "&", "|", "`", "$", "<", ">", "\\", "\n", "\r", "(", ")", "{", "}", "[", "]", "*", "?", "!", "~"];
        if (!value || value.length > 512 || forbidden.some(c => value.includes(c))) return false;

        // Launch our own applications directly.  Sending them through
        // `swaymsg exec` makes failures invisible to the UI and depends on the
        // compositor's shell environment.  External desktop entries still use
        // Sway's launcher path below, after the strict character allowlist.
        const nativeApps = [
            "b1air-files", "b1air-term", "b1air-notes", "b1air-git",
            "b1air-monitor", "b1air-view", "b1air-text", "b1air-settings"
        ];
        if (nativeApps.includes(value)) {
            Quickshell.execDetached([value]);
            return true;
        }

        Quickshell.execDetached(["swaymsg", "exec", value]);
        return true;
    }

    function cleanExec(cmd) {
        return cmd.replace(/%[a-zA-Z]/g, "").trim();
    }

    function launchApp(app) {
        window.close();
        if (!app || !app.cmd) return;
        let cmd = app.cmd.trim();
        cmd = cleanExec(cmd);
        safeLaunchCommand(cmd);
    }

    Component.onCompleted: {
        launchSearchInput.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)

        // ── Top Navigation & Search Bar ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Title & Apps count
            RowLayout {
                spacing: Design.s(Design.space.xs)
                Icon { text: "\u{f009}"; role: "title"; color: Design.accent }
                Label {
                    text: "Launchpad"
                    role: "title"
                    weight: Design.weight.bold
                }
                Badge {
                    text: window.filteredApps.length + " apps"
                    tone: Design.accent
                }
            }

            // Search Capsule
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(38)
                radius: Design.s(Design.radius.ctl)
                color: Design.sunken
                border.color: launchSearchInput.activeFocus ? Design.accent : Design.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.sm)
                    anchors.rightMargin: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon {
                        text: "\u{f002}"
                        role: "caption"
                        color: launchSearchInput.activeFocus ? Design.accent : Design.textDim
                    }

                    TextInput {
                        id: launchSearchInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: Design.text
                        font.family: Design.font.sans
                        font.pixelSize: Design.s(14)
                        selectByMouse: true
                        clip: true

                        text: window.query
                        onTextChanged: window.query = text

                        Keys.onEscapePressed: window.close()
                        Keys.onReturnPressed: {
                            if (window.filteredApps.length > 0) {
                                window.launchApp(window.filteredApps[0]);
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search applications..."
                            color: Design.textDim
                            font: parent.font
                            visible: !launchSearchInput.text && !launchSearchInput.activeFocus
                        }
                    }

                    IconButton {
                        visible: launchSearchInput.text.length > 0
                        icon: "\u{f00d}"
                        role: "caption"
                        onClicked: {
                            launchSearchInput.text = "";
                            launchSearchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // Category Filter Pills
            RowLayout {
                spacing: Design.s(4)
                Repeater {
                    model: ["All", "System", "Utilities", "Development", "Graphics", "Multimedia", "Games", "Office"]
                    delegate: Pill {
                        required property var modelData
                        label: modelData
                        active: window.activeCategory === modelData
                        onClicked: window.activeCategory = modelData
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Design.tint(Design.line, 0.4)
        }

        // ── Application Grid (macOS Squircle style) ──────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: appGrid
                anchors.fill: parent
                clip: true
                reuseItems: true
                cellWidth: Math.floor(width / 6)
                cellHeight: Design.s(104)
                model: window.filteredApps

                ScrollBar.vertical: ScrollBar {
                    policy: appGrid.contentHeight > appGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                }

                delegate: Item {
                    id: gridCell
                    required property var modelData
                    required property int index

                    width: appGrid.cellWidth
                    height: appGrid.cellHeight

                    Rectangle {
                        id: cardBox
                        anchors.centerIn: parent
                        width: parent.width - Design.s(8)
                        height: parent.height - Design.s(6)
                        radius: Design.s(Design.radius.card)
                        color: itemHover.containsMouse ? Design.tint(Design.accent, 0.14) : "transparent"
                        border.color: itemHover.containsMouse ? Design.tint(Design.accent, 0.35) : "transparent"
                        border.width: 1

                        scale: itemHover.containsMouse ? 1.04 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(4)

                            // macOS Squircle Icon Container
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: Design.s(46)
                                height: Design.s(46)
                                radius: Design.s(12)
                                color: Design.tint(window.categoryColor(modelData.cat), itemHover.containsMouse ? 0.25 : 0.14)
                                border.color: itemHover.containsMouse ? window.categoryColor(modelData.cat) : Design.tint(window.categoryColor(modelData.cat), 0.35)
                                border.width: 1

                                IconImage {
                                    anchors.centerIn: parent
                                    width: Design.s(30)
                                    height: Design.s(30)
                                    source: window.iconSource(modelData.icon)
                                    mipmap: true
                                }
                            }

                            // Application Name
                            Label {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                horizontalAlignment: Text.AlignHCenter
                                weight: itemHover.containsMouse ? Design.weight.bold : Design.weight.medium
                                color: itemHover.containsMouse ? Design.accent : Design.text
                                font.pixelSize: Design.s(12)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        // Pin Indicator / Toggle Button
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Design.s(4)
                            width: Design.s(18)
                            height: Design.s(18)
                            radius: Design.s(4)
                            visible: itemHover.containsMouse || PinnedApps.isPinned(modelData.name)
                            color: pinArea.containsMouse ? Design.tint(Design.accent, 0.3) : (PinnedApps.isPinned(modelData.name) ? Design.tint(Design.sapphire, 0.25) : "transparent")
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: PinnedApps.isPinned(modelData.name) ? "󰤲" : "󰤱"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Design.s(11)
                                color: PinnedApps.isPinned(modelData.name) ? Design.sapphire : Design.subtext0
                            }

                            MouseArea {
                                id: pinArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    PinnedApps.togglePin({
                                        name: modelData.name,
                                        icon: modelData.icon,
                                        cmd: modelData.cmd
                                    });
                                }
                            }
                        }

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    PinnedApps.togglePin({
                                        name: modelData.name,
                                        icon: modelData.icon,
                                        cmd: modelData.cmd
                                    });
                                } else {
                                    window.launchApp(modelData);
                                }
                            }
                        }
                    }
                }
            }

            // Zero State
            Item {
                visible: window.filteredApps.length === 0
                anchors.centerIn: parent
                ColumnLayout {
                    spacing: Design.s(Design.space.sm)
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\u{f002}"
                        role: "title"
                        color: Design.textDim
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No applications found"
                        weight: Design.weight.semibold
                    }
                }
            }
        }
    }
}
