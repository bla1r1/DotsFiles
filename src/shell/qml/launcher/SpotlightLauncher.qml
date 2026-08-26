import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Ui"
import "../Services"

// =============================================================================
// Native Quickshell Spotlight Launcher & Command Palette (Dynamic Apps Scanner)
// =============================================================================

PopupShell {
    id: window

    padding: Design.space.md

    property string query: ""
    property int selectedIndex: 0
    property string calcResult: ""
    property var systemApps: []

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
                            cat: "Applications"
                        });
                    }
                    window.systemApps = res;
                } catch (e) {}
            }
        }
    }

    // ── Quick Commands & Core Actions ────────────────────────────────────────
    readonly property var baseApps: [
        { name: "Terminal", desc: "Launch Kitty Terminal emulator", icon: "\u{f120}", cmd: "kitty", cat: "System" },
        { name: "Web Browser", desc: "Browse the web (Firefox)", icon: "\u{f269}", cmd: "firefox", cat: "Internet" },
        { name: "File Manager", desc: "Browse files and folders", icon: "\u{f07b}", cmd: "thunar", cat: "System" },
        { name: "Settings", desc: "Open System & Desktop Settings", icon: "\u{f013}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main toggleSettings", cat: "System" },
        { name: "Control Center", desc: "Quick toggles & notifications", icon: "\u{f0f3}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main toggleControl", cat: "System" },
        { name: "Clipboard Manager", desc: "Search clipboard history & snippets", icon: "\u{f0ea}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main toggleClipboard", cat: "Utilities" },
        { name: "Color Dropper", desc: "Pick any color on screen to clipboard", icon: "\u{f1fb}", cmd: Quickshell.env("HOME") + "/.local/bin/b1air-daemon color-picker", cat: "Utilities" },
        { name: "Window Switcher", desc: "Visual Alt+Tab task manager", icon: "\u{f009}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main toggleSwitcher", cat: "System" },
        { name: "Wallpaper Gallery", desc: "Browse and set desktop wallpapers", icon: "\u{f03e}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main open settings wallpaper", cat: "Appearance" },
        { name: "Focus & Screen Time", desc: "Pomodoro timer & usage breakdown", icon: "\u{f017}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main toggleFocusTime", cat: "Utilities" },
        { name: "Lock Screen", desc: "Lock current user session", icon: "\u{f023}", cmd: Quickshell.env("HOME") + "/.local/bin/b1air-daemon power lock", cat: "Session" },
        { name: "Power & Session", desc: "Shutdown, reboot, sleep options", icon: "\u{f011}", cmd: "qs -p " + Quickshell.env("HOME") + "/.config/quickshell/Main.qml ipc call main open session", cat: "Session" },
        { name: "Screenshot (Area)", desc: "Capture selected region", icon: "\u{f030}", cmd: Quickshell.env("HOME") + "/.local/bin/b1air-daemon screenshot area", cat: "Utilities" },
        { name: "Screenshot (Full)", desc: "Capture entire screen", icon: "\u{f108}", cmd: Quickshell.env("HOME") + "/.local/bin/b1air-daemon screenshot full", cat: "Utilities" },
        { name: "Btop System Monitor", desc: "Terminal task manager", icon: "\u{f080}", cmd: "kitty btop", cat: "System" }
    ]

    function evaluateMath(expr) {
        const clean = expr.trim();
        if (!/^[\d\s\+\-\*\/\%\(\)\.\,\^sqrtPIEsincoztan]+$/i.test(clean)) return "";
        if (!/[\+\-\*\/\%]|sqrt|sin|cos|tan/i.test(clean)) return "";
        try {
            let sanitized = clean.replace(/sqrt\(([^)]+)\)/gi, "Math.sqrt($1)")
                                 .replace(/sin\(([^)]+)\)/gi, "Math.sin($1)")
                                 .replace(/cos\(([^)]+)\)/gi, "Math.cos($1)")
                                 .replace(/tan\(([^)]+)\)/gi, "Math.tan($1)")
                                 .replace(/\^/g, "**")
                                 .replace(/\bPI\b/gi, "Math.PI")
                                 .replace(/\bE\b/g, "Math.E");
            const res = Function('"use strict"; return (' + sanitized + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return (Math.round(res * 100000) / 100000).toString();
            }
        } catch (e) {
            return "";
        }
        return "";
    }

    onQueryChanged: {
        window.calcResult = evaluateMath(window.query);
        window.selectedIndex = 0;
    }

    readonly property var allApps: window.baseApps.concat(window.systemApps)

    readonly property var filteredApps: {
        const q = window.query.trim().toLowerCase();
        if (!q) return window.baseApps;
        return window.allApps.filter(a => {
            return a.name.toLowerCase().includes(q) ||
                   a.desc.toLowerCase().includes(q) ||
                   a.cat.toLowerCase().includes(q) ||
                   a.cmd.toLowerCase().includes(q);
        });
    }

    function execute(item) {
        window.close();
        if (typeof item === "string") {
            Quickshell.execDetached(["bash", "-c", item]);
        } else if (item && item.cmd) {
            Quickshell.execDetached(["bash", "-c", item.cmd]);
        }
    }

    function copyResult() {
        if (window.calcResult) {
            Quickshell.execDetached(["wl-copy", window.calcResult]);
            window.close();
        }
    }

    // Auto-focus on open
    Component.onCompleted: {
        searchInput.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.sm)

        // ── Search Bar ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(48)
            radius: Design.s(Design.radius.ctl)
            color: Design.sunken
            border.color: searchInput.activeFocus ? Design.accent : Design.veilStrong
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.s(Design.space.md)
                anchors.rightMargin: Design.s(Design.space.md)
                spacing: Design.s(Design.space.sm)

                Icon {
                    text: "\u{f002}" // search icon
                    role: "body"
                    color: searchInput.activeFocus ? Design.accent : Design.textDim
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Design.font.sans
                    font.weight: Design.weight.medium
                    font.pixelSize: Design.s(15)
                    color: Design.text
                    selectByMouse: true
                    clip: true

                    text: window.query
                    onTextChanged: window.query = text

                    Keys.onEscapePressed: window.close()
                    Keys.onDownPressed: {
                        const total = window.calcResult ? window.filteredApps.length + 1 : window.filteredApps.length;
                        if (total > 0) window.selectedIndex = (window.selectedIndex + 1) % total;
                    }
                    Keys.onUpPressed: {
                        const total = window.calcResult ? window.filteredApps.length + 1 : window.filteredApps.length;
                        if (total > 0) window.selectedIndex = (window.selectedIndex - 1 + total) % total;
                    }
                    Keys.onReturnPressed: {
                        if (window.calcResult && window.selectedIndex === 0) {
                            window.copyResult();
                        } else {
                            const adjIdx = window.calcResult ? window.selectedIndex - 1 : window.selectedIndex;
                            if (adjIdx >= 0 && adjIdx < window.filteredApps.length) {
                                window.execute(window.filteredApps[adjIdx]);
                            } else if (window.query.trim()) {
                                window.execute(window.query.trim());
                            }
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search all apps, calculate (e.g. 45 * 12), or run command..."
                        color: Design.textDim
                        role: "body"
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }

                IconButton {
                    visible: searchInput.text.length > 0
                    icon: "\u{f00d}" // cross
                    role: "caption"
                    onClicked: {
                        searchInput.text = "";
                        searchInput.forceActiveFocus();
                    }
                }
            }
        }

        // ── Calculator Result Card ───────────────────────────────────────────
        Rectangle {
            visible: window.calcResult !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(44)
            radius: Design.s(Design.radius.ctl)
            color: window.selectedIndex === 0 ? Design.tint(Design.accent, 0.15) : Design.sunken
            border.color: window.selectedIndex === 0 ? Design.accent : Design.veilStrong
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.s(Design.space.md)
                anchors.rightMargin: Design.s(Design.space.md)
                spacing: Design.s(Design.space.md)

                Icon {
                    text: "\u{f1ec}" // calculator
                    color: Design.accent
                    role: "body"
                }

                Label {
                    text: "= " + window.calcResult
                    role: "body"
                    weight: Design.weight.bold
                    isMono: true
                    color: Design.accent
                    Layout.fillWidth: true
                }

                Badge {
                    text: "Click or Enter to copy"
                    tone: Design.accent
                }
            }

            Clickable {
                hoverEnabled: true
                onClicked: window.copyResult()
            }
        }

        // ── Results List ─────────────────────────────────────────────────────
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Design.s(360), window.filteredApps.length * Design.s(48))
            clip: true
            model: window.filteredApps
            currentIndex: window.calcResult ? window.selectedIndex - 1 : window.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            spacing: Design.s(2)

            ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: rowRect
                required property var modelData
                required property int index

                readonly property int realIdx: window.calcResult ? rowRect.index + 1 : rowRect.index
                readonly property bool isSelected: window.selectedIndex === realIdx

                width: resultsList.width - (resultsList.ScrollBar.vertical.visible ? Design.s(12) : 0)
                height: Design.s(44)
                radius: Design.s(Design.radius.ctl)
                color: isSelected ? Design.tint(Design.accent, 0.15) : (rowHover.containsMouse ? Design.raised : Design.surface)
                border.color: isSelected ? Design.accent : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.md)
                    anchors.rightMargin: Design.s(Design.space.md)
                    spacing: Design.s(Design.space.md)

                    Image {
                        Layout.preferredWidth: Design.s(22)
                        Layout.preferredHeight: Design.s(22)
                        source: rowRect.modelData.app_id ? (rowRect.modelData.app_id.startsWith("/") ? "file://" + rowRect.modelData.app_id : "image://icon/" + rowRect.modelData.app_id) : ""
                        visible: source.toString() !== ""
                        fillMode: Image.PreserveAspectFit
                    }

                    Icon {
                        visible: !parent.children[0].visible
                        text: rowRect.modelData.icon || "\u{f108}"
                        color: rowRect.isSelected ? Design.accent : Design.text
                        role: "body"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            text: rowRect.modelData.name
                            weight: Design.weight.semibold
                            color: rowRect.isSelected ? Design.text : Design.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            text: rowRect.modelData.desc
                            role: "caption"
                            color: Design.textDim
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Badge {
                        text: rowRect.modelData.cat
                        tone: rowRect.isSelected ? Design.accent : Design.textDim
                    }
                }

                Clickable {
                    id: rowHover
                    hoverEnabled: true
                    onClicked: window.execute(rowRect.modelData)
                }
            }
        }
    }
}
