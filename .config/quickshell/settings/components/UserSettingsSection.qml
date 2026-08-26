import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "../../Ui"
import "../../Services"

// =============================================================================
// UserSettingsSection — User profile, avatar, display name, shell & password
// =============================================================================

ColumnLayout {
    id: section
    spacing: Design.s(Design.space.lg)

    property var userInfo: ({
        username: "user",
        name: "User",
        uid: "1000",
        home: "/home/user",
        shell: "/usr/bin/fish",
        avatar: "",
        groups: ""
    })

    property string userScript: Quickshell.env("HOME") + "/.config/sway/scripts/system/user-manager.sh"

    function loadUserInfo() {
        userInfoProcess.running = true;
    }

    Process {
        id: userInfoProcess
        command: ["bash", section.userScript, "get"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    section.userInfo = JSON.parse(data);
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: loadUserInfo()

    // ── Header ───────────────────────────────────────────────────────────────
    SettingsCard {
        Layout.fillWidth: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: Design.s(Design.space.md)
            spacing: Design.s(Design.space.lg)

            // Circular Avatar with Tokyo Night accent border
            Rectangle {
                Layout.preferredWidth: Design.s(76)
                Layout.preferredHeight: Design.s(76)
                radius: width / 2
                color: Design.surface
                border.width: Design.s(2)
                border.color: Design.accent

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    anchors.margins: Design.s(3)
                    visible: section.userInfo.avatar !== ""
                    source: section.userInfo.avatar ? "file://" + section.userInfo.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
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
                spacing: Design.s(Design.space.xs)

                RowLayout {
                    spacing: Design.s(Design.space.sm)

                    Label {
                        text: section.userInfo.name || section.userInfo.username
                        role: "title"
                        weight: Design.weight.bold
                    }

                    Badge {
                        text: "UID: " + section.userInfo.uid
                        color: Design.accent
                    }
                }

                Label {
                    text: "@" + section.userInfo.username + " • " + section.userInfo.home
                    dim: true
                }

                RowLayout {
                    spacing: Design.s(Design.space.sm)

                    Button {
                        text: "Change Avatar"
                        icon.text: "\u{f03e}"
                        onClicked: avatarFileDialog.open()
                    }

                    Button {
                        text: "Change Password"
                        icon.text: "\u{f084}"
                        onClicked: {
                            Quickshell.execDetached(["bash", section.userScript, "change-password"]);
                        }
                    }
                }
            }
        }
    }

    // ── Profile Details & Display Name ───────────────────────────────────────
    SettingsCard {
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Design.s(Design.space.md)
            spacing: Design.s(Design.space.md)

            Label {
                text: "Account Details"
                role: "subtitle"
                weight: Design.weight.bold
            }

            // Real / Display Name
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "Full / Display Name"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Used across SDDM login screen and system session greeting"
                        dim: true
                    }
                }

                TextField {
                    id: nameField
                    Layout.preferredWidth: Design.s(220)
                    text: section.userInfo.name || ""
                    placeholderText: "Enter full name..."
                    onAccepted: {
                        if (text.trim().length > 0) {
                            Quickshell.execDetached(["bash", section.userScript, "set-name", text.trim()]);
                            section.loadUserInfo();
                        }
                    }
                }

                Button {
                    text: "Save"
                    onClicked: {
                        if (nameField.text.trim().length > 0) {
                            Quickshell.execDetached(["bash", section.userScript, "set-name", nameField.text.trim()]);
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
                        text: "Login shell executed when opening terminals and virtual consoles"
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
                        Quickshell.execDetached(["bash", section.userScript, "set-shell", chosen]);
                        section.loadUserInfo();
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Design.s(1)
                color: Design.border
            }

            // User Groups
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

    // ── Session & Lockscreen Integration ─────────────────────────────────────
    SettingsCard {
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Design.s(Design.space.md)
            spacing: Design.s(Design.space.md)

            Label {
                text: "Desktop Session & SDDM"
                role: "subtitle"
                weight: Design.weight.bold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "Desktop Environment"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Active session name and display manager theme"
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
                spacing: Design.s(Design.space.md)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Label {
                        text: "SDDM Display Manager Theme"
                        weight: Design.weight.medium
                    }
                    Label {
                        text: "Active login greeter theme with shared wallpaper caching"
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

    // ── File Dialog for Avatar Selection ─────────────────────────────────────
    FileDialog {
        id: avatarFileDialog
        title: "Select Avatar Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg)"]
        onAccepted: {
            let path = selectedFile.toString().replace(/^file:\/\//, "");
            Quickshell.execDetached(["bash", section.userScript, "set-avatar", path]);
            section.loadUserInfo();
        }
    }
}
