import QtQuick
import QtQuick.Effects
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 60
    property real minHeight: 30
    property real maxWidth: 2000
    property real maxHeight: 800
    property real minAspect: 0.2
    property real maxAspect: 20.0
    property bool isRound: false

    property string textContent: ""

    readonly property bool isEmpty: root.textContent.trim() === ""

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: root.isEmpty ? I18n.t("widgets.text.placeholder", "Enter text") : root.textContent
        font.family: ThemeBackend.fontFamily
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        font.weight: Font.Bold
        color: ThemeBackend.text
        opacity: root.isEmpty ? 0.4 : 1.0
        wrapMode: Text.Wrap
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
