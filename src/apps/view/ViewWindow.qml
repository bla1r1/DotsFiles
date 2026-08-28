import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: ViewBackend.fileName ? ("b1air-view — " + ViewBackend.fileName) : "b1air-view"
    width: 960
    height: 640
    minimumWidth: 500
    minimumHeight: 400
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
    readonly property color colFg: "#c0caf5"
    readonly property color colDim: "#6b739b"

    property real zoomFactor: 1.0
    property int rotationAngle: 0
    property bool showFilmstrip: true

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: 14
        color: "#101014"
        border.color: window.colBorder
        border.width: 1
        clip: true

        // Keyboard Shortcuts
        Item {
            focus: true
            Keys.onLeftPressed: ViewBackend.previous()
            Keys.onRightPressed: ViewBackend.next()
            Keys.onEscapePressed: window.close()
            Keys.onSpacePressed: ViewBackend.next()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Top Header Toolbar (40px) ────────────────────────────────────
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

                    // Image Dimensions Badge
                    Rectangle {
                        width: dimText.implicitWidth + 12
                        height: 20
                        radius: 4
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                        visible: ViewBackend.imageWidth > 0

                        Text {
                            id: dimText
                            anchors.centerIn: parent
                            text: ViewBackend.imageWidth + " × " + ViewBackend.imageHeight + "  •  " + ViewBackend.fileSize
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 10
                            color: window.colDim
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Viewer Controls: Zoom In, Zoom Out, Reset, Rotate, Filmstrip Toggle, Wallpaper
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        CtrlBtn { icon: "󰅖"; tip: "Zoom Out"; onClicked: window.zoomFactor = Math.max(0.2, window.zoomFactor - 0.25) }
                        Rectangle {
                            width: zoomText.implicitWidth + 10; height: 26; radius: 4
                            color: "transparent"
                            Text { id: zoomText; anchors.centerIn: parent; text: Math.round(window.zoomFactor * 100) + "%"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 10; color: window.colDim }
                        }
                        CtrlBtn { icon: "󰐕"; tip: "Zoom In"; onClicked: window.zoomFactor = Math.min(5.0, window.zoomFactor + 0.25) }
                        CtrlBtn { icon: "󰑐"; tip: "Reset View"; onClicked: { window.zoomFactor = 1.0; window.rotationAngle = 0; } }
                        CtrlBtn { icon: "󰑓"; tip: "Rotate 90°"; onClicked: window.rotationAngle = (window.rotationAngle + 90) % 360 }
                        CtrlBtn { icon: "󰎆"; tip: "Set Wallpaper"; onClicked: ViewBackend.setWallpaper() }
                        CtrlBtn { icon: "󰋩"; tip: "Toggle Filmstrip"; active: window.showFilmstrip; onClicked: window.showFilmstrip = !window.showFilmstrip }
                    }
                }
            }

            // ── Main Image Canvas ────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: imageFlick
                    anchors.fill: parent
                    contentWidth: Math.max(width, mainImage.width * window.zoomFactor)
                    contentHeight: Math.max(height, mainImage.height * window.zoomFactor)
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        width: imageFlick.contentWidth
                        height: imageFlick.contentHeight

                        Image {
                            id: mainImage
                            anchors.centerIn: parent
                            source: ViewBackend.filePath ? ("file://" + ViewBackend.filePath) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            rotation: window.rotationAngle
                            scale: window.zoomFactor

                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on rotation { NumberAnimation { duration: 150 } }
                        }
                    }

                    // Mouse Wheel Zoom
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) window.zoomFactor = Math.min(5.0, window.zoomFactor + 0.15);
                            else window.zoomFactor = Math.max(0.2, window.zoomFactor - 0.15);
                        }
                    }
                }

                // Left Arrow Overlay (Prev)
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 18
                    color: prevArrArea.containsMouse ? Qt.rgba(26/255, 27/255, 38/255, 0.85) : Qt.rgba(26/255, 27/255, 38/255, 0.45)
                    border.color: window.colBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰁍"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: window.colFg }
                    MouseArea { id: prevArrArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ViewBackend.previous() }
                }

                // Right Arrow Overlay (Next)
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 18
                    color: nextArrArea.containsMouse ? Qt.rgba(26/255, 27/255, 38/255, 0.85) : Qt.rgba(26/255, 27/255, 38/255, 0.45)
                    border.color: window.colBorder
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰁔"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: window.colFg }
                    MouseArea { id: nextArrArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ViewBackend.next() }
                }
            }

            // ── Bottom Filmstrip Thumbnail Strip (Optional, 70px) ─────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: window.colSidebar
                border.color: window.colBorder
                border.width: 1
                visible: window.showFilmstrip

                ListView {
                    id: filmstripList
                    anchors.fill: parent
                    anchors.margins: 6
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    model: ViewBackend.galleryFiles

                    delegate: Rectangle {
                        width: 58; height: 58; radius: 6
                        color: isCur ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : (thumbArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")
                        border.color: isCur ? window.colBlue : "transparent"
                        border.width: 1

                        readonly property bool isCur: modelData.path === ViewBackend.filePath

                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + modelData.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(60, 60)
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
    }

    component CtrlBtn: Rectangle {
        id: cb
        property string icon: ""
        property string tip: ""
        property bool active: false
        signal clicked()

        width: 26; height: 26; radius: 5
        color: cb.active ? window.colBlue : (cbArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.12) : "transparent")
        border.color: cb.active ? "transparent" : window.colBorder
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: cb.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: cb.active ? "#101014" : (cbArea.containsMouse ? "#ffffff" : window.colFg)
        }

        MouseArea {
            id: cbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }
}
