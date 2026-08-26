import QtQuick
import QtQuick.Layouts
import "../../Ui"
import "../../Services"

// =============================================================================
// Power Settings — Energy profiles, battery stats, and sleep timeouts.
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    // ── 1. Energy Profiles Card ──────────────────────────────────────────────
    Card {
        title: "Energy & performance"
        subtitle: "Tune system performance and power consumption"
        icon: "\u{f0084}"
        accentColor: Design.green

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Repeater {
                model: [
                    { id: "performance", label: "Performance", icon: "\u{f0e4}",  color: Design.red },
                    { id: "balanced",    label: "Balanced",    icon: "\u{f0241}", color: Design.sapphire },
                    { id: "power-saver", label: "Power Saver", icon: "\u{f0084}", color: Design.green }
                ]

                Rectangle {
                    id: profTile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(48)
                    radius: Design.s(Design.radius.ctl)

                    readonly property bool isActive: Power.profile === profTile.modelData.id
                    color: isActive ? Design.tint(profTile.modelData.color, 0.18) : (profMa.containsMouse ? Design.raised : Design.sunken)
                    border.color: isActive ? profTile.modelData.color : (profMa.containsMouse ? Design.hover : "transparent")
                    border.width: isActive ? 2 : 1

                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Design.s(Design.space.sm)

                        Icon {
                            text: profTile.modelData.icon
                            role: "body"
                            color: profTile.isActive ? profTile.modelData.color : Design.textDim
                        }

                        Label {
                            text: profTile.modelData.label
                            weight: profTile.isActive ? Design.weight.bold : Design.weight.medium
                            color: profTile.isActive ? profTile.modelData.color : Design.text
                        }
                    }

                    Clickable {
                        id: profMa
                        onClicked: Power.setProfile(profTile.modelData.id)
                    }
                }
            }
        }
    }

    // ── 2. Battery Health Card (if battery exists) ───────────────────────────
    Card {
        visible: Power.hasBattery
        title: "Battery"
        subtitle: Power.charging ? "Currently charging" : "Running on battery power"
        icon: Power.charging ? "\u{f0084}" : "\u{f0079}"
        accentColor: Power.charging ? Design.ok : Design.accent

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            Rectangle {
                width: Design.s(44)
                height: width
                radius: width / 2
                color: Design.tint(Power.charging ? Design.ok : (Power.capacity <= 20 ? Design.danger : Design.accent), 0.15)

                Icon {
                    anchors.centerIn: parent
                    text: Power.charging ? "\u{f0084}" : (Power.capacity > 80 ? "\u{f0079}" : (Power.capacity > 30 ? "\u{f007c}" : "\u{f0083}"))
                    role: "subhead"
                    color: Power.charging ? Design.ok : (Power.capacity <= 20 ? Design.danger : Design.accent)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: Power.capacity + "%"
                    role: "subhead"
                    weight: Design.weight.bold
                }

                Label {
                    text: "Status: " + Power.status
                    role: "caption"
                    dim: true
                }
            }
        }
    }

    // ── 3. Screen and Sleep Timeouts ─────────────────────────────────────────
    Card {
        title: "Screen & sleep timeouts"
        subtitle: "Control idle dimming, display power off, and automatic system suspension"
        icon: "\u{f033e}"
        accentColor: Design.peach

        Toggle {
            label: "Dim screen on lock"
            subtitle: "Lower display brightness immediately when screen is locked"
            checked: Settings.dimOnLock
            onToggled: Settings.set("dimOnLock", !Settings.dimOnLock)
        }

        Stepper {
            label: "Turn off screen after"
            valueText: (Math.round(Settings.dpmsTimeout / 60)) + " min"
            onDecrement: Settings.set("dpmsTimeout", Math.max(60, Settings.dpmsTimeout - 60))
            onIncrement: Settings.set("dpmsTimeout", Math.min(3600, Settings.dpmsTimeout + 60))
        }

        Toggle {
            label: "Automatic sleep"
            subtitle: "Suspend the system automatically when left idle"
            checked: Settings.autoSuspend
            onToggled: Settings.set("autoSuspend", !Settings.autoSuspend)
        }

        Stepper {
            visible: Settings.autoSuspend
            label: "Suspend system after"
            valueText: (Math.round(Settings.suspendTimeout / 60)) + " min"
            onDecrement: Settings.set("suspendTimeout", Math.max(120, Settings.suspendTimeout - 300))
            onIncrement: Settings.set("suspendTimeout", Math.min(7200, Settings.suspendTimeout + 300))
        }
    }
}
