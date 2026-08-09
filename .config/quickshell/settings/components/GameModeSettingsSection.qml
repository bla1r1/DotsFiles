import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Game Mode Settings
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property bool gameModeEnabled: Settings.gameModeEnabled !== undefined ? Settings.gameModeEnabled : false
    property bool gameModeInhibitIdle: Settings.gameModeInhibitIdle !== undefined ? Settings.gameModeInhibitIdle : true
    property bool gameModeMuteNotifs: Settings.gameModeMuteNotifs !== undefined ? Settings.gameModeMuteNotifs : true

    function toggleGameMode(val) {
        section.gameModeEnabled = val;
        Settings.set("gameModeEnabled", val);
        const script = Quickshell.env("HOME") + "/.config/sway/scripts/tools/game-mode.sh";
        Quickshell.execDetached(["bash", script, val ? "on" : "off"]);
    }

    // ── 1. Master Switch ─────────────────────────────────────────────────────
    Card {
        title: "Game Mode Performance"
        subtitle: "Optimize system responsiveness, disable desktop overhead, and maximize FPS"
        icon: "\u{f11b}"
        accentColor: Design.red

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Enable Game Mode"; weight: Design.weight.semibold }
                Label { text: section.gameModeEnabled ? "Active — CPU governor set to performance, desktop effects paused" : "Inactive"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeEnabled
                onToggled: section.toggleGameMode(!section.gameModeEnabled)
            }
        }
    }

    // ── 2. Automatic Rules & Tweaks ──────────────────────────────────────────
    Card {
        title: "Gaming Optimizations"
        subtitle: "Automated behaviors applied when Game Mode is engaged"
        icon: "\u{f085}"
        accentColor: Design.peach

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Inhibit Screen Sleep & DPMS"; weight: Design.weight.semibold }
                Label { text: "Prevents screen from turning off during controller or joystick gameplay"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeInhibitIdle
                onToggled: {
                    const next = !section.gameModeInhibitIdle;
                    section.gameModeInhibitIdle = next;
                    Settings.set("gameModeInhibitIdle", next);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Silence Popups & Notifications"; weight: Design.weight.semibold }
                Label { text: "Blocks distracting notification banners from appearing over games"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeMuteNotifs
                onToggled: {
                    const next = !section.gameModeMuteNotifs;
                    section.gameModeMuteNotifs = next;
                    Settings.set("gameModeMuteNotifs", next);
                }
            }
        }
    }
}
