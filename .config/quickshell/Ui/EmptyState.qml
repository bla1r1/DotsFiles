import QtQuick
import QtQuick.Layouts

// =============================================================================
// Centred icon + line + hint, for a list with nothing in it.
//
// The mini-views filled their empty lists with invented devices — "AirPods Pro",
// "FRITZ!Box 5690 TF" — which look real, click like nothing, and are the worst
// possible answer to "what is connected?". This says so instead.
//
//   EmptyState { icon: "\u{f092e}"; title: "Wi-Fi is off"; hint: "Turn it on…" }
// =============================================================================

ColumnLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string hint: ""

    spacing: Design.s(Design.space.xs)

    Icon {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Design.s(Design.space.xs)
        visible: root.icon !== ""
        text: root.icon
        role: "display"
        color: Design.textFaint
    }

    Label {
        Layout.alignment: Qt.AlignHCenter
        text: root.title
        role: "body"
        weight: Design.weight.semibold
        color: Design.textDim
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: Design.s(240)
        visible: root.hint !== ""
        text: root.hint
        role: "caption"
        color: Design.textFaint
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
