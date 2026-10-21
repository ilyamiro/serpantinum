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
    property string weatherTemp: Weather.currentTempFormatted
    property string weatherHex: Weather.currentHex
    property bool isWeatherLoading: Weather.isLoading || !Weather.isReady

    property real horizontalPadding: barWindow ? barWindow.s(isCompact ? 12 : 14) : (isCompact ? 12 : 14)
    property real targetWidth: weatherRow.implicitWidth + (horizontalPadding * 2)

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

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

        Row {
            id: weatherRow
            anchors.centerIn: parent
            spacing: barWindow ? barWindow.s(root.isCompact ? 6 : 8) : (root.isCompact ? 6 : 8)

            LoaderIcon {
                id: weatherLoader
                anchors.verticalCenter: parent.verticalCenter
                width: barWindow ? barWindow.s(root.isCompact ? 20 : 22) : (root.isCompact ? 20 : 22)
                height: barWindow ? barWindow.s(root.isCompact ? 20 : 22) : (root.isCompact ? 20 : 22)
                accentColor: ThemeBackend.mauve
                running: root.isWeatherLoading
                visible: root.isWeatherLoading
            }

            Text {
                text: root.weatherIcon
                anchors.verticalCenter: parent.verticalCenter
                font.family: "Iosevka Nerd Font"
                font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 18 : 20) : (root.isCompact ? 18 : 20)
                color: Qt.tint(root.weatherHex, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, root.isCompact ? 0.3 : 0.4))
                visible: !root.isWeatherLoading && root.weatherIcon !== ""
            }

            Text {
                text: root.weatherTemp
                anchors.verticalCenter: parent.verticalCenter
                font.family: "Monocraft"
                font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
                font.weight: Font.Black
                color: root.isCompact ? Qt.lighter(ThemeBackend.peach, 1.1) : ThemeBackend.peach
                visible: !root.isWeatherLoading
            }
        }
    }
}
