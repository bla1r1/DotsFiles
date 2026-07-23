import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Ui"
import "../Services"

// =============================================================================
// Control Center — a corner panel of tiles, in the shape macOS uses.
//
// The previous version was a 1120x780 window with a rail and four full pages
// inside it: four popups sharing a frame rather than one thing. A control
// centre is not a window you work in, it is a panel you flick open, change one
// value, and dismiss.
//
// So: 380x560 in the top-right corner, tiles instead of pages, and only the
// controls worth reaching for in two seconds. Nothing was deleted — a tile that
// summarises something opens the full view for it, which is the popup that
// already existed. Volume per application, the equaliser, Wi-Fi scanning, the
// battery history: all still there, one click away, and out of the way.
// =============================================================================

PopupShell {
    id: center

    padding: Design.space.lg

    property var notifModel
    property string activeMode: ""
    // Kept so an old `toggle:volume` still lands somewhere sensible; the panel
    // has no pages to switch between any more.
    property string page: "sound"

    function openFull(name) {
        Quickshell.execDetached(["qs", "-p", center.scriptDir + "/quickshell/Main.qml",
                                 "ipc", "call", "main", "open", name, ""]);
    }

    readonly property var sink: Audio.defaultSink
    readonly property var track: Media.track

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)

        // ── Header ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Label {
                text: "Control Centre"
                weight: Design.weight.semibold
                Layout.fillWidth: true
            }

            Label {
                text: Power.capacity + "%"
                role: "caption"
                color: Power.charging ? Design.ok
                     : (Power.capacity <= 20 ? Design.danger : Design.textDim)
            }

            Icon {
                text: "\u{f0493}"          // cog
                role: "body"
                color: gearMa.containsMouse ? Design.text : Design.textFaint
                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                Clickable { id: gearMa; onClicked: center.openFull("settings") }
            }
        }

        // ── Connectivity + two switches ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            // maximumHeight as well as preferred — same trap as the rail width:
            // a Layout hands out leftover space unless it is capped, and
            // `preferredHeight` alone does not cap anything.
            Layout.preferredHeight: Design.s(112)
            Layout.maximumHeight: Design.s(112)
            spacing: Design.s(Design.space.md)

            Tile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                interactive: true
                onActivated: center.openFull("netFull")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.md)
                    spacing: Design.s(Design.space.sm)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.s(Design.space.sm)
                        Icon {
                            text: "\u{f0928}"
                            role: "body"
                            color: Network.wifi.power === "on" ? Design.accent : Design.textFaint
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: "Wi-Fi"; role: "caption"; weight: Design.weight.semibold }
                            Label {
                                text: Network.wifi.connected ? Network.wifi.connected.ssid : "Off"
                                role: "caption"
                                dim: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.s(Design.space.sm)
                        Icon {
                            text: "\u{f00af}"
                            role: "body"
                            color: Network.bluetooth.power === "on" ? Design.accent : Design.textFaint
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: "Bluetooth"; role: "caption"; weight: Design.weight.semibold }
                            Label {
                                text: Network.bluetooth.connected ? Network.bluetooth.connected.name : "Off"
                                role: "caption"
                                dim: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: Design.s(112)
                Layout.maximumWidth: Design.s(112)
                Layout.fillHeight: true
                spacing: Design.s(Design.space.md)

                Tile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    interactive: true
                    on: center.dnd
                    onActivated: center.dnd = !center.dnd

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Design.s(Design.space.xs)
                        Icon {
                            text: "\u{f09a1}"
                            role: "body"
                            color: center.dnd ? Design.accentText : Design.textDim
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Focus"
                            role: "caption"
                            color: center.dnd ? Design.accentText : Design.textDim
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                Tile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    interactive: true
                    onActivated: center.openFull("powerFull")

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Design.s(Design.space.xs)
                        Icon {
                            text: "\u{f0241}"
                            role: "body"
                            color: Design.textDim
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: Power.profile === "performance" ? "Perf"
                                : (Power.profile === "power-saver" ? "Saver" : "Balanced")
                            role: "caption"
                            dim: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // ── Now playing ──────────────────────────────────────────────────────
        Tile {
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(64)
            Layout.maximumHeight: Design.s(64)
            visible: Media.hasPlayer
            interactive: true
            onActivated: center.openFull("mediaFull")

            RowLayout {
                anchors.fill: parent
                anchors.margins: Design.s(Design.space.md)
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: center.track.title || "Nothing playing"
                        weight: Design.weight.semibold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Label {
                        text: center.track.artist || ""
                        role: "caption"
                        dim: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Icon {
                    text: "\u{f04ae}"
                    role: "body"
                    color: Design.textDim
                    Clickable { onClicked: Media.previous() }
                }
                Icon {
                    text: Media.playing ? "\u{f03e4}" : "\u{f040a}"
                    role: "subhead"
                    Clickable { onClicked: Media.playPause() }
                }
                Icon {
                    text: "\u{f04ad}"
                    role: "body"
                    color: Design.textDim
                    Clickable { onClicked: Media.next() }
                }
            }
        }

        // ── Sliders ──────────────────────────────────────────────────────────
        // Labelled above rather than beside, the way macOS does it: the slider
        // gets the full width instead of losing a third to a caption.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            Label { text: "Display"; role: "caption"; dim: true }

            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(28)
                cornerRadius: Design.radius.pill
                value: Power.brightness
                minimum: 1
                tone: Design.warn
                onMoved: pct => Power.setBrightness(pct)
                onActiveChanged: Power.brightnessHeld = active
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.xs)

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Sound"; role: "caption"; dim: true; Layout.fillWidth: true }
                Label {
                    text: center.sink ? center.sink.description : "No device"
                    role: "caption"
                    color: Design.textFaint
                    elide: Text.ElideRight
                    Layout.maximumWidth: Design.s(170)
                }
            }

            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(28)
                cornerRadius: Design.radius.pill
                value: center.sink ? center.sink.volume : 0
                muted: center.sink ? center.sink.mute : false
                onMoved: pct => Audio.applyVolume("sink", center.sink, pct)
                onActiveChanged: Audio.hold(center.sink ? center.sink.id : "", active)
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Do Not Disturb is read and written as a file by the notification popups;
    // keep that contract until step 07 gives notifications a real owner.
    property bool dnd: false
    onDndChanged: Quickshell.execDetached(["sh", "-c",
        "mkdir -p ~/.cache && echo '" + (dnd ? "1" : "0") + "' > ~/.cache/qs_dnd"])

    Component.onCompleted: {
        Audio.acquire(); Power.acquire(); Media.acquire(); Network.acquire();
    }
    Component.onDestruction: {
        Audio.release(); Power.release(); Media.release(); Network.release();
    }
}
