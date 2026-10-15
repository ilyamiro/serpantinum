import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Item {
    id: root
    implicitWidth: root.maxWidth > 0 ? Math.min(desiredWidth, root.maxWidth) : desiredWidth
    implicitHeight: 56

    property int horizontalPadding: 30
    property int cornerRadius: 12
    readonly property real effectiveRadius: Math.max(0, Math.min(root.cornerRadius, Math.min(width > 0 ? width : desiredWidth, height > 0 ? height : implicitHeight) / 2))

    property string buttonText: "FILLBUTTON"
    property string subText: ""
    property string buttonIcon: "󰐊"
    property int iconFontSize: 20
    property int textFontSize: 16
    property int maxTextWidth: 0
    property int maxWidth: 0
    property int contentAlignment: Qt.AlignHCenter

    property color accentColor: "#89b4fa"
    property color baseColor: "#181825"
    property color hoverColor: "#1e1e2e"
    property color textColor: "#cdd6f4"
    property color filledTextColor: "#11111b"
    property int fillDuration: 800
    property int autoResetTimeout: 1200
    property bool action_highlight: false

    property real iconTextWidth: buttonIcon !== "" ? iconFontSize : 0
    property real textColWidth: Math.max(buttonText !== "" ? buttonText.length * (textFontSize * 0.6) : 0, subText !== "" ? subText.length * (textFontSize * 0.4) : 0)
    property real calculatedContentWidth: iconTextWidth + (iconTextWidth > 0 && textColWidth > 0 ? 12 : 0) + textColWidth
    property real desiredWidth: Math.max(200, calculatedContentWidth + horizontalPadding * 2)

    signal triggered()

    property int chargingSoundHandle: -1
    property real fillLevel: 0.0
    property bool isTriggered: false
    property real flashOpacity: 0.0
    property real popScale: 1.0

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && !root.isTriggered

    function reset() {
        resetTimer.stop();
        root.isTriggered = false;
        fillAnim.stop();
        drainAnim.start();
    }

    Timer {
        id: resetTimer
        interval: root.autoResetTimeout
        repeat: false
        onTriggered: root.reset()
    }

    component ButtonContent : Item {
        id: bRoot
        property color contentTextColor: root.accentColor
        property real currentFill: 0.0

        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        RowLayout {
            id: contentRow
            layoutDirection: I18n.layoutDirection
            x: {
                if (root.contentAlignment === Qt.AlignHCenter) {
                    return Math.round((parent.width - width) / 2);
                }
                let alignLeft = (root.contentAlignment === Qt.AlignLeft && !I18n.rtl) || (root.contentAlignment === Qt.AlignRight && I18n.rtl);
                return alignLeft ? root.horizontalPadding : (parent.width - width - root.horizontalPadding);
            }
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                id: iconText
                visible: root.buttonIcon !== ""
                text: root.buttonIcon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: root.iconFontSize
                color: bRoot.contentTextColor
                Behavior on color { ColorAnimation { duration: 150 } }

                property real iconXInBRoot: contentRow.x + iconText.x + (iconText.width / 2)
                property real charNorm: bRoot.width > 0 ? iconXInBRoot / bRoot.width : 0
                property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999
                                    ? Math.exp(-Math.pow((bRoot.currentFill - charNorm) * 9, 2))
                                    : 0.0

                transform: [
                    Translate { y: -iconText.bump * 1.0 },
                    Scale {
                        origin.x: width / 2
                        origin.y: height / 2
                        xScale: 1.0 + iconText.bump * 0.03
                        yScale: 1.0 + iconText.bump * 0.03
                    }
                ]
            }

            ColumnLayout {
                id: textCol
                visible: root.buttonText !== "" || root.subText !== ""
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    id: rtlMainText
                    visible: I18n.rtl && root.buttonText !== ""
                    text: root.buttonText
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.textFontSize
                    color: bRoot.contentTextColor
                    horizontalAlignment: root.contentAlignment === Qt.AlignHCenter ? Text.AlignHCenter : I18n.textAlignment
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: charRow
                    visible: !I18n.rtl
                    spacing: 0
                    Repeater {
                        model: Array.from(root.buttonText)
                        Item {
                            id: charSlot
                            required property string modelData
                            required property int index

                            width: charText.implicitWidth
                            height: charText.implicitHeight

                            property real charXInBRoot: contentRow.x + textCol.x + charRow.x + charSlot.x + (charSlot.width / 2)
                            property real charNorm: bRoot.width > 0 ? charXInBRoot / bRoot.width : 0
                            property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999
                                                ? Math.exp(-Math.pow((bRoot.currentFill - charNorm) * 9, 2))
                                                : 0.0

                            property real animScale: 1.0
                            property real animY: 0.0
                            property real animRotation: 0.0

                            Component.onCompleted: entranceAnim.restart()

                            SequentialAnimation {
                                id: entranceAnim
                                PauseAnimation { duration: charSlot.index * 20 }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: charSlot
                                        property: "animScale"
                                        from: 0.55
                                        to: 1.0
                                        duration: 240
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.35
                                    }
                                    NumberAnimation {
                                        target: charSlot
                                        property: "animY"
                                        from: 4
                                        to: 0
                                        duration: 220
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.25
                                    }
                                    NumberAnimation {
                                        target: charSlot
                                        property: "animRotation"
                                        from: (charSlot.index % 2 === 0 ? -10 : 10)
                                        to: 0
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: charSlot
                                        property: "opacity"
                                        from: 0.0
                                        to: 1.0
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            Text {
                                id: charText
                                anchors.centerIn: parent
                                text: charSlot.modelData === " " ? "\u00A0" : charSlot.modelData
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.textFontSize
                                color: bRoot.contentTextColor
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            transform: [
                                Translate { y: charSlot.animY - (charSlot.bump * 3.5) },
                                Scale {
                                    origin.x: charSlot.width / 2
                                    origin.y: charSlot.height / 2
                                    xScale: charSlot.animScale * (1.0 + charSlot.bump * 0.12)
                                    yScale: charSlot.animScale * (1.0 + charSlot.bump * 0.12)
                                },
                                Rotation {
                                    origin.x: charSlot.width / 2
                                    origin.y: charSlot.height / 2
                                    angle: charSlot.animRotation + (charSlot.bump * (charSlot.index % 2 === 0 ? -7 : 7))
                                }
                            ]
                        }
                    }
                }

                Text {
                    id: subTextItem
                    visible: root.subText !== ""
                    text: root.subText
                    font.family: "JetBrains Mono"
                    font.pixelSize: Math.max(10, root.textFontSize - 6)
                    color: bRoot.contentTextColor
                    horizontalAlignment: root.contentAlignment === Qt.AlignHCenter ? Text.AlignHCenter : I18n.textAlignment
                    opacity: 0.8
                    Behavior on color { ColorAnimation { duration: 150 } }

                    property real subTextXInBRoot: contentRow.x + textCol.x + subTextItem.x + (subTextItem.width / 2)
                    property real charNorm: bRoot.width > 0 ? subTextXInBRoot / bRoot.width : 0
                    property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999
                                        ? Math.exp(-Math.pow((bRoot.currentFill - charNorm) * 9, 2))
                                        : 0.0

                    transform: [
                        Translate { y: -subTextItem.bump * 2.5 },
                        Scale {
                            origin.x: width / 2
                            origin.y: height / 2
                            xScale: 1.0 + subTextItem.bump * 0.08
                            yScale: 1.0 + subTextItem.bump * 0.08
                        }
                    ]
                }
            }
        }
    }

    Rectangle {
        id: cardShadow
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: root.effectiveRadius
        color: Qt.rgba(0, 0, 0, 0.14)
        scale: btnShape.scale
        opacity: root.isTriggered ? 0.06 : (root.isHoveredOrHighlighted ? 0.24 : 0.14)
        z: -2
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Rectangle {
        id: cardGlowShadow
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: Math.min(root.effectiveRadius + 2, Math.min(width, height) / 2)
        color: root.accentColor
        scale: btnShape.scale
        opacity: root.isHoveredOrHighlighted && !root.isTriggered ? 0.18 : 0.0
        z: -2
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        id: btnShape
        anchors.fill: parent
        radius: root.effectiveRadius
        clip: true
        color: root.isHoveredOrHighlighted ? root.hoverColor : root.baseColor

        Behavior on color { ColorAnimation { duration: 180 } }

        scale: (btnMa.pressed && !root.isTriggered ? 0.96 : (root.isHoveredOrHighlighted ? 1.02 : 1.0)) * root.popScale
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: btnPopAnim
            NumberAnimation { target: root; property: "popScale"; to: 0.95; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
        }

        FluidWave {
            id: waveCanvas
            anchors.fill: parent
            property real wavePhase: 0.0
            NumberAnimation on wavePhase {
                running: root.fillLevel > 0.0 && root.fillLevel < 1.0
                loops: Animation.Infinite
                from: 0; to: Math.PI * 2; duration: 800
            }

            radius: root.cornerRadius
            fillLevel: root.fillLevel
            waveAmp: root.fillLevel < 0.99 ? (Math.min(10, Math.min(width * root.fillLevel, width - width * root.fillLevel)) * Math.sin(root.fillLevel * Math.PI)) : 0
            phase: wavePhase
            vertical: 0.0
            color1: Qt.darker(root.accentColor, 1.15)
            color2: root.accentColor
            visible: root.fillLevel > 0.001
        }

        Rectangle {
            anchors.fill: parent
            radius: root.effectiveRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
        }

        ButtonContent {
            id: mainContent
            width: btnShape.width
            height: btnShape.height
            contentTextColor: root.isHoveredOrHighlighted ? root.textColor : root.accentColor
            currentFill: root.fillLevel
        }

        Item {
            id: waveClipGroup
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            property real maxAmp: Math.min(10, Math.min(parent.width * root.fillLevel, parent.width * (1.0 - root.fillLevel)))
            property real waveAmp: maxAmp * Math.sin(root.fillLevel * Math.PI)
            property real phaseOffset: Math.sin(waveCanvas.wavePhase) - Math.cos(waveCanvas.wavePhase)
            property real centerOffset: root.fillLevel > 0.01 && root.fillLevel < 0.99 ? 0.375 * waveAmp * phaseOffset : 0

            width: Math.max(0, Math.min(parent.width, (parent.width * root.fillLevel) + centerOffset))
            clip: true

            ButtonContent {
                width: btnShape.width
                height: btnShape.height
                contentTextColor: root.filledTextColor
                currentFill: root.fillLevel
            }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.isTriggered
            cursorShape: root.isTriggered ? Qt.ArrowCursor : Qt.PointingHandCursor

            onPressed: {
                if (!root.isTriggered) {
                    if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                        Sounds.stopSfx(root.chargingSoundHandle);
                        root.chargingSoundHandle = -1;
                    }
                    if (typeof Sounds !== "undefined") {
                        root.chargingSoundHandle = Sounds.playUntilStopped("reusables/fillbutton/charge_loop.wav", 0.6, false);
                    }
                    drainAnim.stop();
                    fillAnim.start();
                }
            }

            onReleased: {
                if (!root.isTriggered && root.fillLevel < 1.0) {
                    if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                        Sounds.stopSfx(root.chargingSoundHandle);
                        root.chargingSoundHandle = -1;
                    }
                    fillAnim.stop();
                    drainAnim.start();
                }
            }

            onCanceled: {
                if (!root.isTriggered && root.fillLevel < 1.0) {
                    if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                        Sounds.stopSfx(root.chargingSoundHandle);
                        root.chargingSoundHandle = -1;
                    }
                    fillAnim.stop();
                    drainAnim.start();
                }
            }
        }

        NumberAnimation {
            id: fillAnim
            target: root
            property: "fillLevel"
            to: 1.0
            duration: root.fillDuration * (1.0 - root.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                root.isTriggered = true;
                root.flashOpacity = 0.5;
                btnPopAnim.start();
                if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(root.chargingSoundHandle);
                    root.chargingSoundHandle = -1;
                }
                if (typeof Sounds !== "undefined") {
                    Sounds.playSfx("reusables/fillbutton/button.wav");
                }
                btnFlashAnim.start();
                root.triggered();
                if (root.autoResetTimeout > 0) {
                    resetTimer.restart();
                }
            }
        }

        NumberAnimation {
            id: drainAnim
            target: root
            property: "fillLevel"
            to: 0.0
            duration: (root.fillDuration * 1.875) * root.fillLevel
            easing.type: Easing.OutQuad
        }
    }
}
