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
    property bool gameModeAdaptiveSync: Settings.gameModeAdaptiveSync !== undefined ? Settings.gameModeAdaptiveSync : false
    property bool gameModeHideWaybar: Settings.gameModeHideWaybar !== undefined ? Settings.gameModeHideWaybar : true
    property bool gameModeDND: Settings.gameModeDND !== undefined ? Settings.gameModeDND : false

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
                Label { text: section.gameModeEnabled ? "Active — CPU governor set to performance, compositor blur & shadows disabled" : "Inactive"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeEnabled
                onToggled: section.toggleGameMode(!section.gameModeEnabled)
            }
        }
    }

    // ── 2. Display & Desktop Options ─────────────────────────────────────────
    Card {
        title: "Display & Desktop Overlays"
        subtitle: "Configurable behaviors applied when Game Mode is active"
        icon: "\u{f108}"
        accentColor: Design.cyan

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Hide Top Bar (Waybar)"; weight: Design.weight.semibold }
                Label { text: "Temporarily hides the top bar during gaming to prevent overlay latency"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeHideWaybar
                onToggled: {
                    const next = !section.gameModeHideWaybar;
                    section.gameModeHideWaybar = next;
                    Settings.set("gameModeHideWaybar", next);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Adaptive Sync / VRR (FreeSync & G-Sync)"; weight: Design.weight.semibold }
                Label { text: "Enables variable refresh rate on supported monitors for tear-free gaming"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeAdaptiveSync
                onToggled: {
                    const next = !section.gameModeAdaptiveSync;
                    section.gameModeAdaptiveSync = next;
                    Settings.set("gameModeAdaptiveSync", next);
                }
            }
        }
    }

    // ── 3. Notifications & Focus ─────────────────────────────────────────────
    Card {
        title: "Focus & Notifications"
        subtitle: "Manage alerts and popup banners while playing games"
        icon: "\u{f0f3}"
        accentColor: Design.peach

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Silence Notifications (Do Not Disturb)"; weight: Design.weight.semibold }
                Label { text: "Mutes incoming toast notifications so they do not steal focus during games"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.gameModeDND
                onToggled: {
                    const next = !section.gameModeDND;
                    section.gameModeDND = next;
                    Settings.set("gameModeDND", next);
                }
            }
        }
    }
}
