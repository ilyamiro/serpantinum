import QtQuick

Item {
    id: icon

    property int code: -1
    property int isDay: 1

    implicitWidth: 24
    implicitHeight: 24
    visible: code >= 0

    WeatherIllustration {
        anchors.fill: parent
        kind: icon.code >= 0 ? "wmo_" + icon.code + (icon.isDay === 0 ? "_n" : "") : ""
        animate: false
        backdrop: false
        solidPrecip: true
    }
}
