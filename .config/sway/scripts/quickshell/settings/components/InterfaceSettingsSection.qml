import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property real uiScale: 1.0
    property int workspaceCount: 10
    signal uiScaleChangedByUser(real value)
    signal workspaceCountChangedByUser(int value)

    title: "Interface"
    subtitle: "Scale and helper workspace count"

    Stepper {
        label: "UI scale"
        valueText: section.uiScale.toFixed(1) + "x"
        onDecrement: section.uiScaleChangedByUser(Math.max(0.5, Number((section.uiScale - 0.1).toFixed(1))))
        onIncrement: section.uiScaleChangedByUser(Math.min(2.0, Number((section.uiScale + 0.1).toFixed(1))))
    }

    Stepper {
        label: "Workspaces"
        valueText: section.workspaceCount.toString()
        onDecrement: section.workspaceCountChangedByUser(Math.max(1, section.workspaceCount - 1))
        onIncrement: section.workspaceCountChangedByUser(Math.min(20, section.workspaceCount + 1))
    }
}
