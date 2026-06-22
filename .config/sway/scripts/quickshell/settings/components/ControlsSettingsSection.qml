import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property int audioStep: 5
    property int brightnessStep: 5
    property int keyboardBacklightStep: 10
    property bool audioNotifications: true
    property color surface0Color: "#1e1e2e"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color baseColor: "#11111b"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color blueColor: "#89b4fa"
    property color yellowColor: "#f9e2af"
    property color greenColor: "#a6e3a1"
    property color mauveColor: "#cba6f7"
    signal audioStepChangedByUser(int value)
    signal brightnessStepChangedByUser(int value)
    signal keyboardBacklightStepChangedByUser(int value)
    signal audioNotificationsChangedByUser(bool value)

    title: "Controls"
    subtitle: "Step size for quick actions"
    backgroundColor: Qt.alpha(surface0Color, 0.5)
    borderColor: surface1Color
    titleColor: textColor
    subtitleColor: mutedColor

    SettingsUi.StepperRow {
        label: "Volume step"
        valueText: section.audioStep + "%"
        scaleFactor: section.scaleFactor
        accentColor: section.blueColor
        surface1Color: section.surface1Color
        surface2Color: section.surface2Color
        textColor: section.textColor
        mutedColor: section.mutedColor
        onDecrement: section.audioStepChangedByUser(Math.max(1, section.audioStep - 1))
        onIncrement: section.audioStepChangedByUser(Math.min(25, section.audioStep + 1))
    }

    SettingsUi.StepperRow {
        label: "Brightness step"
        valueText: section.brightnessStep + "%"
        scaleFactor: section.scaleFactor
        accentColor: section.yellowColor
        surface1Color: section.surface1Color
        surface2Color: section.surface2Color
        textColor: section.textColor
        mutedColor: section.mutedColor
        onDecrement: section.brightnessStepChangedByUser(Math.max(1, section.brightnessStep - 1))
        onIncrement: section.brightnessStepChangedByUser(Math.min(25, section.brightnessStep + 1))
    }

    SettingsUi.StepperRow {
        label: "Keyboard light step"
        valueText: section.keyboardBacklightStep + "%"
        scaleFactor: section.scaleFactor
        accentColor: section.greenColor
        surface1Color: section.surface1Color
        surface2Color: section.surface2Color
        textColor: section.textColor
        mutedColor: section.mutedColor
        onDecrement: section.keyboardBacklightStepChangedByUser(Math.max(1, section.keyboardBacklightStep - 1))
        onIncrement: section.keyboardBacklightStepChangedByUser(Math.min(50, section.keyboardBacklightStep + 1))
    }

    SettingsUi.SettingToggle {
        label: "Audio notifications"
        checked: section.audioNotifications
        scaleFactor: section.scaleFactor
        accentColor: section.mauveColor
        surface2Color: section.surface2Color
        baseColor: section.baseColor
        textColor: section.textColor
        mutedColor: section.mutedColor
        onToggled: section.audioNotificationsChangedByUser(!section.audioNotifications)
    }
}
