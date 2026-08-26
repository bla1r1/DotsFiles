import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: infoBlock

    spacing: Config.infoBlockSpacing * Config.generalScale
    visible: Config.infoBlockDisplay

    property int contentAlignment: Config.infoBlockAlign === "right" ? Text.AlignRight : (Config.infoBlockAlign === "center" ? Text.AlignHCenter : Text.AlignLeft)
    property int layoutAlignment: Config.infoBlockAlign === "right" ? Qt.AlignRight : (Config.infoBlockAlign === "center" ? Qt.AlignHCenter : Qt.AlignLeft)

    Text {
        id: infoDate
        Layout.alignment: infoBlock.layoutAlignment
        visible: Config.infoBlockDateDisplay
        text: new Date().toLocaleString(Qt.locale(Config.dateLocale), Config.dateFormat)
        color: Config.infoBlockColor
        horizontalAlignment: infoBlock.contentAlignment
        font.family: Config.infoBlockFontFamily
        font.pixelSize: Config.infoBlockTitleFontSize * Config.generalScale
        font.weight: Config.infoBlockFontWeight

        Timer {
            interval: 60000
            repeat: true
            running: infoDate.visible
            onTriggered: infoDate.text = new Date().toLocaleString(Qt.locale(Config.dateLocale), Config.dateFormat)
        }
    }

    ColumnLayout {
        Layout.alignment: infoBlock.layoutAlignment
        visible: Config.infoBlockWeatherDisplay
        spacing: 1 * Config.generalScale

        Text {
            Layout.alignment: infoBlock.layoutAlignment
            text: Config.infoBlockWeatherLocation + " · °" + Config.infoBlockWeatherUnits
            color: Config.infoBlockColor
            horizontalAlignment: infoBlock.contentAlignment
            font.family: Config.infoBlockFontFamily
            font.pixelSize: Config.infoBlockFontSize * Config.generalScale
            font.weight: 700
        }

        Text {
            Layout.alignment: infoBlock.layoutAlignment
            text: Config.infoBlockWeatherText
            color: Config.infoBlockMutedColor
            opacity: 0.82
            horizontalAlignment: infoBlock.contentAlignment
            font.family: Config.infoBlockFontFamily
            font.pixelSize: Config.infoBlockFontSize * Config.generalScale
            font.weight: Config.infoBlockFontWeight
        }
    }
}
