import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    WlrLayershell.namespace: "assistant-bg"
    WlrLayershell.layer: WlrLayer.Bottom

    focusable: false
    exclusionMode: ExclusionMode.Ignore

    mask: Region {}

    color: "transparent"

    implicitWidth: root.screen.width
    implicitHeight: root.screen.height

    Rectangle {
        id: windowContent
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: "transparent"
        clip: true

        property color currentBasePurple: ThemeBackend.mauve
        property color currentAccentLavender: ThemeBackend.accent
        property color currentLogoColor: ThemeBackend.text

        property real calmState: 1.0
        property real popShockwave: 0.0

        property real time: 0
        NumberAnimation on time {
            from: 0; to: Math.PI * 2; duration: 40000; loops: Animation.Infinite; running: true
        }

        property real breathA: Math.pow((Math.sin(time * 6) + 1) / 2, 1.4)
        property real breathB: Math.pow((Math.sin(time * 6 + 0.4) + 1) / 2, 1.4)
        property real breathC: Math.pow((Math.sin(time * 6 + 0.8) + 1) / 2, 1.4)

        opacity: 0.0
        scale: 0.97

        Component.onCompleted: entranceAnimation.start()

        ParallelAnimation {
            id: entranceAnimation
            NumberAnimation { target: windowContent; property: "opacity"; to: 1.0; duration: 500; easing.type: Easing.OutExpo }
            NumberAnimation { target: windowContent; property: "scale"; to: 1.0; duration: 600; easing.type: Easing.OutExpo }
        }

        Item {
            id: orbGlow
            anchors.centerIn: parent
            width: 290
            height: 290

            property real baseOpacity: 1.0
            property real baseScale: 1.0

            opacity: baseOpacity
            scale: baseScale + (windowContent.breathA * 0.08)

            Repeater {
                model: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + (index * 45) + 25
                    height: width
                    radius: width / 2

                    color: index === 0 ? Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.6) : Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.4)

                    opacity: 1.0
                    antialiasing: true

                    scale: 1.0 + (windowContent.breathA * (0.02 * (index + 1)))
                }
            }
        }

        Rectangle {
            id: diffuseShockwave
            anchors.centerIn: parent
            width: 290
            height: 290
            radius: width / 2
            color: windowContent.currentAccentLavender
            opacity: windowContent.popShockwave * 0.15
            scale: 1.0 + (windowContent.popShockwave * 0.8)
            antialiasing: true
        }

        Item {
            id: worldCenter
            width: 290
            height: 290

            property real driftX: 0
            property real driftY: 0

            SequentialAnimation on driftX {
                loops: Animation.Infinite
                NumberAnimation { to: 2.5; duration: 15000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -2.0; duration: 14000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on driftY {
                loops: Animation.Infinite
                NumberAnimation { to: 2.0; duration: 16000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -2.5; duration: 15500; easing.type: Easing.InOutSine }
            }

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: driftX
            anchors.verticalCenterOffset: driftY

            rotation: windowContent.calmState * Math.sin(windowContent.time * 2) * 1.0

            Item {
                id: orb
                anchors.fill: parent

                Item {
                    id: activeEnergyCore
                    anchors.fill: parent
                    opacity: 1.0

                    scale: 1.0 + (windowContent.breathB * 0.04)

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.75)
                        antialiasing: true
                    }

                    Rectangle {
                        id: fluidGradientLayer
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        opacity: 0.85

                        property real oscRotation: 0
                        SequentialAnimation on oscRotation {
                            loops: Animation.Infinite
                            NumberAnimation { to: 15; duration: 12000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -15; duration: 12000; easing.type: Easing.InOutSine }
                        }
                        rotation: oscRotation

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: windowContent.currentBasePurple }
                            GradientStop { position: 1.0; color: Qt.lighter(windowContent.currentBasePurple, 1.3) }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: 0.4

                        scale: 1.0 + (windowContent.breathC * 0.06)

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: width
                            radius: width / 2
                            color: windowContent.currentAccentLavender
                            opacity: 0.5
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        opacity: 0.6

                        property real maskRotation: 0
                        SequentialAnimation on maskRotation {
                            loops: Animation.Infinite
                            NumberAnimation { to: -20; duration: 14000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 20; duration: 14000; easing.type: Easing.InOutSine }
                        }
                        rotation: maskRotation

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.4; color: Qt.rgba(windowContent.currentAccentLavender.r, windowContent.currentAccentLavender.g, windowContent.currentAccentLavender.b, 0.6) }
                            GradientStop { position: 0.6; color: Qt.rgba(windowContent.currentAccentLavender.r, windowContent.currentAccentLavender.g, windowContent.currentAccentLavender.b, 0.6) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: 0.04
                        clip: true
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 2; blur: 1.0 }
                        Repeater {
                            model: 24
                            Rectangle {
                                property real angle: index * 15
                                property real dist: (index * 4) % (parent.width / 2.2)
                                x: (parent.width / 2) + Math.cos(angle) * dist - width/2
                                y: (parent.height / 2) + Math.sin(angle) * dist - height/2
                                width: (index % 3) + 2
                                height: width
                                radius: width/2
                                color: ThemeBackend.text
                                rotation: windowContent.time * 10 * (index % 2 === 0 ? 1 : -1)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: width / 2
                        color: "transparent"
                        antialiasing: true
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 4; blur: 1.0 }
                    }

                    Item {
                        id: logotypeWrapper
                        anchors.centerIn: parent
                        width: parent.width * 0.70
                        height: width

                        rotation: -worldCenter.rotation

                        scale: 1.0 + (windowContent.breathB * 0.03)
                        opacity: 1.0

                        Image {
                            id: rawSvgImage
                            anchors.fill: parent
                            source: "file://" + Caching.serpantinumDir + "/assets/logo.svg"
                            sourceSize: Qt.size(1024, 1024)
                            fillMode: Image.PreserveAspectFit
                            antialiasing: true
                            mipmap: true
                            visible: false
                        }

                        MultiEffect {
                            source: rawSvgImage
                            anchors.fill: rawSvgImage
                            autoPaddingEnabled: true

                            shadowEnabled: true
                            shadowColor: ThemeBackend.crust
                            shadowBlur: 15
                            shadowOpacity: 0.7
                        }
                    }
                }
            }
        }
    }
}
