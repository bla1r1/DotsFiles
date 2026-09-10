import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Window Management & Gaps
//
// Live controls for:
// 1. Inner and Outer Gaps
// 2. Window Borders and Smart Borders
// 3. Smart Gaps and Inactive Window Opacity
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    readonly property int gapsInner: Settings.gapsInner
    readonly property int gapsOuter: Settings.gapsOuter
    readonly property int borderWidth: Settings.borderWidth
    readonly property bool smartBorders: Settings.smartBorders
    readonly property bool smartGaps: Settings.smartGaps
    readonly property real inactiveOpacity: Settings.inactiveOpacity

    function setGapsInner(val) {
        Settings.set("gapsInner", val);
        Quickshell.execDetached(["swaymsg", "gaps", "inner", "all", "set", String(val)]);
    }

    function setGapsOuter(val) {
        Settings.set("gapsOuter", val);
        Quickshell.execDetached(["swaymsg", "gaps", "outer", "all", "set", String(val)]);
    }

    function setBorderWidth(val) {
        Settings.set("borderWidth", val);
        Quickshell.execDetached(["swaymsg", "default_border", "pixel", String(val)]);
    }

    function toggleSmartBorders(val) {
        Settings.set("smartBorders", val);
        Quickshell.execDetached(["swaymsg", "smart_borders", val ? "on" : "off"]);
    }

    function toggleSmartGaps(val) {
        Settings.set("smartGaps", val);
        Quickshell.execDetached(["swaymsg", "smart_gaps", val ? "on" : "off"]);
    }

    // ── 1. Gaps Configuration ────────────────────────────────────────────────
    Card {
        title: "Window Spacing (Gaps)"
        subtitle: "Adjust the inner and outer spacing between tiled windows"
        icon: "\u{f0379}"
        accentColor: Design.sapphire

        Stepper {
            label: "Inner Gaps (between windows)"
            valueText: section.gapsInner + " px"
            onDecrement: section.setGapsInner(Math.max(0, section.gapsInner - 2))
            onIncrement: section.setGapsInner(Math.min(40, section.gapsInner + 2))
        }

        Stepper {
            label: "Outer Gaps (screen edges)"
            valueText: section.gapsOuter + " px"
            onDecrement: section.setGapsOuter(Math.max(0, section.gapsOuter - 2))
            onIncrement: section.setGapsOuter(Math.min(40, section.gapsOuter + 2))
        }
    }

    // ── 2. Borders & Smart Behavior ──────────────────────────────────────────
    Card {
        title: "Borders & Layout Rules"
        subtitle: "Window border styling and smart fullscreen/single window behaviors"
        icon: "\u{f016d}"
        accentColor: Design.mauve

        Stepper {
            label: "Border Width"
            valueText: section.borderWidth + " px"
            onDecrement: section.setBorderWidth(Math.max(0, section.borderWidth - 1))
            onIncrement: section.setBorderWidth(Math.min(8, section.borderWidth + 1))
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Smart Borders"; weight: Design.weight.semibold }
                Label { text: "Automatically hide window borders when only one window is open"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.smartBorders
                onToggled: section.toggleSmartBorders(!section.smartBorders)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Smart Gaps"; weight: Design.weight.semibold }
                Label { text: "Remove outer gaps when a workspace has only one window"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.smartGaps
                onToggled: section.toggleSmartGaps(!section.smartGaps)
            }
        }
    }
}
