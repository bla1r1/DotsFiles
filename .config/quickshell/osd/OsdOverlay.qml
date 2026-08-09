import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Ui"
import "../Services"

// =============================================================================
// On-Screen Display (OSD) Overlay
//
// Floating pill for Volume, Brightness, Microphone, and Keyboard Backlight
// =============================================================================

PanelWindow {
    id: osdWindow

    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors {
        bottom: true
    }
    margins {
        bottom: Design.s(80)
    }

    implicitWidth: Design.s(320)
    implicitHeight: Design.s(54)
    color: "transparent"

    property string osdIcon: "\u{f028}"
    property string osdLabel: "Volume"
    property real osdValue: 0.0 // 0.0 to 1.0
    property color osdColor: Design.accent
    property bool osdVisible: false

    // Auto-hide timer: stays up for 1.8s after the last change
    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: osdWindow.osdVisible = false
    }

    function triggerOsd(icon, label, val, tone) {
        osdWindow.osdIcon = icon;
        osdWindow.osdLabel = label;
        osdWindow.osdValue = Math.max(0.0, Math.min(1.0, val));
        osdWindow.osdColor = tone || Design.accent;
        osdWindow.osdVisible = true;
        hideTimer.restart();
    }

    // ── Watch Audio Volume ───────────────────────────────────────────────────
    property real _lastVol: Audio.sink ? Audio.sink.volume : 0.0
    property bool _lastMute: Audio.sink ? Audio.sink.muted : false
    property bool _audioInit: false

    Connections {
        target: Audio.sink || null
        function onVolumeChanged() {
            if (!_audioInit) { _audioInit = true; return; }
            const v = Audio.sink.volume;
            const m = Audio.sink.muted;
            const icon = m ? "\u{f026}" : (v > 0.6 ? "\u{f028}" : (v > 0.2 ? "\u{f027}" : "\u{f026}"));
            triggerOsd(icon, m ? "Muted" : "Volume", m ? 0.0 : v, m ? Design.red : Design.teal);
        }
        function onMutedChanged() {
            if (!_audioInit) { _audioInit = true; return; }
            const m = Audio.sink.muted;
            const v = Audio.sink.volume;
            const icon = m ? "\u{f026}" : "\u{f028}";
            triggerOsd(icon, m ? "Muted" : "Volume", m ? 0.0 : v, m ? Design.red : Design.teal);
        }
    }

    // ── Watch Screen Brightness ──────────────────────────────────────────────
    property bool _brightInit: false
    Connections {
        target: Power
        function onBrightnessChanged() {
            if (!_brightInit) { _brightInit = true; return; }
            triggerOsd("\u{f0599}", "Brightness", Power.brightness, Design.yellow);
        }
    }

    // ── Visual Surface ───────────────────────────────────────────────────────
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Design.s(Design.radius.popup)
        color: Design.ground
        border.color: Design.raised
        border.width: 1
        clip: true

        opacity: osdWindow.osdVisible ? 1.0 : 0.0
        scale: osdWindow.osdVisible ? 1.0 : 0.92
        transformOrigin: Item.Center

        Behavior on opacity { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutBack } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Design.s(Design.space.md)
            spacing: Design.s(Design.space.md)

            Icon {
                text: osdWindow.osdIcon
                role: "title"
                color: osdWindow.osdColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(4)

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: osdWindow.osdLabel
                        weight: Design.weight.semibold
                        role: "caption"
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: Math.round(osdWindow.osdValue * 100) + "%"
                        weight: Design.weight.bold
                        role: "caption"
                        color: osdWindow.osdColor
                    }
                }

                // Progress track
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(6)
                    radius: Design.s(3)
                    color: Design.sunken

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * osdWindow.osdValue
                        radius: Design.s(3)
                        color: osdWindow.osdColor
                        Behavior on width { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
