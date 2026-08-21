pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// The settings store. Schema, typed reads, one writer.
//
// Replaces three separate `bash -c "jq -c . settings.json"` subprocess reads
// (Main.qml, Ui/Design.qml, SettingsPopup) and one shell write that was neither
// atomic nor safe:
//
//     echo '" + JSON.stringify(config) + "' > ~/.config/sway/settings.json
//
// That breaks on any single quote inside a value, and an interrupt mid-write
// leaves truncated JSON with no valid state to fall back to.
//
// THE PROPERTY DECLARATIONS BELOW ARE THE SCHEMA. Every default lives here
// once. Previously each consumer carried its own fallback — Design.qml had one
// idea of uiScale, Main.qml another — and they were free to disagree, exactly
// the way the colour fallbacks did before Ui/Design.
//
// Like GSettings over dconf: the file holds values, this holds the schema, and
// changes arrive as a signal rather than by anyone re-reading on a timer.
// =============================================================================

Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/sway/settings.json"

    // ── Schema ───────────────────────────────────────────────────────────────
    // Type and default declared once. Reads are typed: no parseInt at the call
    // site, no `|| 1.0` scattered through the shell.

    readonly property alias uiScale: data.uiScale
    readonly property alias openGuideAtStartup: data.openGuideAtStartup
    readonly property alias topbarHelpIcon: data.topbarHelpIcon
    readonly property alias guideShortcut: data.guideShortcut
    readonly property alias language: data.language
    readonly property alias kbOptions: data.kbOptions
    readonly property alias wallpaperDir: data.wallpaperDir
    readonly property alias workspaceCount: data.workspaceCount
    readonly property alias workspaceAssignments: data.workspaceAssignments
    readonly property alias monitors: data.monitors

    // Key step sizes — how far one press of a media key moves the value.
    readonly property alias audioStep: data.audioStep
    readonly property alias brightnessStep: data.brightnessStep
    readonly property alias keyboardBacklightStep: data.keyboardBacklightStep
    readonly property alias audioNotifications: data.audioNotifications

    // Lock and idle
    readonly property alias dimOnLock: data.dimOnLock
    readonly property alias dimTimeout: data.dimTimeout
    readonly property alias lockTimeout: data.lockTimeout
    readonly property alias dpmsTimeout: data.dpmsTimeout
    readonly property alias autoSuspend: data.autoSuspend
    readonly property alias suspendTimeout: data.suspendTimeout

    // Weather. The API key lives here rather than in scripts/.env so there is
    // one store rather than two.
    readonly property alias weatherApiKey: data.weatherApiKey
    readonly property alias weatherCityId: data.weatherCityId
    readonly property alias weatherUnit: data.weatherUnit

    // Window Management & Gaps
    readonly property alias gapsInner: data.gapsInner
    readonly property alias gapsOuter: data.gapsOuter
    readonly property alias borderWidth: data.borderWidth
    readonly property alias smartBorders: data.smartBorders
    readonly property alias smartGaps: data.smartGaps
    readonly property alias inactiveOpacity: data.inactiveOpacity

    // Screenshots & Screen Recording
    readonly property alias screenshotDir: data.screenshotDir
    readonly property alias screenshotFormat: data.screenshotFormat
    readonly property alias screenshotCopyToClipboard: data.screenshotCopyToClipboard
    readonly property alias screenshotSaveToFile: data.screenshotSaveToFile
    readonly property alias screenshotDelay: data.screenshotDelay

    // Default Applications
    readonly property alias defaultBrowser: data.defaultBrowser
    readonly property alias defaultTerminal: data.defaultTerminal
    readonly property alias defaultFileManager: data.defaultFileManager
    readonly property alias defaultEditor: data.defaultEditor

    // Game Mode
    readonly property alias gameModeEnabled: data.gameModeEnabled
    readonly property alias gameModeInhibitIdle: data.gameModeInhibitIdle
    readonly property alias gameModeMuteNotifs: data.gameModeMuteNotifs

    // Top Bar (Waybar)
    readonly property alias barPosition: data.barPosition
    readonly property alias barShowCava: data.barShowCava
    readonly property alias barShowWeather: data.barShowWeather
    readonly property alias barShowMedia: data.barShowMedia
    readonly property alias barShowTray: data.barShowTray
    readonly property alias barClock24h: data.barClock24h

    // Night Light
    readonly property alias nightLightEnabled: data.nightLightEnabled
    readonly property alias nightLightTemp: data.nightLightTemp

    // Device management
    readonly property alias disabledAudioDevices: data.disabledAudioDevices
    readonly property alias disabledOutputs: data.disabledOutputs

    /** True once the file has been read at least once. */
    property bool loaded: false

    signal changed()

    // ── Writes ───────────────────────────────────────────────────────────────
    // One writer. Assign through this, never touch the file.
    //
    //   Settings.set("uiScale", 1.25)
    //   Settings.apply({ language: "us", kbOptions: "grp:alt_shift_toggle" })

    function set(key, value) {
        if (data[key] === undefined) {
            // Refuse silently-new keys: an unknown key means a typo, and a typo
            // that writes is a setting nobody can ever read back.
            console.warn("Settings: unknown key", key, "— add it to the schema first");
            return;
        }
        if (data[key] === value)
            return;
        data[key] = value;
        root.flush();
    }

    function apply(obj) {
        let touched = false;
        for (const key in obj) {
            if (data[key] === undefined) {
                console.warn("Settings: unknown key", key, "— add it to the schema first");
                continue;
            }
            if (data[key] !== obj[key]) {
                data[key] = obj[key];
                touched = true;
            }
        }
        if (touched)
            root.flush();
    }

    /** Drop a key back to its schema default. */
    function reset(key) {
        if (defaults[key] !== undefined)
            root.set(key, defaults[key]);
    }

    function flush() {
        file.writeAdapter();
        root.changed();
    }

    // The schema defaults, kept separately so reset() has something to go back
    // to — the same reason dconf stores only deltas.
    readonly property var defaults: ({
        uiScale: 1.0,
        openGuideAtStartup: false,
        topbarHelpIcon: true,
        guideShortcut: "Mod+H",
        language: "us,ua",
        kbOptions: "grp:alt_shift_toggle",
        wallpaperDir: Quickshell.env("HOME") + "/.wallpapers",
        workspaceCount: 10,
        audioStep: 5,
        brightnessStep: 5,
        keyboardBacklightStep: 10,
        audioNotifications: true,
        dimOnLock: true,
        dimTimeout: 240,
        lockTimeout: 300,
        dpmsTimeout: 600,
        autoSuspend: false,
        suspendTimeout: 1800,
        weatherApiKey: "",
        weatherCityId: "",
        weatherUnit: "metric",
        gapsInner: 5,
        gapsOuter: 10,
        borderWidth: 2,
        smartBorders: true,
        smartGaps: false,
        inactiveOpacity: 1.0,
        screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots",
        screenshotFormat: "png",
        screenshotCopyToClipboard: true,
        screenshotSaveToFile: true,
        screenshotDelay: 0,
        defaultBrowser: "firefox",
        defaultTerminal: "kitty",
        defaultFileManager: "nautilus",
        defaultEditor: "code",
        gameModeEnabled: false,
        gameModeInhibitIdle: true,
        gameModeMuteNotifs: true,
        barPosition: "top",
        barShowCava: true,
        barShowWeather: true,
        barShowMedia: true,
        barShowTray: true,
        barClock24h: true,
        nightLightEnabled: false,
        nightLightTemp: 4000,
        workspaceAssignments: [],
        monitors: [],
        disabledAudioDevices: [],
        disabledOutputs: []
    })

    // ── Store ────────────────────────────────────────────────────────────────
    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        atomicWrites: true

        onFileChanged: reload()
        onLoaded: {
            root.loaded = true;
            root.changed();
        }
        onLoadFailed: root.loaded = true

        JsonAdapter {
            id: data
            property real uiScale: 1.0
            property bool openGuideAtStartup: false
            property bool topbarHelpIcon: true
            property string guideShortcut: "Mod+H"
            property string language: "us,ua"
            property string kbOptions: "grp:alt_shift_toggle"
            property string wallpaperDir: Quickshell.env("HOME") + "/.wallpapers"
            property int workspaceCount: 10
            property var workspaceAssignments: []
            property var monitors: []
            property var disabledAudioDevices: []
            property var disabledOutputs: []

            property int audioStep: 5
            property int brightnessStep: 5
            property int keyboardBacklightStep: 10
            property bool audioNotifications: true

            property bool dimOnLock: true
            property int dimTimeout: 240
            property int lockTimeout: 300
            property int dpmsTimeout: 600
            property bool autoSuspend: false
            property int suspendTimeout: 1800

            property string weatherApiKey: ""
            property string weatherCityId: ""
            property string weatherUnit: "metric"

            property int gapsInner: 5
            property int gapsOuter: 10
            property int borderWidth: 2
            property bool smartBorders: true
            property bool smartGaps: false
            property real inactiveOpacity: 1.0

            property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
            property string screenshotFormat: "png"
            property bool screenshotCopyToClipboard: true
            property bool screenshotSaveToFile: true
            property int screenshotDelay: 0

            property string defaultBrowser: "firefox"
            property string defaultTerminal: "kitty"
            property string defaultFileManager: "nautilus"
            property string defaultEditor: "code"

            property bool gameModeEnabled: false
            property bool gameModeInhibitIdle: true
            property bool gameModeMuteNotifs: true

            property string barPosition: "top"
            property bool barShowCava: true
            property bool barShowWeather: true
            property bool barShowMedia: true
            property bool barShowTray: true
            property bool barClock24h: true

            property bool nightLightEnabled: false
            property int nightLightTemp: 4000
        }
    }
}
