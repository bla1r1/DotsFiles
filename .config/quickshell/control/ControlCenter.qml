import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Ui"
import "../Services"
import "."

// =============================================================================
// Control Center — the one-click hub, with the mini-settings pages behind it.
// =============================================================================

PopupShell {
    id: center

    padding: Design.space.lg

    property string currentView: (center.page && center.page !== "") ? center.page : "main"

    onPageChanged: currentView = (center.page && center.page !== "") ? center.page : "main"

    // Escape used to close the window from inside a sub-page, so the only way
    // back to the tiles was to reopen the panel.
    escapeHook: function () {
        if (center.currentView === "main")
            return false;
        center.currentView = "main";
        return true;
    }

    function openFull(name) {
        Quickshell.execDetached(["qs", "-p", center.configDir + "/Main.qml",
                                 "ipc", "call", "main", "open", name, ""]);
    }

    // ── Do Not Disturb ───────────────────────────────────────────────────────
    // The flag lives in ~/.cache/qs_dnd, which NotificationPopups reads. It was
    // written but never read back, so the tile showed "Off" every time the panel
    // opened, whatever notifications were actually doing.
    property bool dnd: false
    property bool _dndLoaded: false

    Process {
        running: true
        command: ["sh", "-c", "cat ~/.cache/qs_dnd 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                center.dnd = this.text.trim() === "1";
                center._dndLoaded = true;
            }
        }
    }

    onDndChanged: {
        if (!center._dndLoaded)
            return;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p ~/.cache && echo '" + (dnd ? "1" : "0") + "' > ~/.cache/qs_dnd"]);
    }

    // ── Tile geometry ────────────────────────────────────────────────────────
    // A two-column grid with an odd number of tiles leaves a hole. The last
    // visible tile fills it instead — the old version tried to decide this per
    // tile and the power branch could never be true.
    readonly property int visibleTileCount: (wifiTile.visible ? 1 : 0) + (btTile.visible ? 1 : 0)
                                          + (dndTile.visible ? 1 : 0) + (nightTile.visible ? 1 : 0)
                                          + (powerTile.visible ? 1 : 0)
    readonly property Item lastTile: powerTile.visible ? powerTile : nightTile

    // Only worth filling a hole when there are two columns to leave one in —
    // a columnSpan of 2 in a one-column grid collapses the item to nothing.
    function spanOf(tile) {
        return (center.visibleTileCount > 1 && center.visibleTileCount % 2 === 1
                && tile === center.lastTile) ? 2 : 1;
    }

    // A quick-toggle tile: circle toggles, the rest of the tile opens the page.
    component QuickTile: Tile {
        id: tile

        property string glyph: ""
        property string title: ""
        property string detail: ""
        property color glyphTone: tile.on ? tile.activeTextColor : Design.textDim
        property bool circleToggles: true
        // Only a tile that opens a page shows a chevron. Focus does not.
        property string trailingGlyph: "\u{f0142}"

        signal toggled()

        implicitHeight: Design.s(Design.size.tile)
        interactive: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: Design.s(Design.space.sm)
            spacing: Design.s(Design.space.sm)

            Rectangle {
                Layout.preferredWidth: Design.s(Design.size.knob)
                Layout.preferredHeight: Design.s(Design.size.knob)
                radius: width / 2
                color: tile.on ? Design.tint(tile.activeTextColor, 0.22) : Design.sunken
                Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                Icon {
                    anchors.centerIn: parent
                    text: tile.glyph
                    role: "subhead"
                    color: tile.glyphTone
                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                }

                // Declared inside the tile's own children, so it sits above the
                // tile-wide MouseArea and wins the click.
                Clickable {
                    enabled: tile.circleToggles
                    onClicked: tile.toggled()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: tile.title
                    role: "caption"
                    weight: Design.weight.bold
                    color: tile.on ? tile.activeTextColor : Design.text
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Label {
                    text: tile.detail
                    role: "caption"
                    color: tile.on ? Design.tint(tile.activeTextColor, 0.85) : Design.textDim
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            Icon {
                visible: tile.trailingGlyph !== ""
                text: tile.trailingGlyph
                role: "caption"
                color: tile.on ? Design.tint(tile.activeTextColor, 0.6) : Design.textFaint
            }
        }
    }

    // ── Main dashboard ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)
        visible: center.currentView === "main"

        // ── 1. Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Icon {
                text: "\u{f0067}"   // grid
                role: "subhead"
                color: Design.accent
            }

            Label {
                text: "Control Center"
                role: "subhead"
                weight: Design.weight.bold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            BatteryPill {
                Layout.alignment: Qt.AlignVCenter
                onClicked: center.currentView = "power"
            }

            IconButton {
                icon: Notifications.history.count > 0 ? "\u{f009a}" : "\u{f009b}"
                bordered: true
                hoverTone: Design.accent
                onClicked: center.currentView = (center.currentView === "notifications" ? "main" : "notifications")
            }

            IconButton {
                icon: "\u{f0493}"   // cog
                bordered: true
                onClicked: center.openFull("settings")
            }
        }

        // ── 2. Quick toggles ─────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: center.visibleTileCount === 1 ? 1 : 2
            rowSpacing: Design.s(Design.space.sm)
            columnSpacing: Design.s(Design.space.sm)

            QuickTile {
                id: wifiTile
                Layout.fillWidth: true
                Layout.columnSpan: center.spanOf(wifiTile)
                visible: Network.hasWifi
                glyph: "\u{f0928}"
                title: "Wi-Fi"
                on: Network.wifi.power === "on"
                activeColor: Design.blue
                detail: Network.wifi.connected ? Network.wifi.connected.ssid
                                               : (on ? "Not connected" : "Off")
                onToggled: Network.toggleWifi()
                onActivated: center.currentView = "wifi"
            }

            QuickTile {
                id: btTile
                Layout.fillWidth: true
                Layout.columnSpan: center.spanOf(btTile)
                visible: Network.hasBluetooth
                glyph: "\u{f00af}"
                title: "Bluetooth"
                on: Network.bluetooth.power === "on"
                activeColor: Design.mauve
                detail: Network.bluetooth.connected ? Network.bluetooth.connected.name
                                                    : (on ? "No device" : "Off")
                onToggled: Network.toggleBluetooth()
                onActivated: center.currentView = "bluetooth"
            }

            QuickTile {
                id: dndTile
                Layout.fillWidth: true
                Layout.columnSpan: center.spanOf(dndTile)
                glyph: Notifications.dnd ? "\u{f009b}" : "\u{f009a}"
                title: "Focus"
                on: Notifications.dnd
                activeColor: Design.peach
                detail: Notifications.dnd ? "Silenced" : "Active"
                trailingGlyph: ""
                onToggled: Notifications.toggleDnd()
                onActivated: Notifications.toggleDnd()
            }

            QuickTile {
                id: nightTile
                Layout.fillWidth: true
                Layout.columnSpan: center.spanOf(nightTile)
                glyph: "\u{f0599}"
                title: "Night Light"
                on: Settings.nightLightEnabled !== undefined ? Settings.nightLightEnabled : false
                activeColor: Design.yellow
                glyphTone: on ? Design.yellow : Design.textDim
                detail: on ? "Warm (" + (Settings.nightLightTemp || 4000) + "K)" : "Off"
                onToggled: {
                    const next = !(Settings.nightLightEnabled !== undefined ? Settings.nightLightEnabled : false);
                    Settings.set("nightLightEnabled", next);
                    const temp = Settings.nightLightTemp || 4000;
                    if (!next) {
                        Quickshell.execDetached(["bash", "-c", "killall wlsunset gammastep 2>/dev/null || true"]);
                    } else {
                        Quickshell.execDetached(["bash", "-c",
                            "killall wlsunset gammastep 2>/dev/null || true; wlsunset -t " + temp + " -T " + temp + " 2>/dev/null || gammastep -O " + temp + " 2>/dev/null &"
                        ]);
                    }
                }
                onActivated: center.openFull("nightlight")
            }

            QuickTile {
                id: powerTile
                Layout.fillWidth: true
                Layout.columnSpan: center.spanOf(powerTile)
                visible: Power.hasBattery || Power.hasProfiles
                glyph: Power.profile === "performance" ? "\u{f0e4}"
                     : (Power.profile === "power-saver" ? "\u{f0084}" : "\u{f0241}")
                title: "Power Mode"
                on: false
                activeColor: powerTile.profileTone
                glyphTone: powerTile.profileTone
                detail: Power.profile === "performance" ? "Performance"
                      : (Power.profile === "power-saver" ? "Power Saver" : "Balanced")

                readonly property color profileTone: Power.profile === "performance" ? Design.red
                    : (Power.profile === "power-saver" ? Design.green : Design.sapphire)

                onToggled: Power.setProfile(Power.profile === "balanced" ? "performance"
                                          : (Power.profile === "performance" ? "power-saver" : "balanced"))
                onActivated: center.currentView = "power"
            }
        }

        // ── 3. Sliders ───────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Slider {
                visible: Power.hasBacklight
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(Design.size.ctl)
                value: Power.brightness
                tone: Design.yellow
                icon: "\u{f00df}"
                label: "Brightness"
                onMoved: pct => Power.setBrightness(pct)
            }

            // No sink, no slider. A volume control with nothing behind it is a
            // dead control, not information.
            RowLayout {
                visible: Audio.defaultSink !== null
                Layout.fillWidth: true
                spacing: Design.s(Design.space.xs)

                Slider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(Design.size.ctl)
                    value: Audio.defaultSink ? Audio.defaultSink.volume : 0
                    muted: Audio.defaultSink ? Audio.defaultSink.mute : false
                    tone: Design.sapphire
                    icon: (Audio.defaultSink && Audio.defaultSink.mute) ? "\u{f075f}" : "\u{f057f}"
                    label: "Volume"
                    iconClickable: true
                    // Audio.toggleMute / setVolume take (type, id, …). Called
                    // with the device object they resolved no node at all, so
                    // this slider moved and nothing happened.
                    onIconClicked: if (Audio.defaultSink) Audio.toggleMute("sink", Audio.defaultSink.id)
                    onMoved: pct => Audio.applyVolume("sink", Audio.defaultSink, pct)
                }

                Rectangle {
                    Layout.preferredWidth: Design.s(Design.size.ctl)
                    Layout.preferredHeight: Design.s(Design.size.ctl)
                    radius: Design.s(Design.radius.ctl)
                    color: soundBtnMa.containsMouse ? Design.glassHover : Design.glassCard
                    border.color: Design.glassBorder
                    border.width: Design.border
                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                    Icon {
                        anchors.centerIn: parent
                        text: "\u{f0142}"
                        role: "caption"
                        color: soundBtnMa.containsMouse ? Design.accent : Design.textDim
                    }

                    Clickable { id: soundBtnMa; onClicked: center.currentView = "sound" }
                }
            }
        }

        // ── 4. Media ─────────────────────────────────────────────────────────
        Rectangle {
            id: mediaCard
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(Design.size.media)
            radius: Design.s(Design.radius.card)
            color: Design.glassCard
            border.color: Design.glassBorder
            border.width: Design.border

            RowLayout {
                anchors.fill: parent
                anchors.margins: Design.s(Design.space.md)
                spacing: Design.s(Design.space.md)

                Rectangle {
                    Layout.preferredWidth: Design.s(Design.size.art)
                    Layout.preferredHeight: Design.s(Design.size.art)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.sunken
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Media.track.artUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !Media.track.artUrl
                        text: "\u{f0025}"
                        role: "subhead"
                        color: Media.playing ? Design.accent : Design.textFaint
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)

                    Label {
                        text: Media.track.title || (Media.hasPlayer ? "Nothing playing" : "No media player")
                        weight: Design.weight.semibold
                        color: Media.hasPlayer ? Design.text : Design.textDim
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: Media.track.artist || (Media.hasPlayer ? "Press play to resume" : "Start one to control it here")
                        role: "caption"
                        dim: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // The card-wide "open the player" area, sized to the text
                    // rather than to `parent.width - 120`, which at any other
                    // scale reached under the transport buttons.
                    Clickable {
                        enabled: Media.hasPlayer
                        onClicked: center.openFull("music")
                    }
                }

                RowLayout {
                    spacing: Design.s(Design.space.xs)
                    opacity: Media.hasPlayer ? Design.opacity.full : Design.opacity.disabled
                    enabled: Media.hasPlayer
                    Behavior on opacity { NumberAnimation { duration: Design.duration.fast } }

                    IconButton {
                        icon: "\u{f04ae}"
                        role: "caption"
                        hoverTone: Design.text
                        onClicked: Media.previous()
                    }

                    Rectangle {
                        Layout.preferredWidth: Design.s(Design.size.knob)
                        Layout.preferredHeight: Design.s(Design.size.knob)
                        radius: width / 2
                        color: Design.accent

                        scale: playMa.pressed ? 0.92 : 1.0
                        Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Design.easing } }

                        Icon {
                            anchors.centerIn: parent
                            text: Media.playing ? "\u{f03e4}" : "\u{f040a}"
                            role: "body"
                            color: Design.contrastOn(Design.accent)
                        }

                        Clickable { id: playMa; onClicked: Media.playPause() }
                    }

                    IconButton {
                        icon: "\u{f04ad}"
                        role: "caption"
                        hoverTone: Design.text
                        onClicked: Media.next()
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // ── 5. Session actions ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f033e}"
                label: "Lock"
                onActivated: Quickshell.execDetached(["sh", "-c", "swaylock -f 2>/dev/null || loginctl lock-session"])
            }

            ActionButton {
                icon: "\u{f04b2}"
                label: "Sleep"
                onActivated: Quickshell.execDetached(["systemctl", "suspend"])
            }

            ActionButton {
                icon: "\u{f0709}"
                label: "Reboot"
                iconTone: Design.peach
                tone: Design.peach
                destructive: true
                onActivated: Quickshell.execDetached(["systemctl", "reboot"])
            }

            ActionButton {
                icon: "\u{f0425}"
                label: "Off"
                iconTone: Design.danger
                tone: Design.danger
                destructive: true
                onActivated: Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    }

    // ── Mini-settings pages ──────────────────────────────────────────────────
    WifiMiniView {
        anchors.fill: parent
        visible: center.currentView === "wifi"
        onBackClicked: center.currentView = "main"
        onOpenFullSettings: center.openFull("settings")
    }

    BluetoothMiniView {
        anchors.fill: parent
        visible: center.currentView === "bluetooth"
        onBackClicked: center.currentView = "main"
        onOpenFullSettings: center.openFull("settings")
    }

    SoundMiniView {
        anchors.fill: parent
        visible: center.currentView === "sound"
        onBackClicked: center.currentView = "main"
        onOpenFullSettings: center.openFull("settings")
    }

    PowerMiniView {
        anchors.fill: parent
        visible: center.currentView === "power"
        onBackClicked: center.currentView = "main"
        onOpenFullSettings: center.openFull("settings")
    }

    NotificationsMiniView {
        anchors.fill: parent
        visible: center.currentView === "notifications"
        onBackClicked: center.currentView = "main"
    }

    Component.onCompleted: {
        Audio.acquire(); Power.acquire(); Media.acquire(); Network.acquire();
    }
    Component.onDestruction: {
        Audio.release(); Power.release(); Media.release(); Network.release();
    }
}
