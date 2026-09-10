import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"
import B1air.Daemon

// =============================================================================
// Native Quickshell Top Bar Settings
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property string barPosition: Settings.barPosition || "top"
    property bool barShowWeather: Settings.barShowWeather !== undefined ? Settings.barShowWeather : true
    property bool barShowMedia: Settings.barShowMedia !== undefined ? Settings.barShowMedia : true
    property bool barShowTray: Settings.barShowTray !== undefined ? Settings.barShowTray : true
    property bool barClock24h: Settings.barClock24h !== undefined ? Settings.barClock24h : true

    function reloadTopBar() {
        Daemon.reload();
    }

    // ── 1. Position & Layout ─────────────────────────────────────────────────
    Card {
        title: "Bar Position & Time Format"
        subtitle: "Customize the native top bar placement and clock style"
        icon: "\u{f07e}"
        accentColor: Design.sapphire

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Screen Position"; weight: Design.weight.semibold }
                Label { text: "Pin the status bar to top or bottom edge of the screen"; role: "caption"; dim: true }
            }

            RowLayout {
                spacing: Design.s(Design.space.xs)
                Pill {
                    label: "Top"
                    active: section.barPosition === "top"
                    onClicked: {
                        section.barPosition = "top";
                        Settings.set("barPosition", "top");
                        section.reloadTopBar();
                    }
                }
                Pill {
                    label: "Bottom"
                    active: section.barPosition === "bottom"
                    onClicked: {
                        section.barPosition = "bottom";
                        Settings.set("barPosition", "bottom");
                        section.reloadTopBar();
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "24-Hour Time Format"; weight: Design.weight.semibold }
                Label { text: "Use military 24-hour time (e.g. 18:30) instead of 12-hour AM/PM"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.barClock24h
                onToggled: {
                    const next = !section.barClock24h;
                    section.barClock24h = next;
                    Settings.set("barClock24h", next);
                    section.reloadTopBar();
                }
            }
        }
    }

    // ── 2. Visible Modules ───────────────────────────────────────────────────
    Card {
        title: "Bar Modules & Widgets"
        subtitle: "Toggle visibility of individual modules in the top bar"
        icon: "\u{f009}"
        accentColor: Design.mauve

        // "Audio Visualizer (Cava)" used to be the first switch here. There is
        // no visualizer in the bar and no cava anywhere in this project — not
        // in the package list, not as a process, not as a module — so the
        // switch stored a value nothing read, promising a feature that does not
        // exist. Building it would mean taking on an external program, which is
        // the opposite of the direction the rest of the suite is going. Better
        // to not offer it than to offer it and do nothing.

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Weather Status"; weight: Design.weight.semibold }
                Label { text: "Show temperature and weather condition badge"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.barShowWeather
                onToggled: {
                    const next = !section.barShowWeather;
                    section.barShowWeather = next;
                    Settings.set("barShowWeather", next);
                    section.reloadTopBar();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Media Player Title"; weight: Design.weight.semibold }
                Label { text: "Display currently playing track name and artist"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.barShowMedia
                onToggled: {
                    const next = !section.barShowMedia;
                    section.barShowMedia = next;
                    Settings.set("barShowMedia", next);
                    section.reloadTopBar();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "System Tray"; weight: Design.weight.semibold }
                Label { text: "Show background applet icons (Telegram, Steam, etc.)"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.barShowTray
                onToggled: {
                    const next = !section.barShowTray;
                    section.barShowTray = next;
                    Settings.set("barShowTray", next);
                    section.reloadTopBar();
                }
            }
        }
    }

    // Used to live alone on its own "Interface Scale" page, back when it sat
    // next to a UI scale slider — that slider is gone (scale now follows the
    // display's own scale, set from Displays), leaving a page with nothing
    // but this one control. It's a bar setting; it belongs with the rest.
    Card {
        title: "Workspaces"
        subtitle: "How many workspace numbers the bar shows"
        icon: "\u{f0b60}"
        accentColor: Design.blue

        Stepper {
            label: "Workspace count"
            valueText: Settings.workspaceCount.toString()
            onDecrement: Settings.set("workspaceCount", Math.max(1, Settings.workspaceCount - 1))
            onIncrement: Settings.set("workspaceCount", Math.min(20, Settings.workspaceCount + 1))
        }
    }
}
