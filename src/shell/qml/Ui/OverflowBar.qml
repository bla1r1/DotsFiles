import QtQuick
import QtQuick.Controls

// =============================================================================
// The scrollbar a scrolling surface needs, and half of them forgot.
//
// A list or grid that overflows with no bar shows a card sliced off by the
// panel edge and nothing at all saying there is more below. That does not read
// as "scroll me", it reads as a rendering fault — and four surfaces had exactly
// it: the Control Center, the Launchpad grid, the clipboard list and the media
// popup, each with its own inline bar or none.
//
// Visible for as long as anything is below the fold, rather than fading out
// when idle, because being seen is the entire job.
//
//   ListView   { ScrollBar.vertical: OverflowBar {} }
//   Flickable  { ScrollBar.vertical: OverflowBar {} }
// =============================================================================

ScrollBar {
    id: root

    active: true

    // `size` is the fraction of the content currently on screen, so anything
    // below 1 means there is more of it. Works the same for a ListView, a
    // GridView and a bare Flickable, and needs nothing measured by hand.
    policy: (root.size > 0 && root.size < 1) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

    // 4px of a light outline colour, not 3px of a mid grey at 0.6 alpha:
    // measured against the panel that drew #394E62 on #0A3B4C, a difference
    // nobody notices — which is the same as not being there, for a control
    // whose only job is to be noticed.
    contentItem: Rectangle {
        implicitWidth: Design.s(4)
        radius: width / 2
        color: Design.textFaint
        opacity: 0.8
    }
}
