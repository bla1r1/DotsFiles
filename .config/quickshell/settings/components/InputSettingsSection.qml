import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Mouse & Touchpad Settings
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

    property bool touchpadSwipeWorkspace: Settings.touchpadSwipeWorkspace !== undefined ? Settings.touchpadSwipeWorkspace : true
    property bool touchpadNaturalSwipe: Settings.touchpadNaturalSwipe !== undefined ? Settings.touchpadNaturalSwipe : true
    property bool touchpadPinchZoom: Settings.touchpadPinchZoom !== undefined ? Settings.touchpadPinchZoom : true

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
        title: "Touchpad Basics"
        subtitle: "Scrolling direction and tapping behavior"
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

                Toggle {
                    checked: section.naturalScroll
                    onToggled: section.setNaturalScroll(!section.naturalScroll)
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

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

                Toggle {
                    checked: section.tapToClick
                    onToggled: section.setTapToClick(!section.tapToClick)
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

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

                Toggle {
                    checked: section.dwt
                    onToggled: section.setDwt(!section.dwt)
                }
            }
        }
    }

    // ── 2. Multi-Touch Gestures ──────────────────────────────────────────────
    Card {
        title: "Multi-Touch Gestures"
        subtitle: "3-finger and 4-finger swipes for smooth desktop navigation"
        icon: "\u{f0048}"
        accentColor: Design.teal

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "3-Finger Workspace Swipe"; weight: Design.weight.semibold }
                    Label { text: "Swipe 3 fingers horizontally to smoothly transition between workspaces"; role: "caption"; dim: true }
                }

                Toggle {
                    checked: section.touchpadSwipeWorkspace
                    onToggled: {
                        const next = !section.touchpadSwipeWorkspace;
                        section.touchpadSwipeWorkspace = next;
                        Settings.set("touchpadSwipeWorkspace", next);
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Natural Gesture Direction"; weight: Design.weight.semibold }
                    Label { text: "Invert swipe motion to match direct touch manipulation"; role: "caption"; dim: true }
                }

                Toggle {
                    checked: section.touchpadNaturalSwipe
                    onToggled: {
                        const next = !section.touchpadNaturalSwipe;
                        section.touchpadNaturalSwipe = next;
                        Settings.set("touchpadNaturalSwipe", next);
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "Pinch to Zoom"; weight: Design.weight.semibold }
                    Label { text: "Allow 2-finger pinch gesture in browsers and document viewers"; role: "caption"; dim: true }
                }

                Toggle {
                    checked: section.touchpadPinchZoom
                    onToggled: {
                        const next = !section.touchpadPinchZoom;
                        section.touchpadPinchZoom = next;
                        Settings.set("touchpadPinchZoom", next);
                    }
                }
            }
        }
    }

    // ── 3. Mouse & Pointer Card ──────────────────────────────────────────────
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

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

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

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

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

                Toggle {
                    checked: section.leftHanded
                    onToggled: section.setLeftHanded(!section.leftHanded)
                }
            }
        }
    }
}
