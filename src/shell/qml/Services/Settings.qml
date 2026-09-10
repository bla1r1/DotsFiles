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

    // Appearance & compositor effects. Defaults mirror conf.d/look-and-feel.conf
    // so the UI shows what the session actually booted with.
    readonly property alias themeName: data.themeName
    readonly property alias accentName: data.accentName
    readonly property alias cornerRadius: data.cornerRadius
    readonly property alias blurEnabled: data.blurEnabled
    readonly property alias shadowsEnabled: data.shadowsEnabled
    readonly property alias dimInactive: data.dimInactive

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
    readonly property alias defaultPlayer: data.defaultPlayer

    // Game Mode
    readonly property alias gameModeEnabled: data.gameModeEnabled
    readonly property alias gameModeAdaptiveSync: data.gameModeAdaptiveSync
    readonly property alias gameModeHideBar: data.gameModeHideBar
    readonly property alias gameModeDND: data.gameModeDND

    // Native Top Bar
    readonly property alias barPosition: data.barPosition
    readonly property alias barShowCava: data.barShowCava
    readonly property alias barShowWeather: data.barShowWeather
    readonly property alias barShowMedia: data.barShowMedia
    readonly property alias barShowTray: data.barShowTray
    readonly property alias barClock24h: data.barClock24h

    // Sound Feedback
    readonly property alias soundVolumeFeedback: data.soundVolumeFeedback
    readonly property alias soundScreenshotFeedback: data.soundScreenshotFeedback
    readonly property alias soundDeviceFeedback: data.soundDeviceFeedback

    // Touchpad & Gestures
    readonly property alias touchpadSwipeWorkspace: data.touchpadSwipeWorkspace
    readonly property alias touchpadNaturalSwipe: data.touchpadNaturalSwipe
    readonly property alias touchpadPinchZoom: data.touchpadPinchZoom

    // Pointer & touchpad. Defaults mirror conf.d/input.conf.
    readonly property alias naturalScroll: data.naturalScroll
    readonly property alias tapToClick: data.tapToClick
    readonly property alias dwt: data.dwt
    readonly property alias pointerAccel: data.pointerAccel
    readonly property alias accelProfile: data.accelProfile
    readonly property alias leftHanded: data.leftHanded

    // Autostart & Notifications
    readonly property alias autostartApps: data.autostartApps
    readonly property alias autostartCustom: data.autostartCustom
    readonly property alias notificationRules: data.notificationRules
    readonly property alias notificationsDnd: data.notificationsDnd

    // Night Light. These two were declared in the adapter but had no public
    // alias, so Settings.nightLightEnabled / .nightLightTemp read back as
    // undefined and the page's `!== undefined ? … : default` fallbacks always
    // won — the saved values persisted to disk and were never shown again.
    readonly property alias nightLightEnabled: data.nightLightEnabled
    readonly property alias nightLightTemp: data.nightLightTemp

    // Focus time / pomodoro.
    readonly property alias focusWorkDuration: data.focusWorkDuration
    readonly property alias focusShortBreak: data.focusShortBreak
    readonly property alias focusLongBreak: data.focusLongBreak
    readonly property alias dailyScreenTimeGoal: data.dailyScreenTimeGoal
    readonly property alias focusAutoDnd: data.focusAutoDnd
    readonly property alias focusBreakReminders: data.focusBreakReminders
    readonly property alias focusDaemonAutoStart: data.focusDaemonAutoStart

    // Device management
    readonly property alias disabledAudioDevices: data.disabledAudioDevices
    readonly property alias disabledOutputs: data.disabledOutputs

    /** True once the file has been read at least once. */
    property bool loaded: false

    signal changed()

    property string pendingWeatherApiKey: ""
    Process {
        id: secretWriter
        stdinEnabled: true
        command: ["b1air-secret-service", "set", "weather-api-key"]
        onStarted: {
            write(root.pendingWeatherApiKey + "\n");
            stdinEnabled = false;
        }
    }

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

    function setWeatherApiKey(value) {
        root.data.weatherApiKey = "";
        root.pendingWeatherApiKey = String(value || "");
        secretWriter.running = true;
        root.changed();
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

    /**
     * Drop every key back to its schema default.
     *
     * About → "Reset Defaults" has called this since it was written and it did
     * not exist, so the button threw a TypeError and reset nothing. The button
     * is destructive-styled, so it already arms once before firing.
     */
    function resetDefaults() {
        root.apply(root.defaults);
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
        gapsOuter: 20,
        borderWidth: 2,
        smartBorders: true,
        smartGaps: false,
        inactiveOpacity: 1.0,
        themeName: "catppuccin-mocha",
        accentName: "",
        cornerRadius: 10,
        blurEnabled: true,
        shadowsEnabled: true,
        dimInactive: true,
        screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots",
        screenshotFormat: "png",
        screenshotCopyToClipboard: true,
        screenshotSaveToFile: true,
        screenshotDelay: 0,
        defaultBrowser: "firefox",
        defaultTerminal: "b1air-term",
        defaultFileManager: "b1air-files",
        defaultEditor: "code",
        defaultPlayer: "mpv",
        gameModeEnabled: false,
        gameModeAdaptiveSync: false,
        gameModeHideBar: true,
        gameModeDND: false,
        barPosition: "top",
        barShowCava: true,
        barShowWeather: true,
        barShowMedia: true,
        barShowTray: true,
        barClock24h: true,
        nightLightEnabled: false,
        nightLightTemp: 4000,
        soundVolumeFeedback: true,
        soundScreenshotFeedback: true,
        soundDeviceFeedback: true,
        touchpadSwipeWorkspace: true,
        touchpadNaturalSwipe: true,
        touchpadPinchZoom: true,
        naturalScroll: false,
        tapToClick: true,
        dwt: true,
        pointerAccel: 0.0,
        accelProfile: "flat",
        leftHanded: false,
        autostartApps: ["polkit", "quickshell"],
        autostartCustom: [],
        notificationRules: {},
        notificationsDnd: false,
        focusWorkDuration: 25,
        focusShortBreak: 5,
        focusLongBreak: 15,
        dailyScreenTimeGoal: 8,
        focusAutoDnd: true,
        focusBreakReminders: true,
        focusDaemonAutoStart: true,
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
            // Credentials are owned by b1air-secret-service, never retained in
            // the general settings JSON or exposed to QML after load.
            data.weatherApiKey = "";
            root.loaded = true;
            root.changed();
        }
        onLoadFailed: root.loaded = true

        JsonAdapter {
            id: data
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
            property int gapsOuter: 20
            property int borderWidth: 2
            property bool smartBorders: true
            property bool smartGaps: false
            property real inactiveOpacity: 1.0
            property string themeName: "catppuccin-mocha"
            property string accentName: ""
            property int cornerRadius: 10
            property bool blurEnabled: true
            property bool shadowsEnabled: true
            property bool dimInactive: true

            property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
            property string screenshotFormat: "png"
            property bool screenshotCopyToClipboard: true
            property bool screenshotSaveToFile: true
            property int screenshotDelay: 0

            property string defaultBrowser: "firefox"
            property string defaultTerminal: "b1air-term"
            property string defaultFileManager: "b1air-files"
            property string defaultEditor: "code"
            property string defaultPlayer: "mpv"

            property bool gameModeEnabled: false
            property bool gameModeAdaptiveSync: false
            property bool gameModeHideBar: true
            property bool gameModeDND: false

            property string barPosition: "top"
            property bool barShowCava: true
            property bool barShowWeather: true
            property bool barShowMedia: true
            property bool barShowTray: true
            property bool barClock24h: true

            property bool nightLightEnabled: false
            property int nightLightTemp: 4000

            property bool soundVolumeFeedback: true
            property bool soundScreenshotFeedback: true
            property bool soundDeviceFeedback: true

            property bool touchpadSwipeWorkspace: true
            property bool touchpadNaturalSwipe: true
            property bool touchpadPinchZoom: true
            property bool naturalScroll: false
            property bool tapToClick: true
            property bool dwt: true
            property real pointerAccel: 0.0
            property string accelProfile: "flat"
            property bool leftHanded: false

            property var autostartApps: ["polkit", "quickshell"]
            property var autostartCustom: []
            property var notificationRules: ({})
            property bool notificationsDnd: false
            property int focusWorkDuration: 25
            property int focusShortBreak: 5
            property int focusLongBreak: 15
            property int dailyScreenTimeGoal: 8
            property bool focusAutoDnd: true
            property bool focusBreakReminders: true
            property bool focusDaemonAutoStart: true
        }
    }
}
