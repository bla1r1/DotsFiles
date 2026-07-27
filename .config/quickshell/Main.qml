import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./Services"
import "WindowRegistry.js" as Registry

PanelWindow {
    id: masterWindow
    color: "transparent"
    
    IpcHandler {
        target: "main"
    
        function forceReload() {
            Quickshell.reload(true) 
        }

        function close() {
            masterWindow.handleIpcCommand("close", true)
        }

        function open(targetWidget: string, arg: string) {
            masterWindow.handleIpcCommand("open:" + targetWidget + ":" + (arg || ""), true)
        }

        function toggle(targetWidget: string, arg: string) {
            masterWindow.handleIpcCommand("toggle:" + targetWidget + ":" + (arg || ""), true)
        }

        function toggleControl() { masterWindow.handleIpcCommand("toggle:control:", true) }
        function toggleBattery() { masterWindow.handleIpcCommand("toggle:battery:", true) }
        function toggleVolume() { masterWindow.handleIpcCommand("toggle:volume:", true) }
        function toggleMusic() { masterWindow.handleIpcCommand("toggle:music:", true) }
        function toggleMonitors() { masterWindow.handleIpcCommand("toggle:monitors:", true) }
        function toggleGuide() { masterWindow.handleIpcCommand("toggle:guide:", true) }
        function toggleUpdater() { masterWindow.handleIpcCommand("toggle:updater:", true) }
        function toggleSettings() { masterWindow.handleIpcCommand("toggle:settings:", true) }
        function toggleCalendar() { masterWindow.handleIpcCommand("toggle:calendar:", true) }
        function toggleFocusTime() { masterWindow.handleIpcCommand("toggle:focustime:", true) }
        function toggleNetworkWifi() { masterWindow.handleIpcCommand("toggle:network:wifi", true) }
        function toggleNetworkBt() { masterWindow.handleIpcCommand("toggle:network:bt", true) }
        function toggleNetwork() { masterWindow.handleIpcCommand("toggle:network:bt", true) }
        function openAudioFull() { masterWindow.handleIpcCommand("open:audioFull:", true) }
        function openPowerFull() { masterWindow.handleIpcCommand("open:powerFull:", true) }
        function openNetFull() { masterWindow.handleIpcCommand("open:netFull:", true) }
        function openMediaFull() { masterWindow.handleIpcCommand("open:mediaFull:", true) }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay
    
    exclusionMode: ExclusionMode.Ignore 
    focusable: isVisible

    width: Screen.width
    height: Screen.height

    visible: isVisible
    readonly property string scriptDir: Quickshell.env("QS_SCRIPT_DIR") || (Quickshell.env("HOME") + "/.config/sway/scripts")

    Item {
        id: topBarHole
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 65 
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible
        onClicked: switchWidget("hidden", "")
    }

    Component.onCompleted: {
        // State is now strictly in memory; no need to write to /tmp on startup.
    }

    property string currentActive: "hidden"

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false 
    property int morphDuration: 120
    property int exitDuration: 90 // Controls how fast the outgoing widget disappears
    property bool firstOpen: false

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0
    
    property real targetW: 1
    property real targetH: 1

    // Was fed by its own jq subprocess reading settings.json; now one typed
    // read from the store, which is watching the file anyway.
    readonly property real globalUiScale: Settings.uiScale
    property string lastIpcCommand: ""
    property string loadedWidget: ""

    // Permanent notification history placeholder. The Sway port keeps this
    // passive so Main.qml does not conflict with any existing notification daemon.
    ListModel {
        id: globalNotificationHistory
    }

    property var notifModel: globalNotificationHistory

    onGlobalUiScaleChanged: {
        handleNativeScreenChange();
    }

    function getLayout(name) {
        return Registry.getLayout(name, 0, 0, Screen.width, Screen.height, masterWindow.globalUiScale);
    }

    Connections {
        target: Screen
        function onWidthChanged() { handleNativeScreenChange(); }
        function onHeightChanged() { handleNativeScreenChange(); }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;
        
        let t = getLayout(masterWindow.currentActive);
        if (t) {
            masterWindow.animX = t.rx;
            masterWindow.animY = t.ry;
            masterWindow.animW = t.w;
            masterWindow.animH = t.h;
            masterWindow.targetW = t.w;
            masterWindow.targetH = t.h;
        }
    }

    // `requestActivate()` is not a method on a layer-shell window — this threw
    // a TypeError every single time a popup opened, aborting the handler.
    // Pre-existing, and only visible once the shell was actually run.
    // Keyboard focus comes from `focusable: isVisible` above; nothing else is
    // needed.

    Item {
        x: masterWindow.animX
        y: masterWindow.animY
        width: masterWindow.animW
        height: masterWindow.animH
        clip: true 
        layer.enabled: masterWindow.isVisible 

        // Smoother easing type: OutExpo makes animations feel snappy yet perfectly fluid
        Behavior on x { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutExpo } }
        Behavior on y { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutExpo } }
        Behavior on width { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutExpo } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutExpo } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutSine } }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.centerIn: parent
            width: masterWindow.targetW
            height: masterWindow.targetH

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true
                
                Keys.onEscapePressed: {
                    switchWidget("hidden", "");
                    event.accepted = true;
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 120; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; from: 0.98; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
                    }
                }
                replaceExit: Transition {
                    ParallelAnimation {
                        // Uses the dynamically set exitDuration
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: masterWindow.exitDuration; easing.type: Easing.InCubic }
                        NumberAnimation { property: "scale"; from: 1.0; to: 1.01; duration: masterWindow.exitDuration; easing.type: Easing.InCubic }
                    }
                }
            }
        }
    }

    function switchWidget(newWidget, arg) {
        // REMOVED: Quickshell.execDetached file writing. State is strictly in memory now.

        prepTimer.stop();
        delayedClear.stop();
        cacheExpireTimer.stop();

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.morphDuration = 120;
                masterWindow.exitDuration = 90;
                masterWindow.disableMorph = false;
                
                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false; 
                
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden") {
                masterWindow.morphDuration = 80;
                masterWindow.exitDuration = 60;
                masterWindow.disableMorph = true;
                masterWindow.firstOpen = true;
                
                let t = getLayout(newWidget);
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = t.w;
                masterWindow.animH = t.h;
                masterWindow.targetW = t.w;
                masterWindow.targetH = t.h;
                masterWindow.isVisible = true;

                prepTimer.newWidget = newWidget;
                prepTimer.newArg = arg;
                prepTimer.start();
                
            } else {
                // Morphing directly between widgets
                masterWindow.morphDuration = 120;
                masterWindow.disableMorph = false;
                
                masterWindow.exitDuration = 90;
                
                executeSwitch(newWidget, arg, false);
            }
        }
    }

    Timer {
        id: prepTimer
        interval: 0
        property string newWidget: ""
        property string newArg: ""
        onTriggered: executeSwitch(newWidget, newArg, false)
    }

    // Which page inside a multi-page surface a widget name means. Used both when
    // the surface is created and when it is already on screen.
    function pageFor(w, a) {
        if (w === "wifi") return "wifi";
        if (w === "bluetooth") return "bluetooth";
        if (w === "sound" || w === "volume") return "sound";
        if (w === "power" || w === "battery") return "power";
        if (w === "network") return (a === "bt" || a === "bluetooth") ? "bluetooth" : "wifi";
        if (w === "control") return a || "main";
        if (w === "notifications") return "notifications";
        // Lets a bar button or a keybinding land on a specific settings page:
        // `ipc call main open settings audio`.
        if (w === "settings") return a || "";
        return "";
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        
        let t = getLayout(newWidget);
        if (!t) {
            return;
        }
        masterWindow.animX = t.rx;
        masterWindow.animY = t.ry;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.targetW = t.w;
        masterWindow.targetH = t.h;

        const sameComponent = masterWindow.loadedWidget !== ""
            && getLayout(masterWindow.loadedWidget)
            && getLayout(masterWindow.loadedWidget).comp === t.comp;

        if (sameComponent && widgetStack.currentItem) {
            const target = pageFor(newWidget, arg);
            if (target && widgetStack.currentItem.page !== undefined)
                widgetStack.currentItem.page = target;
            masterWindow.isVisible = true;
            masterWindow.firstOpen = false;
            masterWindow.disableMorph = false;
            widgetStack.currentItem.forceActiveFocus();
            return;
        }
        
        let props = { "notifModel": masterWindow.notifModel };
        const page = pageFor(newWidget, arg);
        if (page)
            props["page"] = page;

        if (immediate || masterWindow.firstOpen) {
            widgetStack.replace(t.comp, props, StackView.Immediate);
            masterWindow.firstOpen = false;
            masterWindow.disableMorph = false;
        } else {
            widgetStack.replace(t.comp, props);
        }
        masterWindow.loadedWidget = newWidget;
        
        masterWindow.isVisible = true;
    }

    // =========================================================
    // --- IPC: EVENT-DRIVEN WATCHER
    // =========================================================
    function handleIpcCommand(rawCmd, force) {
        rawCmd = rawCmd.trim();
        if (rawCmd === "" || (!force && rawCmd === masterWindow.lastIpcCommand)) return;

        masterWindow.lastIpcCommand = rawCmd;
        rawCmd = rawCmd.split("|")[0];

        let parts = rawCmd.split(":");
        let cmd = parts[0];

        if (cmd === "close") {
            switchWidget("hidden", "");
        } else if (cmd === "toggle" || cmd === "open") {
            let targetWidget = parts.length > 1 ? parts[1] : "";
            let arg = parts.length > 2 ? parts.slice(2).join(":") : "";

            delayedClear.stop();

            if (targetWidget === masterWindow.currentActive) {
                let currentItem = widgetStack.currentItem;

                // 1. Same surface, different page: hand it over instead of
                // reloading. Only `activeMode` was handled here, which the
                // page-based surfaces do not have — so asking for a specific
                // settings page while settings was open did nothing at all.
                const wantPage = arg !== "" ? pageFor(targetWidget, arg) : "";

                if (wantPage !== "" && currentItem && currentItem.page !== undefined
                    && currentItem.page !== wantPage) {
                    currentItem.page = wantPage;
                }
                else if (arg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== arg) {
                    currentItem.activeMode = arg;
                }
                // 2. If it's a toggle command and the tab matches (or no subtarget given), close it
                else if (cmd === "toggle") {
                    switchWidget("hidden", "");
                }
                // 3. If "open" and already on the correct tab, do nothing (stays open).

            } else if (getLayout(targetWidget)) {
                switchWidget(targetWidget, arg);
            }
        } else if (getLayout(cmd)) {
            // Fallback for old formatting
            let arg = parts.length > 1 ? parts.slice(1).join(":") : "";
            delayedClear.stop();

            if (cmd === masterWindow.currentActive) {
                let currentItem = widgetStack.currentItem;
                if (arg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== arg) {
                    currentItem.activeMode = arg;
                } else {
                    switchWidget("hidden", "");
                }
            } else {
                switchWidget(cmd, arg);
            }
        }
    }

    Timer {
        id: delayedClear
        interval: masterWindow.morphDuration 
        onTriggered: {
            masterWindow.currentActive = "hidden";
            masterWindow.disableMorph = false;
            cacheExpireTimer.start();
        }
    }

    Timer {
        id: cacheExpireTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (masterWindow.currentActive === "hidden") {
                widgetStack.clear();
                masterWindow.loadedWidget = "";
            }
        }
    }

    Loader {
        active: true
        source: "notifications/NotificationToasts.qml"
    }
}
