import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"

// =============================================================================
// User Profile & Account Settings Section (C++20 b1air-daemon backed)
// =============================================================================

ColumnLayout {
    id: section
    Layout.fillWidth: true
    spacing: Design.s(Design.space.lg)

    property var userInfo: ({
        username: "user",
        name: "User",
        uid: "1000",
        home: "/home/user",
        shell: "/usr/bin/fish",
        avatar: "",
        groups: "wheel, input, audio, video"
    })

    property string daemonCmd: Quickshell.env("HOME") + "/.local/bin/b1air-daemon"

    function loadUserInfo() {
        userInfoProcess.running = true;
    }

    Process {
        id: userInfoProcess
        command: [section.daemonCmd, "user", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let raw = this.text.trim();
                    if (raw !== "") {
                        section.userInfo = JSON.parse(raw);
                    }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: loadUserInfo()

    // ── 1. Header ────────────────────────────────────────────────────────────
    SectionLabel {
        text: "User Profile & Account"
    }

    // ── 2. Profile Overview Card ─────────────────────────────────────────────
    Card {
        title: section.userInfo.name || section.userInfo.username
        subtitle: "@" + section.userInfo.username + " • UID " + section.userInfo.uid + " • " + section.userInfo.home
        icon: "\u{f007}"
        accentColor: Design.mauve

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.lg)

            // Circular Avatar with Accent Frame
            Rectangle {
                Layout.preferredWidth: Design.s(72)
                Layout.preferredHeight: Design.s(72)
                radius: width / 2
                color: Design.surface
                border.width: Design.s(2)
                border.color: Design.accent
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: Design.s(2)
                    visible: section.userInfo.avatar !== ""
                    source: section.userInfo.avatar ? "file://" + section.userInfo.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                }

                Icon {
                    anchors.centerIn: parent
                    visible: section.userInfo.avatar === ""
                    text: "\u{f007}"
                    role: "hero"
                    color: Design.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: avatarFileDialog.open()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.sm)

                RowLayout {
                    spacing: Design.s(Design.space.sm)

                    ActionButton {
                        icon: "\u{f03e}"
                        label: "Change Avatar"
                        onActivated: avatarFileDialog.open()
                    }

                    ActionButton {
                        icon: "\u{f084}"
                        label: "Change Password"
                        tone: Design.sapphire
                        onActivated: {
                            Quickshell.execDetached([section.daemonCmd, "user", "change-password"]);
                        }
                    }
                }

                Label {
                    text: "Synchronized with SDDM and ~/.face.icon automatically"
                    dim: true
                }
            }
        }
    }

    // ── 3. Account Details Card ──────────────────────────────────────────────
    Card {
        title: "Account Details & Shell"
        subtitle: "System user configurations and login preferences"
        icon: "\u{f013}"
        accentColor: Design.blue

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            // Full Name Input
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "Display / Full Name"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Real name shown on lockscreen and greeter"
                        dim: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Design.s(220)
                    Layout.preferredHeight: Design.s(Design.size.action)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.surface
                    border.color: nameInput.activeFocus ? Design.accent : Design.border
                    border.width: 1

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.margins: Design.s(8)
                        color: Design.text
                        text: section.userInfo.name || ""
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        font.pixelSize: Design.s(Design.font.body)

                        Text {
                            text: "Enter full name..."
                            color: Design.textDim
                            visible: !nameInput.text && !nameInput.activeFocus
                            anchors.fill: parent
                            font: nameInput.font
                        }

                        onAccepted: {
                            if (text.trim().length > 0) {
                                Quickshell.execDetached([section.daemonCmd, "user", "set-name", text.trim()]);
                                section.loadUserInfo();
                            }
                        }
                    }
                }

                ActionButton {
                    icon: "\u{f00c}"
                    label: "Save"
                    tone: Design.sapphire
                    onActivated: {
                        if (nameInput.text.trim().length > 0) {
                            Quickshell.execDetached([section.daemonCmd, "user", "set-name", nameInput.text.trim()]);
                            section.loadUserInfo();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(1)
                color: Design.border
            }

            // Default Shell
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "Default Shell"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Login shell executed for terminals and virtual consoles"
                        dim: true
                    }
                }

                ComboBox {
                    id: shellCombo
                    Layout.preferredWidth: Design.s(180)
                    model: ["/usr/bin/fish", "/bin/bash", "/bin/zsh"]
                    currentIndex: {
                        let idx = model.indexOf(section.userInfo.shell);
                        return idx >= 0 ? idx : 0;
                    }
                    onActivated: {
                        let chosen = model[currentIndex];
                        Quickshell.execDetached([section.daemonCmd, "user", "set-shell", chosen]);
                        section.loadUserInfo();
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(1)
                color: Design.border
            }

            // Assigned Groups
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.xs)

                Label {
                    text: "Assigned Groups"
                    weight: Design.weight.medium
                }

                Label {
                    text: section.userInfo.groups || "wheel, input, audio, video, storage"
                    dim: true
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── 4. Desktop Environment & SDDM Badges Card ────────────────────────────
    Card {
        title: "Desktop Session & SDDM Greeter"
        subtitle: "Integrated b1air environment status"
        icon: "\u{f108}"
        accentColor: Design.green

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.md)

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "Desktop Environment"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Active window manager and native C++20 daemons"
                        dim: true
                    }
                }

                Badge {
                    text: "b1air (SwayFX)"
                    color: Design.green
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(1)
                color: Design.border
            }

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "SDDM Greeter Theme"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Active login screen with shared wallpaper caching"
                        dim: true
                    }
                }

                Badge {
                    text: "b1air SDDM Theme"
                    color: Design.sapphire
                }
            }
        }
    }

    // ── 5. File Dialog for Avatar Selection ──────────────────────────────────
    FileDialog {
        id: avatarFileDialog
        title: "Select Avatar Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg)"]
        onAccepted: {
            let path = selectedFile.toString().replace(/^file:\/\//, "");
            Quickshell.execDetached([section.daemonCmd, "user", "set-avatar", path]);
            section.loadUserInfo();
        }
    }
}
