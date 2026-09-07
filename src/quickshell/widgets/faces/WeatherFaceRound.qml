import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 90
    property real minHeight: 90
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    property real faceSize: Math.min(root.width, root.height)
    property real pillLength: root.faceSize * 0.94
    property real pillWidth: root.faceSize * 0.54
    property real pillRadius: root.pillWidth / 2
    property real iconHorizontalOffset: -12

    property var weatherData: Weather.data
    property bool hasLoadedOnce: Weather.isReady
    property bool isLoading: Weather.isLoading || !Weather.isReady

    property string currentHex: Weather.currentHex
    property color accentColor: (currentHex && currentHex.length === 7) ? currentHex : ThemeBackend.mauve

    property string tempNumber: {
        if (!Weather.isReady || Weather.currentTemp === "") {
            return "--";
        }
        let raw = String(Weather.currentTemp).trim();
        if (raw === "") return "--";

        let num = Math.round(parseFloat(raw));
        if (isNaN(num)) return "--";

        return String(num);
    }

    property string formattedTemp: root.tempNumber + "°"

    Rectangle {
        id: pillBackground
        anchors.centerIn: parent
        width: root.pillWidth
        height: root.pillLength
        radius: root.pillRadius
        rotation: 45
        color: ThemeBackend.surface0
        antialiasing: true

        Item {
            anchors.fill: parent
            rotation: -45
            visible: root.isLoading

            LoaderIcon {
                anchors.centerIn: parent
                width: root.pillWidth * 0.45
                height: width
                accentColor: ThemeBackend.mauve
                running: root.isLoading
                visible: root.isLoading
            }
        }

        Item {
            anchors.fill: parent
            visible: !root.isLoading

            Item {
                id: iconContainer
                width: root.pillWidth * 0.68
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: root.pillRadius
                rotation: -45

                Text {
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.iconHorizontalOffset
                    text: Weather.currentIcon !== "" ? Weather.currentIcon : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: parent.height * 0.76
                    color: root.accentColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                }
            }

            Item {
                id: tempContainer
                width: root.pillWidth * 0.68
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.bottom
                anchors.verticalCenterOffset: -root.pillRadius
                rotation: -45

                Item {
                    anchors.centerIn: parent
                    width: tempNumberText.implicitWidth
                    height: tempNumberText.implicitHeight

                    Text {
                        id: tempNumberText
                        anchors.centerIn: parent
                        text: root.tempNumber
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        color: ThemeBackend.text
                        font.pixelSize: tempContainer.height * 0.58
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: degreeText
                        anchors.left: tempNumberText.right
                        anchors.leftMargin: 1
                        anchors.top: tempNumberText.top
                        anchors.topMargin: tempContainer.height * 0.04
                        text: "°"
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        color: ThemeBackend.text
                        font.pixelSize: tempContainer.height * 0.30
                    }
                }
            }
        }
    }
}
