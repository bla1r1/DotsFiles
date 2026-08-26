import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Ui"
import "../Services"
import "components" as Sections

// =============================================================================
// Settings — a rail and pages, not one long scroll.
//
// The eleven section components in settings/components/ were written for
// exactly this and then never wired to anything: nothing referenced them, and
// nothing did before this rework either. They are not dead weight, they are a
// half-built version of this window.
//
// Audio and Network are here, but only their durable half: the per-app mixer,
// per-device levels, saved Wi-Fi profiles and paired devices. "Make it louder"
// and "join this network" stay in the Control Center — the rule in
// docs/migration.md is that a popup changes state and settings change
// configuration, not that whole subsystems are missing from settings.
//
// Sections read and write Services/Settings directly rather than having values
// threaded through this file. Passing them down would rebuild, in miniature,
// the "every consumer keeps its own copy" problem the store exists to end.
// =============================================================================

PopupShell {
    id: app

    Component.onCompleted: if (!app.page) app.page = "user"

    readonly property var pages: [
        { id: "user",        icon: "\u{f007}",  label: "User Profile",     color: Design.mauve },
        { id: "interface",   icon: "\u{f0b60}", label: "Interface",        color: Design.blue },
        { id: "windows",     icon: "\u{f0379}", label: "Window & Gaps",    color: Design.sapphire },
        { id: "appearance",  icon: "\u{f0376}", label: "Appearance",       color: Design.mauve },
        { id: "monitors",    icon: "\u{f0379}", label: "Displays",         color: Design.sapphire },
        { id: "bar",         icon: "\u{f07e}",  label: "Top Bar (Waybar)", color: Design.blue },
        { id: "capture",     icon: "\u{f016d}", label: "Screenshots",      color: Design.pink },
        { id: "defaultapps", icon: "\u{f0ac}",  label: "Default Apps",     color: Design.teal },
        { id: "gamemode",    icon: "\u{f11b}",  label: "Game Mode",        color: Design.red },
        { id: "maintenance", icon: "\u{f0187}", label: "Maintenance",      color: Design.green },
        { id: "nightlight",  icon: "\u{f0599}", label: "Night Light",      color: Design.yellow },
        { id: "network",     icon: "\u{f0928}", label: "Network",          color: Design.lavender },
        { id: "remote",      icon: "\u{f0379}", label: "Remote Desktop",   color: Design.blue },
        { id: "bluetooth",   icon: "\u{f00af}", label: "Bluetooth",        color: Design.mauve },
        { id: "audio",       icon: "\u{f057e}", label: "Sound",            color: Design.teal },
        { id: "power",       icon: "\u{f0084}", label: "Power & Sleep",    color: Design.green },
        { id: "focus",       icon: "\u{f051e}", label: "Screen Time",      color: Design.teal },
        { id: "input",       icon: "\u{f0523}", label: "Mouse & Touchpad", color: Design.peach },
        { id: "keyboard",    icon: "\u{f030c}", label: "Keyboard",         color: Design.peach },
        { id: "shortcuts",   icon: "\u{f11c}",  label: "Shortcuts",        color: Design.sapphire },
        { id: "wallpaper",   icon: "\u{f02ca}", label: "Wallpaper",        color: Design.pink },
        { id: "startup",     icon: "\u{f0459}", label: "Startup",          color: Design.yellow },
        { id: "weather",     icon: "\u{f0590}", label: "Weather",          color: Design.sapphire },
        { id: "about",       icon: "\u{f035b}", label: "About & Health",   color: Design.mauve }
    ]

    function open(id) {
        if (app.pages.some(p => p.id === id))
            app.page = id;
    }

    RowLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.lg)

        // ── Rail ─────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: Design.s(180)
            Layout.maximumWidth: Design.s(180)
            spacing: Design.s(Design.space.xs)

            // Brand Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(Design.size.header)
                spacing: Design.s(Design.space.sm)

                Icon {
                    text: "\u{f0493}"
                    role: "title"
                    color: Design.accent
                }

                Label {
                    text: "Settings"
                    role: "title"
                    weight: Design.weight.bold
                }
            }

            // Category Items List
            ListView {
                id: railList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: app.pages
                clip: true
                spacing: Design.s(2)

                delegate: Rectangle {
                    id: railItem
                    required property var modelData
                    required property int index

                    width: railList.width
                    height: Design.s(34)
                    radius: Design.s(Design.radius.ctl)

                    readonly property bool isActive: app.page === railItem.modelData.id
                    color: railItem.isActive
                        ? Design.raised
                        : (itemMa.containsMouse ? Design.sunken : "transparent")

                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Design.s(Design.space.sm)
                        anchors.rightMargin: Design.s(Design.space.sm)
                        spacing: Design.s(Design.space.sm)

                        Icon {
                            text: railItem.modelData.icon
                            role: "body"
                            color: railItem.isActive ? railItem.modelData.color : Design.textDim
                        }

                        Label {
                            text: railItem.modelData.label
                            weight: railItem.isActive ? Design.weight.semibold : Design.weight.regular
                            color: railItem.isActive ? Design.text : Design.textDim
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Clickable {
                        id: itemMa
                        onClicked: app.open(railItem.modelData.id)
                    }
                }
            }

            // Footer Status
            Label {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(24)
                text: "Changes save automatically"
                role: "caption"
                dim: true
                elide: Text.ElideRight
            }
        }

        // ── Vertical Divider ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Design.veilStrong
        }

        // ── Page Scroll Container ────────────────────────────────────────────
        Flickable {
            id: pageScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: pageCol.implicitWidth
            contentHeight: pageCol.implicitHeight

            ColumnLayout {
                id: pageCol
                width: pageScroll.width
                spacing: Design.s(Design.space.lg)

                Sections.UserSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "user"
                }

                Sections.InterfaceSettingsSection {
                    visible: app.page === "interface"
                    uiScale: Settings.uiScale
                    workspaceCount: Settings.workspaceCount
                    onUiScaleChangedByUser: v => Settings.set("uiScale", v)
                    onWorkspaceCountChangedByUser: v => Settings.set("workspaceCount", v)
                }

                Sections.WindowSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "windows"
                }

                Sections.AppearanceSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "appearance"
                }

                Sections.MonitorSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "monitors"
                }

                Sections.BarSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "bar"
                }

                Sections.CaptureSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "capture"
                }

                Sections.DefaultAppsSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "defaultapps"
                }

                Sections.GameModeSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "gamemode"
                }

                Sections.MaintenanceSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "maintenance"
                }

                Sections.NightLightSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "nightlight"
                }

                Sections.NetworkSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "network"
                }

                Sections.RemoteSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "remote"
                }

                Sections.BluetoothSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "bluetooth"
                }

                Sections.AudioSettingsSection {
                    Layout.preferredWidth: pageScroll.availableWidth
                    visible: app.page === "audio"
                }

                Sections.PowerSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "power"
                }

                Sections.FocusSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "focus"
                }

                Sections.InputSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "input"
                }

                Sections.KeyboardSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "keyboard"
                    language: Settings.language
                    kbOptions: Settings.kbOptions
                    onKbOptionsChangedByUser: v => Settings.set("kbOptions", v)
                    onLanguageAdded: code => {
                        const list = Settings.language.split(",").filter(x => x !== "");
                        if (!list.includes(code))
                            Settings.set("language", list.concat(code).join(","));
                    }
                    onLanguageRemoved: code => {
                        Settings.set("language",
                            Settings.language.split(",").filter(x => x !== code && x !== "").join(","));
                    }
                }

                Sections.ShortcutsSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "shortcuts"
                }

                Sections.WallpaperSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "wallpaper"
                    wallpaperDir: Settings.wallpaperDir
                    onWallpaperDirChangedByUser: v => Settings.set("wallpaperDir", v)
                }

                Sections.StartupSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "startup"
                }

                Sections.WeatherSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "weather"
                    apiKey: Settings.weatherApiKey
                    cityId: Settings.weatherCityId
                    unit: Settings.weatherUnit
                    onApiKeyChangedByUser: v => Settings.set("weatherApiKey", v)
                    onCityIdChangedByUser: v => Settings.set("weatherCityId", v)
                    onUnitChangedByUser: v => Settings.set("weatherUnit", v)
                }

                Sections.AboutSettingsSection {
                    Layout.fillWidth: true
                    visible: app.page === "about"
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
