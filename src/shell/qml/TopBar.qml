import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "./Ui"
import B1air.Daemon
import "./Services"

PanelWindow {
    id: topBar

    // The sway IPC socket, resolved once and kept current.
    //
    // Every swaymsg call below used to open a shell purely to run
    //     SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock | head -n1)
    // because a shell that outlives a sway restart would otherwise inherit a
    // dead socket. The concern is real, the per-call glob is not: listing the
    // directory here follows a restart by itself, and the value is handed to
    // each process through its environment instead of through `bash -c`.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"

    property string swaySock: Quickshell.env("SWAYSOCK") || ""

    FolderListModel {
        id: swaySockets
        folder: "file://" + topBar.runtimeDir
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        sortField: FolderListModel.Time
        onCountChanged: {
            // nameFilters matches files, and these are sockets, so the newest
            // sway-ipc.*.sock is picked out by hand.
            for (let i = 0; i < count; ++i) {
                const n = String(get(i, "fileName"));
                if (n.startsWith("sway-ipc.") && n.endsWith(".sock")) {
                    topBar.swaySock = topBar.runtimeDir + "/" + n;
                    return;
                }
            }
        }
    }

    readonly property var swayEnv: ({ "SWAYSOCK": topBar.swaySock })

    /**
     * The workspace strip: 1..Settings.workspaceCount, plus anything sway has
     * outside that range.
     *
     * The bar used to draw only the workspaces sway currently reports, so
     * "Workspace count" in Settings → Native Top Bar — which says in as many
     * words "how many workspace numbers the bar shows" — changed nothing at
     * all. Showing the empty ones is also what makes them reachable: a
     * workspace you have never visited has no pill to click.
     */
    readonly property var workspaceSlots: {
        const live = {};
        for (const w of topBar.workspacesList)
            live[String(w.name !== undefined ? w.name : w.num)] = w;

        const out = [];
        const count = Math.max(1, Settings.workspaceCount || 10);
        for (let i = 1; i <= count; ++i) {
            const key = String(i);
            const w = live[key];
            out.push({ name: key, focused: w ? !!w.focused : false, exists: !!w });
            delete live[key];
        }
        // Named or out-of-range workspaces still have to be reachable.
        for (const key in live)
            out.push({ name: key, focused: !!live[key].focused, exists: true });
        return out;
    }

    // The Game Mode page has offered "Hide Waybar — automatically hide top
    // status bar during gaming sessions" since it was written. There is no
    // waybar in this project (the native bar below replaced it, and the
    // .config/waybar the README's tree claims does not exist), and nothing
    // read the setting, so the toggle stored a value and the bar never moved.
    // Hiding the PanelWindow also releases its exclusive zone, so tiled windows
    // reclaim the strip.
    visible: !(Settings.gameModeEnabled && Settings.gameModeHideBar)
    
    signal requestCommand(string cmd, bool notify)

    // Wayland Layer-Shell configuration
    WlrLayershell.namespace: "b1air-topbar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: Design.s(40)
    
    // Settings → Native Top Bar has a Top/Bottom control; nothing read it, so
    // the bar was anchored to the top whatever it said.
    anchors.top: Settings.barPosition !== "bottom"
    anchors.bottom: Settings.barPosition === "bottom"
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
        // The desktop entry first: it knows the icon, and it resolves through
        // whatever theme the desktop is set to, so a window in the bar looks
        // like the same window in the switcher and the launcher. The chain
        // below pinned seven of our own app-ids to AdwaitaLegacy PNGs and gave
        // every other application on the machine the same grey executable box.
        const fromEntry = Apps.iconFor(appId);
        if (fromEntry !== "")
            return fromEntry.startsWith("/") ? "file://" + fromEntry : "image://icon/" + fromEntry;

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
            // Settings → Native Top Bar offers a 24-hour toggle. Nothing read
            // it: the bar formatted "hh:mm" unconditionally, so the switch
            // stored a value and the clock never changed.
            topBar.clockTime = Qt.formatTime(now, Settings.barClock24h ? "hh:mm" : "h:mm AP");
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
        command: ["swaymsg", "-t", "get_workspaces"]
        environment: topBar.swayEnv
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
        command: ["swaymsg", "-t", "get_tree"]
        environment: topBar.swayEnv
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
            // SWAYSOCK arrives through `environment` below; the shell is still
            // needed here only for the pgrep/kill reap loop.
            // swaymsg blocks on the sway socket and never notices its stdout closing,
            // so it outlives the shell instead of dying with it. Reap the previous
            // one here: at most one stale subscription can ever exist.
            "for p in $(pgrep -f 'swaymsg -t subscribe -m' 2>/dev/null); do " +
            "  [ \"$p\" != \"$$\" ] && kill \"$p\" 2>/dev/null; done; " +
            "exec swaymsg -t subscribe -m '[\"window\",\"workspace\"]'"
        ]
        environment: topBar.swayEnv
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
                color: appMenuArea.containsMouse ? Design.tint(Design.accent, 0.25) : topBar.colBg
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
                            color: pinArea.containsMouse ? Design.tint(Design.accent, 0.22) : "transparent"

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
                        color: addPinArea.containsMouse ? Design.tint(Design.accent, 0.25) : "transparent"
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
                        model: topBar.workspaceSlots
                        delegate: Rectangle {
                            id: wsPill
                            required property var modelData

                            width: wsText.implicitWidth + 14
                            height: 22
                            radius: 6
                            color: wsPill.modelData.focused ? topBar.colBlue
                                 : (wsMouseArea.containsMouse ? Design.tint(Design.accent, 0.20) : topBar.colWrkBg)
                            border.color: wsPill.modelData.focused ? "transparent" : topBar.colWrkBorder
                            border.width: 1

                            // An empty slot is a place you can go, not a place
                            // you are; it says so by being fainter rather than
                            // by being missing.
                            opacity: wsPill.modelData.exists || wsPill.modelData.focused ? 1.0 : 0.45

                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: wsPill.modelData.name
                                font.family: topBar.fontMain
                                font.pixelSize: Design.s(11)
                                font.bold: true
                                color: wsPill.modelData.focused ? Design.accentText
                                     : (wsMouseArea.containsMouse ? topBar.colBlue : topBar.colFgDim)
                            }

                            MouseArea {
                                id: wsMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const workspace = String(wsPill.modelData.name);
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
                            Quickshell.execDetached({ command: ["swaymsg", "workspace", "prev"], environment: topBar.swayEnv });
                        } else if (wheel.angleDelta.y < 0) {
                            Quickshell.execDetached({ command: ["swaymsg", "workspace", "next"], environment: topBar.swayEnv });
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
                        color: modelData.focused ? Design.tint(Design.accent, 0.22) : topBar.colBg
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
                            onClicked: Quickshell.execDetached({
                                command: ["swaymsg", "[con_id=" + String(modelData.id) + "] focus"],
                                environment: topBar.swayEnv
                            })
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
            color: clockArea.containsMouse ? Qt.lighter(topBar.colBlue, 1.25) : topBar.colBlue

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
        // FOCUS TIMER PILL — only while a focus interval is running
        // ══════════════════════════════════════════════════════════════════════
        //
        // A timer you cannot see is not much of a timer, and its own window is
        // a full screen-time dashboard. Left of the clock, present only when
        // there is something to show; click to pause or resume, middle-click
        // for the dashboard.
        Rectangle {
            id: focusPill
            visible: Focus.active
            anchors.right: clockPill.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: focusRow.implicitWidth + 22
            height: 28
            radius: 999

            readonly property color tone: Focus.onBreak ? Design.green : Design.sapphire
            color: focusArea.containsMouse ? Qt.alpha(tone, 0.32) : Qt.alpha(tone, 0.18)
            border.width: 1
            border.color: Qt.alpha(tone, Focus.running ? 0.55 : 0.28)

            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: focusRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Paused shows the play glyph: it is what the click does.
                    text: Focus.running ? "\u{f0520}" : "\u{f040a}"
                    font.family: Design.font.icon
                    font.pixelSize: Design.s(12)
                    color: focusPill.tone
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Focus.remainingText
                    font.family: topBar.fontMain
                    font.pixelSize: Design.s(12)
                    font.bold: true
                    color: focusPill.tone
                    opacity: Focus.running ? 1.0 : 0.65
                }
            }

            MouseArea {
                id: focusArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton)
                        topBar.requestCommand("toggle:focustime:", true);
                    else
                        Focus.toggle();
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

            // 0. Media title and weather.
            //
            // Settings → Native Top Bar has offered "Media Player Title —
            // display currently playing track name and artist" and "Weather
            // Status — show temperature and weather condition badge" since it
            // was written, and the bar had neither module: the two switches
            // stored a value nothing read. Both services already exist and are
            // used by the Control Center, so this is wiring, not new plumbing.

            Rectangle {
                height: 30
                width: mediaRow.implicitWidth + 20
                radius: 10
                color: mediaArea.containsMouse ? Design.tint(Design.mauve, 0.15) : topBar.colBg
                border.color: mediaArea.containsMouse ? Design.tint(Design.mauve, 0.35) : topBar.colBorder
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                // Only when asked for, and only when there is something to say.
                visible: Settings.barShowMedia && Media.hasPlayer
                         && String(Media.track.title || "") !== ""

                Row {
                    id: mediaRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: Media.playing ? "\u{f040a}" : "\u{f03e4}"
                        font.family: Design.font.icon
                        font.pixelSize: Design.s(12)
                        color: topBar.colBlue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        // Elided rather than allowed to push the clock off
                        // centre: a track title is arbitrarily long.
                        width: Math.min(implicitWidth, Design.s(220))
                        elide: Text.ElideRight
                        text: (Media.track.artist ? Media.track.artist + " — " : "")
                              + (Media.track.title || "")
                        font.family: topBar.fontMain
                        font.pixelSize: Design.s(11)
                        color: topBar.colFgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: mediaArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: topBar.requestCommand("toggle:music:", true)
                }
            }

            Rectangle {
                height: 30
                width: weatherRow.implicitWidth + 20
                radius: 10
                color: weatherArea.containsMouse ? Design.tint(Design.sapphire, 0.15) : topBar.colBg
                border.color: weatherArea.containsMouse ? Design.tint(Design.sapphire, 0.35) : topBar.colBorder
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                visible: Settings.barShowWeather && Weather.loaded

                Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: Weather.icon
                        font.family: Design.font.icon
                        font.pixelSize: Design.s(12)
                        color: topBar.colCyan
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: Weather.temp
                        font.family: topBar.fontMain
                        font.pixelSize: Design.s(11)
                        font.bold: true
                        color: topBar.colFgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: weatherArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: topBar.requestCommand("toggle:calendar:", true)
                }
            }

            // 0b. System tray.
            //
            // The third switch on that page with nothing behind it. Quickshell
            // ships the StatusNotifierItem host; the bar simply never used it,
            // so background applets — Telegram, Steam, the ones the setting
            // names — had nowhere to appear on this desktop at all.
            Rectangle {
                height: 30
                width: trayRow.implicitWidth + 20
                radius: 10
                color: topBar.colBg
                border.color: topBar.colBorder
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                // No applets means no empty pill sitting in the bar.
                visible: Settings.barShowTray && SystemTray.items.values.length > 0

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            required property var modelData
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                anchors.fill: parent
                                source: parent.modelData.icon
                                asynchronous: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                // The three gestures a tray icon is expected to
                                // answer, rather than only the first one.
                                onClicked: mouse => {
                                    const item = parent.modelData;
                                    if (mouse.button === Qt.MiddleButton)
                                        item.secondaryActivate();
                                    else if (mouse.button === Qt.RightButton)
                                        item.display(topBar, 0, Design.s(34));
                                    else
                                        item.activate();
                                }
                            }
                        }
                    }
                }
            }

            // 1. Stats Island (CPU + Load/RAM)
            Rectangle {
                height: 30
                width: statsRow.implicitWidth + 20
                radius: 10
                color: statsArea.containsMouse ? Design.tint(Design.accent, 0.15) : topBar.colBg
                border.color: statsArea.containsMouse ? Design.tint(Design.accent, 0.35) : topBar.colBorder
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
                        color: kbdArea.containsMouse ? Design.tint(Design.accent, 0.20) : "transparent"
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
                                Quickshell.execDetached({
                                    command: ["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"],
                                    environment: topBar.swayEnv
                                });
                                Quickshell.execDetached(["b1air-daemon", "layout"]);
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
                                color: Power.charging ? Design.ok : topBar.colFgDim
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
                        color: bellArea.containsMouse ? Design.tint(Design.accent, 0.20) : "transparent"
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
                        color: powerArea.containsMouse ? Design.tint(Design.danger, 0.25) : "transparent"

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
