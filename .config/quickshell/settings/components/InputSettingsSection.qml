import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Mouse & Touchpad Settings
//
// Direct integration with Sway input subsystem:
// - Touchpad: natural scrolling, tap-to-click, dwt, middle click emulation
// - Mouse: pointer speed / acceleration, accel profile (flat/adaptive)
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property bool naturalScroll: Settings.naturalScroll !== undefined ? Settings.naturalScroll : false
    property bool tapToClick: Settings.tapToClick !== undefined ? Settings.tapToClick : true
    property bool dwt: Settings.dwt !== undefined ? Settings.dwt : true
    property real pointerAccel: Settings.pointerAccel !== undefined ? Settings.pointerAccel : 0.0
    property string accelProfile: Settings.accelProfile || "flat"
    property bool leftHanded: Settings.leftHanded !== undefined ? Settings.leftHanded : false

    function setNaturalScroll(on) {
        section.naturalScroll = on;
        Settings.set("naturalScroll", on);
        Quickshell.execDetached(["swaymsg", "input", "type:touchpad", "natural_scroll", on ? "enabled" : "disabled"]);
    }

    function setTapToClick(on) {
        section.tapToClick = on;
        Settings.set("tapToClick", on);
        Quickshell.execDetached(["swaymsg", "input", "type:touchpad", "tap", on ? "enabled" : "disabled"]);
    }

    function setDwt(on) {
        section.dwt = on;
        Settings.set("dwt", on);
        Quickshell.execDetached(["swaymsg", "input", "type:touchpad", "dwt", on ? "enabled" : "disabled"]);
    }

    function setPointerAccel(val) {
        section.pointerAccel = val;
        Settings.set("pointerAccel", val);
        Quickshell.execDetached(["swaymsg", "input", "type:pointer", "pointer_accel", String(val)]);
        Quickshell.execDetached(["swaymsg", "input", "type:touchpad", "pointer_accel", String(val)]);
    }

    function setAccelProfile(prof) {
        section.accelProfile = prof;
        Settings.set("accelProfile", prof);
        Quickshell.execDetached(["swaymsg", "input", "type:pointer", "accel_profile", prof]);
    }

    function setLeftHanded(on) {
        section.leftHanded = on;
        Settings.set("leftHanded", on);
        Quickshell.execDetached(["swaymsg", "input", "type:pointer", "left_handed", on ? "enabled" : "disabled"]);
    }

    // ── 1. Touchpad Card ─────────────────────────────────────────────────────
    Card {
        title: "Touchpad"
        subtitle: "Gestures, scrolling, and tapping behavior"
        icon: "\u{f0523}"
        accentColor: Design.peach

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Natural Scrolling
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Natural Scrolling"; weight: Design.weight.semibold }
                    Label { text: "Content moves in direction of fingers (macOS style)"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.naturalScroll
                    onToggled: section.setNaturalScroll(checked)
                }
            }

            // Tap to click
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Tap to Click"; weight: Design.weight.semibold }
                    Label { text: "Tap touchpad with 1 finger for primary click, 2 for right click"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.tapToClick
                    onToggled: section.setTapToClick(checked)
                }
            }

            // Disable while typing
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Disable While Typing (DWT)"; weight: Design.weight.semibold }
                    Label { text: "Avoid accidental cursor moves while typing on keyboard"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.dwt
                    onToggled: section.setDwt(checked)
                }
            }
        }
    }

    // ── 2. Mouse & Pointer Card ──────────────────────────────────────────────
    Card {
        title: "Mouse & Pointer"
        subtitle: "Tracking speed, acceleration profiles, and primary button"
        icon: "\u{f037d}"
        accentColor: Design.sapphire

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Pointer Speed
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.xs)

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Pointer Speed / Sensitivity"; weight: Design.weight.semibold }
                    Item { Layout.fillWidth: true }
                    Label { text: Math.round((section.pointerAccel + 1.0) * 50) + "%"; role: "caption"; isMono: true; color: Design.sapphire }
                }

                Slider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(Design.size.ctl)
                    value: Math.round((section.pointerAccel + 1.0) * 50)
                    tone: Design.sapphire
                    icon: "\u{f037d}"
                    onMoved: pct => {
                        const val = ((pct / 50) - 1.0).toFixed(2);
                        section.setPointerAccel(parseFloat(val));
                    }
                }
            }

            // Acceleration Profile
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Acceleration Profile"; weight: Design.weight.semibold }
                    Label { text: section.accelProfile === "flat" ? "Flat: 1:1 linear tracking" : "Adaptive: faster flicks travel further"; role: "caption"; dim: true }
                }

                RowLayout {
                    spacing: Design.s(Design.space.xs)

                    Pill {
                        label: "Flat (Linear)"
                        active: section.accelProfile === "flat"
                        activeColor: Design.sapphire
                        onClicked: section.setAccelProfile("flat")
                    }

                    Pill {
                        label: "Adaptive"
                        active: section.accelProfile === "adaptive"
                        activeColor: Design.sapphire
                        onClicked: section.setAccelProfile("adaptive")
                    }
                }
            }

            // Left-handed Mode
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Left-Handed Mouse Mode"; weight: Design.weight.semibold }
                    Label { text: "Swap left and right mouse buttons"; role: "caption"; dim: true }
                }

                Switch {
                    checked: section.leftHanded
                    onToggled: section.setLeftHanded(checked)
                }
            }
        }
    }
}
