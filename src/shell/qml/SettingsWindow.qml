import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import "Ui"
import "Services"
import "settings"
import Quickshell

Window {
    id: window
    title: "System Settings"
    width: Design.s(960)
    height: Design.s(640)
    minimumWidth: Design.s(760)
    minimumHeight: Design.s(500)
    visible: true
    color: "transparent"

    property string initialPage: {
        try {
            if (typeof Quickshell !== "undefined" && Quickshell.env("INITIAL_SETTINGS_PAGE")) {
                return Quickshell.env("INITIAL_SETTINGS_PAGE");
            }
        } catch (e) {}
        if (typeof InitialSettingsPage !== "undefined" && InitialSettingsPage !== "") {
            return InitialSettingsPage;
        }
        return "monitors";
    }

    onClosing: Qt.quit()

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: (window.visibility === Window.Maximized) ? 0 : Design.s(14)
        color: Design.base
        border.color: (window.visibility === Window.Maximized) ? "transparent" : Design.glassBorder
        border.width: 1
        clip: true

        SettingsApp {
            id: settings
            anchors.fill: parent
            framed: false
            page: window.initialPage !== "" ? window.initialPage : "monitors"
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: window.close()
    }
}
