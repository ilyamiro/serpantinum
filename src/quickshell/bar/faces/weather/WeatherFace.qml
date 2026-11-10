import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"
import "../../../notifications/weather"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property string weatherTemp: {
        if (!isVertical) return Weather.currentTempFormatted;
        let raw = Weather.currentTemp !== "" ? Weather.currentTemp : Weather.currentTempFormatted;
        if (!raw || raw === "") return "--°";
        let intPart = raw.split(".")[0].replace(/[^\d-]/g, "");
        return (intPart !== "" ? intPart : "--") + "°";
    }
    property bool isWeatherLoading: Weather.isLoading || !Weather.isReady

    property real lengthPadding: isVertical ? (barWindow ? barWindow.cs(isCompact ? 10 : 12) : (isCompact ? 10 : 12)) : (barWindow ? barWindow.cs(isCompact ? 12 : 14) : (isCompact ? 12 : 14))
    property real targetLength: (isVertical ? weatherLayout.implicitHeight : weatherLayout.implicitWidth) + (lengthPadding * 2)

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "calendar"]);
            }
        }
    }

    Item {
        id: topArea
        anchors.fill: parent

        AxisFlow {
            id: weatherLayout
            vertical: root.isVertical
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            anchors.centerIn: parent
            spacing: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 2 : 3) : (root.isCompact ? 2 : 3)) : (barWindow ? barWindow.cs(root.isCompact ? 6 : 8) : (root.isCompact ? 6 : 8))

            LoaderIcon {
                id: weatherLoader
                width: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 18 : 20) : (root.isCompact ? 18 : 20)) : (barWindow ? barWindow.cs(root.isCompact ? 20 : 22) : (root.isCompact ? 20 : 22))
                height: width
                accentColor: ThemeBackend.mauve
                running: root.isWeatherLoading
                visible: root.isWeatherLoading
            }

            WeatherIcon {
                width: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 20 : 22) : (root.isCompact ? 20 : 22)) : (barWindow ? barWindow.cs(root.isCompact ? 22 : 24) : (root.isCompact ? 22 : 24))
                height: width
                code: Weather.currentCode
                isDay: Weather.currentIsDay
                visible: !root.isWeatherLoading && Weather.currentCode >= 0
            }

            Text {
                text: root.weatherTemp
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.isVertical ? (barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)) : (barWindow ? barWindow.cs(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15))
                font.weight: Font.Black
                color: root.isCompact ? Qt.lighter(ThemeBackend.peach, 1.1) : ThemeBackend.peach
                visible: !root.isWeatherLoading
            }
        }
    }
}
