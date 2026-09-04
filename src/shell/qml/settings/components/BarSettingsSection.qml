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
    property bool barShowCava: Settings.barShowCava !== undefined ? Settings.barShowCava : true
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Audio Visualizer (Cava)"; weight: Design.weight.semibold }
                Label { text: "Show real-time equalizer bars next to workspace indicator"; role: "caption"; dim: true }
            }

            Toggle {
                checked: section.barShowCava
                onToggled: {
                    const next = !section.barShowCava;
                    section.barShowCava = next;
                    Settings.set("barShowCava", next);
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
}
