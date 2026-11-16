import QtQuick
import QtQuick.Effects
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool previewMode: false

    property real minWidth: 80
    property real minHeight: 40
    property real maxWidth: 1200
    property real maxHeight: 600
    property real minAspect: 1.2
    property real maxAspect: 5.0
    property bool isRound: false

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: DateTime.time
        font.family: ThemeBackend.fontFamily
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 10
        font.weight: Font.Black
        color: ThemeBackend.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: Scaler.s(1.5)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.55
        }
    }
}
