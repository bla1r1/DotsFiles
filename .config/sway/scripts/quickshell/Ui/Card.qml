import QtQuick
import QtQuick.Layouts

// =============================================================================
// Titled card on a panel.
//
// Promoted from settings/components/SettingsCard.qml, where it was invisible to
// every popup but the settings one. Lost on the way: a threaded `scaleFactor`
// property and five hardcoded hex colours.
//
//   Card {
//       title: "Раскладка"
//       Toggle { label: "Основной экран"; checked: true }
//   }
// =============================================================================

Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    default property alias content: body.data

    Layout.fillWidth: true
    Layout.preferredHeight: contentColumn.implicitHeight + Design.s(Design.space.xl + Design.space.xs)

    radius: Design.s(Design.radius.card)
    color: Design.raised
    border.color: Design.line
    border.width: Design.border

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Design.s(Design.space.lg)
        spacing: Design.s(Design.space.md)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)
            visible: card.title.length > 0 || card.subtitle.length > 0

            Label {
                text: card.title
                visible: text.length > 0
                weight: Design.weight.semibold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Label {
                text: card.subtitle
                visible: text.length > 0
                role: "caption"
                dim: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)
        }
    }
}
