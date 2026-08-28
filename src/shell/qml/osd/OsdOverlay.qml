import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../Ui"

// =============================================================================
// On-Screen Display (OSD) Overlay
//
// Shows volume, microphone, and screen brightness changes with smooth animations.
// =============================================================================

PanelWindow {
    id: osdWindow
    color: "transparent"

    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    
    screen: Quickshell.screens[0]

    anchors.top: false
    anchors.right: false
    anchors.bottom: true
    anchors.left: false

    implicitWidth: osdCard.implicitWidth + Design.s(32)
    implicitHeight: osdCard.implicitHeight + Design.s(90)

    visible: osdOpacity > 0.0

    property real osdOpacity: 0.0
    property string osdIcon: "\u{f057e}"
    property string osdTitle: "Volume"
    property int osdValue: 0
    property bool osdMuted: false
    property color osdColor: Design.sapphire

    // Flag to ignore initial bindings on startup
    property bool _ready: false

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: {
            osdWindow.osdOpacity = 0.0;
        }
    }

    function showOsd(icon, title, value, muted, color) {
        if (!osdWindow._ready) return;
        osdWindow.osdIcon = icon;
        osdWindow.osdTitle = title;
        osdWindow.osdValue = Math.max(0, Math.min(100, Math.round(value)));
        osdWindow.osdMuted = muted;
        osdWindow.osdColor = color || Design.sapphire;
        osdWindow.osdOpacity = 1.0;
        hideTimer.restart();
    }

    // ── Track Volume Changes ─────────────────────────────────────────────────
    readonly property var currentSink: Pipewire.defaultAudioSink
    readonly property real currentVol: currentSink && currentSink.audio ? currentSink.audio.volume : 0
    readonly property bool currentMute: currentSink && currentSink.audio ? currentSink.audio.muted : false

    onCurrentVolChanged: {
        if (!osdWindow._ready) return;
        let v = Math.round(currentVol * 100);
        let ic = "\u{f057e}";
        if (currentMute || v === 0) ic = "\u{f0581}";
        else if (v < 35) ic = "\u{f057f}";
        else if (v < 70) ic = "\u{f0580}";
        showOsd(ic, "Volume", v, currentMute, currentMute ? Design.red : Design.sapphire);
    }

    onCurrentMuteChanged: {
        if (!osdWindow._ready) return;
        let v = Math.round(currentVol * 100);
        let ic = currentMute ? "\u{f0581}" : "\u{f057e}";
        showOsd(ic, currentMute ? "Muted" : "Volume", v, currentMute, currentMute ? Design.red : Design.sapphire);
    }

    // ── Track Microphone Changes ─────────────────────────────────────────────
    readonly property var currentSource: Pipewire.defaultAudioSource
    readonly property real currentMicVol: currentSource && currentSource.audio ? currentSource.audio.volume : 0
    readonly property bool currentMicMute: currentSource && currentSource.audio ? currentSource.audio.muted : false

    onCurrentMicVolChanged: {
        if (!osdWindow._ready) return;
        let v = Math.round(currentMicVol * 100);
        let ic = currentMicMute ? "\u{f036d}" : "\u{f036c}";
        showOsd(ic, "Microphone", v, currentMicMute, currentMicMute ? Design.red : Design.peach);
    }

    onCurrentMicMuteChanged: {
        if (!osdWindow._ready) return;
        let v = Math.round(currentMicVol * 100);
        let ic = currentMicMute ? "\u{f036d}" : "\u{f036c}";
        showOsd(ic, currentMicMute ? "Mic Muted" : "Microphone", v, currentMicMute, currentMicMute ? Design.red : Design.peach);
    }

    Timer {
        interval: 1000
        repeat: false
        running: true
        onTriggered: {
            osdWindow._ready = true;
        }
    }

    // ── OSD Card UI ──────────────────────────────────────────────────────────
    Rectangle {
        id: osdCard
        opacity: osdWindow.osdOpacity
        scale: osdWindow.osdOpacity > 0 ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        implicitWidth: Design.s(260)
        implicitHeight: Design.s(60)

        radius: Design.s(30)
        color: Design.ground
        border.color: Design.glassBorder
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Design.s(16)
            anchors.rightMargin: Design.s(18)
            spacing: Design.s(12)

            // Icon circle
            Rectangle {
                Layout.preferredWidth: Design.s(36)
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(18)
                color: Design.surface

                Icon {
                    anchors.centerIn: parent
                    text: osdWindow.osdIcon
                    color: osdWindow.osdColor
                    role: "body"
                }
            }

            // Label & Bar Column
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(4)

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: osdWindow.osdTitle
                        weight: Design.weight.semibold
                        role: "caption"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: osdWindow.osdMuted ? "MUTED" : (osdWindow.osdValue + "%")
                        weight: Design.weight.bold
                        role: "caption"
                        color: osdWindow.osdMuted ? Design.red : Design.text
                    }
                }

                // Progress Level Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(6)
                    radius: Design.s(3)
                    color: Design.sunken

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: osdWindow.osdMuted ? 0 : (parent.width * (osdWindow.osdValue / 100.0))
                        radius: Design.s(3)
                        color: osdWindow.osdColor

                        Behavior on width {
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
