import QtQuick
import QtQuick.Layouts

Item {
    id: card

    required property var greeter
    required property var weather
    readonly property bool fresh: weather.fetched > 0 && greeter.time.getTime() / 1000 - weather.fetched < 10800
    readonly property var hours: fresh && width >= 280 && height >= 120 ? weather.hourly ?? [] : []

    component Label: Text {
        color: card.greeter.foreground
        font.family: card.greeter.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    text: card.fresh ? card.weather.icon || "󰖐" : "󰖐"
                    color: card.fresh ? card.weather.color || card.greeter.accent : card.greeter.subtle
                    font.family: card.greeter.palette.iconFont
                    font.pixelSize: Math.min(35, card.width / 9)
                }
                Label {
                    Layout.fillWidth: true
                    text: card.fresh ? card.weather.temp || "—" : "—"
                    font.pixelSize: Math.min(36, card.width / 8)
                    font.weight: Font.DemiBold
                }
            }
            Label {
                Layout.fillWidth: true
                text: card.weather.city || card.greeter.trLabel("Weather", "Погода")
                font.weight: Font.Medium
            }
            Label {
                Layout.fillWidth: true
                visible: card.fresh && !!card.weather.feelsLike && card.height >= 95
                text: card.greeter.trLabel("Feels like", "Ощущается как") + " " + (card.weather.feelsLike || "")
                color: card.greeter.subtle
                font.pixelSize: 11
            }
        }

        GridLayout {
            columns: 2
            visible: card.hours.length > 0
            columnSpacing: 4
            rowSpacing: 4
            Repeater {
                model: card.hours
                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: Math.min(70, card.width * 0.19)
                    Layout.preferredHeight: Math.min(60, card.height * 0.40)
                    radius: Math.max(4, card.greeter.corner - 2)
                    color: Qt.alpha(card.greeter.fieldColor, 0.75)
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.time; font.pixelSize: 10 }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon || "󰖐"
                            font.family: card.greeter.palette.iconFont
                            color: modelData.color || card.greeter.accent
                            font.pixelSize: 15
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
}
