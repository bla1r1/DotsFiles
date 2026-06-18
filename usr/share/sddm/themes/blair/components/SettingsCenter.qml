import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: settingsCenter

    signal close

    property int selectedSection: 0
    property int revision: 0
    property var sections: [
        {
            "title": "Appearance",
            "subtitle": "Theme, motion and background feel"
        },
        {
            "title": "Lock Screen",
            "subtitle": "Clock, message and lock-screen presentation"
        },
        {
            "title": "Login",
            "subtitle": "User selector and password area"
        },
        {
            "title": "Info & Weather",
            "subtitle": "Future home for status and weather modules"
        },
        {
            "title": "Displays",
            "subtitle": "Monitor targeting and layout behavior"
        },
        {
            "title": "Keyboard",
            "subtitle": "Keyboard layout and virtual keyboard behavior"
        },
        {
            "title": "Quick Menus",
            "subtitle": "Buttons that stay as fast popups"
        },
        {
            "title": "Power",
            "subtitle": "Power actions and their presentation"
        },
        {
            "title": "Advanced",
            "subtitle": "Persistence and configuration status"
        }
    ]

    function currentSection() {
        return sections[Math.max(0, Math.min(selectedSection, sections.length - 1))];
    }

    function boolValue(value) {
        return value ? "On" : "Off";
    }

    function visibleValue(value) {
        return value ? "Visible" : "Hidden";
    }

    function nextValue(current, values) {
        var index = values.indexOf(current);
        if (index < 0)
            return values[0];
        return values[(index + 1) % values.length];
    }

    function steppedValue(current, step, min, max) {
        var next = current + step;
        if (next > max)
            return min;
        return Math.round(next * 100) / 100;
    }

    function signedValue(value) {
        var rounded = Math.round(value * 100) / 100;
        return rounded > 0 ? "+" + rounded.toFixed(2) : rounded.toFixed(2);
    }

    function controlKind(row) {
        if (!row.action)
            return row.value === "Planned" ? "planned" : "readonly";
        if (["On", "Off", "Visible", "Hidden", "Shown", "Yes", "No"].indexOf(row.value) !== -1)
            return "toggle";
        return "cycle";
    }

    function controlLabel(row) {
        var kind = controlKind(row);
        if (kind === "planned")
            return "Soon";
        if (kind === "readonly")
            return row.value;
        if (kind === "toggle")
            return row.value;
        return row.value + "  >";
    }

    function controlOpacity(row, containsMouse) {
        if (!row.action)
            return 0.08;
        if (controlKind(row) === "toggle" && ["On", "Visible", "Shown", "Yes"].indexOf(row.value) !== -1)
            return containsMouse ? 0.34 : 0.26;
        return containsMouse ? 0.26 : 0.16;
    }

    function applyChange(callback) {
        callback();
        revision++;
    }

    function rowsFor(sectionIndex, currentRevision) {
        currentRevision;

        if (sectionIndex === 0) {
            return [
                {"label": "Animations", "value": boolValue(Config.enableAnimations), "hint": "Click to toggle transitions and motion", "action": function () { applyChange(function () { Config.enableAnimations = !Config.enableAnimations; }); }},
                {"label": "Background fill", "value": Config.backgroundFillMode, "hint": "Click to cycle fill, fit and stretch", "action": function () { applyChange(function () { Config.backgroundFillMode = nextValue(Config.backgroundFillMode, ["fill", "fit", "stretch"]); }); }},
                {"label": "Scale", "value": Config.generalScale.toFixed(2), "hint": "Read-only for now; this is safer as a file setting", "action": null}
            ];
        }

        if (sectionIndex === 1) {
            return [
                {"label": "Clock", "value": visibleValue(Config.clockDisplay), "hint": "Click to show or hide the lock-screen clock", "action": function () { applyChange(function () { Config.clockDisplay = !Config.clockDisplay; }); }},
                {"label": "Date", "value": visibleValue(Config.dateDisplay), "hint": "Click to show or hide the lock-screen date", "action": function () { applyChange(function () { Config.dateDisplay = !Config.dateDisplay; }); }},
                {"label": "Clock position", "value": Config.clockPosition, "hint": "Click to move the time block around the screen", "action": function () { applyChange(function () { Config.clockPosition = nextValue(Config.clockPosition, ["top-left", "top-center", "top-right", "center-left", "center", "center-right", "bottom-left", "bottom-center", "bottom-right"]); }); }},
                {"label": "Clock format", "value": Config.clockFormat, "hint": "Click to cycle common time formats", "action": function () { applyChange(function () { Config.clockFormat = nextValue(Config.clockFormat, ["hh:mm", "h:mm AP", "HH:mm:ss"]); }); }},
                {"label": "Message", "value": visibleValue(Config.lockMessageDisplay), "hint": "Click to show or hide the lock prompt", "action": function () { applyChange(function () { Config.lockMessageDisplay = !Config.lockMessageDisplay; }); }},
                {"label": "Message position", "value": Config.lockMessagePosition, "hint": "Click to move the lock prompt", "action": function () { applyChange(function () { Config.lockMessagePosition = nextValue(Config.lockMessagePosition, ["bottom-center", "bottom-right", "bottom-left", "top-center", "center"]); }); }},
                {"label": "Lock blur", "value": Config.lockScreenBlur.toString(), "hint": "Click to step lock-screen blur from 0 to 64", "action": function () { applyChange(function () { Config.lockScreenBlur = steppedValue(Config.lockScreenBlur, 8, 0, 64); }); }},
                {"label": "Lock brightness", "value": signedValue(Config.lockScreenBrightness), "hint": "Click to step brightness from -0.40 to +0.40", "action": function () { applyChange(function () { Config.lockScreenBrightness = steppedValue(Config.lockScreenBrightness, 0.10, -0.40, 0.40); }); }},
                {"label": "Lock saturation", "value": signedValue(Config.lockScreenSaturation), "hint": "Click to step saturation from -0.50 to +0.50", "action": function () { applyChange(function () { Config.lockScreenSaturation = steppedValue(Config.lockScreenSaturation, 0.25, -0.50, 0.50); }); }}
            ];
        }

        if (sectionIndex === 2) {
            return [
                {"label": "Login position", "value": Config.loginAreaPosition, "hint": "Click to cycle center, left and right", "action": function () { applyChange(function () { Config.loginAreaPosition = nextValue(Config.loginAreaPosition, ["center", "left", "right"]); }); }},
                {"label": "Avatar shape", "value": Config.avatarShape, "hint": "Click to switch circle and square avatars", "action": function () { applyChange(function () { Config.avatarShape = nextValue(Config.avatarShape, ["circle", "square"]); }); }},
                {"label": "Login button text", "value": Config.loginButtonShowTextIfNoPassword ? "Shown when useful" : "Icon only", "hint": "Click to change no-password button labeling", "action": function () { applyChange(function () { Config.loginButtonShowTextIfNoPassword = !Config.loginButtonShowTextIfNoPassword; }); }},
                {"label": "Hide extra login button", "value": boolValue(Config.loginButtonHideIfNotNeeded), "hint": "Click to hide the button when password login already submits", "action": function () { applyChange(function () { Config.loginButtonHideIfNotNeeded = !Config.loginButtonHideIfNotNeeded; }); }},
                {"label": "Login blur", "value": Config.loginScreenBlur.toString(), "hint": "Click to step login-screen blur from 0 to 64", "action": function () { applyChange(function () { Config.loginScreenBlur = steppedValue(Config.loginScreenBlur, 8, 0, 64); }); }},
                {"label": "Login brightness", "value": signedValue(Config.loginScreenBrightness), "hint": "Click to step brightness from -0.40 to +0.40", "action": function () { applyChange(function () { Config.loginScreenBrightness = steppedValue(Config.loginScreenBrightness, 0.10, -0.40, 0.40); }); }},
                {"label": "Login saturation", "value": signedValue(Config.loginScreenSaturation), "hint": "Click to step saturation from -0.50 to +0.50", "action": function () { applyChange(function () { Config.loginScreenSaturation = steppedValue(Config.loginScreenSaturation, 0.25, -0.50, 0.50); }); }}
            ];
        }

        if (sectionIndex === 3) {
            return [
                {"label": "Info block", "value": visibleValue(Config.infoBlockDisplay), "hint": "Click to show or hide the lock-screen info block", "action": function () { applyChange(function () { Config.infoBlockDisplay = !Config.infoBlockDisplay; }); }},
                {"label": "Date line", "value": visibleValue(Config.infoBlockDateDisplay), "hint": "Click to show or hide date inside the info block", "action": function () { applyChange(function () { Config.infoBlockDateDisplay = !Config.infoBlockDateDisplay; }); }},
                {"label": "Weather line", "value": visibleValue(Config.infoBlockWeatherDisplay), "hint": "Click to show or hide the weather placeholder", "action": function () { applyChange(function () { Config.infoBlockWeatherDisplay = !Config.infoBlockWeatherDisplay; }); }},
                {"label": "Weather units", "value": "°" + Config.infoBlockWeatherUnits, "hint": "Click to switch Celsius and Fahrenheit labels", "action": function () { applyChange(function () { Config.infoBlockWeatherUnits = nextValue(Config.infoBlockWeatherUnits, ["C", "F"]); }); }},
                {"label": "Block position", "value": Config.infoBlockPosition, "hint": "Click to move the info block around the lock screen", "action": function () { applyChange(function () { Config.infoBlockPosition = nextValue(Config.infoBlockPosition, ["center-right", "top-right", "bottom-right", "center-left", "top-left", "bottom-left", "bottom-center"]); }); }}
            ];
        }

        if (sectionIndex === 4) {
            return [
                {"label": "Target monitor", "value": Config.displayScreenTarget, "hint": "Click to switch between primary and explicit index", "action": function () { applyChange(function () { Config.displayScreenTarget = nextValue(Config.displayScreenTarget, ["primary", "index"]); }); }},
                {"label": "Monitor index", "value": Config.displayScreenIndex.toString(), "hint": "Click to cycle candidate monitor indexes 0-3", "action": function () { applyChange(function () { Config.displayScreenIndex = steppedValue(Config.displayScreenIndex, 1, 0, 3); }); }},
                {"label": "Panel placement", "value": Config.displayScreenTarget === "primary" ? "Primary screen" : "Screen " + Config.displayScreenIndex, "hint": "Runtime target for the whole SDDM frame", "action": null}
            ];
        }

        if (sectionIndex === 5) {
            return [
                {"label": "Layout button", "value": visibleValue(Config.layoutDisplay), "hint": "Click to show or hide the quick layout popup", "action": function () { applyChange(function () { Config.layoutDisplay = !Config.layoutDisplay; }); }},
                {"label": "Layout label", "value": Config.layoutDisplayLayoutName ? "Shown" : "Hidden", "hint": "Click to show or hide the current layout code", "action": function () { applyChange(function () { Config.layoutDisplayLayoutName = !Config.layoutDisplayLayoutName; }); }},
                {"label": "Virtual keyboard button", "value": visibleValue(Config.keyboardDisplay), "hint": "Click to show or hide the quick keyboard toggle", "action": function () { applyChange(function () { Config.keyboardDisplay = !Config.keyboardDisplay; }); }},
                {"label": "Virtual keyboard starts hidden", "value": Config.virtualKeyboardStartHidden ? "Yes" : "No", "hint": "Click to change the startup keyboard state for this run", "action": function () { applyChange(function () { Config.virtualKeyboardStartHidden = !Config.virtualKeyboardStartHidden; }); }}
            ];
        }

        if (sectionIndex === 6) {
            return [
                {"label": "Session menu", "value": visibleValue(Config.sessionDisplay), "hint": "Click to show or hide the quick session chooser", "action": function () { applyChange(function () { Config.sessionDisplay = !Config.sessionDisplay; }); }},
                {"label": "Layout menu", "value": visibleValue(Config.layoutDisplay), "hint": "Click to show or hide the quick layout chooser", "action": function () { applyChange(function () { Config.layoutDisplay = !Config.layoutDisplay; }); }},
                {"label": "Keyboard toggle", "value": visibleValue(Config.keyboardDisplay), "hint": "Click to show or hide the keyboard toggle", "action": function () { applyChange(function () { Config.keyboardDisplay = !Config.keyboardDisplay; }); }},
                {"label": "Power menu", "value": visibleValue(Config.powerDisplay), "hint": "Click to show or hide shutdown/reboot actions", "action": function () { applyChange(function () { Config.powerDisplay = !Config.powerDisplay; }); }}
            ];
        }

        if (sectionIndex === 7) {
            return [
                {"label": "Power button", "value": visibleValue(Config.powerDisplay), "hint": "Click to show or hide the power popup", "action": function () { applyChange(function () { Config.powerDisplay = !Config.powerDisplay; }); }},
                {"label": "Popup width", "value": Config.powerPopupWidth.toString(), "hint": "Read-only for now; the popup is measured at open time", "action": null},
                {"label": "Confirmation", "value": "Planned", "hint": "Optional safety prompt before shutdown", "action": null}
            ];
        }

        return [
            {"label": "Runtime preview", "value": "On", "hint": "Changes apply immediately to this SDDM theme run", "action": null},
            {"label": "Config writer", "value": "External", "hint": "Use tools/settings-tui or settingsctl to persist defaults", "action": null},
            {"label": "Weather provider", "value": "Planned", "hint": "The UI is ready; data source still needs to be connected", "action": null},
            {"label": "Display targeting", "value": "Runtime", "hint": "Primary/index targeting is available for preview", "action": null}
        ];
    }

    Rectangle {
        id: panelBackground
        anchors.fill: parent
        color: Config.settingsPanelBackgroundColor
        opacity: Config.settingsPanelBackgroundOpacity
        radius: Config.settingsPanelBorderRadius * Config.generalScale
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Config.settingsPanelBorderRadius * Config.generalScale
        border.color: Config.settingsPanelBorderColor
        border.width: Config.settingsPanelBorderSize * Config.generalScale
        opacity: Config.settingsPanelBorderOpacity
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.settingsPanelPadding * Config.generalScale
        spacing: 18 * Config.generalScale

        ColumnLayout {
            Layout.preferredWidth: 190 * Config.generalScale
            Layout.fillHeight: true
            spacing: 8 * Config.generalScale

            Text {
                text: "Settings"
                color: Config.settingsPanelContentColor
                font.family: Config.settingsPanelFontFamily
                font.pixelSize: Config.settingsPanelTitleFontSize * Config.generalScale
                font.weight: 800
            }

            Text {
                Layout.fillWidth: true
                text: "Central place for the theme controls."
                color: Config.settingsPanelMutedColor
                opacity: 0.82
                wrapMode: Text.Wrap
                font.family: Config.settingsPanelFontFamily
                font.pixelSize: Config.settingsPanelSmallFontSize * Config.generalScale
            }

            ColumnLayout {
                Layout.topMargin: 10 * Config.generalScale
                Layout.fillWidth: true
                spacing: 4 * Config.generalScale

                Repeater {
                    model: settingsCenter.sections

                    delegate: Rectangle {
                        id: sectionButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34 * Config.generalScale
                        radius: Config.settingsPanelBorderRadius * Config.generalScale
                        color: Config.settingsPanelActiveBackgroundColor
                        opacity: settingsCenter.selectedSection === index || sectionMouseArea.containsMouse ? Config.settingsPanelActiveBackgroundOpacity : 0.0

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10 * Config.generalScale
                                rightMargin: 10 * Config.generalScale
                            }
                            text: modelData.title
                            elide: Text.ElideRight
                            color: Config.settingsPanelContentColor
                            font.family: Config.settingsPanelFontFamily
                            font.pixelSize: Config.settingsPanelFontSize * Config.generalScale
                            font.weight: settingsCenter.selectedSection === index ? 700 : 500
                        }

                        MouseArea {
                            id: sectionMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsCenter.selectedSection = index
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.fillWidth: true
                text: "Runtime preview is active. Persistence comes from the config writer pass."
                color: Config.settingsPanelMutedColor
                opacity: 0.72
                wrapMode: Text.Wrap
                font.family: Config.settingsPanelFontFamily
                font.pixelSize: Config.settingsPanelSmallFontSize * Config.generalScale
            }
        }

        Rectangle {
            Layout.preferredWidth: Math.max(1, Config.settingsPanelBorderSize) * Config.generalScale
            Layout.fillHeight: true
            color: Config.settingsPanelBorderColor
            opacity: Config.settingsPanelBorderOpacity
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12 * Config.generalScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * Config.generalScale

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3 * Config.generalScale

                    Text {
                        Layout.fillWidth: true
                        text: settingsCenter.currentSection().title
                        color: Config.settingsPanelContentColor
                        elide: Text.ElideRight
                        font.family: Config.settingsPanelFontFamily
                        font.pixelSize: Config.settingsPanelTitleFontSize * Config.generalScale
                        font.weight: 800
                    }

                    Text {
                        Layout.fillWidth: true
                        text: settingsCenter.currentSection().subtitle
                        color: Config.settingsPanelMutedColor
                        opacity: 0.82
                        elide: Text.ElideRight
                        font.family: Config.settingsPanelFontFamily
                        font.pixelSize: Config.settingsPanelSmallFontSize * Config.generalScale
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 30 * Config.generalScale
                    Layout.preferredHeight: 30 * Config.generalScale
                    radius: Config.settingsPanelBorderRadius * Config.generalScale
                    color: Config.settingsPanelActiveBackgroundColor
                    opacity: closeMouseArea.containsMouse ? Config.settingsPanelActiveBackgroundOpacity : 0.0

                    Text {
                        anchors.centerIn: parent
                        text: "x"
                        color: Config.settingsPanelContentColor
                        font.family: Config.settingsPanelFontFamily
                        font.pixelSize: Config.settingsPanelFontSize * Config.generalScale
                        font.weight: 700
                    }

                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsCenter.close()
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 8 * Config.generalScale

                    Repeater {
                        model: settingsCenter.rowsFor(settingsCenter.selectedSection, settingsCenter.revision)

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58 * Config.generalScale
                            radius: Config.settingsPanelBorderRadius * Config.generalScale
                            color: Config.settingsPanelActiveBackgroundColor
                            opacity: rowMouseArea.containsMouse ? Config.settingsPanelActiveBackgroundOpacity : 0.08

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * Config.generalScale
                                anchors.rightMargin: 12 * Config.generalScale
                                spacing: 12 * Config.generalScale

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3 * Config.generalScale

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: Config.settingsPanelContentColor
                                        elide: Text.ElideRight
                                        font.family: Config.settingsPanelFontFamily
                                        font.pixelSize: Config.settingsPanelFontSize * Config.generalScale
                                        font.weight: 700
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.hint
                                        color: Config.settingsPanelMutedColor
                                        opacity: 0.78
                                        elide: Text.ElideRight
                                        font.family: Config.settingsPanelFontFamily
                                        font.pixelSize: Config.settingsPanelSmallFontSize * Config.generalScale
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 142 * Config.generalScale
                                    Layout.preferredHeight: 30 * Config.generalScale
                                    radius: Config.settingsPanelBorderRadius * Config.generalScale
                                    color: Config.settingsPanelActiveBackgroundColor
                                    opacity: settingsCenter.controlOpacity(modelData, rowMouseArea.containsMouse)
                                    border.width: modelData.action ? 0 : Math.max(1, Config.settingsPanelBorderSize) * Config.generalScale
                                    border.color: Config.settingsPanelBorderColor

                                    Text {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 10 * Config.generalScale
                                            rightMargin: 10 * Config.generalScale
                                        }
                                        text: settingsCenter.controlLabel(modelData)
                                        color: modelData.action ? Config.settingsPanelContentColor : Config.settingsPanelMutedColor
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        font.family: Config.settingsPanelFontFamily
                                        font.pixelSize: Config.settingsPanelFontSize * Config.generalScale
                                        font.weight: modelData.action ? 700 : 500
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: modelData.action ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (modelData.action)
                                        modelData.action();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
