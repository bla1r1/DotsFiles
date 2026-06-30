import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import "../Ui"
import "../Services"

PopupShell {
    id: window


    // -------------------------------------------------------------------------
    // SHORTCUTS & AUDIO
    // -------------------------------------------------------------------------
    Shortcut {
        sequence: "Tab"
        onActivated: {
            if (window.activeTab === "outputs") window.activeTab = "inputs";
            else if (window.activeTab === "inputs") window.activeTab = "apps";
            else window.activeTab = "outputs";
        }
    }

    // -------------------------------------------------------------------------
    // STATE & CONFIG
    // -------------------------------------------------------------------------
    
    property string activeTab: "outputs" // outputs, inputs, apps

    
    // Durations that are choreography, not styling: a staged entrance and
    // ambient loops. Deliberately off the motion scale — see Ui/README.md.
    readonly property int introDuration: 800
    readonly property int introHeaderDuration: 700
    readonly property int tintDuration: 800
    readonly property int orbitPeriod: 1200
    readonly property int driftPeriod: 90000

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: window.driftPeriod; loops: Animation.Infinite; running: true
    }

    // Top Orb Active State Links

    // Audio state lives in Services/Audio — VolumePopup and BatteryPopup used
    // to read volume two different ways and could disagree on screen.
    Component.onCompleted: Audio.acquire()
    Component.onDestruction: Audio.release()

    readonly property var defaultMic: Audio.defaultSource
    readonly property string defaultMicId: defaultMic ? defaultMic.id : ""
    readonly property string defaultMicName: defaultMic ? defaultMic.description : "No Microphone"
    readonly property int defaultMicVol: defaultMic ? defaultMic.volume : 0
    readonly property bool defaultMicMute: defaultMic ? defaultMic.mute : false

    readonly property var activeDevice: window.activeTab === "inputs" ? Audio.defaultSource : Audio.defaultSink
    readonly property string activeId: activeDevice ? activeDevice.id : ""
    readonly property string activeName: activeDevice ? activeDevice.description : "No Device"
    readonly property string activeDesc: activeDevice ? activeDevice.name : ""
    readonly property int activeVol: activeDevice ? activeDevice.volume : 0
    readonly property bool activeMute: activeDevice ? activeDevice.mute : false
    readonly property string activeIcon: activeDevice ? activeDevice.icon : "󰓃"

    readonly property string activeType: window.activeTab === "inputs" ? "source"
                                       : (window.activeTab === "apps" ? "sink-input" : "sink")

    // -------------------------------------------------------------------------
    // ANIMATIONS
    // -------------------------------------------------------------------------
    property real introMain: 0
    property real introHeader: 0
    property real introContent: 0

    ParallelAnimation {
        running: true
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.fast }
            NumberAnimation { target: window; property: "introHeader"; from: 0; to: 1.0; duration: window.introHeaderDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: Design.duration.base }
            NumberAnimation { target: window; property: "introContent"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutExpo }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain
        transform: Translate { y: Design.s(20) * (1 - introMain) }

        Rectangle {
            anchors.fill: parent
            radius: Design.s(20)
            color: Design.surface
            border.color: Design.raised
            border.width: 1
            clip: true

            // Rotating Background Blobs
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * Design.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * Design.s(100)
                opacity: 0.06
                color: Design.accent
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * Design.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * Design.s(-100)
                opacity: 0.04
                color: Qt.lighter(Design.accent, 1.3)
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Design.s(25)
                spacing: Design.s(20)

                // ==========================================
                // HERO ORB & MASTER SLIDER (TOP SECTION)
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(190)
                    opacity: introHeader
                    transform: Translate { y: Design.s(30) * (1.0 - introHeader) }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Design.s(25)

                        // 1. The Orb
                        Item {
                            Layout.preferredWidth: Design.s(130)
                            Layout.preferredHeight: Design.s(130)
                            scale: masterOrbMa.pressed ? 0.95 : (masterOrbMa.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutBack } }

                            // Outermost border pulse ring
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + Design.s(15)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: window.activeMute ? Design.danger : Design.accent
                                border.width: Design.s(3)
                                z: -2

                                property real pulseOp: 0.0
                                property real pulseSc: 1.0
                                opacity: window.activeMute ? 0.0 : pulseOp
                                scale: pulseSc

                                Timer {
                                    interval: 45
                                    running: parent.opacity > 0.01 || !window.activeMute
                                    repeat: true
                                    onTriggered: {
                                        var time = Date.now() / 1000;
                                        parent.pulseOp = 0.3 + Math.sin(time * 2.5) * 0.15;
                                        parent.pulseSc = 1.02 + Math.cos(time * 3.0) * 0.02;
                                    }
                                }
                            }

                            // Solid pulsing background ring
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + Design.s(40)
                                height: width
                                radius: width / 2
                                color: window.activeMute ? Design.danger : Design.accent
                                opacity: window.activeMute ? 0.3 : 0.15
                                z: -1
                                Behavior on color { ColorAnimation { duration: Design.duration.base } }

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite; running: true
                                    NumberAnimation { to: masterOrbMa.containsMouse ? 1.15 : 1.1; duration: masterOrbMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: masterOrbMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                }
                            }

                            // Core Shadow
                            MultiEffect {
                                source: centralCore
                                anchors.fill: centralCore
                                shadowEnabled: true
                                shadowColor: "#000000"
                                shadowOpacity: 0.5
                                shadowBlur: 1.2
                                shadowVerticalOffset: Design.s(6)
                                z: -1
                            }

                            // Core Rectangle
                            Rectangle {
                                id: centralCore
                                anchors.fill: parent
                                radius: width / 2
                                color: Design.surface
                                border.color: window.activeMute ? Design.danger : Qt.lighter(Design.accent, 1.1)
                                border.width: 2
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: Design.duration.base } }

                                // Volume Wave Fill
                                Canvas {
                                    id: orbWave
                                    anchors.fill: parent
                                    
                                    property real wavePhase: 0.0
                                    NumberAnimation on wavePhase {
                                        running: window.activeVol > 0 && window.activeVol < 100
                                        loops: Animation.Infinite
                                        from: 0; to: Math.PI * 2; duration: window.orbitPeriod
                                    }
                                    onWavePhaseChanged: requestPaint()

                                    Connections {
                                        target: window
                                        function onActiveVolChanged() { orbWave.requestPaint() }
                                        function onActiveMuteChanged() { orbWave.requestPaint() }
                                        function onTabColorChanged() { orbWave.requestPaint() }
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        if (window.activeVol <= 0) return;

                                        var fillRatio = window.activeVol / 100.0;
                                        var r = width / 2;
                                        var fillY = height * (1.0 - fillRatio);

                                        ctx.save();
                                        
                                        // 1. Establish the circular clipping mask
                                        ctx.beginPath();
                                        ctx.arc(r, r, r, 0, 2 * Math.PI);
                                        ctx.clip();
                                        
                                        // 2. Draw the actual wave filling
                                        ctx.beginPath();
                                        ctx.moveTo(0, fillY);
                                        
                                        if (fillRatio < 0.99) {
                                            var waveAmp = Design.s(8) * Math.sin(fillRatio * Math.PI); 
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
                                        
                                        // Vibrant gradient matching the network orb
                                        var grad = ctx.createLinearGradient(0, 0, 0, height);
                                        if (window.activeMute) {
                                            grad.addColorStop(0, Qt.lighter(Design.danger, 1.15).toString());
                                            grad.addColorStop(1, Design.danger.toString());
                                        } else {
                                            grad.addColorStop(0, Qt.lighter(Design.accent, 1.15).toString());
                                            grad.addColorStop(1, Design.accent.toString());
                                        }
                                        ctx.fillStyle = grad;
                                        ctx.globalAlpha = 1.0;
                                        ctx.fill();
                                        ctx.restore();
                                    }
                                }

                                // Dual-Layer Text for contrast clipping
                                // 1. Base Text (Visible when empty)
                                Label {
                                    role: "display"
                                    anchors.centerIn: parent
                                    font.weight: Design.weight.bold
                                    color: window.activeMute ? Design.danger : Design.text
                                    text: window.activeMute ? "MUTE" : window.activeVol + "%"
                                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                }

                                // 2. Clipped Text (Dark text that reveals over the wave fill dynamically)
                                Item {
                                    id: waveClipItem
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    // Calculate the exact wave offset at the center of the orb using the Bezier formula
                                    property real fillRatio: window.activeVol / 100.0
                                    property real waveAmp: fillRatio < 0.99 ? Design.s(8) * Math.sin(fillRatio * Math.PI) : 0
                                    property real waveCenterOffset: 0.375 * waveAmp * (Math.sin(orbWave.wavePhase) - Math.cos(orbWave.wavePhase))
                                    property real baseClipHeight: parent.height * fillRatio

                                    height: Math.min(parent.height, Math.max(0, baseClipHeight - waveCenterOffset))
                                    clip: true
                                    visible: window.activeVol > 0

                                    Label {
                                        role: "display"
                                        x: waveClipItem.width / 2 - width / 2
                                        y: (centralCore.height / 2) - (height / 2) - (centralCore.height - waveClipItem.height)
                                        font.weight: Design.weight.bold
                                        color: Design.ground
                                        text: window.activeMute ? "MUTE" : window.activeVol + "%"
                                    }
                                }
                            }

                            Clickable {
                                id: masterOrbMa
                                onClicked: {
                                    let type = window.activeTab === "inputs" ? "source" : "sink";
                                    Audio.toggleMute(type, window.activeId);
                                    Audio.refresh();
                                }
                            }
                        }

                        // 2. Details & Slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Design.s(10)

                            ColumnLayout {
                                spacing: Design.s(2)
                                Label {
                                    role: "title"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.weight: Design.weight.bold
                                    text: window.activeName
                                }
                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    dim: true
                                    text: window.activeTab === "apps" ? "Master Output Volume" : window.activeDesc
                                }
                            }

                            Item { Layout.fillHeight: true } // spacer

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(15)

                                Slider {
                                    Layout.fillWidth: true
                                    value: window.activeVol
                                    tone: Design.accent
                                    muted: window.activeMute

                                    onMoved: pct => {
                                        let type = window.activeTab === "inputs" ? "source" : "sink";
                                        if (pct > 0 && window.activeMute)
                                            Audio.toggleMute(type, window.activeId);
                                        Audio.setVolume(type, window.activeId, pct);
                                    }

                                    onActiveChanged: {
                                        Audio.hold(window.activeId, active);
                                        if (!active) Audio.refresh();
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Design.s(42)
                                radius: Design.s(14)
                                color: Qt.rgba(Design.accentAlt.r, Design.accentAlt.g, Design.accentAlt.b, micRowMa.containsMouse ? 0.16 : 0.09)
                                border.color: Qt.rgba(Design.accentAlt.r, Design.accentAlt.g, Design.accentAlt.b, 0.28)
                                border.width: 1
                                opacity: window.defaultMicId === "" ? 0.55 : 1.0
                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Design.s(12)
                                    anchors.rightMargin: Design.s(12)
                                    spacing: Design.s(10)

                                    Icon {
                                        Layout.preferredWidth: Design.s(24)
                                        horizontalAlignment: Text.AlignHCenter
                                        color: window.defaultMicMute ? Design.danger : Design.accentAlt
                                        text: window.defaultMicMute ? "󰍭" : "󰍬"
                                    }

                                    ColumnLayout {
                                        Layout.preferredWidth: Design.s(118)
                                        spacing: 0
                                        Label {
                                            role: "caption"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            font.weight: Design.weight.semibold
                                            text: "Microphone"
                                        }
                                        Label {
                                            role: "caption"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            dim: true
                                            text: window.defaultMicName
                                        }
                                    }

                                    Slider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(14)
                                        enabled: window.defaultMicId !== ""

                                        value: window.defaultMicVol
                                        tone: Design.accentAlt
                                        muted: window.defaultMicMute
                                        cornerRadius: Design.radius.ctl

                                        onMoved: pct => {
                                            if (pct > 0 && window.defaultMicMute)
                                                Audio.toggleMute("source", window.defaultMicId);
                                            Audio.setVolume("source", window.defaultMicId, pct);
                                        }

                                        onActiveChanged: {
                                            Audio.hold("__default_mic", active);
                                            if (!active) Audio.refresh();
                                        }
                                    }

                                    Label {
                                        role: "caption"
                                        Layout.preferredWidth: Design.s(36)
                                        horizontalAlignment: Text.AlignRight
                                        font.weight: Design.weight.semibold
                                        dim: true
                                        text: window.defaultMicVol + "%"
                                    }
                                }

                                Clickable {
                                    id: micRowMa
                                    acceptedButtons: Qt.RightButton
                                    cursorShape: window.defaultMicId !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (window.defaultMicId === "") return;
                                        Audio.toggleMute("source", window.defaultMicId);
                                        Audio.refresh();
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // TABS
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(54)
                    radius: Design.s(14)
                    color: Design.veil 
                    border.color: Design.veilStrong
                    border.width: 1
                    opacity: introHeader
                    transform: Translate { y: Design.s(20) * (1.0 - introHeader) }

                    Rectangle {
                        width: (parent.width - Design.s(2)) / 3 
                        height: parent.height - Design.s(2)
                        y: Design.s(1)
                        radius: Design.s(10)
                        x: {
                            if (window.activeTab === "outputs") return Design.s(1);
                            if (window.activeTab === "inputs") return width + Design.s(1);
                            return (width * 2) + Design.s(1);
                        }
                        Behavior on x { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Design.accent; Behavior on color { ColorAnimation { duration: Design.duration.slow } } }
                            GradientStop { position: 1.0; color: Qt.lighter(Design.accent, 1.15); Behavior on color { ColorAnimation { duration: Design.duration.slow } } }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Repeater {
                            model: ListModel {
                                ListElement { tabId: "outputs"; icon: "󰓃"; label: "Outputs" } 
                                ListElement { tabId: "inputs"; icon: "󰍬"; label: "Inputs" }   
                                ListElement { tabId: "apps"; icon: "󰎆"; label: "Streams" } 
                            }
                            
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Design.s(8)
                                    Icon {
                                        color: window.activeTab === tabId ? Design.ground : (tabMa.containsMouse ? Design.text : Design.textDim)
                                        text: icon
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    }
                                    Label {
                                        font.weight: Design.weight.bold
                                        color: window.activeTab === tabId ? Design.ground : (tabMa.containsMouse ? Design.text : Design.textDim)
                                        text: label
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    }
                                }
                                
                                Clickable {
                                    id: tabMa
                                    onClicked: {
                                        window.activeTab = tabId;
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // LIST VIEW CONTENT
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: introContent
                    transform: Translate { y: Design.s(20) * (1.0 - introContent) }

                    ListView {
                        id: contentList
                        anchors.fill: parent
                        spacing: Design.s(12)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // Elegant sliding transitions when models rearrange
                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Design.duration.slow; easing.type: Easing.OutQuint }
                            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Design.duration.slow; easing.type: Easing.OutBack }
                        }
                        displaced: Transition {
                            SpringAnimation { property: "y"; spring: 3; damping: 0.2; mass: 0.2 }
                        }

                        model: {
                            if (window.activeTab === "outputs") return Audio.outputs;
                            if (window.activeTab === "inputs") return Audio.inputs;
                            return Audio.apps;
                        }

                        Item {
                            width: contentList.width; height: contentList.height
                            visible: contentList.count === 0
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Design.s(10)
                                Icon { role: "display"; Layout.alignment: Qt.AlignHCenter; color: Design.active; text: "󰖁" }
                                Label { Layout.alignment: Qt.AlignHCenter; color: Design.textFaint; text: "No active streams" }
                            }
                        }

                        delegate: Rectangle {
                            id: delegateRoot
                            width: contentList.width
                            
                            // Staggered Intro Animation Timer
                            property bool isLoaded: false
                            Timer {
                                running: true
                                interval: 40 + (index * 40)
                                onTriggered: delegateRoot.isLoaded = true
                            }

                            // Intro transforms
                            opacity: isLoaded ? 1.0 : 0.0
                            transform: Translate { y: isLoaded ? 0 : Design.s(15) }
                            Behavior on opacity { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }
                            Behavior on transform { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }

                            // Dynamic Height: The active hero element collapses its bottom slider row
                            property bool isActiveNode: model.is_default && window.activeTab !== "apps"
                            height: isActiveNode ? Design.s(60) : Design.s(100)
                            Behavior on height { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }

                            radius: Design.s(14)
                            
                            property bool isHovered: cardMa.containsMouse && !isActiveNode

                            color: isActiveNode ? Design.accent : (isHovered ? Design.veilStrong : Design.veil)
                            border.color: isActiveNode ? Design.accent : Design.veilStrong
                            border.width: isActiveNode ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                            Behavior on color { ColorAnimation { duration: Design.duration.base } }

                            // Full card selection listener
                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: window.activeTab !== "apps"
                                cursorShape: window.activeTab !== "apps" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (window.activeTab !== "apps" && !model.is_default) {
                                        let type = window.activeTab === "outputs" ? "sink" : "source";
                                        Audio.setDefault(type, model.name);
                                        Audio.refresh();
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Design.s(16)
                                anchors.rightMargin: Design.s(16)
                                anchors.topMargin: Design.s(12)
                                anchors.bottomMargin: isActiveNode ? Design.s(12) : Design.s(16) // Prevent slider crowding bottom bounds
                                spacing: Design.s(12)

                                // Top row: Text info and Icon
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Design.s(12)

                                    Icon {
                                        role: "title"
                                        color: isActiveNode ? Design.ground : Design.text
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                        text: {
                                            if (window.activeTab === "inputs") return "󰍬";
                                            if (window.activeTab === "apps") return "󰎆";
                                            if (model.description.toLowerCase().indexOf("headset") !== -1 || model.description.toLowerCase().indexOf("headphones") !== -1) return "󰋎";
                                            return "󰓃";
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Design.s(2)
                                        Label {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            font.weight: Design.weight.semibold
                                            color: isActiveNode ? Design.ground : Design.text
                                            text: model.description
                                        }
                                        Label {
                                            role: "caption"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            color: isActiveNode ? Qt.darker(Design.ground, 1.5) : Design.textDim
                                            text: isActiveNode ? "Active Default" : model.name
                                        }
                                    }
                                }

                                // Bottom row: Custom Slider & Mute (Hides if it's the active node)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Design.s(15)
                                    visible: !isActiveNode
                                    opacity: isActiveNode ? 0.0 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: Design.duration.base } }

                                    Rectangle {
                                        Layout.preferredWidth: Design.s(32); Layout.preferredHeight: Design.s(32); radius: Design.s(16)
                                        color: muteMa.containsMouse ? Design.veilStrong : "transparent"
                                        border.color: muteMa.containsMouse ? (model.mute ? Design.textFaint : Design.accent) : "transparent"
                                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                                        Icon {
                                            anchors.centerIn: parent
                                            color: model.mute ? Design.textFaint : Design.textDim
                                            text: model.mute || model.volume === 0 ? "󰖁" : (model.volume > 50 ? "󰕾" : "󰖀")
                                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                        }
                                        Clickable {
                                            id: muteMa
                                            onClicked: {
                                                let type = "sink";
                                                if (window.activeTab === "inputs") type = "source";
                                                if (window.activeTab === "apps") type = "sink-input";
                                                Audio.toggleMute(type, model.id);
                                                Audio.refresh();
                                            }
                                        }
                                    }

                                    Slider {
                                        id: deviceSlider
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(14)   // thinner than master, for hierarchy

                                        value: model.volume
                                        tone: Design.accent
                                        muted: model.mute
                                        cornerRadius: Design.radius.ctl

                                        onMoved: pct => {
                                            let type = "sink";
                                            if (window.activeTab === "inputs") type = "source";
                                            if (window.activeTab === "apps") type = "sink-input";

                                            let targetList = window.activeTab === "outputs" ? Audio.outputs : (window.activeTab === "inputs" ? Audio.inputs : Audio.apps);
                                            for (let i = 0; i < targetList.count; i++) {
                                                if (targetList.get(i).id === model.id) {
                                                    targetList.setProperty(i, "volume", pct);
                                                    break;
                                                }
                                            }

                                            if (pct > 0 && model.mute)
                                                Audio.toggleMute(type, model.id);
                                            Audio.setVolume(type, model.id, pct);
                                        }

                                        onActiveChanged: {
                                            Audio.hold(model.id, active);
                                            if (!active) Audio.refresh();
                                        }
                                    }

                                    Label {
                                        role: "caption"
                                        Layout.preferredWidth: Design.s(35)
                                        font.weight: Design.weight.semibold
                                        dim: true
                                        text: deviceSlider.shown + "%"
                                        horizontalAlignment: Text.AlignRight
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
