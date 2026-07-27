import QtQuick

// =============================================================================
// Text on the type scale.
//
// The single biggest duplication in the shell: 374 of 419 Text blocks repeat
// the same family + pixelSize + colour triplet by hand. Four lines each.
//
//   Label { text: "Microphone" }                      // mono, body, text
//   Label { text: "82%"; role: "caption"; dim: true }
//   Label { text: "Displays"; role: "title"; weight: Design.weight.semibold }
//
// Extends Text, so wrapMode / elide / Layout.* all still work.
// =============================================================================

Text {
    id: root

    // caption | body | subhead | title | display
    property string role: "body"

    // Shortcut for the most common colour choice after `text` itself.
    property bool dim: false

    readonly property int _size: {
        switch (root.role) {
        case "caption": return Design.font.caption;
        case "subhead": return Design.font.subhead;
        case "title":   return Design.font.title;
        case "display": return Design.font.display;
        default:        return Design.font.body;
        }
    }

    // isMono: false uses Fira Sans for clean, modern UI; true uses JetBrainsMono Nerd Font for numbers/stats/code
    property bool isMono: false

    property int weight: Design.weight.regular

    font.weight: root.weight
    font.family: root.isMono ? Design.font.mono : Design.font.sans
    font.pixelSize: Design.s(root._size)
    color: root.dim ? Design.textDim : Design.text
}
