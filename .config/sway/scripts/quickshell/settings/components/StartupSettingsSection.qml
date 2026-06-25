import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property bool openGuideAtStartup: false
    property bool guideShortcut: false
    signal openGuideAtStartupChangedByUser(bool value)
    signal guideShortcutChangedByUser(bool value)

    title: "Startup"
    subtitle: "Guide and launcher behavior"

    Toggle {
        icon: ""
        label: "Guide on startup"
        subtitle: "Launch on login"
        checked: section.openGuideAtStartup
        onToggled: section.openGuideAtStartupChangedByUser(!section.openGuideAtStartup)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.alpha(Design.raised, 0.5)
    }

    Toggle {
        icon: "󰋖"
        label: "Guide shortcut"
        subtitle: "Reserved for Waybar/Quickshell launchers"
        checked: section.guideShortcut
        onToggled: section.guideShortcutChangedByUser(!section.guideShortcut)
    }
}
