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

    property string dotfilesLocal: "..."
    property string dotfilesRemote: "..."
    property bool dotfilesUpdateAvail: false

    Process {
        id: updateChecker
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l || echo 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                section.isChecking = false;
                const count = parseInt(this.text.trim(), 10) || 0;
                section.updateCount = count;
                section.statusText = count > 0 ? (count + " package updates available") : "System packages are up to date";
            }
        }
    }

    Process {
        id: dotfilesChecker
        command: ["b1air-daemon", "dotfiles", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    if (data.ok) {
                        section.dotfilesLocal = data.branch + "@" + data.local_hash;
                        section.dotfilesRemote = data.remote_hash ? (data.branch + "@" + data.remote_hash) : "up to date";
                        section.dotfilesUpdateAvail = !!data.update_available;
                    }
                } catch (e) {}
            }
        }
    }

    function checkNow() {
        section.isChecking = true;
        section.statusText = "Checking repositories...";
        updateChecker.running = true;
        dotfilesChecker.running = true;
    }

    function runSystemUpdate() {
        Quickshell.execDetached(["b1air-daemon", "dotfiles", "sys"]);
    }

    function runDotfilesUpdate() {
        Quickshell.execDetached(["b1air-daemon", "dotfiles", "sync"]);
    }

    function viewBackups() {
        Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.dotfiles-backups"]);
    }

    function cleanPackageCache() {
        Quickshell.execDetached(["kitty", "--title", "Clean Package Cache", "bash", "-c", "sudo paccache -rk2 || sudo pacman -Sc --noconfirm; echo 'Done! Press enter to exit'; read"]);
    }

    function cleanOrphanPackages() {
        Quickshell.execDetached(["kitty", "--title", "Remove Orphan Packages", "bash", "-c", "orphans=$(pacman -Qtdq); if [ -n \"$orphans\" ]; then sudo pacman -Rns $orphans; else echo 'No orphan packages found.'; fi; echo 'Press enter to exit'; read"]);
    }

    // ── 1. Desktop Environment Updates ───────────────────────────────────────
    Card {
        title: "Desktop Environment & Dotfiles"
        subtitle: "Synchronize sway, quickshell, and configs with GitHub upstream"
        icon: "\u{f021}"
        accentColor: section.dotfilesUpdateAvail ? Design.ok : Design.sapphire

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(2)
                Label { text: section.dotfilesUpdateAvail ? "New UI update available" : "Desktop environment is up to date"; weight: Design.weight.semibold }
                Label { text: "Local: " + section.dotfilesLocal + " • Remote: " + section.dotfilesRemote; role: "caption"; dim: true }
            }

            Pill {
                label: "Check"
                icon: "\u{f021}"
                onClicked: dotfilesChecker.running = true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f021}"
                label: "Sync UI & Packages"
                tone: section.dotfilesUpdateAvail ? Design.ok : Design.sapphire
                onActivated: section.runDotfilesUpdate()
            }

            ActionButton {
                icon: "\u{f07c}"
                label: "View Backups"
                tone: Design.textDim
                onActivated: section.viewBackups()
            }
        }
    }

    // ── 2. System Packages Updates ───────────────────────────────────────────
    Card {
        title: "Arch Linux & AUR Packages"
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
                label: section.updateCount > 0 ? ("Upgrade " + section.updateCount + " Packages") : "Run Full System Upgrade"
                tone: section.updateCount > 0 ? Design.peach : Design.green
                onActivated: section.runSystemUpdate()
            }
        }
    }

    // ── 3. Storage & Cache Maintenance ───────────────────────────────────────
    Card {
        title: "Disk & Package Cleanup"
        subtitle: "Free up storage by clearing old package cache versions and unused dependencies"
        icon: "\u{f014}"
        accentColor: Design.mauve

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
