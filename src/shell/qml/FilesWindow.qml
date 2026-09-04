import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel

ApplicationWindow {
    id: window
    title: "Files — " + currentPathDisplay
    width: 1060
    height: 680
    minimumWidth: 740
    minimumHeight: 480
    visible: true
    color: "transparent"
    flags: Qt.Window

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

    // User Bookmarks
    property var customBookmarks: [
        { name: "DotsFiles", path: homeDir + "/DotsFiles", icon: "󰊢" }
    ]

    // Premium Tokyo Night Palette & Design Tokens
    readonly property color colBg: "#161722"
    readonly property color colDark: "#13141e"
    readonly property color colSidebar: "#101119"
    readonly property color colSunken: "#0d0e14"
    readonly property color colCard: "#1a1b2a"
    readonly property color colCardHover: Qt.rgba(255/255, 255/255, 255/255, 0.05)
    readonly property color colBorder: Qt.rgba(122/255, 162/255, 247/255, 0.16)
    readonly property color colBorderSubtle: "#1b1c2b"
    readonly property color colBlue: "#7aa2f7"
    readonly property color colPurple: "#bb9af7"
    readonly property color colCyan: "#7dcfff"
    readonly property color colGreen: "#73daca"
    readonly property color colOrange: "#ff9e64"
    readonly property color colYellow: "#e0af68"
    readonly property color colRed: "#f7768e"
    readonly property color colFg: "#c0caf5"
    readonly property color colDim: "#6b739b"

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
        if (isDir) return "󰉋";
        let ext = (name || "").split('.').pop().toLowerCase();
        if (["png","jpg","jpeg","webp","gif","svg","bmp"].indexOf(ext) >= 0) return "󰋩";
        if (["mp4","mkv","avi","mov","webm"].indexOf(ext) >= 0) return "󰕼";
        if (["mp3","flac","wav","ogg","m4a"].indexOf(ext) >= 0) return "󰎆";
        if (["cpp","hpp","c","h","rs","py","js","ts","qml","sh"].indexOf(ext) >= 0) return "󰅩";
        if (["zip","tar","gz","7z","bz2","xz"].indexOf(ext) >= 0) return "󰛫";
        if (["txt","md","json","yaml","yml","conf"].indexOf(ext) >= 0) return "󰈙";
        if (ext === "pdf") return "󰈦";
        return "󰈔";
    }

    function getIconColor(name, isDir) {
        if (isDir) return window.colBlue;
        let ext = (name || "").split('.').pop().toLowerCase();
        if (["png","jpg","jpeg","webp","gif","svg"].indexOf(ext) >= 0) return window.colPurple;
        if (["cpp","hpp","qml","py","rs","sh","js","c","h"].indexOf(ext) >= 0) return window.colCyan;
        if (["txt","md","json","conf","ini","toml","yaml","yml"].indexOf(ext) >= 0) return window.colGreen;
        if (["mp4","mkv","avi","mov","webm"].indexOf(ext) >= 0) return window.colOrange;
        if (["zip","tar","gz","7z"].indexOf(ext) >= 0) return window.colYellow;
        if (ext === "pdf") return window.colRed;
        return window.colFg;
    }

    function isImageFile(name) {
        if (!name) return false;
        let ext = name.split('.').pop().toLowerCase();
        return ["png","jpg","jpeg","webp","gif","svg","bmp"].indexOf(ext) >= 0;
    }

    function getBreadcrumbs() {
        let p = currentPath;
        let crumbs = [];
        if (p.startsWith(homeDir)) {
            crumbs.push({ name: "~", path: homeDir });
            let rel = p.substring(homeDir.length);
            let parts = rel.split("/").filter(Boolean);
            let acc = homeDir;
            for (let i = 0; i < parts.length; ++i) {
                acc += "/" + parts[i];
                crumbs.push({ name: parts[i], path: acc });
            }
        } else {
            crumbs.push({ name: "/", path: "/" });
            let parts = p.split("/").filter(Boolean);
            let acc = "";
            for (let i = 0; i < parts.length; ++i) {
                acc += "/" + parts[i];
                crumbs.push({ name: parts[i], path: acc });
            }
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
        if (parts.length <= 1) {
            navigateTo("/");
        } else {
            parts.pop();
            navigateTo("/" + parts.join("/"));
        }
    }

    function openItem(path, isDir) {
        if (isDir) {
            navigateTo(path);
        } else if (isNative) {
            FilesBackend.openItem(path);
        }
    }

    function openTerminalHere() {
        if (isNative) {
            FilesBackend.openTerminal(currentPath);
        }
    }

    function triggerQuickLook() {
        if (selectedPath && isNative) {
            FilesBackend.triggerQuickLook(selectedPath);
        }
    }

    function addCurrentToBookmarks() {
        let name = currentPath.split('/').pop() || "Folder";
        if (currentPath === homeDir) name = "Home";
        if (currentPath === "/") name = "Root";

        for (let b of customBookmarks) {
            if (b.path === currentPath) return;
        }
        let copy = Array.from(customBookmarks);
        copy.push({ name: name, path: currentPath, icon: "󰉋" });
        customBookmarks = copy;
    }

    function removeBookmark(index) {
        let copy = Array.from(customBookmarks);
        copy.splice(index, 1);
        customBookmarks = copy;
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

    // ═════════════════════════════════════════════════════════════════════════
    // ROOT WINDOW FRAME (Rounded Corners + Antialiased Border)
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: 14
        color: window.colBg
        border.color: window.colBorder
        border.width: 1
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ═════════════════════════════════════════════════════════════════
            // LEFT SIDEBAR (210px, Full-Height Sleek Obsidian)
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 210
                color: window.colSidebar

                // Subtle right divider line
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: window.colBorderSubtle
                    z: 5
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // App Header Branding Card
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Layout.bottomMargin: 2

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 8
                            color: Qt.rgba(122/255, 162/255, 247/255, 0.18)
                            border.color: Qt.rgba(122/255, 162/255, 247/255, 0.35)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰉋"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: window.colBlue
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: "Files"
                                font.family: "Fira Sans SemiBold, sans-serif"
                                font.pixelSize: 13
                                font.bold: true
                                color: window.colFg
                            }
                            Text {
                                text: "Explorer & Gallery"
                                font.family: "Fira Sans, sans-serif"
                                font.pixelSize: 10
                                color: window.colDim
                            }
                        }
                    }

                    // 1. QUICK JUMP (Root, Home, DotsFiles)
                    Text {
                        text: "QUICK JUMP"
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 9
                        font.bold: true
                        color: window.colDim
                        Layout.topMargin: 4
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        SidebarPill { label: "Root (/)"; path: "/"; icon: "󰋜"; iconCol: window.colRed }
                        SidebarPill { label: "Home (~)"; path: window.homeDir; icon: "󰋜"; iconCol: window.colBlue }
                        SidebarPill { label: "DotsFiles"; path: window.homeDir + "/DotsFiles"; icon: "󰊢"; iconCol: window.colCyan }
                    }

                    // 2. PLACES
                    Text {
                        text: "PLACES"
                        font.family: "JetBrainsMono Nerd Font, monospace"
                        font.pixelSize: 9
                        font.bold: true
                        color: window.colDim
                        Layout.topMargin: 4
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        SidebarPill { label: "Documents"; path: window.homeDir + "/Documents"; icon: "󰈙"; iconCol: window.colPurple }
                        SidebarPill { label: "Downloads"; path: window.homeDir + "/Downloads"; icon: "󰁝"; iconCol: window.colGreen }
                        SidebarPill { label: "Pictures"; path: window.homeDir + "/Pictures"; icon: "󰋩"; iconCol: window.colPurple }
                        SidebarPill { label: "Music"; path: window.homeDir + "/Music"; icon: "󰎆"; iconCol: window.colOrange }
                        SidebarPill { label: "Videos"; path: window.homeDir + "/Videos"; icon: "󰕼"; iconCol: window.colRed }
                    }

                    // 3. BOOKMARKS
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4

                        Text {
                            text: "BOOKMARKS"
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 9
                            font.bold: true
                            color: window.colDim
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 18; height: 18; radius: 4
                            color: addBmArea.containsMouse ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰐕"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: addBmArea.containsMouse ? window.colBlue : window.colDim
                            }
                            MouseArea {
                                id: addBmArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.addCurrentToBookmarks()
                            }
                        }
                    }

                    ListView {
                        id: bookmarksList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: window.customBookmarks

                        delegate: Rectangle {
                            width: bookmarksList.width
                            height: 28
                            radius: 6
                            color: window.currentPath === modelData.path ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : (bmArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent")
                            border.color: window.currentPath === modelData.path ? Qt.rgba(122/255, 162/255, 247/255, 0.40) : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 6

                                Text { text: modelData.icon || "󰉋"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: window.colBlue }
                                Text { text: modelData.name; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; color: window.colFg; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text {
                                    text: "×"
                                    font.pixelSize: 13
                                    color: delBmArea.containsMouse ? window.colRed : window.colDim
                                    visible: bmArea.containsMouse
                                    MouseArea {
                                        id: delBmArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: window.removeBookmark(index)
                                    }
                                }
                            }

                            MouseArea {
                                id: bmArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.navigateTo(modelData.path)
                            }
                        }
                    }

                    // Storage Device Card with Progress Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 8
                        color: window.colSunken
                        border.color: window.colBorderSubtle
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "󰋊 System Drive"; font.family: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"; font.pixelSize: 10; font.bold: true; color: window.colFg }
                                Item { Layout.fillWidth: true }
                                Text { text: isNative ? FilesBackend.diskFreeSpace : "12.8 GB free"; font.family: "Fira Sans, sans-serif"; font.pixelSize: 9; color: window.colDim }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: window.colBorderSubtle

                                Rectangle {
                                    width: parent.width * 0.42
                                    height: parent.height
                                    radius: 2
                                    color: window.colBlue
                                }
                            }
                        }
                    }
                }

                component SidebarPill: Rectangle {
                    id: pill
                    property string label: ""
                    property string path: ""
                    property string icon: "󰉋"
                    property color iconCol: window.colBlue

                    readonly property bool isActive: window.currentPath === pill.path

                    Layout.fillWidth: true
                    height: 28
                    radius: 6
                    color: isActive ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : (pillArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent")
                    border.color: isActive ? Qt.rgba(122/255, 162/255, 247/255, 0.45) : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text { text: pill.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: pill.isActive ? window.colBlue : pill.iconCol }
                        Text { text: pill.label; font.family: "Fira Sans SemiBold, sans-serif"; font.pixelSize: 11; color: pill.isActive ? "#ffffff" : window.colFg; Layout.fillWidth: true; elide: Text.ElideRight }
                    }

                    MouseArea {
                        id: pillArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.navigateTo(pill.path)
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // RIGHT WORKSPACE: HEADER TOOLBAR, FILE BROWSER, FOOTER
            // ═════════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ── Top Navigation Bar (46px) ────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    color: window.colDark

                    // Subtle bottom divider
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: window.colBorderSubtle
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        // History Navigation Cluster
                        Rectangle {
                            height: 30
                            radius: 6
                            color: window.colSunken
                            border.color: window.colBorderSubtle
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                NavIconBtn { icon: "󰁍"; enabled: window.historyIndex > 0; onClicked: window.historyBack() }
                                NavIconBtn { icon: "󰁔"; enabled: window.historyIndex < window.history.length - 1; onClicked: window.historyForward() }
                                NavIconBtn { icon: "󰁝"; enabled: window.currentPath !== "/"; onClicked: window.goUp() }
                                NavIconBtn { icon: "󰑐"; enabled: true; onClicked: isNative ? FilesBackend.refresh() : null }
                            }
                        }

                        // Breadcrumbs Path Bar (Capsule)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 6
                            color: window.colSunken
                            border.color: window.colBorderSubtle
                            border.width: 1
                            clip: true

                            ListView {
                                id: breadcrumbsList
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                orientation: ListView.Horizontal
                                spacing: 4
                                clip: true
                                model: window.getBreadcrumbs()

                                delegate: RowLayout {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        implicitWidth: crumbText.implicitWidth + 12
                                        height: 22
                                        radius: 4
                                        color: isLast ? Qt.rgba(122/255, 162/255, 247/255, 0.20) : (crumbHover.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")

                                        readonly property bool isLast: index === (breadcrumbsList.count - 1)

                                        Text {
                                            id: crumbText
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            font.family: "Fira Sans SemiBold, JetBrainsMono Nerd Font, sans-serif"
                                            font.pixelSize: 11
                                            font.bold: isLast
                                            color: isLast ? window.colBlue : (crumbHover.containsMouse ? "#ffffff" : window.colFg)
                                        }

                                        HoverHandler { id: crumbHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: window.navigateTo(modelData.path)
                                        }
                                    }

                                    Text {
                                        text: "󰅂"
                                        font.family: "JetBrainsMono Nerd Font"
                                        color: window.colDim
                                        font.pixelSize: 9
                                        visible: index < (breadcrumbsList.count - 1)
                                    }
                                }
                            }
                        }

                        // Search Filter Bar
                        Rectangle {
                            Layout.preferredWidth: Math.min(180, Math.max(120, window.width * 0.18))
                            height: 30
                            radius: 6
                            color: window.colSunken
                            border.color: searchField.activeFocus ? window.colBlue : window.colBorderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text { text: "󰍉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: searchField.activeFocus ? window.colBlue : window.colDim }
                                TextInput {
                                    id: searchField
                                    Layout.fillWidth: true
                                    font.family: "Fira Sans, sans-serif"
                                    font.pixelSize: 11
                                    color: window.colFg
                                    clip: true
                                    selectByMouse: true
                                    onTextChanged: window.filterQuery = text.trim()

                                    Text {
                                        text: "Search files..."
                                        font.family: "Fira Sans, sans-serif"
                                        font.pixelSize: 11
                                        color: window.colDim
                                        visible: !searchField.text && !searchField.activeFocus
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    text: "󰅖"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: window.colDim
                                    visible: searchField.text.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { searchField.text = ""; window.filterQuery = ""; }
                                    }
                                }
                            }
                        }

                        // Segmented View Mode Capsule [ Grid | List | Gallery ]
                        Rectangle {
                            height: 30
                            width: 90
                            radius: 6
                            color: window.colSunken
                            border.color: window.colBorderSubtle
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                ViewSegmentBtn { icon: "󰕰"; active: window.viewMode === "grid"; onClicked: window.viewMode = "grid" }
                                ViewSegmentBtn { icon: "󰕱"; active: window.viewMode === "list"; onClicked: window.viewMode = "list" }
                                ViewSegmentBtn { icon: "󰋩"; active: window.viewMode === "gallery"; onClicked: window.viewMode = "gallery" }
                            }
                        }

                        // Quick Action Buttons (Hidden Toggle & Terminal)
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                width: 30; height: 30; radius: 6
                                color: window.showHidden ? Qt.rgba(122/255, 162/255, 247/255, 0.25) : (hidArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : window.colSunken)
                                border.color: window.showHidden ? window.colBlue : window.colBorderSubtle
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "󰈉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.showHidden ? window.colBlue : window.colDim }
                                MouseArea { id: hidArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.showHidden = !window.showHidden }
                            }

                            Rectangle {
                                width: 30; height: 30; radius: 6
                                color: termArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : window.colSunken
                                border.color: window.colBorderSubtle
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "󰞷"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: window.colFg }
                                MouseArea { id: termArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.openTerminalHere() }
                            }
                        }
                    }
                }

                // ── Main File Browser Canvas ─────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // 1. GRID VIEW (Default, Smooth Fast Scrolling)
                    GridView {
                        id: grid
                        reuseItems: true
                        anchors.fill: parent
                        anchors.margins: 14
                        cellWidth: 114
                        cellHeight: 114
                        clip: true
                        visible: window.viewMode === "grid"
                        model: folderModel
                        cacheBuffer: 300

                        delegate: Rectangle {
                            id: gridCard
                            width: 104
                            height: 104
                            radius: 8
                            color: isSelected ? Qt.rgba(122/255, 162/255, 247/255, 0.22) : (cardHover.containsMouse ? window.colCardHover : "transparent")
                            border.color: isSelected ? window.colBlue : (cardHover.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")
                            border.width: 1

                            readonly property bool isSelected: window.selectedIndex === index

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                // Low-res fast thumbnail or vector icon
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Image {
                                        anchors.centerIn: parent
                                        width: 44; height: 44
                                        source: window.isImageFile(model.fileName) ? model.filePath : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: window.isImageFile(model.fileName)
                                        asynchronous: true
                                        cache: true
                                        // Low resolution decoding to eliminate scroll stutter!
                                        sourceSize: Qt.size(48, 48)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: window.getIconGlyph(model.fileName, model.fileIsDir)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 34
                                        color: window.getIconColor(model.fileName, model.fileIsDir)
                                        visible: !window.isImageFile(model.fileName)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.fileName || ""
                                    font.family: "Fira Sans SemiBold, sans-serif"
                                    font.pixelSize: 11
                                    font.bold: gridCard.isSelected
                                    color: gridCard.isSelected ? "#ffffff" : window.colFg
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.fileIsDir ? "Folder" : window.formatSize(model.fileSize)
                                    font.family: "Fira Sans, sans-serif"
                                    font.pixelSize: 9
                                    color: window.colDim
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            HoverHandler { id: cardHover }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    window.selectedIndex = index;
                                    window.selectedPath = model.filePath;
                                }
                                onDoubleClicked: window.openItem(model.filePath, model.fileIsDir)
                            }
                        }
                    }

                    // 2. LIST VIEW
                    ListView {
                        id: listView
                        reuseItems: true
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        visible: window.viewMode === "list"
                        model: folderModel
                        spacing: 2

                        delegate: Rectangle {
                            id: listCard
                            width: listView.width
                            height: 32
                            radius: 6
                            color: isSelected ? Qt.rgba(122/255, 162/255, 247/255, 0.22) : (lHover.containsMouse ? window.colCardHover : "transparent")
                            border.color: isSelected ? window.colBlue : "transparent"
                            border.width: 1

                            readonly property bool isSelected: window.selectedIndex === index

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: window.getIconGlyph(model.fileName, model.fileIsDir)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                    color: window.getIconColor(model.fileName, model.fileIsDir)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.fileName || ""
                                    font.family: "Fira Sans SemiBold, sans-serif"
                                    font.pixelSize: 11
                                    color: listCard.isSelected ? "#ffffff" : window.colFg
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    width: 80
                                    text: model.fileIsDir ? "Folder" : window.formatSize(model.fileSize)
                                    font.family: "JetBrainsMono Nerd Font, monospace"
                                    font.pixelSize: 10
                                    color: window.colDim
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    width: 140
                                    text: window.formatDate(model.fileModified)
                                    font.family: "Fira Sans, sans-serif"
                                    font.pixelSize: 10
                                    color: window.colDim
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            HoverHandler { id: lHover }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    window.selectedIndex = index;
                                    window.selectedPath = model.filePath;
                                }
                                onDoubleClicked: window.openItem(model.filePath, model.fileIsDir)
                            }
                        }
                    }

                    // 3. GALLERY VIEW
                    GridView {
                        id: galView
                        reuseItems: true
                        anchors.fill: parent
                        anchors.margins: 14
                        cellWidth: 180
                        cellHeight: 160
                        clip: true
                        visible: window.viewMode === "gallery"
                        model: folderModel
                        cacheBuffer: 200

                        delegate: Rectangle {
                            id: galCard
                            width: 170
                            height: 150
                            radius: 8
                            color: isSelected ? Qt.rgba(122/255, 162/255, 247/255, 0.22) : (gHover.containsMouse ? window.colCardHover : window.colSunken)
                            border.color: isSelected ? window.colBlue : window.colBorderSubtle
                            border.width: 1

                            readonly property bool isSelected: window.selectedIndex === index

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: window.colSunken
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: window.isImageFile(model.fileName) ? model.filePath : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: window.isImageFile(model.fileName)
                                        asynchronous: true
                                        cache: true
                                        // Low resolution for gallery view
                                        sourceSize: Qt.size(120, 90)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: window.getIconGlyph(model.fileName, model.fileIsDir)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 38
                                        color: window.getIconColor(model.fileName, model.fileIsDir)
                                        visible: !window.isImageFile(model.fileName)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.fileName || ""
                                    font.family: "Fira Sans SemiBold, sans-serif"
                                    font.pixelSize: 11
                                    font.bold: galCard.isSelected
                                    color: galCard.isSelected ? "#ffffff" : window.colFg
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideMiddle
                                }
                            }

                            HoverHandler { id: gHover }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    window.selectedIndex = index;
                                    window.selectedPath = model.filePath;
                                }
                                onDoubleClicked: window.openItem(model.filePath, model.fileIsDir)
                            }
                        }
                    }
                }

                // ── Bottom Status Bar (30px) ─────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    color: window.colDark

                    // Subtle top divider
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: window.colBorderSubtle
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        Text {
                            text: folderModel.count + " items" + (window.selectedPath ? ("  •  Selected: " + window.selectedPath.split('/').pop()) : "")
                            font.family: "Fira Sans SemiBold, sans-serif"
                            font.pixelSize: 10
                            color: window.colDim
                            Layout.fillWidth: true
                        }

                        Row {
                            spacing: 8
                            Text { text: "Space QuickLook"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 9; color: window.colDim }
                            Text { text: "•"; font.pixelSize: 8; color: window.colBorderSubtle }
                            Text { text: "Ctrl+T Terminal"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 9; color: window.colDim }
                            Text { text: "•"; font.pixelSize: 8; color: window.colBorderSubtle }
                            Text { text: "Ctrl+H Hidden"; font.family: "JetBrainsMono Nerd Font, monospace"; font.pixelSize: 9; color: window.colDim }
                        }
                    }
                }
            }
        }
    }

    component NavIconBtn: Rectangle {
        id: nb
        property string icon: ""
        property bool enabled: true
        signal clicked()

        width: 24; height: 24; radius: 4
        color: nbArea.containsMouse && nb.enabled ? Qt.rgba(255/255, 255/255, 255/255, 0.10) : "transparent"
        opacity: nb.enabled ? 1.0 : 0.35

        Text {
            anchors.centerIn: parent
            text: nb.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: window.colFg
        }

        MouseArea {
            id: nbArea
            anchors.fill: parent
            enabled: nb.enabled
            hoverEnabled: true
            cursorShape: nb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: nb.clicked()
        }
    }

    component ViewSegmentBtn: Rectangle {
        id: vsb
        property string icon: ""
        property bool active: false
        signal clicked()

        width: 26; height: 24; radius: 4
        color: vsb.active ? window.colBlue : (vsbArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")

        Text {
            anchors.centerIn: parent
            text: vsb.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: vsb.active ? "#101119" : (vsbArea.containsMouse ? "#ffffff" : window.colDim)
        }

        MouseArea {
            id: vsbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: vsb.clicked()
        }
    }
}
