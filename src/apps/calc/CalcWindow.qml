import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "b1air-calc"
    width: 820
    height: 560
    minimumWidth: 500
    minimumHeight: 380
    visible: true
    color: "#1a1b26"

    property int currentTab: 0 // 0: Scratchpad, 1: Programmer, 2: Converters

    // Design Tokens
    readonly property color colBg: "#1a1b26"
    readonly property color colDark: "#16161e"
    readonly property color colBorder: Qt.rgba(122/255, 162/255, 247/255, 0.18)
    readonly property color colBlue: "#7aa2f7"
    readonly property color colPurple: "#bb9af7"
    readonly property color colCyan: "#7dcfff"
    readonly property color colGreen: "#73daca"
    readonly property color colOrange: "#ff9e64"
    readonly property color colFg: "#c0caf5"
    readonly property color colDim: "#565f89"

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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            // App Icon & Title
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                Text { text: "🧮"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "b1air-calc"
                    font.family: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: window.colBlue
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.fillWidth: true }

            // Mode Selector Pills
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: [
                        { label: "Scratchpad", icon: "📝" },
                        { label: "Programmer", icon: "⚙️" },
                        { label: "Converters", icon: "🔄" }
                    ]
                    delegate: Rectangle {
                        width: tabText.implicitWidth + 20
                        height: 24
                        radius: 6
                        color: window.currentTab === index ? window.colBlue : (tabArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.15) : Qt.rgba(36/255, 40/255, 59/255, 0.60))
                        border.color: window.currentTab === index ? "transparent" : Qt.rgba(65/255, 72/255, 104/255, 0.40)
                        border.width: 1

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData.icon + " " + modelData.label
                            font.family: "Fira Sans SemiBold, sans-serif"
                            font.pixelSize: 11
                            font.bold: true
                            color: window.currentTab === index ? "#101014" : window.colFg
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.currentTab = index
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Action Buttons
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 24; height: 24; radius: 5
                    color: clearArea.containsMouse ? Qt.rgba(247/255, 118/255, 142/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: 12 }
                    MouseArea {
                        id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (window.currentTab === 0) editorArea.text = "";
                            else if (window.currentTab === 1) progInput.text = "0";
                        }
                    }
                }
            }
        }
    }

    // ── Main Content Area ───────────────────────────────────────────────────
    Item {
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // ══════════════════════════════════════════════════════════════════════
        // TAB 0: Smart Scratchpad (Soulver / Numi style)
        // ══════════════════════════════════════════════════════════════════════
        Item {
            id: scratchTab
            anchors.fill: parent
            visible: window.currentTab === 0

            property var evalResults: CalcEngine.evaluateDocument(editorArea.text)

            // Split View: Editor on Left, Results on Right
            RowLayout {
                anchors.fill: parent
                anchors.bottomMargin: 28
                spacing: 0

                // Left: Code Editor
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: window.colBg

                    Flickable {
                        id: editorFlick
                        anchors.fill: parent
                        anchors.margins: 12
                        contentWidth: width
                        contentHeight: editorArea.implicitHeight + 40
                        clip: true

                        TextArea {
                            id: editorArea
                            width: parent.width
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 13
                            color: window.colFg
                            selectionColor: Qt.rgba(122/255, 162/255, 247/255, 0.35)
                            selectedTextColor: "#ffffff"
                            wrapMode: TextEdit.Wrap
                            background: null
                            selectByMouse: true
                            text: "# Welcome to b1air-calc Smart Scratchpad\nsalary = 5000\nbonus = 750\nrent = 1200\ngroceries = 450\ntax = 18%\n\nnet_income = (salary + bonus - rent - groceries) - tax\n\n# Quick conversions & percentages\n20% of 850\n150 + 20%\n2048 mb in gb\n100 km in miles\n\ntotal"

                            onTextChanged: {
                                scratchTab.evalResults = CalcEngine.evaluateDocument(text);
                            }
                        }
                    }
                }

                // Vertical Divider
                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: window.colBorder
                }

                // Right: Results Column
                Rectangle {
                    Layout.preferredWidth: 240
                    Layout.fillHeight: true
                    color: window.colDark

                    Flickable {
                        id: resultsFlick
                        anchors.fill: parent
                        anchors.margins: 12
                        contentHeight: resultsColumn.implicitHeight + 40
                        contentY: editorFlick.contentY // sync scrolling with editor
                        clip: true

                        Column {
                            id: resultsColumn
                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: scratchTab.evalResults
                                delegate: Item {
                                    width: resultsColumn.width
                                    height: 20
                                    visible: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: rowArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.15) : (modelData.isTotal ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent")

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6

                                            Text {
                                                text: modelData.varName ? (modelData.varName + ":") : ""
                                                font.family: "JetBrainsMono Nerd Font, monospace"
                                                font.pixelSize: 11
                                                color: window.colCyan
                                                visible: text !== ""
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: modelData.result
                                                font.family: "JetBrainsMono Nerd Font, monospace"
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: modelData.isTotal ? window.colBlue : window.colPurple
                                            }

                                            Text {
                                                text: "📋"
                                                font.pixelSize: 10
                                                opacity: rowArea.containsMouse ? 1.0 : 0.0
                                            }
                                        }

                                        MouseArea {
                                            id: rowArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                editorArea.copy();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Summary Status Bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                color: "#13131a"
                border.color: window.colBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        text: "💡 Type math expressions, variables (x = 10), or percentages (+ 20%)"
                        font.family: "Fira Sans, sans-serif"
                        font.pixelSize: 11
                        color: window.colDim
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Lines: " + editorArea.lineCount
                        font.family: "Fira Sans SemiBold, sans-serif"
                        font.pixelSize: 11
                        color: "#a9b1d6"
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // TAB 1: Programmer Radix Converter
        // ══════════════════════════════════════════════════════════════════════
        Item {
            id: progTab
            anchors.fill: parent
            visible: window.currentTab === 1
            anchors.margins: 16

            property var baseData: CalcEngine.convertBase(progInput.text, 10)

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // Input Field
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 8
                    color: window.colDark
                    border.color: progInput.activeFocus ? window.colBlue : window.colBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text { text: "🔢"; font.pixelSize: 14 }

                        TextInput {
                            id: progInput
                            Layout.fillWidth: true
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 15
                            font.bold: true
                            color: window.colFg
                            selectByMouse: true
                            text: "255"
                            onTextChanged: {
                                progTab.baseData = CalcEngine.convertBase(text, 10);
                            }
                        }
                    }
                }

                // 4 Radix Cards Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    // HEX Card
                    Rectangle {
                        Layout.fillWidth: true; height: 60; radius: 8
                        color: window.colDark; border.color: window.colBorder; border.width: 1
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: "HEXADECIMAL"; font.pixelSize: 10; font.bold: true; color: window.colDim }
                            Text { text: progTab.baseData.hex || "0x0"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 16; font.bold: true; color: window.colBlue }
                        }
                    }

                    // DEC Card
                    Rectangle {
                        Layout.fillWidth: true; height: 60; radius: 8
                        color: window.colDark; border.color: window.colBorder; border.width: 1
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: "DECIMAL"; font.pixelSize: 10; font.bold: true; color: window.colDim }
                            Text { text: progTab.baseData.dec || "0"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 16; font.bold: true; color: window.colPurple }
                        }
                    }

                    // OCT Card
                    Rectangle {
                        Layout.fillWidth: true; height: 60; radius: 8
                        color: window.colDark; border.color: window.colBorder; border.width: 1
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: "OCTAL"; font.pixelSize: 10; font.bold: true; color: window.colDim }
                            Text { text: progTab.baseData.oct || "0o0"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 16; font.bold: true; color: window.colCyan }
                        }
                    }

                    // ASCII Card
                    Rectangle {
                        Layout.fillWidth: true; height: 60; radius: 8
                        color: window.colDark; border.color: window.colBorder; border.width: 1
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: "ASCII / CHAR"; font.pixelSize: 10; font.bold: true; color: window.colDim }
                            Text { text: "'" + (progTab.baseData.ascii || "") + "'"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 16; font.bold: true; color: window.colGreen }
                        }
                    }
                }

                // BIN Card (Full width with grouped bits)
                Rectangle {
                    Layout.fillWidth: true
                    height: 65
                    radius: 8
                    color: window.colDark
                    border.color: window.colBorder
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "BINARY (64-BIT / NIBBLE GROUPED)"; font.pixelSize: 10; font.bold: true; color: window.colDim }
                        Text {
                            text: progTab.baseData.bin || "0b 0000"
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 14
                            font.bold: true
                            color: window.colOrange
                        }
                    }
                }

                // Bitwise Quick Operations Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["NOT (~)", "<< 1", ">> 1", "<< 4", ">> 4", "Clear (0)"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 6
                            color: opArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : Qt.rgba(36/255, 40/255, 59/255, 0.60)
                            border.color: window.colBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: window.colFg
                            }

                            MouseArea {
                                id: opArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let v = parseInt(progInput.text) || 0;
                                    if (modelData === "NOT (~)") progInput.text = "" + (~v);
                                    else if (modelData === "<< 1") progInput.text = "" + (v << 1);
                                    else if (modelData === ">> 1") progInput.text = "" + (v >> 1);
                                    else if (modelData === "<< 4") progInput.text = "" + (v << 4);
                                    else if (modelData === ">> 4") progInput.text = "" + (v >> 4);
                                    else if (modelData === "Clear (0)") progInput.text = "0";
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // TAB 2: Converters & Utilities (Base64, Timestamp)
        // ══════════════════════════════════════════════════════════════════════
        Item {
            anchors.fill: parent
            visible: window.currentTab === 2
            anchors.margins: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                // Base64 Section
                Rectangle {
                    Layout.fillWidth: true
                    height: 140
                    radius: 8
                    color: window.colDark
                    border.color: window.colBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text { text: "📦 BASE64 ENCODER / DECODER"; font.pixelSize: 11; font.bold: true; color: window.colBlue }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: b64Input
                                Layout.fillWidth: true
                                placeholderText: "Plain text input..."
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 12
                                color: window.colFg
                                background: Rectangle { color: window.colBg; radius: 6; border.color: window.colBorder }
                            }

                            Button {
                                text: "Encode"
                                onClicked: b64Output.text = CalcEngine.toBase64(b64Input.text)
                            }
                            Button {
                                text: "Decode"
                                onClicked: b64Output.text = CalcEngine.fromBase64(b64Input.text)
                            }
                        }

                        TextField {
                            id: b64Output
                            Layout.fillWidth: true
                            placeholderText: "Result..."
                            readOnly: true
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 12
                            color: window.colGreen
                            background: Rectangle { color: window.colBg; radius: 6; border.color: window.colBorder }
                        }
                    }
                }

                // Epoch Timestamp Section
                Rectangle {
                    Layout.fillWidth: true
                    height: 140
                    radius: 8
                    color: window.colDark
                    border.color: window.colBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text { text: "⏰ UNIX TIMESTAMP CONVERTER"; font.pixelSize: 11; font.bold: true; color: window.colPurple }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: tsInput
                                Layout.fillWidth: true
                                text: "" + CalcEngine.currentTimestamp()
                                font.family: "JetBrainsMono Nerd Font, monospace"
                                font.pixelSize: 12
                                color: window.colFg
                                background: Rectangle { color: window.colBg; radius: 6; border.color: window.colBorder }
                            }

                            Button {
                                text: "Now"
                                onClicked: tsInput.text = "" + CalcEngine.currentTimestamp()
                            }
                        }

                        Text {
                            text: "Human Date: " + CalcEngine.formatTimestamp(parseInt(tsInput.text) || 0)
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 13
                            font.bold: true
                            color: window.colOrange
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
