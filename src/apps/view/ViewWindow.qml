import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: ViewBackend.fileName ? ("b1air-view — " + ViewBackend.fileName) : "b1air-view"
    width: 900
    height: 620
    minimumWidth: 500
    minimumHeight: 400
    visible: true
    color: "#101014"

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

    property real zoomFactor: 1.0
    property int rotationAngle: 0
    property bool showFilmstrip: true
    property bool showInfoPopup: false

    // Keyboard Shortcuts
    Item {
        focus: true
        Keys.onLeftPressed: ViewBackend.previous()
        Keys.onRightPressed: ViewBackend.next()
        Keys.onEscapePressed: {
            if (window.showInfoPopup) window.showInfoPopup = false;
            else window.close();
        }
        Keys.onSpacePressed: ViewBackend.next()
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

            // App Icon & File Name
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter
                Text {
                    text: "󰋩"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: window.colBlue
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: ViewBackend.fileName || "No Image Open"
                    font.family: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: window.colFg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.fillWidth: true }

            // Metadata Chips (Resolution, Size, Index)
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: resText.implicitWidth + 12
                    height: 20
                    radius: 5
                    color: Qt.rgba(36/255, 40/255, 59/255, 0.60)
                    Text {
                        id: resText
                        anchors.centerIn: parent
                        text: ViewBackend.imageResolution
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 10
                        font.bold: true
                        color: window.colCyan
                    }
                }

                Rectangle {
                    width: sizeText.implicitWidth + 12
                    height: 20
                    radius: 5
                    color: Qt.rgba(36/255, 40/255, 59/255, 0.60)
                    Text {
                        id: sizeText
                        anchors.centerIn: parent
                        text: ViewBackend.fileSize
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 10
                        font.bold: true
                        color: window.colPurple
                    }
                }

                Rectangle {
                    width: idxText.implicitWidth + 12
                    height: 20
                    radius: 5
                    color: Qt.rgba(36/255, 40/255, 59/255, 0.60)
                    Text {
                        id: idxText
                        anchors.centerIn: parent
                        text: (ViewBackend.fileIndex + 1) + " / " + ViewBackend.totalFiles
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 10
                        font.bold: true
                        color: window.colFg
                    }
                }
            }
        }
    }

    // ── Main Image Canvas & Viewer ──────────────────────────────────────────
    Item {
        id: canvasArea
        anchors.top: headerBar.bottom
        anchors.bottom: window.showFilmstrip ? filmstripBar.top : parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true

        Flickable {
            id: flickable
            anchors.fill: parent
            contentWidth: Math.max(canvasArea.width, canvasArea.width * window.zoomFactor)
            contentHeight: Math.max(canvasArea.height, canvasArea.height * window.zoomFactor)
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: imgContainer
                width: flickable.contentWidth
                height: flickable.contentHeight

                Image {
                    id: mainImage
                    anchors.centerIn: parent
                    width: canvasArea.width
                    height: canvasArea.height
                    sourceSize: Qt.size(3840, 2160)
                    source: ViewBackend.currentPath ? ("file://" + ViewBackend.currentPath) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    scale: window.zoomFactor
                    rotation: window.rotationAngle

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on rotation { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                drag.target: imgContainer
                drag.axis: Drag.XAndYAxis
                hoverEnabled: true

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        window.zoomFactor = Math.min(window.zoomFactor * 1.15, 8.0);
                    } else if (wheel.angleDelta.y < 0) {
                        window.zoomFactor = Math.max(window.zoomFactor / 1.15, 0.15);
                    }
                }

                onDoubleClicked: {
                    window.zoomFactor = 1.0;
                    window.rotationAngle = 0;
                }
            }
        }

        // ── Floating Bottom Control Island (Floating Pill) ──────────────────
        Rectangle {
            id: floatingControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            height: 38
            width: ctrlRow.implicitWidth + 24
            radius: 12
            color: Qt.rgba(26/255, 27/255, 38/255, 0.88)
            border.color: window.colBorder
            border.width: 1
            z: 20

            Row {
                id: ctrlRow
                anchors.centerIn: parent
                spacing: 6

                // Previous Image
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: prevArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: ViewBackend.hasPrevious ? window.colFg : window.colDim
                    }
                    MouseArea {
                        id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: ViewBackend.hasPrevious
                        onClicked: ViewBackend.previous()
                    }
                }

                // Next Image
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: nextArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅗"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: ViewBackend.hasNext ? window.colFg : window.colDim
                    }
                    MouseArea {
                        id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: ViewBackend.hasNext
                        onClicked: ViewBackend.next()
                    }
                }

                Rectangle { width: 1; height: 18; color: window.colBorder; anchors.verticalCenter: parent.verticalCenter }

                // Zoom Out
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: zmOutArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰐴"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colFg }
                    MouseArea {
                        id: zmOutArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: window.zoomFactor = Math.max(window.zoomFactor / 1.25, 0.15)
                    }
                }

                // Zoom Level Pill
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(window.zoomFactor * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font, monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: window.colBlue
                }

                // Zoom In
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: zmInArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰐕"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colFg }
                    MouseArea {
                        id: zmInArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: window.zoomFactor = Math.min(window.zoomFactor * 1.25, 8.0)
                    }
                }

                // 1:1 Reset
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: resetArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰑐"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colFg }
                    MouseArea {
                        id: resetArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { window.zoomFactor = 1.0; window.rotationAngle = 0; }
                    }
                }

                Rectangle { width: 1; height: 18; color: window.colBorder; anchors.verticalCenter: parent.verticalCenter }

                // Rotate Right
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: rotArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰑓"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; color: window.colFg }
                    MouseArea {
                        id: rotArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: window.rotationAngle = (window.rotationAngle + 90) % 360
                    }
                }

                // Set Wallpaper
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: wallArea.containsMouse ? Qt.rgba(115/255, 218/255, 202/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰋩"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colGreen }
                    MouseArea {
                        id: wallArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ViewBackend.setWallpaper()
                    }
                }

                // Toggle Filmstrip
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: filmArea.containsMouse ? Qt.rgba(187/255, 154/255, 247/255, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰎆"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colPurple }
                    MouseArea {
                        id: filmArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: window.showFilmstrip = !window.showFilmstrip
                    }
                }
            }
        }
    }

    // ── Collapsible Filmstrip Carousel ──────────────────────────────────────
    Rectangle {
        id: filmstripBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: window.showFilmstrip ? 70 : 0
        visible: height > 0
        color: window.colDark
        border.color: window.colBorder
        border.width: 1
        z: 15

        Behavior on height { NumberAnimation { duration: 150 } }

        ListView {
            id: filmstripView
            anchors.fill: parent
            anchors.margins: 6
            orientation: ListView.Horizontal
            spacing: 8
            model: ViewBackend.filesInDir
            clip: true

            delegate: Rectangle {
                width: 76
                height: 56
                radius: 6
                color: modelData.path === ViewBackend.currentPath ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : (thumbArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "#13131a")
                border.color: modelData.path === ViewBackend.currentPath ? window.colBlue : window.colBorder
                border.width: modelData.path === ViewBackend.currentPath ? 2 : 1

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: "file://" + modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MouseArea {
                    id: thumbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ViewBackend.openFile(modelData.path)
                }
            }
        }
    }
}
