import QtQuick

// =============================================================================
// A nerd-font glyph, on the same size scale as Label.
//
// Separate from Label only because the family differs — but that difference is
// exactly what kept breaking: 120 call sites asked for "Iosevka Nerd Font",
// which the installer never ships. One token, one place to be wrong.
//
//   Icon { text: "󰕾"; role: "subhead"; color: Design.accent }
// =============================================================================

Text {
    id: root

    property string role: "subhead"

    readonly property int _size: {
        switch (root.role) {
        case "caption": return Design.font.caption;
        case "body":    return Design.font.body;
        case "title":   return Design.font.title;
        case "display": return Design.font.display;
        default:        return Design.font.subhead;
        }
    }

    font.family: Design.font.icon
    font.pixelSize: Design.s(root._size)
    color: Design.text
    horizontalAlignment: Text.AlignHCenter
}
