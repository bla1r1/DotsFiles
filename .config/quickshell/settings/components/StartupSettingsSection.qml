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
    subtitle: "What opens when the session starts"
    icon: "\u{f0459}"
    accentColor: Design.green

    Toggle {
        icon: ""
        label: "Guide on startup"
        subtitle: "Launch on login"
        checked: section.openGuideAtStartup
        onToggled: section.openGuideAtStartupChangedByUser(!section.openGuideAtStartup)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Design.border
        color: Design.tint(Design.line, 0.6)
    }

    Toggle {
        icon: "󰋖"
        label: "Guide shortcut"
        subtitle: "Keeps the guide reachable from the bar and the launcher"
        checked: section.guideShortcut
        onToggled: section.guideShortcutChangedByUser(!section.guideShortcut)
    }
}
