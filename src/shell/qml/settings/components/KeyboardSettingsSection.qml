import QtQuick
import Quickshell
import "../../Ui"
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: section

    property string language: ""
    property string kbOptions: "grp:alt_shift_toggle"
    property string shortcutLabel: ""
    // langSearchModel and searchChanged were declared here and never connected
    // by SettingsApp, so the "Search to add…" field typed into nothing: the
    // dropdown's height binding read .count off an undefined model and stayed
    // 0, which meant there was no way to add a keyboard layout from Settings at
    // all — even though onLanguageAdded was already wired and waiting on the
    // other side. The list is local because the host has nothing to add to it.
    property string langQuery: ""
    property var langSearchModel: langResults

    readonly property var knownLayouts: [
        { code: "us", name: "English (US)" },
        { code: "gb", name: "English (UK)" },
        { code: "ua", name: "Ukrainian" },
        { code: "ru", name: "Russian" },
        { code: "de", name: "German" },
        { code: "fr", name: "French" },
        { code: "es", name: "Spanish" },
        { code: "it", name: "Italian" },
        { code: "pt", name: "Portuguese" },
        { code: "pl", name: "Polish" },
        { code: "cz", name: "Czech" },
        { code: "sk", name: "Slovak" },
        { code: "se", name: "Swedish" },
        { code: "no", name: "Norwegian" },
        { code: "fi", name: "Finnish" },
        { code: "dk", name: "Danish" },
        { code: "nl", name: "Dutch" },
        { code: "tr", name: "Turkish" },
        { code: "gr", name: "Greek" },
        { code: "il", name: "Hebrew" },
        { code: "ara", name: "Arabic" },
        { code: "hu", name: "Hungarian" },
        { code: "ro", name: "Romanian" },
        { code: "bg", name: "Bulgarian" },
        { code: "rs", name: "Serbian" },
        { code: "hr", name: "Croatian" },
        { code: "lt", name: "Lithuanian" },
        { code: "lv", name: "Latvian" },
        { code: "ee", name: "Estonian" },
        { code: "jp", name: "Japanese" },
        { code: "kr", name: "Korean" },
        { code: "cn", name: "Chinese" },
        { code: "in", name: "Indian" },
        { code: "ch", name: "Swiss" },
        { code: "be", name: "Belgian" },
        { code: "ca", name: "Canadian" },
        { code: "br", name: "Portuguese (Brazil)" },
        { code: "latam", name: "Spanish (Latin America)" }
    ]

    // A ListModel rather than a plain array: the dropdown below reads .count and
    // its delegate reads model.code / model.name.
    ListModel { id: langResults }

    onLangQueryChanged: section.refreshLangResults()

    function refreshLangResults() {
        langResults.clear();
        const q = section.langQuery.trim().toLowerCase();
        if (q === "")
            return;
        const already = section.language.split(",").filter(x => x !== "");
        for (const l of section.knownLayouts) {
            if (already.includes(l.code))
                continue;
            if (l.code.toLowerCase().includes(q) || l.name.toLowerCase().includes(q))
                langResults.append({ code: l.code, name: l.name });
        }
    }

    property var toggleOptions: []
    signal languageRemoved(int index)
    signal languageAdded(string code)
    signal searchChanged(string query)
    signal kbOptionsChangedByUser(string value)
    signal accepted()

    property bool shortcutOpen: false

    title: "Keyboard"
    subtitle: "Layouts and switch shortcut"
    icon: "\u{f030c}"
    accentColor: Design.mauve

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.s(14)

        Text {
            Layout.preferredWidth: Design.s(24)
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Design.s(2)
            horizontalAlignment: Text.AlignHCenter
            text: "󰌌"
            font.family: Design.font.icon
            font.pixelSize: Design.s(20)
            color: Design.ok
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(8)

            Text {
                text: "Keyboard layouts"
                color: Design.text
                font.family: Design.font.mono
                font.weight: Design.weight.semibold
                font.pixelSize: Design.s(13)
                Layout.fillWidth: true
            }

            Text {
                text: "Matches config. Click X to remove."
                color: Design.textDim
                font.family: Design.font.mono
                font.pixelSize: Design.s(11)
                Layout.fillWidth: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: Design.s(8)

                Repeater {
                    model: section.language ? section.language.split(",").filter(x => x.trim() !== "") : []

                    Rectangle {
                        width: chipLayout.implicitWidth + Design.s(24)
                        height: Design.s(28)
                        radius: Design.s(14)
                        color: Design.raised
                        border.color: chipArea.containsMouse ? Design.danger : Design.hover
                        border.width: 1

                        RowLayout {
                            id: chipLayout
                            anchors.centerIn: parent
                            spacing: Design.s(8)

                            Text {
                                text: modelData
                                color: chipArea.containsMouse ? Design.danger : Design.text
                                font.family: Design.font.mono
                                font.weight: Design.weight.semibold
                                font.pixelSize: Design.s(12)
                            }

                            Text {
                                text: "x"
                                color: chipArea.containsMouse ? Design.danger : Design.textDim
                                font.family: Design.font.mono
                                font.pixelSize: Design.s(13)
                            }
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.languageRemoved(index)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(6)
                color: Design.surface
                border.color: langInput.activeFocus ? Design.ok : Design.hover
                border.width: 1

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
                    onTextChanged: {
                        section.langQuery = text;
                        section.searchChanged(text);
                    }
                    onAccepted: section.accepted()

                    Text {
                        text: "Search to add..."
                        color: Design.textDim
                        visible: !parent.text && !parent.activeFocus
                        font: parent.font
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: langInput.activeFocus && section.langSearchModel && section.langSearchModel.count > 0 ? Math.min(Design.s(150), section.langSearchModel.count * Design.s(32)) : 0
                radius: Design.s(6)
                color: Design.surface
                border.color: Design.ok
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.langSearchModel
                    interactive: true
                    ScrollBar.vertical: OverflowBar {}

                    delegate: Rectangle {
                        width: parent.width
                        height: Design.s(32)
                        color: searchArea.containsMouse ? Design.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(12)
                            anchors.rightMargin: Design.s(12)
                            spacing: Design.s(10)

                            Text {
                                text: model.code
                                color: Design.text
                                font.family: Design.font.mono
                                font.weight: Design.weight.semibold
                                font.pixelSize: Design.s(12)
                            }

                            Text {
                                text: model.name
                                color: Design.textDim
                                font.family: Design.font.mono
                                font.pixelSize: Design.s(11)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: searchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                section.languageAdded(model.code);
                                langInput.text = "";
                                langInput.focus = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.alpha(Design.raised, 0.5)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.s(14)

        Text {
            Layout.preferredWidth: Design.s(24)
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Design.s(2)
            horizontalAlignment: Text.AlignHCenter
            text: "󰯍"
            font.family: Design.font.icon
            font.pixelSize: Design.s(20)
            color: Qt.alpha(Design.ok, 0.7)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(8)

            Text {
                text: "Layout shortcut"
                color: Design.text
                font.family: Design.font.mono
                font.weight: Design.weight.semibold
                font.pixelSize: Design.s(13)
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(36)
                radius: Design.s(6)
                color: Design.surface
                border.color: section.shortcutOpen ? Design.ok : Design.hover
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(10)

                    Text {
                        text: section.shortcutLabel
                        color: Design.text
                        font.family: Design.font.mono
                        font.pixelSize: Design.s(12)
                        Layout.fillWidth: true
                    }

                    Text {
                        text: section.shortcutOpen ? "^" : "v"
                        color: Design.textDim
                        font.pixelSize: Design.s(14)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.shortcutOpen = !section.shortcutOpen
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: section.shortcutOpen ? section.toggleOptions.length * Design.s(32) : 0
                radius: Design.s(6)
                color: Design.surface
                border.color: Design.ok
                border.width: Layout.preferredHeight > 0 ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }

                ListView {
                    anchors.fill: parent
                    model: section.toggleOptions
                    interactive: false

                    delegate: Rectangle {
                        width: parent.width
                        height: Design.s(32)
                        color: toggleArea.containsMouse ? Design.hover : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Design.s(12)
                            text: modelData.label
                            color: section.kbOptions === modelData.val ? Design.ok : Design.text
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(12)
                        }

                        MouseArea {
                            id: toggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                section.kbOptionsChangedByUser(modelData.val);
                                section.shortcutOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 2. Keybindings Cheat Sheet Card ──────────────────────────────────────
    Card {
        id: shortcutsCard
        title: "Keyboard Shortcuts & Keybinds"
        subtitle: "Click any shortcut to edit and rebind it in real-time"
        icon: "\u{f030c}"
        accentColor: Design.sapphire

        property string searchFilter: ""
        property string activeCategory: "All"
        property string editingId: ""
        property string editKeys: ""
        property string statusMsg: ""

        readonly property var allBindings: [
            { id: "settings", cat: "System", keys: "$mod+shift+s", label: "SUPER + SHIFT + S", desc: "Open Settings App", cmd: "exec b1air-shell toggle settings" },
            { id: "control", cat: "System", keys: "$mod+c", label: "SUPER + C", desc: "Toggle Control Center", cmd: "exec b1air-shell toggle control" },
            { id: "guide", cat: "System", keys: "$mod+h", label: "SUPER + H", desc: "Open About This System", cmd: "exec b1air-shell open settings about" },
            { id: "wallpaper", cat: "System", keys: "$mod+w", label: "SUPER + W", desc: "Open Wallpaper Gallery", cmd: "exec b1air-shell open settings wallpaper" },
            { id: "battery", cat: "System", keys: "$mod+b", label: "SUPER + B", desc: "Toggle Battery / Power", cmd: "exec b1air-shell toggle battery" },
            { id: "network", cat: "System", keys: "$mod+n", label: "SUPER + N", desc: "Toggle Network Manager", cmd: "exec b1air-shell toggle network" },
            { id: "monitors", cat: "System", keys: "$mod+m", label: "SUPER + M", desc: "Toggle Displays Manager", cmd: "exec b1air-shell toggle monitors" },
            { id: "focustime", cat: "System", keys: "$mod+shift+t", label: "SUPER + SHIFT + T", desc: "Toggle FocusTime Daemon", cmd: "exec b1air-shell toggle focustime" },
            { id: "terminal", cat: "Apps", keys: "$mod+t", label: "SUPER + T", desc: "Launch Terminal", cmd: "exec $terminal" },
            { id: "menu", cat: "Apps", keys: "$mod+space", label: "SUPER + SPACE", desc: "Application Launcher", cmd: "exec $menu" },
            { id: "files", cat: "Apps", keys: "$mod+e", label: "SUPER + E", desc: "File Manager", cmd: "exec $fileManager" },
            { id: "browser", cat: "Apps", keys: "$mod+f", label: "SUPER + F", desc: "Web Browser (Firefox)", cmd: "exec firefox" },
            { id: "github", cat: "Apps", keys: "$mod+g", label: "SUPER + G", desc: "GitHub Desktop", cmd: "exec github-desktop" },
            { id: "close", cat: "Windows", keys: "$mod+q", label: "SUPER + Q", desc: "Close Focused Window", cmd: "kill" },
            { id: "floating", cat: "Windows", keys: "$mod+ctrl+space", label: "SUPER + CTRL + SPACE", desc: "Toggle Floating Window", cmd: "floating toggle" },
            { id: "fullscreen", cat: "Windows", keys: "$mod+shift+f", label: "SUPER + SHIFT + F", desc: "Toggle Fullscreen", cmd: "exec b1air-daemon fullscreen-toggle" },
            { id: "focus_left", cat: "Windows", keys: "$mod+Left", label: "SUPER + Left", desc: "Focus Window Left", cmd: "focus left" },
            { id: "focus_right", cat: "Windows", keys: "$mod+Right", label: "SUPER + Right", desc: "Focus Window Right", cmd: "focus right" },
            { id: "focus_up", cat: "Windows", keys: "$mod+Up", label: "SUPER + Up", desc: "Focus Window Up", cmd: "focus up" },
            { id: "focus_down", cat: "Windows", keys: "$mod+Down", label: "SUPER + Down", desc: "Focus Window Down", cmd: "focus down" }
        ]

        readonly property var filteredBindings: shortcutsCard.allBindings.filter(b => {
            const matchCat = (shortcutsCard.activeCategory === "All" || b.cat === shortcutsCard.activeCategory);
            const matchSearch = (!shortcutsCard.searchFilter || b.desc.toLowerCase().includes(shortcutsCard.searchFilter.toLowerCase()) || b.keys.toLowerCase().includes(shortcutsCard.searchFilter.toLowerCase()) || b.label.toLowerCase().includes(shortcutsCard.searchFilter.toLowerCase()));
            return matchCat && matchSearch;
        })

        function saveBinding(item, newKey) {
            if (!newKey || newKey.trim() === "") return;
            const cleanKey = newKey.trim();
            if (!/^[A-Za-z0-9+_<>-]+$/.test(cleanKey)) {
                shortcutsCard.statusMsg = "Unsupported key format";
                statusTimer.restart();
                return;
            }
            const cmd = "mkdir -p ~/.config/sway/conf.d && printf '%s\\n' \"bindsym --to-code $1 $2\" >> ~/.config/sway/conf.d/custom_keybinds.conf && swaymsg reload";
            Quickshell.execDetached(["bash", "-c", cmd, "--", cleanKey, item.cmd]);
            shortcutsCard.editingId = "";
            shortcutsCard.statusMsg = "Keybind updated to " + cleanKey + " & Sway reloaded!";
            statusTimer.restart();
        }

        Timer {
            id: statusTimer
            interval: 3000
            onTriggered: shortcutsCard.statusMsg = ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Status message
            Rectangle {
                visible: shortcutsCard.statusMsg !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(28)
                radius: Design.s(Design.radius.ctl)
                color: Design.tint(Design.green, 0.15)
                border.color: Design.green
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    text: shortcutsCard.statusMsg
                    role: "caption"
                    weight: Design.weight.semibold
                    color: Design.green
                }
            }

            // Search bar & Category filters
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.sm)

                Field {
                    Layout.fillWidth: true
                    placeholder: "Search shortcuts (e.g. terminal, settings, window)..."
                    text: shortcutsCard.searchFilter
                    onEdited: v => shortcutsCard.searchFilter = v
                }

                RowLayout {
                    spacing: Design.s(Design.space.xs)

                    Repeater {
                        model: ["All", "System", "Apps", "Windows"]

                        Pill {
                            id: catPill
                            required property string modelData
                            label: catPill.modelData
                            active: shortcutsCard.activeCategory === catPill.modelData
                            activeColor: Design.sapphire
                            onClicked: shortcutsCard.activeCategory = catPill.modelData
                        }
                    }
                }
            }

            // Shortcuts list
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.xs)

                Repeater {
                    model: shortcutsCard.filteredBindings

                    Rectangle {
                        id: bindRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: shortcutsCard.editingId === bindRow.modelData.id ? Design.s(72) : Design.s(38)
                        radius: Design.s(Design.radius.ctl)
                        color: shortcutsCard.editingId === bindRow.modelData.id ? Design.tint(Design.sapphire, 0.1) : (rowHoverMa.containsMouse ? Design.raised : Design.sunken)
                        border.color: shortcutsCard.editingId === bindRow.modelData.id ? Design.sapphire : "transparent"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(Design.space.sm)
                            spacing: Design.s(Design.space.xs)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(Design.space.md)

                                Badge {
                                    text: bindRow.modelData.cat
                                    tone: Design.sapphire
                                }

                                Label {
                                    text: bindRow.modelData.desc
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    radius: Design.s(4)
                                    color: Design.raised
                                    border.color: Design.veilStrong
                                    border.width: 1
                                    Layout.preferredHeight: Design.s(24)
                                    Layout.preferredWidth: keyTxt.implicitWidth + Design.s(16)

                                    Label {
                                        id: keyTxt
                                        anchors.centerIn: parent
                                        text: bindRow.modelData.label
                                        role: "caption"
                                        isMono: true
                                        weight: Design.weight.bold
                                        color: Design.sapphire
                                    }
                                }

                                IconButton {
                                    icon: "\u{f03eb}" // pencil
                                    role: "caption"
                                    hoverTone: Design.sapphire
                                    onClicked: {
                                        if (shortcutsCard.editingId === bindRow.modelData.id) {
                                            shortcutsCard.editingId = "";
                                        } else {
                                            shortcutsCard.editingId = bindRow.modelData.id;
                                            shortcutsCard.editKeys = bindRow.modelData.keys;
                                        }
                                    }
                                }
                            }

                            // Inline editing row
                            RowLayout {
                                visible: shortcutsCard.editingId === bindRow.modelData.id
                                Layout.fillWidth: true
                                spacing: Design.s(Design.space.sm)

                                Field {
                                    Layout.fillWidth: true
                                    placeholder: "New key combo (e.g. $mod+t, $mod+Return)..."
                                    text: shortcutsCard.editKeys
                                    onEdited: v => shortcutsCard.editKeys = v
                                }

                                ActionButton {
                                    icon: "\u{f012c}"
                                    label: "Save"
                                    onActivated: shortcutsCard.saveBinding(bindRow.modelData, shortcutsCard.editKeys)
                                }

                                ActionButton {
                                    icon: "\u{f0156}"
                                    label: "Cancel"
                                    onActivated: shortcutsCard.editingId = ""
                                }
                            }
                        }

                        MouseArea {
                            id: rowHoverMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }
        }
    }
}
