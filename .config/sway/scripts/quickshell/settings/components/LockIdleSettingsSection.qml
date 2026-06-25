import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property int dimTimeout: 300
    property int lockTimeout: 600
    property int dpmsTimeout: 900
    property int suspendTimeout: 1200
    property bool dimOnLock: true
    property bool autoSuspend: false
    signal dimTimeoutChangedByUser(int value)
    signal lockTimeoutChangedByUser(int value)
    signal dpmsTimeoutChangedByUser(int value)
    signal suspendTimeoutChangedByUser(int value)
    signal dimOnLockChangedByUser(bool value)
    signal autoSuspendChangedByUser(bool value)

    title: "Lock & idle"
    subtitle: "Timeouts are in seconds"

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Design.s(12)
        rowSpacing: Design.s(10)

        Text { text: "Dim"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(11) }
        TextInput {
            text: section.dimTimeout.toString()
            color: Design.text
            font.family: Design.font.mono
            font.pixelSize: Design.s(12)
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.dimTimeoutChangedByUser(parseInt(text || "300"))
        }

        Text { text: "Lock"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(11) }
        TextInput {
            text: section.lockTimeout.toString()
            color: Design.text
            font.family: Design.font.mono
            font.pixelSize: Design.s(12)
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.lockTimeoutChangedByUser(parseInt(text || "600"))
        }

        Text { text: "DPMS"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(11) }
        TextInput {
            text: section.dpmsTimeout.toString()
            color: Design.text
            font.family: Design.font.mono
            font.pixelSize: Design.s(12)
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.dpmsTimeoutChangedByUser(parseInt(text || "900"))
        }

        Text { text: "Suspend"; color: Design.textDim; font.family: Design.font.mono; font.pixelSize: Design.s(11) }
        TextInput {
            text: section.suspendTimeout.toString()
            enabled: section.autoSuspend
            opacity: section.autoSuspend ? 1.0 : 0.4
            color: Design.text
            font.family: Design.font.mono
            font.pixelSize: Design.s(12)
            validator: IntValidator { bottom: 30; top: 86400 }
            onTextChanged: section.suspendTimeoutChangedByUser(parseInt(text || "1200"))
        }
    }

    Toggle {
        label: "Dim while locking"
        checked: section.dimOnLock
        onToggled: section.dimOnLockChangedByUser(!section.dimOnLock)
    }

    Toggle {
        label: "Auto suspend"
        checked: section.autoSuspend
        onToggled: section.autoSuspendChangedByUser(!section.autoSuspend)
    }
}
