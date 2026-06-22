import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property int dimTimeout: 300
    property int lockTimeout: 600
    property int dpmsTimeout: 900
    property int suspendTimeout: 1200
    property bool dimOnLock: true
    property bool autoSuspend: false
    property color surface0Color: "#1e1e2e"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color baseColor: "#11111b"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color peachColor: "#fab387"
    signal dimTimeoutChangedByUser(int value)
    signal lockTimeoutChangedByUser(int value)
    signal dpmsTimeoutChangedByUser(int value)
    signal suspendTimeoutChangedByUser(int value)
    signal dimOnLockChangedByUser(bool value)
    signal autoSuspendChangedByUser(bool value)

    title: "Lock & idle"
    subtitle: "Timeouts are in seconds"
    backgroundColor: Qt.alpha(surface0Color, 0.5)
    borderColor: surface1Color
    titleColor: textColor
    subtitleColor: mutedColor

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12 * section.scaleFactor
        rowSpacing: 10 * section.scaleFactor

        Text { text: "Dim"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor }
        TextInput {
            text: section.dimTimeout.toString()
            color: section.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: 12 * section.scaleFactor
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.dimTimeoutChangedByUser(parseInt(text || "300"))
        }

        Text { text: "Lock"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor }
        TextInput {
            text: section.lockTimeout.toString()
            color: section.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: 12 * section.scaleFactor
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.lockTimeoutChangedByUser(parseInt(text || "600"))
        }

        Text { text: "DPMS"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor }
        TextInput {
            text: section.dpmsTimeout.toString()
            color: section.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: 12 * section.scaleFactor
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.dpmsTimeoutChangedByUser(parseInt(text || "900"))
        }

        Text { text: "Suspend"; color: section.mutedColor; font.family: "JetBrains Mono"; font.pixelSize: 11 * section.scaleFactor }
        TextInput {
            text: section.suspendTimeout.toString()
            enabled: section.autoSuspend
            opacity: section.autoSuspend ? 1.0 : 0.4
            color: section.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: 12 * section.scaleFactor
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.suspendTimeoutChangedByUser(parseInt(text || "1200"))
        }
    }

    SettingsUi.SettingToggle {
        label: "Dim while locking"
        checked: section.dimOnLock
        scaleFactor: section.scaleFactor
        accentColor: section.peachColor
        surface2Color: section.surface2Color
        baseColor: section.baseColor
        textColor: section.textColor
        mutedColor: section.mutedColor
        onToggled: section.dimOnLockChangedByUser(!section.dimOnLock)
    }

    SettingsUi.SettingToggle {
        label: "Auto suspend"
        checked: section.autoSuspend
        scaleFactor: section.scaleFactor
        accentColor: section.peachColor
        surface2Color: section.surface2Color
        baseColor: section.baseColor
        textColor: section.textColor
        mutedColor: section.mutedColor
        onToggled: section.autoSuspendChangedByUser(!section.autoSuspend)
    }
}
