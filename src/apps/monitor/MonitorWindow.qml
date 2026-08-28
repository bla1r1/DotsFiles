import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Ui

Window {
    id: window
    title: "System Monitor"
    width: Design.s(880)
    height: Design.s(580)
    minimumWidth: Design.s(720)
    minimumHeight: Design.s(450)
    visible: true
    color: "transparent"

    onClosing: Qt.quit()

    readonly property bool isNative: typeof MonitorBackend !== "undefined"
    property string currentTab: "overview" // "overview", "processes"

    // ── Metric bindings (Direct C++ in-memory properties when native, 0 JSON) ──
    readonly property real cpuPct: isNative ? MonitorBackend.cpuPercent : 0.0
    readonly property string cpuModelStr: isNative ? MonitorBackend.cpuModel : "CPU"
    readonly property int cpuCores: isNative ? MonitorBackend.cores : 4
    readonly property string loadAvgStr: isNative ? MonitorBackend.loadAvg : "0.0 0.0 0.0"

    readonly property real ramPct: isNative ? MonitorBackend.ramPercent : 0.0
    readonly property real ramUsedMb: isNative ? MonitorBackend.ramUsedMb : 0.0
    readonly property real ramTotalMb: isNative ? MonitorBackend.ramTotalMb : 0.0

    readonly property real swapUsedMb: isNative ? MonitorBackend.swapUsedMb : 0.0
    readonly property real swapTotalMb: isNative ? MonitorBackend.swapTotalMb : 0.0

    readonly property real diskPct: isNative ? MonitorBackend.diskPercent : 0.0
    readonly property real diskFreeGb: isNative ? MonitorBackend.diskFreeGb : 0.0
    readonly property real diskTotalGb: isNative ? MonitorBackend.diskTotalGb : 0.0

    readonly property string uptimeStr: isNative ? MonitorBackend.uptime : "0h 0m"

    property string procSearchQuery: ""
    property string procSortBy: "cpu" // "cpu", "mem", "name", "pid"

    Connections {
        target: isNative ? MonitorBackend : null
        function onHistoryChanged() {
            historyChart.requestPaint();
        }
    }

    // ── Global Shortcuts ─────────────────────────────────────────────────────
    Shortcut { sequence: "Escape"; onActivated: window.close() }
    Shortcut { sequence: "Ctrl+F"; onActivated: if (window.currentTab === "processes") searchInput.forceActiveFocus() }
    Shortcut { sequence: "F5"; onActivated: if (isNative) MonitorBackend.refresh() }

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        radius: (window.visibility === Window.Maximized) ? 0 : Design.s(14)
        color: Design.base
        border.color: (window.visibility === Window.Maximized) ? "transparent" : Design.glassBorder
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ═════════════════════════════════════════════════════════════════
            // HEADER BAR (COMPACT TILED TOOLBAR)
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Design.s(36)
                color: Design.crust
                border.color: Design.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.sm)
                    anchors.rightMargin: Design.s(Design.space.sm)
                    spacing: Design.s(Design.space.sm)

                    // Title Branding
                    RowLayout {
                        spacing: Design.s(6)

                        Rectangle {
                            width: Design.s(22)
                            height: Design.s(22)
                            radius: Design.s(Design.radius.sm)
                            color: Design.tint(Design.sapphire, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: "\u{f080}" // bar-chart / pulse
                                color: Design.sapphire
                                font.family: Design.font.icon
                                font.pixelSize: Design.s(12)
                            }
                        }

                        Text {
                            text: "System Monitor"
                            font.family: Design.font.sans
                            font.weight: Design.weight.bold
                            font.pixelSize: Design.s(12)
                            color: Design.text
                        }
                    }

                    Item { Layout.fillWidth: true }

                // Tab Switcher Pills
                Rectangle {
                    implicitWidth: tabRow.implicitWidth + Design.s(6)
                    implicitHeight: Design.s(26)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.sunken
                    border.color: Design.glassBorder
                    border.width: 1

                    RowLayout {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: Design.s(2)

                        Rectangle {
                            implicitWidth: Design.s(76)
                            implicitHeight: Design.s(22)
                            radius: Design.s(Design.radius.sm)
                            color: window.currentTab === "overview" ? Design.tint(Design.accent, 0.28) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "Overview"
                                font.family: Design.font.sans
                                font.weight: window.currentTab === "overview" ? Design.weight.bold : Design.weight.medium
                                font.pixelSize: Design.s(11)
                                color: window.currentTab === "overview" ? Design.accent : Design.textDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: window.currentTab = "overview"
                            }
                        }

                        Rectangle {
                            implicitWidth: Design.s(76)
                            implicitHeight: Design.s(22)
                            radius: Design.s(Design.radius.sm)
                            color: window.currentTab === "processes" ? Design.tint(Design.accent, 0.28) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "Processes"
                                font.family: Design.font.sans
                                font.weight: window.currentTab === "processes" ? Design.weight.bold : Design.weight.medium
                                font.pixelSize: Design.s(11)
                                color: window.currentTab === "processes" ? Design.accent : Design.textDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: window.currentTab = "processes"
                            }
                        }
                    }
                }

                // Refresh Button
                IconButton {
                    icon: "\u{f021}" // refresh
                    bordered: true
                    hoverTone: Design.accent
                    onClicked: if (isNative) MonitorBackend.refresh()
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // TAB 1: OVERVIEW (METRICS, DIALS & LIVE HISTORY GRAPH)
        // ═════════════════════════════════════════════════════════════════════
        ScrollView {
            id: overviewScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: window.currentTab === "overview"
            clip: true

            ColumnLayout {
                id: overviewCol
                x: Design.s(Design.space.md)
                width: window.width - Design.s(Design.space.md * 2)
                // A ScrollView sizes its content to the implicit height, which left
                // Layout.fillHeight below with nothing to claim and stranded the
                // bottom half of the tab. Grow to the viewport, scroll past it.
                height: Math.max(implicitHeight, overviewScroll.availableHeight)
                spacing: Design.s(Design.space.md)

                Item { Layout.preferredHeight: Design.s(4) }

                // ── 1. Top 4 Metric Cards ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(10)

                    // 1. CPU CARD
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Design.s(100)
                        radius: Design.s(Design.radius.card)
                        color: Design.ground
                        border.color: Design.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(10)
                            spacing: Design.s(10)

                            Rectangle {
                                width: Design.s(44)
                                height: Design.s(44)
                                radius: width / 2
                                color: Design.tint(Design.sapphire, 0.15)
                                border.color: Design.sapphire
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(window.cpuPct) + "%"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(11)
                                    color: Design.sapphire
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "CPU"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }

                                Text {
                                    text: window.cpuPct.toFixed(1) + "%"
                                    font.family: Design.font.sans
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(14)
                                    color: Design.text
                                }

                                Text {
                                    text: window.cpuCores + " Cores"
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // 2. RAM CARD
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Design.s(100)
                        radius: Design.s(Design.radius.card)
                        color: Design.ground
                        border.color: Design.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(10)
                            spacing: Design.s(10)

                            Rectangle {
                                width: Design.s(44)
                                height: Design.s(44)
                                radius: width / 2
                                color: Design.tint(Design.mauve, 0.15)
                                border.color: Design.mauve
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(window.ramPct) + "%"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(11)
                                    color: Design.mauve
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "MEMORY"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }

                                Text {
                                    text: (window.ramUsedMb / 1024.0).toFixed(1) + " GB"
                                    font.family: Design.font.sans
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(14)
                                    color: Design.text
                                }

                                Text {
                                    text: "of " + (window.ramTotalMb / 1024.0).toFixed(1) + " GB"
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }
                            }
                        }
                    }

                    // 3. DISK CARD
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Design.s(100)
                        radius: Design.s(Design.radius.card)
                        color: Design.ground
                        border.color: Design.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(10)
                            spacing: Design.s(10)

                            Rectangle {
                                width: Design.s(44)
                                height: Design.s(44)
                                radius: width / 2
                                color: Design.tint(Design.pink, 0.15)
                                border.color: Design.pink
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(window.diskPct) + "%"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(11)
                                    color: Design.pink
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "STORAGE"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }

                                Text {
                                    text: window.diskFreeGb.toFixed(1) + " GB"
                                    font.family: Design.font.sans
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(14)
                                    color: Design.text
                                }

                                Text {
                                    text: "Free Space"
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }
                            }
                        }
                    }

                    // 4. SYSTEM UPTIME CARD
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Design.s(100)
                        radius: Design.s(Design.radius.card)
                        color: Design.ground
                        border.color: Design.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(10)
                            spacing: Design.s(10)

                            Rectangle {
                                width: Design.s(44)
                                height: Design.s(44)
                                radius: width / 2
                                color: Design.tint(Design.teal, 0.15)
                                border.color: Design.teal
                                border.width: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f017}" // clock
                                    font.family: Design.font.icon
                                    color: Design.teal
                                    font.pixelSize: Design.s(16)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "UPTIME"
                                    font.family: Design.font.mono
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }

                                Text {
                                    text: window.uptimeStr
                                    font.family: Design.font.sans
                                    font.weight: Design.weight.bold
                                    font.pixelSize: Design.s(14)
                                    color: Design.text
                                }

                                Text {
                                    text: (isNative && MonitorBackend.processes ? MonitorBackend.processes.rowCount() : 0) + " Tasks"
                                    font.family: Design.font.sans
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                }
                            }
                        }
                    }
                }

                // ── 2. Live Performance History Graph ────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    // Nothing claimed the leftover vertical space, so the whole
                    // Overview tab stopped halfway down and left the bottom of the
                    // window empty.
                    Layout.fillHeight: true
                    Layout.minimumHeight: Design.s(220)
                    radius: Design.s(Design.radius.card)
                    color: Design.ground
                    border.color: Design.glassBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Design.s(16)
                        spacing: Design.s(8)

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "ACTIVITY HISTORY (LAST 60 SECONDS)"
                                font.family: Design.font.mono
                                font.weight: Design.weight.bold
                                font.pixelSize: Design.s(11)
                                color: Design.textDim
                            }

                            Item { Layout.fillWidth: true }

                            // Legend
                            RowLayout {
                                spacing: Design.s(16)

                                RowLayout {
                                    spacing: Design.s(6)
                                    Rectangle { width: Design.s(10); height: Design.s(10); radius: 2; color: Design.sapphire }
                                    Text { text: "CPU"; font.family: Design.font.sans; font.pixelSize: Design.s(11); color: Design.textDim }
                                }

                                RowLayout {
                                    spacing: Design.s(6)
                                    Rectangle { width: Design.s(10); height: Design.s(10); radius: 2; color: Design.mauve }
                                    Text { text: "Memory"; font.family: Design.font.sans; font.pixelSize: Design.s(11); color: Design.textDim }
                                }
                            }
                        }

                        Canvas {
                            id: historyChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            onPaint: {
                                let ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                // Grid lines
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.05)";
                                ctx.lineWidth = 1;
                                for (let y = 0; y <= height; y += height / 4) {
                                    ctx.beginPath();
                                    ctx.moveTo(0, y);
                                    ctx.lineTo(width, y);
                                    ctx.stroke();
                                }

                                function drawSeries(data, color, fillGrad) {
                                    if (!data || data.length < 2) return;
                                    // Inset by half the stroke width: the last sample
                                    // landed exactly on x = width, so the 2px line was
                                    // drawn half outside the canvas and looked clipped.
                                    let inset = 1;
                                    let plotW = width - inset * 2;
                                    let step = plotW / (40 - 1);
                                    let offset = inset + (40 - data.length) * step;

                                    ctx.beginPath();
                                    for (let i = 0; i < data.length; ++i) {
                                        let x = offset + (i * step);
                                        let y = height - ((data[i] / 100.0) * (height - 10)) - 5;
                                        if (i === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.strokeStyle = color;
                                    ctx.lineWidth = 2;
                                    ctx.stroke();

                                    ctx.lineTo(offset + ((data.length - 1) * step), height);
                                    ctx.lineTo(offset, height);
                                    ctx.closePath();
                                    ctx.fillStyle = fillGrad;
                                    ctx.fill();
                                }

                                let cpuData = isNative ? MonitorBackend.cpuHistory : [];
                                let ramData = isNative ? MonitorBackend.ramHistory : [];

                                drawSeries(cpuData, "#7aa2f7", "rgba(122, 162, 247, 0.15)");
                                drawSeries(ramData, "#bb9af7", "rgba(187, 154, 247, 0.10)");
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Design.s(8) }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // TAB 2: PROCESSES (TASK MANAGER TABLE)
        // ═════════════════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: window.currentTab === "processes"
            spacing: 0

            // Search and Sort Bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Design.s(44)
                color: Design.ground
                border.color: Design.glassBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.md)
                    anchors.rightMargin: Design.s(Design.space.md)
                    spacing: Design.s(Design.space.md)

                    // Search Filter
                    Rectangle {
                        Layout.preferredWidth: Design.s(220)
                        implicitHeight: Design.s(30)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        border.color: searchInput.activeFocus ? Design.accent : Design.glassBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.s(8)
                            anchors.rightMargin: Design.s(8)
                            spacing: Design.s(6)

                            Text {
                                text: "\u{f002}" // search
                                font.family: Design.font.icon
                                color: Design.textDim
                                font.pixelSize: Design.s(11)
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                font.family: Design.font.sans
                                font.pixelSize: Design.s(11)
                                color: Design.text
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    text: "Filter processes..."
                                    color: Design.textDim
                                    font: parent.font
                                    visible: !searchInput.text && !searchInput.activeFocus
                                }

                                onTextChanged: {
                                    window.procSearchQuery = text;
                                    if (isNative) MonitorBackend.setProcessFilter(text);
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Sort buttons
                    RowLayout {
                        spacing: Design.s(4)

                        Text {
                            text: "Sort by:"
                            font.family: Design.font.sans
                            font.pixelSize: Design.s(11)
                            color: Design.textDim
                        }

                        Rectangle {
                            implicitWidth: Design.s(54)
                            implicitHeight: Design.s(26)
                            radius: Design.s(Design.radius.sm)
                            color: window.procSortBy === "cpu" ? Design.tint(Design.accent, 0.25) : Design.surface

                            Text {
                                anchors.centerIn: parent
                                text: "CPU"
                                font.family: Design.font.sans
                                font.weight: window.procSortBy === "cpu" ? Design.weight.bold : Design.weight.medium
                                font.pixelSize: Design.s(11)
                                color: window.procSortBy === "cpu" ? Design.accent : Design.textDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    window.procSortBy = "cpu";
                                    if (isNative) MonitorBackend.setProcessSort("cpu");
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: Design.s(54)
                            implicitHeight: Design.s(26)
                            radius: Design.s(Design.radius.sm)
                            color: window.procSortBy === "mem" ? Design.tint(Design.accent, 0.25) : Design.surface

                            Text {
                                anchors.centerIn: parent
                                text: "RAM"
                                font.family: Design.font.sans
                                font.weight: window.procSortBy === "mem" ? Design.weight.bold : Design.weight.medium
                                font.pixelSize: Design.s(11)
                                color: window.procSortBy === "mem" ? Design.accent : Design.textDim
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    window.procSortBy = "mem";
                                    if (isNative) MonitorBackend.setProcessSort("mem");
                                }
                            }
                        }
                    }
                }
            }

            // Table Header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Design.s(30)
                color: Design.crust

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.s(Design.space.md)
                    anchors.rightMargin: Design.s(Design.space.md)
                    spacing: Design.s(Design.space.sm)

                    Text { text: "PID"; font.family: Design.font.mono; font.weight: Design.weight.bold; font.pixelSize: Design.s(10); color: Design.textDim; Layout.preferredWidth: Design.s(60) }
                    Text { text: "PROCESS NAME"; font.family: Design.font.sans; font.weight: Design.weight.bold; font.pixelSize: Design.s(10); color: Design.textDim; Layout.fillWidth: true }
                    Text { text: "USER"; font.family: Design.font.sans; font.weight: Design.weight.bold; font.pixelSize: Design.s(10); color: Design.textDim; Layout.preferredWidth: Design.s(80) }
                    Text { text: "% CPU"; font.family: Design.font.mono; font.weight: Design.weight.bold; font.pixelSize: Design.s(10); color: Design.textDim; Layout.preferredWidth: Design.s(70); horizontalAlignment: Text.AlignRight }
                    Text { text: "% MEM"; font.family: Design.font.mono; font.weight: Design.weight.bold; font.pixelSize: Design.s(10); color: Design.textDim; Layout.preferredWidth: Design.s(70); horizontalAlignment: Text.AlignRight }
                    Text { text: "ACTIONS"; font.family: Design.font.sans; font.weight: Design.weight.bold; font.pixelSize: Design.s(10); color: Design.textDim; Layout.preferredWidth: Design.s(80); horizontalAlignment: Text.AlignHCenter }
                }
            }

            // Process Rows List (Direct C++ Model)
            ListView {
                id: procList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                reuseItems: true
                model: isNative ? MonitorBackend.processes : null

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: procList.width
                    height: Design.s(36)
                    color: rowHover.containsMouse ? Design.tint(Design.text, 0.05) : (index % 2 === 0 ? "transparent" : Design.tint(Design.surface, 0.3))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Design.s(Design.space.md)
                        anchors.rightMargin: Design.s(Design.space.md)
                        spacing: Design.s(Design.space.sm)

                        Text {
                            text: String(model.pid)
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(11)
                            color: Design.textDim
                            Layout.preferredWidth: Design.s(60)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Design.s(8)

                            Text {
                                text: "\u{f108}" // binary icon
                                font.family: Design.font.icon
                                color: Design.sapphire
                                font.pixelSize: Design.s(12)
                            }

                            Text {
                                text: model.name
                                font.family: Design.font.sans
                                font.weight: Design.weight.semibold
                                font.pixelSize: Design.s(12)
                                color: Design.text
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: model.user
                            font.family: Design.font.sans
                            font.pixelSize: Design.s(11)
                            color: Design.textDim
                            Layout.preferredWidth: Design.s(80)
                        }

                        Text {
                            text: model.cpu.toFixed(1) + "%"
                            font.family: Design.font.mono
                            font.weight: model.cpu > 5.0 ? Design.weight.bold : Design.weight.regular
                            font.pixelSize: Design.s(11)
                            color: model.cpu > 15.0 ? Design.pink : (model.cpu > 5.0 ? Design.peach : Design.text)
                            Layout.preferredWidth: Design.s(70)
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            text: model.mem.toFixed(1) + "%"
                            font.family: Design.font.mono
                            font.pixelSize: Design.s(11)
                            color: Design.textDim
                            Layout.preferredWidth: Design.s(70)
                            horizontalAlignment: Text.AlignRight
                        }

                        // Kill Action Buttons
                        RowLayout {
                            Layout.preferredWidth: Design.s(80)
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Design.s(4)

                            Rectangle {
                                width: Design.s(26)
                                height: Design.s(26)
                                radius: width / 2
                                color: killHover.containsMouse ? Design.tint(Design.pink, 0.25) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00d}" // cross
                                    font.family: Design.font.icon
                                    color: killHover.containsMouse ? Design.pink : Design.textDim
                                    font.pixelSize: Design.s(11)
                                }

                                HoverHandler { id: killHover }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: if (isNative) MonitorBackend.killProcess(model.pid, false)
                                }
                            }

                            Rectangle {
                                width: Design.s(26)
                                height: Design.s(26)
                                radius: width / 2
                                color: forceHover.containsMouse ? Design.pink : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f057}" // skull / force kill
                                    font.family: Design.font.icon
                                    color: forceHover.containsMouse ? Design.crust : Design.textDim
                                    font.pixelSize: Design.s(11)
                                }

                                HoverHandler { id: forceHover }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: if (isNative) MonitorBackend.killProcess(model.pid, true)
                                }
                            }
                        }
                    }

                    HoverHandler { id: rowHover }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // BOTTOM STATUS BAR
        // ═════════════════════════════════════════════════════════════════════
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
                    text: (isNative && MonitorBackend.processes ? MonitorBackend.processes.rowCount() : 0) + " Total Tasks  |  Load: " + window.loadAvgStr + "  |  Uptime: " + window.uptimeStr
                    font.family: Design.font.sans
                    font.pixelSize: Design.s(10)
                    color: Design.textDim
                    font.weight: Design.weight.medium
                    Layout.fillWidth: true
                }

                Text {
                    text: "F5: Refresh  |  Escape: Close"
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
