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
    color: "transparent"
    flags: Qt.Window

    // Design Tokens
    readonly property color colBg: "#161722"
    readonly property color colDark: "#13141e"
    readonly property color colSidebar: "#101119"
    readonly property color colSunken: "#0d0e14"
    readonly property color colBorder: Qt.rgba(122/255, 162/255, 247/255, 0.16)
    readonly property color colBorderSubtle: "#1b1c2b"
    readonly property color colBlue: "#7aa2f7"
    readonly property color colPurple: "#bb9af7"
    readonly property color colCyan: "#7dcfff"
    readonly property color colGreen: "#73daca"
    readonly property color colOrange: "#ff9e64"
    readonly property color colRed: "#f7768e"
    readonly property color colFg: "#c0caf5"
    readonly property color colDim: "#6b739b"

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

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: 14
        color: window.colBg
        border.color: window.colBorder
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
                        height: 26
                        radius: 6
                        color: newArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: newRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰐕"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colBlue }
                            Text { text: "New Note"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colFg }
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
                        color: obsArea.containsMouse ? Qt.rgba(187/255, 154/255, 247/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.40)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: obsRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰈚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colPurple }
                            Text { text: "Obsidian Sync"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colPurple }
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
                        color: notionArea.containsMouse ? Qt.rgba(115/255, 218/255, 202/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.40)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: notionRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "󰍉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colGreen }
                            Text { text: "Notion Sync"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colGreen }
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
                        width: 26; height: 26; radius: 5
                        color: prevArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                        border.color: window.colBorder
                        border.width: 1
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
                            model: NotesBackend.notes

                            delegate: Rectangle {
                                width: notesList.width
                                height: 58
                                radius: 6
                                color: isSelected ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : (itemArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent")
                                border.color: isSelected ? window.colBlue : "transparent"
                                border.width: 1

                                readonly property bool isSelected: NotesBackend.currentNoteId === modelData.id
                                visible: window.searchQuery === "" || (modelData.title || "").toLowerCase().includes(window.searchQuery) || (modelData.content || "").toLowerCase().includes(window.searchQuery)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || "Untitled"
                                            font.family: "Fira Sans SemiBold, sans-serif"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: isSelected ? "#ffffff" : window.colFg
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.date || ""
                                            font.family: "Fira Sans, sans-serif"
                                            font.pixelSize: 9
                                            color: window.colDim
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.content || "").replace(/\n/g, " ")
                                        font.family: "Fira Sans, sans-serif"
                                        font.pixelSize: 10
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
                                    font.family: "Fira Sans SemiBold, sans-serif"
                                    font.pixelSize: 20
                                    font.bold: true
                                    color: "#ffffff"
                                    selectByMouse: true
                                    onTextChanged: autoSaveTimer.restart()
                                }

                                Rectangle {
                                    width: 28; height: 28; radius: 6
                                    color: delArea.containsMouse ? Qt.rgba(247/255, 118/255, 142/255, 0.25) : "transparent"
                                    border.color: window.colBorder
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: window.colRed
                                    }
                                    MouseArea {
                                        id: delArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: NotesBackend.deleteCurrentNote()
                                    }
                                }
                            }

                            // Tags Bar
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text { text: "󰓹"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colCyan }
                                TextInput {
                                    id: tagInput
                                    Layout.fillWidth: true
                                    text: NotesBackend.currentTags
                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                    font.pixelSize: 11
                                    color: window.colCyan
                                    selectByMouse: true
                                    onTextChanged: autoSaveTimer.restart()

                                    Text {
                                        text: "Add tags (comma separated)..."
                                        font.family: "Fira Sans, sans-serif"
                                        font.pixelSize: 11
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
                                            font.family: "JetBrainsMono Nerd Font, monospace"
                                            font.pixelSize: 13
                                            color: window.colFg
                                            selectionColor: Qt.rgba(122/255, 162/255, 247/255, 0.35)
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
                                    color: Qt.rgba(22/255, 22/255, 30/255, 0.60)
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
                                            text: NotesBackend.renderMarkdown(editorArea.text)
                                            textFormat: Text.RichText
                                            font.family: "Fira Sans, sans-serif"
                                            font.pixelSize: 13
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
}
