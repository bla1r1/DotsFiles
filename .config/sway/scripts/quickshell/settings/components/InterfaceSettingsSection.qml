import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property real uiScale: 1.0
    property int workspaceCount: 10
    property color surface0Color: "#1e1e2e"
    property color surface1Color: "#313244"
    property color surface2Color: "#45475a"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color sapphireColor: "#74c7ec"
    property color yellowColor: "#f9e2af"
    signal uiScaleChangedByUser(real value)
    signal workspaceCountChangedByUser(int value)

    title: "Interface"
    subtitle: "Scale and helper workspace count"
    backgroundColor: Qt.alpha(surface0Color, 0.5)
    borderColor: surface1Color
    titleColor: textColor
    subtitleColor: mutedColor

    SettingsUi.StepperRow {
        label: "UI scale"
        valueText: section.uiScale.toFixed(1) + "x"
        scaleFactor: section.scaleFactor
        accentColor: section.sapphireColor
        surface1Color: section.surface1Color
        surface2Color: section.surface2Color
        textColor: section.textColor
        mutedColor: section.mutedColor
        onDecrement: section.uiScaleChangedByUser(Math.max(0.5, Number((section.uiScale - 0.1).toFixed(1))))
        onIncrement: section.uiScaleChangedByUser(Math.min(2.0, Number((section.uiScale + 0.1).toFixed(1))))
    }

    SettingsUi.StepperRow {
        label: "Workspaces"
        valueText: section.workspaceCount.toString()
        scaleFactor: section.scaleFactor
        accentColor: section.yellowColor
        surface1Color: section.surface1Color
        surface2Color: section.surface2Color
        textColor: section.textColor
        mutedColor: section.mutedColor
        onDecrement: section.workspaceCountChangedByUser(Math.max(1, section.workspaceCount - 1))
        onIncrement: section.workspaceCountChangedByUser(Math.min(20, section.workspaceCount + 1))
    }
}
