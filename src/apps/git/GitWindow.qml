import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "b1air-git — " + (GitBackend.repoName || "Git")
    width: 1040
    height: 680
    minimumWidth: 700
    minimumHeight: 450
    visible: true
    color: "#16161e"

    // Design Tokens
    readonly property color colBg: "#1a1b26"
    readonly property color colDark: "#16161e"
    readonly property color colHeader: "#13141c"
    readonly property color colBorder: Qt.rgba(122/255, 162/255, 247/255, 0.16)
    readonly property color colBlue: "#7aa2f7"
    readonly property color colPurple: "#bb9af7"
    readonly property color colCyan: "#7dcfff"
    readonly property color colGreen: "#73daca"
    readonly property color colOrange: "#ff9e64"
    readonly property color colRed: "#f7768e"
    readonly property color colFg: "#c0caf5"
    readonly property color colDim: "#565f89"

    property int currentTab: 0 // 0: Changes, 1: History
    property bool repoDropdownOpen: false
    property bool branchDropdownOpen: false

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        color: window.colBg
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ══════════════════════════════════════════════════════════════════
            // GITHUB DESKTOP TOP TOOLBAR (42px)
            // ══════════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: window.colHeader
                border.color: window.colBorder
                border.width: 1
                z: 20

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // 1. Current Repository Selector
                    Rectangle {
                        id: repoBtn
                        width: repoRow.implicitWidth + 20
                        height: 28
                        radius: 6
                        color: repoArea.containsMouse || window.repoDropdownOpen ? Qt.rgba(122/255, 162/255, 247/255, 0.18) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                        border.color: window.repoDropdownOpen ? window.colBlue : window.colBorder
                        border.width: 1

                        Row {
                            id: repoRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰊢"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: window.colBlue
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Current Repository:"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 10
                                color: window.colDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: GitBackend.repoName
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 12
                                font.bold: true
                                color: window.colFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: window.repoDropdownOpen ? "󰅃" : "󰅀"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: window.colDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: repoArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.repoDropdownOpen = !window.repoDropdownOpen;
                                window.branchDropdownOpen = false;
                            }
                        }
                    }

                    // 2. Current Branch Selector
                    Rectangle {
                        id: branchBtn
                        width: branchRow.implicitWidth + 20
                        height: 28
                        radius: 6
                        color: branchArea.containsMouse || window.branchDropdownOpen ? Qt.rgba(115/255, 218/255, 202/255, 0.18) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                        border.color: window.branchDropdownOpen ? window.colGreen : window.colBorder
                        border.width: 1

                        Row {
                            id: branchRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: window.colGreen
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Current Branch:"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 10
                                color: window.colDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: GitBackend.branchName
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: window.colGreen
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: window.branchDropdownOpen ? "󰅃" : "󰅀"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: window.colDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: branchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.branchDropdownOpen = !window.branchDropdownOpen;
                                window.repoDropdownOpen = false;
                            }
                        }
                    }

                    // 3. Fetch / Push / Pull Action Pill
                    Rectangle {
                        id: syncBtn
                        width: syncRow.implicitWidth + 20
                        height: 28
                        radius: 6
                        color: syncArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.22) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                        border.color: window.colBorder
                        border.width: 1

                        Row {
                            id: syncRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰑐"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: window.colBlue
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Fetch origin"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 11
                                font.bold: true
                                color: window.colFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: syncArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GitBackend.fetch()
                        }
                    }

                    // Push / Pull Quick Actions
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: pushArea.containsMouse ? Qt.rgba(187/255, 154/255, 247/255, 0.25) : "transparent"
                            border.color: pushArea.containsMouse ? window.colPurple : window.colBorder
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "󰜮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colPurple }
                            MouseArea { id: pushArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.push() }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: pullArea.containsMouse ? Qt.rgba(125/255, 207/255, 255/255, 0.25) : "transparent"
                            border.color: pullArea.containsMouse ? window.colCyan : window.colBorder
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "󰜱"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colCyan }
                            MouseArea { id: pullArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.pull() }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Quick External Tools
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: termRow.implicitWidth + 14
                            height: 26
                            radius: 6
                            color: termArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.12) : "transparent"
                            border.color: window.colBorder
                            border.width: 1

                            Row {
                                id: termRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: "󰞷"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colFg }
                                Text { text: "Terminal"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; color: window.colFg }
                            }
                            MouseArea { id: termArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.openTerminal() }
                        }

                        Rectangle {
                            width: filesRow.implicitWidth + 14
                            height: 26
                            radius: 6
                            color: filesArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.12) : "transparent"
                            border.color: window.colBorder
                            border.width: 1

                            Row {
                                id: filesRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: "󰉋"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colFg }
                                Text { text: "Files"; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; color: window.colFg }
                            }
                            MouseArea { id: filesArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GitBackend.openFileManager() }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // MAIN WORKSPACE (Left: Changes/History Sidebar, Right: Diff View)
            // ══════════════════════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ── LEFT SIDEBAR (Changes & History) ──────────────────────
                    Rectangle {
                        Layout.preferredWidth: 320
                        Layout.fillHeight: true
                        color: window.colDark
                        border.color: window.colBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Top Sidebar Tab Switcher: [ Changes (N) ] [ History ]
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                color: Qt.rgba(19/255, 20/255, 28/255, 0.8)
                                border.color: window.colBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: window.currentTab === 0 ? window.colDark : "transparent"
                                        border.color: window.currentTab === 0 ? window.colBlue : "transparent"
                                        border.width: window.currentTab === 0 ? 1 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Changes (" + GitBackend.changedFiles.length + ")"
                                            font.family: "Fira Sans SemiBold, sans-serif"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: window.currentTab === 0 ? window.colBlue : window.colDim
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: window.currentTab = 0
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: window.currentTab === 1 ? window.colDark : "transparent"
                                        border.color: window.currentTab === 1 ? window.colBlue : "transparent"
                                        border.width: window.currentTab === 1 ? 1 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "History"
                                            font.family: "Fira Sans SemiBold, sans-serif"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: window.currentTab === 1 ? window.colBlue : window.colDim
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: window.currentTab = 1
                                        }
                                    }
                                }
                            }

                            // Tab 0: Changes File List & Commit Box
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: window.currentTab === 0

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Stage All / Unstage All Bar
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        color: Qt.rgba(26/255, 27/255, 38/255, 0.40)
                                        border.color: window.colBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10

                                            Text {
                                                text: "Changed Files"
                                                font.family: "Fira Sans SemiBold, sans-serif"
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: window.colDim
                                            }
                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: "Stage All"
                                                font.family: "Fira Sans SemiBold, sans-serif"
                                                font.pixelSize: 10
                                                color: window.colGreen
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: GitBackend.stageAll()
                                                }
                                            }
                                            Text { text: "•"; font.pixelSize: 8; color: window.colDim }
                                            Text {
                                                text: "Unstage All"
                                                font.family: "Fira Sans SemiBold, sans-serif"
                                                font.pixelSize: 10
                                                color: window.colRed
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: GitBackend.unstageAll()
                                                }
                                            }
                                        }
                                    }

                                    // Changed Files ListView
                                    ListView {
                                        id: changedList
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        model: GitBackend.changedFiles
                                        spacing: 1

                                        delegate: Rectangle {
                                            id: fileCard
                                            width: changedList.width
                                            height: 32
                                            color: isSelected ? Qt.rgba(122/255, 162/255, 247/255, 0.18) : (fArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent")

                                            readonly property bool isSelected: GitBackend.selectedFile === modelData.path

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                // Staged Checkbox
                                                Rectangle {
                                                    width: 16
                                                    height: 16
                                                    radius: 3
                                                    color: modelData.isStaged ? window.colGreen : "transparent"
                                                    border.color: modelData.isStaged ? window.colGreen : window.colDim
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✓"
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        color: "#101014"
                                                        visible: modelData.isStaged
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData.isStaged) GitBackend.unstageFile(modelData.path);
                                                            else GitBackend.stageFile(modelData.path);
                                                        }
                                                    }
                                                }

                                                // File Status Badge (M, A, D)
                                                Text {
                                                    text: modelData.status === "added" ? "A" : (modelData.status === "deleted" ? "D" : "M")
                                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: modelData.status === "added" ? window.colGreen : (modelData.status === "deleted" ? window.colRed : window.colOrange)
                                                }

                                                // File Name
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.path
                                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                                    font.pixelSize: 11
                                                    color: fileCard.isSelected ? "#ffffff" : window.colFg
                                                    elide: Text.ElideMiddle
                                                }
                                            }

                                            MouseArea {
                                                id: fArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: GitBackend.selectFile(modelData.path)
                                            }
                                        }
                                    }

                                    // Bottom GitHub Desktop Commit Box
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 130
                                        color: Qt.rgba(19/255, 20/255, 28/255, 0.90)
                                        border.color: window.colBorder
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 6

                                            // Summary (Required)
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 28
                                                radius: 4
                                                color: window.colBg
                                                border.color: sumInput.activeFocus ? window.colBlue : window.colBorder
                                                border.width: 1

                                                TextInput {
                                                    id: sumInput
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    font.family: "Fira Sans SemiBold, sans-serif"
                                                    font.pixelSize: 11
                                                    color: window.colFg
                                                    selectByMouse: true
                                                    clip: true

                                                    Text {
                                                        text: "Summary (required)"
                                                        font.family: "Fira Sans SemiBold, sans-serif"
                                                        font.pixelSize: 11
                                                        color: window.colDim
                                                        visible: !sumInput.text && !sumInput.activeFocus
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                            }

                                            // Description (Optional)
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                radius: 4
                                                color: window.colBg
                                                border.color: descInput.activeFocus ? window.colBlue : window.colBorder
                                                border.width: 1

                                                TextArea {
                                                    id: descInput
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    font.family: "Fira Sans, sans-serif"
                                                    font.pixelSize: 11
                                                    color: window.colFg
                                                    selectByMouse: true
                                                    background: null
                                                    wrapMode: TextEdit.Wrap

                                                    Text {
                                                        text: "Description"
                                                        font.family: "Fira Sans, sans-serif"
                                                        font.pixelSize: 11
                                                        color: window.colDim
                                                        visible: !descInput.text && !descInput.activeFocus
                                                    }
                                                }
                                            }

                                            // Commit Action Button
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 28
                                                radius: 5
                                                color: sumInput.text.trim() ? (commitArea.containsMouse ? Qt.lighter(window.colBlue, 1.1) : window.colBlue) : Qt.rgba(122/255, 162/255, 247/255, 0.20)
                                                enabled: sumInput.text.trim().length > 0

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Commit to " + GitBackend.branchName
                                                    font.family: "Fira Sans SemiBold, sans-serif"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: sumInput.text.trim() ? "#101014" : window.colDim
                                                }

                                                MouseArea {
                                                    id: commitArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: {
                                                        let fullMsg = sumInput.text.trim();
                                                        if (descInput.text.trim()) fullMsg += "\n\n" + descInput.text.trim();
                                                        GitBackend.commit(fullMsg);
                                                        sumInput.text = "";
                                                        descInput.text = "";
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Tab 1: History Commit List
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: window.currentTab === 1

                                ListView {
                                    id: historyList
                                    anchors.fill: parent
                                    clip: true
                                    model: GitBackend.commitHistory
                                    spacing: 1

                                    delegate: Rectangle {
                                        width: historyList.width
                                        height: 52
                                        color: hArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent"
                                        border.color: Qt.rgba(122/255, 162/255, 247/255, 0.08)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 3

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.message || "Commit"
                                                    font.family: "Fira Sans SemiBold, sans-serif"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: window.colFg
                                                    elide: Text.ElideRight
                                                }
                                                Rectangle {
                                                    width: 54; height: 18; radius: 3
                                                    color: Qt.rgba(122/255, 162/255, 247/255, 0.15)
                                                    Text { anchors.centerIn: parent; text: modelData.hash || ""; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 9; color: window.colBlue }
                                                }
                                            }

                                            Text {
                                                text: (modelData.author || "User") + " • " + (modelData.date || "")
                                                font.family: "Fira Sans, sans-serif"
                                                font.pixelSize: 10
                                                color: window.colDim
                                            }
                                        }

                                        MouseArea {
                                            id: hArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── RIGHT MAIN PANEL (File Diff Viewer) ───────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: window.colBg

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Diff File Header Bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                color: window.colDark
                                border.color: window.colBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    Text {
                                        text: "󰈙"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: window.colBlue
                                    }

                                    Text {
                                        text: GitBackend.selectedFile || (GitBackend.isRepo ? "Working tree clean" : "Open a repository")
                                        font.family: "JetBrainsMono Nerd Font, monospace"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: window.colFg
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        text: GitBackend.statusSummary
                                        font.family: "Fira Sans SemiBold, sans-serif"
                                        font.pixelSize: 11
                                        color: window.colDim
                                    }
                                }
                            }

                            // Diff Lines ListView
                            ListView {
                                id: diffList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: GitBackend.currentDiff

                                delegate: Rectangle {
                                    width: diffList.width
                                    height: Math.max(20, diffLineText.implicitHeight + 4)

                                    color: {
                                        if (modelData.type === "add") return Qt.rgba(115/255, 218/255, 202/255, 0.14);
                                        if (modelData.type === "del") return Qt.rgba(247/255, 118/255, 142/255, 0.16);
                                        if (modelData.type === "header") return Qt.rgba(122/255, 162/255, 247/255, 0.12);
                                        return "transparent";
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        // Old Line Num
                                        Text {
                                            width: 42
                                            text: modelData.oldLine || ""
                                            horizontalAlignment: Text.AlignRight
                                            font.family: "JetBrainsMono Nerd Font, monospace"
                                            font.pixelSize: 11
                                            color: window.colDim
                                            rightPadding: 8
                                        }

                                        // New Line Num
                                        Text {
                                            width: 42
                                            text: modelData.newLine || ""
                                            horizontalAlignment: Text.AlignRight
                                            font.family: "JetBrainsMono Nerd Font, monospace"
                                            font.pixelSize: 11
                                            color: window.colDim
                                            rightPadding: 8
                                        }

                                        // Line Content
                                        Text {
                                            id: diffLineText
                                            Layout.fillWidth: true
                                            text: modelData.text || ""
                                            font.family: "JetBrainsMono Nerd Font, monospace"
                                            font.pixelSize: 11
                                            color: {
                                                if (modelData.type === "add") return window.colGreen;
                                                if (modelData.type === "del") return window.colRed;
                                                if (modelData.type === "header") return window.colBlue;
                                                return window.colFg;
                                            }
                                        }
                                    }
                                }

                                // Empty State when clean
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    visible: GitBackend.currentDiff.length === 0

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "󰊢"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 48
                                        color: window.colDim
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: GitBackend.isRepo ? "No changes to display" : "No Git Repository Open"
                                        font.family: "Fira Sans SemiBold, sans-serif"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: window.colFg
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: GitBackend.isRepo ? "Working directory is clean" : "Select a repository from the top menu or open a folder."
                                        font.family: "Fira Sans, sans-serif"
                                        font.pixelSize: 12
                                        color: window.colDim
                                    }
                                }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════════
                // REPOSITORY SELECTOR DROPDOWN POPUP
                // ══════════════════════════════════════════════════════════════
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    width: 380
                    height: 280
                    radius: 8
                    color: window.colHeader
                    border.color: window.colBlue
                    border.width: 1
                    z: 50
                    visible: window.repoDropdownOpen

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "Switch Local Repository"
                            font.family: "Fira Sans SemiBold, sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: window.colBlue
                        }

                        // Path Input Field
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 5
                            color: window.colBg
                            border.color: window.colBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                TextInput {
                                    id: customPathInput
                                    Layout.fillWidth: true
                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                    font.pixelSize: 11
                                    color: window.colFg
                                    text: GitBackend.repoPath
                                    selectByMouse: true
                                    onAccepted: {
                                        GitBackend.openRepo(customPathInput.text);
                                        window.repoDropdownOpen = false;
                                    }
                                }

                                Rectangle {
                                    width: 44; height: 20; radius: 3
                                    color: window.colBlue
                                    Text { anchors.centerIn: parent; text: "Open"; font.bold: true; font.pixelSize: 10; color: "#101014" }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            GitBackend.openRepo(customPathInput.text);
                                            window.repoDropdownOpen = false;
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Discovered Repositories:"
                            font.family: "Fira Sans SemiBold, sans-serif"
                            font.pixelSize: 10
                            color: window.colDim
                        }

                        // Discovered Repos List
                        ListView {
                            id: discoveredList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: GitBackend.discoverRepos()

                            delegate: Rectangle {
                                width: discoveredList.width
                                height: 32
                                radius: 4
                                color: discArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Text { text: "󰊢"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colBlue }
                                    Text { text: modelData.name; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; font.bold: true; color: window.colFg }
                                    Text { text: modelData.path; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: window.colDim; Layout.fillWidth: true; elide: Text.ElideMiddle }
                                }

                                MouseArea {
                                    id: discArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        GitBackend.openRepo(modelData.path);
                                        window.repoDropdownOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════════
                // BRANCH SWITCHER DROPDOWN POPUP
                // ══════════════════════════════════════════════════════════════
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: 180
                    width: 260
                    height: 220
                    radius: 8
                    color: window.colHeader
                    border.color: window.colGreen
                    border.width: 1
                    z: 50
                    visible: window.branchDropdownOpen

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "Switch Branch"
                            font.family: "Fira Sans SemiBold, sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: window.colGreen
                        }

                        ListView {
                            id: branchList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: GitBackend.branches

                            delegate: Rectangle {
                                width: branchList.width
                                height: 28
                                radius: 4
                                color: modelData === GitBackend.branchName ? Qt.rgba(115/255, 218/255, 202/255, 0.25) : (bArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6

                                    Text { text: ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: window.colGreen }
                                    Text { text: modelData; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 11; font.bold: modelData === GitBackend.branchName; color: window.colFg; Layout.fillWidth: true }
                                    Text { text: "✓"; font.pixelSize: 11; font.bold: true; color: window.colGreen; visible: modelData === GitBackend.branchName }
                                }

                                MouseArea {
                                    id: bArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        GitBackend.switchBranch(modelData);
                                        window.branchDropdownOpen = false;
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
