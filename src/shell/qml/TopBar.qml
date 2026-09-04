import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "./Ui"
import B1air.Daemon
import "./Services"

PanelWindow {
    id: topBar
    
    signal requestCommand(string cmd, bool notify)

    // Wayland Layer-Shell configuration
    WlrLayershell.namespace: "b1air-topbar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: Design.s(40)
    
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Design.s(38)
    color: "transparent"

    // ── Design Tokens ───────────────────────────────────────────────────────
    // These were a second, hand-rolled Tokyo Night palette living alongside the
    // Catppuccin one in Ui/Design.qml, so the bar never followed the theme. The
    // names stay — they are used throughout this file — but each now resolves
    // to a design-system role.
    readonly property color colBg: Design.glassBg
    readonly property color colBorder: Design.glassBorder
    readonly property color colBlue: Design.accent
    readonly property color colPurple: Design.mauve
    readonly property color colCyan: Design.sapphire
    readonly property color colGreen: Design.ok
    readonly property color colOrange: Design.warn
    readonly property color colRed: Design.danger
    readonly property color colFg: Design.text
    readonly property color colFgDim: Design.textDim
    readonly property color colWrkBg: Design.glassTile
    readonly property color colWrkBorder: Design.line
    readonly property string fontMain: Design.font.sans

    function safePinnedCommand(cmd) {
        const value = (cmd || "").trim();
        const forbidden = [";", "&", "|", "`", "$", "<", ">", "\\", "\n", "\r", "(", ")", "{", "}", "[", "]", "*", "?", "!", "~"];
        if (!value || value.length > 512 || forbidden.some(c => value.includes(c))) return false;
        Quickshell.execDetached(["bash", "-c", value]);
        return true;
    }

    // ── State Trackers ──────────────────────────────────────────────────────
    property string clockTime: "00:00"
    property string clockDate: ""
    property string cpuUsage: "0%"
    property string loadAvg: "0.00"
    property string kbdLayout: "US"
    property var workspacesList: [ { num: 1, name: "1", focused: true } ]
    property var runningApps: []

    function refreshRunningApps() {
        runningAppsProcess.running = false;
        runningAppsProcess.running = true;
    }

    function refreshWorkspaces() {
        workspacesProcess.running = false;
        workspacesProcess.running = true;
    }

    Component.onCompleted: {
        refreshRunningApps();
        refreshWorkspaces();
    }

    function collectSwayNodes(nodes, result, workspaceName) {
        for (let node of (nodes || [])) {
            let currentWorkspace = node.type === "workspace" ? (node.name || workspaceName) : workspaceName;
            let appId = node.app_id || (node.window_properties ? node.window_properties.class : "") || "";
            let title = node.name || appId;
            let children = (node.nodes || []).concat(node.floating_nodes || []);
            if (appId && node.pid && appId !== "b1air-topbar" && appId !== "waybar" && node.type !== "workspace") {
                result.push({ id: node.id, appId: appId, title: title, workspace: currentWorkspace, focused: !!node.focused });
            } else if (children.length > 0) {
                collectSwayNodes(children, result, currentWorkspace);
            }
        }
    }

    function appIcon(appId) {
        const id = (appId || "").toLowerCase();
        if (id.includes("b1air-term")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/utilities-terminal.png";
        if (id.includes("b1air-files")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/system-file-manager.png";
        if (id.includes("b1air-monitor")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/utilities-system-monitor.png";
        if (id.includes("b1air-setting")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/preferences-system.png";
        if (id.includes("b1air-note") || id.includes("b1air-text")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/accessories-text-editor.png";
        if (id.includes("b1air-git")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/applications-development.png";
        if (id.includes("b1air-view")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/mimetypes/image-x-generic.png";
        if (id.includes("firefox") || id.includes("browser")) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/web-browser.png";
        // Never pass an unknown app-id to image://icon: that produces the
        // red/purple missing-icon tile. Use a real system fallback instead.
        return "file:///usr/share/icons/AdwaitaLegacy/48x48/mimetypes/application-x-executable.png";
    }

    function iconSource(icon) {
        const value = (icon || "application-x-executable").trim();
        if (value.startsWith("/") || value.startsWith("file://")) return value.startsWith("file://") ? value : "file://" + value;
        const legacy = {
            "utilities-terminal": "utilities-terminal.png",
            "system-file-manager": "system-file-manager.png",
            "utilities-system-monitor": "utilities-system-monitor.png",
            "preferences-system": "preferences-system.png",
            "web-browser": "web-browser.png",
            "network-wired": "network-wired.png",
            "application-x-executable": "../mimetypes/application-x-executable.png"
        };
        if (legacy[value]) return "file:///usr/share/icons/AdwaitaLegacy/48x48/legacy/" + legacy[value];
        return "image://icon/" + value;
    }

    // Clock Timer (ticks every 1s)
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date();
            topBar.clockTime = Qt.formatTime(now, "hh:mm");
            topBar.clockDate = Qt.formatDate(now, "dddd, d MMMM yyyy");
        }
    }

    // ── Continuous Background State Poller (Realtime Delta CPU, Load, Kbd, Workspaces) ──
    Process {
        id: statePoller
        running: true
        command: [
            "bash", "-c",
            "prev_idle=0; prev_total=0; " +
            "while true; do " +
            "  read -r _ u n s idle iowait irq softirq steal _ < /proc/stat; " +
            "  idle_all=$((idle + iowait)); " +
            "  total=$((u + n + s + idle + iowait + irq + softirq + steal)); " +
            "  diff_idle=$((idle_all - prev_idle)); " +
            "  diff_total=$((total - prev_total)); " +
            "  if [ $prev_total -gt 0 ] && [ $diff_total -gt 0 ]; then " +
            "    cpu=$(( 100 * (diff_total - diff_idle) / diff_total )); " +
            "  else " +
            "    cpu=0; " +
            "  fi; " +
            "  prev_idle=$idle_all; " +
            "  prev_total=$total; " +
            "  LOAD=$(cut -d' ' -f1 /proc/loadavg); " +
            "  KBD=$(b1air-daemon layout 2>/dev/null || echo US); " +
            "  echo \"STATS|${cpu}%|${LOAD}|${KBD}\"; " +
            "  sleep 2; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                let str = ("" + line).trim();
                if (str.startsWith("STATS|")) {
                    let parts = str.split("|");
                    if (parts.length >= 4) {
                        topBar.cpuUsage = parts[1];
                        topBar.loadAvg = parts[2];
                        topBar.kbdLayout = parts[3].toUpperCase();
                    }
                }
            }
        }
    }

    Process {
        id: workspacesProcess
        command: ["bash", "-c", "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1); export SWAYSOCK; swaymsg -t get_workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let ws = JSON.parse(this.text);
                    if (Array.isArray(ws) && ws.length > 0) topBar.workspacesList = ws;
                } catch (e) {}
            }
        }
    }

    Process {
        id: runningAppsProcess
        // Resolve the current socket on every refresh: Sway assigns a new
        // socket after a restart, so inheriting an old SWAYSOCK hides windows.
        command: ["bash", "-c", "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1); export SWAYSOCK; swaymsg -t get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let tree = JSON.parse(this.text);
                    let apps = [];
                    topBar.collectSwayNodes([tree], apps, "");
                    topBar.runningApps = apps;
                } catch (e) {
                    topBar.runningApps = [];
                }
            }
        }
    }

    // Sway pushes window/workspace events, so there is nothing to poll for:
    // one long-lived subscription replaces a get_tree spawn every second.
    Process {
        id: swayEvents
        running: true
        command: [
            "bash", "-c",
            "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1); export SWAYSOCK; " +
            // swaymsg blocks on the sway socket and never notices its stdout closing,
            // so it outlives the shell instead of dying with it. Reap the previous
            // one here: at most one stale subscription can ever exist.
            "for p in $(pgrep -f 'swaymsg -t subscribe -m' 2>/dev/null); do " +
            "  [ \"$p\" != \"$$\" ] && kill \"$p\" 2>/dev/null; done; " +
            "exec swaymsg -t subscribe -m '[\"window\",\"workspace\"]'"
        ]
        stdout: SplitParser {
            // Coalesce bursts: dragging a window emits a stream of events, and one
            // refresh per event would spawn more processes than the old polling did.
            onRead: (line) => { if (("" + line).trim()) swayCoalesce.restart(); }
        }
        // Sway restarts hand out a new socket; reconnect instead of going stale.
        onExited: swayResubscribe.restart()
    }

    Timer {
        id: swayCoalesce
        interval: 120
        onTriggered: {
            topBar.refreshRunningApps();
            topBar.refreshWorkspaces();
        }
    }

    Timer {
        id: swayResubscribe
        interval: 2000
        onTriggered: {
            topBar.refreshRunningApps();
            topBar.refreshWorkspaces();
            swayEvents.running = true;
        }
    }

    // ── Bar Content Layout ──────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 4
        anchors.bottomMargin: 4

        // ══════════════════════════════════════════════════════════════════════
        // LEFT ISLANDS: APPS, Dynamic Pinned Apps, Workspaces
        // ══════════════════════════════════════════════════════════════════════
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. APPS Island (Launchpad on Left Click, Spotlight on Right Click)
            Rectangle {
                id: appMenuBtn
                width: appRow.implicitWidth + 20
                height: 30
                radius: 10
                color: appMenuArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : topBar.colBg
                border.color: appMenuArea.containsMouse ? topBar.colBlue : topBar.colBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: appRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰍜"
                        font.family: Design.font.mono
                        font.pixelSize: Design.s(13)
                        color: topBar.colBlue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "APPS"
                        font.family: topBar.fontMain
                        font.pixelSize: Design.s(12)
                        font.bold: true
                        color: appMenuArea.containsMouse ? "#ffffff" : topBar.colBlue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: appMenuArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            topBar.requestCommand("toggle:spotlight:", true);
                        } else {
                            topBar.requestCommand("toggle:launchpad:", true);
                        }
                    }
                }
            }

            // 2. User-Configured Pinned Apps Island
            Rectangle {
                height: 30
                width: pinnedRow.implicitWidth + 14
                radius: 10
                color: topBar.colBg
                border.color: topBar.colBorder
                border.width: 1
                visible: PinnedApps.pinnedList.length > 0

                Row {
                    id: pinnedRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: PinnedApps.pinnedList
                        delegate: Rectangle {
                            id: pinPill
                            width: 24
                            height: 24
                            radius: 6
                            color: pinArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.22) : "transparent"

                            IconImage {
                                anchors.centerIn: parent
                                width: 17
                                height: 17
                                source: topBar.iconSource(modelData.icon)
                                mipmap: true
                            }

                            MouseArea {
                                id: pinArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        // Unpin immediately on right click!
                                        PinnedApps.togglePin(modelData);
                                    } else {
                                        let cmd = modelData.cmd || "";
                                        if (cmd.startsWith("toggle:")) {
                                            topBar.requestCommand(cmd, true);
                                        } else if (cmd.startsWith("open:")) {
                                            topBar.requestCommand(cmd, true);
                                        } else {
                                            topBar.safePinnedCommand(cmd);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Add Pinned App '+' Button
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 5
                        color: addPinArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰐕"
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(11)
                            color: addPinArea.containsMouse ? topBar.colBlue : topBar.colFgDim
                        }

                        MouseArea {
                            id: addPinArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: topBar.requestCommand("toggle:launchpad:", true)
                        }
                    }
                }
            }

            // 3. Workspaces Island
            Rectangle {
                id: workspacesIsland
                height: 30
                width: workspacesRow.implicitWidth + 12
                radius: 10
                color: topBar.colBg
                border.color: topBar.colBorder
                border.width: 1

                Row {
                    id: workspacesRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: topBar.workspacesList
                        delegate: Rectangle {
                            id: wsPill
                            width: wsText.implicitWidth + 14
                            height: 22
                            radius: 6
                            color: modelData.focused ? topBar.colBlue : (wsMouseArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : topBar.colWrkBg)
                            border.color: modelData.focused ? "transparent" : topBar.colWrkBorder
                            border.width: 1

                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: modelData.name || (index + 1)
                                font.family: topBar.fontMain
                                font.pixelSize: Design.s(11)
                                font.bold: true
                                color: modelData.focused ? "#101014" : (wsMouseArea.containsMouse ? topBar.colBlue : topBar.colFgDim)
                            }

                            MouseArea {
                                id: wsMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const workspace = String(modelData.name || (index + 1));
                                    if (/^[A-Za-z0-9_.-]+$/.test(workspace))
                                        Quickshell.execDetached(["swaymsg", "workspace", workspace]);
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg workspace prev"]);
                        } else if (wheel.angleDelta.y < 0) {
                            Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg workspace next"]);
                        }
                    }
                }
            }

            // Old Waybar placed the taskbar after workspaces on the left.
            // Keep that topology, but render compact native icons.
            Row {
                id: runningAppsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                visible: topBar.runningApps.length > 0

                Repeater {
                    model: topBar.runningApps
                    delegate: Rectangle {
                        width: 28
                        height: 28
                        radius: 7
                        color: modelData.focused ? Qt.rgba(122/255, 162/255, 247/255, 0.22) : topBar.colBg
                        border.color: modelData.focused ? topBar.colBlue : topBar.colBorder
                        border.width: 1

                        IconImage {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: topBar.iconSource(topBar.appIcon(modelData.appId))
                            mipmap: true
                        }

                        MouseArea {
                            id: runningArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1); export SWAYSOCK; swaymsg '[con_id=" + String(modelData.id) + "] focus'"])
                        }

                        ToolTip.visible: runningArea.containsMouse
                        ToolTip.text: modelData.title || modelData.appId
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // CENTER ISLAND: Floating Clock Pill (Calendar, Focus Time, Updater)
        // ══════════════════════════════════════════════════════════════════════
        Rectangle {
            id: clockPill
            anchors.centerIn: parent
            width: clockText.implicitWidth + 36
            height: 28
            radius: 999
            color: clockArea.containsMouse ? "#89b4fa" : topBar.colBlue

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: clockText
                anchors.centerIn: parent
                text: topBar.clockTime
                font.family: topBar.fontMain
                font.pixelSize: Design.s(13)
                font.bold: true
                color: topBar.colFg
            }

            MouseArea {
                id: clockArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        topBar.requestCommand("toggle:focustime:", true);
                    } else if (mouse.button === Qt.RightButton) {
                        topBar.requestCommand("toggle:pollkit:", true);
                    } else {
                        topBar.requestCommand("toggle:calendar:", true);
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // RIGHT ISLANDS: Stats, System Status
        // ══════════════════════════════════════════════════════════════════════
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. Stats Island (CPU + Load/RAM)
            Rectangle {
                height: 30
                width: statsRow.implicitWidth + 20
                radius: 10
                color: statsArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.15) : topBar.colBg
                border.color: statsArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.35) : topBar.colBorder
                border.width: 1

                Row {
                    id: statsRow
                    anchors.centerIn: parent
                    spacing: 10

                    Row {
                        spacing: 4
                        Text { text: ""; font.family: topBar.fontMain; font.pixelSize: Design.s(12); color: topBar.colCyan }
                        Text { text: topBar.cpuUsage; font.family: topBar.fontMain; font.pixelSize: Design.s(11); font.bold: true; color: topBar.colFg }
                    }

                    Row {
                        spacing: 4
                        Text { text: "󰍛"; font.family: topBar.fontMain; font.pixelSize: Design.s(12); color: topBar.colPurple }
                        Text { text: topBar.loadAvg; font.family: topBar.fontMain; font.pixelSize: Design.s(11); font.bold: true; color: topBar.colFg }
                    }
                }

                MouseArea {
                    id: statsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["b1air-monitor"])
                }
            }

            // 2. System Status Island (Layout, Volume, Battery, Bell, Power)
            Rectangle {
                height: 30
                width: systemRow.implicitWidth + 20
                radius: 10
                color: topBar.colBg
                border.color: topBar.colBorder
                border.width: 1

                Row {
                    id: systemRow
                    anchors.centerIn: parent
                    spacing: 10

                    // Keyboard Layout Pill
                    Rectangle {
                        width: kbdText.implicitWidth + 10
                        height: 20
                        radius: 5
                        color: kbdArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text {
                            id: kbdText
                            anchors.centerIn: parent
                            text: topBar.kbdLayout
                            font.family: topBar.fontMain
                            font.pixelSize: Design.s(11)
                            font.bold: true
                            color: topBar.colFg
                        }
                        MouseArea {
                            id: kbdArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg input type:keyboard xkb_switch_layout next && b1air-daemon layout"]);
                            }
                        }
                    }

                    // Volume Pill
                    Item {
                        width: volRow.implicitWidth
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: volRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) ? "󰖁" : "󰕾"
                                font.family: topBar.fontMain
                                font.pixelSize: Design.s(13)
                                color: (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) ? topBar.colRed : topBar.colFgDim
                            }
                            Text {
                                text: (Audio.defaultSink && Audio.defaultSink.audio) ? Math.round(Audio.defaultSink.audio.volume * 100) + "%" : "65%"
                                font.family: topBar.fontMain
                                font.pixelSize: Design.s(11)
                                font.bold: true
                                color: topBar.colFg
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: topBar.requestCommand("toggle:control:", true)
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    Daemon.volumeUp(5);
                                } else if (wheel.angleDelta.y < 0) {
                                    Daemon.volumeDown(5);
                                }
                            }
                        }
                    }

                    // Battery Pill (if present)
                    Item {
                        visible: Power.hasBattery
                        width: batRow.implicitWidth
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: batRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: Power.charging ? "󰂄" : "󰁹"
                                font.family: topBar.fontMain
                                font.pixelSize: Design.s(13)
                                color: Power.charging ? "#a6e3a1" : topBar.colFgDim
                            }
                            Text {
                                text: Power.capacity + "%"
                                font.family: topBar.fontMain
                                font.pixelSize: Design.s(11)
                                font.bold: true
                                color: topBar.colFg
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: topBar.requestCommand("toggle:battery:", true)
                        }
                    }

                    // Notification Bell (opens Control Center)
                    Rectangle {
                        width: 20; height: 20; radius: 5
                        color: bellArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            font.family: topBar.fontMain
                            font.pixelSize: Design.s(13)
                            color: topBar.colFgDim
                        }
                        MouseArea {
                            id: bellArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: topBar.requestCommand("toggle:control:", true)
                        }
                    }

                    // Power Button (opens Session Menu)
                    Rectangle {
                        id: powerBtn
                        width: 22; height: 22; radius: 6
                        color: powerArea.containsMouse ? Qt.rgba(247/255, 118/255, 142/255, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            font.family: topBar.fontMain
                            font.pixelSize: Design.s(13)
                            font.bold: true
                            color: topBar.colRed
                        }

                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: topBar.requestCommand("toggle:session:", true)
                        }
                    }
                }
            }
        }
    }
}
