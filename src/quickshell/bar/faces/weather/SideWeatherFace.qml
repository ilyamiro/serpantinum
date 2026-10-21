import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property string weatherIcon: Weather.currentIcon
    property string weatherTemp: {
        let raw = Weather.currentTemp !== "" ? Weather.currentTemp : Weather.currentTempFormatted;
        if (!raw || raw === "") return "--°";
        let intPart = raw.split(".")[0].replace(/[^\d-]/g, "");
        return (intPart !== "" ? intPart : "--") + "°";
    }
    property string weatherHex: Weather.currentHex
    property bool isWeatherLoading: Weather.isLoading || !Weather.isReady

    property real verticalPadding: barWindow ? barWindow.s(isCompact ? 10 : 12) : (isCompact ? 10 : 12)
    property real targetHeight: weatherCol.implicitHeight + (verticalPadding * 2)

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

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

        Column {
            id: weatherCol
            anchors.centerIn: parent
            spacing: barWindow ? barWindow.s(root.isCompact ? 2 : 3) : (root.isCompact ? 2 : 3)

            LoaderIcon {
                id: weatherLoader
                anchors.horizontalCenter: parent.horizontalCenter
                width: barWindow ? barWindow.s(root.isCompact ? 18 : 20) : (root.isCompact ? 18 : 20)
                height: barWindow ? barWindow.s(root.isCompact ? 18 : 20) : (root.isCompact ? 18 : 20)
                accentColor: ThemeBackend.mauve
                running: root.isWeatherLoading
                visible: root.isWeatherLoading
            }

            Text {
                text: root.weatherIcon
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: "Iosevka Nerd Font"
                font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 16 : 18) : (root.isCompact ? 16 : 18)
                color: Qt.tint(root.weatherHex, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, root.isCompact ? 0.3 : 0.4))
                visible: !root.isWeatherLoading && root.weatherIcon !== ""
            }

            Text {
                text: root.weatherTemp
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: "Monocraft"
                font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
                font.weight: Font.Black
                color: root.isCompact ? Qt.lighter(ThemeBackend.peach, 1.1) : ThemeBackend.peach
                visible: !root.isWeatherLoading
            }
        }
    }
}
