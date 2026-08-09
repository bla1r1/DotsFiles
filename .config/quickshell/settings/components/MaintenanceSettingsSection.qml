import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"

// =============================================================================
// System Maintenance & Package Updates
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property int updateCount: 0
    property string statusText: "Checking for updates..."
    property bool isChecking: false

    Process {
        id: updateChecker
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l || echo 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                section.isChecking = false;
                const count = parseInt(this.text.trim(), 10) || 0;
                section.updateCount = count;
                section.statusText = count > 0 ? (count + " package updates available") : "System is up to date";
            }
        }
    }

    function checkNow() {
        section.isChecking = true;
        section.statusText = "Checking repositories...";
        updateChecker.running = true;
    }

    function runSystemUpdate() {
        Quickshell.execDetached(["kitty", "--title", "System Update", "bash", "-c", "sudo pacman -Syu && echo 'Press enter to exit' && read"]);
    }

    function cleanPackageCache() {
        Quickshell.execDetached(["kitty", "--title", "Clean Package Cache", "bash", "-c", "sudo paccache -rk2 || sudo pacman -Sc --noconfirm; echo 'Done! Press enter to exit'; read"]);
    }

    function cleanOrphanPackages() {
        Quickshell.execDetached(["kitty", "--title", "Remove Orphan Packages", "bash", "-c", "orphans=$(pacman -Qtdq); if [ -n \"$orphans\" ]; then sudo pacman -Rns $orphans; else echo 'No orphan packages found.'; fi; echo 'Press enter to exit'; read"]);
    }

    // ── 1. System Updates ────────────────────────────────────────────────────
    Card {
        title: "Software & Package Updates"
        subtitle: "Manage Pacman and AUR repositories"
        icon: "\u{f0187}"
        accentColor: section.updateCount > 0 ? Design.peach : Design.green

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: "Update Status"; weight: Design.weight.semibold }
                Label { text: section.statusText; role: "caption"; dim: true }
            }

            Pill {
                label: "Check"
                icon: "\u{f021}"
                onClicked: section.checkNow()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f0187}"
                label: section.updateCount > 0 ? ("Update " + section.updateCount + " Packages") : "Run System Update"
                tone: section.updateCount > 0 ? Design.peach : Design.green
                onActivated: section.runSystemUpdate()
            }
        }
    }

    // ── 2. Storage & Cache Maintenance ───────────────────────────────────────
    Card {
        title: "Disk & Package Cleanup"
        subtitle: "Free up storage by clearing old package cache versions and unused dependencies"
        icon: "\u{f014}"
        accentColor: Design.sapphire

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f014}"
                label: "Clean Package Cache"
                tone: Design.sapphire
                onActivated: section.cleanPackageCache()
            }

            ActionButton {
                icon: "\u{f128}"
                label: "Remove Orphan Packages"
                tone: Design.mauve
                onActivated: section.cleanOrphanPackages()
            }
        }
    }
}
