import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"
import B1air.Daemon

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
    property bool promptFree: false
    property bool uinputReady: false
    readonly property bool devMode: Quickshell.env("B1AIR_DEV_MODE") === "1"
    property string vncPassword: ""

    Process {
        id: vncStarter
        stdinEnabled: true
        command: ["b1air-daemon", "remote", "start-stdin", String(section.vncPort)]
        onStarted: {
            write(section.vncPassword + "\n");
            stdinEnabled = false;
        }
    }

    // Daemon.requestRemoteStatus's second argument was never a real Quickshell
    // API — execDetached takes no JS callback, so this silently never ran and
    // vncRunning/localIp never updated after the first paint.
    function refreshStatus() {
        Daemon.requestRemoteStatus();
    }

    Connections {
        target: Daemon
        function onRemoteStatusReady(tag, json) {
            try {
                if (json && json.trim().startsWith("{")) {
                    let parsed = JSON.parse(json.trim());
                    section.vncRunning = parsed.running || false;
                    section.localIp = parsed.ip || "127.0.0.1";
                    section.promptFree = section.devMode && parsed.promptFreeScreencast === true;
                    section.uinputReady = parsed.uinputReady !== undefined ? parsed.uinputReady : true;
                }
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        refreshStatus();
    }

    // ── 1. WayVNC Native Remote Desktop ──────────────────────────────────────
    Card {
        title: "Remote Desktop (WayVNC)"
        subtitle: section.vncRunning
            ? "Server active on port " + section.vncPort + " — local session only"
            : (section.devMode ? "Development mode: available to the local network" : "Stopped — starts on localhost in production mode")
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
                    text: section.vncRunning ? "Active (Listening on " + (section.devMode ? section.localIp : "127.0.0.1") + ":" + section.vncPort + ")" : "Stopped"
                    role: "caption"
                    dim: true
                }
            }

            Switch {
                checked: section.vncRunning
                onToggled: {
                    if (checked) {
                        // Never put a VNC password in argv: it is visible through
                        // process listings. Password-backed/TLS mode is enabled
                        // by the daemon's secret-store integration.
                        vncStarter.running = true;
                        section.vncRunning = true;
                    } else {
                        Daemon.remoteStop();
                        section.vncRunning = false;
                    }
                    statusTimer.restart();
                }
            }
        }

        Item { height: Design.s(Design.space.xs) }

        RowLayout {
            Layout.fillWidth: true
            Label { text: "VNC password"; role: "caption"; dim: true }
            Field {
                Layout.fillWidth: true
                text: section.vncPassword
                echoMode: TextInput.Password
                placeholder: "Required for TLS authentication"
                onCommitted: v => section.vncPassword = v
            }
        }

        // Quick Connect Badge & Copy
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)
            visible: section.vncRunning

            Pill {
                label: "vnc://" + section.localIp + ":" + section.vncPort
                active: true
                activeColor: Design.surface1
                activeTextColor: Design.sapphire
            }

            ActionButton {
                label: "Copy Address"
                icon: "\u{f00c5}"
                onActivated: {
                    Quickshell.execDetached(["wl-copy", "vnc://" + section.localIp + ":" + section.vncPort]);
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
                    text: section.devMode ? "Allow trusted remote tools to capture screen without interactive popup confirmation" : "Available only in explicit development mode"
                    role: "caption"
                    dim: true
                }
            }

            Switch {
                checked: section.promptFree && section.devMode
                enabled: section.devMode
                onToggled: {
                    section.promptFree = checked;
                    Daemon.remotePromptFree(checked);
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
                label: "Start Service"
                icon: "\u{f04b}"
                onActivated: {
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
                    label: "Create Display"
                    icon: "\u{f0079}"
                    onActivated: {
                        Daemon.sidecarCreate(1920, 1080);
                        SoundEffects.play(SoundEffects.action);
                    }
                }

                ActionButton {
                    label: "Remove"
                    icon: "\u{f00d}"
                    onActivated: {
                        Daemon.sidecarRemove();
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
