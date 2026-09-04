import QtQuick
import QtQuick.Layouts
import "../Ui"
import "../Services"
import "."

// =============================================================================
// Battery & power mini-settings.
//
// The three energy-mode rows were the same forty lines three times over, which
// is how they ended up with three different hover colours. One model, one row.
// =============================================================================

MiniView {
    id: root

    title: "Battery & Power"
    icon: "\u{f0079}"
    tone: Design.green
    footerLabel: "Power Settings…"

    trailing: BatteryPill { clickable: false }

    readonly property var modes: [
        {
            id: "performance",
            glyph: "\u{f0e4}",
            title: "Performance",
            hint: "Maximum speed, shortest battery life",
            tone: Design.red
        },
        {
            id: "balanced",
            glyph: "\u{f0241}",
            title: "Balanced",
            hint: "Automatic — speed when you need it, quiet when you do not",
            tone: Design.sapphire
        },
        {
            id: "power-saver",
            glyph: "\u{f0084}",
            title: "Low Power",
            hint: "Caps performance to stretch the charge",
            tone: Design.green
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.sm)

        // ── Summary ──────────────────────────────────────────────────────────
        Rectangle {
            visible: Power.hasBattery
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(Design.size.tile)
            radius: Design.s(Design.radius.card)
            color: Design.glassCard
            border.color: Design.glassBorder
            border.width: Design.border

            RowLayout {
                anchors.fill: parent
                anchors.margins: Design.s(Design.space.md)
                spacing: Design.s(Design.space.md)

                Icon {
                    text: Power.charging ? "\u{f0084}" : "\u{f0079}"
                    role: "title"
                    color: Power.charging ? Design.ok : Design.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: Power.charging ? "Running on power adapter" : "Running on battery"
                        role: "body"
                        weight: Design.weight.semibold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: Power.status + (Power.timeRemainingText !== ""
                            ? " • " + (Power.charging ? "until full " : "left ") + Power.timeRemainingText : "")
                        role: "caption"
                        dim: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ── Screen brightness ────────────────────────────────────────────────
        SectionLabel {
            text: "Display"
            visible: Power.hasBacklight
            Layout.topMargin: Design.s(Design.space.xs)
        }

        Slider {
            visible: Power.hasBacklight
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(Design.size.ctl)
            value: Power.brightness
            tone: Design.yellow
            icon: "\u{f00df}"
            label: "Brightness"
            onMoved: pct => Power.setBrightness(pct)
        }

        // ── Energy modes ─────────────────────────────────────────────────────
        SectionLabel {
            text: "Energy mode"
            Layout.topMargin: Design.s(Design.space.xs)
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            EmptyState {
                anchors.centerIn: parent
                width: parent.width
                visible: !Power.hasProfiles
                icon: "\u{f0241}"
                title: "No energy modes"
                hint: "power-profiles-daemon is not running, so there is nothing to switch between."
            }

            ColumnLayout {
                anchors.fill: parent
                visible: Power.hasProfiles
                spacing: Design.s(Design.space.xs)

                Repeater {
                    model: root.modes

                    Rectangle {
                        id: modeRow
                        required property var modelData

                        readonly property bool active: Power.profile === modeRow.modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(Design.size.rowTall)
                        radius: Design.s(Design.radius.ctl)

                        color: modeRow.active ? Design.tint(modeRow.modelData.tone, 0.15)
                                              : (modeMa.containsMouse ? Design.glassHover : "transparent")
                        border.color: modeRow.active ? Design.tint(modeRow.modelData.tone, 0.35) : "transparent"
                        border.width: Design.border

                        Behavior on color { ColorAnimation { duration: Design.duration.fast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(Design.space.sm)
                            anchors.rightMargin: Design.s(Design.space.sm)
                            spacing: Design.s(Design.space.sm)

                            Icon {
                                text: modeRow.modelData.glyph
                                role: "body"
                                color: modeRow.modelData.tone
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Label {
                                    text: modeRow.modelData.title
                                    weight: Design.weight.semibold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: modeRow.modelData.hint
                                    role: "caption"
                                    dim: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            Icon {
                                visible: modeRow.active
                                text: "\u{f012c}"
                                role: "caption"
                                color: modeRow.modelData.tone
                            }
                        }

                        Clickable {
                            id: modeMa
                            onClicked: Power.setProfile(modeRow.modelData.id)
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
