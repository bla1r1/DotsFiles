import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"

// =============================================================================
// Startup & Services Manager (Dynamic App Picker & Custom Commands)
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property var autostartApps: Settings.autostartApps || ["polkit", "quickshell"]
    property var autostartCustom: Settings.autostartCustom || []
    property bool openGuideAtStartup: Settings.openGuideAtStartup || false
    property bool showAppPicker: false
    property string appSearchQuery: ""

    readonly property ListModel allInstalledApps: ListModel {}

    Process {
        id: allAppsScanner
        running: true
        command: ["b1air-daemon", "apps", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text);
                    section.allInstalledApps.clear();
                    for (let app of items) {
                        section.allInstalledApps.append({
                            name: app.name,
                            exec: app.exec,
                            desktopFile: app.desktopFile,
                            icon: app.icon,
                            comment: app.comment || ""
                        });
                    }
                } catch (e) {}
            }
        }
    }

    function isAppEnabled(id) {
        return (section.autostartApps || []).indexOf(id) !== -1;
    }

    function toggleApp(id) {
        var list = (section.autostartApps || []).slice();
        var idx = list.indexOf(id);
        if (idx === -1) {
            list.push(id);
        } else {
            list.splice(idx, 1);
        }
        section.autostartApps = list;
        Settings.set("autostartApps", list);
    }

    function addCustomApp(name, cmd, icon) {
        if (!name.trim() || !cmd.trim()) return;
        var list = (section.autostartCustom || []).slice();
        list.push({
            name: name.trim(),
            command: cmd.trim(),
            icon: icon || "",
            enabled: true
        });
        section.autostartCustom = list;
        Settings.set("autostartCustom", list);
        customNameInput.text = "";
        customCmdInput.text = "";
        section.showAppPicker = false;
    }

    function toggleCustomApp(index) {
        var list = (section.autostartCustom || []).slice();
        if (index >= 0 && index < list.length) {
            list[index].enabled = !list[index].enabled;
            section.autostartCustom = list;
            Settings.set("autostartCustom", list);
        }
    }

    function removeCustomApp(index) {
        var list = (section.autostartCustom || []).slice();
        if (index >= 0 && index < list.length) {
            list.splice(index, 1);
            section.autostartCustom = list;
            Settings.set("autostartCustom", list);
        }
    }

    // ── 1. Core Desktop Services ─────────────────────────────────────────────
    Card {
        title: "Desktop Environment Services"
        subtitle: "Core system components loaded automatically on login"
        icon: "\u{f0459}"
        accentColor: Design.sapphire

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰚰"; role: "title"; color: Design.sapphire }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Quickshell Desktop Shell"; weight: Design.weight.semibold }
                    Label { text: "Renders Control Center, Spotlight Launcher, and widgets"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("quickshell")
                    onToggled: section.toggleApp("quickshell")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰃚"; role: "title"; color: Design.blue }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Native Quickshell Top Bar"; weight: Design.weight.semibold }
                    Label { text: "Status bar with workspaces, clock, and hardware monitors"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("quickshell")
                    onToggled: section.toggleApp("quickshell")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰌾"; role: "title"; color: Design.peach }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Polkit Authentication Agent"; weight: Design.weight.semibold }
                    Label { text: "Handles graphical sudo and privileged permission prompts"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isAppEnabled("polkit")
                    onToggled: section.toggleApp("polkit")
                }
            }
        }
    }

    // ── 2. Applications Autostart ────────────────────────────────────────────
    Card {
        title: "Autostart Applications"
        subtitle: "Launch your favourite applications, background daemons, and scripts on login"
        icon: "\u{f009}"
        accentColor: Design.mauve

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Header Action: Choose from installed applications
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.sm)

                Label {
                    text: "Startup Programs"
                    weight: Design.weight.bold
                    role: "subhead"
                    Layout.fillWidth: true
                }

                ActionButton {
                    icon: "󰐕"
                    label: section.showAppPicker ? "Close App List" : "Add Installed App…"
                    tone: Design.sapphire
                    onActivated: section.showAppPicker = !section.showAppPicker
                }
            }

            // ── Installed Apps Search & Picker Grid (Expanded on demand) ──────
            Rectangle {
                visible: section.showAppPicker
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(220)
                radius: Design.s(Design.radius.card)
                color: Design.ground
                border.color: Design.glassBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    // Search input
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(32)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.surface
                        border.color: appSearchInput.activeFocus ? Design.sapphire : Design.tint(Design.line, 0.4)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(6)

                            Icon { text: "󰍉"; role: "caption"; color: Design.textDim }

                            TextInput {
                                id: appSearchInput
                                Layout.fillWidth: true
                                color: Design.text
                                font.pixelSize: Design.font.caption
                                clip: true
                                selectByMouse: true
                                onTextChanged: section.appSearchQuery = text.toLowerCase()
                                Text {
                                    text: "Search installed applications..."
                                    color: Design.textDim
                                    visible: !appSearchInput.text && !appSearchInput.activeFocus
                                    anchors.fill: parent
                                    font: appSearchInput.font
                                }
                            }
                        }
                    }

                    // App ListView
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Design.s(4)
                        model: section.allInstalledApps

                        delegate: Rectangle {
                            id: appPickerItem
                            required property var model
                            required property int index

                            visible: section.appSearchQuery === "" ||
                                     appPickerItem.model.name.toLowerCase().includes(section.appSearchQuery) ||
                                     appPickerItem.model.exec.toLowerCase().includes(section.appSearchQuery)

                            width: ListView.view ? ListView.view.width : 0
                            height: visible ? Design.s(36) : 0
                            radius: Design.s(6)
                            color: pickerMa.containsMouse ? Design.glassHover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Design.s(6)
                                spacing: Design.s(8)

                                Image {
                                    Layout.preferredWidth: Design.s(20)
                                    Layout.preferredHeight: Design.s(20)
                                    source: appPickerItem.model.icon ? (appPickerItem.model.icon.startsWith("/") ? "file://" + appPickerItem.model.icon : "image://icon/" + appPickerItem.model.icon) : ""
                                    visible: source.toString() !== ""
                                    fillMode: Image.PreserveAspectFit
                                }

                                Icon {
                                    visible: !parent.children[0].visible
                                    text: "󰄛"
                                    role: "caption"
                                    color: Design.sapphire
                                }

                                Label {
                                    text: appPickerItem.model.name
                                    weight: Design.weight.semibold
                                    role: "caption"
                                    elide: Text.ElideRight
                                    Layout.preferredWidth: Design.s(140)
                                }

                                Label {
                                    text: appPickerItem.model.exec
                                    role: "caption"
                                    dim: true
                                    isMono: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                ActionButton {
                                    icon: "󰐕"
                                    label: "Add"
                                    tone: Design.sapphire
                                    onActivated: section.addCustomApp(appPickerItem.model.name, appPickerItem.model.exec, appPickerItem.model.icon)
                                }
                            }

                            MouseArea {
                                id: pickerMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: section.addCustomApp(appPickerItem.model.name, appPickerItem.model.exec, appPickerItem.model.icon)
                            }
                        }
                    }
                }
            }

            // ── Manual Custom Binary / Script Row ────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.sm)

                Rectangle {
                    Layout.preferredWidth: Design.s(150)
                    Layout.preferredHeight: Design.s(36)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.surface
                    border.color: customNameInput.activeFocus ? Design.teal : Design.tint(Design.line, 0.4)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Design.s(Design.space.sm)
                        TextInput {
                            id: customNameInput
                            Layout.fillWidth: true
                            color: Design.text
                            font.pixelSize: Design.font.caption
                            clip: true
                            selectByMouse: true
                            Text {
                                text: "App Name..."
                                color: Design.textDim
                                visible: !customNameInput.text && !customNameInput.activeFocus
                                anchors.fill: parent
                                font: customNameInput.font
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(36)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.surface
                    border.color: customCmdInput.activeFocus ? Design.teal : Design.tint(Design.line, 0.4)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Design.s(Design.space.sm)
                        TextInput {
                            id: customCmdInput
                            Layout.fillWidth: true
                            color: Design.text
                            font.pixelSize: Design.font.caption
                            clip: true
                            selectByMouse: true
                            Text {
                                text: "Custom binary / command (e.g. syncthing, /opt/app/bin, steam -silent)..."
                                color: Design.textDim
                                visible: !customCmdInput.text && !customCmdInput.activeFocus
                                anchors.fill: parent
                                font: customCmdInput.font
                            }
                            onAccepted: section.addCustomApp(customNameInput.text, customCmdInput.text, "")
                        }
                    }
                }

                ActionButton {
                    icon: "󰐕"
                    label: "Add Binary"
                    tone: Design.teal
                    onActivated: section.addCustomApp(customNameInput.text, customCmdInput.text, "")
                }
            }

            // ── Active Startup Apps List ─────────────────────────────────────
            Repeater {
                model: section.autostartCustom || []
                delegate: ColumnLayout {
                    id: customAppItem
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4); visible: customAppItem.index > 0 }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(44)
                        spacing: Design.s(Design.space.md)

                        Icon { text: "󰄛"; role: "title"; color: Design.teal }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: customAppItem.modelData.name || "Custom App"; weight: Design.weight.semibold }
                            Label { text: customAppItem.modelData.command || ""; role: "caption"; isMono: true; dim: true }
                        }

                        Toggle {
                            checked: customAppItem.modelData.enabled !== false
                            onToggled: section.toggleCustomApp(customAppItem.index)
                        }

                        ActionButton {
                            icon: "󰆴"
                            tone: Design.danger
                            onActivated: section.removeCustomApp(customAppItem.index)
                        }
                    }
                }
            }
        }
    }

    // ── 3. Welcome & User Guide ──────────────────────────────────────────────
    Card {
        title: "Session Hints & Welcome Guide"
        subtitle: "Preferences for onboarding prompts and keybinding guides"
        icon: "\u{f02d}"
        accentColor: Design.yellow

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰋖"; role: "title"; color: Design.yellow }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Open Guide on Login"; weight: Design.weight.semibold }
                    Label { text: "Displays the keybinding and tips modal after desktop loads"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.openGuideAtStartup
                    onToggled: {
                        const next = !section.openGuideAtStartup;
                        section.openGuideAtStartup = next;
                        Settings.set("openGuideAtStartup", next);
                    }
                }
            }
        }
    }
}
