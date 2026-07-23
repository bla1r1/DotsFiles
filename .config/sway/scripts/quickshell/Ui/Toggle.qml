import QtQuick
import QtQuick.Layouts

// =============================================================================
// Labelled switch row.
//
// Promoted from settings/components/SettingToggle.qml. Lost: `scaleFactor` and
// five hex colours. The switch geometry follows Design.radius.pill instead of
// three separately-computed radii that had to stay in sync by hand.
// =============================================================================

RowLayout {
    id: row

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    Icon {
        text: row.icon
        visible: text.length > 0
        role: "title"
        color: Design.accent
        Layout.preferredWidth: Design.s(24)
        Layout.alignment: Qt.AlignTop
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Design.s(Design.space.xs)

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: row.label
                weight: Design.weight.semibold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                id: track
                Layout.preferredWidth: Design.s(40)
                Layout.preferredHeight: Design.s(24)
                radius: height / 2
                color: row.checked ? Design.accent : Design.hover

                Behavior on color { ColorAnimation { duration: Design.duration.base } }

                Rectangle {
                    id: knob
                    width: parent.height - Design.s(6)
                    height: width
                    radius: width / 2
                    color: row.checked ? Design.accentText : Design.ground
                    y: Design.s(3)
                    x: row.checked ? parent.width - width - Design.s(3) : Design.s(3)

                    Behavior on x { NumberAnimation { duration: Design.duration.base; easing.type: Design.easing } }
                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                }

                Clickable { onClicked: row.toggled() }
            }
        }

        Label {
            text: row.subtitle
            visible: text.length > 0
            role: "caption"
            dim: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
