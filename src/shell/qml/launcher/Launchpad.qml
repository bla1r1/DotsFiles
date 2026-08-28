import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
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
                            icon: app.icon || "\u{f108}",
                            app_id: app.icon || "",
                            cmd: app.exec,
                            cat: app.category || "Applications"
                        });
                    }
                    window.systemApps = res;
                } catch (e) {}
            }
        }
    }

    // ── System Core Essentials ───────────────────────────────────────────────
    readonly property var baseApps: [
        { name: "Terminal", desc: "Kitty Terminal emulator", icon: "\u{f120}", app_id: "kitty", cmd: "kitty", cat: "System" },
        { name: "File Manager", desc: "Browse files and folders", icon: "\u{f07b}", app_id: "thunar", cmd: "thunar", cat: "System" },
        { name: "Settings", desc: "System & Desktop Preferences", icon: "\u{f013}", app_id: "preferences-system", cmd: "b1air-shell toggle settings", cat: "System" },
        { name: "Control Center", desc: "Quick toggles & notifications", icon: "\u{f0f3}", app_id: "preferences-desktop", cmd: "b1air-shell toggle control", cat: "System" },
        { name: "Clipboard", desc: "Search clipboard history", icon: "\u{f0ea}", app_id: "klipper", cmd: "b1air-shell toggle clipboard", cat: "Utilities" },
        { name: "Calendar & Weather", desc: "Calendar, time, forecasts", icon: "\u{f073}", app_id: "calendar", cmd: "b1air-shell toggle calendar", cat: "Utilities" },
        { name: "Spotlight", desc: "Quick search & calculations", icon: "\u{f002}", app_id: "system-search", cmd: "b1air-shell toggle spotlight", cat: "Utilities" },
        { name: "Color Dropper", desc: "Pick screen color", icon: "\u{f1fb}", app_id: "color-picker", cmd: "b1air-daemon color-picker", cat: "Utilities" },
        { name: "Task Manager", desc: "Btop system monitor", icon: "\u{f080}", app_id: "utilities-system-monitor", cmd: "kitty btop", cat: "System" },
        { name: "Lock Screen", desc: "Lock session", icon: "\u{f023}", app_id: "system-lock-screen", cmd: "b1air-daemon power lock", cat: "Session" },
        { name: "Power Menu", desc: "Power options", icon: "\u{f011}", app_id: "system-shutdown", cmd: "b1air-shell toggle session", cat: "Session" }
    ]

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

    function cleanExec(cmd) {
        return cmd.replace(/%[a-zA-Z]/g, "").trim();
    }

    function getAppGlyph(name) {
        const n = (name || "").toLowerCase();
        if (n.includes("term") || n.includes("kitty") || n.includes("foot") || n.includes("bash") || n.includes("sh")) return "\u{f120}";
        if (n.includes("file") || n.includes("thunar") || n.includes("nemo") || n.includes("bulk")) return "\u{f07b}";
        if (n.includes("setting") || n.includes("pref") || n.includes("control")) return "\u{f013}";
        if (n.includes("cal") || n.includes("time") || n.includes("clock")) return "\u{f073}";
        if (n.includes("music") || n.includes("audio") || n.includes("sound") || n.includes("play")) return "\u{f001}";
        if (n.includes("browser") || n.includes("web") || n.includes("firefox") || n.includes("chrom")) return "\u{f269}";
        if (n.includes("code") || n.includes("edit") || n.includes("vim") || n.includes("text")) return "\u{f121}";
        if (n.includes("spotlight") || n.includes("search") || n.includes("find")) return "\u{f002}";
        if (n.includes("drop") || n.includes("color") || n.includes("picker")) return "\u{f1fb}";
        if (n.includes("task") || n.includes("monitor") || n.includes("btop") || n.includes("top")) return "\u{f080}";
        if (n.includes("lock")) return "\u{f023}";
        if (n.includes("power") || n.includes("shut") || n.includes("exit")) return "\u{f011}";
        if (n.includes("clip") || n.includes("copy")) return "\u{f0ea}";
        if (n.includes("cmake") || n.includes("build") || n.includes("dev")) return "\u{f085}";
        if (n.includes("avahi") || n.includes("vnc") || n.includes("ssh") || n.includes("net")) return "\u{f6ff}";
        return "\u{f108}";
    }

    function getAppColor(name) {
        const n = (name || "").toLowerCase();
        if (n.includes("term") || n.includes("kitty") || n.includes("foot")) return Design.green;
        if (n.includes("file") || n.includes("thunar") || n.includes("bulk")) return Design.peach;
        if (n.includes("setting") || n.includes("pref") || n.includes("control")) return Design.blue;
        if (n.includes("cal") || n.includes("time") || n.includes("clock")) return Design.red;
        if (n.includes("music") || n.includes("audio")) return Design.mauve;
        if (n.includes("browser") || n.includes("web") || n.includes("firefox")) return Design.peach;
        if (n.includes("code") || n.includes("vim")) return Design.teal;
        if (n.includes("spotlight") || n.includes("search")) return Design.sapphire;
        if (n.includes("cmake")) return Design.yellow;
        return Design.accent;
    }

    function launchApp(app) {
        window.close();
        if (!app || !app.cmd) return;
        let cmd = app.cmd.trim();
        if (cmd.startsWith("b1air-shell") || cmd.startsWith("b1air-daemon")) {
            Quickshell.execDetached(["bash", "-c", cmd]);
            return;
        }
        cmd = cleanExec(cmd);
        Quickshell.execDetached(["swaymsg", "exec", cmd]);
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
                    model: ["All", "System", "Utilities"]
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
                                color: Design.tint(window.getAppColor(modelData.name), itemHover.containsMouse ? 0.25 : 0.14)
                                border.color: itemHover.containsMouse ? window.getAppColor(modelData.name) : Design.tint(window.getAppColor(modelData.name), 0.35)
                                border.width: 1

                                Icon {
                                    anchors.centerIn: parent
                                    text: window.getAppGlyph(modelData.name)
                                    font.pixelSize: Design.s(20)
                                    color: window.getAppColor(modelData.name)
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

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.launchApp(modelData)
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
