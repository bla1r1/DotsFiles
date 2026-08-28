import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./Services"

PanelWindow {
    id: topBar
    
    signal requestCommand(string cmd, bool notify)

    // Wayland Layer-Shell configuration
    WlrLayershell.namespace: "b1air-topbar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 40
    
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 38
    color: "transparent"

    // ── Design Tokens ───────────────────────────────────────────────────────
    readonly property color colBg: Qt.rgba(26/255, 27/255, 38/255, 0.88)
    readonly property color colBorder: Qt.rgba(122/255, 162/255, 247/255, 0.22)
    readonly property color colBlue: "#7aa2f7"
    readonly property color colPurple: "#bb9af7"
    readonly property color colCyan: "#7dcfff"
    readonly property color colGreen: "#73daca"
    readonly property color colOrange: "#ff9e64"
    readonly property color colRed: "#f7768e"
    readonly property color colFg: "#c0caf5"
    readonly property color colFgDim: "#a9b1d6"
    readonly property color colWrkBg: Qt.rgba(36/255, 40/255, 59/255, 0.60)
    readonly property color colWrkBorder: Qt.rgba(65/255, 72/255, 104/255, 0.40)
    readonly property string fontMain: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"

    // ── State Trackers ──────────────────────────────────────────────────────
    property string clockTime: "00:00"
    property string clockDate: ""
    property string cpuUsage: "0%"
    property string loadAvg: "0.00"
    property string kbdLayout: "US"
    property var workspacesList: [ { num: 1, name: "1", focused: true } ]

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
            "  SWAYSOCK=$(ls -t /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -n1); " +
            "  WS=$(swaymsg -t get_workspaces 2>/dev/null || echo '[]'); " +
            "  echo \"WS|${WS}\"; " +
            "  sleep 1; " +
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
                } else if (str.startsWith("WS|")) {
                    let jsonStr = str.substring(3);
                    try {
                        let ws = JSON.parse(jsonStr);
                        if (Array.isArray(ws) && ws.length > 0) {
                            topBar.workspacesList = ws;
                        }
                    } catch(e) {}
                }
            }
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
        // LEFT ISLANDS: APPS, Quicklinks, Workspaces
        // ══════════════════════════════════════════════════════════════════════
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. APPS Island (Launchpad on Left Click, Spotlight on Right Click)
            Rectangle {
                id: appMenuBtn
                width: appMenuText.implicitWidth + 28
                height: 30
                radius: 10
                color: appMenuArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : topBar.colBg
                border.color: appMenuArea.containsMouse ? topBar.colBlue : topBar.colBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    id: appMenuText
                    anchors.centerIn: parent
                    text: "APPS"
                    font.family: topBar.fontMain
                    font.pixelSize: 12
                    font.bold: true
                    color: appMenuArea.containsMouse ? "#ffffff" : topBar.colBlue
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

            // 2. Quicklinks Island (Files, Night Light, Term, Calc, Control Center)
            Rectangle {
                height: 30
                width: quicklinksRow.implicitWidth + 16
                radius: 10
                color: topBar.colBg
                border.color: topBar.colBorder
                border.width: 1

                Row {
                    id: quicklinksRow
                    anchors.centerIn: parent
                    spacing: 6

                    // File Manager
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: qlFilesArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 13 }
                        MouseArea {
                            id: qlFilesArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["b1air-files"])
                        }
                    }

                    // Night Light / Mode
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: qlNightArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text { anchors.centerIn: parent; text: "🌘"; font.pixelSize: 13 }
                        MouseArea {
                            id: qlNightArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["b1air-daemon", "night-light", "toggle"])
                        }
                    }

                    // Terminal
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: qlTermArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text { anchors.centerIn: parent; text: "💻"; font.pixelSize: 13 }
                        MouseArea {
                            id: qlTermArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["b1air-term"])
                        }
                    }

                    // Calculator
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: qlCalcArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text { anchors.centerIn: parent; text: "🔢"; font.pixelSize: 13 }
                        MouseArea {
                            id: qlCalcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["b1air-calc"])
                        }
                    }

                    // Notes
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: qlNotesArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text { anchors.centerIn: parent; text: "📝"; font.pixelSize: 13 }
                        MouseArea {
                            id: qlNotesArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["b1air-notes"])
                        }
                    }

                    // Settings / Control Center
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: qlSettingsArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"
                        Text { anchors.centerIn: parent; text: "🛠️"; font.pixelSize: 13 }
                        MouseArea {
                            id: qlSettingsArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: topBar.requestCommand("toggle:control:", true)
                        }
                    }
                }
            }

            // 3. Workspaces Island
            Rectangle {
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
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.focused ? "#101014" : (wsMouseArea.containsMouse ? topBar.colBlue : topBar.colFgDim)
                            }

                            MouseArea {
                                id: wsMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg workspace " + (modelData.name || (index + 1))]);
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
                            Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg workspace prev"]);
                        } else if (wheel.angleDelta.y < 0) {
                            Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg workspace next"]);
                        }
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
                font.pixelSize: 13
                font.bold: true
                color: "#ffffff"
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
                        topBar.requestCommand("toggle:updater:", true);
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
                        Text { text: ""; font.family: topBar.fontMain; font.pixelSize: 12; color: topBar.colCyan }
                        Text { text: topBar.cpuUsage; font.family: topBar.fontMain; font.pixelSize: 11; font.bold: true; color: topBar.colFg }
                    }

                    Row {
                        spacing: 4
                        Text { text: "󰍛"; font.family: topBar.fontMain; font.pixelSize: 12; color: topBar.colPurple }
                        Text { text: topBar.loadAvg; font.family: topBar.fontMain; font.pixelSize: 11; font.bold: true; color: topBar.colFg }
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
                            font.pixelSize: 11
                            font.bold: true
                            color: topBar.colFg
                        }
                        MouseArea {
                            id: kbdArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "SWAYSOCK=$(ls -t /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -n1) swaymsg input type:keyboard xkb_switch_layout next && b1air-daemon layout"]);
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
                                font.pixelSize: 13
                                color: (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) ? topBar.colRed : topBar.colFgDim
                            }
                            Text {
                                text: (Audio.defaultSink && Audio.defaultSink.audio) ? Math.round(Audio.defaultSink.audio.volume * 100) + "%" : "65%"
                                font.family: topBar.fontMain
                                font.pixelSize: 11
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
                                    Quickshell.execDetached(["b1air-daemon", "volume", "up", "5"]);
                                } else if (wheel.angleDelta.y < 0) {
                                    Quickshell.execDetached(["b1air-daemon", "volume", "down", "5"]);
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
                                font.pixelSize: 13
                                color: Power.charging ? "#a6e3a1" : topBar.colFgDim
                            }
                            Text {
                                text: Power.capacity + "%"
                                font.family: topBar.fontMain
                                font.pixelSize: 11
                                font.bold: true
                                color: topBar.colFg
                            }
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
                            font.pixelSize: 13
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
                            font.pixelSize: 13
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
