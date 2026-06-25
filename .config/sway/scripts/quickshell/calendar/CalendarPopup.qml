import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../Ui"

PopupShell {
    id: window

    // Durations that are choreography, not styling: a staged entrance, ambient
    // loops and slow tint crossfades. Deliberately off the motion scale.
    // PauseAnimation delays are left as they are — that spread is the stagger.
    readonly property int introDuration: 800
    readonly property int tintDuration: 1000
    readonly property int pulsePeriod: 1500
    readonly property int driftPeriod: 90000


    // Durations that are choreography, not styling: a staged entrance, ambient
    // loops and slow tint crossfades. Deliberately off the motion scale.
    // PauseAnimation delays are left as they are — that spread is the stagger.
    readonly property int introDuration: 800
    readonly property int tintDuration: 1000
    readonly property int pulsePeriod: 1500
    readonly property int driftPeriod: 90000



    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // (Escape is handled by Main.qml now)
    // -------------------------------------------------------------------------
    Shortcut { 
        sequence: "Left"
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut { 
        sequence: "Right"
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }


    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/sway/scripts/quickshell/calendar"

    // -------------------------------------------------------------------------
    // TIME OF DAY DYNAMIC COLORS
    // -------------------------------------------------------------------------
    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return Design.warn;      // Morning
        if (h >= 12 && h < 17) return Design.accentSoft;  // Afternoon
        if (h >= 17 && h < 21) return Design.accentAlt;     // Evening
        return Design.accent;                             // Night
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return Design.warn;     // Morning Accent
        if (h >= 12 && h < 17) return Design.ok;      // Afternoon Accent
        if (h >= 17 && h < 21) return Design.accentAlt;      // Evening Accent
        return Design.accentAlt;                            // Night Accent
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(Design.text, 0.35))

    // -------------------------------------------------------------------------
    // STARTUP ANIMATION STATES
    // -------------------------------------------------------------------------
    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0
    property real introSchedule: 0

    SequentialAnimation {
        running: true
        
        // 50ms buffer to allow the window manager to map the surface before animating
        PauseAnimation { duration: 20 }

        ParallelAnimation {
            // Base window fades and scales slightly
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuart }

            // Ambient background glows and big parallax icon fade in
            SequentialAnimation {
                PauseAnimation { duration: Design.duration.fast }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutSine }
            }

            // Central clock and 3D orbital pop from the center
            SequentialAnimation {
                PauseAnimation { duration: Design.duration.base }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            // Left wing (Calendar) slides in from the left
            SequentialAnimation {
                PauseAnimation { duration: Design.duration.base }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuint }
            }

            // Right wing (Weather) slides in from the right
            SequentialAnimation {
                PauseAnimation { duration: Design.duration.slow }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuint }
            }

            // Bottom section (Schedule) flows up smoothly
            SequentialAnimation {
                PauseAnimation { duration: Design.duration.slow }
                NumberAnimation { target: window; property: "introSchedule"; from: 0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutExpo }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: window; property: "introMain"; to: 0; duration: Design.duration.slow; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introAmbient"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introClock"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introCalendar"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introWeather"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introSchedule"; to: 0; duration: Design.duration.base; easing.type: Easing.InQuart }
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: window.driftPeriod; loops: Animation.Infinite; running: true
    }

    // -------------------------------------------------------------------------
    // STATE & TIME (WITH SECOND PULSE)
    // -------------------------------------------------------------------------
    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000
    
    property real secondPulse: 1.0
    NumberAnimation on secondPulse { 
        id: pulseReset 
        to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuint; running: false 
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            window.currentTime = new Date();
            window.secondPulse = 1.06; // Gentle pulse
            pulseReset.start();        
            
            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    // -------------------------------------------------------------------------
    // WEATHER DATA & ELEGANT TRANSITIONS (3D ORBIT SPIN)
    // -------------------------------------------------------------------------
    property var weatherData: null
    property int weatherView: 0
    property color activeWeatherHex: weatherData && weatherData.forecast && weatherData.forecast[weatherView] ? weatherData.forecast[weatherView].hex : Design.accentAlt

    // Transition Properties
    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1
    
    // New 3D Spin Properties
    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    // -------------------------------------------------------------------------
    // TEMPERATURE LOGIC 
    // -------------------------------------------------------------------------
    property real targetTemp: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? Number(window.weatherData.forecast[window.targetWeatherView].max) : 0
    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: window.introDuration
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return Design.text;
        
        // If the target is higher than the currently ticking number, we are counting up
        if (window.targetTemp > window.displayedTemp) return Design.danger;
        
        // If the target is lower than the currently ticking number, we are counting down
        if (window.targetTemp < window.displayedTemp) return Design.accent;
        
        return Design.text; 
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: Design.duration.base; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: Design.s(-40) * weatherAnimDirection; duration: Design.duration.base; easing.type: Easing.InSine }
            
            // Spin the 3D orbit out and scale it down for depth
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: Design.duration.base; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: Design.duration.base; easing.type: Easing.InCubic }
        }
        ScriptAction { 
            script: { 
                window.weatherView = window.targetWeatherView; 
                window.weatherContentOffset = Design.s(40) * weatherAnimDirection; // Move to opposite side while hidden
                
                // Reset the spin to the opposite side so it continues spinning into place seamlessly
                window.transitionSpin = -180 * weatherAnimDirection;
            } 
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: Design.duration.slow; easing.type: Easing.OutQuart }
            
            // Snap the 3D orbit back to 0 degrees and restore full scale
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: window.introDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return; // Ignore if we are already heading there

        // If an animation is already running, gracefully interrupt it and apply the logical switch
        // before starting the new animation so the data doesn't get desynced.
        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;
        
        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;
        
        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0]);
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    Process {
        id: weatherPoller
        command: ["bash", window.scriptsDir + "/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.weatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 150000 
        running: true; repeat: true
        onTriggered: weatherPoller.running = true
    }

    // -------------------------------------------------------------------------
    // SCHEDULE DATA & CONDITIONAL RENDERING
    // -------------------------------------------------------------------------
    property bool scheduleModuleExists: false
    property var scheduleData: { "header": "Loading Schedule...", "link": "", "lessons": [] }

    // Dynamic offset based on whether the schedule module exists
    property real centerOffset: window.scheduleModuleExists ? Design.s(-100) : 0
    Behavior on centerOffset { NumberAnimation { duration: window.introDuration; easing.type: Easing.OutQuart } }

    // Check if the schedule manager script actually exists before doing anything
    Process {
        id: schedulePathChecker
        command: ["bash", "-c", "[ -f '" + window.scriptsDir + "/schedule/schedule_manager.sh' ] && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "1") {
                    window.scheduleModuleExists = true;
                    schedulePoller.running = true; // Safe to start polling
                } else {
                    window.scheduleModuleExists = false;
                    
                    // --- DYNAMICALLY SHRINK THE MASTER WINDOW ---
                    // Reach out to the global 'masterWindow' ID and update both
                    // the morphing wrapper (animH) and the content wrapper (targetH)
                    if (typeof masterWindow !== "undefined") {
                        let newHeight = Design.s(510);
                        masterWindow.animH = newHeight;
                        masterWindow.targetH = newHeight;
                    }
                }
            }
        }
    }

    Process {
        id: schedulePoller
        command: ["bash", window.scriptsDir + "/schedule/schedule_manager.sh"]
        running: false // Handled by schedulePathChecker
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.scheduleData = JSON.parse(txt); } catch(e) { console.log("Schedule Parse Error:", e); }
                }
            }
        }
    }

    Timer {
        interval: 600000 
        // Only run the timer if the module actually exists
        running: window.scheduleModuleExists; repeat: true
        onTriggered: schedulePoller.running = true
    }

    // -------------------------------------------------------------------------
    // CALENDAR GRID LOGIC & TRANSITIONS
    // -------------------------------------------------------------------------
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: Design.duration.base; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: Design.s(-20) * calendarAnimDirection; duration: Design.duration.base; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = Design.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: Design.duration.base; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: Design.duration.base; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1); 
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();
        
        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1; 

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: Design.s(20)
            color: Design.surface
            border.color: Design.raised
            border.width: 1
            clip: true

            // =======================================================
            // AMBIENT WIDGET COLOR BLOBS (Spread Out)
            // =======================================================
            Rectangle {
                width: Design.s(parent.width * 0.5); height: width; radius: width / 2
                x: (parent.width * 0.75 - width / 2) + Math.cos(window.globalOrbitAngle * 1.5) * Design.s(350)
                y: (parent.height * 0.3 - height / 2) + Math.sin(window.globalOrbitAngle * 1.5) * Design.s(200)
                opacity: 0.025 * window.introAmbient
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }

            Rectangle {
                width: Design.s(parent.width * 0.6); height: width; radius: width / 2
                x: (parent.width * 0.25 - width / 2) + Math.sin(window.globalOrbitAngle * 1.2) * Design.s(-300)
                y: (parent.height * 0.7 - height / 2) + Math.cos(window.globalOrbitAngle * 1.2) * Design.s(-250)
                opacity: 0.02 * window.introAmbient
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }

            Rectangle {
                width: Design.s(parent.width * 0.45); height: width; radius: width / 2
                x: (parent.width * 0.5 - width / 2) + Math.cos(window.globalOrbitAngle * -1.8) * Design.s(400)
                y: (parent.height * 0.5 - height / 2) + Math.sin(window.globalOrbitAngle * -1.8) * Design.s(-350)
                opacity: 0.015 * window.introAmbient
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }

            // Big Parallax Weather Icon (Tied to Weather Transition)
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.centerOffset
                text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : ""
                font.family: Design.font.icon
                font.pixelSize: Design.s(800)
                color: window.activeWeatherHex
                opacity: (0.03 + (0.01 * Math.sin(window.globalOrbitAngle * 4))) * window.introAmbient * window.weatherContentOpacity
                z: 0
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
                
                property real drift: 0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    NumberAnimation { to: Design.s(-20); duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                }
                
                transform: [
                    Translate { y: parent.drift },
                    Translate { x: window.weatherContentOffset * 2 } // Exaggerated shift for background depth
                ]
            }

            // =======================================================
            // CENTRAL HERO: THE BREATHING TIME HUB & 3D HOURLY ORBIT
            // =======================================================
            Item {
                id: centralHub
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.centerOffset
                width: Design.s(1); height: Design.s(1) 
                z: 5

                opacity: introClock
                scale: 0.85 + (0.15 * introClock)

                property real levitation: 0
                SequentialAnimation on levitation {
                    loops: Animation.Infinite
                    NumberAnimation { to: Design.s(-15); duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                }

                property real orbitBreath: 1.0
                SequentialAnimation on orbitBreath {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { to: 1.035; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                }

                // 3D Perspective Wobble (Pitch, Yaw, Roll)
                property real pitchBreath: 0
                SequentialAnimation on pitchBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 3.5; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -3.5; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                }

                property real yawBreath: 0
                SequentialAnimation on yawBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 2.5; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -2.5; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                }

                property real rollBreath: 0
                SequentialAnimation on rollBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 1.5; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1.5; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                }
                
                transform: [
                    Translate { y: Design.s(25) * (1.0 - introClock) },
                    Translate { y: centralHub.levitation },
                    Rotation { axis { x: 1; y: 0; z: 0 } angle: centralHub.pitchBreath },
                    Rotation { axis { x: 0; y: 1; z: 0 } angle: centralHub.yawBreath },
                    Rotation { axis { x: 0; y: 0; z: 1 } angle: centralHub.rollBreath }
                ]

                // OPTIMIZATION: Moved scale property out of the onPaint function to prevent redrawing every frame.
                // It now draws once, and scales using the GPU.
                Canvas {
                    id: orbitCanvas
                    z: -10
                    x: Design.s(-400)   // Widened to prevent clipping when scaled
                    y: Design.s(-200)   // Heightened to prevent clipping when scaled
                    width: Design.s(800)
                    height: Design.s(400)
                    opacity: 0.25

                    scale: centralHub.orbitBreath

                    onWidthChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.beginPath();
                        var currentRx = Design.s(320);
                        var currentRy = Design.s(140);
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width/2 + Math.cos(i) * currentRx;
                            var yy = height/2 + Math.sin(i) * currentRy;
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = window.textAccent;
                        ctx.lineWidth = Design.s(1.5);
                        ctx.setLineDash([Design.s(4), Design.s(10)]);
                        ctx.stroke();
                    }
                    Behavior on opacity { NumberAnimation { duration: window.introDuration } }
                }

                // Core Clock
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0 
                    scale: 0.95 + (0.05 * window.secondPulse) 
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Design.s(2)
                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: Design.font.mono
                            font.weight: Design.weight.bold
                            font.pixelSize: Design.s(84)
                            color: Design.text
                            style: Text.Outline; styleColor: Qt.alpha(Design.ground, 0.4)
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: Design.font.mono
                            font.weight: Design.weight.semibold
                            font.pixelSize: Design.s(32)
                            color: window.textAccent
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: Design.s(15)
                            opacity: window.secondPulse > 1.02 ? 1.0 : 0.6 
                            style: Text.Outline; styleColor: Qt.alpha(Design.ground, 0.4)
                            Behavior on color { ColorAnimation { duration: window.tintDuration } }
                        }
                    }

                    Label {
                        role: "subhead"
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.weight: Design.weight.semibold
                        dim: true
                        opacity: 0.9
                    }
                }

                // TRUE 3D ORBITAL HOURLY FORECAST (Tied to Spin Transition)
                Item {
                    anchors.fill: parent
                    opacity: window.weatherContentOpacity
                    
                    // Added Scale property to give a z-depth shrink effect when spinning
                    scale: window.transitionScale 
                    transform: Translate { x: window.weatherContentOffset * 1.5 }

                    Repeater {
                        id: hourRepeater
                        model: window.weatherData && window.weatherData.forecast[window.weatherView] && window.weatherData.forecast[window.weatherView].hourly ? window.weatherData.forecast[window.weatherView].hourly.slice(0, 8) : []
                        
                        delegate: Item {
                            property int mCount: hourRepeater.count
                            property bool isToday: window.weatherView === 0
                            property bool isHighlighted: isToday && index === window.activeHourIndex
                            
                            property real rx: Design.s(320) * centralHub.orbitBreath
                            property real ry: Design.s(140) * centralHub.orbitBreath
                            
                            property int relIdx: isToday ? (index - window.activeHourIndex) : index
                            
                            property real targetAngleDeg: isToday ? (65 + (relIdx * 30)) : (index * (360 / Math.max(1, mCount)))
                            
                            property real orbitOffset: isToday ? 0 : (window.globalOrbitAngle * (180 / Math.PI) * -1.5)
                            property real osc: isToday ? (Math.sin(window.globalOrbitAngle * 10 + index) * 5) : 0 
                            
                            // Integrated window.transitionSpin directly into the final angle calculation
                            property real rad: (targetAngleDeg + orbitOffset + osc + window.transitionSpin) * (Math.PI / 180)

                            x: Math.cos(rad) * rx - width/2
                            y: Math.sin(rad) * ry - height/2
                            z: Math.sin(rad) * Design.s(100) 
                            
                            scale: isHighlighted ? 1.4 : (isToday ? (0.95 + 0.20 * Math.sin(rad)) : (0.90 + 0.25 * Math.sin(rad)))
                            opacity: isHighlighted ? 1.0 : (isToday ? (0.7 + 0.3 * ((Math.sin(rad) + 1) / 2)) : (0.65 + 0.35 * ((Math.sin(rad) + 1) / 2)))

                            width: Design.s(56); height: Design.s(95)
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: Design.s(28)
                                color: isHighlighted ? window.textAccent : (hrMa.containsMouse ? Design.active : Design.raised)
                                border.color: isHighlighted ? "transparent" : (hrMa.containsMouse ? window.textAccent : Design.hover)
                                border.width: 1
                                
                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                
                                ColumnLayout {
                                    anchors.centerIn: parent 
                                    spacing: Design.s(4)
                                    
                                    Label {
                                        role: "caption"
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.time
                                        font.weight: Design.weight.semibold
                                        color: isHighlighted ? Design.surface : (hrMa.containsMouse ? Design.text : Design.textFaint)
                                    }
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || (window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : "")
                                        font.family: Design.font.icon; font.pixelSize: Design.s(18)
                                        color: isHighlighted ? Design.surface : (modelData.hex || Design.text)
                                        
                                        transform: Translate { y: hrMa.containsMouse ? Design.s(-3) : 0 }
                                        Behavior on transform { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                    }
                                    
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.temp + "°"
                                        font.weight: Design.weight.bold
                                        color: isHighlighted ? Design.surface : Design.text
                                    }
                                }
                            }
                            Clickable { id: hrMa }
                        }
                    }
                }
            }

            // =======================================================
            // LEFT WING: FLOATING GLASS CALENDAR
            // =======================================================
            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Design.s(40)
                width: Design.s(320)
                height: Design.s(420)
                color: Qt.alpha(Design.raised, 0.2) 
                radius: Design.s(14)
                border.color: Qt.alpha(Design.hover, 0.4)
                border.width: 1
                z: 10 

                opacity: introCalendar
                transform: Translate { x: Design.s(-40) * (1.0 - introCalendar) }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(25)
                    spacing: Design.s(15)

                    RowLayout {
                        Layout.fillWidth: true
                        
                        // "Return to Today" Home Button
                        Rectangle {
                            width: Design.s(32); height: Design.s(32); radius: Design.s(16)
                            color: homeMa.containsMouse ? Design.hover : "transparent"
                            opacity: window.targetMonthOffset !== 0 ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
                            Icon { anchors.centerIn: parent; text: "󰃭" }
                            MouseArea { 
                                id: homeMa; anchors.fill: parent; hoverEnabled: window.targetMonthOffset !== 0; 
                                onClicked: if (window.targetMonthOffset !== 0) window.setMonthOffset(0) 
                            }
                        }

                        Rectangle {
                            width: Design.s(32); height: Design.s(32); radius: Design.s(16)
                            color: prevMa.containsMouse ? Design.hover : "transparent"
                            Icon { anchors.centerIn: parent; text: "" }
                            Clickable { id: prevMa; onClicked: window.setMonthOffset(window.targetMonthOffset - 1) }
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: Design.font.mono
                            font.weight: Design.weight.bold
                            font.pixelSize: Design.s(16)
                            color: Design.text
                            horizontalAlignment: Text.AlignHCenter
                            
                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        Rectangle {
                            width: Design.s(32); height: Design.s(32); radius: Design.s(16)
                            color: nextMa.containsMouse ? Design.hover : "transparent"
                            Icon { anchors.centerIn: parent; text: "" }
                            Clickable { id: nextMa; onClicked: window.setMonthOffset(window.targetMonthOffset + 1) }
                        }

                        Rectangle {
                            width: Design.s(32); height: Design.s(32); radius: Design.s(16)
                            color: diaryMa.containsMouse ? Design.hover : "transparent"
                            Icon { role: "display"; anchors.centerIn: parent; text: "+"; color: diaryMa.containsMouse ? Design.accentAlt : Design.text }
                            Clickable {
                                id: diaryMa
                                onClicked: Quickshell.execDetached(["bash", window.scriptsDir + "/diary_manager.sh"])
                            }
                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Label {
                                Layout.fillWidth: true
                                text: modelData
                                font.weight: Design.weight.bold
                                color: Design.textFaint
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: Design.s(6)
                        columnSpacing: Design.s(6)

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                color: isToday ? window.textAccent : (dayMa.containsMouse ? Qt.alpha(Design.active, 0.4) : "transparent")
                                radius: Design.s(10)
                                scale: dayMa.containsMouse ? 1.2 : 1.0
                                border.color: isToday ? Design.raised : (dayMa.containsMouse ? Design.textFaint : "transparent")
                                border.width: isToday || dayMa.containsMouse ? 1 : 0
                                
                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }

                                Label {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.weight: isToday ? Design.weight.bold : Design.weight.semibold
                                    color: isToday ? Design.surface : (isCurrentMonth ? Design.text : Design.raised)
                                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                }

                                Clickable { id: dayMa }
                            }
                        }
                    }
                }
            }

            // =======================================================
            // RIGHT WING: ORGANIC FLOATING WEATHER STATS
            // =======================================================
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Design.s(40)
                width: Design.s(320)
                height: Design.s(420)
                z: 10 

                opacity: introWeather
                transform: Translate { x: Design.s(40) * (1.0 - introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Design.s(20)

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: Design.s(20)
                        
                        MouseArea { 
                            id: wPrevMa; width: Design.s(30); height: Design.s(30); hoverEnabled: true
                            onClicked: window.setWeatherView(window.targetWeatherView - 1) 
                            
                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: Design.s(-3); duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                            }
                            
                            Text { 
                                anchors.centerIn: parent; text: ""; font.family: Design.font.icon; font.pixelSize: Design.s(18)
                                color: parent.containsMouse ? window.textAccent : Design.textFaint
                                transform: Translate { x: parent.containsMouse ? Design.s(-5) : wPrevMa.pulseOffset }
                                Behavior on transform { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                            }
                        }
                        
                        Label {
                            role: "subhead"
                            Layout.preferredWidth: Design.s(110)
                            horizontalAlignment: Text.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].day_full.toUpperCase() : "LOADING..."
                            font.weight: Design.weight.bold
                        }
                        
                        MouseArea { 
                            id: wNextMa; width: Design.s(30); height: Design.s(30); hoverEnabled: true
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                            
                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: Design.s(3); duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: window.pulsePeriod; easing.type: Easing.InOutSine }
                            }
                            
                            Text { 
                                anchors.centerIn: parent; text: ""; font.family: Design.font.icon; font.pixelSize: Design.s(18)
                                color: parent.containsMouse ? window.textAccent : Design.textFaint
                                transform: Translate { x: parent.containsMouse ? Design.s(5) : wNextMa.pulseOffset }
                                Behavior on transform { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight 
                        spacing: Design.s(-5)
                        
                        // BIG TEMPERATURE TEXT - Anchored so it doesn't slide with the wrapper
                        Text {
                            Layout.alignment: Qt.AlignHCenter 
                            text: Math.round(window.displayedTemp) + "°"
                            font.family: Design.font.mono
                            font.weight: Design.weight.bold
                            font.pixelSize: Design.s(84)
                            color: window.tempGlowColor
                            style: Text.Outline; 
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(Design.ground, 0.4)
                            
                            Behavior on color { ColorAnimation { duration: Design.duration.base } }
                            Behavior on styleColor { ColorAnimation { duration: Design.duration.base } }
                        }
                        
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].desc : ""
                            font.family: Design.font.mono
                            font.weight: Design.weight.semibold
                            font.pixelSize: Design.s(16)
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: window.tintDuration } }
                            
                            opacity: window.weatherContentOpacity
                            transform: Translate { x: window.weatherContentOffset }
                        }
                    }

                    Item { Layout.fillHeight: true } 

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: Design.s(10)
                        spacing: Design.s(20)

                        Repeater {
                            model: 4

                            Item {
                                id: gaugeWrapper
                                width: Design.s(68)
                                height: Design.s(100)
                                scale: gaugeMa.containsMouse ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }

                                property var forecast: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? window.weatherData.forecast[window.targetWeatherView] : null

                                property string gaugeIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                property string gaugeLbl: index === 0 ? "WIND" : index === 1 ? "HUMID" : index === 2 ? "RAIN" : "FEELS"

                                property string gaugeVal: forecast ? (
                                    index === 0 ? forecast.wind + "m/s" :
                                    index === 1 ? forecast.humidity + "%" :
                                    index === 2 ? forecast.pop + "%" :
                                    forecast.feels_like + "°"
                                ) : ""

                                property real gaugeFill: forecast ? (
                                    index === 0 ? Math.min(1.0, forecast.wind / 25.0) :
                                    index === 1 ? forecast.humidity / 100.0 :
                                    index === 2 ? forecast.pop / 100.0 :
                                    Math.max(0.0, Math.min(1.0, (forecast.feels_like + 15) / 55.0))
                                ) : 0.0
                                
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Design.s(68); height: Design.s(68); radius: Design.s(34)
                                    color: window.textAccent
                                    opacity: gaugeMa.containsMouse ? 0.3 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
                                }

                                Item {
                                    id: circleItem
                                    width: Design.s(68); height: Design.s(68)
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    
                                    Canvas {
                                        id: gaugeCanvas
                                        anchors.fill: parent
                                        rotation: -90 
                                        
                                        property real animProgress: gaugeWrapper.gaugeFill
                                        
                                        Behavior on animProgress {
                                            NumberAnimation { duration: window.introDuration; easing.type: Easing.OutExpo }
                                        }
                                        
                                        // Ensuring canvas draws properly regardless of initialization speed
                                        onAnimProgressChanged: requestPaint()
                                        onWidthChanged: requestPaint()
                                        Component.onCompleted: requestPaint()
                                        
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var r = width / 2;
                                            
                                            ctx.beginPath();
                                            ctx.arc(r, r, r - Design.s(4), 0, 2 * Math.PI);
                                            ctx.strokeStyle = Qt.alpha(Design.text, 0.1);
                                            ctx.lineWidth = Design.s(3);
                                            ctx.stroke();
                                            
                                            if (animProgress > 0) {
                                                ctx.beginPath();
                                                ctx.arc(r, r, r - Design.s(4), 0, animProgress * 2 * Math.PI);
                                                var grad = ctx.createLinearGradient(0, 0, width, height);
                                                grad.addColorStop(0, window.timeAccent);
                                                grad.addColorStop(1, Design.accentSoft);
                                                ctx.strokeStyle = grad;
                                                ctx.lineWidth = Design.s(4);
                                                ctx.lineCap = "round";
                                                ctx.stroke();
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: gaugeWrapper.gaugeVal
                                        font.weight: Design.weight.bold
                                    }
                                }
                                
                                RowLayout {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: Design.s(4)
                                    
                                    Icon {
                                        role: "body"
                                        text: gaugeWrapper.gaugeIcon
                                        color: gaugeMa.containsMouse ? window.textAccent : Design.textFaint
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    }
                                    Label {
                                        role: "caption"
                                        text: gaugeWrapper.gaugeLbl
                                        font.weight: Design.weight.semibold
                                        color: Design.textFaint
                                    }
                                }
                                
                                Clickable { id: gaugeMa }
                            }
                        }
                    }
                }
            }

            // =======================================================
            // BOTTOM SECTION: FRAMELESS FLUID DATA STREAM (SCHEDULE)
            // =======================================================
            Item {
                id: bottomSection
                
                // CONDITIONAL RENDERING BINDING
                visible: window.scheduleModuleExists
                
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Design.s(240)
                z: 20 

                opacity: introSchedule
                transform: Translate { y: Design.s(50) * (1.0 - introSchedule) }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(Design.ground, 0.6) }
                    }
                }

                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.alpha(Design.hover, 0.5) }

                // OPTIMIZATION: Separated the massive continuous Canvas path-drawing loop into three pre-rendered hardware-accelerated static layers.
                Item {
                    anchors.fill: parent
                    z: -1
                    opacity: 0.15
                    clip: true

                    // Wave 1 - Mauve
                    Canvas {
                        id: wave1
                        property real wLen: Design.s(100) * 2 * Math.PI
                        width: parent.width + wLen
                        height: parent.height
                        
                        NumberAnimation on x { from: 0; to: -wave1.wLen; duration: window.introDuration; loops: Animation.Infinite; running: window.scheduleModuleExists }
                        
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cy = height / 2;
                            ctx.beginPath();
                            ctx.moveTo(0, cy);
                            for(var i = 0; i <= width + Design.s(20); i += Design.s(10)) {
                                ctx.lineTo(i, cy + Math.sin(i/Design.s(100)) * Design.s(30));
                            }
                            ctx.strokeStyle = Design.accentAlt;
                            ctx.lineWidth = Design.s(2);
                            ctx.stroke();
                        }
                    }

                    // Wave 2 - Sapphire
                    Canvas {
                        id: wave2
                        property real wLen: Design.s(120) * 2 * Math.PI
                        width: parent.width + wLen
                        height: parent.height
                        
                        NumberAnimation on x { from: -wave2.wLen; to: 0; duration: window.introDuration; loops: Animation.Infinite; running: window.scheduleModuleExists }
                        
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cy = height / 2;
                            ctx.beginPath();
                            ctx.moveTo(0, cy);
                            for(var i = 0; i <= width + Design.s(20); i += Design.s(10)) {
                                ctx.lineTo(i, cy + Math.sin(i/Design.s(120)) * Design.s(40));
                            }
                            ctx.strokeStyle = Design.accentSoft;
                            ctx.lineWidth = Design.s(2);
                            ctx.stroke();
                        }
                    }

                    // Wave 3 - Peach
                    Canvas {
                        id: wave3
                        property real wLen: Design.s(80) * 2 * Math.PI
                        width: parent.width + wLen
                        height: parent.height
                        
                        NumberAnimation on x { from: 0; to: -wave3.wLen; duration: window.introDuration; loops: Animation.Infinite; running: window.scheduleModuleExists }
                        
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cy = height / 2;
                            ctx.beginPath();
                            ctx.moveTo(0, cy);
                            for(var i = 0; i <= width + Design.s(20); i += Design.s(10)) {
                                ctx.lineTo(i, cy + Math.sin(i/Design.s(80)) * Design.s(20));
                            }
                            ctx.strokeStyle = Design.warn;
                            ctx.lineWidth = Design.s(2);
                            ctx.stroke();
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Design.s(25)
                    spacing: Design.s(15)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.s(15)
                        
                        Rectangle {
                            width: Design.s(40); height: Design.s(40); radius: Design.s(20); color: Design.raised
                            Icon { anchors.centerIn: parent; text: ""; color: window.textAccent }
                        }
                        
                        Label {
                            role: "subhead"
                            text: window.scheduleData ? window.scheduleData.header : "Loading Schedule..."
                            font.weight: Design.weight.semibold
                            color: Design.textFaint
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Rectangle {
                            width: Design.s(120); height: Design.s(36); radius: Design.s(10)
                            color: schLinkMa.containsMouse ? Design.accentAlt : Qt.alpha(Design.hover, 0.5)
                            border.color: Design.accentAlt; border.width: 1
                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Design.s(6)
                                Label { text: "Open Web"; font.weight: Design.weight.semibold; color: schLinkMa.containsMouse ? Design.surface : Design.text }
                                Icon { role: "body"; text: ""; color: schLinkMa.containsMouse ? Design.surface : Design.text }
                            }
                            
                            Clickable {
                                id: schLinkMa
                                onClicked: if(window.scheduleData && window.scheduleData.link) Quickshell.execDetached(["xdg-open", window.scheduleData.link])
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Label {
                            text: "Data stream offline. No scheduled events."
                            font.italic: true
                            color: Design.textFaint
                            visible: window.scheduleData && window.scheduleData.lessons.length === 0
                            anchors.centerIn: parent
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: Design.s(2)
                            color: Qt.alpha(Design.hover, 0.4)
                            visible: window.scheduleData && window.scheduleData.lessons.length > 0
                        }

                        ScrollView {
                            id: schedScroll
                            anchors.fill: parent
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                            visible: window.scheduleData && window.scheduleData.lessons.length > 0
                            contentWidth: scheduleRow.width
                            contentHeight: parent.height

                            Row {
                                id: scheduleRow
                                height: parent.height
                                spacing: 0
                                
                                // Divide the actual rendered width of the scroll area by the 430 minutes in a standard school day 
                                // to get the dynamic Pixels Per Minute ratio that stretches perfectly across the entire space.
                                property real ppm: schedScroll.width / 430.0

                                Repeater {
                                    model: window.scheduleData ? window.scheduleData.lessons : []

                                    delegate: Item {
                                        property bool isClass: modelData.type === "class"
                                        
                                        // Calculate the exact duration in minutes directly from the start and end epochs 
                                        property real durationMinutes: ((modelData.end || 0) - (modelData.start || 0)) / 60.0
                                        
                                        // Multiply duration by PPM and round to the nearest whole pixel to avoid sub-pixel gaps entirely
                                        width: Math.max(1, Math.round(durationMinutes * scheduleRow.ppm))
                                        height: parent.height
                                        
                                        Item {
                                            id: classNode
                                            anchors.fill: parent
                                            anchors.topMargin: Design.s(10)
                                            anchors.bottomMargin: Design.s(10)
                                            visible: parent.isClass
                                            
                                            property bool isActive: parent.isClass && window.currentEpoch >= (modelData.start || 0) && window.currentEpoch <= (modelData.end || 0)
                                            property bool isPast: parent.isClass && window.currentEpoch > (modelData.end || 0)
                                            
                                            Canvas {
                                                anchors.fill: parent
                                                visible: classMa.containsMouse || classNode.isActive
                                                opacity: classMa.containsMouse ? 0.2 : 0.08
                                                Behavior on opacity { NumberAnimation { duration: Design.duration.base } }
                                                
                                                property real wavePhase: 0
                                                NumberAnimation on wavePhase {
                                                    from: 0; to: Math.PI * 2; duration: window.introDuration; loops: Animation.Infinite; running: parent.visible
                                                }
                                                onWavePhaseChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.clearRect(0, 0, width, height);
                                                    ctx.beginPath();
                                                    ctx.moveTo(0, height);
                                                    for(var x = 0; x <= width; x += Design.s(10)) {
                                                        ctx.lineTo(x, height/2 + Math.sin(x/Design.s(25) + wavePhase) * Design.s(20));
                                                    }
                                                    ctx.lineTo(width, height);
                                                    ctx.lineTo(0, height);
                                                    var grad = ctx.createLinearGradient(0, 0, width, 0);
                                                    grad.addColorStop(0, Design.accentAlt);
                                                    grad.addColorStop(1, "transparent");
                                                    ctx.fillStyle = grad;
                                                    ctx.fill();
                                                }
                                            }

                                            Rectangle {
                                                id: accentLine
                                                width: classNode.isActive || classMa.containsMouse ? Design.s(4) : Design.s(2)
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                radius: Design.s(2)
                                                color: classNode.isActive ? Design.accentAlt : (classNode.isPast ? Design.hover : Design.active)
                                                Behavior on width { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                            }

                                            ColumnLayout {
                                                anchors.left: accentLine.right
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: classMa.containsMouse ? Design.s(25) : Design.s(15)
                                                Behavior on anchors.leftMargin { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }
                                                spacing: Design.s(6)

                                                Label {
                                                    role: "subhead"
                                                    text: modelData.subject || ""
                                                    font.weight: Design.weight.bold
                                                    color: classNode.isActive ? Design.accentAlt : (classNode.isPast ? Design.textFaint : Design.text)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                RowLayout {
                                                    visible: !modelData.is_compact
                                                    spacing: Design.s(8)
                                                    Icon { role: "body"; text: "󰅐"; color: classNode.isActive ? Design.accentAlt : Design.textFaint }
                                                    Label { text: modelData.time || ""; font.weight: Design.weight.semibold; color: classNode.isActive ? Design.text : Design.textFaint }
                                                }

                                                RowLayout {
                                                    visible: !modelData.is_compact && (modelData.room || "") !== ""
                                                    spacing: Design.s(8)
                                                    Icon { role: "body"; text: ""; color: classNode.isPast ? Design.active : Design.warn }
                                                    Label { text: modelData.room || ""; font.weight: Design.weight.semibold; dim: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                            }

                                            MouseArea { id: classMa; anchors.fill: parent; hoverEnabled: parent.visible }
                                        }

                                        Item {
                                            anchors.fill: parent
                                            visible: !parent.isClass
                                            
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: gapMa.containsMouse ? Design.s(4) : Design.s(2)
                                                color: gapMa.containsMouse ? Design.accentAlt : "transparent"
                                                Behavior on height { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutBack } }
                                                Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: breakText.width + Design.s(16)
                                                height: Design.s(24)
                                                radius: Design.s(6)
                                                color: Design.sunken
                                                border.color: Design.active
                                                border.width: 1
                                                opacity: gapMa.containsMouse ? 1.0 : 0.0
                                                scale: gapMa.containsMouse ? 1.0 : 0.8
                                                Behavior on opacity { NumberAnimation { duration: Design.duration.fast } }
                                                Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutBack } }

                                                Label {
                                                    id: breakText
                                                    anchors.centerIn: parent
                                                    text: modelData.desc || ""
                                                    font.weight: Design.weight.semibold
                                                    color: Design.accentAlt
                                                }
                                            }

                                            MouseArea { id: gapMa; anchors.fill: parent; hoverEnabled: parent.visible }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
