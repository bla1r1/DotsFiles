import QtQuick

// =============================================================================
// MouseArea with the shell's defaults already set.
//
// 121 MouseAreas across the popups; 96 set hoverEnabled and 75 set the pointer
// cursor, always the same three lines. Everything MouseArea does still works —
// this only stops the three lines from being retyped.
//
//   Clickable { onClicked: window.close() }
// =============================================================================

MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
}
