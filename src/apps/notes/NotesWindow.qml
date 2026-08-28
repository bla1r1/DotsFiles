import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "b1air-notes"
    width: 960
    height: 620
    minimumWidth: 460
    minimumHeight: 360
    visible: true
    color: "#1a1b26"

    // Design Tokens
    readonly property color colBg: "#1a1b26"
    readonly property color colDark: "#16161e"
    readonly property color colBorder: Qt.rgba(122/255, 162/255, 247/255, 0.18)
    readonly property color colBlue: "#7aa2f7"
    readonly property color colPurple: "#bb9af7"
    readonly property color colCyan: "#7dcfff"
    readonly property color colGreen: "#73daca"
    readonly property color colOrange: "#ff9e64"
    readonly property color colRed: "#f7768e"
    readonly property color colFg: "#c0caf5"
    readonly property color colDim: "#565f89"

    property string searchQuery: ""
    property bool showPreview: window.width > 800

    // Auto-save debounce timer
    Timer {
        id: autoSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            NotesBackend.saveCurrentNote(titleInput.text, editorArea.text, tagInput.text);
        }
    }

    // ── Headerbar (36px, zero window buttons) ───────────────────────────────
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: window.colDark
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
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: window.colBlue
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "b1air-notes"
                    font.family: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: window.colFg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // New Note Button
            Rectangle {
                width: newRow.implicitWidth + 14
                height: 24
                radius: 6
                color: newArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                border.color: window.colBorder
                border.width: 1

                Row {
                    id: newRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰐕"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colBlue }
                    Text { text: "New"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colFg }
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
                height: 24
                radius: 6
                color: obsArea.containsMouse ? Qt.rgba(187/255, 154/255, 247/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.40)
                border.color: window.colBorder
                border.width: 1

                Row {
                    id: obsRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰈚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colPurple }
                    Text { text: "Obsidian"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colPurple }
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
                height: 24
                radius: 6
                color: notionArea.containsMouse ? Qt.rgba(115/255, 218/255, 202/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.40)
                border.color: window.colBorder
                border.width: 1

                Row {
                    id: notionRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰍉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colGreen }
                    Text { text: "Notion"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colGreen }
                }

                MouseArea {
                    id: notionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotesBackend.syncWithNotion()
                }
            }

            Item { Layout.fillWidth: true }

            // Search Bar
            Rectangle {
                width: Math.min(140, Math.max(80, window.width * 0.15))
                height: 24
                radius: 6
                color: window.colBg
                border.color: searchInput.activeFocus ? window.colBlue : window.colBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Text { text: "󰍉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: window.colDim }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: "Fira Sans, sans-serif"
                        font.pixelSize: 11
                        color: window.colFg
                        selectByMouse: true
                        onTextChanged: window.searchQuery = text.toLowerCase()
                    }
                }
            }

            // Toggle Preview Button
            Rectangle {
                width: 24; height: 24; radius: 5
                color: prevArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: window.showPreview ? "󰈙" : "󱡁"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: window.colFg
                }
                MouseArea {
                    id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: window.showPreview = !window.showPreview
                }
            }
        }
    }

    // ── Main Content: 3-Column Split ─────────────────────────────────────────
    RowLayout {
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ══════════════════════════════════════════════════════════════════════
        // 1. NOTES SIDEBAR (Responsive)
        // ══════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: Math.min(200, Math.max(140, window.width * 0.22))
            Layout.fillHeight: true
            color: window.colDark

            ListView {
                id: notesListView
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                model: NotesBackend.noteList
                clip: true

                delegate: Rectangle {
                    width: notesListView.width
                    height: 52
                    radius: 6
                    visible: window.searchQuery === "" || modelData.title.toLowerCase().indexOf(window.searchQuery) !== -1 || modelData.content.toLowerCase().indexOf(window.searchQuery) !== -1
                    color: modelData.id === NotesBackend.currentNoteId ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : (noteItemArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent")
                    border.color: modelData.id === NotesBackend.currentNoteId ? window.colBlue : "transparent"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        RowLayout {
                            width: parent.width

                            Text {
                                text: modelData.title || "Untitled"
                                Layout.fillWidth: true
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.id === NotesBackend.currentNoteId ? "#ffffff" : window.colFg
                                elide: Text.ElideRight
                            }

                            // Source Badge
                            Rectangle {
                                width: srcText.implicitWidth + 6
                                height: 14
                                radius: 3
                                color: modelData.source === "obsidian" ? Qt.rgba(187/255, 154/255, 247/255, 0.25) : (modelData.source === "notion" ? Qt.rgba(115/255, 218/255, 202/255, 0.25) : Qt.rgba(122/255, 162/255, 247/255, 0.20))
                                Text {
                                    id: srcText
                                    anchors.centerIn: parent
                                    text: modelData.source === "obsidian" ? "Obsidian" : (modelData.source === "notion" ? "Notion" : "Local")
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: modelData.source === "obsidian" ? window.colPurple : (modelData.source === "notion" ? window.colGreen : window.colBlue)
                                }
                            }
                        }

                        Text {
                            text: modelData.snippet || ""
                            width: parent.width
                            font.family: "Fira Sans, sans-serif"
                            font.pixelSize: 10
                            color: window.colDim
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: noteItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NotesBackend.selectNote(modelData.id);
                            titleInput.text = NotesBackend.currentTitle;
                            editorArea.text = NotesBackend.currentContent;
                            tagInput.text = NotesBackend.currentTags;
                        }
                    }
                }
            }
        }

        // Vertical Divider
        Rectangle { Layout.fillHeight: true; width: 1; color: window.colBorder }

        // ══════════════════════════════════════════════════════════════════════
        // 2. MARKDOWN EDITOR (Center)
        // ══════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.colBg

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Note Title Field
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextInput {
                        id: titleInput
                        Layout.fillWidth: true
                        text: NotesBackend.currentTitle
                        font.family: "Fira Sans Bold, sans-serif"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ffffff"
                        selectByMouse: true
                        onTextChanged: autoSaveTimer.restart()
                    }

                    // Delete button
                    Rectangle {
                        width: 22; height: 22; radius: 5
                        color: delArea.containsMouse ? Qt.rgba(247/255, 118/255, 142/255, 0.25) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰆴"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: window.colRed
                        }
                        MouseArea {
                            id: delArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: NotesBackend.deleteNote(NotesBackend.currentNoteId)
                        }
                    }
                }

                // Tags Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "󰓹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: window.colDim
                    }
                    TextInput {
                        id: tagInput
                        Layout.fillWidth: true
                        text: NotesBackend.currentTags
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 11
                        color: window.colCyan
                        selectByMouse: true
                        onTextChanged: autoSaveTimer.restart()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: window.colBorder }

                // Text Area for Markdown
                Flickable {
                    id: editorFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: editorArea.implicitHeight + 40
                    clip: true

                    TextArea {
                        id: editorArea
                        width: parent.width
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 12
                        color: window.colFg
                        selectionColor: Qt.rgba(122/255, 162/255, 247/255, 0.35)
                        selectedTextColor: "#ffffff"
                        wrapMode: TextEdit.Wrap
                        background: null
                        selectByMouse: true
                        text: NotesBackend.currentContent
                        onTextChanged: autoSaveTimer.restart()
                    }
                }
            }
        }

        // Vertical Divider (Preview)
        Rectangle { Layout.fillHeight: true; width: window.showPreview ? 1 : 0; color: window.colBorder; visible: window.showPreview }

        // ══════════════════════════════════════════════════════════════════════
        // 3. LIVE MARKDOWN PREVIEW (Right)
        // ══════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: window.showPreview ? Math.min(280, window.width * 0.35) : 0
            Layout.fillHeight: true
            visible: window.showPreview
            color: window.colDark

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                contentWidth: width
                contentHeight: previewText.implicitHeight + 40
                clip: true

                Text {
                    id: previewText
                    width: parent.width
                    textFormat: Text.MarkdownText
                    text: editorArea.text
                    font.family: "Fira Sans, sans-serif"
                    font.pixelSize: 12
                    color: window.colFg
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
