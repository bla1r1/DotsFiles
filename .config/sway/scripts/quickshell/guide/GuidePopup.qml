import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Ui"

PopupShell {
    id: root


    // --- Helper Functions ---
    function formatBytes(bytes) {
        if (bytes === 0 || isNaN(bytes)) return '0 B';
        var k = 1024;
        var sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    function compareVersions(local, remote) {
        if (local === remote || local === "Unknown" || local === "Loading..." || !local || !remote) return false;

        function parseVersion(v) {
            let parts = v.split('-');
            let base = parts[0].split('.').map(Number);
            let rev = parts.length > 1 ? parseInt(parts[1]) : 0;
            return { base: base, rev: rev };
        }

        let l = parseVersion(local);
        let r = parseVersion(remote);

        for (let i = 0; i < Math.max(l.base.length, r.base.length); i++) {
            let lVal = l.base[i] || 0;
            let rVal = r.base[i] || 0;
            if (lVal < rVal) return true;
            if (lVal > rVal) return false;
        }

        return l.rev < r.rev;
    }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS & NAVIGATION
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: {
        closeSequence.start();
        event.accepted = true;
    }
    Keys.onTabPressed: {
        let next = (currentTab + 1) % tabNames.length;
        if (next === 1) next = 2; // Skip Settings Tab visually
        currentTab = next;
        event.accepted = true;
    }
    Keys.onBacktabPressed: {
        let prev = (currentTab - 1 + tabNames.length) % tabNames.length;
        if (prev === 1) prev = 0; // Skip Settings Tab visually
        currentTab = prev;
        event.accepted = true;
    }
    Keys.onLeftPressed: {
        if (currentTab === 3) { 
            if (selectedModuleIndex > 0) {
                selectedModuleIndex--;
                modulesList.positionViewAtIndex(selectedModuleIndex, ListView.Contain);
            }
            event.accepted = true;
        }
    }
    Keys.onRightPressed: {
        if (currentTab === 3) { 
            if (selectedModuleIndex < modulesDataModel.count - 1) {
                selectedModuleIndex++;
                modulesList.positionViewAtIndex(selectedModuleIndex, ListView.Contain);
            }
            event.accepted = true;
        }
    }
    Keys.onReturnPressed: {
        if (currentTab === 3) { 
            let target = modulesDataModel.get(selectedModuleIndex).target;
            root.toggleModule(target);
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: { Keys.onReturnPressed(event); }


    property real colorBlend: 0.0
    SequentialAnimation on colorBlend {
        loops: Animation.Infinite
        running: true
        NumberAnimation { to: 1.0; duration: root.driftPeriod; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: root.driftPeriod; easing.type: Easing.InOutSine }
    }
    
    property color ambientPurple: Qt.tint(Design.accentAlt, Qt.rgba(Design.accentAlt.r, Design.accentAlt.g, Design.accentAlt.b, colorBlend))
    property color ambientBlue: Qt.tint(Design.accent, Qt.rgba(Design.accentSoft.r, Design.accentSoft.g, Design.accentSoft.b, colorBlend))

    // -------------------------------------------------------------------------
    // GLOBALS
    // -------------------------------------------------------------------------
    property string dotsVersion: "Loading..."
    property string remoteVersion: ""
    property bool updateAvailable: false
    readonly property string scriptDir: Quickshell.env("QS_SCRIPT_DIR") || (Quickshell.env("HOME") + "/.config/sway/scripts")
    readonly property string mainQmlPath: scriptDir + "/quickshell/Main.qml"
    readonly property string updaterScriptPath: scriptDir + "/system/dotfiles-update.sh"

    function ipc(method) {
        Quickshell.execDetached(["qs", "-p", root.mainQmlPath, "ipc", "call", "main", method]);
    }

    function toggleModule(target) {
        const methods = {
            "battery": "toggleBattery",
            "network": "toggleNetwork",
            "monitors": "toggleMonitors",
            "guide": "toggleGuide",
            "updater": "toggleUpdater",
            "settings": "toggleSettings",
            "focustime": "toggleFocusTime",
            "calendar": "toggleCalendar",
            "music": "toggleMusic",
            "volume": "toggleVolume"
        };
        if (methods[target])
            root.ipc(methods[target]);
    }

    Process {
        id: versionReader
        command: ["bash", "-c", "repo=\"$HOME/GitHub/DotsFiles\"; if [ -d \"$repo/.git\" ]; then branch=$(git -C \"$repo\" rev-parse --abbrev-ref HEAD 2>/dev/null); hash=$(git -C \"$repo\" rev-parse --short HEAD 2>/dev/null); printf '%s@%s\\n' \"${branch:-local}\" \"${hash:-unknown}\"; git -C \"$repo\" fetch --quiet origin >/dev/null 2>&1 || true; remote=$(git -C \"$repo\" rev-parse --short origin/main 2>/dev/null || true); if [ -n \"$remote\" ] && [ \"$remote\" != \"$hash\" ]; then printf '%s@%s\\n' \"${branch:-local}\" \"$remote\"; fi; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim().split("\n") : [];
                root.dotsVersion = out.length > 0 && out[0] !== "" ? out[0] : "local";
                root.remoteVersion = out.length > 1 ? out[1] : "";
                root.updateAvailable = root.remoteVersion !== "";
            }
        }
    }

    // -------------------------------------------------------------------------
    // SYSTEM INFO PROPERTIES & FETCHER (CACHED)
    // -------------------------------------------------------------------------
    property string sysUser: "Loading..."
    property string sysHost: "Loading..."
    property string sysOS: "Loading..."
    property string sysKernel: "Loading..."
    property string sysCPU: "Loading..."
    property string sysGPU: "Loading..."
    property string faceIconPath: ""
    property string sysUptime: "Loading..."

    Process {
        id: sysInfoProc
        running: true
        command: [
            "bash", "-c",
            "CACHE=\"$HOME/.cache/qs_sysinfo.txt\"; " +
            "if [ ! -f \"$CACHE\" ]; then " +
            "  ICON=\"\"; if [ -f ~/.face.icon ]; then ICON=$(readlink -f ~/.face.icon); elif [ -f ~/.face ]; then ICON=$(readlink -f ~/.face); fi; " +
            "  echo \"$(whoami)|$(hostname)|$(uname -r)|$(cat /etc/os-release | grep '^PRETTY_NAME=' | cut -d'=' -f2 | tr -d '\\\"')|$(grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2 | xargs)|$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | tail -n1 | cut -d':' -f3 | xargs)|$ICON\" > \"$CACHE\"; " +
            "fi; " +
            "cat \"$CACHE\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let line = this.text ? this.text.trim() : "";
                let parts = line.split("|");
                if (parts.length >= 6) {
                    root.sysUser = parts[0];
                    root.sysHost = parts[1];
                    root.sysKernel = parts[2];
                    root.sysOS = parts[3];
                    root.sysCPU = parts[4];
                    root.sysGPU = parts[5] ? parts[5] : "Integrated Graphics";
                    if (parts.length >= 7 && parts[6].trim() !== "") root.faceIconPath = parts[6].trim();
                }
            }
        }
    }

    Process {
        id: envReader
        command: ["bash", "-c", "cat ~/.config/sway/scripts/quickshell/calendar/.env 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text ? this.text.trim().split('\n') : [];
                for (let line of lines) {
                    line = line.trim();
                    if (line.startsWith("OPENWEATHER_KEY=")) apiKeyInput.text = line.substring(16).trim();
                    else if (line.startsWith("OPENWEATHER_CITY_ID=")) cityIdInput.text = line.substring(20).trim();
                    else if (line.startsWith("OPENWEATHER_UNIT=")) weatherTab.selectedUnit = line.substring(17).trim();
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // LIVE RESOURCE TELEMETRY (OPTIMIZED POLLING)
    // -------------------------------------------------------------------------
    property int cpuUsage: 0
    property int memUsage: 0
    property int sysTemp: 0
    property real globalTotalDisk: 1
    property real globalUsedDisk: 0

    Timer {
        id: resTimer
        interval: 2000
        running: root.currentTab === 2
        repeat: true
        triggeredOnStart: true
        onTriggered: { 
            resProc.running = false; 
            resProc.running = true; 
        }
    }

    Process {
        id: resProc
        command: [
            "bash", "-c", 
            "c1=($(awk '/^cpu / {print $2+$3+$4+$6+$7+$8, $5}' /proc/stat)); sleep 0.2; " +
            "c2=($(awk '/^cpu / {print $2+$3+$4+$6+$7+$8, $5}' /proc/stat)); act=$((c2[0] - c1[0])); tot=$((act + c2[1] - c1[1])); " +
            "cpu=$((tot > 0 ? act * 100 / tot : 0)); mem=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print int((t-a)/t*100)}' /proc/meminfo); " +
            "temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n1 || echo 0); up=$(awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'); " +
            "echo \"$cpu|$mem|$((temp / 1000))|$up\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text ? this.text.trim().split("|") : [];
                if (parts.length >= 4) {
                    root.cpuUsage = parseInt(parts[0]) || 0;
                    root.memUsage = parseInt(parts[1]) || 0;
                    root.sysTemp = parseInt(parts[2]) || 0;
                    root.sysUptime = parts[3];
                }
            }
        }
    }

    Timer {
        id: diskTimer
        interval: 60000
        running: root.currentTab === 2
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -B1 -x tmpfs -x devtmpfs -x efivarfs -x squashfs | awk 'NR>1 && !seen[$1]++ {tot+=$2; use+=$3} END {print tot\"|\"use}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = this.text ? this.text.trim().split("|") : [];
                if(p.length >= 2) {
                    root.globalTotalDisk = parseFloat(p[0]) || 0;
                    root.globalUsedDisk = parseFloat(p[1]) || 0;
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // NETWORK SPEEDTEST PIPELINE
    // -------------------------------------------------------------------------
    property int netState: 0
    property real finalPing: 0
    property real finalDown: 0
    property real finalUp: 0
    property real displayPing: 0
    property real displayDown: 0
    property real displayUp: 0

    NumberAnimation { 
        id: pingAnim
        target: root
        property: "displayPing"
        from: 0
        to: root.finalPing
        duration: root.tintDuration
        easing.type: Easing.OutQuart 
    }
    
    NumberAnimation { 
        id: downAnim
        target: root
        property: "displayDown"
        from: 0
        to: root.finalDown
        duration: root.pulsePeriod
        easing.type: Easing.OutQuart 
    }
    
    NumberAnimation { 
        id: upAnim
        target: root
        property: "displayUp"
        from: 0
        to: root.finalUp
        duration: root.pulsePeriod
        easing.type: Easing.OutQuart 
    }

    Process {
        id: pingProc
        command: ["bash", "-c", "ping -c 1 1.1.1.1 | awk -F'/' 'END{printf \"%.0f\", $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.finalPing = parseFloat(this.text ? this.text.trim() : "0") || 0;
                pingAnim.restart(); 
                root.netState = 2; 
                downProc.running = false; 
                downProc.running = true;
            }
        }
    }
    
    Process {
        id: downProc
        command: ["bash", "-c", "curl -m 5 -s -w '%{speed_download}' -o /dev/null https://speed.cloudflare.com/__down?bytes=50000000 | awk '{printf \"%.1f\", ($1 * 8) / 1000000}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.finalDown = parseFloat(this.text ? this.text.trim() : "0") || 0;
                downAnim.restart(); 
                root.netState = 3; 
                upProc.running = false; 
                upProc.running = true;
            }
        }
    }
    
    Process {
        id: upProc
        command: ["bash", "-c", "dd if=/dev/zero bs=1M count=10 2>/dev/null | curl -m 5 -s -w '%{speed_upload}' --data-binary @- -o /dev/null https://speed.cloudflare.com/__up | awk '{printf \"%.1f\", ($1 * 8) / 1000000}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.finalUp = parseFloat(this.text ? this.text.trim() : "0") || 0;
                upAnim.restart(); 
                root.netState = 4;
            }
        }
    }

    // -------------------------------------------------------------------------
    // STATE MANAGEMENT & DATA
    // -------------------------------------------------------------------------
    property int currentTab: 0
    property int selectedModuleIndex: 0
    // Durations that are choreography, not styling: a staged entrance, ambient
    // drift and slow tint crossfades. Deliberately off the motion scale.
    readonly property int introDuration: 900
    readonly property int introSlow: 1200
    readonly property int tintDuration: 1000
    readonly property int pulsePeriod: 1500
    readonly property int driftPeriod: 20000

    property var tabNames: ["System", "Settings", "Resources", "Modules", "Keybinds", "Matugen", "Weather", "Greeter", "About"]
    property var tabIcons: ["", "", "󰣖", "󰣆", "󰌌", "󰏘", "󰖐", "󰍃", ""]

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0

    ListModel { id: dynamicKeybindsModel }
    ListModel {
        id: modulesDataModel
        ListElement { title: "Calendar & Weather"; target: "calendar"; icon: ""; desc: "Dual-sync calendar with live \nOpenWeatherMap integration."; preview: "previews/preview_calendar.png" }
        ListElement { title: "Media & Lyrics"; target: "music"; icon: "󰎆"; desc: "PlayerCtl integration, Cava \nvisualizer, and live lyrics."; preview: "previews/preview_music.png" }
        ListElement { title: "Battery & Power"; target: "battery"; icon: "󰁹"; desc: "Uptime tracking, power profiles, \nand battery health metrics."; preview: "previews/preview_battery.png" }
        ListElement { title: "Network Hub"; target: "network"; icon: "󰤨"; desc: "Wi-Fi and Bluetooth connection \nmanagement via nmcli/bluez."; preview: "previews/preview_network.png" }
        ListElement { title: "FocusTime"; target: "focustime"; icon: "󰄉"; desc: "Built-in Pomodoro timer daemon \nwith session tracking."; preview: "previews/preview_focustime.png" }
        ListElement { title: "Volume Mixer"; target: "volume"; icon: "󰕾"; desc: "Pipewire integration for I/O \nvolume and stream routing."; preview: "previews/preview_volume.png" }
        ListElement { title: "Monitors"; target: "monitors"; icon: "󰍹"; desc: "Quick display management."; preview: "previews/preview_monitors.png" }
    }

    function buildKeybinds() {
        dynamicKeybindsModel.clear();
        let binds = [
            { k1: "SUPER", k2: "T", action: "Open Terminal", cmd: "$terminal" },
            { k1: "SUPER", k2: "SPACE", action: "App Launcher", cmd: "bash ~/.config/sway/scripts/launchers/rofi_show.sh drun" },
            { k1: "ALT", k2: "TAB", action: "Focus Next Window", cmd: "swaymsg focus next" },
            { k1: "SUPER", k2: "F", action: "Open Firefox", cmd: "firefox" },
            { k1: "SUPER", k2: "E", action: "Open File Manager", cmd: "$fileManager" },
            { k1: "SUPER", k2: "G", action: "Open GitHub Desktop", cmd: "github-desktop" },
            { k1: "SUPER", k2: "V", action: "Open Virt Manager", cmd: "virt-manager" },
            { k1: "SUPER", k2: "S", action: "Open Steam", cmd: "steam" },
            { k1: "SUPER", k2: "D", action: "Open Discord", cmd: "discord" },
            { k1: "SUPER", k2: "Q", action: "Close Active Window", cmd: "swaymsg kill" },
            { k1: "CTRL+ALT", k2: "L", action: "Lock Screen", cmd: "bash ~/.config/sway/scripts/session/lock.sh" },
            { k1: "PRINT", k2: "", action: "Screenshot", cmd: "bash ~/.config/sway/scripts/tools/screenshot.sh" },
            { k1: "SHIFT", k2: "PRINT", action: "Screenshot (Edit)", cmd: "bash ~/.config/sway/scripts/tools/screenshot.sh --edit" },
            { k1: "SUPER", k2: "PRINT", action: "Screenshot (Full)", cmd: "bash ~/.config/sway/scripts/tools/screenshot.sh --full" },
            { k1: "SUPER+SHIFT", k2: "PRINT", action: "Screenshot (Full Edit)", cmd: "bash ~/.config/sway/scripts/tools/screenshot.sh --full --edit" },
            { k1: "SUPER", k2: "W", action: "Open Waypaper", cmd: "waypaper" },
            { k1: "SUPER", k2: "B", action: "Toggle Battery", cmd: "qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main toggleBattery" },
            { k1: "SUPER", k2: "N", action: "Toggle Network", cmd: "qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main toggleNetwork" },
            { k1: "SUPER", k2: "M", action: "Toggle Monitors", cmd: "qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main toggleMonitors" },
            { k1: "SUPER", k2: "H", action: "Toggle Guide", cmd: "qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main toggleGuide" },
            { k1: "SUPER+SHIFT", k2: "S", action: "Toggle Settings", cmd: "qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main toggleSettings" },
            { k1: "SUPER+SHIFT", k2: "T", action: "Toggle FocusTime", cmd: "qs -p ~/.config/sway/scripts/quickshell/Main.qml ipc call main toggleFocusTime" },
            { k1: "SUPER+SHIFT", k2: "G", action: "Toggle Game Mode", cmd: "bash ~/.config/sway/scripts/tools/game-mode.sh" },
            { k1: "SUPER+SHIFT", k2: "V", action: "Toggle Floating", cmd: "swaymsg floating toggle" },
            { k1: "SUPER+SHIFT", k2: "F", action: "Toggle Fullscreen", cmd: "swaymsg fullscreen toggle" },
            { k1: "SUPER+CTRL", k2: "F", action: "Toggle Global Fullscreen", cmd: "swaymsg fullscreen toggle global" },
            { k1: "Media", k2: "Play/Pause", action: "Play/Pause Media", cmd: "playerctl play-pause" },
            { k1: "Media", k2: "Vol Up/Down", action: "Adjust Volume", cmd: "bash ~/.config/sway/scripts/controls/audio-control.sh" },
            { k1: "Media", k2: "Mute", action: "Mute Volume", cmd: "bash ~/.config/sway/scripts/controls/audio-control.sh --toggle" },
            { k1: "Media", k2: "Mic Mute", action: "Mute Microphone", cmd: "bash ~/.config/sway/scripts/controls/mic-control.sh --toggle" },
            { k1: "Media", k2: "Brightness", action: "Adjust Brightness", cmd: "bash ~/.config/sway/scripts/controls/brightness-control.sh" },
            { k1: "Kbd", k2: "Brightness", action: "Adjust Keyboard Light", cmd: "bash ~/.config/sway/scripts/controls/kbd-backlight.sh" },
            { k1: "SUPER", k2: "ARROWS", action: "Move Focus", cmd: "swaymsg focus right" },
            { k1: "SUPER+CTRL", k2: "ARROWS", action: "Move Window", cmd: "swaymsg move right" },
            { k1: "SUPER+SHIFT", k2: "ARROWS", action: "Resize Window", cmd: "swaymsg resize grow width 50px" }
        ];
        for (let item of binds) { dynamicKeybindsModel.append(item); }
    }

    Component.onCompleted: { 
        startupSequence.start(); 
        buildKeybinds(); 
    }

    ParallelAnimation {
        id: startupSequence
        NumberAnimation { 
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: root.introDuration
            easing.type: Easing.OutExpo 
        }
        SequentialAnimation { 
            PauseAnimation { duration: Design.duration.fast }
            NumberAnimation { 
                target: root
                property: "introSidebar"
                from: 0.0
                to: 1.0
                duration: root.tintDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.05 
            } 
        }
        SequentialAnimation { 
            PauseAnimation { duration: Design.duration.base }
            NumberAnimation { 
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: root.introSlow
                easing.type: Easing.OutBack
                easing.overshoot: 1.02 
            } 
        }
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation { 
            NumberAnimation { 
                target: root
                property: "introContent"
                to: 0.0
                duration: Design.duration.fast
                easing.type: Easing.InExpo 
            }
            NumberAnimation { 
                target: root
                property: "introSidebar"
                to: 0.0
                duration: Design.duration.fast
                easing.type: Easing.InExpo 
            } 
        }
        NumberAnimation { 
            target: root
            property: "introBase"
            to: 0.0
            duration: Design.duration.base
            easing.type: Easing.InQuart 
        }
        ScriptAction { 
            script: root.ipc("close")
        }
    }

    // -------------------------------------------------------------------------
    // BACKGROUND AMBIENCE
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)
        
        Rectangle {
            anchors.fill: parent
            radius: Design.s(16)
            color: Design.surface
            border.color: Design.raised
            border.width: 1
            clip: true
            
            property real time: 0
            NumberAnimation on time { 
                from: 0
                to: Math.PI * 2
                duration: root.driftPeriod
                loops: Animation.Infinite
                running: true 
            }
            
            Rectangle {
                width: Design.s(600)
                height: Design.s(600)
                radius: Design.s(300)
                x: parent.width * 0.6 + Math.cos(parent.time) * Design.s(100)
                y: parent.height * 0.1 + Math.sin(parent.time * 1.5) * Design.s(100)
                color: root.ambientPurple
                opacity: 0.04
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
            }
            
            Rectangle {
                width: Design.s(700)
                height: Design.s(700)
                radius: Design.s(350)
                x: parent.width * 0.1 + Math.sin(parent.time * 0.8) * Design.s(150)
                y: parent.height * 0.4 + Math.cos(parent.time * 1.2) * Design.s(100)
                color: root.ambientBlue
                opacity: 0.03
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 90; blur: 1.0 }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MAIN LAYOUT
    // -------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        anchors.margins: Design.s(20)
        spacing: Design.s(20)

        // ==========================================
        // SIDEBAR
        // ==========================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Design.s(220)
            radius: Design.s(12)
            color: Qt.alpha(Design.raised, 0.4)
            border.color: Design.hover
            border.width: 1
            opacity: introSidebar
            transform: Translate { x: Design.s(-30) * (1.0 - introSidebar) }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Design.s(15)
                spacing: Design.s(10)
                
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(60)
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: Design.s(12)
                        
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: Design.s(36)
                            height: Design.s(36)
                            radius: Design.s(10)
                            color: root.ambientPurple
                            Icon {
                                role: "title"
                                anchors.centerIn: parent
                                text: "󰣇"
                                color: Design.surface
                            }
                        }
                        
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Design.s(2)
                            Label {
                                text: "Imperative"
                                font.weight: Design.weight.bold
                                Layout.alignment: Qt.AlignLeft
                            }
                            Label {
                                role: "caption"
                                text: "v" + (root.dotsVersion !== "Loading..." ? root.dotsVersion : "...")
                                dim: true
                                Layout.alignment: Qt.AlignLeft
                            }
                        }
                    }
                }

                Rectangle { 
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.alpha(Design.hover, 0.5)
                    Layout.bottomMargin: Design.s(10) 
                }

                Repeater {
                    model: root.tabNames.length
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(44)
                        radius: Design.s(8)
                        property bool isActive: root.currentTab === index
                        color: isActive ? Design.hover : (tabMa.containsMouse ? Qt.alpha(Design.hover, 0.5) : "transparent")
                        
                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(15)
                            spacing: Design.s(12)
                            
                            Item {
                                Layout.preferredWidth: Design.s(24)
                                Layout.alignment: Qt.AlignVCenter
                                Icon {
                                    anchors.centerIn: parent
                                    text: root.tabIcons[index]
                                    color: parent.parent.parent.isActive ? root.ambientPurple : Design.textDim
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                }
                            }
                            
                            Label {
                                text: root.tabNames[index]
                                font.weight: parent.parent.isActive ? Font.Bold : Font.Medium
                                color: parent.parent.isActive ? Design.text : Design.textDim
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                            }
                        }
                        
                        Rectangle { 
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Design.s(3)
                            height: parent.isActive ? Design.s(20) : 0
                            radius: Design.s(2)
                            color: root.ambientPurple
                            Behavior on height { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } } 
                        }
                        
                        Clickable {
                            id: tabMa
                            onClicked: {
                                if (index === 1) { // 1 = Settings Tab
                                    root.ipc("toggleSettings");
                                } else {
                                    root.currentTab = index;
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // --- UPDATE AVAILABLE BUTTON ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.updateAvailable ? Design.s(50) : 0
                    visible: root.updateAvailable
                    opacity: root.updateAvailable ? 1.0 : 0.0
                    radius: Design.s(8)
                    color: updateHover.containsMouse ? Qt.alpha(Design.ok, 0.15) : Qt.alpha(Design.ok, 0.05)
                    border.color: updateHover.containsMouse ? Design.ok : Qt.alpha(Design.ok, 0.4)
                    border.width: 1
                    scale: updateHover.pressed ? 0.96 : (updateHover.containsMouse ? 1.02 : 1.0)
                    clip: true
                    
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                    Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
                    Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Design.s(2)
                        
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Design.s(6)
                            Icon { role: "body"; text: "󰚰"; color: Design.ok }
                            Label { role: "caption"; text: "Update Available"; font.weight: Design.weight.semibold; color: Design.ok }
                        }
                        
                        Label {
                            role: "caption"
                            text: root.dotsVersion + "  " + root.remoteVersion
                            dim: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                    }

                    Clickable { id: updateHover; onClicked: root.ipc("toggleUpdater") }
                }

                // --- CLOSE BUTTON ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(44)
                    radius: Design.s(8)
                    color: closeHover.containsMouse ? Qt.alpha(Design.danger, 0.1) : "transparent"
                    border.color: closeHover.containsMouse ? Design.danger : Design.hover
                    border.width: 1
                    scale: closeHover.pressed ? 0.95 : (closeHover.containsMouse ? 1.02 : 1.0)
                    
                    Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                    Item {
                        anchors.centerIn: parent
                        width: arrowText.implicitWidth
                        height: arrowText.implicitHeight
                        Icon {
                            id: arrowText
                            text: ""
                            color: closeHover.containsMouse ? Design.danger : Design.textDim
                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                        }
                    }
                    Clickable { id: closeHover; onClicked: closeSequence.start() }
                }
            }
        }

        // ==========================================
        // CONTENT AREA
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: introContent
            scale: 0.95 + (0.05 * introContent)
            transform: Translate { y: Design.s(20) * (1.0 - introContent) }

            // ------------------------------------------
            // TAB 0: SYSTEM OVERVIEW
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 0
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                ListModel {
                    id: systemDataModel
                    ListElement { pkg: "Sway"; role: "Wayland Compositor"; icon: ""; clr: "blue"; link: "https://swaywm.org/" }
                    ListElement { pkg: "Quickshell"; role: "UI Framework"; icon: "󰣆"; clr: "mauve"; link: "https://git.outfoxxed.me/outfoxxed/quickshell" }
                    ListElement { pkg: "Matugen"; role: "Theme Engine"; icon: "󰏘"; clr: "peach"; link: "https://github.com/InioX/matugen" }
                    ListElement { pkg: "Rofi Wayland"; role: "App Launcher"; icon: ""; clr: "green"; link: "https://github.com/lbonn/rofi" }
                    ListElement { pkg: "Kitty"; role: "Terminal Emulator"; icon: "󰄛"; clr: "yellow"; link: "https://sw.kovidgoyal.net/kitty/" }
                    ListElement { pkg: "Quickshell Popups"; role: "Panel & Overlays"; icon: "󰂚"; clr: "pink"; link: "https://quickshell.org/" }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Design.s(15) // Fixed offset matching the sidebar
                    anchors.leftMargin: Design.s(20)
                    anchors.rightMargin: Design.s(20)
                    anchors.bottomMargin: Design.s(20)
                    spacing: Design.s(20)

                    // ENHANCED DEVICE INFO BLOCK
                    Rectangle {
                        id: sysBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(180)
                        radius: Design.s(16)
                        color: sysBoxMa.containsMouse ? Qt.alpha(Design.raised, 0.7) : Qt.alpha(Design.raised, 0.4)
                        border.color: sysBoxMa.containsMouse ? root.ambientBlue : Design.hover
                        border.width: 1
                        clip: true
                        
                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                        Behavior on border.color { ColorAnimation { duration: Design.duration.base } }

                        Rectangle {
                            width: Design.s(250)
                            height: Design.s(250)
                            radius: Design.s(125)
                            color: root.ambientBlue
                            opacity: 0.15
                            x: sysBoxMa.containsMouse ? parent.width * 0.7 : parent.width * 0.8
                            y: -Design.s(50)
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
                            Behavior on x { NumberAnimation { duration: root.introDuration; easing.type: Easing.OutExpo } }
                        }
                        
                        Rectangle {
                            width: Design.s(200)
                            height: Design.s(200)
                            radius: Design.s(100)
                            color: root.ambientPurple
                            opacity: 0.15
                            x: sysBoxMa.containsMouse ? Design.s(50) : -Design.s(50)
                            y: Design.s(20)
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
                            Behavior on x { NumberAnimation { duration: root.introDuration; easing.type: Easing.OutExpo } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(20)
                            spacing: Design.s(30)

                            Item {
                                Layout.preferredWidth: Design.s(100)
                                Layout.preferredHeight: Design.s(100)
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Design.s(100)
                                    height: Design.s(100)
                                    radius: Design.s(50)
                                    color: "transparent"
                                    border.color: Qt.alpha(root.ambientPurple, sysBoxMa.containsMouse ? 0.8 : 0.3)
                                    border.width: Design.s(3)
                                    scale: sysBoxMa.containsMouse ? 1.05 : 1.0
                                    
                                    Behavior on scale { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutBack } }
                                    Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                    
                                    RotationAnimation on rotation { 
                                        from: 0
                                        to: 360
                                        duration: root.driftPeriod
                                        loops: Animation.Infinite
                                        running: true 
                                    }
                                }
                                
                                Item {
                                    anchors.centerIn: parent
                                    width: Design.s(84)
                                    height: Design.s(84)
                                    
                                    Rectangle { 
                                        id: avatarMaskTab0
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "black"
                                        visible: false
                                        layer.enabled: true 
                                    }
                                    
                                    Image {
                                        id: userAvatarImg
                                        anchors.fill: parent
                                        source: root.faceIconPath !== "" ? "file://" + root.faceIconPath.replace("file://", "") : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: false
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }
                                    
                                    MultiEffect { 
                                        source: userAvatarImg
                                        anchors.fill: userAvatarImg
                                        maskEnabled: true
                                        maskSource: avatarMaskTab0
                                        visible: root.faceIconPath !== "" 
                                    }
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: root.faceIconPath === "" ? Design.raised : "transparent"
                                        border.color: Design.active
                                        border.width: 1
                                        Text { 
                                            anchors.centerIn: parent
                                            text: ""
                                            font.family: Design.font.icon
                                            font.pixelSize: Design.s(42)
                                            color: Design.text
                                            visible: root.faceIconPath === ""
                                            scale: sysBoxMa.containsMouse ? 1.1 : 1.0
                                            Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Design.s(8)
                                
                                Label {
                                    role: "title"
                                    text: root.sysUser
                                    font.weight: Design.weight.bold
                                }
                                
                                Label { text: "@" + root.sysHost; dim: true }
                                
                                Rectangle { 
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.alpha(Design.hover, 0.5)
                                    Layout.topMargin: Design.s(5)
                                    Layout.bottomMargin: Design.s(5) 
                                }

                                RowLayout {
                                    spacing: Design.s(15)
                                    RowLayout { 
                                        spacing: Design.s(6)
                                        Icon { text: ""; color: Design.accent } 
                                        Label { role: "caption"; text: root.sysOS; font.weight: Font.Medium; dim: true } 
                                    }
                                    RowLayout { 
                                        spacing: Design.s(6)
                                        Icon { text: ""; color: Design.warn } 
                                        Label { role: "caption"; text: root.sysKernel; font.weight: Font.Medium; dim: true } 
                                    }
                                }
                                
                                RowLayout {
                                    spacing: Design.s(15)
                                    RowLayout { 
                                        spacing: Design.s(6)
                                        Icon { text: ""; color: Design.ok } 
                                        Label {
                                            role: "caption"
                                            text: root.sysCPU
                                            font.weight: Font.Medium
                                            dim: true
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: Design.s(220)
                                        } 
                                    }
                                    RowLayout { 
                                        spacing: Design.s(6)
                                        Icon { text: "󰢮"; color: Design.warn } 
                                        Label {
                                            role: "caption"
                                            text: root.sysGPU
                                            font.weight: Font.Medium
                                            dim: true
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: Design.s(220)
                                        } 
                                    }
                                }
                            }
                        }
                        Clickable { id: sysBoxMa }
                    }

                    // AUTHOR BLOCK
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(50)
                        radius: Design.s(10)
                        color: authorMa.containsMouse ? Qt.alpha(Design.hover, 0.6) : Qt.alpha(Design.raised, 0.4)
                        border.color: authorMa.containsMouse ? Design.accentAlt : Design.hover
                        border.width: 1
                        scale: authorMa.pressed ? 0.98 : (authorMa.containsMouse ? 1.01 : 1.0)
                        
                        Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                        Behavior on border.color { ColorAnimation { duration: Design.duration.base } }

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Design.s(12)
                            spacing: Design.s(15)
                            
                            Rectangle { 
                                Layout.alignment: Qt.AlignVCenter
                                width: Design.s(32)
                                height: Design.s(32)
                                radius: Design.s(8)
                                color: Design.raised
                                border.color: Design.active
                                border.width: 1
                                Icon { role: "title"; anchors.centerIn: parent; text: "" } 
                            }
                            
                            Row {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Design.s(1)
                                Repeater {
                                    model: [ { l: "b", c: Design.danger }, { l: "l", c: Design.warn }, { l: "a", c: Design.warn }, { l: "1", c: Design.ok }, { l: "r", c: Design.accentSoft }, { l: "1", c: Design.accent } ]
                                    Text { 
                                        text: modelData.l
                                        font.family: Design.font.mono
                                        font.weight: Design.weight.bold
                                        font.pixelSize: Design.s(14)
                                        color: modelData.c
                                        property real hoverOffset: authorMa.containsMouse ? Design.s(-3) : 0
                                        transform: Translate { y: hoverOffset }
                                        Behavior on hoverOffset { NumberAnimation { duration: Design.duration.base + (index * 35); easing.type: Easing.OutBack } } 
                                    }
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Rectangle { 
                                Layout.alignment: Qt.AlignVCenter
                                width: Design.s(28)
                                height: Design.s(28)
                                radius: Design.s(6)
                                color: authorMa.containsMouse ? Design.hover : "transparent"
                                Icon {
                                    role: "body"
                                    anchors.centerIn: parent
                                    text: ""
                                    color: authorMa.containsMouse ? Design.accentAlt : Design.textDim
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                } 
                            }
                        }
                        Clickable {
                            id: authorMa
                            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/bla1r1"])
                        }
                    }

                    // MODULES AND QUICK LINKS ROW
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.s(15)
                        
                        Repeater {
                            model: [ 
                                { name: "Settings", icon: "", color: "mauve", targetTab: 1, isToggle: true }, 
                                { name: "Resources", icon: "󰣖", color: "green", targetTab: 2, isToggle: false }, 
                                { name: "Modules", icon: "󰣆", color: "blue", targetTab: 3, isToggle: false } 
                            ]
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Design.s(44)
                                radius: Design.s(8)
                                color: navBtnMa.containsMouse ? Qt.alpha(root[modelData.color], 0.15) : Qt.alpha(Design.raised, 0.4)
                                border.color: navBtnMa.containsMouse ? root[modelData.color] : Design.hover
                                border.width: 1
                                scale: navBtnMa.pressed ? 0.95 : 1.0
                                
                                Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutQuart } }
                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                
                                RowLayout { 
                                    anchors.centerIn: parent
                                    spacing: Design.s(10)
                                    Icon { text: modelData.icon; color: root[modelData.color] } 
                                    Label { text: modelData.name; font.weight: Design.weight.semibold } 
                                }
                                
                                Clickable {
                                    id: navBtnMa
                                    onClicked: {
                                        if (modelData.isToggle) {
                                            root.ipc("toggleSettings");
                                        } else {
                                            root.currentTab = modelData.targetTab;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        role: "title"
                        text: "System Architecture"
                        font.weight: Design.weight.bold
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: Design.s(5)
                    }
                    
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Design.s(15)
                        columnSpacing: Design.s(15)
                        
                        Repeater {
                            model: systemDataModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Design.s(60)
                                radius: Design.s(10)
                                color: sysCardMa.containsMouse ? Qt.alpha(root[model.clr], 0.1) : Qt.alpha(Design.raised, 0.4)
                                border.color: sysCardMa.containsMouse ? root[model.clr] : Design.hover
                                border.width: 1
                                scale: sysCardMa.pressed ? 0.98 : 1.0
                                
                                Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutQuart } }
                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                
                                Item {
                                    anchors.fill: parent
                                    anchors.margins: Design.s(10)
                                    
                                    Item { 
                                        id: sysIconBox
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Design.s(36)
                                        height: Design.s(36)
                                        Icon { role: "title"; anchors.centerIn: parent; text: model.icon; color: root[model.clr] } 
                                    }
                                    
                                    Column { 
                                        anchors.left: sysIconBox.right
                                        anchors.leftMargin: Design.s(15)
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Design.s(2)
                                        Label { text: model.pkg; font.weight: Design.weight.semibold } 
                                        Label { role: "caption"; text: model.role; dim: true } 
                                    }
                                }
                                
                                Clickable {
                                    id: sysCardMa
                                    onClicked: Quickshell.execDetached(["xdg-open", model.link])
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // ------------------------------------------
            // TAB 2: RESOURCES 
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 2
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                ScrollView {
                    anchors.fill: parent
                    anchors.topMargin: Design.s(15) // Applied safely to ScrollView, preventing crash!
                    anchors.leftMargin: Design.s(20)
                    anchors.rightMargin: Design.s(20)
                    anchors.bottomMargin: Design.s(20)
                    contentWidth: availableWidth
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: Design.s(15)

                        // --- Integrated System Info Grid ---
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: sysInfoCol.implicitHeight + Design.s(40)
                            radius: Design.s(16)
                            color: Qt.alpha(Design.raised, 0.4)
                            border.color: Design.hover
                            border.width: 1

                            ColumnLayout {
                                id: sysInfoCol
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Design.s(20)
                                spacing: Design.s(15)

                                RowLayout {
                                    Icon { text: "󰇄"; color: Design.accentAlt }
                                    Label { text: "System Specifications"; font.weight: Design.weight.semibold }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Design.hover, 0.5) }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: Design.s(15)
                                    columnSpacing: Design.s(30)
                                    
                                    RowLayout { 
                                        spacing: Design.s(12)
                                        Rectangle { width: Design.s(36); height: Design.s(36); radius: Design.s(8); color: Qt.alpha(Design.accent, 0.15); Icon { anchors.centerIn: parent; text: ""; color: Design.accent } } 
                                        ColumnLayout { spacing: Design.s(2); Label { role: "caption"; text: "Operating System"; dim: true } Label { text: root.sysOS; font.weight: Design.weight.semibold } } 
                                    }
                                    RowLayout { 
                                        spacing: Design.s(12)
                                        Rectangle { width: Design.s(36); height: Design.s(36); radius: Design.s(8); color: Qt.alpha(Design.warn, 0.15); Icon { anchors.centerIn: parent; text: ""; color: Design.warn } } 
                                        ColumnLayout { spacing: Design.s(2); Label { role: "caption"; text: "Kernel Version"; dim: true } Label { text: root.sysKernel; font.weight: Design.weight.semibold } } 
                                    }
                                    RowLayout { 
                                        spacing: Design.s(12)
                                        Rectangle { width: Design.s(36); height: Design.s(36); radius: Design.s(8); color: Qt.alpha(Design.ok, 0.15); Icon { anchors.centerIn: parent; text: ""; color: Design.ok } } 
                                        ColumnLayout { spacing: Design.s(2); Label { role: "caption"; text: "Active User"; dim: true } Label { text: root.sysUser + "@" + root.sysHost; font.weight: Design.weight.semibold } } 
                                    }
                                    RowLayout { 
                                        spacing: Design.s(12)
                                        Rectangle { width: Design.s(36); height: Design.s(36); radius: Design.s(8); color: Qt.alpha(Design.warn, 0.15); Icon { anchors.centerIn: parent; text: "󰔟"; color: Design.warn } } 
                                        ColumnLayout { spacing: Design.s(2); Label { role: "caption"; text: "System Uptime"; dim: true } Label { text: root.sysUptime; font.weight: Design.weight.semibold } } 
                                    }
                                    RowLayout { 
                                        Layout.columnSpan: 2
                                        spacing: Design.s(12)
                                        Rectangle { width: Design.s(36); height: Design.s(36); radius: Design.s(8); color: Qt.alpha(Design.accentSoft, 0.15); Icon { anchors.centerIn: parent; text: ""; color: Design.accentSoft } } 
                                        ColumnLayout { spacing: Design.s(2); Label { role: "caption"; text: "Processor (CPU)"; dim: true } Label { text: root.sysCPU; font.weight: Design.weight.semibold; elide: Text.ElideRight; Layout.maximumWidth: Design.s(450) } } 
                                    }
                                    RowLayout { 
                                        Layout.columnSpan: 2
                                        spacing: Design.s(12)
                                        Rectangle { width: Design.s(36); height: Design.s(36); radius: Design.s(8); color: Qt.alpha(Design.danger, 0.15); Icon { anchors.centerIn: parent; text: "󰢮"; color: Design.danger } } 
                                        ColumnLayout { spacing: Design.s(2); Label { role: "caption"; text: "Graphics (GPU)"; dim: true } Label { text: root.sysGPU; font.weight: Design.weight.semibold; elide: Text.ElideRight; Layout.maximumWidth: Design.s(450) } } 
                                    }
                                }
                            }
                        }

                        // --- Circular Gauges ---
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: Design.s(15)
                            
                            Repeater {
                                model: 3
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Design.s(200)
                                    radius: Design.s(16)
                                    property real targetValue: index === 0 ? root.cpuUsage : (index === 1 ? root.memUsage : Math.min(root.sysTemp, 100))
                                    property string txtValue: index === 0 ? root.cpuUsage + "%" : (index === 1 ? root.memUsage + "%" : (root.sysTemp > 0 ? root.sysTemp + "°C" : "N/A"))
                                    property string cKey: index === 0 ? "sapphire" : (index === 1 ? "peach" : "red")
                                    property string tTitle: index === 0 ? "CPU LOAD" : (index === 1 ? "MEMORY" : "THERMALS")
                                    property string iIcon: index === 0 ? "" : (index === 1 ? "󰍛" : "")

                                    color: Qt.alpha(Design.raised, 0.4)
                                    border.color: Qt.alpha(root[cKey], 0.2)
                                    border.width: 1
                                    clip: true

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: Design.s(15)
                                        
                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: Design.s(130)
                                            Layout.preferredHeight: Design.s(130)
                                            
                                            Canvas {
                                                id: gaugeCanvas
                                                anchors.fill: parent
                                                property real animatedValue: targetValue
                                                Behavior on animatedValue { NumberAnimation { duration: root.introDuration; easing.type: Easing.OutCubic } }
                                                onAnimatedValueChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d"); 
                                                    ctx.clearRect(0, 0, width, height);
                                                    var cx = width / 2; 
                                                    var cy = height / 2; 
                                                    var r = width / 2 - Design.s(8);
                                                    
                                                    ctx.beginPath(); 
                                                    ctx.arc(cx, cy, r, 0, 2 * Math.PI); 
                                                    ctx.lineWidth = Design.s(12); 
                                                    ctx.strokeStyle = Qt.alpha(Design.hover, 0.4); 
                                                    ctx.stroke();
                                                    
                                                    var start = -Math.PI / 2; 
                                                    var end = start + (animatedValue / 100) * 2 * Math.PI;
                                                    
                                                    ctx.beginPath(); 
                                                    ctx.arc(cx, cy, r, start, end); 
                                                    ctx.lineWidth = Design.s(12); 
                                                    ctx.strokeStyle = root[cKey]; 
                                                    ctx.lineCap = "round"; 
                                                    ctx.stroke();
                                                }
                                            }
                                            
                                            ColumnLayout { 
                                                anchors.centerIn: parent
                                                spacing: Design.s(2)
                                                Text { text: iIcon; font.family: Design.font.icon; font.pixelSize: Design.s(26); color: root[cKey]; Layout.alignment: Qt.AlignHCenter } 
                                                Label { role: "subhead"; text: txtValue; font.weight: Design.weight.bold; Layout.alignment: Qt.AlignHCenter } 
                                            }
                                        }
                                        
                                        Label {
                                            role: "caption"
                                            text: tTitle
                                            font.weight: Design.weight.semibold
                                            dim: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }

                        // --- Consolidated Storage Block ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(80)
                            radius: Design.s(16)
                            color: Qt.alpha(Design.raised, 0.4)
                            border.color: Design.hover
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Design.s(20)
                                spacing: Design.s(10)
                                
                                RowLayout {
                                    Icon { text: "󰋊"; color: Design.accentAlt }
                                    Label { text: "Storage"; font.weight: Design.weight.semibold }
                                    Item { Layout.fillWidth: true }
                                    Label {
                                        role: "caption"
                                        text: root.formatBytes(root.globalUsedDisk) + " / " + root.formatBytes(root.globalTotalDisk) + " (" + (root.globalTotalDisk > 0 ? Math.round((root.globalUsedDisk / root.globalTotalDisk) * 100) : 0) + "%)"
                                        dim: true
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Design.s(8)
                                    radius: Design.s(4)
                                    color: Qt.alpha(Design.hover, 0.4)
                                    clip: true
                                    
                                    Rectangle { 
                                        height: parent.height
                                        radius: Design.s(4)
                                        width: root.globalTotalDisk > 0 ? parent.width * (root.globalUsedDisk / root.globalTotalDisk) : 0
                                        color: Design.accentAlt
                                        Behavior on width { NumberAnimation { duration: root.tintDuration; easing.type: Easing.OutQuart } } 
                                    }
                                }
                            }
                        }

                        // --- OOKLA Inspired Network Dashboard ---
                        Rectangle {
                            id: netContainer
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(160)
                            radius: Design.s(16)
                            color: Qt.alpha(Design.raised, 0.4)
                            border.color: Design.hover
                            border.width: 1
                            clip: true

                            Rectangle {
                                id: goBtn
                                width: Design.s(90)
                                height: Design.s(90)
                                radius: Design.s(45)
                                x: root.netState === 0 ? (parent.width - width) / 2 : Design.s(30)
                                y: (parent.height - height) / 2
                                color: Qt.alpha(Design.accent, 0.15)
                                border.color: (root.netState > 0 && root.netState < 4) ? Design.accent : Design.active
                                border.width: Design.s(2)
                                Behavior on x { NumberAnimation { duration: root.introDuration; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: Design.accentSoft
                                    border.width: Design.s(2)
                                    opacity: 0
                                    SequentialAnimation on opacity { 
                                        running: root.netState > 0 && root.netState < 4
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1; to: 0; duration: root.tintDuration } 
                                    }
                                    SequentialAnimation on scale { 
                                        running: root.netState > 0 && root.netState < 4
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 1.5; duration: root.tintDuration } 
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Design.s(2)
                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: Design.s(32)
                                        height: Design.s(32)
                                        Text { 
                                            anchors.centerIn: parent
                                            text: root.netState === 0 ? "GO" : (root.netState === 4 ? "󰑐" : "󰑮")
                                            font.family: root.netState === 0 ? "JetBrains Mono" : "Iosevka Nerd Font"
                                            font.weight: Design.weight.bold
                                            font.pixelSize: root.netState === 0 ? Design.s(28) : Design.s(32)
                                            color: (root.netState > 0 && root.netState < 4) ? Design.accent : Design.text
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            transformOrigin: Item.Center
                                            RotationAnimation on rotation { 
                                                running: root.netState > 0 && root.netState < 4
                                                loops: Animation.Infinite
                                                from: 0
                                                to: 360
                                                duration: root.tintDuration 
                                            } 
                                        }
                                    }
                                    Label {
                                        role: "caption"
                                        text: "SPEEDTEST"
                                        font.weight: Design.weight.semibold
                                        dim: true
                                        visible: root.netState === 0
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                            MouseArea { 
                                anchors.fill: parent
                                hoverEnabled: root.netState === 0 || root.netState === 4
                                cursorShape: (root.netState === 0 || root.netState === 4) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: { 
                                    if (root.netState === 0 || root.netState === 4) { 
                                        root.netState = 1; 
                                        root.displayPing = 0; 
                                        root.finalPing = 0; 
                                        root.displayDown = 0; 
                                        root.finalDown = 0; 
                                        root.displayUp = 0; 
                                        root.finalUp = 0; 
                                        pingProc.running = false; 
                                        pingProc.running = true; 
                                    } 
                                } 
                            }
                        }

                        RowLayout {
                            id: netResults
                            x: root.netState === 0 ? parent.width : Design.s(150)
                            y: (parent.height - height) / 2
                            opacity: root.netState === 0 ? 0 : 1
                            spacing: Design.s(40)
                            Behavior on x { NumberAnimation { duration: root.introDuration; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                            Behavior on opacity { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.InOutQuad } }

                            ColumnLayout {
                                spacing: Design.s(4)
                                opacity: root.netState >= 1 ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Design.duration.slow } }
                                RowLayout { 
                                    spacing: Design.s(6)
                                    Item { 
                                        Layout.preferredWidth: Design.s(16)
                                        Layout.preferredHeight: Design.s(16)
                                        Icon { anchors.centerIn: parent; text: "󰅸"; color: Design.warn } 
                                    } 
                                    Label { role: "caption"; text: "PING"; font.weight: Design.weight.semibold; dim: true } 
                                }
                                RowLayout { 
                                    spacing: Design.s(4)
                                    Label { role: "display"; text: root.netState >= 2 ? root.displayPing.toFixed(0) : "..."; font.weight: Design.weight.bold } 
                                    Label { role: "caption"; text: "ms"; dim: true; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: Design.s(5); visible: root.netState >= 2 } 
                                }
                            }
                            
                            ColumnLayout {
                                spacing: Design.s(4)
                                opacity: root.netState >= 2 ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Design.duration.slow } }
                                RowLayout { 
                                    spacing: Design.s(6)
                                    Item { 
                                        Layout.preferredWidth: Design.s(16)
                                        Layout.preferredHeight: Design.s(16)
                                        Icon { anchors.centerIn: parent; text: "󰇚"; color: Design.ok } 
                                    } 
                                    Label { role: "caption"; text: "DOWNLOAD"; font.weight: Design.weight.semibold; dim: true } 
                                }
                                RowLayout { 
                                    spacing: Design.s(4)
                                    Label { role: "display"; text: root.netState >= 3 ? root.displayDown.toFixed(1) : "..."; font.weight: Design.weight.bold; color: Design.ok } 
                                    Label { role: "caption"; text: "Mbps"; dim: true; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: Design.s(5); visible: root.netState >= 3 } 
                                }
                            }
                            
                            ColumnLayout {
                                spacing: Design.s(4)
                                opacity: root.netState >= 3 ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Design.duration.slow } }
                                RowLayout { 
                                    spacing: Design.s(6)
                                    Item { 
                                        Layout.preferredWidth: Design.s(16)
                                        Layout.preferredHeight: Design.s(16)
                                        Icon { anchors.centerIn: parent; text: "󰕒"; color: Design.accentAlt } 
                                    } 
                                    Label { role: "caption"; text: "UPLOAD"; font.weight: Design.weight.semibold; dim: true } 
                                }
                                RowLayout { 
                                    spacing: Design.s(4)
                                    Label { role: "display"; text: root.netState >= 4 ? root.displayUp.toFixed(1) : "..."; font.weight: Design.weight.bold; color: Design.accentAlt } 
                                    Label { role: "caption"; text: "Mbps"; dim: true; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: Design.s(5); visible: root.netState >= 4 } 
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 3: MODULES
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 3
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Design.s(15)
                    anchors.leftMargin: Design.s(20)
                    anchors.rightMargin: Design.s(20)
                    anchors.bottomMargin: Design.s(20)
                    spacing: Design.s(20)

                    RowLayout {
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Design.s(4)
                            Label { role: "display"; text: "Interactive Modules"; font.weight: Design.weight.bold }
                            Label { text: "Use arrow keys or select below to preview. Double-click or press Enter to toggle."; dim: true }
                        }
                        
                        Item { Layout.fillWidth: true } 
                        
                        Rectangle {
                            Layout.preferredWidth: Design.s(110)
                            Layout.preferredHeight: Design.s(44)
                            radius: Design.s(22)
                            color: launchMa.containsMouse ? Qt.alpha(root.ambientBlue, 0.9) : Qt.alpha(root.ambientBlue, 0.7)
                            border.color: root.ambientBlue
                            border.width: 1
                            scale: launchMa.pressed ? 0.95 : (launchMa.containsMouse ? 1.05 : 1.0)
                            
                            Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                            
                            RowLayout { 
                                anchors.centerIn: parent
                                spacing: Design.s(8)
                                Icon { role: "title"; text: "󰐊"; color: Design.surface } 
                                Label { text: "PLAY"; font.weight: Design.weight.bold; color: Design.surface } 
                            }
                            
                            Clickable {
                                id: launchMa
                                onClicked: root.toggleModule(modulesDataModel.get(root.selectedModuleIndex).target)
                            }
                        }
                    }

                    Rectangle {
                        id: previewContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Design.s(12)
                        color: Design.raised
                        border.color: Design.active
                        border.width: 1
                        clip: true
                        
                        property string targetSource: modulesDataModel.get(root.selectedModuleIndex).preview ? Qt.resolvedUrl(modulesDataModel.get(root.selectedModuleIndex).preview) : ""
                        
                        onTargetSourceChanged: { 
                            baseImage.source = overlayImage.source; 
                            overlayImage.opacity = 0.0; 
                            overlayImage.source = targetSource; 
                            fadeAnim.restart(); 
                        }
                        
                        Image { 
                            id: baseImage
                            anchors.fill: parent
                            anchors.margins: 0
                            fillMode: Image.PreserveAspectCrop
                            verticalAlignment: Image.AlignTop
                            horizontalAlignment: Image.AlignHCenter
                            smooth: true
                            mipmap: true
                            asynchronous: true 
                        }
                        
                        Image { 
                            id: overlayImage
                            anchors.fill: parent
                            anchors.margins: 0
                            fillMode: Image.PreserveAspectCrop
                            verticalAlignment: Image.AlignTop
                            horizontalAlignment: Image.AlignHCenter
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            NumberAnimation on opacity { 
                                id: fadeAnim
                                to: 1.0
                                duration: Design.duration.base
                                easing.type: Easing.InOutQuad 
                            } 
                        }
                    }

                    ListView {
                        id: modulesList
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(90)
                        orientation: ListView.Horizontal
                        spacing: Design.s(15)
                        clip: true
                        model: modulesDataModel
                        currentIndex: root.selectedModuleIndex
                        highlightMoveDuration: 250
                        
                        delegate: Rectangle {
                            width: Design.s(220)
                            height: Design.s(90)
                            radius: Design.s(12)
                            property bool isSelected: index === root.selectedModuleIndex
                            color: isSelected ? Design.hover : (modMa.containsMouse ? Qt.alpha(Design.hover, 0.5) : Qt.alpha(Design.raised, 0.4))
                            border.color: isSelected ? root.ambientBlue : (modMa.containsMouse ? Design.active : Design.hover)
                            border.width: isSelected ? 2 : 1
                            scale: isSelected ? 1.0 : (modMa.pressed ? 0.96 : (modMa.containsMouse ? 1.02 : 1.0))
                            
                            Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                            Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Design.s(12)
                                spacing: Design.s(5)
                                RowLayout { 
                                    spacing: Design.s(10)
                                    Rectangle { 
                                        Layout.alignment: Qt.AlignVCenter
                                        width: Design.s(28)
                                        height: Design.s(28)
                                        radius: Design.s(6)
                                        color: Qt.alpha(Design.surface, 0.5)
                                        Icon { role: "body"; anchors.centerIn: parent; text: model.icon; color: isSelected ? root.ambientBlue : Design.text } 
                                    } 
                                    Label {
                                        role: "caption"
                                        text: model.title
                                        font.weight: Design.weight.semibold
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        elide: Text.ElideRight
                                    } 
                                }
                                Label {
                                    role: "caption"
                                    text: model.desc
                                    dim: true
                                    Layout.alignment: Qt.AlignLeft
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }
                            }
                            
                            Clickable {
                                id: modMa
                                onClicked: { 
                                    root.selectedModuleIndex = index; 
                                    modulesList.positionViewAtIndex(index, ListView.Contain); 
                                }
                                onDoubleClicked: { 
                                    root.selectedModuleIndex = index; 
                                    root.toggleModule(model.target)
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 4: KEYBINDS
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 4
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Design.s(15)
                    anchors.leftMargin: Design.s(20)
                    anchors.rightMargin: Design.s(20)
                    anchors.bottomMargin: Design.s(20)
                    spacing: Design.s(20)

                    Label { role: "display"; text: "Navigation & Control"; font.weight: Design.weight.bold; Layout.alignment: Qt.AlignVCenter }
                    Label { text: "Click any row below to instantly execute the keybind command."; dim: true; Layout.alignment: Qt.AlignVCenter }
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        GridLayout {
                            width: parent.width
                            columns: 2
                            rowSpacing: Design.s(10)
                            columnSpacing: Design.s(15)
                            
                            Rectangle {
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                Layout.preferredHeight: Design.s(60)
                                radius: Design.s(8)
                                color: Qt.alpha(Design.raised, 0.4)
                                border.color: Design.hover
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Design.s(10)
                                    spacing: Design.s(10)
                                    
                                    Label { text: "Workspaces (SUPER + 1-9)"; font.weight: Design.weight.semibold; Layout.alignment: Qt.AlignVCenter }
                                    Item { Layout.fillWidth: true }
                                    
                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            property int wsNum: index + 1
                                            Layout.preferredWidth: Design.s(32)
                                            Layout.preferredHeight: Design.s(32)
                                            radius: Design.s(6)
                                            color: wsMa.containsMouse ? Design.hover : Design.raised
                                            border.color: wsMa.containsMouse ? Design.warn : "transparent"
                                            border.width: 1
                                            Label { role: "caption"; anchors.centerIn: parent; text: parent.wsNum; font.weight: Design.weight.semibold; color: Design.warn }
                                            Clickable { id: wsMa; onClicked: Quickshell.execDetached(["swaymsg", "workspace", "number", wsNum.toString()]) }
                                        }
                                    }
                                }
                            }
                            
                            Repeater {
                                model: dynamicKeybindsModel
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Design.s(46)
                                    radius: Design.s(8)
                                    color: bindMa.containsMouse ? Design.hover : Qt.alpha(Design.raised, 0.4)
                                    border.color: bindMa.containsMouse ? Design.warn : "transparent"
                                    border.width: 1
                                    scale: bindMa.pressed ? 0.98 : 1.0
                                    
                                    Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutQuart } }
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Design.s(10)
                                        spacing: Design.s(15)
                                        
                                        Item {
                                            Layout.preferredWidth: Design.s(220)
                                            Layout.minimumWidth: Design.s(220)
                                            Layout.maximumWidth: Design.s(220)
                                            Layout.fillHeight: true
                                            
                                            Row { 
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Design.s(8)
                                                
                                                Rectangle { 
                                                    width: k1Text.implicitWidth + Design.s(16)
                                                    height: Design.s(26)
                                                    radius: Design.s(4)
                                                    color: Design.raised
                                                    border.color: Design.active
                                                    border.width: 1
                                                    Label { role: "caption"; id: k1Text; anchors.centerIn: parent; text: model.k1; font.weight: Design.weight.semibold; color: Design.warn } 
                                                } 
                                                
                                                Label { role: "caption"; text: "+"; color: Design.textFaint; visible: model.k2 !== ""; anchors.verticalCenter: parent.verticalCenter } 
                                                
                                                Rectangle { 
                                                    width: k2Text.implicitWidth + Design.s(16)
                                                    height: Design.s(26)
                                                    radius: Design.s(4)
                                                    color: Design.raised
                                                    border.color: Design.active
                                                    border.width: 1
                                                    visible: model.k2 !== ""
                                                    Label { role: "caption"; id: k2Text; anchors.centerIn: parent; text: model.k2; font.weight: Design.weight.semibold; color: Design.warn } 
                                                } 
                                            }
                                        }
                                        
                                        Label {
                                            text: model.action
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                    }
                                    
                                    Clickable {
                                        id: bindMa
                                        onClicked: Quickshell.execDetached(["bash", "-c", model.cmd])
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 5: MATUGEN ENGINE
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 5
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Design.s(15)
                    anchors.leftMargin: Design.s(20)
                    anchors.rightMargin: Design.s(20)
                    anchors.bottomMargin: Design.s(20)
                    spacing: Design.s(20)

                    Label { role: "display"; text: "Theming Engine"; font.weight: Design.weight.bold; Layout.alignment: Qt.AlignVCenter }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(160)
                        radius: Design.s(12)
                        color: Qt.alpha(Design.raised, 0.4)
                        border.color: root.ambientPurple
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(20)
                            spacing: Design.s(20)
                            
                            Item { Layout.fillWidth: true } 
                            
                            ColumnLayout { 
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Design.s(8)
                                Rectangle { 
                                    Layout.alignment: Qt.AlignHCenter
                                    width: Design.s(60)
                                    height: Design.s(60)
                                    radius: Design.s(10)
                                    color: Design.hover
                                    Icon { role: "display"; anchors.centerIn: parent; text: "" } 
                                } 
                                Label { role: "caption"; text: "Wallpaper"; font.weight: Design.weight.semibold; Layout.alignment: Qt.AlignHCenter } 
                            }
                            
                            Item { 
                                Layout.preferredWidth: Design.s(60)
                                Layout.preferredHeight: Design.s(20)
                                Layout.alignment: Qt.AlignVCenter
                                Repeater { 
                                    model: 3
                                    Item { 
                                        width: parent.width
                                        height: parent.height
                                        Rectangle { 
                                            width: Design.s(6)
                                            height: Design.s(6)
                                            radius: Design.s(3)
                                            color: [Design.accentAlt, Design.warn, Design.accent][index]
                                            y: parent.height / 2 - Design.s(3)
                                            SequentialAnimation on x { 
                                                loops: Animation.Infinite
                                                running: root.currentTab === 5
                                                PauseAnimation { duration: index * 400 }
                                                NumberAnimation { from: 0; to: parent.width; duration: root.pulsePeriod; easing.type: Easing.InOutSine } 
                                            } 
                                            SequentialAnimation on opacity { 
                                                loops: Animation.Infinite
                                                running: root.currentTab === 5
                                                PauseAnimation { duration: index * 400 }
                                                NumberAnimation { from: 0; to: 1; duration: Design.duration.base }
                                                PauseAnimation { duration: root.introDuration }
                                                NumberAnimation { from: 1; to: 0; duration: Design.duration.base } 
                                            } 
                                        } 
                                    } 
                                } 
                            }
                            
                            Rectangle {
                                width: Design.s(180)
                                height: Design.s(90)
                                radius: Design.s(12)
                                color: Design.surface
                                border.color: root.ambientPurple
                                Layout.alignment: Qt.AlignVCenter
                                
                                SequentialAnimation on border.width { 
                                    loops: Animation.Infinite
                                    running: root.currentTab === 5
                                    NumberAnimation { from: Design.s(1); to: Design.s(4); duration: root.tintDuration; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: Design.s(4); to: Design.s(1); duration: root.tintDuration; easing.type: Easing.InOutSine } 
                                }
                                
                                ColumnLayout { 
                                    anchors.centerIn: parent
                                    spacing: Design.s(8)
                                    Label { text: "Matugen Core"; font.weight: Design.weight.bold; color: root.ambientPurple; Layout.alignment: Qt.AlignHCenter } 
                                    RowLayout { 
                                        spacing: Design.s(4)
                                        Layout.alignment: Qt.AlignHCenter
                                        Repeater { 
                                            model: [Design.danger, Design.warn, Design.warn, Design.ok, Design.accent, Design.accentAlt]
                                            Rectangle { 
                                                Layout.alignment: Qt.AlignVCenter
                                                width: Design.s(12)
                                                height: Design.s(12)
                                                radius: Design.s(6)
                                                color: modelData
                                                SequentialAnimation on scale { 
                                                    loops: Animation.Infinite
                                                    running: root.currentTab === 5
                                                    PauseAnimation { duration: index * 150 }
                                                    NumberAnimation { to: 1.3; duration: Design.duration.base; easing.type: Easing.OutQuart }
                                                    NumberAnimation { to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutQuart }
                                                    PauseAnimation { duration: root.tintDuration } 
                                                } 
                                            } 
                                        } 
                                    } 
                                } 
                            }
                            
                            Item { 
                                Layout.preferredWidth: Design.s(60)
                                Layout.preferredHeight: Design.s(20)
                                Layout.alignment: Qt.AlignVCenter
                                Repeater { 
                                    model: 3
                                    Item { 
                                        width: parent.width
                                        height: parent.height
                                        Rectangle { 
                                            width: Design.s(6)
                                            height: Design.s(6)
                                            radius: Design.s(3)
                                            color: [Design.ok, Design.warn, Design.accentAlt][index]
                                            y: parent.height / 2 - Design.s(3)
                                            SequentialAnimation on x { 
                                                loops: Animation.Infinite
                                                running: root.currentTab === 5
                                                PauseAnimation { duration: index * 400 }
                                                NumberAnimation { from: 0; to: parent.width; duration: root.pulsePeriod; easing.type: Easing.InOutSine } 
                                            } 
                                            SequentialAnimation on opacity { 
                                                loops: Animation.Infinite
                                                running: root.currentTab === 5
                                                PauseAnimation { duration: index * 400 }
                                                NumberAnimation { from: 0; to: 1; duration: Design.duration.base }
                                                PauseAnimation { duration: root.introDuration }
                                                NumberAnimation { from: 1; to: 0; duration: Design.duration.base } 
                                            } 
                                        } 
                                    } 
                                } 
                            }
                            
                            ColumnLayout { 
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Design.s(8)
                                Rectangle { 
                                    Layout.alignment: Qt.AlignHCenter
                                    width: Design.s(60)
                                    height: Design.s(60)
                                    radius: Design.s(10)
                                    color: Design.hover
                                    Icon { role: "display"; anchors.centerIn: parent; text: "󰏘" } 
                                } 
                                Label { role: "caption"; text: "Templates"; font.weight: Design.weight.semibold; Layout.alignment: Qt.AlignHCenter } 
                            }
                            Item { Layout.fillWidth: true } 
                        }
                    }

                    Label { text: "When you change wallpapers, Matugen extracts the dominant colors and writes the shared palette used by these configs:"; dim: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; Layout.alignment: Qt.AlignVCenter }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 3
                        rowSpacing: Design.s(10)
                        columnSpacing: Design.s(10)
                        
                        Repeater {
                            model: [ 
                                { f: "kitty/matugen-colors.conf", i: "󰄛", c: "yellow" }, 
                                { f: "nvim/lua/matugen-colors.lua", i: "", c: "green" }, 
                                { f: "rofi/matugen-colors.rasi", i: "", c: "blue" }, 
                                { f: "cava/colors", i: "󰎆", c: "mauve" }, 
                                { f: "cache/matugen/sddm-colors.conf", i: "󰍃", c: "peach" }, 
                                { f: "tmp/qs_colors.json", i: "󰂚", c: "pink" } 
                            ]
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Design.s(45)
                                radius: Design.s(8)
                                color: tplMa.containsMouse ? Qt.alpha(root[modelData.c], 0.1) : Design.raised
                                border.color: tplMa.containsMouse ? root[modelData.c] : "transparent"
                                border.width: 1
                                
                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }
                                
                                RowLayout { 
                                    anchors.fill: parent
                                    anchors.margins: Design.s(10)
                                    spacing: Design.s(10)
                                    Item { 
                                        Layout.preferredWidth: Design.s(24)
                                        Layout.alignment: Qt.AlignVCenter
                                        Icon { anchors.centerIn: parent; text: modelData.i; color: root[modelData.c] } 
                                    } 
                                    Label { role: "caption"; text: modelData.f; font.weight: Font.Medium; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter } 
                                }
                                Clickable { id: tplMa }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 6: WEATHER API
            // ------------------------------------------
            Item {
                id: weatherTab
                anchors.fill: parent
                visible: root.currentTab === 6
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                property string selectedUnit: "metric"
                property bool apiKeyVisible: false

                function saveWeatherConfig() {
                    var cache_weather = Quickshell.env("HOME") + "/.cache/quickshell/weather";
                    var file = Quickshell.env("HOME") + "/.config/sway/scripts/quickshell/calendar/.env";
                    var cmds = [
                        "mkdir -p $(dirname " + file + ")",
                        "echo '# OpenWeather API Configuration (OVERWRITE, not add)' > " + file,
                        "echo 'OPENWEATHER_KEY=" + apiKeyInput.text + "' >> " + file,
                        "echo 'OPENWEATHER_CITY_ID=" + cityIdInput.text + "' >> " + file,
                        "echo 'OPENWEATHER_UNIT=" + weatherTab.selectedUnit + "' >> " + file,
                        "rm -r " + cache_weather,
                        "notify-send 'Weather' 'API configuration saved successfully!'"
                    ];
                    var finalCmd = cmds.join(" && ");
                    Quickshell.execDetached(["bash", "-c", finalCmd]);
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Design.s(15)
                    anchors.leftMargin: Design.s(20)
                    anchors.rightMargin: Design.s(20)
                    anchors.bottomMargin: Design.s(20)
                    spacing: Design.s(15)

                    Label { role: "display"; text: "Weather Configuration"; font.weight: Design.weight.bold; Layout.alignment: Qt.AlignVCenter }
                    Label { text: "To use the weather widget, please enter your OpenWeatherMap API Key.\nThen, search for your city's exact City ID on OpenWeatherMap and enter it below."; dim: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; Layout.alignment: Qt.AlignVCenter }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(46)
                        radius: Design.s(8)
                        color: Design.raised
                        border.color: apiKeyInput.activeFocus ? Design.accent : Design.active
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(10)
                            spacing: Design.s(10)
                            Icon { text: "󰌆"; dim: true }
                            TextInput { 
                                id: apiKeyInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Design.font.mono
                                font.pixelSize: Design.s(13)
                                color: Design.text
                                clip: true
                                selectByMouse: true
                                echoMode: weatherTab.apiKeyVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                Text { text: "Enter OpenWeather API Key..."; color: Design.textDim; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter } 
                            }
                            Rectangle { 
                                width: Design.s(26)
                                height: Design.s(26)
                                radius: Design.s(4)
                                color: "transparent"
                                Icon {
                                    anchors.centerIn: parent
                                    text: weatherTab.apiKeyVisible ? "󰈈" : "󰈉"
                                    color: eyeMa.containsMouse ? Design.accent : Design.textDim
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                } 
                                Clickable { id: eyeMa; onClicked: weatherTab.apiKeyVisible = !weatherTab.apiKeyVisible } 
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(46)
                        radius: Design.s(8)
                        Layout.topMargin: Design.s(10)
                        color: Design.raised
                        border.color: cityIdInput.activeFocus ? Design.warn : Design.active
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }
                        
                        TextInput { 
                            id: cityIdInput
                            anchors.fill: parent
                            anchors.margins: Design.s(10)
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(13)
                            color: Design.text
                            clip: true
                            selectByMouse: true
                            Text { text: "City ID (e.g. 2624652)"; color: Design.textDim; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter } 
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.s(15)
                        Layout.topMargin: Design.s(10)
                        Label { text: "Units:"; font.weight: Design.weight.semibold }
                        
                        RowLayout {
                            spacing: Design.s(5)
                            Repeater {
                                model: ["metric", "imperial", "standard"]
                                Rectangle {
                                    Layout.preferredWidth: Design.s(80)
                                    Layout.preferredHeight: Design.s(32)
                                    radius: Design.s(6)
                                    color: weatherTab.selectedUnit === modelData ? Qt.alpha(Design.accentAlt, 0.2) : "transparent"
                                    border.color: weatherTab.selectedUnit === modelData ? Design.accentAlt : Design.hover
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                                    Label {
                                        role: "caption"
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.capitalization: Font.Capitalize
                                        color: weatherTab.selectedUnit === modelData ? Design.accentAlt : Design.textDim
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: weatherTab.selectedUnit = modelData }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true; Layout.fillWidth: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        
                        Rectangle {
                            Layout.preferredWidth: Design.s(160)
                            Layout.preferredHeight: Design.s(46)
                            radius: Design.s(8)
                            color: saveMa.containsMouse ? Qt.alpha(Design.ok, 0.8) : Design.ok
                            scale: saveMa.pressed ? 0.95 : (saveMa.containsMouse ? 1.02 : 1.0)
                            
                            Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                            
                            RowLayout { 
                                anchors.centerIn: parent
                                spacing: Design.s(8)
                                Icon { text: "󰆓"; color: Design.surface } 
                                Label { text: "Save Config"; font.weight: Design.weight.bold; color: Design.surface } 
                            }
                            
                            Clickable { id: saveMa; onClicked: weatherTab.saveWeatherConfig() }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB 7: GREETER
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 7
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                Label {
                    role: "title"
                    anchors.centerIn: parent
                    text: "coming soon"
                    dim: true
                }
            }

            // ------------------------------------------
            // TAB 8: ABOUT
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: root.currentTab === 8
                opacity: visible ? 1.0 : 0.0
                property real slideY: visible ? 0 : Design.s(10)
                
                Behavior on slideY { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuart } }
                transform: Translate { y: slideY }
                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                Label {
                    role: "title"
                    anchors.centerIn: parent
                    text: "coming soon"
                    dim: true
                }
            }
        }
    }
}
