import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Ui"
import "../Services"

// =============================================================================
// Native Clipboard Manager Popup
//
// Fast, searchable clipboard history with pinning, format detection, and
// 1-click paste/copy.
// =============================================================================

PopupShell {
    id: root

    property string searchFilter: ""
    property string activeTab: "All"

    readonly property var allItems: {
        const list = [];
        for (let i = 0; i < Clipboard.items.count; i++) {
            list.push(Clipboard.items.get(i));
        }
        return list;
    }

    readonly property var filteredItems: root.allItems.filter(it => {
        const matchTab = (root.activeTab === "All")
            || (root.activeTab === "Pinned" && it.pinned)
            || (root.activeTab === "Code" && it.type === "code")
            || (root.activeTab === "Links" && it.type === "link");
        const matchSearch = (!root.searchFilter || it.text.toLowerCase().includes(root.searchFilter.toLowerCase()));
        return matchTab && matchSearch;
    })

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)

        // ── 1. Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Icon {
                text: "\u{f004e}" // clipboard
                role: "subhead"
                color: Design.accent
            }

            Label {
                text: "Clipboard History"
                role: "subhead"
                weight: Design.weight.bold
            }

            Badge {
                text: String(root.filteredItems.length)
                tone: Design.sapphire
            }

            Item { Layout.fillWidth: true }

            ActionButton {
                visible: Clipboard.items.count > 0
                icon: "\u{f0156}"
                label: "Clear All"
                onActivated: Clipboard.clearHistory()
            }
        }

        // ── 2. Search Field & Category Filters ───────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Field {
                id: searchInput
                Layout.fillWidth: true
                placeholder: "Search clipboard history..."
                text: root.searchFilter
                onEdited: v => root.searchFilter = v
                Component.onCompleted: searchInput.forceActiveFocus()
            }

            RowLayout {
                spacing: Design.s(Design.space.xs)

                Repeater {
                    model: ["All", "Pinned", "Code", "Links"]

                    Pill {
                        id: tabPill
                        required property string modelData
                        label: tabPill.modelData
                        active: root.activeTab === tabPill.modelData
                        activeColor: Design.accent
                        onClicked: root.activeTab = tabPill.modelData
                    }
                }
            }
        }

        // ── 3. Clipboard Items List ──────────────────────────────────────────
        ListView {
            id: clipList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Design.s(Design.space.xs)
            model: root.filteredItems

            delegate: Rectangle {
                id: clipCard
                required property var modelData
                required property int index

                width: ListView.view ? ListView.view.width : 0
                implicitHeight: cardCol.implicitHeight + Design.s(Design.space.sm)
                radius: Design.s(Design.radius.card)
                color: clipCard.modelData.pinned ? Design.tint(Design.accent, 0.12)
                     : (cardHoverMa.containsMouse ? Design.raised : Design.glassCard)
                border.color: clipCard.modelData.pinned ? Design.accent
                            : (cardHoverMa.containsMouse ? Design.glassBorderStrong : Design.glassBorder)
                border.width: 1

                RowLayout {
                    id: cardCol
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.sm)

                    // Type Icon
                    Rectangle {
                        Layout.preferredWidth: Design.s(32)
                        Layout.preferredHeight: Design.s(32)
                        radius: Design.s(Design.radius.ctl)
                        color: clipCard.modelData.type === "color" ? clipCard.modelData.text.trim() : Design.sunken
                        Layout.alignment: Qt.AlignTop

                        Icon {
                            visible: clipCard.modelData.type !== "color"
                            anchors.centerIn: parent
                            text: clipCard.modelData.type === "code" ? "\u{f0169}"
                                : (clipCard.modelData.type === "link" ? "\u{f0339}" : "\u{f0219}")
                            role: "caption"
                            color: Design.accent
                        }
                    }

                    // Content Snippet
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: clipCard.modelData.type.toUpperCase()
                                role: "caption"
                                weight: Design.weight.bold
                                color: Design.accent
                            }
                            Label {
                                text: "• " + clipCard.modelData.time
                                role: "caption"
                                dim: true
                            }
                            Label {
                                text: "(" + clipCard.modelData.text.length + " chars)"
                                role: "caption"
                                dim: true
                            }
                        }

                        Label {
                            text: clipCard.modelData.preview
                            isMono: clipCard.modelData.type === "code"
                            role: "body"
                            maximumLineCount: 3
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Action buttons
                    RowLayout {
                        spacing: Design.s(2)
                        Layout.alignment: Qt.AlignTop

                        IconButton {
                            icon: clipCard.modelData.pinned ? "\u{f0403}" : "\u{f0404}"
                            role: "caption"
                            hoverTone: Design.accent
                            onClicked: Clipboard.togglePin(clipCard.index)
                        }

                        IconButton {
                            icon: "\u{f0156}"
                            role: "caption"
                            hoverTone: Design.danger
                            onClicked: Clipboard.deleteItem(clipCard.index)
                        }
                    }
                }

                MouseArea {
                    id: cardHoverMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Clipboard.copyToClipboard(clipCard.modelData.text);
                        root.close();
                    }
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                visible: root.filteredItems.length === 0
                text: root.searchFilter ? "No matching clips found" : "Clipboard history is empty"
                role: "body"
                dim: true
            }
        }
    }
}
