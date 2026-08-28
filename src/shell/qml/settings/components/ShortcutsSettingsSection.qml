import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Interactive Shortcuts & Keybindings Reference
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property string query: ""

    readonly property var categories: [
        {
            title: "Spotlight & App Launchers",
            icon: "󰄛",
            color: Design.sapphire,
            items: [
                { key: "Mod + Space", label: "Spotlight Launcher", desc: "Launch apps, calculate math, run shell commands" },
                { key: "Mod + Return", label: "Kitty Terminal", desc: "Open GPU-accelerated terminal emulator" },
                { key: "Mod + F", label: "Web Browser", desc: "Open default internet browser" },
                { key: "Mod + E", label: "File Manager", desc: "Open graphical files & directories explorer" },
                { key: "Mod + C", label: "Code Editor", desc: "Launch default text & code editor" }
            ]
        },
        {
            title: "Control Center & Popups",
            icon: "󰚰",
            color: Design.blue,
            items: [
                { key: "Mod + P", label: "Control Center", desc: "Open quick tiles, weather, and media hub" },
                { key: "Mod + K", label: "Keyboard Layouts", desc: "Switch input sources (US, UA, etc.)" },
                { key: "Mod + V", label: "Clipboard Manager", desc: "View and paste copied text history" },
                { key: "Mod + D", label: "Calendar & Schedule", desc: "Open calendar and task planner" },
                { key: "Mod + N", label: "Network & Wi-Fi", desc: "Scan and connect to wireless networks" },
                { key: "Mod + B", label: "Bluetooth", desc: "Manage paired and nearby bluetooth devices" },
                { key: "Mod + Shift + T", label: "Screen Time & Focus", desc: "View daily app statistics and timer" },
                { key: "Mod + Shift + E", label: "Power & Session Menu", desc: "Lock, Sleep, Reboot, or Power off" }
            ]
        },
        {
            title: "Window & Workspace Management",
            icon: "󰖲",
            color: Design.mauve,
            items: [
                { key: "Mod + Shift + F", label: "Smart Fullscreen", desc: "Seamless fullscreen toggle with auto-centering" },
                { key: "Mod + Shift + V", label: "Floating Toggle", desc: "Toggle window between tiling and floating" },
                { key: "Mod + Shift + Q", label: "Close Window", desc: "Gracefully terminate focused application" },
                { key: "Mod + Shift + I", label: "Split Direction", desc: "Toggle horizontal / vertical split orientation" },
                { key: "Mod + Arrows", label: "Focus Navigation", desc: "Move focus Left / Right / Up / Down" },
                { key: "Mod + Ctrl + Arrows", label: "Move Window", desc: "Relocate window within tiling container" },
                { key: "Mod + R", label: "Resize Mode", desc: "Adjust container width and height with arrows" },
                { key: "Mod + 1 .. 9", label: "Switch Workspace", desc: "Jump directly to numbered desktop workspace" },
                { key: "Mod + Shift + 1 .. 9", label: "Move to Workspace", desc: "Send focused window to workspace" }
            ]
        },
        {
            title: "Gaming & Hardware Controls",
            icon: "󰓓",
            color: Design.red,
            items: [
                { key: "Mod + Shift + G", label: "Game Mode Toggle", desc: "Disable compositor overhead and set performance governor" },
                { key: "Print", label: "Area Screenshot", desc: "Select area to copy to clipboard and save" },
                { key: "Mod + Print", label: "Full Screenshot", desc: "Capture entire desktop output" },
                { key: "XF86AudioRaise / Lower", label: "Volume Control", desc: "Increase or decrease Master output level" },
                { key: "XF86AudioMute", label: "Mute Sound", desc: "Toggle speaker and headphones mute state" },
                { key: "XF86MonBrightnessUp / Down", label: "Screen Brightness", desc: "Adjust laptop and monitor backlight level" }
            ]
        }
    ]

    // ── Search & Filter ──────────────────────────────────────────────────────
    Card {
        title: "Keyboard Shortcuts Reference"
        subtitle: "Complete cheatsheet of desktop keybindings and global triggers"
        icon: "\u{f11c}"
        accentColor: Design.sapphire

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(38)
                radius: Design.s(Design.radius.ctl)
                color: Design.surface
                border.color: searchInput.activeFocus ? Design.accent : Design.tint(Design.line, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    Icon { text: "󰍉"; role: "caption"; color: Design.textDim }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Design.text
                        font.pixelSize: Design.font.caption
                        clip: true
                        selectByMouse: true
                        Text {
                            text: "Type to filter shortcuts (e.g. fullscreen, volume, space)..."
                            color: Design.textDim
                            visible: !searchInput.text && !searchInput.activeFocus
                            anchors.fill: parent
                            font: searchInput.font
                        }
                        onTextChanged: section.query = text.toLowerCase().trim()
                    }
                }
            }
        }
    }

    // ── Categories ───────────────────────────────────────────────────────────
    Repeater {
        model: section.categories
        delegate: ColumnLayout {
            id: catCol
            required property var modelData
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)
            visible: categoryItems.count > 0

            Card {
                title: catCol.modelData.title
                icon: catCol.modelData.icon
                accentColor: catCol.modelData.color

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Repeater {
                        id: categoryItems
                        model: {
                            var items = catCol.modelData.items;
                            if (!section.query) return items;
                            return items.filter(function(item) {
                                return item.key.toLowerCase().indexOf(section.query) !== -1 ||
                                       item.label.toLowerCase().indexOf(section.query) !== -1 ||
                                       item.desc.toLowerCase().indexOf(section.query) !== -1;
                            });
                        }
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(36)
                            spacing: Design.s(Design.space.md)

                            Rectangle {
                                Layout.preferredWidth: Design.s(160)
                                Layout.preferredHeight: Design.s(28)
                                radius: Design.s(Design.radius.pill)
                                color: Design.raised
                                border.color: Design.tint(catCol.modelData.color || Design.accent, 0.4)
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    role: "caption"
                                    weight: Design.weight.semibold
                                    color: catCol.modelData.color || Design.accent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { text: modelData.label; weight: Design.weight.semibold; role: "caption" }
                                Label { text: modelData.desc; role: "caption"; dim: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
