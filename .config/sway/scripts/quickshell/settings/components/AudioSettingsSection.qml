import QtQuick
import QtQuick.Layouts
import "." as SettingsUi

SettingsUi.SettingsCard {
    id: section

    property var outputsModel
    property var inputsModel
    property color surface0Color: "#313244"
    property color surface1Color: "#45475a"
    property color surface2Color: "#585b70"
    property color textColor: "#cdd6f4"
    property color mutedColor: "#a6adc8"
    property color outputColor: "#89b4fa"
    property color inputColor: "#fab387"
    property color dangerColor: "#f38ba8"
    signal refreshRequested()
    signal setDefaultRequested(string type, string name)
    signal toggleMuteRequested(string type, string id)

    title: "Audio"
    subtitle: "Default output/input and quick mute controls"
    backgroundColor: Qt.alpha(section.surface0Color, 0.5)
    borderColor: section.surface1Color
    titleColor: section.textColor
    subtitleColor: section.mutedColor

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Outputs"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 11 * section.scaleFactor; color: section.outputColor; Layout.fillWidth: true }
        SettingsUi.PillButton { label: "Refresh"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.surface2Color; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.refreshRequested() }
    }

    Repeater {
        model: section.outputsModel
        delegate: RowLayout {
            Layout.fillWidth: true
            SettingsUi.DeviceRow { title: model.description; subtitle: model.name; value: (model.is_default ? "default  " : "") + (model.mute ? "muted" : model.volume + "%"); scaleFactor: section.scaleFactor; backgroundColor: Qt.alpha(section.surface0Color, 0.7); borderColor: model.is_default ? section.outputColor : section.surface1Color; titleColor: section.textColor; subtitleColor: section.mutedColor; valueColor: model.mute ? section.dangerColor : section.outputColor; Layout.fillWidth: true }
            SettingsUi.PillButton { label: "Default"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.outputColor; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.setDefaultRequested("sink", model.name) }
            SettingsUi.PillButton { label: model.mute ? "Unmute" : "Mute"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.dangerColor; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.toggleMuteRequested("sink", model.id) }
        }
    }

    Text { visible: !section.outputsModel || section.outputsModel.count === 0; text: "No output devices found"; font.family: "JetBrains Mono"; font.pixelSize: 10 * section.scaleFactor; color: section.mutedColor; Layout.fillWidth: true }
    Text { text: "Inputs"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 11 * section.scaleFactor; color: section.inputColor; Layout.fillWidth: true }

    Repeater {
        model: section.inputsModel
        delegate: RowLayout {
            Layout.fillWidth: true
            SettingsUi.DeviceRow { title: model.description; subtitle: model.name; value: (model.is_default ? "default  " : "") + (model.mute ? "muted" : model.volume + "%"); scaleFactor: section.scaleFactor; backgroundColor: Qt.alpha(section.surface0Color, 0.7); borderColor: model.is_default ? section.inputColor : section.surface1Color; titleColor: section.textColor; subtitleColor: section.mutedColor; valueColor: model.mute ? section.dangerColor : section.inputColor; Layout.fillWidth: true }
            SettingsUi.PillButton { label: "Default"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.inputColor; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.setDefaultRequested("source", model.name) }
            SettingsUi.PillButton { label: model.mute ? "Unmute" : "Mute"; scaleFactor: section.scaleFactor; baseColor: section.surface1Color; hoverColor: section.dangerColor; borderColor: section.surface2Color; textColor: section.textColor; onClicked: section.toggleMuteRequested("source", model.id) }
        }
    }
}
