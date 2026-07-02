import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Ui"
import "../Services"

// =============================================================================
// Control Center — one surface, four pages.
//
// Volume, Battery, Network and Music were four popups that overlapped heavily:
// BatteryPopup already carried volume and brightness sliders, so "quick tweak"
// had three separate homes with three different looks and three key bindings.
//
// The pages are the existing popup files, loaded unchanged. PopupShell.framed
// is false for them because the Center owns the window chrome — that is the
// whole edit those four files needed.
// =============================================================================

PopupShell {
    id: center

    property string page: "sound"

    readonly property var pages: [
        { id: "sound",   icon: "󰕾", label: "Звук",     src: "../volume/VolumePopup.qml" },
        { id: "power",   icon: "󰁹", label: "Питание",  src: "../battery/BatteryPopup.qml" },
        { id: "network", icon: "󰤨", label: "Сеть",     src: "../network/NetworkPopup.qml" },
        { id: "media",   icon: "󰎆", label: "Медиа",    src: "../music/MusicPopup.qml" }
    ]

    // Passed through to whichever page wants them: the notification list for
    // the power page, the wifi/bt tab for the network page.
    property var notifModel
    property string activeMode: ""

    function open(id) {
        if (center.pages.some(p => p.id === id))
            center.page = id;
    }

    readonly property var current: pages.find(p => p.id === center.page) || pages[0]

    onActiveModeChanged: {
        if (activeMode !== "" && pageLoader.item && pageLoader.item.activeMode !== undefined)
            pageLoader.item.activeMode = activeMode;
    }

    RowLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.lg)

        // ── Rail ─────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: Design.s(150)
            spacing: Design.s(Design.space.xs)

            Label {
                text: "Управление"
                role: "subhead"
                weight: Design.weight.semibold
                Layout.bottomMargin: Design.s(Design.space.md)
            }

            Repeater {
                model: center.pages

                Rectangle {
                    id: railRow
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(38)
                    radius: Design.s(Design.radius.ctl)

                    readonly property bool active: center.page === modelData.id
                    color: active ? Design.accent : (rowMa.containsMouse ? Design.veilStrong : "transparent")
                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Design.s(Design.space.md)
                        spacing: Design.s(Design.space.md)

                        Icon {
                            text: modelData.icon
                            role: "body"
                            color: railRow.active ? Design.onAccent : Design.textDim
                        }
                        Label {
                            text: modelData.label
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            weight: railRow.active ? Design.weight.semibold : Design.weight.regular
                            color: railRow.active ? Design.onAccent : Design.textDim
                        }
                    }

                    Clickable {
                        id: rowMa
                        onClicked: center.page = modelData.id
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Design.border
            color: Design.line
        }

        // ── Page ─────────────────────────────────────────────────────────────
        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            asynchronous: true
            source: center.current.src

            onLoaded: {
                // The Center owns the chrome; the page must not draw its own.
                item.framed = false;
                if (item.notifModel !== undefined)
                    item.notifModel = center.notifModel;
                if (center.activeMode !== "" && item.activeMode !== undefined)
                    item.activeMode = center.activeMode;
            }

            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
        }
    }
}
