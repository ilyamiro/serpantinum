import QtQuick
import QtQuick.Effects
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 120
    property real minHeight: 60
    property real maxWidth: 1400
    property real maxHeight: 700
    property real minAspect: 1.2
    property real maxAspect: 5.0
    property bool isRound: false

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.06
        text: DateTime.hour + DateTime.minute
        font.family: ThemeBackend.fontFamily
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
        font.weight: Font.Black
        font.letterSpacing: height * 0.01
        color: Qt.tint(ThemeBackend.text, Qt.alpha(ThemeBackend.mauve, 0.14))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: Scaler.s(3)
            shadowBlur: 0.55
            shadowOpacity: 0.5
        }
    }
}
