import QtQuick
import QtQuick.Window
import Quickshell
import "../Services"

// =============================================================================
// The frame every popup repeats by hand.
//
// Absorbs the boilerplate that opens all eleven popup files today: the Scaler
// instance, the MatugenColors instance and its colour re-exports, the scriptDir
// / mainQmlPath dance, the execDetached close call, the Escape handler, and the
// outer rounded Rectangle.
//
//   PopupShell {
//       ColumnLayout { anchors.fill: parent; spacing: Design.s(Design.space.xl) }
//   }
// =============================================================================

Item {
    id: root
    focus: true

    // Children land inside the padded frame, not on top of the border.
    default property alias content: body.data

    // A page inside the Control Center has no chrome of its own — the Center
    // owns the window. Lets the four popups be reused as pages unchanged.
    property bool framed: true

    property int padding: Design.space.xl
    property color background: Design.surface
    property color borderColor: Design.line
    property int cornerRadius: Design.radius.panel

    readonly property string scriptDir: Quickshell.env("QS_SCRIPT_DIR")
        || (Quickshell.env("HOME") + "/.config/sway/scripts")

    // Design carries a global scale and cannot read the screen itself — it is a
    // singleton with no visual parent. Every popup lives inside one of these,
    // so this is the one place that always knows.
    Component.onCompleted: Design.screenWidth = Screen.width
    Binding { target: Design; property: "uiScale"; value: Settings.uiScale }
    Connections {
        target: Screen
        function onWidthChanged() { Design.screenWidth = Screen.width }
    }

    // Every popup rebuilt this call with its own path juggling.
    function close() {
        Quickshell.execDetached(["qs", "-p", root.scriptDir + "/quickshell/Main.qml", "ipc", "call", "main", "close"]);
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.framed ? Design.s(root.cornerRadius) : 0
        color: root.framed ? root.background : "transparent"
        border.color: root.framed ? root.borderColor : "transparent"
        border.width: root.framed ? Design.border : 0
        clip: true

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: root.framed ? Design.s(root.padding) : 0
        }
    }
}
