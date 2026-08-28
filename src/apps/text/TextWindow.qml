import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Ui

Window {
    id: window
    title: (TextBackend.isModified ? "● " : "") + TextBackend.fileName + " — b1air-text"
    width: Design.s(900)
    height: Design.s(620)
    minimumWidth: Design.s(680)
    minimumHeight: Design.s(420)
    visible: true
    color: "transparent"

    onClosing: Qt.quit()

    property bool wordWrapEnabled: false
    property int currentLine: 1
    property int currentCol: 1

    function calculateCursorPos() {
        let textBefore = editorArea.text.substring(0, editorArea.cursorPosition);
        let lines = textBefore.split("\n");
        currentLine = lines.length;
        currentCol = lines[lines.length - 1].length + 1;
    }

    // ── Global Shortcuts ─────────────────────────────────────────────────────
    Shortcut { sequence: "Ctrl+S"; onActivated: TextBackend.saveFile() }
    Shortcut { sequence: "Ctrl+N"; onActivated: TextBackend.newFile() }
    Shortcut { sequence: "Escape"; onActivated: window.close() }

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: (window.visibility === Window.Maximized) ? 0 : Design.s(14)
        color: Design.base
        border.color: (window.visibility === Window.Maximized) ? "transparent" : Design.glassBorder
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

        // ═════════════════════════════════════════════════════════════════════
        // TOP HEADER BAR (COMPACT TILED TOOLBAR)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Design.s(36)
            color: Design.crust
            border.color: Design.glassBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.s(Design.space.sm)
                anchors.rightMargin: Design.s(Design.space.sm)
                spacing: Design.s(Design.space.xs)

                // File Icon
                Rectangle {
                    width: Design.s(22)
                    height: Design.s(22)
                    radius: Design.s(Design.radius.sm)
                    color: Design.tint(Design.accent, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f0f6}" // file-text
                        color: Design.accent
                        font.family: Design.font.icon
                        font.pixelSize: Design.s(12)
                    }
                }

                // File Name & Path
                RowLayout {
                    spacing: Design.s(6)

                    Text {
                        text: TextBackend.fileName
                        font.family: Design.font.sans
                        font.weight: Design.weight.bold
                        font.pixelSize: Design.s(12)
                        color: Design.text
                    }

                    Rectangle {
                        width: Design.s(6)
                        height: Design.s(6)
                        radius: 3
                        color: Design.peach
                        visible: TextBackend.isModified
                    }

                    Text {
                        text: TextBackend.filePath ? ("— " + TextBackend.filePath) : ""
                        font.family: Design.font.sans
                        font.pixelSize: Design.s(11)
                        color: Design.textDim
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: Design.s(320)
                    }
                }

                Item { Layout.fillWidth: true }

                // Actions: New, Save, Word Wrap
                RowLayout {
                    spacing: Design.s(4)

                    IconButton {
                        icon: "\u{f067}" // plus
                        bordered: true
                        onClicked: TextBackend.newFile()
                    }

                    IconButton {
                        icon: "\u{f0c7}" // save
                        bordered: true
                        hoverTone: Design.teal
                        fill: TextBackend.isModified ? Design.tint(Design.accent, 0.25) : "transparent"
                        tone: TextBackend.isModified ? Design.accent : Design.textDim
                        onClicked: TextBackend.saveFile()
                    }

                    Rectangle {
                        implicitWidth: wrapBtnText.implicitWidth + Design.s(12)
                        implicitHeight: Design.s(24)
                        radius: Design.s(Design.radius.ctl)
                        color: window.wordWrapEnabled ? Design.tint(Design.accent, 0.22) : Design.sunken
                        border.color: Design.glassBorder
                        border.width: 1

                        Text {
                            id: wrapBtnText
                            anchors.centerIn: parent
                            text: "Wrap"
                            font.family: Design.font.sans
                            font.weight: Design.weight.medium
                            font.pixelSize: Design.s(10)
                            color: window.wordWrapEnabled ? Design.accent : Design.textDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: window.wordWrapEnabled = !window.wordWrapEnabled
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // MAIN TEXT EDITOR WITH LINE NUMBERS
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Design.base

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ── Line Numbers Gutter ──────────────────────────────────────
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Design.s(52)
                    color: Design.crust

                    ListView {
                        id: lineNumbersView
                        anchors.fill: parent
                        anchors.topMargin: Design.s(12)
                        anchors.bottomMargin: Design.s(12)
                        clip: true
                        interactive: false
                        contentY: editorFlickable.contentY

                        model: TextBackend.lineCount

                        delegate: Text {
                            width: lineNumbersView.width - Design.s(14)
                            height: Design.s(20)
                            text: String(index + 1)
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(12)
                            color: (index + 1 === window.currentLine) ? Design.accent : Design.textFaint
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Gutter Right Divider
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Design.glassBorder
                    }
                }

                // ── Editor TextArea ──────────────────────────────────────────
                Flickable {
                    id: editorFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    ScrollBar.horizontal: ScrollBar { policy: window.wordWrapEnabled ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded }

                    TextArea.flickable: TextArea {
                        id: editorArea
                        font.family: Design.font.mono
                        font.pixelSize: Design.s(13)
                        color: Design.text
                        selectionColor: Design.tint(Design.accent, 0.35)
                        selectedTextColor: Design.text
                        tabStopDistance: 32
                        wrapMode: window.wordWrapEnabled ? TextEdit.Wrap : TextEdit.NoWrap
                        padding: Design.s(12)
                        selectByMouse: true

                        text: TextBackend.fileContent

                        onTextChanged: {
                            if (text !== TextBackend.fileContent) {
                                TextBackend.setFileContent(text);
                            }
                            window.calculateCursorPos();
                        }

                        onCursorPositionChanged: {
                            window.calculateCursorPos();
                        }

                        Connections {
                            target: TextBackend
                            function onContentChanged() {
                                if (editorArea.text !== TextBackend.fileContent) {
                                    editorArea.text = TextBackend.fileContent;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // BOTTOM STATUS BAR
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Design.s(26)
            color: Design.crust
            border.color: Design.glassBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.s(Design.space.md)
                anchors.rightMargin: Design.s(Design.space.md)
                spacing: Design.s(Design.space.md)

                Text {
                    text: "Ln " + window.currentLine + ", Col " + window.currentCol
                    font.family: Design.font.mono
                    font.pixelSize: Design.s(10)
                    color: Design.textDim
                }

                Text {
                    text: TextBackend.lineCount + " lines  •  " + TextBackend.wordCount + " words"
                    font.family: Design.font.sans
                    font.pixelSize: Design.s(10)
                    color: Design.textDim
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: ftText.implicitWidth + Design.s(12)
                    implicitHeight: Design.s(18)
                    radius: Design.s(9)
                    color: Design.tint(Design.teal, 0.18)

                    Text {
                        id: ftText
                        anchors.centerIn: parent
                        text: TextBackend.fileType
                        font.family: Design.font.sans
                        font.weight: Design.weight.bold
                        font.pixelSize: Design.s(9)
                        color: Design.teal
                    }
                }

                Text {
                    text: "UTF-8"
                    font.family: Design.font.sans
                    font.pixelSize: Design.s(10)
                    color: Design.textDim
                }
            }
        }
    }
}
}
