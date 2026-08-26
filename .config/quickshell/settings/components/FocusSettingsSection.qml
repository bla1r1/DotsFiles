import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../Ui"
import "../../Services"

// =============================================================================
// Screen Time & Focus Settings Section
// =============================================================================

ColumnLayout {
    id: section
    spacing: Design.s(Design.space.lg)

    property int workDuration: Settings.focusWorkDuration || 25
    property int shortBreakDuration: Settings.focusShortBreak || 5
    property int longBreakDuration: Settings.focusLongBreak || 15
    property int dailyGoalHours: Settings.dailyScreenTimeGoal || 8
    property bool autoDnd: Settings.focusAutoDnd !== undefined ? Settings.focusAutoDnd : true
    property bool breakReminders: Settings.focusBreakReminders !== undefined ? Settings.focusBreakReminders : true
    property bool daemonAutoStart: Settings.focusDaemonAutoStart !== undefined ? Settings.focusDaemonAutoStart : true

    property var notifRules: Settings.notificationRules || { "telegram": true, "discord": true, "browser": true, "media": true, "system": true }

    function isRuleEnabled(app) {
        return section.notifRules && section.notifRules[app] !== undefined ? section.notifRules[app] : true;
    }

    function toggleRule(app) {
        var rules = Object.assign({}, section.notifRules || {});
        rules[app] = !section.isRuleEnabled(app);
        section.notifRules = rules;
        Settings.set("notificationRules", rules);
    }

    // ── 1. Header ────────────────────────────────────────────────────────────
    SectionLabel {
        text: "Screen Time & Focus"
    }

    // ── 2. Today's Wellbeing Overview ────────────────────────────────────────
    Card {
        title: "Today's Activity"
        subtitle: "Real-time summary of your computer usage and focus intervals"
        icon: "\u{f051e}"
        accentColor: Design.teal

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Screen time stat box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(72)
                radius: Design.s(Design.radius.card)
                color: Design.sunken

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label {
                        text: "Screen Time Today"
                        role: "caption"
                        dim: true
                    }
                    Label {
                        text: (Power.upHours > 0 ? Power.upHours + "h " : "") + Power.upMins + "m"
                        role: "subhead"
                        weight: Design.weight.bold
                        color: Design.teal
                    }
                }
            }

            // Daily goal progress box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(72)
                radius: Design.s(Design.radius.card)
                color: Design.sunken

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label {
                        text: "Daily Goal (" + section.dailyGoalHours + "h)"
                        role: "caption"
                        dim: true
                    }
                    Label {
                        readonly property real pct: Math.min(100, Math.round(((Power.upHours * 60 + Power.upMins) / (section.dailyGoalHours * 60)) * 100))
                        text: pct + "% used"
                        role: "subhead"
                        weight: Design.weight.bold
                        color: pct > 100 ? Design.danger : Design.sapphire
                    }
                }
            }

            // Focus status box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(72)
                radius: Design.s(Design.radius.card)
                color: Design.sunken

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label {
                        text: "Focus Status"
                        role: "caption"
                        dim: true
                    }
                    Label {
                        text: Notifications.dnd ? "Focusing (DND)" : "Active"
                        role: "subhead"
                        weight: Design.weight.bold
                        color: Notifications.dnd ? Design.peach : Design.green
                    }
                }
            }
        }
    }

    // ── 3. Application Notification Filters ──────────────────────────────────
    Card {
        title: "Application Notification Filters"
        subtitle: "Control banner popups and sound alerts for individual apps"
        icon: "\u{f0f3}"
        accentColor: Design.mauve

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰭹"; role: "title"; color: Design.teal }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Telegram Desktop"; weight: Design.weight.semibold }
                    Label { text: "Show notification banners for incoming direct messages"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isRuleEnabled("telegram")
                    onToggled: section.toggleRule("telegram")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰙯"; role: "title"; color: Design.lavender }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Discord & Matrix"; weight: Design.weight.semibold }
                    Label { text: "Allow mentions and community channel pings"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isRuleEnabled("discord")
                    onToggled: section.toggleRule("discord")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰈹"; role: "title"; color: Design.sapphire }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Web Browsers"; weight: Design.weight.semibold }
                    Label { text: "Website push notifications from Firefox, Brave, Chrome"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isRuleEnabled("browser")
                    onToggled: section.toggleRule("browser")
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Design.tint(Design.line, 0.4) }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)
                Icon { text: "󰓇"; role: "title"; color: Design.green }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(2)
                    Label { text: "Media Track Changes"; weight: Design.weight.semibold }
                    Label { text: "Pop up banner on song change (Spotify, Cmus, MPD)"; role: "caption"; dim: true }
                }
                Toggle {
                    checked: section.isRuleEnabled("media")
                    onToggled: section.toggleRule("media")
                }
            }
        }
    }

    // ── 4. Pomodoro & Interval Durations ─────────────────────────────────────
    Card {
        title: "Focus & Break Intervals"
        subtitle: "Customize work cycles and rest duration for FocusTime timer"
        icon: "\u{f0520}"
        accentColor: Design.sapphire

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Stepper {
                label: "Focus Work Duration"
                valueText: section.workDuration + " min"
                onDecrement: {
                    const v = Math.max(5, section.workDuration - 5);
                    section.workDuration = v;
                    Settings.set("focusWorkDuration", v);
                }
                onIncrement: {
                    const v = Math.min(120, section.workDuration + 5);
                    section.workDuration = v;
                    Settings.set("focusWorkDuration", v);
                }
            }

            Stepper {
                label: "Short Break Duration"
                valueText: section.shortBreakDuration + " min"
                onDecrement: {
                    const v = Math.max(1, section.shortBreakDuration - 1);
                    section.shortBreakDuration = v;
                    Settings.set("focusShortBreak", v);
                }
                onIncrement: {
                    const v = Math.min(30, section.shortBreakDuration + 1);
                    section.shortBreakDuration = v;
                    Settings.set("focusShortBreak", v);
                }
            }

            Stepper {
                label: "Long Break Duration"
                valueText: section.longBreakDuration + " min"
                onDecrement: {
                    const v = Math.max(5, section.longBreakDuration - 5);
                    section.longBreakDuration = v;
                    Settings.set("focusLongBreak", v);
                }
                onIncrement: {
                    const v = Math.min(60, section.longBreakDuration + 5);
                    section.longBreakDuration = v;
                    Settings.set("focusLongBreak", v);
                }
            }

            Stepper {
                label: "Daily Screen Time Limit Goal"
                valueText: section.dailyGoalHours + " hours"
                onDecrement: {
                    const v = Math.max(1, section.dailyGoalHours - 1);
                    section.dailyGoalHours = v;
                    Settings.set("dailyScreenTimeGoal", v);
                }
                onIncrement: {
                    const v = Math.min(24, section.dailyGoalHours + 1);
                    section.dailyGoalHours = v;
                    Settings.set("dailyScreenTimeGoal", v);
                }
            }
        }
    }

    // ── 5. Focus Automation & Distraction Control ────────────────────────────
    Card {
        title: "Focus Automation"
        subtitle: "Automatic notification suppression and health reminders"
        icon: "\u{f009b}"
        accentColor: Design.peach

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Toggle {
                label: "Auto-Silence Notifications in Focus Mode"
                subtitle: "Automatically activate Do Not Disturb during active focus sessions"
                checked: section.autoDnd
                onToggled: {
                    const v = !section.autoDnd;
                    section.autoDnd = v;
                    Settings.set("focusAutoDnd", v);
                }
            }

            Toggle {
                label: "Hourly Eye Care & Break Reminders"
                subtitle: "Send a gentle notification when continuous screen time reaches 60 minutes"
                checked: section.breakReminders
                onToggled: {
                    const v = !section.breakReminders;
                    section.breakReminders = v;
                    Settings.set("focusBreakReminders", v);
                }
            }

            Toggle {
                label: "Auto-Start FocusTime Daemon"
                subtitle: "Launch background activity tracker automatically on login"
                checked: section.daemonAutoStart
                onToggled: {
                    const v = !section.daemonAutoStart;
                    section.daemonAutoStart = v;
                    Settings.set("focusDaemonAutoStart", v);
                }
            }
        }
    }
}
