import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Appearance & Window Tweaks
//
// Allows live customization of:
// 1. Accent colors and theme palettes
// 2. Window inner and outer gaps with instant compositor feedback
// 3. Window borders, corner radius, blur, shadows, and dimming
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property int innerGaps: Settings.innerGaps !== undefined ? Settings.innerGaps : 5
    property int outerGaps: Settings.outerGaps !== undefined ? Settings.outerGaps : 20
    property int borderWidth: Settings.borderWidth !== undefined ? Settings.borderWidth : 2
    property int cornerRadius: Settings.cornerRadius !== undefined ? Settings.cornerRadius : 10
    property bool blurEnabled: Settings.blurEnabled !== undefined ? Settings.blurEnabled : true
    property bool shadowsEnabled: Settings.shadowsEnabled !== undefined ? Settings.shadowsEnabled : true
    property bool dimInactive: Settings.dimInactive !== undefined ? Settings.dimInactive : true

    function setInnerGaps(val) {
        section.innerGaps = val;
        Settings.set("innerGaps", val);
        Quickshell.execDetached(["swaymsg", "gaps", "inner", "current", "set", String(val)]);
    }

    function setOuterGaps(val) {
        section.outerGaps = val;
        Settings.set("outerGaps", val);
        Quickshell.execDetached(["swaymsg", "gaps", "outer", "current", "set", String(val)]);
    }

    function setBorderWidth(val) {
        section.borderWidth = val;
        Settings.set("borderWidth", val);
        Quickshell.execDetached(["swaymsg", "default_border", "pixel", String(val)]);
    }

    function setCornerRadius(val) {
        section.cornerRadius = val;
        Settings.set("cornerRadius", val);
        Quickshell.execDetached(["swaymsg", "corner_radius", String(val)]);
    }

    function toggleBlur(enabled) {
        section.blurEnabled = enabled;
        Settings.set("blurEnabled", enabled);
        Quickshell.execDetached(["swaymsg", "blur", enabled ? "enable" : "disable"]);
    }

    function toggleShadows(enabled) {
        section.shadowsEnabled = enabled;
        Settings.set("shadowsEnabled", enabled);
        Quickshell.execDetached(["swaymsg", "shadows", enabled ? "enable" : "disable"]);
    }

    function toggleDimInactive(enabled) {
        section.dimInactive = enabled;
        Settings.set("dimInactive", enabled);
        Quickshell.execDetached(["swaymsg", "default_dim_inactive", enabled ? "0.20" : "0.0"]);
    }

    // ── 1. Color Scheme & Accents ────────────────────────────────────────────
    Card {
        title: "Accent & Theme"
        subtitle: "Customize the primary accent color across Quickshell and Sway"
        icon: "\u{f0376}"
        accentColor: Design.mauve

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            Label { text: "Accent Color"; role: "caption"; dim: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.sm)

                Repeater {
                    model: [
                        { name: "Sapphire", color: "#74c7ec" },
                        { name: "Mauve", color: "#cba6f7" },
                        { name: "Teal", color: "#94e2d5" },
                        { name: "Peach", color: "#fab387" },
                        { name: "Pink", color: "#f5c2e7" },
                        { name: "Green", color: "#a6e3a1" },
                        { name: "Lavender", color: "#b4befe" },
                        { name: "Yellow", color: "#f9e2af" },
                        { name: "Red", color: "#f38ba8" }
                    ]

                    Rectangle {
                        id: accentDot
                        required property var modelData
                        width: Design.s(32)
                        height: width
                        radius: width / 2
                        color: accentDot.modelData.color
                        border.color: (Settings.accentName === accentDot.modelData.name) ? "#ffffff" : "transparent"
                        border.width: 2

                        Behavior on scale { NumberAnimation { duration: Design.duration.fast } }
                        scale: accentDotMa.pressed ? 0.9 : (accentDotMa.containsMouse ? 1.15 : 1.0)

                        Icon {
                            visible: (Settings.accentName === accentDot.modelData.name)
                            anchors.centerIn: parent
                            text: "\u{f012c}"
                            role: "caption"
                            color: "#11111b"
                        }

                        Clickable {
                            id: accentDotMa
                            onClicked: Settings.set("accentName", accentDot.modelData.name)
                        }
                    }
                }
            }
        }
    }

    // ── 2. Window Gaps ───────────────────────────────────────────────────────
    Card {
        title: "Window Spacing (Gaps)"
        subtitle: "Adjust inner and outer spacing between tiled windows"
        icon: "\u{f002b}"
        accentColor: Design.sapphire

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Stepper {
                label: "Inner Gaps (Between Windows)"
                valueText: section.innerGaps + " px"
                onDecrement: section.setInnerGaps(Math.max(0, section.innerGaps - 1))
                onIncrement: section.setInnerGaps(Math.min(30, section.innerGaps + 1))
            }

            Stepper {
                label: "Outer Gaps (Screen Edge)"
                valueText: section.outerGaps + " px"
                onDecrement: section.setOuterGaps(Math.max(0, section.outerGaps - 2))
                onIncrement: section.setOuterGaps(Math.min(40, section.outerGaps + 2))
            }
        }
    }

    // ── 3. Borders & Effects ─────────────────────────────────────────────────
    Card {
        title: "Borders & Compositor Effects"
        subtitle: "Window borders, corner rounding, blur, and inactive window dimming"
        icon: "\u{f02db}"
        accentColor: Design.teal

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            Stepper {
                label: "Window Border Width"
                valueText: section.borderWidth + " px"
                onDecrement: section.setBorderWidth(Math.max(0, section.borderWidth - 1))
                onIncrement: section.setBorderWidth(Math.min(8, section.borderWidth + 1))
            }

            Stepper {
                label: "Corner Radius (SwayFX)"
                valueText: section.cornerRadius + " px"
                onDecrement: section.setCornerRadius(Math.max(0, section.cornerRadius - 2))
                onIncrement: section.setCornerRadius(Math.min(24, section.cornerRadius + 2))
            }

            // Blur Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Window Blur"; weight: Design.weight.semibold }
                    Label { text: section.blurEnabled ? "Enabled" : "Disabled"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.blurEnabled
                    onToggled: section.toggleBlur(checked)
                }
            }

            // Shadows Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Window Shadows"; weight: Design.weight.semibold }
                    Label { text: section.shadowsEnabled ? "Enabled" : "Disabled"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.shadowsEnabled
                    onToggled: section.toggleShadows(checked)
                }
            }

            // Dim Inactive Windows Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Dim Inactive Windows"; weight: Design.weight.semibold }
                    Label { text: section.dimInactive ? "Enabled (20% dimming)" : "Disabled"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.dimInactive
                    onToggled: section.toggleDimInactive(checked)
                }
            }
        }
    }
}
