import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Ui"

// =============================================================================
// QuickLook Instant File Preview Overlay (Space / b1air-daemon quicklook)
// =============================================================================

PopupShell {
    id: root

    padding: Design.s(Design.space.md)

    property string filePath: ""
    property string fileText: ""
    property string fileType: "text" // "image", "text", "pdf", "archive"

    readonly property string fileName: filePath ? filePath.split("/").pop() : "File Preview"
    readonly property string fileExt: fileName.includes(".") ? fileName.split(".").pop().toLowerCase() : ""

    function detectType() {
        const ext = root.fileExt;
        if (["png", "jpg", "jpeg", "webp", "svg", "gif", "bmp"].includes(ext)) {
            root.fileType = "image";
        } else if (["zip", "tar", "gz", "xz", "bz2", "7z"].includes(ext)) {
            root.fileType = "archive";
        } else if (ext === "pdf") {
            root.fileType = "pdf";
        } else {
            root.fileType = "text";
        }
    }

    onFilePathChanged: {
        detectType();
        if (root.fileType === "text") {
            textLoader.running = true;
        } else if (root.fileType === "archive") {
            archiveLoader.command = root.filePath.toLowerCase().endsWith(".zip")
                ? ["unzip", "-l", root.filePath]
                : ["tar", "-tf", root.filePath];
            archiveLoader.running = true;
        } else if (root.fileType === "pdf") {
            pdfLoader.running = true;
        }
    }

    Process {
        id: textLoader
        command: ["head", "-n", "200", root.filePath]
        stdout: StdioCollector {
            onStreamFinished: root.fileText = this.text
        }
    }

    Process {
        id: archiveLoader
        command: ["tar", "-tf", root.filePath]
        stdout: StdioCollector {
            onStreamFinished: root.fileText = this.text
        }
    }

    Process {
        id: pdfLoader
        command: ["pdfinfo", root.filePath]
        stdout: StdioCollector {
            onStreamFinished: root.fileText = this.text || "PDF Document"
        }
    }

    focus: true
    Keys.onEscapePressed: root.close()
    Keys.onSpacePressed: root.close()

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Icon {
                text: root.fileType === "image" ? "\u{f03e}" :
                      (root.fileType === "archive" ? "\u{f1c6}" :
                      (root.fileType === "pdf" ? "\u{f1c1}" : "\u{f15c}"))
                role: "subhead"
                color: Design.accent
            }

            ColumnLayout {
                spacing: 1
                Label {
                    text: root.fileName
                    role: "subhead"
                    weight: Design.weight.bold
                }
                Label {
                    text: root.filePath
                    role: "caption"
                    dim: true
                    elide: Text.ElideMiddle
                    Layout.preferredWidth: Design.s(450)
                }
            }

            Item { Layout.fillWidth: true }

            ActionButton {
                icon: "\u{f0c5}"
                label: "Copy Path"
                onActivated: {
                    Quickshell.execDetached(["wl-copy", root.filePath]);
                    Quickshell.execDetached(["notify-send", "-a", "QuickLook", "Copied", root.filePath]);
                }
            }

            ActionButton {
                icon: "\u{f08e}"
                label: "Open"
                onActivated: {
                    Quickshell.execDetached(["xdg-open", root.filePath]);
                    root.close();
                }
            }
        }

        // ── Preview Canvas ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Design.s(Design.radius.card)
            color: Design.sunken
            border.color: Design.glassBorder
            border.width: 1
            clip: true

            // 1. Image Preview
            Image {
                visible: root.fileType === "image"
                anchors.fill: parent
                anchors.margins: Design.s(Design.space.sm)
                source: root.fileType === "image" && root.filePath ? "file://" + root.filePath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            // 2. Text / Code / Archive / PDF Metadata Preview
            ScrollView {
                visible: root.fileType !== "image"
                anchors.fill: parent
                anchors.margins: Design.s(Design.space.sm)
                clip: true

                TextArea {
                    text: root.fileText || (root.filePath ? "Loading preview..." : "Select a file to preview")
                    readOnly: true
                    selectByMouse: true
                    font.family: Design.font.mono
                    font.pixelSize: Design.s(12)
                    color: Design.text
                    background: null
                    wrapMode: TextEdit.WrapAnywhere
                }
            }
        }
    }
}
