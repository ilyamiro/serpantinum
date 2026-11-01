import QtQuick
import QtQuick.Effects
import "../../"
import "../"

Item {
    id: root

    property real value: 0.0
    property color accentColor: ThemeBackend.accent
    property color trackColor: ThemeBackend.surface0
    property string icon: ""
    property string title: ""
    property string valueText: ""
    property bool useSineWave: true
    property real lineThickness: 8
    property bool isLive: true
    property bool compact: false

    property var scaleFunc: null
    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : (typeof Scaler !== "undefined" ? Scaler.s(val) : val);
    }

    property string fontFamily: ThemeBackend.fontFamily
    property color valueTextColor: ThemeBackend.text
    property color subTextColor: ThemeBackend.subtext0
    property color iconColor: ThemeBackend.subtext0

    readonly property real diameter: Math.min(width, height)
    readonly property real referenceDiameter: s(130)
    readonly property real strokePx: root.diameter * Math.max(3, Math.min(16, root.lineThickness)) / root.referenceDiameter
    readonly property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(value) ? 0.0 : value))
    readonly property bool showTitle: root.title !== "" && root.diameter >= s(96)
    readonly property bool showIcon: root.icon !== "" && root.diameter >= s(72)

    Item {
        id: gaugeBox
        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: root.s(1.5)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.55
        }

        ShaderEffect {
            anchors.fill: parent

            property vector2d itemSize: Qt.vector2d(width, height)
            property real fillRatio: root.fillRatio
            property real strokeWidth: root.strokePx
            property real useSineWave: root.useSineWave ? 1.0 : 0.0
            property color accentColor: root.accentColor
            property vector4d params: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
            property color trackColor: root.trackColor

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/gauges/circular_wave_gauge_smooth.frag.qsb"
        }

        Column {
            anchors.centerIn: parent
            spacing: root.s(2)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showIcon
                text: root.icon
                font.family: ThemeBackend.iconFont
                font.pixelSize: Math.round(root.diameter * 0.16)
                color: root.iconColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.valueText
                font.family: root.fontFamily
                font.weight: Font.Black
                font.pixelSize: Math.round(root.diameter * (root.compact ? 0.2 : 0.22))
                color: root.valueTextColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showTitle
                text: root.title
                font.family: root.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: Math.round(root.diameter * 0.095)
                color: root.subTextColor
            }
        }
    }
}
