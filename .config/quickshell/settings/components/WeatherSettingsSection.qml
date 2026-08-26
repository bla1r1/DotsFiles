import QtQuick
import "../../Ui"
import QtQuick.Layouts

Card {
    id: section

    property string apiKey: ""
    property string cityId: ""
    property string unit: "metric"
    signal apiKeyChangedByUser(string value)
    signal cityIdChangedByUser(string value)
    signal unitChangedByUser(string value)

    title: "Weather"
    subtitle: "Used by the bar widget and the weather popup. Keys are stored in your local settings file, never sent anywhere else."
    icon: "\u{f0590}"
    accentColor: Design.yellow

    // Was two bare TextInputs with their own font, size and colour, saving on
    // every keystroke — a half-typed key was written and then queried.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Design.s(Design.space.xs)

        Label { text: "OpenWeather API key"; role: "caption"; dim: true }

        Field {
            Layout.fillWidth: true
            text: section.apiKey
            echoMode: TextInput.Password
            placeholder: "32-character key from openweathermap.org"
            onCommitted: v => section.apiKeyChangedByUser(v)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Design.s(Design.space.xs)

        Label { text: "City ID"; role: "caption"; dim: true }

        Field {
            Layout.fillWidth: true
            text: section.cityId
            placeholder: "e.g. 703448 for Kyiv"
            onCommitted: v => section.cityIdChangedByUser(v)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Design.s(Design.space.xs)

        Label { text: "Units"; role: "caption"; dim: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.s(Design.space.sm)

            Repeater {
                model: [
                    { id: "metric", label: "Celsius" },
                    { id: "imperial", label: "Fahrenheit" }
                ]

                Pill {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.label
                    active: section.unit === modelData.id
                    onClicked: section.unitChangedByUser(modelData.id)
                }
            }
        }
    }
}
