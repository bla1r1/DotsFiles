import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property var outputsModel
    property var inputsModel
    signal refreshRequested()
    signal setDefaultRequested(string type, string name)
    signal toggleMuteRequested(string type, string id)

    title: "Audio"
    subtitle: "Default output/input and quick mute controls"

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Outputs"; font.family: Design.font.mono; font.weight: Design.weight.semibold; font.pixelSize: Design.s(11); color: Design.accent; Layout.fillWidth: true }
        Pill { label: "Refresh"; onClicked: section.refreshRequested() }
    }

    Repeater {
        model: section.outputsModel
        delegate: RowLayout {
            Layout.fillWidth: true
            DeviceRow { title: model.description; subtitle: model.name; value: (model.is_default ? "default  " : "") + (model.mute ? "muted" : model.volume + "%"); valueTone: model.mute ? Design.danger : Design.accent; Layout.fillWidth: true }
            Pill { label: "Default"; onClicked: section.setDefaultRequested("sink", model.name) }
            Pill { label: model.mute ? "Unmute" : "Mute"; onClicked: section.toggleMuteRequested("sink", model.id) }
        }
    }

    Text { visible: !section.outputsModel || section.outputsModel.count === 0; text: "No output devices found"; font.family: Design.font.mono; font.pixelSize: Design.s(10); color: Design.textDim; Layout.fillWidth: true }
    Text { text: "Inputs"; font.family: Design.font.mono; font.weight: Design.weight.semibold; font.pixelSize: Design.s(11); color: Design.warn; Layout.fillWidth: true }

    Repeater {
        model: section.inputsModel
        delegate: RowLayout {
            Layout.fillWidth: true
            DeviceRow { title: model.description; subtitle: model.name; value: (model.is_default ? "default  " : "") + (model.mute ? "muted" : model.volume + "%"); valueTone: model.mute ? Design.danger : Design.warn; Layout.fillWidth: true }
            Pill { label: "Default"; onClicked: section.setDefaultRequested("source", model.name) }
            Pill { label: model.mute ? "Unmute" : "Mute"; onClicked: section.toggleMuteRequested("source", model.id) }
        }
    }
}
