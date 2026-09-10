import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import Ui

ApplicationWindow {
    id: window
    title: NotesBackend.currentNoteId ? "Notes — " + NotesBackend.currentTitle : "Notes"
    width: 960
    height: 620
    minimumWidth: 460
    minimumHeight: 360
    visible: true
    color: "transparent"
    flags: Qt.Window

    // A second, hand-rolled Tokyo Night palette used to live here alongside the
    // Catppuccin one in Ui/Design.qml, so this window never followed the theme.
    // The names stay — they are used throughout the file — but each now resolves
    // to a design-system role, exactly as FilesWindow.qml was already migrated.
    readonly property color colBg: Design.surface
    readonly property color colDark: Design.ground
    readonly property color colSidebar: Design.sunken
    readonly property color colSunken: Design.sunken
    readonly property color colBorder: Design.glassBorder
    readonly property color colBorderSubtle: Design.line
    readonly property color colBlue: Design.accent
    readonly property color colPurple: Design.mauve
    readonly property color colCyan: Design.sapphire
    readonly property color colGreen: Design.ok
    readonly property color colOrange: Design.warn
    readonly property color colRed: Design.danger
    readonly property color colFg: Design.text
    readonly property color colDim: Design.textDim

    property string searchQuery: ""
    property bool showPreview: window.width > 800

    // b1air-git and b1air-notes were the only two apps in the suite with no
    // key bindings at all — every sibling (files, monitor, settings, text,
    // view) closes on Escape, and b1air-text already had Ctrl+S / Ctrl+N for
    // exactly these actions.
    Shortcut {
        sequence: "Escape"
        onActivated: window.close()
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: NotesBackend.createNote("Untitled Note")
    }

    // Editing is auto-saved on a 500 ms debounce; Ctrl+S is the "now, please"
    // that every editor has trained people to expect.
    Shortcut {
        sequence: "Ctrl+S"
        onActivated: {
            autoSaveTimer.stop();
            NotesBackend.saveCurrentNote(titleInput.text, editorArea.text, tagInput.text);
        }
    }

    Shortcut {
        sequence: "Ctrl+P"
        onActivated: window.showPreview = !window.showPreview
    }

    // Auto-save debounce timer
    Timer {
        id: autoSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            NotesBackend.saveCurrentNote(titleInput.text, editorArea.text, tagInput.text);
        }
    }

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: (window.visibility === Window.Maximized) ? 0 : Design.s(14)
        color: window.colBg
        border.color: (window.visibility === Window.Maximized) ? "transparent" : window.colBorder
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Headerbar (40px) ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: window.colSidebar
                border.color: window.colBorder
                border.width: 1
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // App Icon & Title
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: "󰈙"
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(15)
                            color: window.colBlue
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "b1air-notes"
                            font.family: Design.font.sans
                            font.pixelSize: Design.s(12)
                            font.bold: true
                            color: window.colFg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // New Note Button
                    Rectangle {
                        width: newRow.implicitWidth + 14
                        height: 26
                        radius: 6
                        color: newArea.containsMouse ? Design.tint(Design.accent, 0.25) : Design.tint(Design.raised, 0.60)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: newRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰐕"; font.family: Design.font.mono; font.pixelSize: Design.s(12); color: window.colBlue }
                            Text { text: "New Note"; font.family: Design.font.sans; font.pixelSize: Design.s(11); font.bold: true; color: window.colFg }
                        }

                        MouseArea {
                            id: newArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotesBackend.createNote("Untitled Note")
                        }
                    }

                    // Obsidian Sync Pill
                    Rectangle {
                        width: obsRow.implicitWidth + 14
                        height: 26
                        radius: 6
                        color: obsArea.containsMouse ? Design.tint(Design.mauve, 0.25) : Design.tint(Design.raised, 0.40)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: obsRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰈚"; font.family: Design.font.mono; font.pixelSize: Design.s(12); color: window.colPurple }
                            Text { text: "Obsidian Sync"; font.family: Design.font.sans; font.pixelSize: Design.s(11); font.bold: true; color: window.colPurple }
                        }

                        MouseArea {
                            id: obsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotesBackend.syncWithObsidian()
                        }
                    }

                    // Notion Sync Pill
                    Rectangle {
                        width: notionRow.implicitWidth + 14
                        height: 26
                        radius: 6
                        color: notionArea.containsMouse ? Design.tint(Design.ok, 0.25) : Design.tint(Design.raised, 0.40)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: notionRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰍉"; font.family: Design.font.mono; font.pixelSize: Design.s(12); color: window.colGreen }
                            Text { text: "Notion Sync"; font.family: Design.font.sans; font.pixelSize: Design.s(11); font.bold: true; color: window.colGreen }
                        }

                        MouseArea {
                            id: notionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotesBackend.syncWithNotion()
                        }
                    }

                    // What the two buttons above did. Both set a status the
                    // window never showed, so pressing either was silent —
                    // including the case where Notion has no credentials at
                    // all, which is every install, since nothing here sets
                    // them. Now the button says so, and says where they go.
                    Text {
                        id: syncStatusText
                        Layout.fillWidth: true
                        Layout.leftMargin: Design.s(Design.space.sm)
                        text: NotesBackend.syncStatus
                        elide: Text.ElideRight
                        font.family: Design.font.sans
                        font.pixelSize: Design.s(11)
                        color: NotesBackend.syncStatus.indexOf("Error") >= 0
                               || NotesBackend.syncStatus.indexOf("not configured") >= 0
                               || NotesBackend.syncStatus.indexOf("No Obsidian") >= 0
                            ? Design.warn : Design.textDim
                        visible: NotesBackend.syncStatus !== "" && NotesBackend.syncStatus !== "Ready"
                    }

                    Item { Layout.fillWidth: !syncStatusText.visible }

                    // Search Bar
                    Rectangle {
                        width: Math.min(160, Math.max(100, window.width * 0.18))
                        height: 26
                        radius: 6
                        color: window.colBg
                        border.color: searchInput.activeFocus ? window.colBlue : window.colBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Text { text: "󰍉"; font.family: Design.font.mono; font.pixelSize: Design.s(11); color: window.colDim }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                color: window.colFg
                                selectByMouse: true
                                onTextChanged: window.searchQuery = text.toLowerCase()
                            }
                        }
                    }

                    // Toggle Preview Button
                    Rectangle {
                        width: 26; height: 26; radius: 5
                        color: prevArea.containsMouse ? Design.tint(Design.accent, 0.25) : "transparent"
                        border.color: window.colBorder
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: window.showPreview ? "󰈙" : "󱡁"
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(13)
                            color: window.colFg
                        }
                        MouseArea {
                            id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: window.showPreview = !window.showPreview
                        }
                    }
                }
            }

            // ── Main Notes Workspace ─────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Left Column: Note List (240px)
                    Rectangle {
                        Layout.preferredWidth: 240
                        Layout.fillHeight: true
                        color: window.colSidebar

                        // Right vertical divider
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: window.colBorder
                        }

                        ListView {
                            id: notesList
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            spacing: 4
                            model: NotesBackend.noteList

                            delegate: Rectangle {
                                width: notesList.width
                                // A hidden delegate still occupies its height in a
                                // ListView, so filtering by `visible` alone left a
                                // 58 px hole for every note the search excluded.
                                height: matchesSearch ? Design.s(58) : 0
                                radius: Design.s(6)
                                clip: true
                                color: isSelected ? Design.tint(Design.accent, 0.20) : (itemArea.containsMouse ? Design.tint(Design.text, 0.05) : "transparent")
                                border.color: isSelected ? window.colBlue : "transparent"
                                border.width: 1

                                readonly property bool isSelected: NotesBackend.currentNoteId === modelData.id
                                readonly property bool matchesSearch: window.searchQuery === ""
                                    || (modelData.title || "").toLowerCase().includes(window.searchQuery)
                                    || (modelData.content || "").toLowerCase().includes(window.searchQuery)
                                visible: matchesSearch

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || "Untitled"
                                            font.family: Design.font.sans
                                            font.pixelSize: Design.s(12)
                                            font.bold: true
                                            color: isSelected ? "#ffffff" : window.colFg
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.date || ""
                                            font.family: Design.font.sans
                                            font.pixelSize: Design.s(9)
                                            color: window.colDim
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.content || "").replace(/\n/g, " ")
                                        font.family: Design.font.sans
                                        font.pixelSize: Design.s(10)
                                        color: window.colDim
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NotesBackend.selectNote(modelData.id);
                                        titleInput.text = modelData.title || "";
                                        editorArea.text = modelData.content || "";
                                        tagInput.text = modelData.tags || "";
                                    }
                                }
                            }
                        }
                    }

                    // Middle/Right Column: Editor & Preview
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: window.colBg

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            // Note Title Input & Delete Button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                TextInput {
                                    id: titleInput
                                    Layout.fillWidth: true
                                    text: NotesBackend.currentTitle
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(20)
                                    font.bold: true
                                    color: window.colFg
                                    selectByMouse: true
                                    onTextChanged: autoSaveTimer.restart()
                                }

                                Rectangle {
                                    width: 28; height: 28; radius: 6
                                    color: delArea.containsMouse ? Design.tint(Design.danger, 0.25) : "transparent"
                                    border.color: window.colBorder
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        font.family: Design.font.mono
                                        font.pixelSize: Design.s(13)
                                        color: window.colRed
                                    }
                                    MouseArea {
                                        id: delArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: deleteConfirm.open()
                                    }
                                }
                            }

                            // Tags Bar
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text { text: "󰓹"; font.family: Design.font.mono; font.pixelSize: Design.s(12); color: window.colCyan }
                                TextInput {
                                    id: tagInput
                                    Layout.fillWidth: true
                                    text: NotesBackend.currentTags
                                    font.family: Design.font.mono
                                    font.pixelSize: Design.s(11)
                                    color: window.colCyan
                                    selectByMouse: true
                                    onTextChanged: autoSaveTimer.restart()

                                    Text {
                                        text: "Add tags (comma separated)..."
                                        font.family: Design.font.sans
                                        font.pixelSize: Design.s(11)
                                        color: window.colDim
                                        visible: !tagInput.text && !tagInput.activeFocus
                                    }
                                }
                            }

                            // Horizontal Divider
                            Rectangle { Layout.fillWidth: true; height: 1; color: window.colBorder }

                            // Editor & Preview Row
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 14

                                // Markdown Raw Text Editor
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: window.colDark
                                    radius: 8
                                    border.color: window.colBorder
                                    border.width: 1

                                    Flickable {
                                        id: editorFlick
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        contentWidth: width
                                        contentHeight: editorArea.implicitHeight + 20
                                        clip: true

                                        TextArea {
                                            id: editorArea
                                            width: parent.width
                                            text: NotesBackend.currentContent
                                            font.family: Design.font.mono
                                            font.pixelSize: Design.s(13)
                                            color: window.colFg
                                            selectionColor: Design.tint(Design.accent, 0.35)
                                            wrapMode: TextEdit.Wrap
                                            background: null
                                            selectByMouse: true
                                            onTextChanged: autoSaveTimer.restart()
                                        }
                                    }
                                }

                                // Live Markdown Rich Preview Pane (Optional)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: Design.tint(Design.surface, 0.60)
                                    radius: 8
                                    border.color: window.colBorder
                                    border.width: 1
                                    visible: window.showPreview

                                    Flickable {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        contentWidth: width
                                        contentHeight: previewText.implicitHeight + 20
                                        clip: true

                                        Text {
                                            id: previewText
                                            width: parent.width
                                            text: NotesBackend.renderMarkdownToHtml(editorArea.text)
                                            textFormat: Text.RichText
                                            font.family: Design.font.sans
                                            font.pixelSize: Design.s(13)
                                            color: window.colFg
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteConfirm
        title: "Delete note?"
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: NotesBackend.deleteNote(NotesBackend.currentNoteId)
        // A wrapping label as contentItem sizes itself from the width the
        // Dialog gives it, while the Dialog sizes itself from the label —
        // Qt reported "Binding loop detected for property implicitWidth" on
        // every start. An explicit implicitWidth breaks the cycle.
        // Text.implicitWidth is read-only, so the loop has to be broken one
        // level up: an Item can carry an explicit implicit size, and the
        // wrapping label lays out inside it.
        contentItem: Item {
            implicitWidth: Design.s(300)
            implicitHeight: delMsg.implicitHeight + Design.s(36)

            Label {
                id: delMsg
                anchors.fill: parent
                anchors.margins: Design.s(18)
                text: "This note will be permanently deleted."
                wrapMode: Text.WordWrap
            }
        }
    }
}
