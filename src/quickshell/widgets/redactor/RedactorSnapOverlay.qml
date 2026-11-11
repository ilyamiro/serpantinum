import QtQuick
import "../../"
import ".."

Item {
    id: snapOverlay
    anchors.fill: parent
    z: 100000

    property var guideLines: []
    property var measureLines: []

    function s(val) { return Scaler.s(val); }

    readonly property real lineWidth: s(1)
    readonly property real capLength: s(7)

    Repeater {
        model: snapOverlay.guideLines
        delegate: Rectangle {
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: ThemeBackend.mauve
        }
    }

    Repeater {
        model: snapOverlay.measureLines
        delegate: Item {
            id: measure
            readonly property bool horizontal: modelData.horizontal
            readonly property bool labelFits: horizontal
                ? modelData.length >= measureLabel.width + snapOverlay.capLength * 2
                : modelData.length >= measureLabel.height + snapOverlay.capLength * 2

            x: modelData.x
            y: modelData.y
            width: horizontal ? modelData.length : 0
            height: horizontal ? 0 : modelData.length

            Rectangle {
                x: measure.horizontal ? 0 : -width / 2
                y: measure.horizontal ? -height / 2 : 0
                width: measure.horizontal ? measure.width : snapOverlay.lineWidth
                height: measure.horizontal ? snapOverlay.lineWidth : measure.height
                color: ThemeBackend.mauve
            }

            Repeater {
                model: 2
                delegate: Rectangle {
                    width: measure.horizontal ? snapOverlay.lineWidth : snapOverlay.capLength
                    height: measure.horizontal ? snapOverlay.capLength : snapOverlay.lineWidth
                    x: measure.horizontal ? index * measure.width - width / 2 : -width / 2
                    y: measure.horizontal ? -height / 2 : index * measure.height - height / 2
                    color: ThemeBackend.mauve
                }
            }

            Rectangle {
                id: measureLabel
                width: measureText.implicitWidth + s(12)
                height: s(20)
                radius: Math.min(ThemeBackend.borderRadius, height / 2)
                color: ThemeBackend.mauve
                x: measure.horizontal
                    ? (measure.width - width) / 2
                    : (measure.labelFits ? -width / 2 : s(6))
                y: measure.horizontal
                    ? (measure.labelFits ? -height / 2 : -height - s(6))
                    : (measure.height - height) / 2

                Text {
                    id: measureText
                    anchors.centerIn: parent
                    text: modelData.value
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(11)
                    font.bold: true
                    color: ThemeBackend.crust
                }
            }
        }
    }
}
