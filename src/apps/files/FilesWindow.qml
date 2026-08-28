import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Ui

Window {
    id: window
    title: "Files — " + currentPathDisplay
    width: Design.s(980)
    height: Design.s(640)
    minimumWidth: Design.s(760)
    minimumHeight: Design.s(480)
    visible: true
    color: "transparent"

    onClosing: Qt.quit()

    readonly property bool isNative: typeof FilesBackend !== "undefined"
    readonly property string homeDir: isNative ? FilesBackend.homePath : "/home/dev"
    property string currentPath: isNative ? FilesBackend.currentPath : homeDir
    property string currentPathDisplay: currentPath.startsWith(homeDir) 
        ? ("~" + currentPath.substring(homeDir.length)) 
        : currentPath

    property var history: [currentPath]
    property int historyIndex: 0

    property bool showHidden: false
    property string filterQuery: ""
    property string viewMode: "grid" // "grid", "list", "gallery"
    property int selectedIndex: -1
    property string selectedPath: ""

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return "0 B";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function formatDate(d) {
        if (!d) return "";
        let date = new Date(d);
        return date.toLocaleDateString(Qt.locale(), "MMM d, yyyy") + " " + date.toLocaleTimeString(Qt.locale(), "hh:mm");
    }

    function getIconGlyph(name, isDir) {
        if (isDir) return "\u{f07b}"; // folder
        let ext = (name || "").split('.').pop().toLowerCase();
        if (["png","jpg","jpeg","webp","gif","svg","bmp"].indexOf(ext) >= 0) return "\u{f03e}";
        return "\u{f0f6}";
    }

    function getIconColor(name, isDir) {
        if (isDir) return Design.sapphire;
        let ext = (name || "").split('.').pop().toLowerCase();
        if (["png","jpg","jpeg","webp","gif","svg"].indexOf(ext) >= 0) return Design.pink;
        if (["cpp","hpp","qml","py","rs","sh","js","c","h"].indexOf(ext) >= 0) return Design.teal;
        if (["txt","md","json","conf","ini","toml","yaml","yml"].indexOf(ext) >= 0) return Design.peach;
        if (ext === "pdf") return Design.danger;
        return Design.text;
    }

    function isImageFile(name) {
        if (!name) return false;
        let ext = name.split('.').pop().toLowerCase();
        return ["png","jpg","jpeg","webp","gif","svg","bmp"].indexOf(ext) >= 0;
    }

    function getBreadcrumbs() {
        let crumbs = [{ name: "root", path: "/" }];
        if (currentPath === "/") return crumbs;
        let parts = currentPath.split("/").filter(Boolean);
        let acc = "";
        for (let i = 0; i < parts.length; ++i) {
            acc += "/" + parts[i];
            let name = parts[i];
            if (acc === homeDir) name = "~";
            crumbs.push({ name: name, path: acc });
        }
        return crumbs;
    }

    function navigateTo(path) {
        if (!path || path === currentPath) return;
        currentPath = path;
        selectedIndex = -1;
        selectedPath = "";

        if (historyIndex >= 0 && historyIndex < history.length - 1) {
            history = history.slice(0, historyIndex + 1);
        }
        history.push(path);
        historyIndex = history.length - 1;
    }

    function historyBack() {
        if (historyIndex > 0) {
            historyIndex--;
            currentPath = history[historyIndex];
            selectedIndex = -1;
            selectedPath = "";
        }
    }

    function historyForward() {
        if (historyIndex < history.length - 1) {
            historyIndex++;
            currentPath = history[historyIndex];
            selectedIndex = -1;
            selectedPath = "";
        }
    }

    function goUp() {
        if (currentPath === "/" || currentPath === "") return;
        let parts = currentPath.split("/").filter(Boolean);
        parts.pop();
        let parent = "/" + parts.join("/");
        if (parent === "") parent = "/";
        navigateTo(parent);
    }

    function openItem(path, isDir) {
        if (isDir) {
            navigateTo(path);
        } else {
            if (isNative) FilesBackend.openItem(path);
            else Qt.openUrlExternally("file://" + path);
        }
    }

    function openTerminalHere() {
        if (isNative) FilesBackend.openTerminal(currentPath);
    }

    function triggerQuickLook() {
        if (selectedPath && isNative) {
            FilesBackend.triggerQuickLook(selectedPath);
        }
    }

    // ── FolderListModel ──────────────────────────────────────────────────────
    FolderListModel {
        id: folderModel
        folder: "file://" + window.currentPath
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: window.showHidden
        nameFilters: window.filterQuery ? ["*" + window.filterQuery + "*"] : ["*"]
        sortField: FolderListModel.Name
        sortReversed: false
    }

    // ── Global Keyboard Shortcuts ────────────────────────────────────────────
    Shortcut { sequence: "Space"; onActivated: window.triggerQuickLook() }
    Shortcut { sequence: "Return"; onActivated: {
        if (selectedIndex >= 0 && selectedIndex < folderModel.count) {
            window.openItem(folderModel.get(selectedIndex, "filePath"), folderModel.isFolder(selectedIndex));
        }
    }}
    Shortcut { sequence: "Alt+Up"; onActivated: window.goUp() }
    Shortcut { sequence: "Backspace"; onActivated: window.goUp() }
    Shortcut { sequence: "Alt+Left"; onActivated: window.historyBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: window.historyForward() }
    Shortcut { sequence: "Ctrl+H"; onActivated: window.showHidden = !window.showHidden }
    Shortcut { sequence: "Ctrl+T"; onActivated: window.openTerminalHere() }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Escape"; onActivated: { searchField.text = ""; window.filterQuery = ""; } }

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: (window.visibility === Window.Maximized) ? 0 : Design.s(14)
        color: Design.base
        border.color: (window.visibility === Window.Maximized) ? "transparent" : Design.glassBorder
        border.width: 1
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

        // ═════════════════════════════════════════════════════════════════════
        // LEFT SIDEBAR: PLACES & VOLUMES
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Design.s(190)
            color: Design.crust

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Design.s(Design.space.md)
                spacing: Design.s(Design.space.sm)

                // App Branding Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.sm)

                    Rectangle {
                        width: Design.s(22)
                        height: Design.s(22)
                        radius: Design.s(Design.radius.sm)
                        color: Design.tint(Design.accent, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f07b}" // folder
                            color: Design.accent
                            font.family: Design.font.icon
                            font.pixelSize: Design.s(12)
                        }
                    }

                    Text {
                        text: "Files"
                        font.family: Design.font.sans
                        font.weight: Design.weight.bold
                        font.pixelSize: Design.s(13)
                        color: Design.text
                        Layout.fillWidth: true
                    }
                }

                Item { Layout.preferredHeight: Design.s(6) }

                Text {
                    text: "FAVORITES"
                    font.family: Design.font.mono
                    font.weight: Design.weight.bold
                    font.pixelSize: Design.s(10)
                    color: Design.textDim
                }

                // Places List
                ListView {
                    id: placesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Design.s(3)

                    model: [
                        { name: "Home",        path: window.homeDir,                     glyph: "\u{f015}", color: "#7aa2f7" },
                        { name: "Desktop",     path: window.homeDir + "/Desktop",        glyph: "\u{f108}", color: "#7dcfff" },
                        { name: "Documents",   path: window.homeDir + "/Documents",      glyph: "\u{f02d}", color: "#bb9af7" },
                        { name: "Downloads",   path: window.homeDir + "/Downloads",      glyph: "\u{f019}", color: "#73daca" },
                        { name: "Pictures",    path: window.homeDir + "/Pictures",       glyph: "\u{f03e}", color: "#f7768e" },
                        { name: "Music",       path: window.homeDir + "/Music",          glyph: "\u{f001}", color: "#e0af68" },
                        { name: "Videos",      path: window.homeDir + "/Videos",         glyph: "\u{f008}", color: "#ff9e64" },
                        { name: "DotsFiles",   path: window.homeDir + "/DotsFiles",      glyph: "\u{f121}", color: "#73daca" },
                        { name: "File System", path: "/",                                glyph: "\u{f0a0}", color: "#c0caf5" }
                    ]

                    delegate: Rectangle {
                        id: placeItem
                        width: placesList.width
                        height: Design.s(34)
                        radius: Design.s(Design.radius.ctl)

                        readonly property bool isActive: window.currentPath === modelData.path

                        color: isActive ? Design.tint(Design.accent, 0.22) :
                               placeHover.containsMouse ? Design.tint(Design.text, 0.07) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(10)
                            anchors.rightMargin: Design.s(10)
                            spacing: Design.s(10)

                            Text {
                                text: modelData.glyph
                                font.family: Design.font.icon
                                color: placeItem.isActive ? Design.accent : modelData.color
                                font.pixelSize: Design.s(14)
                            }

                            Text {
                                text: modelData.name
                                font.family: Design.font.sans
                                font.weight: placeItem.isActive ? Design.weight.bold : Design.weight.medium
                                color: placeItem.isActive ? Design.accent : Design.text
                                font.pixelSize: Design.s(12)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler { id: placeHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: window.navigateTo(modelData.path)
                        }
                    }
                }

                // Storage Info Badge
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Design.s(44)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.surface
                    border.color: Design.glassBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Design.s(10)
                        anchors.rightMargin: Design.s(10)
                        spacing: Design.s(8)

                        Text {
                            text: "\u{f0a0}" // hdd
                            font.family: Design.font.icon
                            color: Design.textDim
                            font.pixelSize: Design.s(13)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Storage"
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(10)
                                color: Design.textDim
                                font.weight: Design.weight.semibold
                            }

                            Text {
                                text: "System Drive"
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                color: Design.text
                                font.weight: Design.weight.medium
                            }
                        }
                    }
                }
            }

            // Right divider
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Design.glassBorder
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // MAIN FILE BROWSER AREA
        // ═════════════════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Top Navigation Bar ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Design.s(38)
                color: Design.ground
                border.color: Design.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.sm)
                    anchors.rightMargin: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.xs)

                    // History & Navigation Buttons
                    RowLayout {
                        spacing: Design.s(4)

                        IconButton {
                            icon: "\u{f053}" // chevron-left
                            bordered: true
                            enabled: window.historyIndex > 0
                            opacity: enabled ? 1.0 : 0.4
                            onClicked: window.historyBack()
                        }

                        IconButton {
                            icon: "\u{f054}" // chevron-right
                            bordered: true
                            enabled: window.historyIndex < window.history.length - 1
                            opacity: enabled ? 1.0 : 0.4
                            onClicked: window.historyForward()
                        }

                        IconButton {
                            icon: "\u{f062}" // arrow-up
                            bordered: true
                            onClicked: window.goUp()
                        }
                    }

                    // Clickable Breadcrumbs Path Navigation Bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Design.s(32)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        border.color: Design.glassBorder
                        border.width: 1
                        clip: true

                        ListView {
                            id: breadcrumbsList
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(8)
                            anchors.rightMargin: Design.s(8)
                            orientation: ListView.Horizontal
                            spacing: Design.s(2)
                            clip: true
                            model: window.getBreadcrumbs()

                            delegate: RowLayout {
                                spacing: Design.s(2)

                                Rectangle {
                                    implicitWidth: crumbText.implicitWidth + Design.s(12)
                                    implicitHeight: Design.s(22)
                                    radius: Design.s(Design.radius.sm)
                                    color: crumbHover.containsMouse ? Design.tint(Design.accent, 0.2) : "transparent"

                                    Text {
                                        id: crumbText
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        font.family: Design.font.sans
                                        font.weight: Design.weight.semibold
                                        font.pixelSize: Design.s(11)
                                        color: crumbHover.containsMouse ? Design.accent : Design.text
                                    }

                                    HoverHandler { id: crumbHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: window.navigateTo(modelData.path)
                                    }
                                }

                                Text {
                                    text: "/"
                                    color: Design.textDim
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(10)
                                    visible: index < (breadcrumbsList.count - 1)
                                }
                            }
                        }
                    }

                    // Search / Filter Input
                    Rectangle {
                        Layout.preferredWidth: Design.s(170)
                        implicitHeight: Design.s(32)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        border.color: searchField.activeFocus ? Design.accent : Design.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(8)
                            anchors.rightMargin: Design.s(8)
                            spacing: Design.s(6)

                            Text {
                                text: "\u{f002}" // search
                                font.family: Design.font.icon
                                color: searchField.activeFocus ? Design.accent : Design.textDim
                                font.pixelSize: Design.s(11)
                            }

                            TextInput {
                                id: searchField
                                Layout.fillWidth: true
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                color: Design.text
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    text: "Filter files..."
                                    color: Design.textDim
                                    font: parent.font
                                    visible: !searchField.text && !searchField.activeFocus
                                }

                                onTextChanged: {
                                    window.filterQuery = text.trim();
                                }
                            }

                            IconButton {
                                icon: "\u{f00d}" // times
                                visible: searchField.text.length > 0
                                onClicked: {
                                    searchField.text = "";
                                    window.filterQuery = "";
                                }
                            }
                        }
                    }

                    // View Switcher (Grid / List / Gallery)
                    RowLayout {
                        spacing: Design.s(2)

                        IconButton {
                            icon: "\u{f009}" // grid
                            bordered: true
                            hoverTone: Design.accent
                            fill: window.viewMode === "grid" ? Design.tint(Design.accent, 0.25) : Design.hover
                            tone: window.viewMode === "grid" ? Design.accent : Design.textDim
                            onClicked: window.viewMode = "grid"
                        }

                        IconButton {
                            icon: "\u{f00b}" // list
                            bordered: true
                            hoverTone: Design.accent
                            fill: window.viewMode === "list" ? Design.tint(Design.accent, 0.25) : Design.hover
                            tone: window.viewMode === "list" ? Design.accent : Design.textDim
                            onClicked: window.viewMode = "list"
                        }

                        IconButton {
                            icon: "\u{f03e}" // gallery
                            bordered: true
                            hoverTone: Design.accent
                            fill: window.viewMode === "gallery" ? Design.tint(Design.accent, 0.25) : Design.hover
                            tone: window.viewMode === "gallery" ? Design.accent : Design.textDim
                            onClicked: window.viewMode = "gallery"
                        }
                    }

                    // Show hidden files. Ctrl+H already did this, but with no
                    // control on screen dotfolders just looked missing.
                    IconButton {
                        icon: window.showHidden ? "\u{f06e}" : "\u{f070}" // eye / eye-slash
                        bordered: true
                        hoverTone: Design.yellow
                        fill: window.showHidden ? Design.tint(Design.yellow, 0.25) : Design.hover
                        tone: window.showHidden ? Design.yellow : Design.textDim
                        onClicked: window.showHidden = !window.showHidden
                    }

                    // Set the selected image as the desktop wallpaper
                    IconButton {
                        icon: "\u{f03e}" // image
                        bordered: true
                        hoverTone: Design.mauve
                        visible: window.selectedPath !== "" && window.isImageFile(window.selectedPath)
                        onClicked: FilesBackend.setWallpaper(window.selectedPath)
                    }

                    // Open Terminal in Current Folder
                    IconButton {
                        icon: "\u{f120}" // terminal
                        bordered: true
                        hoverTone: Design.teal
                        onClicked: window.openTerminalHere()
                    }
                }
            }

            // ── Main File View Content ───────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ── 1. GRID VIEW MODE ─────────────────────────────────────────
                GridView {
                    id: gridView
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.md)
                    visible: window.viewMode === "grid"
                    cellWidth: Design.s(120)
                    cellHeight: Design.s(120)
                    clip: true
                    reuseItems: true
                    // ponytail: an invisible view still builds and updates every
                    // delegate, so all three modes were populating at once — the
                    // gallery one decoding thumbnails nobody was looking at.
                    model: window.viewMode === "grid" ? folderModel : null

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: gridCard
                        width: gridView.cellWidth - Design.s(10)
                        height: gridView.cellHeight - Design.s(10)
                        radius: Design.s(Design.radius.card)

                        readonly property bool isSelected: window.selectedIndex === index
                        readonly property string itemFileName: model.fileName || ""
                        readonly property bool isDirectory: folderModel.isFolder(index)
                        readonly property bool isImg: itemFileName ? window.isImageFile(itemFileName) : false

                        color: isSelected ? Design.tint(Design.accent, 0.25) :
                               cardHover.containsMouse ? Design.tint(Design.text, 0.06) : "transparent"
                        border.color: isSelected ? Design.accent : "transparent"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(8)
                            spacing: Design.s(4)

                            // Icon or Thumbnail
                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Design.s(54)
                                implicitHeight: Design.s(54)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Design.s(12)
                                    color: Design.sunken
                                    border.color: Design.glassBorder
                                    border.width: 1
                                    visible: !gridCard.isImg

                                    Text {
                                        anchors.centerIn: parent
                                        text: gridCard.isDirectory ? "\u{f07b}" : window.getIconGlyph(gridCard.itemFileName, false)
                                        color: gridCard.isDirectory ? Design.sapphire : window.getIconColor(gridCard.itemFileName, false)
                                        font.family: Design.font.icon
                                        font.pixelSize: Design.s(24)
                                    }
                                }

                                Image {
                                    anchors.fill: parent
                                    source: gridCard.isImg ? ("file://" + model.filePath) : ""
                                    visible: gridCard.isImg
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: Design.s(80)
                                    sourceSize.height: Design.s(80)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: Design.glassBorder
                                        border.width: 1
                                        radius: Design.s(8)
                                    }
                                }
                            }

                            // Filename
                            Text {
                                text: model.fileName || ""
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                font.weight: gridCard.isSelected ? Design.weight.bold : Design.weight.medium
                                color: gridCard.isSelected ? Design.accent : Design.text
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }

                            // Size / Folder
                            Text {
                                text: model.fileIsDir ? "Folder" : window.formatSize(model.fileSize)
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(9)
                                color: Design.textDim
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }

                        HoverHandler { id: cardHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                window.selectedIndex = index;
                                window.selectedPath = model.filePath;
                            }
                            onDoubleClicked: {
                                window.openItem(model.filePath, model.fileIsDir);
                            }
                        }
                    }
                }

                // ── 2. LIST VIEW MODE ─────────────────────────────────────────
                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.sm)
                    visible: window.viewMode === "list"
                    clip: true
                    reuseItems: true
                    spacing: 2
                    // ponytail: an invisible view still builds and updates every
                    // delegate, so all three modes were populating at once — the
                    // gallery one decoding thumbnails nobody was looking at.
                    model: window.viewMode === "list" ? folderModel : null

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: listRow
                        width: listView.width
                        height: Design.s(36)
                        radius: Design.s(Design.radius.ctl)

                        readonly property bool isSelected: window.selectedIndex === index

                        color: isSelected ? Design.tint(Design.accent, 0.22) :
                               rowHover.containsMouse ? Design.tint(Design.text, 0.05) : "transparent"
                        border.color: isSelected ? Design.accent : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(12)
                            anchors.rightMargin: Design.s(12)
                            spacing: Design.s(12)

                            Text {
                                text: window.getIconGlyph(model.fileName, folderModel.isFolder(index))
                                color: window.getIconColor(model.fileName, folderModel.isFolder(index))
                                font.family: Design.font.icon
                                font.pixelSize: Design.s(15)
                            }

                            Text {
                                text: model.fileName || ""
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(12)
                                font.weight: listRow.isSelected ? Design.weight.bold : Design.weight.medium
                                color: listRow.isSelected ? Design.accent : Design.text
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            Text {
                                text: model.fileIsDir ? "Folder" : window.formatSize(model.fileSize)
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                color: Design.textDim
                                Layout.preferredWidth: Design.s(80)
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                text: window.formatDate(model.fileModified)
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                color: Design.textDim
                                Layout.preferredWidth: Design.s(140)
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        HoverHandler { id: rowHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                window.selectedIndex = index;
                                window.selectedPath = model.filePath;
                            }
                            onDoubleClicked: {
                                window.openItem(model.filePath, model.fileIsDir);
                            }
                        }
                    }
                }

                // ── 3. GALLERY VIEW MODE (Large Photo Cards) ──────────────────
                GridView {
                    id: galleryView
                    anchors.fill: parent
                    anchors.margins: Design.s(Design.space.md)
                    visible: window.viewMode === "gallery"
                    cellWidth: Design.s(210)
                    cellHeight: Design.s(210)
                    clip: true
                    reuseItems: true
                    // ponytail: an invisible view still builds and updates every
                    // delegate, so all three modes were populating at once — the
                    // gallery one decoding thumbnails nobody was looking at.
                    model: window.viewMode === "gallery" ? folderModel : null

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: galleryCard
                        width: galleryView.cellWidth - Design.s(12)
                        height: galleryView.cellHeight - Design.s(12)
                        radius: Design.s(Design.radius.card)

                        readonly property bool isSelected: window.selectedIndex === index
                        readonly property bool isImg: model.fileName ? window.isImageFile(model.fileName) : false

                        color: isSelected ? Design.tint(Design.accent, 0.25) : Design.sunken
                        border.color: isSelected ? Design.accent : Design.glassBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(6)

                            // Media Frame
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Image {
                                    anchors.fill: parent
                                    source: galleryCard.isImg ? ("file://" + model.filePath) : ""
                                    visible: galleryCard.isImg
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: Design.s(180)
                                    sourceSize.height: Design.s(180)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.color: Design.glassBorder
                                        border.width: 1
                                        radius: Design.s(8)
                                    }
                                }

                                // Non-image fallback
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !galleryCard.isImg
                                    color: Design.tint(window.getIconColor(model.fileName, model.fileIsDir), 0.1)
                                    radius: Design.s(8)

                                    Text {
                                        anchors.centerIn: parent
                                        text: window.getIconGlyph(model.fileName, model.fileIsDir)
                                        color: window.getIconColor(model.fileName, model.fileIsDir)
                                        font.family: Design.font.icon
                                        font.pixelSize: Design.s(48)
                                    }
                                }

                                // QuickLook Indicator on Hover
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Design.s(6)
                                    width: Design.s(26)
                                    height: Design.s(26)
                                    radius: Design.s(13)
                                    color: Design.tint(Design.ground, 0.85)
                                    visible: galHover.containsMouse

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u{f06e}" // eye
                                        font.family: Design.font.icon
                                        color: Design.accent
                                        font.pixelSize: Design.s(12)
                                    }
                                }
                            }

                            // Caption & Details
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.s(4)

                                Text {
                                    text: model.fileName || ""
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(11)
                                    font.weight: galleryCard.isSelected ? Design.weight.bold : Design.weight.medium
                                    color: galleryCard.isSelected ? Design.accent : Design.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }

                                Rectangle {
                                    implicitWidth: badgeText.implicitWidth + Design.s(10)
                                    implicitHeight: Design.s(18)
                                    radius: Design.s(9)
                                    color: galleryCard.isSelected ? Design.accent : Design.surface
                                    border.color: Design.glassBorder
                                    border.width: 1

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: model.fileIsDir ? "DIR" : window.formatSize(model.fileSize)
                                        font.family: Design.font.sans
                                        font.pixelSize: Design.s(9)
                                        font.weight: Design.weight.bold
                                        color: galleryCard.isSelected ? Design.crust : Design.textDim
                                    }
                                }
                            }
                        }

                        HoverHandler { id: galHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                window.selectedIndex = index;
                                window.selectedPath = model.filePath;
                            }
                            onDoubleClicked: {
                                window.openItem(model.filePath, model.fileIsDir);
                            }
                        }
                    }
                }
            }

            // ── Bottom Status Bar ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Design.s(28)
                color: Design.crust
                border.color: Design.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.md)
                    anchors.rightMargin: Design.s(Design.space.md)

                    Text {
                        text: folderModel.count + " items" + 
                              (window.selectedPath ? ("  |  Selected: " + window.selectedPath.split('/').pop()) : "")
                        font.family: Design.font.sans
                        font.pixelSize: Design.s(10)
                        color: Design.textDim
                        font.weight: Design.weight.medium
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Space: QuickLook  |  Ctrl+T: Terminal  |  Ctrl+H: Dotfiles"
                        font.family: Design.font.sans
                        font.pixelSize: Design.s(10)
                        color: Design.textDim
                        font.weight: Design.weight.medium
                    }
                }
            }
        }
    }
}
}
