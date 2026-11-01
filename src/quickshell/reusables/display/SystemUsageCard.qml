import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

Item {
    id: root

    property real value: 0.0
    property color colorBase: ThemeBackend.surface0
    property color colorFill: ThemeBackend.mauve
    property string icon: ""
    property string title: ""
    property string midText: ""
    property string valueText: ""
    property string subText: ""
    property alias bottomLeftText: root.subText

    property real internalWavePhase: 0.8
    property real wavePhase: internalWavePhase
    property bool isLive: true
    property bool hasShadow: false
    property bool blurred: false
    property real bgOpacity: 1.0
    property color shadowColor: Qt.rgba(0, 0, 0, 0.22)

    Timer {
        id: waveSettleTimer
        interval: 1600
        repeat: false
        onTriggered: waveAnimation.stop()
    }

    NumberAnimation {
        id: waveAnimation
        target: root
        property: "internalWavePhase"
        from: 0
        to: Math.PI * 2
        loops: Animation.Infinite
        duration: 1800
    }

    onValueChanged: {
        if (root.visible && root.isLive && root.fillRatio > 0.001 && root.fillRatio < 0.999) {
            if (!waveAnimation.running) waveAnimation.start();
            waveSettleTimer.restart();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            waveAnimation.stop();
            waveSettleTimer.stop();
        }
    }

    onIsLiveChanged: {
        if (!isLive) {
            waveAnimation.stop();
            waveSettleTimer.stop();
        }
    }

    property bool compact: false

    property var scaleFunc: null
    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : (typeof Scaler !== "undefined" ? Scaler.s(val) : val);
    }

    property real cardRadius: compact ? s(Math.max(0, ThemeBackend.clampedBorderRadius - 2)) : s(ThemeBackend.clampedBorderRadius)
    property real contentMargins: compact ? s(10) : s(12)
    property real waveAmpMax: compact ? s(4) : s(5)

    property real iconSize: compact ? s(26) : s(28)
    property real iconCornerRadius: Math.min(iconSize / 2, s(ThemeBackend.borderRadius))
    property real iconFontSize: compact ? s(14) : s(16)
    property real midTextFontSize: compact ? s(10.5) : s(13)
    property real titleFontSize: compact ? s(10.5) : s(13)
    property real subTextFontSize: compact ? s(11) : s(15)
    property real valueFontSize: compact ? s(18) : s(24)

    property string fontFamily: ThemeBackend.fontFamily
    property color borderColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.06)
    property color iconAccentColor: Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.6)
    property color iconTextColor: ThemeBackend.subtext0
    property color midTextColor: Qt.rgba(ThemeBackend.subtext0.r, ThemeBackend.subtext0.g, ThemeBackend.subtext0.b, 0.7)
    property color titleColor: ThemeBackend.subtext0
    property color subTextColor: ThemeBackend.subtext0
    property color valueTextColor: ThemeBackend.text

    property color filledIconAccentColor: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.15)
    property color filledTextColor: ThemeBackend.crust
    property color filledMidTextColor: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.6)
    property color filledTitleColor: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.85)
    property color filledSubTextColor: ThemeBackend.crust

    readonly property bool glassActive: cardGlass.active || (root.blurred && ThemeBackend.liquidGlass)
    readonly property color effFilledTextColor: glassActive ? ThemeBackend.text : filledTextColor
    readonly property color effFilledMidTextColor: glassActive ? Qt.alpha(ThemeBackend.text, 0.7) : filledMidTextColor
    readonly property color effFilledTitleColor: glassActive ? Qt.alpha(ThemeBackend.text, 0.85) : filledTitleColor
    readonly property color effFilledSubTextColor: glassActive ? ThemeBackend.text : filledSubTextColor

    default property alias childItems: customContentBox.data

    readonly property real fillRatio: Math.max(0.0, Math.min(1.0, root.value))
    readonly property real fillY: height * (1.0 - root.fillRatio)
    readonly property real waveAmp: (root.fillRatio < 0.99 && root.fillRatio > 0.01) ? root.waveAmpMax * Math.sin(root.fillRatio * Math.PI) : 0
    readonly property real waveCenterOffset: root.waveAmp > 0 ? 0.375 * root.waveAmp * (Math.sin(root.wavePhase) - Math.cos(root.wavePhase)) : 0



    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.s(2)
        anchors.bottomMargin: -root.s(2)
        radius: root.cardRadius
        color: root.shadowColor
        visible: root.hasShadow
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: cardGlass.active ? "transparent" : Qt.alpha(root.colorBase, root.bgOpacity)

        GlassFill {
            id: cardGlass
            anchors.fill: parent
            allowed: !root.blurred
            radius: root.cardRadius
            tintColor: root.colorBase
            tintAmount: 0.3 * root.bgOpacity
        }

        Loader {
            z: -1
            anchors.fill: parent
            active: root.blurred
            sourceComponent: WallpaperBlur {
                radius: root.cardRadius
                standalone: true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: "transparent"
    }

    FluidWave {
        id: fluidWave
        anchors.fill: parent
        radius: root.cardRadius
        fillLevel: root.fillRatio
        waveAmp: root.waveAmp
        phase: root.wavePhase
        vertical: 1.0
        color1: Qt.lighter(root.colorFill, 1.18)
        color2: root.colorFill
        params: Qt.vector4d(0.94, 0.0, 0.0, 0.0)
        opacity: root.glassActive ? 0.6 : 1.0
        visible: root.fillRatio > 0.001
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.contentMargins

        IconButton {
            id: baseCardIcon
            anchors.top: parent.top
            anchors.left: parent.left
            size: Math.round(root.iconSize)
            cornerRadius: Math.round(root.iconCornerRadius)
            accentColor: root.iconAccentColor
            bgOpacity: root.bgOpacity
            textColor: root.iconTextColor
            buttonIcon: root.icon
            iconFontSize: Math.round(root.iconFontSize)
            enabled: false
        }

        Row {
            anchors.verticalCenter: baseCardIcon.verticalCenter
            anchors.right: parent.right
            spacing: root.s(4)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: root.midTextFontSize
                color: root.midTextColor
                text: root.midText
                visible: root.midText !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: root.titleFontSize
                color: root.titleColor
                text: root.title
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: root.s(1)
            font.family: root.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: root.subTextFontSize
            color: root.subTextColor
            text: root.subText
            visible: root.subText !== ""
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            font.family: root.fontFamily
            font.weight: Font.Black
            font.pixelSize: root.valueFontSize
            color: root.valueTextColor
            text: root.valueText
        }
    }

    Item {
        id: waveClipBox
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(parent.height, Math.max(0, (parent.height * root.fillRatio) - root.waveCenterOffset))
        clip: true
        visible: root.value > 0

        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.height - (root.contentMargins * 2)
            anchors.margins: root.contentMargins

            IconButton {
                id: filledCardIcon
                anchors.top: parent.top
                anchors.left: parent.left
                size: Math.round(root.iconSize)
                cornerRadius: Math.round(root.iconCornerRadius)
                accentColor: root.filledIconAccentColor
                textColor: root.effFilledTextColor
                buttonIcon: root.icon
                iconFontSize: Math.round(root.iconFontSize)
                enabled: false
            }

            Row {
                anchors.verticalCenter: filledCardIcon.verticalCenter
                anchors.right: parent.right
                spacing: root.s(4)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: root.midTextFontSize
                    color: root.effFilledMidTextColor
                    text: root.midText
                    visible: root.midText !== ""
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: root.titleFontSize
                    color: root.effFilledTitleColor
                    text: root.title
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: root.s(1)
                font.family: root.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: root.subTextFontSize
                color: root.effFilledSubTextColor
                text: root.subText
                visible: root.subText !== ""
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                font.family: root.fontFamily
                font.weight: Font.Black
                font.pixelSize: root.valueFontSize
                color: root.effFilledTextColor
                text: root.valueText
            }
        }
    }

    Item {
        id: customContentBox
        anchors.fill: parent
        anchors.margins: root.contentMargins
        z: 10
    }
}
