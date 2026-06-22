import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property bool openGuideAtStartup: false
    property bool guideShortcut: false
    property color surface0Color: "#1e1e2e"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color baseColor: "#11111b"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color peachColor: "#fab387"
    property color blueColor: "#89b4fa"
    signal openGuideAtStartupChangedByUser(bool value)
    signal guideShortcutChangedByUser(bool value)

    title: "Startup"
    subtitle: "Guide and launcher behavior"
    backgroundColor: Qt.alpha(surface0Color, 0.5)
    borderColor: surface1Color
    titleColor: textColor
    subtitleColor: mutedColor

    SettingsUi.SettingToggle {
        icon: ""
        label: "Guide on startup"
        subtitle: "Launch on login"
        checked: section.openGuideAtStartup
        scaleFactor: section.scaleFactor
        accentColor: section.peachColor
        surface2Color: section.surface2Color
        baseColor: section.baseColor
        textColor: section.textColor
        mutedColor: section.mutedColor
        onToggled: section.openGuideAtStartupChangedByUser(!section.openGuideAtStartup)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.alpha(section.surface1Color, 0.5)
    }

    SettingsUi.SettingToggle {
        icon: "󰋖"
        label: "Guide shortcut"
        subtitle: "Reserved for Waybar/Quickshell launchers"
        checked: section.guideShortcut
        scaleFactor: section.scaleFactor
        accentColor: section.blueColor
        surface2Color: section.surface2Color
        baseColor: section.baseColor
        textColor: section.textColor
        mutedColor: section.mutedColor
        onToggled: section.guideShortcutChangedByUser(!section.guideShortcut)
    }
}
