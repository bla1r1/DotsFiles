import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property int audioStep: 5
    property int brightnessStep: 5
    property int keyboardBacklightStep: 10
    property bool audioNotifications: true
    signal audioStepChangedByUser(int value)
    signal brightnessStepChangedByUser(int value)
    signal keyboardBacklightStepChangedByUser(int value)
    signal audioNotificationsChangedByUser(bool value)

    title: "Controls"
    subtitle: "Step size for quick actions"

    Stepper {
        label: "Volume step"
        valueText: section.audioStep + "%"
        onDecrement: section.audioStepChangedByUser(Math.max(1, section.audioStep - 1))
        onIncrement: section.audioStepChangedByUser(Math.min(25, section.audioStep + 1))
    }

    Stepper {
        label: "Brightness step"
        valueText: section.brightnessStep + "%"
        onDecrement: section.brightnessStepChangedByUser(Math.max(1, section.brightnessStep - 1))
        onIncrement: section.brightnessStepChangedByUser(Math.min(25, section.brightnessStep + 1))
    }

    Stepper {
        label: "Keyboard light step"
        valueText: section.keyboardBacklightStep + "%"
        onDecrement: section.keyboardBacklightStepChangedByUser(Math.max(1, section.keyboardBacklightStep - 1))
        onIncrement: section.keyboardBacklightStepChangedByUser(Math.min(50, section.keyboardBacklightStep + 1))
    }

    Toggle {
        label: "Audio notifications"
        checked: section.audioNotifications
        onToggled: section.audioNotificationsChangedByUser(!section.audioNotifications)
    }
}
