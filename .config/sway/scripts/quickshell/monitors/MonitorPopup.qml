import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Ui"

PopupShell {
    id: window

    

    // -------------------------------------------------------------------------
    // STATE & MATH
    // -------------------------------------------------------------------------
    // Durations that are choreography, not styling: a staged entrance, ambient
    // drift and layout settling. Deliberately off the motion scale.
    readonly property int introDuration: 900
    readonly property int introSlow: 1500
    readonly property int tintDuration: 1000
    readonly property int layoutDuration: 600
    readonly property int driftPeriod: 90000

    property int activeEditIndex: 0
    // Virtual mapping scale (1920px -> 192 virtual units)
    property real uiScale: 0.10 
    
    // Wayland Absolute Anchor tracking
    property int originalLayoutOriginX: 0
    property int originalLayoutOriginY: 0

    ListModel {
        id: monitorsModel
    }

    ListModel {
        id: brightnessModel
    }
    
    property color selectedResAccent: Design.accentAlt
    property color selectedRateAccent: Design.accent
    readonly property string monitorsScriptPath: Quickshell.env("HOME") + "/.config/sway/scripts/tools/monitors.sh"
    readonly property string brightnessScriptPath: Quickshell.env("HOME") + "/.config/sway/scripts/controls/monitor-brightness.sh"

    property real currentSimW: monitorsModel.count > 0 ? monitorsModel.get(0).resW : 1920
    property real currentSimH: monitorsModel.count > 0 ? monitorsModel.get(0).resH : 1080

    function updateBrightnessModel(text) {
        try {
            let data = JSON.parse((text || "").trim() || "[]");
            brightnessModel.clear();
            for (let i = 0; i < data.length; i++) {
                brightnessModel.append({
                    id: data[i].id || "",
                    name: data[i].name || "Display",
                    type: data[i].type || "ddc",
                    brightness: Math.max(1, Math.min(100, parseInt(data[i].brightness) || 50))
                });
            }
        } catch(e) {}
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: window.driftPeriod
        loops: Animation.Infinite
        running: true
    }
    
    // -------------------------------------------------------------------------
    // FLUID STARTUP ANIMATIONS 
    // -------------------------------------------------------------------------
    property real introProgress: 0.0
    property real monitorScale: 0.85
    property real uiYOffset: Design.s(25)
    property real screenLight: 0.0

    Component.onCompleted: {
        startupAnim.start();
        brightnessPoller.running = true;
    }

    ParallelAnimation {
        id: startupAnim
        NumberAnimation { target: window; property: "introProgress"; from: 0.0; to: 1.0; duration: window.introDuration; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "monitorScale"; from: 0.85; to: 1.0; duration: window.introSlow; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "uiYOffset"; from: Design.s(25); to: 0; duration: window.introSlow; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "screenLight"; from: 0.0; to: 1.0; duration: window.introSlow; easing.type: Easing.InOutQuad }
    }
    property bool applyHovered: false
    property bool applyPressed: false
    property bool brightnessDragging: false
    property int activeTab: 0  // 0 = Display, 1 = Brightness

    onActiveEditIndexChanged: {
        menuTransitionAnim.restart();
    }

    // -------------------------------------------------------------------------
    // MATHEMATICAL PERIMETER GLUE (Virtual Coordinates - Do not scale)
    // -------------------------------------------------------------------------
    function isOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function isOverlappingAny(x, y, w, h, skipIdx) {
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            let m = monitorsModel.get(i);
            let mW = (m.resW / m.sysScale) * window.uiScale;
            let mH = (m.resH / m.sysScale) * window.uiScale;
            if (isOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function getPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        let edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH }, // Top Edge
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH }, // Bottom Edge
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH }, // Left Edge
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }  // Right Edge
        ];

        let bestX = pX;
        let bestY = pY;
        let minDist = 999999;

        for (let i = 0; i < 4; i++) {
            let e = edges[i];
            
            let cx = Math.max(e.x1, Math.min(pX, e.x2));
            let cy = Math.max(e.y1, Math.min(pY, e.y2));

            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW/2 - mW/2)) < snapT) cx = sX + sW/2 - mW/2;
            
            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH/2 - mH/2)) < snapT) cy = sY + sH/2 - mH/2;

            let dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) {
                minDist = dist;
                bestX = cx;
                bestY = cy;
            }
        }
        return { x: bestX, y: bestY };
    }

    function forceLayoutUpdate() {
        if (monitorsModel.count < 2) return;
        
        let mIdx = window.activeEditIndex;
        let mModel = monitorsModel.get(mIdx);
        let mW = (mModel.resW / mModel.sysScale) * window.uiScale;
        let mH = (mModel.resH / mModel.sysScale) * window.uiScale;

        let bestX = mModel.uiX;
        let bestY = mModel.uiY;
        let bestDist = 999999;

        // Loop through ALL other monitors to find the closest valid snap
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === mIdx) continue;
            let sModel = monitorsModel.get(i);
            let sW = (sModel.resW / sModel.sysScale) * window.uiScale;
            let sH = (sModel.resH / sModel.sysScale) * window.uiScale;
            
            let snapped = window.getPerimeterSnap(
                mModel.uiX, mModel.uiY,
                sModel.uiX, sModel.uiY,
                sW, sH, mW, mH, 20
            );
            
            let dist = Math.hypot(snapped.x - mModel.uiX, snapped.y - mModel.uiY);
            if (dist < bestDist) {
                bestDist = dist;
                bestX = snapped.x;
                bestY = snapped.y;
            }
        }

        monitorsModel.setProperty(mIdx, "uiX", bestX);
        monitorsModel.setProperty(mIdx, "uiY", bestY);
    }

    Timer {
        id: delayedLayoutUpdate
        interval: 10
        running: false
        repeat: false
        onTriggered: window.forceLayoutUpdate()
    }

    // -------------------------------------------------------------------------
    // NATIVE SYSTEM PROCESSES 
    // -------------------------------------------------------------------------
    Process {
        id: displayPoller
        command: ["swaymsg", "-t", "get_outputs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    monitorsModel.clear();
                    
                    let minX = 999999, minY = 999999;

                    for (let i = 0; i < data.length; i++) {
                        let rect = data[i].rect || { x: 0, y: 0, width: 0, height: 0 };
                        if (rect.x < minX) minX = rect.x;
                        if (rect.y < minY) minY = rect.y;
                    }

                    window.originalLayoutOriginX = minX !== 999999 ? minX : 0;
                    window.originalLayoutOriginY = minY !== 999999 ? minY : 0;

                    for (let i = 0; i < data.length; i++) {
                        let rect = data[i].rect || { x: 0, y: 0, width: 0, height: 0 };
                        let mode = data[i].current_mode || { width: rect.width, height: rect.height, refresh: 60000 };
                        let scl = data[i].scale !== undefined ? data[i].scale : 1.0;
                        let normalizedX = (rect.x - minX) * window.uiScale;
                        let normalizedY = (rect.y - minY) * window.uiScale;

                        monitorsModel.append({
                            name: data[i].name,
                            resW: mode.width,
                            resH: mode.height,
                            sysScale: scl,
                            rate: Math.round((mode.refresh || 60000) / 1000).toString(),
                            uiX: normalizedX,
                            uiY: normalizedY
                        });

                        if (data[i].focused) window.activeEditIndex = i;
                    }
                    
                    window.forceLayoutUpdate();
                } catch(e) {}
            }
        }
    }

    property bool brightnessUpdatePending: false

    Process {
        id: brightnessPoller
        command: ["bash", window.brightnessScriptPath, "list-ddc"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (window.brightnessDragging) {
                    window.brightnessUpdatePending = false;
                    return;
                }
                window.updateBrightnessModel(this.text);
                window.brightnessUpdatePending = false;
            }
        }
    }

    Process {
        id: brightnessRefresher
        command: ["bash", window.brightnessScriptPath, "refresh-ddc"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.updateBrightnessModel(this.text);
            }
        }
    }

    Timer {
        id: brightnessCooldownTimer
        interval: 3000
        repeat: false
        running: false
        onTriggered: {
            if (!brightnessPoller.running && !window.brightnessDragging) {
                window.brightnessUpdatePending = true;
                brightnessPoller.running = true;
            }
        }
    }

    Timer {
        id: brightnessRefreshTimer
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            if (!window.brightnessDragging && !brightnessPoller.running && !window.brightnessUpdatePending) {
                window.brightnessUpdatePending = true;
                brightnessPoller.running = true;
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * window.introProgress)
        opacity: window.introProgress

        Rectangle {
            anchors.fill: parent
            radius: Design.s(30)
            color: Design.surface
            border.color: Design.raised
            border.width: 1
            clip: true

            Rectangle {
                width: parent.width * 0.8
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * Design.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * Design.s(100)
                opacity: 0.04
                color: window.selectedResAccent
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * Design.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * Design.s(-100)
                opacity: 0.04
                color: window.selectedRateAccent
                Behavior on color { ColorAnimation { duration: window.tintDuration } }
            }

            // ==========================================
            // LEFT SIDE VISUAL AREA
            // ==========================================
            Item {
                id: leftVisualArea
                width: Design.s(380)
                height: Design.s(300)
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Design.s(20)

                // --------------------------------------------------
                // MODE 1: SINGLE MONITOR
                // --------------------------------------------------
                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count === 1

                    Item {
                        id: singleMonitorZoom
                        anchors.centerIn: parent
                        width: Design.s(380)
                        height: Design.s(280)
                        
                        property real baseScale: Math.min(1.0, 2200 / window.currentSimW)
                        scale: baseScale * window.monitorScale
                        opacity: window.introProgress
                        Behavior on baseScale { NumberAnimation { duration: window.layoutDuration; easing.type: Easing.OutQuint } }

                        Rectangle {
                            id: deskSurface
                            width: Design.s(1000)
                            height: Design.s(14)
                            radius: Design.s(6)
                            anchors.top: standBase.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Design.sunken
                            border.color: Design.raised
                            border.width: 1

                            Rectangle { 
                                width: Design.s(24)
                                height: Design.s(350)
                                radius: Design.s(4)
                                color: Design.ground
                                anchors.top: parent.bottom
                                anchors.topMargin: Design.s(-5)
                                anchors.left: parent.left
                                anchors.leftMargin: Design.s(100)
                                z: -1 
                            }
                            Rectangle { 
                                width: Design.s(24)
                                height: Design.s(350)
                                radius: Design.s(4)
                                color: Design.ground
                                anchors.top: parent.bottom
                                anchors.topMargin: Design.s(-5)
                                anchors.right: parent.right
                                anchors.rightMargin: Design.s(100)
                                z: -1 
                            }
                        }

                        Rectangle {
                            id: standBase
                            width: Design.s(130)
                            height: Design.s(8)
                            radius: Design.s(4)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Design.s(20)
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Design.hover
                        }
                        
                        Rectangle {
                            id: standNeck
                            width: Design.s(34)
                            height: Design.s(70)
                            anchors.bottom: standBase.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Design.raised
                            Rectangle { 
                                width: Design.s(10)
                                height: Design.s(30)
                                radius: Design.s(5)
                                anchors.centerIn: parent
                                color: Design.surface 
                            }
                        }

                        Rectangle {
                            id: screenBezel
                            width: Design.s(140) + (Design.s(180) * (window.currentSimW / 1920))
                            height: Design.s(90) + (Design.s(90) * (window.currentSimH / 1080))
                            anchors.bottom: standNeck.top
                            anchors.bottomMargin: Design.s(-10)
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: Design.s(12)
                            color: Design.ground
                            border.color: Design.active
                            border.width: Design.s(2)
                            
                            Behavior on width { NumberAnimation { duration: window.layoutDuration; easing.type: Easing.OutQuint } }
                            Behavior on height { NumberAnimation { duration: window.layoutDuration; easing.type: Easing.OutQuint } }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Design.s(10)
                                radius: Design.s(6)
                                color: Design.raised
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    opacity: window.screenLight
                                    
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { 
                                            position: 0.0
                                            color: Qt.tint(Design.raised, Qt.alpha(window.selectedResAccent, 0.15))
                                            Behavior on color { ColorAnimation { duration: Design.duration.slow } } 
                                        }
                                        GradientStop { 
                                            position: 1.0
                                            color: Qt.tint(Design.raised, Qt.alpha(window.selectedRateAccent, 0.1))
                                            Behavior on color { ColorAnimation { duration: Design.duration.slow } } 
                                        }
                                    }
                                    
                                    Grid { 
                                        anchors.centerIn: parent
                                        rows: 10
                                        columns: 15
                                        spacing: Design.s(20)
                                        Repeater { 
                                            model: 150
                                            Rectangle { width: Design.s(2); height: Design.s(2); radius: Design.s(1); color: Qt.alpha(Design.text, 0.1) } 
                                        } 
                                    }

                                    Item {
                                        anchors.centerIn: parent
                                        scale: 1.0 / singleMonitorZoom.scale
                                        
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: Design.s(4)
                                            Text { 
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: Design.font.icon
                                                font.pixelSize: Design.s(38)
                                                color: window.selectedResAccent
                                                text: "󰍹"
                                                Behavior on color { ColorAnimation { duration: Design.duration.slow } } 
                                            }
                                            Label {
                                                role: "subhead"
                                                Layout.alignment: Qt.AlignHCenter
                                                font.weight: Design.weight.semibold
                                                text: monitorsModel.count > 0 ? monitorsModel.get(0).name : "Unknown"
                                            }
                                            Label {
                                                role: "caption"
                                                Layout.alignment: Qt.AlignHCenter
                                                dim: true
                                                text: window.currentSimW + "x" + window.currentSimH + " @ " + (monitorsModel.count > 0 ? monitorsModel.get(0).rate : "60") + "Hz"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --------------------------------------------------
                // MODE 2: MULTI-MONITOR (3+ Supported)
                // --------------------------------------------------
                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count > 1

                    Item {
                        id: multiMonitorView
                        width: Design.s(380)
                        height: Design.s(280)
                        anchors.centerIn: parent
                        clip: true 

                        Grid {
                            anchors.centerIn: parent
                            rows: 25
                            columns: 34
                            spacing: Design.s(18)
                            Repeater { 
                                model: 850
                                Rectangle { width: Design.s(2); height: Design.s(2); radius: Design.s(1); color: Qt.alpha(Design.text, 0.1) } 
                            }
                        }

                        // Target Scale computes virtual bounds -> Maps to scaled physical layout
                        property real targetScale: {
                            if (monitorsModel.count < 2) return 1.0;
                            let minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
                            
                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let w = (m.resW / m.sysScale) * window.uiScale;
                                let h = (m.resH / m.sysScale) * window.uiScale;
                                
                                minX = Math.min(minX, m.uiX);
                                minY = Math.min(minY, m.uiY);
                                maxX = Math.max(maxX, m.uiX + w);
                                maxY = Math.max(maxY, m.uiY + h);
                            }
                            
                            let requiredW = (maxX - minX) + 80;
                            let requiredH = (maxY - minY) + 80;
                            
                            return Math.min(1.8 * scaler.baseScale, Math.min(Design.s(340) / requiredW, Design.s(240) / requiredH));
                        }

                        property real offsetX: {
                            if (monitorsModel.count < 2) return 0;
                            let minX = 999999, maxX = -999999;
                            
                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let w = (m.resW / m.sysScale) * window.uiScale;
                                
                                minX = Math.min(minX, m.uiX);
                                maxX = Math.max(maxX, m.uiX + w);
                            }
                            
                            let centerX = minX + (maxX - minX) / 2;
                            return Design.s(190) - (centerX * targetScale);
                        }

                        property real offsetY: {
                            if (monitorsModel.count < 2) return 0;
                            let minY = 999999, maxY = -999999;
                            
                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let h = (m.resH / m.sysScale) * window.uiScale;
                                
                                minY = Math.min(minY, m.uiY);
                                maxY = Math.max(maxY, m.uiY + h);
                            }
                            
                            let centerY = minY + (maxY - minY) / 2;
                            return Design.s(140) - (centerY * targetScale);
                        }

                        Item {
                            id: transformNode
                            x: multiMonitorView.offsetX
                            y: multiMonitorView.offsetY
                            scale: multiMonitorView.targetScale
                            transformOrigin: Item.TopLeft

                            Behavior on x { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }
                            Behavior on scale { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }

                            Repeater {
                                id: monitorRepeater
                                model: monitorsModel

                                // NOTE: The items inside the transform node remain strictly virtual
                                Item {
                                    property bool isActive: window.activeEditIndex === index

                                    // THE VISIBLE SNAPPED MONITOR CARD
                                    Rectangle {
                                        id: monitorCard
                                        x: model.uiX
                                        y: model.uiY
                                        
                                        width: (model.resW / model.sysScale) * window.uiScale
                                        height: (model.resH / model.sysScale) * window.uiScale
                                        
                                        radius: 8
                                        color: isActive ? Design.hover : Design.ground
                                        border.color: isActive ? window.selectedResAccent : Design.active
                                        border.width: isActive ? 2 : 1
                                        z: isActive ? 5 : 0

                                        Behavior on x { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutQuint } }
                                        
                                        Behavior on border.color { ColorAnimation { duration: Design.duration.base } }
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                        Behavior on width { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }
                                        Behavior on height { NumberAnimation { duration: Design.duration.slow; easing.type: Easing.OutQuint } }

                                        Item {
                                            anchors.centerIn: parent
                                            width: 110
                                            height: 80
                                            
                                            property real idealScale: Math.min(1.2, parent.width / 110, parent.height / 80) / transformNode.scale
                                            property real maxPhysicalScale: Math.min((parent.width * 0.9) / width, (parent.height * 0.9) / height)
                                            scale: Math.min(idealScale, maxPhysicalScale)
                                            
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text { 
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: Design.font.icon
                                                    font.pixelSize: 32
                                                    color: isActive ? window.selectedResAccent : Design.text
                                                    text: "󰍹"
                                                    Behavior on color { ColorAnimation { duration: Design.duration.base } } 
                                                }
                                                Text { 
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: Design.font.mono
                                                    font.weight: Design.weight.bold
                                                    font.pixelSize: 13
                                                    color: Design.text
                                                    text: model.name 
                                                }
                                                Text { 
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: Design.font.mono
                                                    font.pixelSize: 10
                                                    color: Design.textDim
                                                    text: model.resW + "x" + model.resH + " @ " + model.rate + "Hz" 
                                                }
                                            }
                                        }
                                    }

                                    // THE INVISIBLE GHOST DRAGGER
                                    Item {
                                        id: ghostDrag
                                        x: model.uiX
                                        y: model.uiY
                                        width: monitorCard.width
                                        height: monitorCard.height
                                        z: isActive ? 10 : 1

                                        MouseArea {
                                            id: ghostMa
                                            anchors.fill: parent
                                            drag.target: ghostDrag
                                            drag.axis: Drag.XAndYAxis
                                            
                                            onPressed: {
                                                window.activeEditIndex = index;
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }

                                            onPositionChanged: {
                                                if (drag.active && monitorsModel.count >= 2) {
                                                    let mW = monitorCard.width;
                                                    let mH = monitorCard.height;

                                                    // Compute boundary limits dynamically against ALL other monitors
                                                    let padding = 40;
                                                    let boundMinX = 999999, boundMinY = 999999;
                                                    let boundMaxX = -999999, boundMaxY = -999999;
                                                    
                                                    for (let j = 0; j < monitorsModel.count; j++) {
                                                        if (j === index) continue;
                                                        let sModel = monitorsModel.get(j);
                                                        let sW = (sModel.resW / sModel.sysScale) * window.uiScale;
                                                        let sH = (sModel.resH / sModel.sysScale) * window.uiScale;
                                                        
                                                        boundMinX = Math.min(boundMinX, sModel.uiX - mW - padding);
                                                        boundMinY = Math.min(boundMinY, sModel.uiY - mH - padding);
                                                        boundMaxX = Math.max(boundMaxX, sModel.uiX + sW + padding);
                                                        boundMaxY = Math.max(boundMaxY, sModel.uiY + sH + padding);
                                                    }

                                                    ghostDrag.x = Math.max(boundMinX, Math.min(ghostDrag.x, boundMaxX));
                                                    ghostDrag.y = Math.max(boundMinY, Math.min(ghostDrag.y, boundMaxY));

                                                    // Snap to the nearest perimeter of ANY other monitor
                                                    let bestX = ghostDrag.x;
                                                    let bestY = ghostDrag.y;
                                                    let bestDist = 999999;
                                                    
                                                    for (let j = 0; j < monitorsModel.count; j++) {
                                                        if (j === index) continue;
                                                        let sModel = monitorsModel.get(j);
                                                        let sW = (sModel.resW / sModel.sysScale) * window.uiScale;
                                                        let sH = (sModel.resH / sModel.sysScale) * window.uiScale;
                                                        
                                                        let snapped = window.getPerimeterSnap(
                                                            ghostDrag.x, ghostDrag.y,
                                                            sModel.uiX, sModel.uiY,
                                                            sW, sH, mW, mH, 20
                                                        );
                                                        
                                                        let dist = Math.hypot(ghostDrag.x - snapped.x, ghostDrag.y - snapped.y);
                                                        if (dist < bestDist) {
                                                            bestDist = dist;
                                                            bestX = snapped.x;
                                                            bestY = snapped.y;
                                                        }
                                                    }

                                                    if (!window.isOverlappingAny(bestX, bestY, mW, mH, index)) {
                                                        monitorsModel.setProperty(index, "uiX", bestX);
                                                        monitorsModel.setProperty(index, "uiY", bestY);
                                                    }
                                                }
                                            }

                                            onReleased: {
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // INTERACTIVE SELECTION GRIDS
            // ==========================================
            Item {
                anchors.left: leftVisualArea.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter 
                anchors.leftMargin: Design.s(10)
                anchors.rightMargin: Design.s(30)
                height: Design.s(310)

                opacity: window.introProgress
                transform: Translate { y: window.uiYOffset }

                SequentialAnimation {
                    id: menuTransitionAnim
                    ParallelAnimation {
                        ScaleAnimator { 
                            target: rightSideContainer
                            from: 0.99
                            to: 1.0
                            duration: Design.duration.base
                            easing.type: Easing.OutSine 
                        }
                        NumberAnimation { 
                            target: highlightFlash
                            property: "opacity"
                            from: 0.05
                            to: 0.0
                            duration: Design.duration.base
                            easing.type: Easing.OutQuad 
                        }
                    }
                }

                Rectangle {
                    id: highlightFlash
                    anchors.fill: rightSideContainer
                    anchors.margins: Design.s(-10)
                    color: window.selectedResAccent
                    opacity: 0.0
                    radius: Design.s(12)
                }

                ColumnLayout {
                    id: rightSideContainer
                    anchors.fill: parent
                    spacing: Design.s(10)

                    // --- TAB BAR ---
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(36)
                        radius: Design.s(18)
                        color: Design.sunken
                        border.color: Design.raised
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Design.s(3)
                            spacing: Design.s(3)

                            Repeater {
                                model: [
                                    { label: "Display",    icon: "󰍹" },
                                    { label: "Brightness", icon: "󰃠" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Design.s(15)
                                    property bool isSel: window.activeTab === index
                                    color: isSel ? Qt.alpha(index === 0 ? window.selectedResAccent : Design.warn, 0.18) : (tabMa.containsMouse ? Design.raised : "transparent")
                                    border.color: isSel ? (index === 0 ? window.selectedResAccent : Design.warn) : "transparent"
                                    border.width: isSel ? 1 : 0
                                    Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Design.duration.fast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Design.s(5)
                                        Icon {
                                            role: "body"
                                            color: isSel ? (index === 0 ? window.selectedResAccent : Design.warn) : Design.textDim
                                            text: modelData.icon
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                        }
                                        Label {
                                            role: "caption"
                                            font.weight: isSel ? Design.weight.semibold : Design.weight.regular
                                            color: isSel ? Design.text : Design.textDim
                                            text: modelData.label
                                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                                        }
                                    }
                                    Clickable { id: tabMa; onClicked: window.activeTab = index }
                                }
                            }
                        }
                    }

                    // --- DISPLAY TAB CONTENT ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Design.s(10)
                        visible: window.activeTab === 0
                        opacity: window.activeTab === 0 ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Design.duration.fast } }

                    // --- RESOLUTION CARDS SECTION ---
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Design.s(10)
                        rowSpacing: Design.s(10)

                        Repeater {
                            model: [
                                { resW: 3840, resH: 2160, label: "4K",   accent: Design.accentAlt }, 
                                { resW: 2560, resH: 1440, label: "QHD",  accent: Design.accentAlt },
                                { resW: 1920, resH: 1080, label: "FHD",  accent: Design.accent },
                                { resW: 1600, resH: 900,  label: "HD+",  accent: Design.ok }, 
                                { resW: 1366, resH: 768,  label: "WXGA", accent: Design.warn }, 
                                { resW: 1280, resH: 720,  label: "HD",   accent: Design.warn }, 
                                { resW: 1024, resH: 768,  label: "XGA",  accent: Design.ok }, 
                                { resW: 800,  resH: 600,  label: "SVGA", accent: Design.danger } 
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Design.s(48)
                                radius: Design.s(12)
                                
                                property bool isSel: {
                                    if (monitorsModel.count === 0) return false;
                                    let activeMon = monitorsModel.get(window.activeEditIndex);
                                    return activeMon.resW === modelData.resW && activeMon.resH === modelData.resH;
                                }
                                property color accentColor: modelData.accent
                                
                                color: isSel ? Qt.alpha(accentColor, 0.15) : (resMa.containsMouse ? Design.raised : Design.sunken)
                                border.color: isSel ? accentColor : (resMa.containsMouse ? Design.hover : "transparent")
                                border.width: isSel ? 2 : 1
                                
                                Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                Behavior on border.color { ColorAnimation { duration: Design.duration.base } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Design.s(12)
                                    spacing: Design.s(8)
                                    
                                    Label {
                                        role: "subhead"
                                        font.weight: isSel ? Design.weight.bold : Design.weight.semibold
                                        color: isSel ? accentColor : Design.text
                                        text: modelData.label
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    }
                                    
                                    Item { Layout.fillWidth: true } 
                                    
                                    Label {
                                        role: "caption"
                                        color: isSel ? Design.text : Design.textFaint
                                        text: modelData.resW + "x" + modelData.resH
                                        Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                    }
                                }

                                scale: resMa.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: Design.duration.fast; easing.type: Easing.OutSine } }

                                Clickable {
                                    id: resMa
                                    onClicked: {
                                        if (monitorsModel.count > 0) {
                                            window.selectedResAccent = accentColor;
                                            monitorsModel.setProperty(window.activeEditIndex, "resW", modelData.resW);
                                            monitorsModel.setProperty(window.activeEditIndex, "resH", modelData.resH);
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: Design.s(15) } 

                    // --- REFRESH RATE SLIDER SECTION ---
                    Item {
                        id: sliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: Design.s(50)
                        Layout.leftMargin: Design.s(10)
                        Layout.rightMargin: Design.s(10)
                        
                        property var rates: [60, 75, 100, 120, 144, 165, 180, 240, 360]
                        property var rateColors: [Design.danger, Design.accentAlt, Design.accent, Design.accentSoft, Design.ok, Design.accentAlt, Design.warn, Design.ok, Design.warn]
                        
                        property int currentIndex: {
                            if (monitorsModel.count === 0) return 0;
                            let currentVal = parseInt(monitorsModel.get(window.activeEditIndex).rate) || 60;
                            let closestIdx = 0;
                            let minDiff = 9999;
                            for (let i = 0; i < rates.length; i++) {
                                let diff = Math.abs(rates[i] - currentVal);
                                if (diff < minDiff) { 
                                    minDiff = diff; 
                                    closestIdx = i; 
                                }
                            }
                            return closestIdx;
                        }

                        property real visualPct: currentIndex / (rates.length - 1)

                        onCurrentIndexChanged: { 
                            if (!sliderMa.pressed) visualPct = currentIndex / (rates.length - 1); 
                        }

                        Rectangle {
                            id: track
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: Design.s(-10)
                            height: Design.s(12)
                            radius: Design.s(6)
                            color: Design.sunken
                            border.color: Design.ground
                            border.width: 1
                            
                            Rectangle { 
                                width: Math.max(knob.width, knob.x + knob.width / 2)
                                height: parent.height
                                radius: parent.radius
                                color: window.selectedRateAccent
                                Behavior on color { ColorAnimation { duration: Design.duration.base } } 
                            }
                        }

                        Repeater {
                            model: sliderContainer.rates.length
                            Item {
                                x: (index / (sliderContainer.rates.length - 1)) * track.width
                                y: track.y + Design.s(20)
                                
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: sliderContainer.rates[index]
                                    font.weight: sliderContainer.currentIndex === index ? Design.weight.semibold : Design.weight.regular
                                    color: sliderContainer.currentIndex === index ? window.selectedRateAccent : Design.textFaint
                                    Behavior on color { ColorAnimation { duration: Design.duration.base } }
                                }
                            }
                        }

                        Rectangle {
                            id: knob
                            width: Design.s(24)
                            height: Design.s(24)
                            radius: Design.s(12)
                            color: sliderMa.containsPress ? window.selectedRateAccent : Design.text
                            anchors.verticalCenter: track.verticalCenter
                            x: (sliderContainer.visualPct * track.width) - width / 2
                            
                            Behavior on x { 
                                enabled: !sliderMa.pressed
                                NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutCubic } 
                            }
                            Behavior on color { ColorAnimation { duration: Design.duration.fast } }
                            
                            border.width: sliderMa.containsMouse ? 4 : 0
                            border.color: Qt.alpha(window.selectedRateAccent, 0.3)
                            Behavior on border.width { NumberAnimation { duration: Design.duration.fast } }
                        }

                        Clickable {
                            id: sliderMa
                            anchors.margins: Design.s(-15)
                            function updateSelection(mouseX, snapToGrid) {
                                if (monitorsModel.count === 0) return;
                                let pct = (mouseX - track.x) / track.width;
                                pct = Math.max(0, Math.min(1, pct));
                                let idx = Math.round(pct * (sliderContainer.rates.length - 1));
                                
                                if (snapToGrid) {
                                    sliderContainer.visualPct = idx / (sliderContainer.rates.length - 1);
                                } else {
                                    sliderContainer.visualPct = pct;
                                }

                                monitorsModel.setProperty(window.activeEditIndex, "rate", sliderContainer.rates[idx].toString());
                                window.selectedRateAccent = sliderContainer.rateColors[idx];
                            }
                            onPressed: (mouse) => updateSelection(mouse.x, false)
                            onPositionChanged: (mouse) => { if (pressed) updateSelection(mouse.x, false) }
                            onReleased: (mouse) => updateSelection(mouse.x, true)
                            onCanceled: () => sliderContainer.visualPct = sliderContainer.currentIndex / (sliderContainer.rates.length - 1)
                        }
                    }

                    Item { Layout.fillHeight: true }
                    } // end display tab ColumnLayout

                    // --- BRIGHTNESS TAB CONTENT ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Design.s(10)
                        visible: window.activeTab === 1
                        opacity: window.activeTab === 1 ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Design.duration.fast } }

                        // Empty state
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: brightnessModel.count === 0
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Design.s(8)
                                Icon {
                                    role: "display"
                                    Layout.alignment: Qt.AlignHCenter
                                    color: Design.textFaint
                                    text: "󰃠"
                                }
                                Label {
                                    role: "caption"
                                    Layout.alignment: Qt.AlignHCenter
                                    color: Design.textFaint
                                    text: "No DDC brightness"
                                }
                            }
                        }

                        // Reload button row
                        RowLayout {
                            Layout.fillWidth: true
                            visible: brightnessModel.count > 0
                            spacing: Design.s(8)
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: Design.s(26)
                                height: Design.s(26)
                                radius: Design.s(13)
                                color: brightnessReloadMa.containsMouse ? Design.hover : Design.raised
                                border.color: brightnessReloadMa.containsMouse ? Design.warn : Design.active
                                border.width: 1
                                Icon {
                                    role: "body"
                                    anchors.centerIn: parent
                                    text: "󰑓"
                                }
                                Clickable {
                                    id: brightnessReloadMa
                                    onClicked: {
                                        if (!brightnessRefresher.running) brightnessRefresher.running = true;
                                    }
                                }
                            }
                        }

                        // Brightness sliders
                        Repeater {
                            model: brightnessModel
                            delegate: ColumnLayout {
                                id: brightnessRow
                                Layout.fillWidth: true
                                spacing: Design.s(6)

                                property bool dragging: false
                                readonly property string brightnessDeviceId: model.id

                                function sendBrightness(pct) {
                                    Quickshell.execDetached(["bash", window.brightnessScriptPath, "set", brightnessDeviceId, pct.toString()]);
                                }

                                                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Design.s(8)
                                    Icon {
                                        role: "body"
                                        color: Design.warn
                                        text: "󰍹"
                                    }
                                    Label {
                                        role: "caption"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.weight: Design.weight.semibold
                                        text: model.name
                                    }
                                    Label {
                                        Layout.preferredWidth: Design.s(38)
                                        horizontalAlignment: Text.AlignRight
                                        font.weight: Design.weight.semibold
                                        color: Design.warn
                                        text: model.brightness + "%"
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Design.s(22)

                                    value: model.brightness
                                    tone: Design.warn
                                    minimum: 1          // a monitor at 0 is just a black screen
                                    cornerRadius: Design.radius.pill

                                    onMoved: pct => {
                                        brightnessModel.setProperty(index, "brightness", pct);
                                        brightnessRow.sendBrightness(pct);
                                    }

                                    onActiveChanged: {
                                        brightnessRow.dragging = active;
                                        window.brightnessDragging = active;
                                        if (!active) brightnessCooldownTimer.restart();
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    } // end brightness tab ColumnLayout

                } // end rightSideContainer ColumnLayout
            }

            // ==========================================
            Item {
                id: applyButtonContainer
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Design.s(30)
                width: Design.s(170)
                height: Design.s(50)
                
                opacity: window.introProgress
                transform: Translate { y: window.uiYOffset }

                MultiEffect {
                    source: applyBtn
                    anchors.fill: applyBtn
                    shadowEnabled: true
                    shadowColor: window.selectedRateAccent
                    shadowBlur: window.applyHovered ? 1.2 : 0.6
                    shadowOpacity: window.applyHovered ? 0.6 : 0.2
                    shadowVerticalOffset: Design.s(4)
                    z: -1
                    Behavior on shadowBlur { NumberAnimation { duration: Design.duration.base } } 
                    Behavior on shadowOpacity { NumberAnimation { duration: Design.duration.base } } 
                    Behavior on shadowColor { ColorAnimation { duration: Design.duration.slow } }
                }

                Rectangle {
                    id: applyBtn
                    anchors.fill: parent
                    radius: Design.s(25)
                    
                    gradient: Gradient { 
                        orientation: Gradient.Horizontal
                        GradientStop { 
                            position: 0.0
                            color: window.selectedResAccent
                            Behavior on color { ColorAnimation { duration: Design.duration.slow } } 
                        } 
                        GradientStop { 
                            position: 1.0
                            color: window.selectedRateAccent
                            Behavior on color { ColorAnimation { duration: Design.duration.slow } } 
                        } 
                    }
                    
                    scale: window.applyPressed ? 0.94 : (window.applyHovered ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Design.duration.base; easing.type: Easing.OutBack } }

                    Rectangle {
                        id: flashRect
                        anchors.fill: parent
                        radius: Design.s(25)
                        color: Design.text
                        opacity: 0.0
                        PropertyAnimation on opacity { 
                            id: applyFlashAnim
                            to: 0.0
                            duration: Design.duration.slow
                            easing.type: Easing.OutExpo 
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Design.s(8)
                        
                        Icon {
                            role: "title"
                            color: Design.ground
                            text: "󰸵"
                        }
                        
                        Label {
                            font.weight: Design.weight.bold
                            color: Design.ground
                            text: monitorsModel.count > 1 ? "Apply All" : "Apply"
                        }
                    }
                }

                Clickable {
                    id: applyMa
                    z: 10
                    onEntered: window.applyHovered = true
                    onExited: window.applyHovered = false
                    onPressed: window.applyPressed = true
                    onReleased: window.applyPressed = false
                    onCanceled: window.applyPressed = false
                    onClicked: {
                        flashRect.opacity = 0.8; 
                        applyFlashAnim.start();

                        if (monitorsModel.count === 0) return;

                        if (monitorsModel.count === 1) {
                            let mon = monitorsModel.get(0);
                            let savedLayout = [{
                                name: mon.name,
                                resW: mon.resW,
                                resH: mon.resH,
                                rate: mon.rate,
                                sysScale: mon.sysScale,
                                x: 0,
                                y: 0
                            }];
                            Quickshell.execDetached(["notify-send", "Display Update", "Applied: " + mon.resW + "x" + mon.resH + " @ " + mon.rate + "Hz"]);
                            Quickshell.execDetached(["bash", window.monitorsScriptPath, "apply", JSON.stringify(savedLayout)]);
                        } else {
                            let rects = [];
                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let layoutW = Math.round(m.resW / m.sysScale);
                                let layoutH = Math.round(m.resH / m.sysScale);
                                let rawX = m.uiX / window.uiScale;
                                let rawY = m.uiY / window.uiScale;
                                rects.push({
                                    x: rawX, y: rawY, w: layoutW, h: layoutH, 
                                    resW: m.resW, resH: m.resH, name: m.name, 
                                    rate: m.rate, sysScale: m.sysScale
                                });
                            }
                            
                            // Tight Snap Pass: Close tiny floating gaps between ANY adjacent monitors
                            function getTightSnap(pX, pY, sX, sY, sW, sH, mW, mH, t) {
                                let cx = pX; let cy = pY;
                                if (Math.abs(cx - (sX - mW)) < t) cx = sX - mW;
                                else if (Math.abs(cx - (sX + sW)) < t) cx = sX + sW;
                                else if (Math.abs(cx - sX) < t) cx = sX;
                                else if (Math.abs(cx - (sX + sW - mW)) < t) cx = sX + sW - mW;
                                else if (Math.abs(cx - (sX + sW/2 - mW/2)) < t) cx = sX + sW/2 - mW/2;
                                
                                if (Math.abs(cy - (sY - mH)) < t) cy = sY - mH;
                                else if (Math.abs(cy - (sY + sH)) < t) cy = sY + sH;
                                else if (Math.abs(cy - sY) < t) cy = sY;
                                else if (Math.abs(cy - (sY + sH - mH)) < t) cy = sY + sH - mH;
                                else if (Math.abs(cy - (sY + sH/2 - mH/2)) < t) cy = sY + sH/2 - mH/2;
                                
                                return {x: cx, y: cy};
                            }

                            for (let i = 1; i < rects.length; i++) {
                                let bestX = rects[i].x;
                                let bestY = rects[i].y;
                                let bestDist = 999999;
                                for (let j = 0; j < i; j++) {
                                    let r0 = rects[j];
                                    let snapped = getTightSnap(
                                        rects[i].x, rects[i].y,
                                        r0.x, r0.y,
                                        r0.w, r0.h, rects[i].w, rects[i].h, 25
                                    );
                                    let dist = Math.hypot(rects[i].x - snapped.x, rects[i].y - snapped.y);
                                    if (dist < bestDist) {
                                        bestDist = dist;
                                        bestX = Math.round(snapped.x);
                                        bestY = Math.round(snapped.y);
                                    }
                                }
                                rects[i].x = bestX;
                                rects[i].y = bestY;
                            }

                            // CORE SWAY FIX: Find absolute bounding box minimums to force a 0x0 anchor
                            let finalMinX = 999999;
                            let finalMinY = 999999;
                            for (let i = 0; i < rects.length; i++) {
                                if (rects[i].x < finalMinX) finalMinX = rects[i].x;
                                if (rects[i].y < finalMinY) finalMinY = rects[i].y;
                            }
                            
                            let summaryString = "";
                            for (let i = 0; i < rects.length; i++) {
                                let r = rects[i];
                                
                                // CORE SWAY FIX: Subtract the minimum so the entire layout grid starts at exactly 0x0.
                                r.x = Math.round(r.x - finalMinX);
                                r.y = Math.round(r.y - finalMinY);
                                
                                summaryString += r.name + " ";
                            }
                            
                            let saveLayout = rects.map(function(r) {
                                return {
                                    name: r.name,
                                    resW: r.resW,
                                    resH: r.resH,
                                    rate: r.rate,
                                    sysScale: r.sysScale,
                                    x: r.x,
                                    y: r.y
                                };
                            });
                            
                            Quickshell.execDetached(["bash", window.monitorsScriptPath, "apply", JSON.stringify(saveLayout)]);
                            Quickshell.execDetached(["notify-send", "Display Update", "Applied layout for: " + summaryString]);
                        }
                    }
                }
            }
        }
    }
}
