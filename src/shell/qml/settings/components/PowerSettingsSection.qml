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

    // Services/Power is refcounted — only ControlCenter ever acquired it, so
    // opening this page started no poller and "Balanced" stayed lit no matter
    // which profile was actually active.
    Component.onCompleted: Power.acquire()
    Component.onDestruction: Power.release()

    // ── 1. Energy Profiles Card ──────────────────────────────────────────────
    Card {
        title: "Energy & performance"
        subtitle: "Tune system performance and power consumption"
        icon: "\u{f0084}"
        accentColor: Design.green

        // The mini view in the Control Center has always had this empty state;
        // the full page drew three live-looking tiles that silently did nothing
        // when power-profiles-daemon was not running.
        EmptyState {
            visible: !Power.hasProfiles
            Layout.fillWidth: true
            icon: "\u{f0241}"
            title: "No energy modes"
            hint: "power-profiles-daemon is not running, so there is nothing to switch between."
        }

        RowLayout {
            visible: Power.hasProfiles
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

    // ── 2. Display brightness ────────────────────────────────────────────────
    // The page advertises "brightness" in its own search tags and had no
    // brightness control on it — the only slider lived in the Control Center
    // mini view, so searching for it landed you on a page without it.
    Card {
        visible: Power.hasBacklight
        title: "Display brightness"
        subtitle: "Backlight level of the built-in panel"
        icon: "\u{f00df}"
        accentColor: Design.yellow

        Slider {
            Layout.fillWidth: true
            Layout.preferredHeight: Design.s(Design.size.ctl)
            value: Power.brightness
            tone: Design.yellow
            icon: "\u{f00df}"
            label: "Brightness"
            onMoved: pct => Power.setBrightness(pct)
        }
    }

    // ── 3. Battery ───────────────────────────────────────────────────────────
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

                // The mini view showed the time estimate and the full settings
                // page did not, so the popup was strictly more informative than
                // the page it links to.
                Label {
                    text: Power.status + (Power.timeRemainingText !== ""
                        ? " • " + (Power.charging ? "until full " : "left ") + Power.timeRemainingText
                        : "")
                    role: "caption"
                    dim: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        // ── Per-pack breakdown ───────────────────────────────────────────────
        // Everything above is UPower's composite device. On a two-battery
        // machine that single number hides which pack is doing the work and
        // which one has aged: BAT0 can sit at 99% and fully-charged while BAT1
        // is still charging at 73%, with BAT0 down to 65% of design capacity.
        SectionLabel {
            visible: Power.hasMultipleBatteries
            text: "Installed packs"
            Layout.topMargin: Design.s(Design.space.sm)
        }

        Repeater {
            model: Power.hasMultipleBatteries ? Power.batteries : []

            DeviceRow {
                required property var modelData

                Layout.fillWidth: true
                title: Power.labelOf(modelData) + (modelData.model ? " · " + modelData.model : "")
                subtitle: Power.stateTextOf(modelData)
                    + (Power.healthOf(modelData) > 0
                        ? " • health " + Power.healthOf(modelData) + "%"
                        : "")
                value: Power.percentOf(modelData) + "%"
                valueTone: Power.percentOf(modelData) <= 20 ? Design.danger
                    : (Power.healthOf(modelData) > 0 && Power.healthOf(modelData) < 70 ? Design.warn : Design.ok)
            }
        }

        // A single pack still has health worth showing; it just does not need a
        // list to show it in.
        DeviceRow {
            visible: !Power.hasMultipleBatteries && Power.batteryCount === 1
                     && Power.healthOf(Power.batteries[0]) > 0
            Layout.fillWidth: true
            Layout.topMargin: Design.s(Design.space.sm)
            title: "Battery health"
            subtitle: "Capacity now, against what the pack shipped with"
            value: Power.batteryCount === 1 ? Power.healthOf(Power.batteries[0]) + "%" : ""
            valueTone: Power.batteryCount === 1 && Power.healthOf(Power.batteries[0]) < 70 ? Design.warn : Design.ok
        }
    }

    // ── 4. Screen and Sleep Timeouts ─────────────────────────────────────────
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
            onDecrement: Settings.set("suspendTimeout", Math.max(300, Settings.suspendTimeout - 300))
            onIncrement: Settings.set("suspendTimeout", Math.min(7200, Settings.suspendTimeout + 300))
        }
    }
}
