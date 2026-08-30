pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Sound Effects & Desktop Audio Feedback Service
// =============================================================================

Singleton {
    id: root

    property bool enabled: true

    function play(soundName) {
        if (!root.enabled) return;
        const allowed = ["camera-shutter", "dialog-information", "audio-volume-change", "message", "trash-empty", "device-added", "action"];
        if (!allowed.includes(soundName)) return;
        Quickshell.execDetached(["canberra-gtk-play", "-i", soundName]);
    }

    function playScreenshot() { root.play("camera-shutter"); }
    function playColorPicker() { root.play("dialog-information"); }
    function playVolume() { root.play("audio-volume-change"); }
    function playNotification() { root.play("message"); }
    function playTrash() { root.play("trash-empty"); }
    function playPlug() { root.play("device-added"); }
}
