import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "b1air-git"
    width: 960
    height: 620
    minimumWidth: 500
    minimumHeight: 380
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

    property int currentTab: 0 // 0: Changes, 1: History

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
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                Text { text: "🌿"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "b1air-git"
                    font.family: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: window.colGreen
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Branch Pill
            Rectangle {
                width: brText.implicitWidth + 14
                height: 22
                radius: 6
                color: Qt.rgba(115/255, 218/255, 202/255, 0.20)
                border.color: "transparent"

                Text {
                    id: brText
                    anchors.centerIn: parent
                    text: " " + GitBackend.branchName
                    font.family: "JetBrainsMono Nerd Font, monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: window.colGreen
                }
            }

            Item { Layout.fillWidth: true }

            // Commit Input & Action
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: Math.min(220, Math.max(120, window.width * 0.25))
                    height: 24
                    radius: 5
                    color: window.colBg
                    border.color: commitInput.activeFocus ? window.colBlue : window.colBorder
                    border.width: 1

                    TextInput {
                        id: commitInput
                        anchors.fill: parent
                        anchors.margins: 4
                        font.family: "Fira Sans, sans-serif"
                        font.pixelSize: 11
                        color: window.colFg
                        selectByMouse: true
                    }
                }

                Rectangle {
                    width: cBtnText.implicitWidth + 14
                    height: 24
                    radius: 5
                    color: cBtnArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.35) : window.colBlue

                    Text {
                        id: cBtnText
                        anchors.centerIn: parent
                        text: "Commit"
                        font.family: "Fira Sans SemiBold, sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#101014"
                    }

                    MouseArea {
                        id: cBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            GitBackend.commit(commitInput.text);
                            commitInput.text = "";
                        }
                    }
                }
            }

            // Sync Buttons (Push, Pull, Refresh)
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 24; height: 24; radius: 5
                    color: pshArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "⬆"; font.pixelSize: 12; color: window.colFg }
                    MouseArea { id: pshArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.push() }
                }

                Rectangle {
                    width: 24; height: 24; radius: 5
                    color: pulArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "⬇"; font.pixelSize: 12; color: window.colFg }
                    MouseArea { id: pulArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.pull() }
                }

                Rectangle {
                    width: 24; height: 24; radius: 5
                    color: refArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "🔄"; font.pixelSize: 12 }
                    MouseArea { id: refArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.refresh() }
                }
            }
        }
    }

    // ── Main Content Area ───────────────────────────────────────────────────
    RowLayout {
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ══════════════════════════════════════════════════════════════════════
        // 1. LEFT SIDEBAR: Changed Files / Commit History (240px)
        // ══════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: Math.min(240, Math.max(160, window.width * 0.28))
            Layout.fillHeight: true
            color: window.colDark

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Tab Switcher
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: "#13131a"
                    border.color: window.colBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: window.currentTab === 0 ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "Changes (" + GitBackend.changedFiles.length + ")"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: window.currentTab === 0 ? window.colBlue : window.colDim
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: window.currentTab = 0 }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: window.currentTab === 1 ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "History"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: window.currentTab === 1 ? window.colBlue : window.colDim
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: window.currentTab = 1 }
                        }
                    }
                }

                // File List (Tab 0)
                ListView {
                    id: fileListView
                    visible: window.currentTab === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: GitBackend.changedFiles
                    spacing: 4
                    clip: true
                    anchors.margins: 6

                    delegate: Rectangle {
                        width: fileListView.width - 12
                        height: 32
                        radius: 6
                        color: modelData.path === GitBackend.selectedFile ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : (fArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent")
                        border.color: modelData.path === GitBackend.selectedFile ? window.colBlue : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // Status Tag (M, A, D, ?)
                            Rectangle {
                                width: 16; height: 16; radius: 4
                                color: modelData.status === "added" ? Qt.rgba(115/255, 218/255, 202/255, 0.25) : (modelData.status === "deleted" ? Qt.rgba(247/255, 118/255, 142/255, 0.25) : Qt.rgba(224/255, 175/255, 104/255, 0.25))
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.code ? modelData.code[0] : "M"
                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: modelData.status === "added" ? window.colGreen : (modelData.status === "deleted" ? window.colRed : window.colOrange)
                                }
                            }

                            Text {
                                text: modelData.name
                                Layout.fillWidth: true
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.path === GitBackend.selectedFile ? "#ffffff" : window.colFg
                                elide: Text.ElideMiddle
                            }

                            // Stage / Unstage Button
                            Rectangle {
                                width: 18; height: 18; radius: 4
                                color: sArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.35) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.isStaged ? "−" : "+"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: modelData.isStaged ? window.colRed : window.colGreen
                                }
                                MouseArea {
                                    id: sArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.isStaged) GitBackend.unstageFile(modelData.path);
                                        else GitBackend.stageFile(modelData.path);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: fArea
                            anchors.fill: parent
                            // Declared after the row content, so it sat on top and ate
                            // every click aimed at the stage/unstage button: pressing +
                            // only ever selected the file.
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GitBackend.selectFile(modelData.path)
                        }
                    }
                }

                // Commit History List (Tab 1)
                ListView {
                    id: historyListView
                    visible: window.currentTab === 1
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: GitBackend.commitHistory
                    spacing: 6
                    clip: true
                    anchors.margins: 6

                    delegate: Rectangle {
                        width: historyListView.width - 12
                        height: 48
                        radius: 6
                        color: Qt.rgba(36/255, 40/255, 59/255, 0.40)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: modelData.hash
                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: window.colBlue
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: modelData.date
                                    font.family: "Fira Sans, sans-serif"
                                    font.pixelSize: 9
                                    color: window.colDim
                                }
                            }

                            Text {
                                text: modelData.message
                                width: parent.width
                                font.family: "Fira Sans, sans-serif"
                                font.pixelSize: 11
                                color: window.colFg
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // Vertical Divider
        Rectangle { Layout.fillHeight: true; width: 1; color: window.colBorder }

        // ══════════════════════════════════════════════════════════════════════
        // 2. RIGHT MAIN PANE: Visual Diff Viewer
        // ══════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.colBg

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Diff Header Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: window.colDark
                    border.color: window.colBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        Text {
                            text: GitBackend.selectedFile ? ("📄 " + GitBackend.selectedFile) : "No file selected"
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 11
                            font.bold: true
                            color: window.colCyan
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: stgAllText.implicitWidth + 12
                            height: 20
                            radius: 4
                            color: stgAllArea.containsMouse ? Qt.rgba(115/255, 218/255, 202/255, 0.35) : Qt.rgba(36/255, 40/255, 59/255, 0.60)

                            Text {
                                id: stgAllText
                                anchors.centerIn: parent
                                text: "+ Stage All"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 10
                                font.bold: true
                                color: window.colGreen
                            }

                            MouseArea {
                                id: stgAllArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GitBackend.stageAll()
                            }
                        }
                    }
                }

                // Diff Line Viewer
                ListView {
                    id: diffListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: GitBackend.currentDiff
                    clip: true

                    delegate: Rectangle {
                        width: diffListView.width
                        height: 20
                        color: modelData.type === "add" ? Qt.rgba(115/255, 218/255, 202/255, 0.12) : (modelData.type === "del" ? Qt.rgba(247/255, 118/255, 142/255, 0.12) : (modelData.type === "header" ? Qt.rgba(122/255, 162/255, 247/255, 0.18) : "transparent"))

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Old Line Num
                            Text {
                                Layout.preferredWidth: 36
                                text: modelData.oldLine ? ("" + modelData.oldLine) : ""
                                horizontalAlignment: Text.AlignRight
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 11
                                color: window.colDim
                                anchors.rightMargin: 6
                            }

                            // New Line Num
                            Text {
                                Layout.preferredWidth: 36
                                text: modelData.newLine ? ("" + modelData.newLine) : ""
                                horizontalAlignment: Text.AlignRight
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 11
                                color: window.colDim
                                anchors.rightMargin: 10
                            }

                            // Divider
                            Rectangle { Layout.fillHeight: true; width: 1; color: Qt.rgba(122/255, 162/255, 247/255, 0.10) }

                            // Diff Text
                            Text {
                                Layout.fillWidth: true
                                anchors.leftMargin: 8
                                text: modelData.text
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 11
                                color: modelData.type === "add" ? window.colGreen : (modelData.type === "del" ? window.colRed : (modelData.type === "header" ? window.colBlue : window.colFg))
                                elide: Text.ElideNone
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Failure toast ────────────────────────────────────────────────────────
    // Errors used to go nowhere: a rejected push or a failed commit left the UI
    // unchanged, which read as "the button does nothing".
    Connections {
        target: GitBackend
        function onCommandFailed(message) {
            errorToast.text = message;
            errorToast.visible = true;
            errorTimer.restart();
        }
    }

    Timer { id: errorTimer; interval: 6000; onTriggered: errorToast.visible = false }

    Rectangle {
        id: errorToast
        property alias text: errorLabel.text
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: Math.min(parent.width - 32, errorLabel.implicitWidth + 28)
        height: errorLabel.implicitHeight + 18
        radius: 8
        color: Qt.rgba(247/255, 118/255, 142/255, 0.16)
        border.color: window.colRed
        border.width: 1
        z: 100

        Text {
            id: errorLabel
            anchors.centerIn: parent
            width: parent.width - 28
            font.family: "JetBrainsMono Nerd Font, monospace"
            font.pixelSize: 11
            color: window.colRed
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        MouseArea { anchors.fill: parent; onClicked: errorToast.visible = false }
    }

    // Shown instead of an empty, dead-looking window when this is not a repo.
    Rectangle {
        visible: !GitBackend.isRepo
        anchors.fill: parent
        anchors.topMargin: 36
        color: window.colBg
        z: 90

        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Not a git repository\n\n" + GitBackend.repoPath +
                  "\n\nOpen b1air-git from inside a repository,\nor pass one as an argument."
            font.family: "JetBrainsMono Nerd Font, monospace"
            font.pixelSize: 12
            color: window.colDim
        }
    }
}
