import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    property string weatherIcon: Weather.currentIcon
    property string weatherTemp: {
        if (!isVertical) return Weather.currentTempFormatted;
        let raw = Weather.currentTemp !== "" ? Weather.currentTemp : Weather.currentTempFormatted;
        if (!raw || raw === "") return "--°";
        let intPart = raw.split(".")[0].replace(/[^\d-]/g, "");
        return (intPart !== "" ? intPart : "--") + "°";
    }
    property string weatherHex: Weather.currentHex
    property bool isWeatherLoading: Weather.isLoading || !Weather.isReady

    property real lengthPadding: isVertical ? s(isCompact ? 10 : 12) : s(isCompact ? 12 : 14)
    property real targetLength: (isVertical ? weatherLayout.implicitHeight : weatherLayout.implicitWidth) + (lengthPadding * 2)

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePanel("calendar")
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
            spacing: root.isVertical ? root.s(root.isCompact ? 2 : 3) : root.s(root.isCompact ? 6 : 8)

            LoaderIcon {
                id: weatherLoader
                width: root.isVertical ? root.s(root.isCompact ? 18 : 20) : root.s(root.isCompact ? 20 : 22)
                height: width
                accentColor: ThemeBackend.mauve
                running: root.isWeatherLoading
                visible: root.isWeatherLoading
            }

            Text {
                text: root.weatherIcon
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.isVertical ? root.s(root.isCompact ? 16 : 18) : root.s(root.isCompact ? 18 : 20)
                color: Qt.tint(root.weatherHex, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, root.isCompact ? 0.3 : 0.4))
                visible: !root.isWeatherLoading && root.weatherIcon !== ""
            }

            Text {
                text: root.weatherTemp
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.isVertical ? root.s(root.isCompact ? 11 : 12) : root.s(root.isCompact ? 14 : 15)
                font.weight: Font.Black
                color: root.isCompact ? Qt.lighter(ThemeBackend.peach, 1.1) : ThemeBackend.peach
                visible: !root.isWeatherLoading
            }
        }
    }
}
