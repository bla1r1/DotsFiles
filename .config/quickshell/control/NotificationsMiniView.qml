import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Ui"
import "../Services"

// =============================================================================
// Notifications Mini View (Control Center Subpage)
// =============================================================================

Item {
    id: root

    signal backClicked()

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)

        // ── 1. Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            IconButton {
                icon: "\u{f0141}" // back arrow
                bordered: true
                onClicked: root.backClicked()
            }

            Label {
                text: "Notifications"
                role: "subhead"
                weight: Design.weight.bold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            ActionButton {
                visible: Notifications.history.count > 0
                icon: "\u{f0156}"
                label: "Clear"
                onActivated: Notifications.clearAllHistory()
            }
        }

        // ── 2. DND Toggle Bar ────────────────────────────────────────────────
        Card {
            Layout.fillWidth: true

            Toggle {
                label: "Do Not Disturb"
                subtitle: "Silence popups and store them in history"
                checked: Notifications.dnd
                onToggled: Notifications.toggleDnd()
            }
        }

        // ── 3. Notification History List ─────────────────────────────────────
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Design.s(Design.space.xs)
            model: Notifications.history

            delegate: Rectangle {
                id: notifItem
                required property var model
                required property int index

                width: ListView.view ? ListView.view.width : 0
                implicitHeight: itemRow.implicitHeight + Design.s(Design.space.sm)
                radius: Design.s(Design.radius.card)
                color: Design.glassCard
                border.color: Design.glassBorder
                border.width: 1

                RowLayout {
                    id: itemRow
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.sm)

                    Rectangle {
                        width: Design.s(32)
                        height: width
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        Layout.alignment: Qt.AlignTop

                        Icon {
                            anchors.centerIn: parent
                            text: notifItem.model.icon ? notifItem.model.icon : "\u{f009a}"
                            role: "caption"
                            color: Design.sapphire
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: notifItem.model.appName
                                role: "caption"
                                dim: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: notifItem.model.time
                                role: "caption"
                                dim: true
                            }
                        }

                        Label {
                            text: notifItem.model.summary
                            weight: Design.weight.semibold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: notifItem.model.body !== ""
                            text: notifItem.model.body
                            role: "caption"
                            dim: true
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    IconButton {
                        icon: "\u{f0156}"
                        role: "caption"
                        Layout.alignment: Qt.AlignTop
                        onClicked: Notifications.dismissHistoryItem(notifItem.index)
                    }
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                visible: Notifications.history.count === 0
                text: "No notifications"
                role: "body"
                dim: true
            }
        }
    }
}
