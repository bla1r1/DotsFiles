import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Ui"

PopupShell {
    id: window

    // --- RECEIVE THE DBUS LIST FROM MAIN.QML ---
    property var notifModel



    // -------------------------------------------------------------------------
    // STATE & POLLING
    // -------------------------------------------------------------------------
    property int batCapacity: 0
    property string batStatus: "Unknown"
    property string powerProfile: "balanced"
    
    property int upHours: 0
    property int upMins: 0

    property real sysVolume: 0
    property bool sysMuted: false
    property real sysBrightness: 0
    
    property string currentUserName: ""
    
    property bool dndEnabled: false

    // State object for collapsible notification groups
    property var collapsedGroups: ({})

    function toggleGroup(groupName) {
        let temp = Object.assign({}, collapsedGroups);
        temp[groupName] = !temp[groupName];
        collapsedGroups = temp;
    }

    function isCollapsed(groupName) {
        return collapsedGroups[groupName] === true;
    }

    // Durations that are choreography, not styling: a staged entrance, ambient
    // breathing and a hold-to-confirm. Deliberately off the motion scale.
    // The pulses ran at 600 / 800 / 1200 / 1600 simultaneously — four rhythms
    // at once read as noise, so they share one period now.
    readonly property int introDuration: 800
    readonly property int introPause: 550
    readonly property int tintDuration: 1000
    readonly property int pulsePeriod: 1200
    readonly property int gaugeDuration: 1200
    readonly property int holdDuration: 1500
    readonly property int driftPeriod: 90000

    // Anti-jitter sync states — the poller must not yank a control mid-drag.
    property bool isDraggingVol: false
    property bool isDraggingBri: false

    Timer { id: volSyncDelay; interval: 800; onTriggered: window.isDraggingVol = false; triggeredOnStart: true; }

    readonly property bool isCharging: batStatus === "Charging"

    // Unified hue for Battery
    readonly property color batColorStart: {
        if (isCharging) return Design.ok;
        if (batCapacity >= 70) return Design.accent;
        if (batCapacity >= 30) return Design.warn;
        return Design.danger;
    }
    readonly property color batColorEnd: Qt.lighter(batColorStart, 1.15)

    // Unified hue for Performance Profile
    readonly property color profileStart: {
        if (powerProfile === "performance") return Design.danger;
        if (powerProfile === "power-saver") return Design.ok;
        return Design.accent;
    }
    readonly property color profileEnd: Qt.lighter(profileStart, 1.15)

    // Ambient Blobs - Based strictly on aesthetic pairs derived from battery state
    readonly property color ambientPrimary: window.batColorStart
    readonly property color ambientSecondary: {
        if (isCharging) return Design.accentSoft;
        if (batCapacity >= 70) return Design.accentAlt;
        if (batCapacity >= 30) return Design.warn;
        return Design.danger; 
    }

    property real animCapacity: 0
    Behavior on animCapacity { NumberAnimation { duration: window.gaugeDuration; easing.type: Easing.OutQuint } }
    
    onAnimCapacityChanged: batCanvas.requestPaint()
    onBatColorStartChanged: batCanvas.requestPaint()

    // --- INIT DND STATE FROM CACHE ---
    Process {
        id: dndInit
        running: true
        command: ["bash", "-c", "mkdir -p ~/.cache && cat ~/.cache/qs_dnd 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.dndEnabled = (this.text.trim() === "1");
            }
        }
    }

    Process {
        id: userPoller
        command: ["bash", "-c", "echo $USER"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                window.currentUserName = this.text.trim();
            }
        }
    }

    Process {
        id: sysPoller
        command: ["bash", "-c", 
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '0'; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'Unknown'; " +
            "powerprofilesctl get 2>/dev/null || echo 'balanced'; " +
            "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100), ($3==\"[MUTED]\"?\"off\":\"on\")}' || echo '0 on'; " +
            "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' || echo '0'"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 6) {
                    if (window.batCapacity !== parseInt(lines[0])) {
                        window.batCapacity = parseInt(lines[0]);
                        window.animCapacity = window.batCapacity;
                    }
                    window.batStatus = lines[1];
                    window.powerProfile = lines[2];
                    
                    let upParts = lines[3].split("h ");
                    if (upParts.length === 2) {
                        window.upHours = parseInt(upParts[0]) || 0;
                        window.upMins = parseInt(upParts[1].replace("m", "")) || 0;
                    }

                    if (!window.isDraggingVol) {
                        let volParts = (lines[4] || "0 on").trim().split(" ");
                        window.sysVolume = parseInt(volParts[0]) || 0;
                        window.sysMuted = (volParts[1] === "off");
                    }
                    
                    if (!window.isDraggingBri) {
                        window.sysBrightness = parseInt(lines[5]) || 0;
                    }
                }
            }
        }
    }
    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true;
        onTriggered: sysPoller.running = true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: window.driftPeriod; loops: Animation.Infinite; running: true
    }

    // --- ENHANCED STARTUP ANIMATION STATES ---
    property real introMain: 0
    property real introTop: 0
    property real introNotifs: 0
    property real introCore: 0
    property real introSliders: 0
    property real introActions: 0
    property real introProfiles: 0

    ParallelAnimation {
        running: true

        // Base window fades, scales, and lifts
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuart }

        // Top bar drops in
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.fast }
            NumberAnimation { target: window; property: "introTop"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }

        // Notification List cascades in smoothly
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.fast }
            NumberAnimation { target: window; property: "introNotifs"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuart }
        }

        // Central core pops out and breathes
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.base }
            NumberAnimation { target: window; property: "introCore"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        // Hardware sliders slide up
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.base }
            NumberAnimation { target: window; property: "introSliders"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuart }
        }

        // Actions waterfall
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.slow }
            NumberAnimation { target: window; property: "introActions"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutExpo }
        }

        // Power profiles finish the wave
        SequentialAnimation {
            PauseAnimation { duration: window.introPause }
            NumberAnimation { target: window; property: "introProfiles"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: window; property: "introMain"; to: 0; duration: Design.duration.slow; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introTop"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introNotifs"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introCore"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introSliders"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introActions"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introProfiles"; to: 0; duration: Design.duration.fast; easing.type: Easing.InQuart }
    }

    // Helper: Safely clear an entire group of notifications by AppName
    function clearGroup(appName) {
        if (!notifModel) return;
        for (let i = notifModel.count - 1; i >= 0; i--) {
            if (notifModel.get(i).appName === appName) {
                notifModel.remove(i);
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.92 + (0.08 * introMain)
        opacity: introMain
        transform: Translate { y: Design.s(15) * (1 - introMain) }

        // Unified Outer Background
        Rectangle {
            anchors.fill: parent
            radius: Design.s(20)
            color: Design.surface
            border.color: Design.raised 
            border.width: 1
            clip: true

            // Rotating Background Blobs - Spanning across the whole widget natively
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * Design.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * Design.s(100)
                opacity: 0.08
                color: window.ambientPrimary
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }
            
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * Design.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * Design.s(-100)
                opacity: 0.06
                color: window.ambientSecondary
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }

            RowLayout {
                anchors.fill: parent
                spacing: Design.s(15) // Seamless separation instead of a line

                // ==========================================
                // LEFT SIDE: NOTIFICATION CENTER
                // ==========================================
                Item {
                    Layout.preferredWidth: Design.s(320)
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Design.s(20)
                        spacing: Design.s(15)

                        // --- Notification Header & DND Toggle ---
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(38)
                            spacing: Design.s(12)
                            
                            transform: Translate { y: Design.s(-20) * (1.0 - introTop) }
                            opacity: introTop

                            Label {
                                role: "subhead"
                                text: "Notifications"
                                font.weight: Design.weight.bold
                            }

                            Item { Layout.fillWidth: true } // Spacer

                            // DND Toggle Button
                            Rectangle {
                                Layout.preferredWidth: dndMa.containsMouse ? Design.s(38) + dndText.implicitWidth + Design.s(8) : Design.s(38)
                                Layout.preferredHeight: Design.s(38)
                                radius: Design.s(12)
                                color: window.dndEnabled ? Qt.alpha(Design.danger, 0.15) : (dndMa.containsMouse ? Design.hover : "transparent")
                                border.color: window.dndEnabled ? Design.danger : (dndMa.containsMouse ? Design.active : "transparent")
                                border.width: 1
                                clip: true

                                Behavior on width { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuint } }
                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Design.s(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Design.s(8)

                                    Label {
                                        id: dndText
                                        text: window.dndEnabled ? "Silent" : "Mute"
                                        font.weight: Design.weight.semibold
                                        color: window.dndEnabled ? Design.danger : Design.text
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: dndMa.containsMouse ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
                                    }

                                    Icon {
                                        color: window.dndEnabled ? Design.danger : (dndMa.containsMouse ? Design.text : Design.textFaint)
                                        text: window.dndEnabled ? "󰂛" : "󰂚"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                    }
                                }

                                Clickable {
                                    id: dndMa
                                    onClicked: {
                                        window.dndEnabled = !window.dndEnabled;
                                        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.cache && echo '" + (window.dndEnabled ? "1" : "0") + "' > ~/.cache/qs_dnd"]);
                                    }
                                }
                            }
                        }

                        // --- Zero State ---
                        Label {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.weight: Design.weight.medium
                            color: Design.textFaint
                            text: "You're all caught up."
                            visible: !notifModel || notifModel.count === 0
                            opacity: introNotifs
                        }

                        // --- Notification List ---
                        ListView {
                            id: notifList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: window.notifModel
                            spacing: Design.s(8)
                            clip: true
                            
                            opacity: introNotifs
                            transform: Translate { y: Design.s(20) * (1 - introNotifs) }

                            ScrollBar.vertical: ScrollBar {
                                active: notifList.moving || notifList.movingVertically
                                width: Design.s(4)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle { implicitWidth: Design.s(4); radius: Design.s(2); color: Design.active }
                            }

                            // Fluid Animations
                            add: Transition {
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutQuint }
                                    NumberAnimation { property: "x"; from: Design.s(-40); to: 0; duration: Design.duration.slow; easing.type: Easing.OutExpo }
                                    NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutBack }
                                }
                            }
                            remove: Transition {
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; to: 0.0; duration: Design.duration.base; easing.type: Easing.OutQuint }
                                    NumberAnimation { property: "scale"; to: 0.9; duration: Design.duration.base; easing.type: Easing.OutQuint }
                                }
                            }
                            displaced: Transition {
                                NumberAnimation { properties: "y"; duration: Design.duration.slow; easing.type: Easing.OutExpo }
                            }

                            // --- Grouping Configuration ---
                            section.property: "appName"
                            section.criteria: ViewSection.FullString
                            section.delegate: Item {
                                width: ListView.view.width
                                height: Design.s(46)
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: Design.s(10)
                                    anchors.bottomMargin: Design.s(4)
                                    color: headerMa.containsMouse ? Design.hover : "transparent"
                                    radius: Design.s(8)
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Design.s(6)
                                        anchors.rightMargin: Design.s(6)
                                        spacing: Design.s(8)

                                        // Clickable Area for Collapse Toggle
                                        MouseArea {
                                            id: headerMa
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: window.toggleGroup(section)

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: Design.s(8)
                                                
                                                Icon {
                                                    role: "body"
                                                    color: Design.accentAlt
                                                    text: window.isCollapsed(section) ? "󰅂" : "󰅀"
                                                    Behavior on rotation { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                                }

                                                Label {
                                                    role: "caption"
                                                    text: section.toUpperCase()
                                                    font.weight: Design.weight.bold
                                                    Layout.fillWidth: true
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }

                                        // Clear Group Button
                                        Rectangle {
                                            Layout.preferredWidth: Design.s(26)
                                            Layout.preferredHeight: Design.s(26)
                                            radius: Design.s(13)
                                            color: groupClearMa.containsMouse ? Design.active : "transparent"
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                                            Icon {
                                                role: "body"
                                                anchors.centerIn: parent
                                                color: groupClearMa.containsMouse ? Design.danger : Design.textFaint
                                                text: "󰅖"
                                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                            }

                                            Clickable { id: groupClearMa; onClicked: window.clearGroup(section) }
                                        }
                                    }
                                }
                            }

                            // --- Individual Notification Card ---
                            delegate: Item {
                                id: delegateWrapper
                                width: ListView.view.width
                                property bool isHidden: window.isCollapsed(model.appName)
                                height: isHidden ? 0 : innerCard.height
                                visible: height > 0
                                opacity: isHidden ? 0 : 1
                                clip: true
                                
                                Behavior on height { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutExpo } }
                                Behavior on opacity { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuint } }

                                Rectangle {
                                    id: innerCard
                                    width: parent.width
                                    height: cardContent.height + Design.s(24)
                                    radius: Design.s(14)
                                    color: cardHover.containsMouse ? Design.hover : Design.raised
                                    border.color: cardHover.containsMouse ? Design.active : "transparent"
                                    border.width: 1
                                    clip: true
                                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    Behavior on border.color { ColorAnimation { duration: Design.duration.base } }

                                    Clickable { id: cardHover }

                                    // Left side accent stripe
                                    Rectangle {
                                        width: Design.s(4)
                                        height: parent.height
                                        anchors.left: parent.left
                                        color: window.ambientPrimary
                                    }

                                    ColumnLayout {
                                        id: cardContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: Design.s(14)
                                        anchors.leftMargin: Design.s(18) // make room for the accent stripe
                                        spacing: Design.s(6)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Design.s(8)

                                            Label {
                                                text: model.summary || "Notification"
                                                font.weight: Design.weight.semibold
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                            }

                                            // Individual Dismiss Button
                                            Rectangle {
                                                Layout.preferredWidth: Design.s(22)
                                                Layout.preferredHeight: Design.s(22)
                                                radius: Design.s(11)
                                                color: itemClearMa.containsMouse ? Qt.alpha(Design.danger, 0.15) : "transparent"
                                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                                                Icon {
                                                    role: "caption"
                                                    anchors.centerIn: parent
                                                    color: itemClearMa.containsMouse ? Design.danger : Design.textFaint
                                                    text: "󰅖"
                                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                                }

                                                Clickable {
                                                    id: itemClearMa
                                                    onClicked: {
                                                        if(window.notifModel) window.notifModel.remove(index);
                                                    }
                                                }
                                            }
                                        }

                                        Label {
                                            role: "caption"
                                            text: model.body || ""
                                            font.weight: Design.weight.medium
                                            dim: true
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            visible: text !== ""
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // RIGHT SIDE: HARDWARE & BATTERY CORE
                // ==========================================
                Item {
                    Layout.preferredWidth: Design.s(480)
                    Layout.fillHeight: true

                    // Radar Rings (Centered on the Hardware Panel so it aligns perfectly with the gauge)
                    Item {
                        anchors.fill: parent
                        
                        Repeater {
                            model: 3
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: Design.s(-70)
                                width: Design.s(320) + (index * Design.s(170))
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: window.ambientSecondary
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: window.tintDuration } }
                                opacity: 0.06 - (index * 0.02)
                            }
                        }
                    }

                    // TOP: UPTIME COMPONENT
                    Row {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: Design.s(25)
                        spacing: Design.s(6)
                        
                        transform: Translate { y: Design.s(-20) * (1.0 - introTop) }
                        opacity: introTop
                        
                        // Hours Box
                        Rectangle {
                            width: Design.s(44); height: Design.s(48); radius: Design.s(10)
                            color: Design.raised; border.color: Design.hover; border.width: 1
                            
                            Rectangle { anchors.fill: parent; radius: Design.s(10); color: window.ambientPrimary; opacity: 0.05; Behavior on color { ColorAnimation { duration: window.tintDuration } } }
                            Column {
                                anchors.centerIn: parent
                                Label {
                                    role: "subhead"
                                    text: window.upHours.toString().padStart(2, '0')
                                    font.weight: Design.weight.bold
                                    color: window.ambientPrimary
                                    Behavior on color { ColorAnimation { duration: window.tintDuration } }
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label {
                                    role: "caption"
                                    text: "HR"
                                    font.weight: Design.weight.semibold
                                    dim: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Pulsing Colon
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ":"
                            font.pixelSize: Design.s(22); font.family: Design.font.mono; font.weight: Design.weight.bold
                            color: window.ambientPrimary
                            Behavior on color { ColorAnimation { duration: window.tintDuration } }
                            
                            opacity: uptimePulse
                            property real uptimePulse: 1.0
                            SequentialAnimation on uptimePulse {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: 0.2; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                            }
                        }

                        // Mins Box
                        Rectangle {
                            width: Design.s(44); height: Design.s(48); radius: Design.s(10)
                            color: Design.raised; border.color: Design.hover; border.width: 1
                            
                            Rectangle { anchors.fill: parent; radius: Design.s(10); color: window.ambientSecondary; opacity: 0.05; Behavior on color { ColorAnimation { duration: window.tintDuration } } }
                            Column {
                                anchors.centerIn: parent
                                Label {
                                    role: "subhead"
                                    text: window.upMins.toString().padStart(2, '0')
                                    font.weight: Design.weight.bold
                                    color: window.ambientSecondary
                                    Behavior on color { ColorAnimation { duration: window.tintDuration } }
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label {
                                    role: "caption"
                                    text: "MIN"
                                    font.weight: Design.weight.semibold
                                    dim: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    // Expanding top-right logout icon
                    Rectangle {
                        id: logoutBtn
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.margins: Design.s(25)
                        width: logoutMa.containsMouse ? Design.s(44) + usernameText.implicitWidth + Design.s(12) : Design.s(44)
                        height: Design.s(44); radius: Design.s(14)
                        color: logoutMa.containsMouse ? Design.hover : "transparent"
                        border.color: logoutMa.containsMouse ? Design.active : "transparent"
                        clip: true
                        
                        transform: Translate { y: Design.s(-20) * (1.0 - introTop) }
                        opacity: introTop

                        Behavior on width { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                        Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Design.s(13)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Design.s(12)

                            Label {
                                id: usernameText
                                text: window.currentUserName
                                font.weight: Design.weight.semibold
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: logoutMa.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
                            }

                            Icon {
                                color: logoutMa.containsMouse ? Design.danger : Design.textFaint
                                text: "󰍃"
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                            }
                        }

                        Clickable {
                            id: logoutMa
                            onClicked: { 
                                exitAnim.start(); // Trigger graceful UI exit
                                Quickshell.execDetached(["sh", "-c", "loginctl terminate-user $USER"]); 
                                window.close();
                            }
                        }
                    }

                    // CENTRAL CORE & BATTERY RING 
                    Item {
                        anchors.fill: parent
                        z: 1
                        
                        opacity: introCore
                        transform: Translate { y: Design.s(25) * (1 - introCore) }
                        scale: 0.9 + (0.1 * introCore)

                        // CLEAN OUTSIDE GLOW HALO
                        Rectangle {
                            anchors.centerIn: centralCore
                            width: centralCore.width + Design.s(45)
                            height: width
                            radius: width / 2
                            color: centralCore.isDangerState ? Design.danger : window.ambientPrimary
                            opacity: centralCore.isDangerState ? 0.25 : 0.15
                            z: 0 
                            Behavior on color { ColorAnimation { duration: Design.duration.slow } }
                            SequentialAnimation on scale {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: heroMa.containsMouse ? 1.15 : 1.08; duration: heroMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: heroMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                            }
                        }

                        Rectangle {
                            id: centralCore
                            width: Design.s(260)
                            height: width
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: Design.s(-70)
                            radius: width / 2
                            z: 1
                            
                            property bool isDangerState: !window.isCharging && window.batCapacity < 15
                            
                            SequentialAnimation on scale {
                                loops: Animation.Infinite
                                running: true
                                NumberAnimation { 
                                    to: heroMa.containsMouse ? 1.05 : (centralCore.isDangerState ? 1.04 : 1.01)
                                    duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                                    easing.type: Easing.InOutSine 
                                }
                                NumberAnimation { 
                                    to: 1.0
                                    duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                                    easing.type: Easing.InOutSine 
                                }
                            }

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: Design.raised }
                                GradientStop { position: 1.0; color: Design.surface }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Design.danger
                                opacity: centralCore.isDangerState ? 0.15 : 0.0
                                Behavior on opacity { NumberAnimation { duration: window.tintDuration } }
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: centralCore.isDangerState
                                    NumberAnimation { to: 0.25; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.15; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                
                                property real textPulse: 0.0
                                SequentialAnimation on textPulse {
                                    loops: Animation.Infinite; running: true
                                    NumberAnimation { from: 0.0; to: 1.0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.0; to: 0.0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                }
                                
                                property real pumpPhase: 0.0
                                NumberAnimation on pumpPhase {
                                    running: heroMa.containsMouse && window.isCharging
                                    loops: Animation.Infinite
                                    from: 0.0; to: 1.0; duration: window.pulsePeriod
                                    easing.type: Easing.InOutSine 
                                    onStopped: batCanvas.requestPaint()
                                }
                                
                                property real dischargePhase: 1.0
                                NumberAnimation on dischargePhase {
                                    running: heroMa.containsMouse && !window.isCharging
                                    loops: Animation.Infinite
                                    from: 1.0; to: 0.0; duration: window.pulsePeriod
                                    easing.type: Easing.InOutSine
                                    onStopped: batCanvas.requestPaint()
                                }
                                
                                onPumpPhaseChanged: { if(heroMa.containsMouse && window.isCharging) batCanvas.requestPaint() }
                                onDischargePhaseChanged: { if(heroMa.containsMouse && !window.isCharging) batCanvas.requestPaint() }
                                
                                Canvas {
                                    id: batCanvas
                                    anchors.fill: parent
                                    rotation: 180 
                                    
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        
                                        var centerX = width / 2;
                                        var centerY = height / 2;
                                        var radius = (width / 2) - Design.s(18); 
                                        var endAngle = (window.animCapacity / 100) * 2 * Math.PI;
                                        
                                        ctx.lineCap = "round";
                                        
                                        ctx.lineWidth = Design.s(8);
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                                        ctx.strokeStyle = Design.hover;
                                        ctx.stroke();
                                        
                                        var fillGrad = ctx.createLinearGradient(0, height, width, 0);
                                        fillGrad.addColorStop(0, window.batColorStart.toString());
                                        fillGrad.addColorStop(1, window.batColorEnd.toString());

                                        ctx.globalAlpha = 1.0;
                                        ctx.lineWidth = Design.s(14);
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, 0, endAngle);
                                        ctx.strokeStyle = fillGrad;
                                        ctx.stroke();
                                        
                                        if (heroMa.containsMouse && endAngle > 0.1) {
                                            if (window.isCharging) {
                                                var surgeAngle = parent.pumpPhase * (endAngle + 0.6) - 0.3;
                                                if (surgeAngle > 0 && surgeAngle < endAngle) {
                                                    var sStart = Math.max(0, surgeAngle - 0.4);
                                                    var sEnd = Math.min(endAngle, surgeAngle + 0.4);
                                                    ctx.beginPath();
                                                    ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                                    ctx.lineWidth = Design.s(22);
                                                    ctx.strokeStyle = window.batColorStart.toString();
                                                    ctx.globalAlpha = 0.5 * Math.sin(parent.pumpPhase * Math.PI);
                                                    ctx.stroke();

                                                    sStart = Math.max(0, surgeAngle - 0.2);
                                                    sEnd = Math.min(endAngle, surgeAngle + 0.2);
                                                    ctx.beginPath();
                                                    ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                                    ctx.lineWidth = Design.s(28);
                                                    ctx.strokeStyle = window.batColorEnd.toString();
                                                    ctx.globalAlpha = 0.8 * Math.sin(parent.pumpPhase * Math.PI);
                                                    ctx.stroke();
                                                }
                                                
                                                if (parent.pumpPhase > 0.7) {
                                                    var flarePhase = (parent.pumpPhase - 0.7) / 0.3;
                                                    var hitX = centerX + Math.cos(endAngle) * radius;
                                                    var hitY = centerY + Math.sin(endAngle) * radius;
                                                    ctx.beginPath();
                                                    ctx.arc(hitX, hitY, Design.s(7) + (flarePhase * Design.s(15)), 0, 2*Math.PI);
                                                    ctx.fillStyle = window.batColorEnd.toString();
                                                    ctx.globalAlpha = (1.0 - flarePhase) * 0.6;
                                                    ctx.fill();
                                                }
                                            } else {
                                                var drainCenter = parent.dischargePhase * endAngle;
                                                for (var d = 0; d < 2; d++) {
                                                    var dSpread = 0.2 + (d * 0.15);
                                                    var dStart = Math.max(0, drainCenter - dSpread);
                                                    var dEnd = Math.min(endAngle, drainCenter + dSpread);
                                                    
                                                    if (dStart < dEnd) {
                                                        ctx.beginPath();
                                                        ctx.arc(centerX, centerY, radius, dStart, dEnd);
                                                        ctx.lineWidth = Design.s(14) + (1 - d) * Design.s(2);
                                                        ctx.strokeStyle = window.batColorEnd.toString();
                                                        ctx.globalAlpha = 0.2 * Math.sin(parent.dischargePhase * Math.PI);
                                                        ctx.stroke();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Design.s(-2)
                                
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: Design.s(8)
                                    
                                    Icon {
                                        role: "display"
                                        color: window.batColorStart
                                        text: window.isCharging ? "󰂄" : (window.batCapacity > 20 ? "󰁹" : "󰂃")
                                        Behavior on color { ColorAnimation { duration: Design.duration.slow } }
                                    }
                                    
                                    Text {
                                        font.family: Design.font.mono
                                        font.weight: Design.weight.bold
                                        font.pixelSize: Design.s(54)
                                        color: Design.text
                                        text: Math.round(window.animCapacity) + "%" 
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.semibold
                                    font.pixelSize: Design.s(13)
                                    
                                    color: window.isCharging 
                                            ? Qt.tint(Design.ok, Qt.rgba(1, 1, 1, parent.textPulse * 0.4)) 
                                            : (centralCore.isDangerState ? Qt.tint(Design.danger, Qt.rgba(1, 1, 1, parent.textPulse * 0.3)) : Design.textDim)
                                            
                                    text: window.batStatus.toUpperCase()
                                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                }
                            }
                        }

                        MouseArea {
                            id: heroMa
                            anchors.fill: centralCore 
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: batCanvas.requestPaint()
                            onExited: batCanvas.requestPaint()
                        }
                    }

                    // BOTTOM DOCKS
                    ColumnLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Design.s(25)
                        spacing: Design.s(15)

                        // 1. HARDWARE CONTROLS DOCK (Sliders)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(96)
                            radius: Design.s(14)
                            color: Design.raised
                            border.color: Design.hover
                            border.width: 1

                            opacity: introSliders
                            transform: Translate { y: Design.s(20) * (1.0 - introSliders) }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Design.s(14)
                                spacing: Design.s(12)

                                // Brightness Slider
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Design.s(15)

                                    Item {
                                        Layout.preferredWidth: Design.s(32)
                                        Layout.preferredHeight: Design.s(32)
                                        Icon {
                                            role: "title"
                                            anchors.centerIn: parent
                                            text: window.sysBrightness > 66 ? "󰃠" : (window.sysBrightness > 33 ? "󰃟" : "󰃞")
                                            color: window.ambientPrimary
                                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                        }
                                    }

                                    Slider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(18)

                                        value: window.sysBrightness
                                        tone: window.batColorStart
                                        cornerRadius: Design.radius.ctl

                                        onMoved: pct => {
                                            window.sysBrightness = pct;
                                            Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
                                        }
                                        onActiveChanged: window.isDraggingBri = active
                                    }
                                }

                                // Volume Slider
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Design.s(15)

                                    Rectangle {
                                        Layout.preferredWidth: Design.s(32)
                                        Layout.preferredHeight: Design.s(32)
                                        radius: Design.s(16)
                                        color: volIconMa.containsMouse ? Design.hover : "transparent"
                                        border.color: volIconMa.containsMouse ? window.profileStart : "transparent"
                                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                        Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                                        Icon {
                                            role: "title"
                                            anchors.centerIn: parent
                                            text: window.sysMuted || window.sysVolume === 0 ? "󰖁" : (window.sysVolume > 50 ? "󰕾" : "󰖀")
                                            color: window.sysMuted ? Design.textFaint : window.profileStart
                                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                        }
                                        Clickable {
                                            id: volIconMa
                                            onClicked: {
                                                volSyncDelay.stop();
                                                window.isDraggingVol = true; 
                                                window.sysMuted = !window.sysMuted;
                                                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                                                volSyncDelay.restart();
                                            }
                                        }
                                    }

                                    Slider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(18)

                                        value: window.sysVolume
                                        tone: window.profileStart
                                        muted: window.sysMuted

                                        onMoved: pct => {
                                            window.sysVolume = pct;
                                            if (pct > 0 && window.sysMuted) {
                                                window.sysMuted = false;
                                                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
                                            }
                                            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%"]);
                                        }
                                        onActiveChanged: window.isDraggingVol = active
                                    }
                                }
                            }
                        }

                        // 2. SYSTEM ACTIONS DOCK
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(75)
                            spacing: Design.s(12)
                            
                            Repeater {
                                model: ListModel {
                                    ListElement { cmd: "bash ~/.config/sway/scripts/session/lock.sh"; icon: ""; baseColor: "mauve"; weight: 1.0 }
                                    ListElement { cmd: "bash ~/.config/sway/scripts/session/suspend.sh"; icon: "ᶻ 𝗓 𐰁"; baseColor: "blue"; weight: 1.0 }
                                    ListElement { cmd: "systemctl reboot"; icon: "󰑓"; baseColor: "yellow"; weight: 2.5 }
                                    ListElement { cmd: "systemctl poweroff -i"; icon: ""; baseColor: "red"; weight: 3.5 }
                                }
                                
                                delegate: Rectangle {
                                    id: actionCapsule
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Design.s(14)

                                    opacity: introActions
                                    transform: Translate { y: Design.s(30) * (1.0 - introActions) + (index * Design.s(12) * (1.0 - introActions)) }
                                    
                                    property color c1: window[baseColor] || Design.hover
                                    property color c2: Qt.lighter(c1, 1.2)

                                    color: actionMa.containsMouse ? Design.hover : Design.raised
                                    border.color: actionMa.containsMouse ? c1 : Design.active
                                    border.width: actionMa.containsMouse ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                    
                                    scale: actionMa.pressed ? (0.98 - (0.01 * weight)) : (actionMa.containsMouse ? 1.08 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuart } }

                                    property real fillLevel: 0.0
                                    property bool triggered: false
                                    property real flashOpacity: 0.0
                                    
                                    Canvas {
                                        id: actionWaveCanvas
                                        anchors.fill: parent
                                        
                                        property real wavePhase: 0.0
                                        NumberAnimation on wavePhase {
                                            running: actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                                            loops: Animation.Infinite
                                            from: 0; to: Math.PI * 2; duration: window.pulsePeriod
                                        }
                                        onWavePhaseChanged: requestPaint()
                                        Connections { target: actionCapsule; function onFillLevelChanged() { actionWaveCanvas.requestPaint() } }
                                        
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            if (actionCapsule.fillLevel <= 0.001) return;
                                            
                                            var r = Design.s(14); 
                                            var fillY = height * (1.0 - actionCapsule.fillLevel);
                                            ctx.save();
                                            ctx.beginPath();
                                            ctx.moveTo(r, 0);
                                            ctx.lineTo(width - r, 0);
                                            ctx.arcTo(width, 0, width, r, r);
                                            ctx.lineTo(width, height - r);
                                            ctx.arcTo(width, height, width - r, height, r);
                                            ctx.lineTo(r, height);
                                            ctx.arcTo(0, height, 0, height - r, r);
                                            ctx.lineTo(0, r);
                                            ctx.arcTo(0, 0, r, 0, r);
                                            ctx.closePath();
                                            ctx.clip(); 
                                            
                                            ctx.beginPath();
                                            ctx.moveTo(0, fillY);
                                            if (actionCapsule.fillLevel < 0.99) {
                                                var waveAmp = Design.s(10) * Math.sin(actionCapsule.fillLevel * Math.PI); 
                                                var cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                                                var cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                                                ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                                                ctx.lineTo(width, height);
                                                ctx.lineTo(0, height);
                                            } else {
                                                ctx.lineTo(width, 0);
                                                ctx.lineTo(width, height);
                                                ctx.lineTo(0, height);
                                            }
                                            ctx.closePath();
                                            
                                            var grad = ctx.createLinearGradient(0, 0, 0, height);
                                            grad.addColorStop(0, actionCapsule.c1.toString());
                                            grad.addColorStop(1, actionCapsule.c2.toString());
                                            ctx.fillStyle = grad;
                                            ctx.fill();
                                            ctx.restore();
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent; radius: Design.s(14); color: Design.text
                                        opacity: actionCapsule.flashOpacity
                                        PropertyAnimation on opacity { id: cardFlashAnim; to: 0; duration: Design.duration.slow; easing.type: Easing.OutExpo }
                                    }

                                    Icon {
                                        role: "title"
                                        anchors.centerIn: parent
                                        color: actionMa.containsMouse ? Design.text : Design.textDim
                                        text: icon
                                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                    }

                                    Item {
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                        height: actionCapsule.height * actionCapsule.fillLevel
                                        clip: true
                                        
                                        Icon {
                                            role: "title"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                                            color: Design.ground
                                            text: icon
                                        }
                                    }

                                    Clickable {
                                        id: actionMa
                                        cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onPressed: { 
                                            if (!actionCapsule.triggered) { 
                                                drainAnim.stop(); 
                                                fillAnim.start(); 
                                            }
                                        }
                                        onReleased: {
                                            if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) { 
                                                fillAnim.stop(); 
                                                drainAnim.start(); 
                                            }
                                        }
                                    }

                                    NumberAnimation {
                                        id: fillAnim; target: actionCapsule; property: "fillLevel"; to: 1.0
                                        duration: (550 * weight) * (1.0 - actionCapsule.fillLevel); easing.type: Easing.InSine
                                        onFinished: {
                                            actionCapsule.triggered = true; actionCapsule.flashOpacity = 0.6; cardFlashAnim.start();
                                            exitAnim.start(); exitTimer.start(); // Start graceful exit sequence
                                        }
                                    }
                                    
                                    NumberAnimation {
                                        id: drainAnim; target: actionCapsule; property: "fillLevel"; to: 0.0
                                        duration: window.holdDuration * actionCapsule.fillLevel; easing.type: Easing.OutQuad
                                    }

                                    Timer {
                                        id: exitTimer; interval: 500 
                                        onTriggered: { Quickshell.execDetached(["sh", "-c", cmd]); window.close(); }
                                    }
                                }
                            }
                        }

                        // 3. POWER PROFILES DOCK
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(54)
                            radius: Design.s(14)
                            color: Design.raised 
                            border.color: Design.hover
                            border.width: 1

                            opacity: introProfiles
                            transform: Translate { y: Design.s(20) * (1.0 - introProfiles) }
                            
                            Rectangle {
                                id: sliderPill
                                width: (parent.width - Design.s(2)) / 3 
                                height: parent.height - Design.s(2)
                                y: Design.s(1)
                                radius: Design.s(10)
                                x: {
                                    if (window.powerProfile === "performance") return Design.s(1);
                                    if (window.powerProfile === "balanced") return width + Design.s(1);
                                    return (width * 2) + Design.s(1);
                                }
                                
                                Behavior on x { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                                
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: window.profileStart; Behavior on color { ColorAnimation{duration:400} } }
                                    GradientStop { position: 1.0; color: window.profileEnd; Behavior on color { ColorAnimation{duration:400} } }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Repeater {
                                    model: ListModel {
                                        ListElement { name: "performance"; icon: "󰓅"; label: "Perform" } 
                                        ListElement { name: "balanced"; icon: "󰗑"; label: "Balance" }   
                                        ListElement { name: "power-saver"; icon: "󰌪"; label: "Saver" } 
                                    }
                                    
                                    delegate: Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: Design.s(8)
                                            Icon {
                                                color: window.powerProfile === name ? Design.ground : (profileMa.containsMouse ? Design.text : Design.textDim)
                                                text: icon
                                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                            }
                                            Label {
                                                font.weight: Design.weight.bold
                                                color: window.powerProfile === name ? Design.ground : (profileMa.containsMouse ? Design.text : Design.textDim)
                                                text: label
                                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                            }
                                        }
                                        
                                        Clickable {
                                            id: profileMa
                                            onClicked: { Quickshell.execDetached(["powerprofilesctl", "set", name]); sysPoller.running = true; }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
