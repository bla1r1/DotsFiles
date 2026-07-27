import QtQuick

// =============================================================================
// The small uppercase mono caption above a list — "OUTPUT DEVICES".
//
// Written out four times in the Control Center, each repeating the same four
// properties, and each free to disagree about the letter spacing.
// =============================================================================

Label {
    role: "caption"
    isMono: true
    weight: Design.weight.bold
    dim: true
    font.letterSpacing: 0.6
    font.capitalization: Font.AllUppercase
}
