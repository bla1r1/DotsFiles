import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Night Light & Eye Care
//
// Controls screen color temperature to reduce eye strain at night.
// Integrates with wlsunset / gammastep.
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property bool nightLightEnabled: Settings.nightLightEnabled !== undefined ? Settings.nightLightEnabled : false
    property int tempK: Settings.nightLightTemp !== undefined ? Settings.nightLightTemp : 4000

    function applyTemp(enabled, temp) {
        section.nightLightEnabled = enabled;
        section.tempK = temp;
        // One apply() instead of two set() calls. Two set() calls in a single
        // handler lose one of the two: each set() writes the file, and a write
        // started mid-handler clobbers the change that follows it — measured on
        // a live shell, five sets in one tick kept only the 1st, 3rd and 5th,
        // in memory as well as on disk. apply() mutates the adapter for every
        // key first and writes once, which is the shape that survives.
        // This was the only handler in the shell calling set() more than once.
        Settings.apply({ nightLightEnabled: enabled, nightLightTemp: temp });

        if (!enabled) {
            Quickshell.execDetached(["bash", "-c", "killall wlsunset gammastep 2>/dev/null || true"]);
        } else {
            Quickshell.execDetached(["bash", "-c",
                "killall wlsunset gammastep 2>/dev/null || true; wlsunset -t " + temp + " -T " + temp + " 2>/dev/null || gammastep -O " + temp + " 2>/dev/null &"
            ]);
        }
    }

    // ── 1. Master Control ────────────────────────────────────────────────────
    Card {
        title: "Night Light"
        subtitle: section.nightLightEnabled
            ? "Active at " + section.tempK + "K color temperature"
            : "Reduce blue light in evening hours to protect sleep"
        icon: "\u{f0599}"
        accentColor: Design.yellow

        Toggle {
            label: "Night Light State"
            subtitle: section.nightLightEnabled ? "Enabled" : "Disabled"
            checked: section.nightLightEnabled
            onToggled: section.applyTemp(!section.nightLightEnabled, section.tempK)
        }
    }

    // ── 2. Color Temperature Slider & Presets ────────────────────────────────
    Card {
        visible: section.nightLightEnabled
        title: "Color Temperature"
        subtitle: "Lower values produce warmer, amber tones with less blue light"
        icon: "\u{f0590}"
        accentColor: Design.yellow

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Color Warmth"; weight: Design.weight.semibold }
                Item { Layout.fillWidth: true }
                Label { text: section.tempK + " K"; role: "caption"; isMono: true; color: Design.yellow }
            }

            // Slider: 2500K to 6500K mapped to 0..100
            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(Design.size.ctl)
                value: Math.round(((section.tempK - 2500) / 4000) * 100)
                tone: Design.yellow
                icon: "\u{f0590}"
                onMoved: pct => {
                    const temp = Math.round(2500 + (pct / 100) * 4000);
                    section.applyTemp(true, temp);
                }
            }

            Label { text: "Quick Warmth Presets"; role: "caption"; dim: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.xs)

                Pill {
                    label: "Candle (2700K)"
                    active: section.tempK === 2700
                    activeColor: Design.yellow
                    onClicked: section.applyTemp(true, 2700)
                }

                Pill {
                    label: "Warm Incandescent (3400K)"
                    active: section.tempK === 3400
                    activeColor: Design.yellow
                    onClicked: section.applyTemp(true, 3400)
                }

                Pill {
                    label: "Sunset (4500K)"
                    active: section.tempK === 4500
                    activeColor: Design.yellow
                    onClicked: section.applyTemp(true, 4500)
                }

                Pill {
                    label: "Daylight (6500K)"
                    active: section.tempK === 6500
                    activeColor: Design.yellow
                    onClicked: section.applyTemp(true, 6500)
                }
            }
        }
    }
}
