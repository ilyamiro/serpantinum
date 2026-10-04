import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 150
    property real minHeight: 150
    property real maxWidth: 1000
    property real maxHeight: 1000
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

    property bool isVisVisible: visible

    property bool isSubscribed: false

    onIsVisVisibleChanged: updateSubscription()

    function updateSubscription() {
        if (isVisVisible && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Component.onCompleted: {
        updateSubscription();
    }

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    property int barCount: 64
    property var rawBarLevels: Cava.barLevels

    property var processedBars: {
        let source = rawBarLevels;
        let count = barCount;
        let out = [];

        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return { levels: out, bass: 0.0, kick: 0.0 };
        }

        let subBass = (source[0] || 0.0) * 0.50 + (source[1] || 0.0) * 0.35 + (source[2] || 0.0) * 0.15;
        let kickPunch = (source[1] || 0.0) * 0.30 + (source[2] || 0.0) * 0.45 + (source[3] || 0.0) * 0.25;
        let rawKick = Math.max(subBass, kickPunch);

        let kick = rawKick > 0.10 ? Math.min(1.0, Math.pow((rawKick - 0.10) / 0.90, 1.8) * 1.4) : 0.0;
        let bass = Math.max(0.0, Math.min(1.0, subBass * 0.6 + kickPunch * 0.4));

        let srcLen = source.length;
        for (let i = 0; i < count; i++) {
            let norm = i / (count - 1);
            let pos = Math.pow(norm, 1.15) * (srcLen - 1);
            let idx0 = Math.floor(pos);
            let idx1 = Math.min(srcLen - 1, idx0 + 1);
            let frac = pos - idx0;

            let v0 = source[idx0] || 0.0;
            let v1 = source[idx1] || 0.0;
            let val = v0 + (v1 - v0) * frac;

            val = Math.max(0.0, Math.min(1.0, val));
            val = Math.pow(val, 1.08);

            out.push(val);
        }

        return { levels: out, bass: bass, kick: kick };
    }

    property var barLevels: processedBars.levels
    property real bassLevel: processedBars.bass
    property real kickLevel: processedBars.kick

    property real availableRadius: Math.min(width, height) / 2
    property real dynMargin: 0
    property real artRadius: availableRadius * 0.78
    property real barHeightScale: 0.92
    property real maxBarHeight: (availableRadius - artRadius) * barHeightScale
    property real barWidth: Math.max(2.2, (2 * Math.PI * artRadius) / barCount * 0.60)

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: discContainer.anchors.verticalCenterOffset * 0.5
            width: (root.artRadius * 2) + (root.maxBarHeight * 2.0)
            height: width
            radius: width / 2
            color: ThemeBackend.mauve
            opacity: (root.isMediaActive && MprisController.isPlaying) ? (0.005 + (root.bassLevel * 0.035)) : 0.0
            scale: 0.985 + (root.bassLevel * 0.0375)

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: 4.2
                    damping: 0.38
                    mass: 0.8
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: discContainer.anchors.verticalCenterOffset * 0.8
            width: (root.artRadius * 2) + (root.maxBarHeight * 1.35)
            height: width
            radius: width / 2
            color: ThemeBackend.mauve
            opacity: (root.isMediaActive && MprisController.isPlaying) ? (0.01 + (root.kickLevel * 0.055)) : 0.0
            scale: 0.992 + (root.kickLevel * 0.02625)

            Behavior on opacity {
                NumberAnimation {
                    duration: 40
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: 5.2
                    damping: 0.34
                    mass: 0.6
                }
            }
        }

        Repeater {
            model: root.barCount
            delegate: Item {
                anchors.centerIn: parent
                width: 0
                height: 0
                rotation: index * (360 / root.barCount)

                property real level: {
                    if (!root.barLevels || root.barLevels.length === 0) return 0.0;
                    return root.barLevels[index] || 0.0;
                }

                Rectangle {
                    anchors.bottom: parent.top
                    anchors.bottomMargin: root.artRadius
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.barWidth
                    height: Math.max(2.5, parent.level * root.maxBarHeight)
                    topLeftRadius: width / 2
                    topRightRadius: width / 2
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                    antialiasing: true
                    color: {
                        let mixRatio = (index / root.barCount) * 0.4 + (parent.level * 0.6);
                        return Qt.tint(ThemeBackend.mauve, Qt.rgba(1, 1, 1, mixRatio * 0.45));
                    }
                    opacity: 0.40 + (parent.level * 0.60)

                    Behavior on height {
                        NumberAnimation {
                            duration: 70
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Item {
            id: discContainer
            anchors.centerIn: parent
            width: root.artRadius * 2
            height: root.artRadius * 2

            property real borderWidth: 0
            property real targetScale: (root.isMediaActive && MprisController.isPlaying) ? (1.0 + (root.bassLevel * 0.0135) + (root.kickLevel * 0.027)) : 0.95
            property real targetBounceY: (root.isMediaActive && MprisController.isPlaying) ? -(root.kickLevel * root.artRadius * 0.02025) : 0
            property real targetTilt: (root.isMediaActive && MprisController.isPlaying) ? (root.bassLevel - 0.3) * 0.9 : 0

            anchors.verticalCenterOffset: targetBounceY
            rotation: targetTilt
            scale: targetScale

            Behavior on anchors.verticalCenterOffset {
                SpringAnimation {
                    spring: 4.8
                    damping: 0.38
                    mass: 0.85
                }
            }

            Behavior on rotation {
                SpringAnimation {
                    spring: 2.8
                    damping: 0.52
                    mass: 0.95
                }
            }

            Behavior on scale {
                SpringAnimation {
                    spring: 5.2
                    damping: 0.35
                    mass: 0.75
                }
            }

            Rectangle {
                id: vinylBase
                anchors.fill: parent
                radius: width / 2
                color: ThemeBackend.surface1
                border.width: discContainer.borderWidth
                border.color: (root.isMediaActive && MprisController.isPlaying) ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.overlay0 || "#6c7086")
                Behavior on border.color { ColorAnimation { duration: 500 } }

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 24000
                    loops: Animation.Infinite
                    running: true
                    paused: !(root.isMediaActive && MprisController.isPlaying)
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: discContainer.borderWidth

                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: (root.isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    Rectangle {
                        id: maskRect
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: artImg
                        maskEnabled: true
                        maskSource: maskRect
                        opacity: (root.isMediaActive && artImg.status === Image.Ready && MprisController.artUrl !== "") ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 600 }
                        }
                    }

                    Rectangle {
                        id: fallbackPlaceholder
                        anchors.fill: parent
                        radius: width / 2
                        color: ThemeBackend.mantle
                        opacity: (root.isMediaActive && artImg.status === Image.Ready && MprisController.artUrl !== "") ? 0.0 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 400 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            font.pixelSize: parent.width * 0.26
                            color: ThemeBackend.overlay1
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.08 + (root.kickLevel * 0.08))
                        opacity: (root.isMediaActive && artImg.status === Image.Ready && MprisController.artUrl !== "") ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 600 }
                        }
                    }

                    Repeater {
                        model: [0.92, 0.84, 0.76, 0.68, 0.60, 0.52, 0.44]
                        delegate: Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * modelData
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: index % 2 === 0 ? "#ffffff" : "#000000"
                            border.width: 1
                            opacity: (index % 2 === 0 ? 0.035 : 0.06) + (root.bassLevel * 0.02)
                            antialiasing: true
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.28
                        height: width
                        radius: width / 2
                        color: ThemeBackend.crust
                        opacity: 0.96
                        scale: 1.0 + (root.kickLevel * 0.0135)
                        border.width: 1.5
                        border.color: Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.45 + (root.kickLevel * 0.4))

                        Behavior on scale {
                            SpringAnimation {
                                spring: 6.0
                                damping: 0.32
                                mass: 0.5
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.68
                            height: width
                            radius: width / 2
                            color: ThemeBackend.surface2
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.38
                                height: width
                                radius: width / 2
                                color: "#0d0e15"
                            }
                        }
                    }
                }
            }
        }
    }
}
