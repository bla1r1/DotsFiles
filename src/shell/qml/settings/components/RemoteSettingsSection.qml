import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../Ui"
import "../../Services"

// =============================================================================
// Remote Desktop & Screen Sharing Settings Section
//
// Full control over native WayVNC remote server, unattended screencasting
// permissions (RustDesk / AnyDesk / OBS), /dev/uinput kernel input emulation,
// and wireless tablet secondary display (Sidecar).
// =============================================================================

ColumnLayout {
    id: section

    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property bool vncRunning: false
    property string localIp: "127.0.0.1"
    property int vncPort: 5900
    property bool promptFree: true
    property bool uinputReady: true
    property string vncPassword: ""

    function refreshStatus() {
        Quickshell.execDetached(["bash", "-c", "b1air-daemon remote status > /tmp/b1air_remote_status.json"], (out) => {
            fetchStatusFile();
        });
        // Quick check
        fetchStatusFile();
    }

    function fetchStatusFile() {
        Quickshell.execDetached(["cat", "/tmp/b1air_remote_status.json"], (data) => {
            try {
                if (data && data.trim().startsWith("{")) {
                    let parsed = JSON.parse(data.trim());
                    section.vncRunning = parsed.running || false;
                    section.localIp = parsed.ip || "127.0.0.1";
                    section.promptFree = parsed.promptFreeScreencast !== undefined ? parsed.promptFreeScreencast : true;
                    section.uinputReady = parsed.uinputReady !== undefined ? parsed.uinputReady : true;
                }
            } catch (e) {}
        });
    }

    Component.onCompleted: {
        refreshStatus();
    }

    // ── 1. WayVNC Native Remote Desktop ──────────────────────────────────────
    Card {
        title: "Remote Desktop (WayVNC)"
        subtitle: section.vncRunning
            ? "Server active on port " + section.vncPort + " — accessible on local network"
            : "Direct hardware-accelerated remote desktop with zero permission popups"
        icon: "\u{f0379}"
        accentColor: Design.blue

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: "Remote Desktop Server"; weight: Design.weight.semibold }
                Label {
                    text: section.vncRunning ? "Active (Listening on " + section.localIp + ":" + section.vncPort + ")" : "Stopped"
                    role: "caption"
                    dim: true
                }
            }

            Switch {
                checked: section.vncRunning
                onToggled: {
                    if (checked) {
                        Quickshell.execDetached(["b1air-daemon", "remote", "start", String(section.vncPort), section.vncPassword]);
                        section.vncRunning = true;
                    } else {
                        Quickshell.execDetached(["b1air-daemon", "remote", "stop"]);
                        section.vncRunning = false;
                    }
                    statusTimer.restart();
                }
            }
        }

        Item { height: Design.s(Design.space.xs) }

        // Quick Connect Badge & Copy
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)
            visible: section.vncRunning

            Pill {
                text: "vnc://" + section.localIp + ":" + section.vncPort
                color: Design.surface1
                textColor: Design.sapphire
            }

            ActionButton {
                text: "Copy Address"
                icon: "\u{f00c5}"
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", "printf '%s' 'vnc://" + section.localIp + ":" + section.vncPort + "' | wl-copy"]);
                    SoundEffects.play(SoundEffects.action);
                }
            }
        }
    }

    // ── 2. Unattended Screen Sharing & Permissions ───────────────────────────
    Card {
        title: "Unattended Remote Access & Permissions"
        subtitle: "Eliminate repetitive security dialogs for RustDesk, AnyDesk, and OBS"
        icon: "\u{f016d}"
        accentColor: Design.teal

        // Prompt-Free Screencast Toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: "Silent Screencast Sharing"; weight: Design.weight.semibold }
                Label {
                    text: "Allow trusted remote tools to capture screen without interactive popup confirmation"
                    role: "caption"
                    dim: true
                }
            }

            Switch {
                checked: section.promptFree
                onToggled: {
                    section.promptFree = checked;
                    Quickshell.execDetached(["b1air-daemon", "remote", "prompt-free", checked ? "on" : "off"]);
                }
            }
        }

        Item { height: Design.s(Design.space.xs) }

        // Kernel Input Emulation (/dev/uinput) Status
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: "Kernel Input Emulation (/dev/uinput)"; weight: Design.weight.semibold }
                Label {
                    text: section.uinputReady
                        ? "Active: Mouse and keyboard can be controlled unattended on lockscreen and root apps"
                        : "Requires input group permissions (/dev/uinput)"
                    role: "caption"
                    dim: true
                }
            }

            Badge {
                text: section.uinputReady ? "Ready" : "Inactive"
                color: section.uinputReady ? Design.green : Design.red
            }
        }

        Item { height: Design.s(Design.space.xs) }

        // RustDesk Service Control
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: "RustDesk Background Service"; weight: Design.weight.semibold }
                Label {
                    text: "Start or restart systemd daemon for persistent unattended access"
                    role: "caption"
                    dim: true
                }
            }

            ActionButton {
                text: "Start Service"
                icon: "\u{f04b}"
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", "sudo systemctl enable --now rustdesk 2>/dev/null || systemctl --user restart rustdesk 2>/dev/null || true"]);
                    SoundEffects.play(SoundEffects.action);
                }
            }
        }
    }

    // ── 3. Wireless Tablet Sidecar Display ────────────────────────────────────
    Card {
        title: "Wireless Tablet Sidecar Display"
        subtitle: "Create a virtual second monitor to stream to an iPad or tablet via VNC"
        icon: "\u{f004b}"
        accentColor: Design.mauve

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: "Virtual Headless Display"; weight: Design.weight.semibold }
                Label {
                    text: "Creates an extra 1920x1080 workspace that can be viewed on another device"
                    role: "caption"
                    dim: true
                }
            }

            RowLayout {
                spacing: Design.s(Design.space.sm)

                ActionButton {
                    text: "Create Display"
                    icon: "\u{f0079}"
                    onClicked: {
                        Quickshell.execDetached(["b1air-daemon", "sidecar", "create", "1920", "1080"]);
                        SoundEffects.play(SoundEffects.action);
                    }
                }

                ActionButton {
                    text: "Remove"
                    icon: "\u{f00d}"
                    onClicked: {
                        Quickshell.execDetached(["b1air-daemon", "sidecar", "remove"]);
                        SoundEffects.play(SoundEffects.action);
                    }
                }
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 1500
        repeat: false
        onTriggered: refreshStatus()
    }
}
