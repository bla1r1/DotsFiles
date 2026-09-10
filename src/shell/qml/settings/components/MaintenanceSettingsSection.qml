import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"
import B1air.Daemon

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
        Daemon.dotfilesSys();
    }

    function runDotfilesUpdate() {
        Daemon.dotfilesSync();
    }

    function viewBackups() {
        Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.dotfiles-backups"]);
    }

    function cleanPackageCache() {
        Quickshell.execDetached(["b1air-term", "-e", "fish", "-lc", "sudo paccache -rk2; or sudo pacman -Sc --noconfirm; printf '\\nDone! Press enter to exit\\n'; read"]);
    }

    function cleanOrphanPackages() {
        Quickshell.execDetached(["b1air-term", "-e", "fish", "-lc", "set orphans (pacman -Qtdq); if test (count $orphans) -gt 0; sudo pacman -Rns $orphans; else; echo 'No orphan packages found.'; end; printf '\\nPress enter to exit\\n'; read"]);
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

            // The three actions on this page and the next remove packages, wipe
            // caches or start a full system upgrade, and each was a single
            // click in a page people scroll through. ActionButton already has
            // the arm-then-confirm step — "Reset Defaults" in About and the
            // power row in the Control Center use it — and these deserve it at
            // least as much.
            ActionButton {
                icon: "\u{f0187}"
                label: section.updateCount > 0 ? ("Upgrade " + section.updateCount + " Packages") : "Run Full System Upgrade"
                tone: section.updateCount > 0 ? Design.peach : Design.green
                destructive: true
                confirmLabel: "Start upgrade?"
                onActivated: section.runSystemUpdate()
            }
        }
    }

    // ── 3. Disk Sweeper & Cache Maintenance (M4) ─────────────────────────────
    Card {
        title: "Disk Sweeper & Storage Maintenance"
        subtitle: "Free up storage by clearing pacman cache, systemd journals, and thumbnail cache"
        icon: "\u{f014}"
        accentColor: Design.mauve

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f014}"
                label: "Clean All Caches & Logs"
                tone: Design.sapphire
                destructive: true
                confirmLabel: "Delete them?"
                onActivated: Daemon.sweeperClean()
            }

            ActionButton {
                icon: "\u{f128}"
                label: "Remove Orphan Packages"
                tone: Design.mauve
                destructive: true
                confirmLabel: "Uninstall them?"
                onActivated: section.cleanOrphanPackages()
            }
        }
    }

    // ── 4. System Restore Points & Snapshots (M4) ─────────────────────────────
    Card {
        title: "Btrfs & Timeshift Restore Points"
        subtitle: "Create automatic system snapshots prior to major updates and package changes"
        icon: "\u{f0c7}"
        accentColor: Design.teal

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f0c7}"
                label: "Create Pre-Update Restore Point"
                tone: Design.teal
                onActivated: Cmd.run(["b1air-daemon", "snapshot", "create", "Manual user snapshot"], "Create snapshot")
            }
        }
    }

    // ── 5. Encrypted Vaults Manager (M4) ──────────────────────────────────────
    Card {
        title: "Encrypted Security Vaults"
        subtitle: "Mount and secure confidential directories using client-side encryption"
        icon: "\u{f023}"
        accentColor: Design.peach

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            ActionButton {
                icon: "\u{f07c}"
                label: "Open Secure Vaults Location"
                tone: Design.peach
                onActivated: Quickshell.execDetached(["bash", "-c", "mkdir -p ~/.vaults && xdg-open ~/.vaults"])
            }
        }
    }
}
