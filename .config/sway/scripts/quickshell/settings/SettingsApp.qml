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
// Three of them are NOT here on purpose. Audio, Connectivity and Devices show
// live state, and by the rule in docs/migration.md state belongs to the Control
// Center: a popup changes state now, settings change configuration forever.
// Keeping them would have been the third place to adjust a volume.
//
// Sections read and write Services/Settings directly rather than having values
// threaded through this file. Passing them down would rebuild, in miniature,
// the "every consumer keeps its own copy" problem the store exists to end.
// =============================================================================

PopupShell {
    id: app

    property string page: "interface"

    readonly property var pages: [
        { id: "interface", icon: "\u{f0b60}", label: "Interface" },
        { id: "monitors",  icon: "\u{f0379}", label: "Displays" },
        { id: "keyboard",  icon: "\u{f030c}", label: "Keyboard" },
        { id: "controls",  icon: "\u{f04c3}", label: "Controls" },
        { id: "lock",      icon: "\u{f033e}", label: "Lock & idle" },
        { id: "startup",   icon: "\u{f0459}", label: "Startup" },
        { id: "wallpaper", icon: "\u{f02ca}", label: "Wallpaper" },
        { id: "weather",   icon: "\u{f0590}", label: "Weather" }
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
            Layout.preferredWidth: Design.s(168)
            spacing: Design.s(Design.space.xs)

            Label {
                text: "Settings"
                role: "subhead"
                weight: Design.weight.semibold
                Layout.bottomMargin: Design.s(Design.space.md)
            }

            Repeater {
                model: app.pages

                Rectangle {
                    id: railRow
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(38)
                    radius: Design.s(Design.radius.ctl)

                    readonly property bool active: app.page === modelData.id
                    color: active ? Design.accent
                                  : (rowMa.containsMouse ? Design.veilStrong : "transparent")
                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Design.s(Design.space.md)
                        spacing: Design.s(Design.space.md)

                        Icon {
                            text: railRow.modelData.icon
                            role: "body"
                            color: railRow.active ? Design.onAccent : Design.textDim
                        }
                        Label {
                            text: railRow.modelData.label
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            weight: railRow.active ? Design.weight.semibold : Design.weight.regular
                            color: railRow.active ? Design.onAccent : Design.textDim
                        }
                    }

                    Clickable { id: rowMa; onClicked: app.page = railRow.modelData.id }
                }
            }

            Item { Layout.fillHeight: true }

            Label {
                text: "Changes save as you make them"
                role: "caption"
                dim: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Design.border
            color: Design.line
        }

        // ── Page ─────────────────────────────────────────────────────────────
        ScrollArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            framed: false

            ColumnLayout {
                width: parent ? parent.width : 0
                spacing: Design.s(Design.space.lg)

                Sections.InterfaceSettingsSection {
                    visible: app.page === "interface"
                    uiScale: Settings.uiScale
                    workspaceCount: Settings.workspaceCount
                    onUiScaleChangedByUser: v => Settings.set("uiScale", v)
                    onWorkspaceCountChangedByUser: v => Settings.set("workspaceCount", v)
                }

                Sections.KeyboardSettingsSection {
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

                Sections.ControlsSettingsSection {
                    visible: app.page === "controls"
                    audioStep: Settings.audioStep
                    brightnessStep: Settings.brightnessStep
                    keyboardBacklightStep: Settings.keyboardBacklightStep
                    audioNotifications: Settings.audioNotifications
                    onAudioStepChangedByUser: v => Settings.set("audioStep", v)
                    onBrightnessStepChangedByUser: v => Settings.set("brightnessStep", v)
                    onKeyboardBacklightStepChangedByUser: v => Settings.set("keyboardBacklightStep", v)
                    onAudioNotificationsChangedByUser: v => Settings.set("audioNotifications", v)
                }

                Sections.LockIdleSettingsSection {
                    visible: app.page === "lock"
                    dimOnLock: Settings.dimOnLock
                    dimTimeout: Settings.dimTimeout
                    lockTimeout: Settings.lockTimeout
                    dpmsTimeout: Settings.dpmsTimeout
                    autoSuspend: Settings.autoSuspend
                    suspendTimeout: Settings.suspendTimeout
                    onDimOnLockChangedByUser: v => Settings.set("dimOnLock", v)
                    onDimTimeoutChangedByUser: v => Settings.set("dimTimeout", v)
                    onLockTimeoutChangedByUser: v => Settings.set("lockTimeout", v)
                    onDpmsTimeoutChangedByUser: v => Settings.set("dpmsTimeout", v)
                    onAutoSuspendChangedByUser: v => Settings.set("autoSuspend", v)
                    onSuspendTimeoutChangedByUser: v => Settings.set("suspendTimeout", v)
                }

                Sections.StartupSettingsSection {
                    visible: app.page === "startup"
                    openGuideAtStartup: Settings.openGuideAtStartup
                    guideShortcut: Settings.guideShortcut
                    onOpenGuideAtStartupChangedByUser: v => Settings.set("openGuideAtStartup", v)
                    onGuideShortcutChangedByUser: v => Settings.set("guideShortcut", v)
                }

                Sections.WallpaperSettingsSection {
                    visible: app.page === "wallpaper"
                    wallpaperDir: Settings.wallpaperDir
                    onWallpaperDirChangedByUser: v => Settings.set("wallpaperDir", v)
                }

                Sections.WeatherSettingsSection {
                    visible: app.page === "weather"
                    apiKey: Settings.weatherApiKey
                    cityId: Settings.weatherCityId
                    unit: Settings.weatherUnit
                    onApiKeyChangedByUser: v => Settings.set("weatherApiKey", v)
                    onCityIdChangedByUser: v => Settings.set("weatherCityId", v)
                    onUnitChangedByUser: v => Settings.set("weatherUnit", v)
                }

                // TODO: needs a monitorModel. Filling it means folding
                // MonitorPopup (1406 lines) in here, which is the rest of step
                // 06 — see docs/migration.md. Until then this page renders
                // empty rather than wrong.
                Sections.MonitorSettingsSection {
                    visible: app.page === "monitors"
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
