import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Ui"

PopupShell {
    id: root

    // Durations that are choreography, not styling: a staged entrance, ambient
    // loops and slow tint crossfades. Deliberately off the motion scale.
    // PauseAnimation delays are left as they are — that spread is the stagger.
    readonly property int introDuration: 800
    readonly property int tintDuration: 1000
    readonly property int pulsePeriod: 1500
    readonly property int driftPeriod: 90000


    // --- Responsive Scaling Logic ---
    
    readonly property string scriptDir: Quickshell.env("QS_SCRIPT_DIR") || (Quickshell.env("HOME") + "/.config/sway/scripts")
    readonly property string mainQmlPath: scriptDir + "/quickshell/Main.qml"

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: {
        closeSequence.start();
        event.accepted = true;
    }
    Keys.onReturnPressed: {
        root.saveAppSettings();
        event.accepted = true;
    }
    Keys.onEnterPressed: {
        root.saveAppSettings();
        event.accepted = true;
    }


    // -------------------------------------------------------------------------
    // SSOT GLOBAL SETTINGS & UPDATES
    // -------------------------------------------------------------------------
    property int initialWorkspaceCount: 8 // Track the value loaded from JSON
    
    property real setUiScale: 1.0
    property bool setOpenGuideAtStartup: true
    property bool setGuideShortcut: true
    property int setWorkspaceCount: 8
    property string setWallpaperDir: {
        const dir = Quickshell.env("WALLPAPER_DIR")
        return (dir && dir !== "") 
        ? dir 
        : Quickshell.env("HOME") + "/Pictures/Wallpapers"
    }
    property string setLanguage: ""
    property string setKbOptions: "grp:alt_shift_toggle"

    property var kbToggleModelArr: [
        { label: "Alt + Shift", val: "grp:alt_shift_toggle" },
        { label: "Win + Space", val: "grp:win_space_toggle" },
        { label: "Caps Lock", val: "grp:caps_toggle" },
        { label: "Ctrl + Shift", val: "grp:ctrl_shift_toggle" },
        { label: "Ctrl + Alt", val: "grp:ctrl_alt_toggle" },
        { label: "Right Alt", val: "grp:toggle" },
        { label: "No Toggle", val: "" }
    ]

    function getKbToggleLabel(val) {
        for (let i = 0; i < root.kbToggleModelArr.length; i++) {
            if (root.kbToggleModelArr[i].val === val) return root.kbToggleModelArr[i].label;
        }
        return "Alt + Shift";
    }

    function saveAppSettings() {
        let config = {
            "uiScale": root.setUiScale,
            "openGuideAtStartup": root.setOpenGuideAtStartup,
            "guideShortcut": root.setGuideShortcut,
            "wallpaperDir": root.setWallpaperDir,
            "language": root.setLanguage,
            "kbOptions": root.setKbOptions,
            "workspaceCount": root.setWorkspaceCount
        };
        let jsonString = JSON.stringify(config, null, 2);
        
        let cmd = "mkdir -p ~/.config/sway/ && echo '" + jsonString + "' > ~/.config/sway/settings.json && notify-send 'Quickshell' 'Settings Applied Successfully!'";
                  
        Quickshell.execDetached(["bash", "-c", cmd]);
        
        if (root.setWorkspaceCount !== root.initialWorkspaceCount) {
            root.initialWorkspaceCount = root.setWorkspaceCount; 
        }
    }

    function root.close() {
        Quickshell.execDetached(["qs", "-p", root.mainQmlPath, "ipc", "call", "main", "close"]);
    }
    Process {
        id: swayLangReader
        command: ["bash", "-c", "grep -m1 '^ *xkb_layout ' ~/.config/sway/conf.d/input.conf | awk '{print $2}' | tr -d ' '"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "";
                if (out.length > 0 && root.setLanguage === "") {
                    root.setLanguage = out;
                }
            }
        }
    }

    Process {
        id: settingsReader
        command: ["bash", "-c", "jq -c . ~/.config/sway/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text ? this.text.trim() : "{}";
                    let start = text.indexOf("{");
                    let end = text.lastIndexOf("}");
                    if (start >= 0 && end >= start) text = text.slice(start, end + 1);
                    else text = "{}";

                    if (text.length > 0 && text !== "{}") {
                        let parsed = JSON.parse(text);
                        if (parsed.uiScale !== undefined) root.setUiScale = parsed.uiScale;
                        if (parsed.openGuideAtStartup !== undefined) root.setOpenGuideAtStartup = parsed.openGuideAtStartup;
                        if (parsed.guideShortcut !== undefined) root.setGuideShortcut = parsed.guideShortcut;
                        if (parsed.wallpaperDir !== undefined) root.setWallpaperDir = parsed.wallpaperDir;
                        if (parsed.language !== undefined && parsed.language !== "") root.setLanguage = parsed.language;
                        if (parsed.kbOptions !== undefined) root.setKbOptions = parsed.kbOptions;
                        if (parsed.workspaceCount !== undefined) {
                            root.setWorkspaceCount = parsed.workspaceCount;
                            root.initialWorkspaceCount = parsed.workspaceCount; // TRACK BASELINE
                        }
                    } else {
                        root.saveAppSettings();
                    }
                } catch (e) {
                    console.log("Error parsing global settings:", e);
                }
            }
        }
    }
    ListModel {
        id: langModel
        ListElement { code: "us"; name: "English (US)" }
        ListElement { code: "gb"; name: "English (UK)" }
        ListElement { code: "au"; name: "English (Australia)" }
        ListElement { code: "ca"; name: "English/French (Canada)" }
        ListElement { code: "ie"; name: "English (Ireland)" }
        ListElement { code: "nz"; name: "English (New Zealand)" }
        ListElement { code: "za"; name: "English (South Africa)" }
        ListElement { code: "fr"; name: "French" }
        ListElement { code: "de"; name: "German" }
        ListElement { code: "es"; name: "Spanish" }
        ListElement { code: "pt"; name: "Portuguese" }
        ListElement { code: "it"; name: "Italian" }
        ListElement { code: "se"; name: "Swedish" }
        ListElement { code: "no"; name: "Norwegian" }
        ListElement { code: "dk"; name: "Danish" }
        ListElement { code: "fi"; name: "Finnish" }
        ListElement { code: "pl"; name: "Polish" }
        ListElement { code: "ru"; name: "Russian" }
        ListElement { code: "ua"; name: "Ukrainian" }
        ListElement { code: "cn"; name: "Chinese" }
        ListElement { code: "jp"; name: "Japanese" }
        ListElement { code: "kr"; name: "Korean" }
    }

    ListModel { id: pathSuggestModel }
    ListModel { id: langSearchModel }

    function updateLangSearch(query) {
        langSearchModel.clear();
        let q = query.trim().toLowerCase();
        if (q === "") return;
        for (let i = 0; i < langModel.count; i++) {
            let item = langModel.get(i);
            if (item.code.toLowerCase().includes(q) || item.name.toLowerCase().includes(q)) {
                langSearchModel.append({ code: item.code, name: item.name });
            }
        }
    }

    Process {
        id: pathSuggestProc
        property string query: ""
        command: ["bash", "-c", "eval ls -dp " + query + "* 2>/dev/null | grep '/$' | head -n 5 || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                pathSuggestModel.clear();
                if (this.text) {
                    let lines = this.text.trim().split('\n');
                    for (let i = 0; i < lines.length; i++) {
                        if (lines[i].length > 0) {
                            pathSuggestModel.append({ path: lines[i] });
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // ANIMATIONS
    // -------------------------------------------------------------------------
    property real introContent: 0.0

    Component.onCompleted: { 
        startupSequence.start(); 
    }

    SequentialAnimation {
        id: startupSequence
        PauseAnimation { duration: Design.duration.fast }
        NumberAnimation { 
            target: root
            property: "introContent"
            from: 0.0
            to: 1.0
            duration: root.introDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.05
        } 
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { 
            target: root
            property: "introContent"
            to: 0.0
            duration: 80
            easing.type: Easing.InExpo 
        }
        ScriptAction { 
            script: {
                root.closePanel();
            } 
        }
    }

    // -------------------------------------------------------------------------
    // SIDEBAR BACKGROUND
    // -------------------------------------------------------------------------
    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: Qt.rgba(Design.surface.r, Design.surface.g, Design.surface.b, 0.95)
        radius: Design.s(16)
        border.width: 1
        border.color: Qt.rgba(Design.raised.r, Design.raised.g, Design.raised.b, 0.8)
        clip: true

        // --- Straighten Left Corners ---
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Design.s(16)
            color: sidebarPanel.color

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: sidebarPanel.border.color }
        }

        // -------------------------------------------------------------------------
        // FLICKABLE CONTENT AREA
        // -------------------------------------------------------------------------
        Item {
            anchors.fill: parent
            opacity: introContent
            scale: 0.98 + (0.02 * introContent)

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: settingsMainCol.implicitHeight + Design.s(100)
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: settingsMainCol
                    width: parent.width - Design.s(48)
                    x: Design.s(24)
                    y: Design.s(24)
                    spacing: Design.s(20)

                    // --- HEADER ---
                    RowLayout {
                        Layout.fillWidth: true
                        Text { 
                            text: "Settings"
                            font.family: Design.font.mono
                            font.weight: Design.weight.bold
                            font.pixelSize: Design.s(26)
                            color: Design.text
                            Layout.alignment: Qt.AlignVCenter 
                        }
                    }

                    // --- SETTINGS LIST ---
                    
                    // Box 1: Startup & Icons
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col1.implicitHeight + Design.s(32)
                        radius: Design.s(12)
                        color: Qt.alpha(Design.raised, 0.5)
                        border.color: Design.hover
                        border.width: 1
                        
                        ColumnLayout {
                            id: col1
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Design.s(16)
                            spacing: Design.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: Design.warn }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { text: "Guide on startup"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                            Layout.preferredWidth: Design.s(40)
                                            Layout.preferredHeight: Design.s(24)
                                            radius: Design.s(12)
                                            color: root.setOpenGuideAtStartup ? Design.warn : Design.active
                                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                            Rectangle {
                                                width: Design.s(18); height: Design.s(18); radius: Design.s(9); color: Design.surface
                                                y: Design.s(3); x: root.setOpenGuideAtStartup ? Design.s(19) : Design.s(3)
                                                Behavior on x { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.setOpenGuideAtStartup = !root.setOpenGuideAtStartup; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                    Label { role: "caption"; text: "Launch on login"; dim: true; Layout.fillWidth: true }
                                }
                            }
                            
                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Design.hover, 0.5) }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰋖"; color: Design.accent }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { text: "Guide shortcut"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                            Layout.preferredWidth: Design.s(40)
                                            Layout.preferredHeight: Design.s(24)
                                            radius: Design.s(12)
                                            color: root.setGuideShortcut ? Design.accent : Design.active
                                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                            Rectangle {
                                                width: Design.s(18); height: Design.s(18); radius: Design.s(9); color: Design.surface
                                                y: Design.s(3); x: root.setGuideShortcut ? Design.s(19) : Design.s(3)
                                                Behavior on x { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.setGuideShortcut = !root.setGuideShortcut; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                    Label { role: "caption"; text: "Reserved for Waybar/Quickshell launchers"; dim: true; Layout.fillWidth: true }
                                }
                            }
                        }
                    }

                    // Box 2: UI Scale
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col2.implicitHeight + Design.s(32)
                        radius: Design.s(12)
                        color: Qt.alpha(Design.raised, 0.5)
                        border.color: Design.hover
                        border.width: 1
                        
                        ColumnLayout {
                            id: col2
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Design.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰁦"; color: Design.accentSoft }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    Label { text: "UI Scale"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                    Label { role: "caption"; text: "Base size scalar"; dim: true; Layout.fillWidth: true }
                                    
                                    RowLayout {
                                        Layout.topMargin: Design.s(8)
                                        spacing: Design.s(12)
                                        Rectangle {
                                            width: Design.s(30); height: Design.s(30); radius: Design.s(8)
                                            color: sMinusMa.pressed ? Design.active : Design.hover
                                            border.color: sMinusMa.containsMouse ? Design.accentSoft : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                            Label { role: "subhead"; anchors.centerIn: parent; text: "-"; font.weight: Design.weight.semibold }
                                            Clickable { id: sMinusMa; onClicked: root.setUiScale = Math.max(0.5, (root.setUiScale - 0.1).toFixed(1)) }
                                        }
                                        Label {
                                            text: root.setUiScale.toFixed(1) + "x"
                                            font.weight: Design.weight.bold
                                            color: Design.accentSoft
                                            Layout.minimumWidth: Design.s(40)
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Rectangle {
                                            width: Design.s(30); height: Design.s(30); radius: Design.s(8)
                                            color: sPlusMa.pressed ? Design.active : Design.hover
                                            border.color: sPlusMa.containsMouse ? Design.accentSoft : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                            Label { role: "subhead"; anchors.centerIn: parent; text: "+"; font.weight: Design.weight.semibold }
                                            Clickable { id: sPlusMa; onClicked: root.setUiScale = Math.min(2.0, (root.setUiScale + 0.1).toFixed(1)) }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }

                    // Box 3: Keyboard Language & Switcher
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col3.implicitHeight + Design.s(32)
                        radius: Design.s(12)
                        color: Qt.alpha(Design.raised, 0.5)
                        border.color: Design.hover
                        border.width: 1
                        
                        ColumnLayout {
                            id: col3
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Design.s(16)
                            spacing: Design.s(16)
                            
                            // Part 1: Language
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰌌"; color: Design.ok }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    Label { text: "Keyboard layouts"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                    Label { role: "caption"; text: "Matches config. Click ✖ to remove."; dim: true; Layout.fillWidth: true }
                                    
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: Design.s(8)
                                        Layout.topMargin: Design.s(6)
                                        Repeater {
                                            model: root.setLanguage ? root.setLanguage.split(",").filter(x => x.trim() !== "") : []
                                            Rectangle {
                                                width: langChipLayout.implicitWidth + Design.s(24)
                                                height: Design.s(28)
                                                radius: Design.s(14)
                                                color: Design.hover
                                                border.color: chipMa.containsMouse ? Design.danger : Design.active
                                                border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }
                                                RowLayout {
                                                    id: langChipLayout
                                                    anchors.centerIn: parent
                                                    spacing: Design.s(8)
                                                    Label {
                                                        role: "caption"
                                                        text: modelData
                                                        font.weight: Design.weight.semibold
                                                        color: chipMa.containsMouse ? Design.danger : Design.text
                                                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                                    }
                                                    Label {
                                                        text: "✖"
                                                        color: chipMa.containsMouse ? Design.danger : Design.textDim
                                                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                                    }
                                                }
                                                Clickable {
                                                    id: chipMa
                                                    onClicked: {
                                                        let arr = root.setLanguage.split(",").filter(x => x.trim() !== "");
                                                        arr.splice(index, 1);
                                                        root.setLanguage = arr.join(",");
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Search Bar Input
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(36)
                                        Layout.topMargin: Design.s(8)
                                        radius: Design.s(6)
                                        color: Design.raised
                                        border.color: langInput.activeFocus ? Design.ok : Design.active
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                        TextInput {
                                            id: langInput
                                            anchors.fill: parent
                                            anchors.margins: Design.s(10)
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: Design.font.mono
                                            font.pixelSize: Design.s(12)
                                            color: Design.text
                                            clip: true
                                            selectByMouse: true
                                            onTextChanged: { root.updateLangSearch(text); }
                                            onAccepted: root.saveAppSettings()
                                            Text { text: "Search to add..."; color: Design.textDim; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                    }

                                    // Expanding List Container
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: langInput.activeFocus && langSearchModel.count > 0 ? Math.min(Design.s(150), langSearchModel.count * Design.s(32)) : 0
                                        radius: Design.s(6)
                                        color: Design.raised
                                        border.color: Design.ok
                                        border.width: Layout.preferredHeight > 0 ? 1 : 0
                                        clip: true
                                        Behavior on Layout.preferredHeight { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutExpo } }
                                        ListView {
                                            anchors.fill: parent
                                            model: langSearchModel
                                            interactive: true
                                            ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }
                                            delegate: Rectangle {
                                                width: parent.width
                                                height: Design.s(32)
                                                color: sMa.containsMouse ? Design.active : "transparent"
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: Design.s(12)
                                                    anchors.rightMargin: Design.s(12)
                                                    spacing: Design.s(10)
                                                    Label { role: "caption"; text: model.code; font.weight: Design.weight.semibold }
                                                    Label { role: "caption"; text: model.name; dim: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                                Clickable {
                                                    id: sMa
                                                    onClicked: {
                                                        let arr = root.setLanguage ? root.setLanguage.split(",").filter(x => x.trim() !== "") : [];
                                                        if (!arr.includes(model.code)) {
                                                            arr.push(model.code);
                                                            root.setLanguage = arr.join(",");
                                                        }
                                                        langInput.text = "";
                                                        langInput.focus = false;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Design.hover, 0.5) }

                            // Part 2: Layout Switcher
                            RowLayout {
                                id: layoutSwitcherBox
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                property bool isDropdownOpen: false

                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰯍"; color: Qt.alpha(Design.ok, 0.7) }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    Label { text: "Layout shortcut"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                    Label { role: "caption"; text: "Toggle combination"; dim: true; Layout.fillWidth: true }

                                    // Switcher Selection Header
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(36)
                                        Layout.topMargin: Design.s(8)
                                        radius: Design.s(6)
                                        color: Design.raised
                                        border.color: layoutSwitcherBox.isDropdownOpen ? Design.ok : Design.active
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Design.s(10)
                                            Label {
                                                role: "caption"
                                                text: root.getKbToggleLabel(root.setKbOptions)
                                                Layout.fillWidth: true
                                            }
                                            Text { 
                                                text: layoutSwitcherBox.isDropdownOpen ? "▴" : "▾"
                                                font.pixelSize: Design.s(14)
                                                color: Design.textDim 
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: layoutSwitcherBox.isDropdownOpen = !layoutSwitcherBox.isDropdownOpen
                                        }
                                    }

                                    // Expanding Switcher Dropdown
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: layoutSwitcherBox.isDropdownOpen ? root.kbToggleModelArr.length * Design.s(32) : 0
                                        radius: Design.s(6)
                                        color: Design.raised
                                        border.color: Design.ok
                                        border.width: Layout.preferredHeight > 0 ? 1 : 0
                                        clip: true
                                        Behavior on Layout.preferredHeight { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutExpo } }
                                        ListView {
                                            anchors.fill: parent
                                            model: root.kbToggleModelArr
                                            interactive: false
                                            delegate: Rectangle {
                                                width: parent.width
                                                height: Design.s(32)
                                                color: toggleMa.containsMouse ? Design.active : "transparent"
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: Design.s(12)
                                                    anchors.rightMargin: Design.s(12)
                                                    Label {
                                                        role: "caption"
                                                        text: modelData.label
                                                        color: root.setKbOptions === modelData.val ? Design.ok : Design.text
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                                Clickable {
                                                    id: toggleMa
                                                    onClicked: {
                                                        root.setKbOptions = modelData.val;
                                                        layoutSwitcherBox.isDropdownOpen = false;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Box 4: Wallpaper Directory
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col4.implicitHeight + Design.s(32)
                        radius: Design.s(12)
                        color: Qt.alpha(Design.raised, 0.5)
                        border.color: wpDirInput.activeFocus ? Design.accentAlt : Design.hover
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }
                        
                        ColumnLayout {
                            id: col4
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Design.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: Design.accentAlt }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    Label { text: "Wallpaper directory"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                    Label { role: "caption"; text: "Absolute source path"; dim: true; Layout.fillWidth: true }
                                    
                                    // Text Input
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Design.s(36)
                                        Layout.topMargin: Design.s(8)
                                        radius: Design.s(6)
                                        color: Design.raised
                                        border.color: wpDirInput.activeFocus ? Design.accentAlt : Design.active
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                        TextInput {
                                            id: wpDirInput
                                            anchors.fill: parent
                                            anchors.margins: Design.s(10)
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: root.setWallpaperDir
                                            font.family: Design.font.mono
                                            font.pixelSize: Design.s(12)
                                            color: Design.text
                                            clip: true
                                            selectByMouse: true
                                            onTextChanged: { 
                                                root.setWallpaperDir = text; 
                                                if (activeFocus) { 
                                                    pathSuggestProc.query = text; 
                                                    pathSuggestProc.running = false; 
                                                    pathSuggestProc.running = true; 
                                                } 
                                            }
                                            onAccepted: root.saveAppSettings()
                                        }
                                    }

                                    // Expanding Suggestions List
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: wpDirInput.activeFocus && pathSuggestModel.count > 0 ? pathSuggestModel.count * Design.s(30) : 0
                                        radius: Design.s(6)
                                        color: Design.raised
                                        border.color: Design.accentAlt
                                        border.width: Layout.preferredHeight > 0 ? 1 : 0
                                        clip: true
                                        Behavior on Layout.preferredHeight { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutExpo } }
                                        ListView {
                                            anchors.fill: parent
                                            model: pathSuggestModel
                                            interactive: false
                                            delegate: Rectangle {
                                                width: parent.width
                                                height: Design.s(30)
                                                color: suggestMa.containsMouse ? Design.active : "transparent"
                                                Label {
                                                    role: "caption"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: Design.s(12)
                                                    text: model.path
                                                    elide: Text.ElideMiddle
                                                    width: parent.width - Design.s(24)
                                                }
                                                Clickable {
                                                    id: suggestMa
                                                    onClicked: { 
                                                        wpDirInput.text = model.path; 
                                                        pathSuggestModel.clear(); 
                                                        wpDirInput.focus = false; 
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Box 5: Workspace Count
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col5.implicitHeight + Design.s(32)
                        radius: Design.s(12)
                        color: Qt.alpha(Design.raised, 0.5)
                        border.color: Design.hover
                        border.width: 1
                        
                        ColumnLayout {
                            id: col5
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Design.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(16)
                                Item {
                                    Layout.preferredWidth: Design.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Design.s(2)
                                    Icon { role: "title"; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰽿"; color: Design.warn }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Design.s(4)
                                    Label { text: "Workspaces"; font.weight: Design.weight.semibold; Layout.fillWidth: true }
                                    Label { role: "caption"; text: "Static workspace count for helper views"; dim: true; Layout.fillWidth: true }
                                    
                                    RowLayout {
                                        Layout.topMargin: Design.s(8)
                                        spacing: Design.s(12)
                                        Rectangle {
                                            width: Design.s(30); height: Design.s(30); radius: Design.s(8)
                                            color: wsMinusMa.pressed ? Design.active : Design.hover
                                            border.color: wsMinusMa.containsMouse ? Design.warn : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                            Label { role: "subhead"; anchors.centerIn: parent; text: "-"; font.weight: Design.weight.semibold }
                                            Clickable { id: wsMinusMa; onClicked: root.setWorkspaceCount = Math.max(1, root.setWorkspaceCount - 1) }
                                        }
                                        Label {
                                            text: root.setWorkspaceCount.toString()
                                            font.weight: Design.weight.bold
                                            color: Design.warn
                                            Layout.minimumWidth: Design.s(40)
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Rectangle {
                                            width: Design.s(30); height: Design.s(30); radius: Design.s(8)
                                            color: wsPlusMa.pressed ? Design.active : Design.hover
                                            border.color: wsPlusMa.containsMouse ? Design.warn : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                            Label { role: "subhead"; anchors.centerIn: parent; text: "+"; font.weight: Design.weight.semibold }
                                            Clickable { id: wsPlusMa; onClicked: root.setWorkspaceCount = Math.min(20, root.setWorkspaceCount + 1) }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }

                }
            }
            
            // --- NEW PILL SAVE BUTTON ---
            Rectangle {
                id: floatingSaveBtn
                width: saveRow.implicitWidth + Design.s(32)
                height: Design.s(40)
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Design.s(24)
                radius: height / 2
                color: mainSaveMa.pressed ? Qt.darker(Design.accentAlt, 1.2) : (mainSaveMa.containsMouse ? Design.accentAlt : Design.raised)
                border.color: Design.accentAlt
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                RowLayout {
                    id: saveRow
                    anchors.centerIn: parent
                    spacing: Design.s(8)
                    
                    Icon {
                        text: "󰆓"
                        color: mainSaveMa.containsMouse ? Design.ground : Design.accentAlt
                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                    }
                    Label {
                        text: "Apply"
                        font.weight: Design.weight.semibold
                        color: mainSaveMa.containsMouse ? Design.ground : Design.text
                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                    }
                }
                
                Clickable { id: mainSaveMa; onClicked: root.saveAppSettings() }
            }
        }
    }
}
