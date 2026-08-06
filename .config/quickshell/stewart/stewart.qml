import QtQuick
import QtQuick.Effects
import "../Ui"

PopupShell {
    id: root

    // Durations that are choreography, not styling: a staged entrance, ambient
    // loops and slow tint crossfades. Deliberately off the motion scale.
    // PauseAnimation delays are left as they are — that spread is the stagger.
    readonly property int introDuration: 800
    readonly property int tintDuration: 1000
    readonly property int pulsePeriod: 1500
    readonly property int driftPeriod: 90000


    
    readonly property color mauve: Design.mauve
    readonly property color pink: Design.pink
    readonly property color blue: Design.blue
    readonly property color sapphire: Design.sapphire

    // Master Container
    Rectangle {
        id: windowContent
        anchors.fill: parent
        radius: 12
        color: Design.surface 
        clip: true

        // ---------------------------------------------------------------------
        // GLOBAL THEME & STATE CONTROLS
        // ---------------------------------------------------------------------
        
        // 5. Slow Color Temperature Drift (Fixed for Live Theme Reloading)
        property real baseBlend: 0.0
        property color currentBasePurple: Design.accentAlt
        property real accentBlend: 0.0
        property color currentAccentLavender: Design.accent

        // Animation States
        property real calmState: 0.0 
        property real popShockwave: 0.0 
        property real time: 0
        property real breathA: 0.5
        property real breathB: 0.5
        property real breathC: 0.5

        // Window Entrance Animation
        opacity: 0.0
        scale: 0.98
        
        Component.onCompleted: entranceAnimation.start()
        
        ParallelAnimation {
            id: entranceAnimation
            NumberAnimation { target: windowContent; property: "opacity"; to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: windowContent; property: "scale"; to: 1.0; duration: Design.duration.slow; easing.type: Easing.OutCubic }
        }

        property real globalOrbitAngle: 0

        // ---------------------------------------------------------------------
        // BACKGROUND ARTIFACTS
        // ---------------------------------------------------------------------

        // 1. Large Flowing Background Orb A
        Rectangle {
            id: backgroundOrbA
            width: parent.width * 0.8
            height: width
            radius: width / 2
            anchors.centerIn: parent
            opacity: 0.03
            color: windowContent.currentBasePurple
        }

        // 2. Large Flowing Background Orb B
        Rectangle {
            id: backgroundOrbB
            width: parent.width * 0.9
            height: width
            radius: width / 2
            anchors.centerIn: parent
            opacity: 0.02
            color: windowContent.currentAccentLavender
        }

        // 3. Gravitational Floating Particles (Improved Naturalism)
        Repeater {
            model: 20 
            
            Rectangle {
                id: particle
                property real randomPhase: index * 0.47
                property real baseX: (index * 113) % root.width
                property real baseY: (index * 137) % root.height
                
                property real vecX: (root.width / 2) - baseX
                property real vecY: (root.height / 2) - baseY
                
                width: (index % 4) + 3
                height: width
                radius: width / 2
                
                // 4. Improve Particle Naturalism (Elliptical drift instead of vertical bounce)
                // 1. Parallax addition
                x: baseX + Math.cos(windowContent.time * 4 + randomPhase) * 15 * windowContent.calmState + (worldCenter.driftX * 0.8) - (vecX * 0.04 * windowContent.popShockwave)
                y: baseY + Math.sin(windowContent.time * 3 + randomPhase) * 15 * windowContent.calmState + (worldCenter.driftY * 0.8) - (vecY * 0.04 * windowContent.popShockwave)
                
                color: index % 3 === 0 ? windowContent.currentAccentLavender : windowContent.currentBasePurple
                
                opacity: ((index % 3) * 0.1 + 0.1) + (windowContent.popShockwave * 0.2)
                antialiasing: true

                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: (index % 3) * 3 + 2; blur: 1.0 }
            }
        }

        // ---------------------------------------------------------------------
        // THE ASSISTANT CORE
        // ---------------------------------------------------------------------
        
        // Premium Glow Aura
        Item {
            id: orbGlow
            anchors.centerIn: parent
            width: 150
            height: 150
            
            property real baseOpacity: 0.0
            property real baseScale: 0.8
            
            // 9. Offset breathing A
            // 6. Energy Shift (Lowers glow mildly in calm state)
            opacity: baseOpacity * (1.0 - (windowContent.calmState * 0.2)) * (0.8 + (windowContent.breathA * 0.2))
            scale: baseScale + (windowContent.breathA * 0.03)

            Repeater {
                model: 2 
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + (index * 40) + 20
                    height: width
                    radius: width / 2
                    color: windowContent.currentBasePurple 
                    opacity: index === 0 ? 0.12 : 0.05
                    antialiasing: true
                }
            }
        }

        // Redesigned Diffuse Shockwave Fade 
        Rectangle {
            id: diffuseShockwave
            anchors.centerIn: parent
            width: 150
            height: 150
            radius: width / 2
            color: windowContent.currentAccentLavender
            opacity: windowContent.popShockwave * 0.12 
            scale: 1.0 + (windowContent.popShockwave * 0.8) 
            antialiasing: true
        }

        // Center Wrapper
        Item {
            id: worldCenter
            width: 150
            height: 150
            
            property real driftX: 0
            property real driftY: 0
            
            SequentialAnimation on driftX {
                loops: Animation.Infinite
                NumberAnimation { to: 2; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                NumberAnimation { to: -1.5; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on driftY {
                loops: Animation.Infinite
                NumberAnimation { to: 1.5; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                NumberAnimation { to: -2; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
            }

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: driftX
            anchors.verticalCenterOffset: driftY
            
            // 10. Ultra-Subtle Idle Micro Drift
            rotation: windowContent.calmState * Math.sin(windowContent.time * 2) * 2.0

            Item {
                id: orb
                anchors.fill: parent

                // 1. Loading Shell
                Rectangle {
                    id: loadingShell
                    anchors.fill: parent
                    radius: width / 2
                    antialiasing: true
                    opacity: 1.0
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Design.active }
                        GradientStop { position: 1.0; color: Design.raised }
                    }
                }

                // 2. Activated Energy Core
                Item {
                    id: activeEnergyCore
                    anchors.fill: parent
                    opacity: 0.0
                    
                    // 9. Offset breathing B
                    scale: 1.0 + (windowContent.breathB * 0.015)

                    // Layer A: Oscillating Base Gradient
                    Rectangle {
                        id: fluidGradientLayer
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        
                        property real oscRotation: 0
                        SequentialAnimation on oscRotation {
                            loops: Animation.Infinite
                            NumberAnimation { to: 15; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -15; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                        }
                        rotation: oscRotation

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { 
                                position: 0.0 
                                color: windowContent.currentBasePurple 
                                SequentialAnimation on position {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.0; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                                }
                            }
                            GradientStop { 
                                position: 1.0 
                                color: windowContent.currentAccentLavender 
                                SequentialAnimation on position {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.8; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    // 2. Micro Inner Pulse to Core (Circulating core energy, not scaling)
                    Item {
                        anchors.fill: parent
                        opacity: 0.3 + (windowContent.breathB * 0.2)
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: width
                            radius: width / 2
                            color: windowContent.currentAccentLavender
                            opacity: 0.4
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                        }
                    }

                    // Layer B: Subtle transparent mask oscillating opposite
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        opacity: 0.8
                        
                        property real maskRotation: 0
                        SequentialAnimation on maskRotation {
                            loops: Animation.Infinite
                            NumberAnimation { to: -20; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 20; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                        }
                        rotation: maskRotation

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.4; color: windowContent.currentAccentLavender } 
                            GradientStop { position: 0.6; color: windowContent.currentAccentLavender } 
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // 7. Subtle Orb Surface Noise (Simulated via rotating organic low-opacity elements)
                    Item {
                        anchors.fill: parent
                        opacity: 0.03
                        clip: true
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 2; blur: 1.0 }
                        Repeater {
                            model: 24
                            Rectangle {
                                property real angle: index * 15
                                property real dist: (index * 4) % (parent.width / 2.2)
                                x: (parent.width / 2) + Math.cos(angle) * dist - width/2
                                y: (parent.height / 2) + Math.sin(angle) * dist - height/2
                                width: (index % 3) + 2
                                height: width
                                radius: width/2
                                color: Design.text
                                rotation: windowContent.time * 20 * (index % 2 === 0 ? 1 : -1)
                            }
                        }
                    }

                    // 4. Subtle Light Refraction Sweep
                    Rectangle {
                        id: refractionLayer
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        rotation: 25
                        color: "transparent"
                        
                        // 6. Density Shift (Diminish refraction sweeps slightly on idle)
                        opacity: 1.0 - (windowContent.calmState * 0.2)
                        
                        property real sweepPos: 0.0
                        
                        SequentialAnimation on sweepPos {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation { from: -0.5; to: 1.5; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: root.introDuration } 
                        }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: Math.max(0.0, Math.min(1.0, refractionLayer.sweepPos - 0.2)); color: "transparent" }
                            GradientStop { position: Math.max(0.0, Math.min(1.0, refractionLayer.sweepPos)); color: Qt.alpha(Design.text, 0.08) }
                            GradientStop { position: Math.max(0.0, Math.min(1.0, refractionLayer.sweepPos + 0.2)); color: "transparent" }
                        }
                    }

                    // 3. Soft Ambient Edge Lighting (Inner rim light via blurred border trick)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1 // Keep inside bounds
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(Design.text.r, Design.text.g, Design.text.b, 0.15 + windowContent.breathA * 0.1)
                        antialiasing: true
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 4; blur: 1.0 }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // MASTER CINEMATIC SEQUENCE
        // ---------------------------------------------------------------------
        SequentialAnimation {
            id: introSequence
            running: true

            PauseAnimation { duration: Design.duration.base } 

            // Phase 1: Loading Wind-Up
            NumberAnimation {
                target: loadingShell
                property: "rotation"
                from: 0
                to: 360 
                duration: root.introDuration 
                easing.type: Easing.InCubic
            }

            // Phase 2: Anticipation Contraction
            NumberAnimation { 
                target: orb; 
                property: "scale"; 
                to: 0.96; 
                duration: Design.duration.base; 
                easing.type: Easing.InOutSine 
            }
            
            PauseAnimation { duration: Design.duration.fast }

            // Phase 3: The Transformation Pop
            ParallelAnimation {
                NumberAnimation { target: loadingShell; property: "opacity"; to: 0.0; duration: Design.duration.fast }
                NumberAnimation { target: activeEnergyCore; property: "opacity"; to: 1.0; duration: Design.duration.base }

                SequentialAnimation {
                    NumberAnimation { target: orb; property: "scale"; to: 1.05; duration: Design.duration.base; easing.type: Easing.OutCubic }
                    NumberAnimation { target: orb; property: "scale"; to: 1.0; duration: root.pulsePeriod; easing.type: Easing.InOutSine }
                }
                
                // 8. Refine Shockwave Dissipation (Asymmetrical decay: Fast rise, slow lingering fade)
                SequentialAnimation {
                    NumberAnimation { target: windowContent; property: "popShockwave"; from: 0.0; to: 1.0; duration: Design.duration.fast; easing.type: Easing.OutCubic }
                    NumberAnimation { target: windowContent; property: "popShockwave"; to: 0.0; duration: root.introDuration; easing.type: Easing.OutQuart } 
                }

                NumberAnimation { target: orbGlow; property: "baseOpacity"; to: 1.0; duration: Design.duration.slow; easing.type: Easing.InOutSine }
                NumberAnimation { target: orbGlow; property: "baseScale"; to: 1.0; duration: root.introDuration; easing.type: Easing.OutBack }
            }

            // Phase 4: Settle into Calm Idle State
            NumberAnimation {
                target: windowContent
                property: "calmState"
                from: 0.0
                to: 1.0
                duration: root.pulsePeriod
                easing.type: Easing.InOutSine
            }
        }
    }
}
