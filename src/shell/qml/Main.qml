import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./Ui"
import "./Services"
import "WindowRegistry.js" as Registry

Scope {
    id: rootScope

    // Ui/Design cannot read Services/Settings itself — the standalone apps load
    // Ui without a Quickshell runtime — so the shell is what joins the two. The
    // accent picker in Appearance had no effect on anything before this.
    Binding {
        target: Design
        property: "accentName"
        value: Settings.accentName
    }

    // Services/Theme is a singleton, and a QML singleton is not created until
    // something refers to it — so without this the theme was only applied once
    // the Appearance page happened to be opened, and never at login.
    // Only once Settings has actually read the file. Applying eagerly here
    // used the schema default instead of the saved choice, and since applying
    // publishes the palette, that overwrote the active theme with the default
    // on every login — the picked theme survived in settings.json and was
    // undone on disk a moment later.
    Component.onCompleted: {
        if (Settings.loaded && Settings.themeName)
            Theme.apply(Settings.themeName);

        // Warm the focused-screen lookup, so the first toast or OSD is placed
        // correctly instead of appearing on screen one and hopping across once
        // the answer arrives. The singleton is created lazily otherwise — at
        // the moment something first asks it a question.
        Screens.refresh();
    }

    Connections {
        target: Settings
        function onLoadedChanged() {
            if (Settings.loaded && Settings.themeName)
                Theme.apply(Settings.themeName);
        }
    }

    // Turns B1air.Daemon call failures into notifications.
    DaemonErrors {}

    // One bar per screen.
    //
    // TopBar was instantiated once, and a PanelWindow with no screen set lands
    // on the first one — so on a two-monitor desktop the second monitor had no
    // bar at all: no clock, no workspaces, no tray, nothing. Confirmed on a
    // live session with two outputs, where the bar covered x 0..1920 of a
    // 3840-wide desktop and the rest was bare.
    //
    // Odd, given how much of this project is about multiple monitors: a
    // Displays page, a persisted layout, per-output brightness.
    Variants {
        model: Quickshell.screens

        delegate: TopBar {
            required property var modelData
            screen: modelData
            onRequestCommand: (cmd, notify) => masterWindow.handleIpcCommand(cmd, notify)
        }
    }

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
        function togglePollKit() { masterWindow.handleIpcCommand("toggle:pollkit:", true) }
        function toggleSettings() { masterWindow.handleIpcCommand("toggle:settings:", true) }
        function toggleCalendar() { masterWindow.handleIpcCommand("toggle:calendar:", true) }
        function toggleClipboard() { masterWindow.handleIpcCommand("toggle:clipboard:", true) }
        function toggleFocusTime() { masterWindow.handleIpcCommand("toggle:focustime:", true) }
        function toggleNetworkWifi() { masterWindow.handleIpcCommand("toggle:network:wifi", true) }
        function toggleNetworkBt() { masterWindow.handleIpcCommand("toggle:network:bt", true) }
        function toggleNetwork() { masterWindow.handleIpcCommand("toggle:network:bt", true) }
        function openAudioFull() { masterWindow.handleIpcCommand("open:audioFull:", true) }
        function openPowerFull() { masterWindow.handleIpcCommand("open:powerFull:", true) }
        function openNetFull() { masterWindow.handleIpcCommand("open:netFull:", true) }
        function openMediaFull() { masterWindow.handleIpcCommand("open:mediaFull:", true) }
        function openSession() { masterWindow.handleIpcCommand("open:session:", true) }
        function toggleSession() { masterWindow.handleIpcCommand("toggle:session:", true) }
        function openKeyboard() { masterWindow.handleIpcCommand("open:keyboard:", true) }
        function toggleKeyboard() { masterWindow.handleIpcCommand("toggle:keyboard:", true) }
        function openLauncher() { masterWindow.handleIpcCommand("open:launcher:", true) }
        function toggleLauncher() { masterWindow.handleIpcCommand("toggle:launcher:", true) }
        function openSpotlight() { masterWindow.handleIpcCommand("open:spotlight:", true) }
        function toggleSpotlight() { masterWindow.handleIpcCommand("toggle:spotlight:", true) }
        function openLaunchpad() { masterWindow.handleIpcCommand("open:launchpad:", true) }
        function toggleLaunchpad() { masterWindow.handleIpcCommand("toggle:launchpad:", true) }
        function openMenu() { masterWindow.handleIpcCommand("open:menu:", true) }
        function toggleMenu() { masterWindow.handleIpcCommand("toggle:menu:", true) }
        function openSwitcher() { masterWindow.handleIpcCommand("open:switcher:", true) }
        function toggleSwitcher() { masterWindow.handleIpcCommand("toggle:switcher:", true) }

        // Real Alt+Tab needs two distinct actions, not one toggle: each Tab
        // press while Alt is held must advance the selection, and toggling
        // would instead close the popup on every second press. Release of
        // Alt (bound separately in sway) confirms. "switcher" was never in
        // WindowRegistry until now, so toggleSwitcher above has always been
        // a silent no-op — that's why Alt+Tab had no binding at all.
        function switcherAdvance() {
            if (masterWindow.currentActive === "switcher" && widgetStack.currentItem
                    && widgetStack.currentItem.nextWindow) {
                widgetStack.currentItem.nextWindow();
            } else {
                masterWindow.handleIpcCommand("open:switcher:", true);
            }
        }
        function switcherConfirm() {
            if (masterWindow.currentActive === "switcher" && widgetStack.currentItem
                    && widgetStack.currentItem.activateCurrent) {
                widgetStack.currentItem.activateCurrent();
            }
        }
        function openEmoji() { masterWindow.handleIpcCommand("open:emoji:", true) }
        function toggleEmoji() { masterWindow.handleIpcCommand("toggle:emoji:", true) }
        function openZones() { masterWindow.handleIpcCommand("open:zones:", true) }
        function toggleZones() { masterWindow.handleIpcCommand("toggle:zones:", true) }
        function openRuler() { masterWindow.handleIpcCommand("open:ruler:", true) }
        function toggleRuler() { masterWindow.handleIpcCommand("toggle:ruler:", true) }
        function openShelf() { masterWindow.handleIpcCommand("open:shelf:", true) }
        function toggleShelf() { masterWindow.handleIpcCommand("toggle:shelf:", true) }
        function openQuickLook(file: string) { masterWindow.handleIpcCommand("open:quicklook:" + (file || ""), true) }
        function toggleQuickLook(file: string) { masterWindow.handleIpcCommand("toggle:quicklook:" + (file || ""), true) }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay
    
    exclusionMode: ExclusionMode.Ignore
    focusable: isVisible

    // Quickshell deprecated setting width/height on a PanelWindow; it wants the
    // implicit pair and warned about both on every start.
    implicitWidth: Screen.width
    implicitHeight: Screen.height

    visible: isVisible
    readonly property string scriptDir: Quickshell.env("QS_SCRIPT_DIR") || (Quickshell.env("HOME") + "/.config/sway/scripts")

    // Without a mask this layer-shell surface claims pointer input across the
    // whole screen — including the transparent strip over the TopBar — even
    // though nothing is drawn there. That silently ate every click meant for
    // TopBar's own surface underneath whenever a popup was open. Masking to
    // just the below-the-bar MouseArea lets clicks over the bar fall through.
    mask: Region {
        item: masterWindow.isVisible ? clickCatcher : null
    }

    Item {
        id: topBarHole
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 42
    }

    MouseArea {
        id: clickCatcher
        anchors.top: topBarHole.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        enabled: masterWindow.isVisible
        onClicked: masterWindow.switchWidget("hidden", "")
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
    readonly property real globalUiScale: Design.uiScale

    // NOT the real Wayland output scale (Screen.devicePixelRatio) — Qt Quick
    // already renders every window, layer-shell surfaces included, at the
    // compositor's real scale on its own; nothing here has to ask for that.
    // Binding this to devicePixelRatio doubled it: the surface was already
    // being drawn at (say) 1.5x by Qt, and then every Design.s() size in it
    // got multiplied by another 1.5x on top, so the bar rendered enormous at
    // any scale other than 1.0. uiScale is a separate, purely cosmetic
    // "make the shell chrome bigger/smaller" preference on top of whatever
    // the real display scale already is — which is exactly why it used to be
    // a manual setting instead of derived from anything.
    Binding { target: Design; property: "uiScale"; value: 1.0 }
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
        return Registry.getLayout(name, 0, 0, Screen.width, Screen.height, masterWindow.globalUiScale,
                                  Settings.barPosition === "bottom");
    }

    Connections {
        target: Screen
        function onWidthChanged() { handleNativeScreenChange(); }
        function onHeightChanged() { handleNativeScreenChange(); }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onIpcTriggered(action, target, arg) {
            masterWindow.handleIpcCommand(action + ":" + target + ":" + (arg || ""), true);
        }
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
                if (!t) return;
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = t.w;
                masterWindow.animH = t.h;
                masterWindow.targetW = t.w;
                masterWindow.targetH = t.h;

                executeSwitch(newWidget, arg, true);
                masterWindow.isVisible = true;
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
        if (w === "guide") return "about";
        if (w === "focus") return "focus";
        if (w === "settings") {
            if (a === "wifi") return "network";
            if (a === "sound" || a === "volume") return "audio";
            if (a === "battery") return "power";
            return a || "";
        }
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
            if (newWidget === "quicklook" && widgetStack.currentItem.filePath !== undefined)
                widgetStack.currentItem.filePath = arg;
            if (newWidget === "settings" && arg && !target && widgetStack.currentItem.searchQuery !== undefined)
                widgetStack.currentItem.searchQuery = arg;
            masterWindow.isVisible = true;
            masterWindow.firstOpen = false;
            masterWindow.disableMorph = false;
            widgetStack.currentItem.forceActiveFocus();
            return;
        }
        
        let props = {};
        if (newWidget === "control")
            props["notifModel"] = masterWindow.notifModel;
        const page = pageFor(newWidget, arg);
        if (page)
            props["page"] = page;
        if (newWidget === "quicklook" && arg)
            props["filePath"] = arg;
        if ((newWidget === "spotlight" || newWidget === "launchpad") && arg)
            props["query"] = arg;
        if (newWidget === "settings" && arg && !page)
            props["searchQuery"] = arg;

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
            // Retain cached widget in widgetStack for zero-latency, zero-CPU reopening
        }
    }

    // Free widget tree if idle for 5 minutes
    Timer {
        id: idleMemoryCleanup
        interval: 300000 // 5 minutes
        running: !masterWindow.isVisible && widgetStack.depth > 0
        repeat: false
        onTriggered: {
            if (!masterWindow.isVisible) {
                widgetStack.clear();
                masterWindow.loadedWidget = "";
            }
        }
    }

    Loader {
        active: true
        source: "notifications/NotificationToasts.qml"
    }

    Loader {
        active: true
        source: "osd/OsdOverlay.qml"
    }
}
}
