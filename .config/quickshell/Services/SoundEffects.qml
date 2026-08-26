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
        Quickshell.execDetached([
            "bash", "-c",
            "canberra-gtk-play -i " + soundName + " 2>/dev/null || " +
            "pw-play /usr/share/sounds/freedesktop/stereo/" + soundName + ".oga 2>/dev/null || " +
            "paplay /usr/share/sounds/freedesktop/stereo/" + soundName + ".oga 2>/dev/null || true"
        ]);
    }

    function playScreenshot() { root.play("camera-shutter"); }
    function playColorPicker() { root.play("dialog-information"); }
    function playVolume() { root.play("audio-volume-change"); }
    function playNotification() { root.play("message"); }
    function playTrash() { root.play("trash-empty"); }
    function playPlug() { root.play("device-added"); }
}
