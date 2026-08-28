import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import "../Ui"
import "../Services"

// =============================================================================
// Calendar & Weather Dashboard — macOS-inspired Unified 2-Column Suite
// Perfectly proportioned 860x480 for desktop and compact displays.
// =============================================================================

PopupShell {
    id: window

    padding: Design.space.md
    background: Design.tint(Design.ground, 0.94)
    borderColor: Design.glassBorder
    cornerRadius: Design.radius.panel

    property var currentTime: new Date()
    property var weatherData: null

    // Calendar state
    property int currentYear: currentTime.getFullYear()
    property int currentMonth: currentTime.getMonth() // 0-indexed
    property int viewYear: currentYear
    property int viewMonth: currentMonth
    property int selectedDay: currentTime.getDate()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: window.currentTime = new Date()
    }

    // Weather Poller via native b1air-daemon
    Process {
        id: weatherPoller
        command: ["b1air-daemon", "weather", "json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt.length > 10) {
                    try {
                        window.weatherData = JSON.parse(txt);
                    } catch (e) {}
                }
            }
        }
    }

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    readonly property var weekDayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear--;
        } else {
            viewMonth--;
        }
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear++;
        } else {
            viewMonth++;
        }
    }

    function resetToToday() {
        viewYear = currentYear;
        viewMonth = currentMonth;
        selectedDay = currentTime.getDate();
    }

    // Compute 42 calendar grid cells (6 rows x 7 days)
    readonly property var calendarGrid: {
        let cells = [];
        let firstDayIndex = (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7;
        let daysInCurrentMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(viewYear, viewMonth, 0).getDate();

        // Prev month padding
        for (let i = firstDayIndex - 1; i >= 0; i--) {
            cells.push({
                day: daysInPrevMonth - i,
                isCurrentMonth: false,
                isToday: false,
                year: viewMonth === 0 ? viewYear - 1 : viewYear,
                month: viewMonth === 0 ? 11 : viewMonth - 1
            });
        }

        // Current month days
        let todayDay = currentTime.getDate();
        let isCurrentMonthViewing = (viewYear === currentYear && viewMonth === currentMonth);
        for (let d = 1; d <= daysInCurrentMonth; d++) {
            cells.push({
                day: d,
                isCurrentMonth: true,
                isToday: isCurrentMonthViewing && (d === todayDay),
                year: viewYear,
                month: viewMonth
            });
        }

        // Next month padding to fill 42 cells (6 rows)
        let remaining = 42 - cells.length;
        for (let n = 1; n <= remaining; n++) {
            cells.push({
                day: n,
                isCurrentMonth: false,
                isToday: false,
                year: viewMonth === 11 ? viewYear + 1 : viewYear,
                month: viewMonth === 11 ? 0 : viewMonth + 1
            });
        }

        return cells;
    }

    readonly property var todayForecast: (window.weatherData && window.weatherData.forecast && window.weatherData.forecast.length > 0)
        ? window.weatherData.forecast[0] : null

    RowLayout {
        anchors.fill: parent
        spacing: Design.s(Design.space.md)

        // ═════════════════════════════════════════════════════════════════════
        // LEFT: CALENDAR CARD (310px)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: Design.s(310)
            Layout.fillHeight: true
            radius: Design.s(Design.radius.card)
            color: Design.glassCard
            border.color: Design.glassBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Design.s(12)
                spacing: Design.s(8)

                // Month / Year Navigation Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(4)

                    Label {
                        text: window.monthNames[window.viewMonth] + " " + window.viewYear
                        weight: Design.weight.bold
                        role: "body"
                        color: Design.text
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: Design.s(26); height: Design.s(26)
                        radius: Design.s(Design.radius.ctl)
                        color: prevMa.containsMouse ? Design.glassHover : Design.surface
                        border.color: Design.line; border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            text: "\u{f053}"
                            role: "caption"
                            color: Design.text
                        }
                        Clickable {
                            id: prevMa
                            hoverEnabled: true
                            onClicked: window.prevMonth()
                        }
                    }

                    Rectangle {
                        width: Design.s(26); height: Design.s(26)
                        radius: Design.s(Design.radius.ctl)
                        color: todayMa.containsMouse ? Design.glassHover : Design.surface
                        border.color: Design.line; border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            text: "\u{f017}"
                            role: "caption"
                            color: Design.accent
                        }
                        Clickable {
                            id: todayMa
                            hoverEnabled: true
                            onClicked: window.resetToToday()
                        }
                    }

                    Rectangle {
                        width: Design.s(26); height: Design.s(26)
                        radius: Design.s(Design.radius.ctl)
                        color: nextMa.containsMouse ? Design.glassHover : Design.surface
                        border.color: Design.line; border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            text: "\u{f054}"
                            role: "caption"
                            color: Design.text
                        }
                        Clickable {
                            id: nextMa
                            hoverEnabled: true
                            onClicked: window.nextMonth()
                        }
                    }
                }

                // Days of week header (Mo Tu We Th Fr Sa Su)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: window.weekDayNames
                        Label {
                            Layout.fillWidth: true
                            text: modelData
                            horizontalAlignment: Text.AlignHCenter
                            role: "caption"
                            weight: Design.weight.bold
                            color: (index >= 5) ? Design.accent : Design.textDim
                        }
                    }
                }

                // 7x6 Calendar Cells Grid
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: Design.s(2)
                    columnSpacing: Design.s(2)

                    Repeater {
                        model: window.calendarGrid

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Design.s(Design.radius.ctl)

                            readonly property bool isSel: modelData.isCurrentMonth && (modelData.day === window.selectedDay)
                            readonly property bool isTod: modelData.isToday

                            color: isTod ? Design.accent : (isSel ? Design.tint(Design.accent, 0.2) : (cellMa.containsMouse ? Design.glassHover : "transparent"))
                            border.color: isSel && !isTod ? Design.accent : "transparent"
                            border.width: 1

                            Label {
                                anchors.centerIn: parent
                                text: modelData.day.toString()
                                role: "caption"
                                weight: (isTod || isSel) ? Design.weight.bold : Design.weight.regular
                                isMono: true
                                color: isTod ? Design.surface : (modelData.isCurrentMonth ? Design.text : Design.textDim)
                                opacity: modelData.isCurrentMonth ? 1.0 : 0.35
                            }

                            Clickable {
                                id: cellMa
                                hoverEnabled: true
                                onClicked: {
                                    if (modelData.isCurrentMonth) {
                                        window.selectedDay = modelData.day;
                                    } else {
                                        window.viewYear = modelData.year;
                                        window.viewMonth = modelData.month;
                                        window.selectedDay = modelData.day;
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom Date Stamp
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Design.s(28)
                    radius: Design.s(Design.radius.ctl)
                    color: Design.sunken

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Design.s(8)
                        anchors.rightMargin: Design.s(8)
                        spacing: Design.s(Design.space.xs)

                        Icon {
                            text: "\u{f073}"
                            role: "caption"
                            color: Design.accent
                        }

                        Label {
                            text: Qt.formatDateTime(window.currentTime, "dddd, MMMM d, yyyy")
                            role: "caption"
                            weight: Design.weight.medium
                            color: Design.textDim
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // RIGHT: WEATHER & TIME DASHBOARD (Fill remaining width)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Design.s(Design.radius.card)
            color: Design.glassCard
            border.color: Design.glassBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Design.s(14)
                spacing: Design.s(10)

                // ── Top Row: Clock & Current Weather Badge ───────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.md)

                    // Big Clean Clock
                    ColumnLayout {
                        spacing: 0
                        Label {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.pixelSize: Design.s(48)
                            font.family: Design.font.mono
                            font.weight: Design.weight.bold
                            color: Design.text
                        }
                        Label {
                            text: Qt.formatDateTime(window.currentTime, "dddd • d MMMM")
                            role: "caption"
                            weight: Design.weight.semibold
                            color: Design.accent
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Weather Hero Card
                    Rectangle {
                        Layout.preferredWidth: Design.s(240)
                        Layout.preferredHeight: Design.s(68)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        border.color: Design.glassBorder; border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(8)
                            spacing: Design.s(10)

                            // Weather Icon
                            Rectangle {
                                width: Design.s(44); height: Design.s(44)
                                radius: Design.s(10)
                                color: Design.glassCard

                                Icon {
                                    anchors.centerIn: parent
                                    text: window.todayForecast ? (window.todayForecast.icon || "\u{f0c2}") : "\u{f0c2}"
                                    font.pixelSize: Design.s(24)
                                    color: window.todayForecast ? (window.todayForecast.hex || Design.accent) : Design.accent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                RowLayout {
                                    spacing: Design.s(Design.space.xs)
                                    Label {
                                        text: window.todayForecast ? (window.todayForecast.max + "°C") : "--°C"
                                        font.pixelSize: Design.s(20)
                                        font.family: Design.font.mono
                                        font.weight: Design.weight.bold
                                        color: Design.text
                                    }
                                    Label {
                                        text: window.todayForecast ? ("Feels " + window.todayForecast.feels_like + "°") : ""
                                        role: "caption"
                                        color: Design.textDim
                                    }
                                }
                                Label {
                                    text: window.todayForecast ? window.todayForecast.desc : "Fetching weather..."
                                    role: "caption"
                                    weight: Design.weight.semibold
                                    color: Design.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Design.tint(Design.line, 0.4)
                }

                // ── 4 Weather Metrics Pills ──────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    // Wind
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(40)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(6)
                            Icon { text: "\u{f0590}"; role: "caption"; color: Design.teal }
                            ColumnLayout {
                                spacing: 0
                                Label { text: "Wind"; role: "caption"; color: Design.textDim; font.pixelSize: Design.s(10) }
                                Label { text: window.todayForecast ? (window.todayForecast.wind + " km/h") : "--"; role: "caption"; weight: Design.weight.bold; color: Design.text }
                            }
                        }
                    }

                    // Humidity
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(40)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(6)
                            Icon { text: "\u{f043}"; role: "caption"; color: Design.sapphire }
                            ColumnLayout {
                                spacing: 0
                                Label { text: "Humidity"; role: "caption"; color: Design.textDim; font.pixelSize: Design.s(10) }
                                Label { text: window.todayForecast ? (window.todayForecast.humidity + "%") : "--"; role: "caption"; weight: Design.weight.bold; color: Design.text }
                            }
                        }
                    }

                    // Rain / Precip
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(40)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(6)
                            Icon { text: "\u{f0597}"; role: "caption"; color: Design.blue }
                            ColumnLayout {
                                spacing: 0
                                Label { text: "Rain"; role: "caption"; color: Design.textDim; font.pixelSize: Design.s(10) }
                                Label { text: (window.todayForecast && window.todayForecast.rain_chance !== undefined) ? (window.todayForecast.rain_chance + "%") : "0%"; role: "caption"; weight: Design.weight.bold; color: Design.text }
                            }
                        }
                    }

                    // Range Min/Max
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(40)
                        radius: Design.s(Design.radius.ctl)
                        color: Design.sunken
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(6)
                            spacing: Design.s(6)
                            Icon { text: "\u{f2c9}"; role: "caption"; color: Design.peach }
                            ColumnLayout {
                                spacing: 0
                                Label { text: "Range"; role: "caption"; color: Design.textDim; font.pixelSize: Design.s(10) }
                                Label { text: window.todayForecast ? (window.todayForecast.min + "° - " + window.todayForecast.max + "°") : "--"; role: "caption"; weight: Design.weight.bold; color: Design.text }
                            }
                        }
                    }
                }

                // ── 5-Day Forecast Row ───────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.s(Design.space.xs)

                    Repeater {
                        model: (window.weatherData && window.weatherData.forecast) ? window.weatherData.forecast.slice(0, 5) : []

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Design.s(68)
                            radius: Design.s(Design.radius.ctl)
                            color: Design.sunken
                            border.color: Design.glassBorder; border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Design.s(6)
                                spacing: Design.s(2)

                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.day || ""
                                    role: "caption"
                                    weight: Design.weight.bold
                                    color: (index === 0) ? Design.accent : Design.text
                                }

                                Icon {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon || "\u{f0c2}"
                                    role: "caption"
                                    color: modelData.hex || Design.accent
                                }

                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (modelData.min || "-") + "° / " + (modelData.max || "-") + "°"
                                    role: "caption"
                                    font.pixelSize: Design.s(10)
                                    color: Design.textDim
                                    isMono: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
