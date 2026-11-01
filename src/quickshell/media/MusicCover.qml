import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import "../"
import "../reusables"
import "../reusables/media"

Item {
    required property var root
    id: coverHost
    Layout.preferredWidth: root.s(224)
    Layout.preferredHeight: root.s(224)
    Layout.alignment: Qt.AlignVCenter

    opacity: root.introCover
    transform: Translate { x: root.s(-35) * (1 - root.introCover); y: root.s(9) * (1 - root.introCover) }

    property real availableRadius: width / 2
    property real dynMargin: 0
    property real artRadius: availableRadius * 0.86
    property real maxBarHeight: availableRadius - artRadius
    property real barWidth: Math.max(root.s(2), (2 * Math.PI * artRadius) / root.barCount * 0.65)

    Item {
        id: discAndVisGroup
        anchors.centerIn: parent
        width: coverHost.artRadius * 2
        height: coverHost.artRadius * 2

        property real targetScale: (root.targetPlayer && root.targetPlayer.isPlaying) ? (1.0 + (root.bassLevel * 0.0135) + (root.kickLevel * 0.027)) : 0.90
        property real targetBounceY: (root.targetPlayer && root.targetPlayer.isPlaying) ? -(root.kickLevel * coverHost.artRadius * 0.02025) : 0
        property real targetTilt: (root.targetPlayer && root.targetPlayer.isPlaying) ? (root.bassLevel - 0.3) * 0.9 : 0

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
            anchors.centerIn: parent
            width: (coverHost.artRadius * 2) + (coverHost.maxBarHeight * 2.2)
            height: width
            radius: width / 2
            color: ThemeBackend.mauve || "#cba6f7"
            opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? (0.005 + (root.bassLevel * 0.035)) : 0.0
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
            width: (coverHost.artRadius * 2) + (coverHost.maxBarHeight * 1.5)
            height: width
            radius: width / 2
            color: ThemeBackend.mauve || "#cba6f7"
            opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? (0.01 + (root.kickLevel * 0.055)) : 0.0
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

        Visualizer {
            anchors.centerIn: parent
            width: (coverHost.artRadius + coverHost.maxBarHeight * 1.4) * 2 + 2
            height: width
            active: root.cavaRegistered
            count: root.barCount
            color: ThemeBackend.mauve || "#cba6f7"
            mirrored: false
            curve: 1.15
            threshold: 0.0
            gamma: 1.08
            rise: 0.55
            fall: 0.55
            ringRadius: coverHost.artRadius
            ringBarWidth: coverHost.barWidth
            maxLength: coverHost.maxBarHeight * 1.4
            minLength: root.s(2)
            opacityBase: 0.4
            opacityRange: 0.6
            tintStrength: 0.45
        }

        Item {
            id: discContainer
            anchors.fill: parent

            property real borderWidth: 0

            Rectangle {
                z: -1
                anchors.centerIn: parent
                width: parent.width + root.s(12)
                height: parent.height + root.s(12)
                radius: width / 2
                color: ThemeBackend.mauve || "#cba6f7"
                opacity: (root.targetPlayer && root.targetPlayer.isPlaying) ? (0.35 + root.kickLevel * 0.25) : 0.0
                Behavior on opacity { NumberAnimation { duration: 500 } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 1.0
                }
            }

            Rectangle {
                id: vinylBase
                anchors.fill: parent
                radius: width / 2
                color: ThemeBackend.surface1 || "#45475a"
                border.width: discContainer.borderWidth
                border.color: (root.targetPlayer && root.targetPlayer.isPlaying) ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.overlay0 || "#6c7086")
                Behavior on border.color { ColorAnimation { duration: 500 } }

                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 25000
                    loops: Animation.Infinite
                    running: root.active
                    paused: root.active && !(root.targetPlayer && root.targetPlayer.isPlaying)
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: vinylBase.border.width

                    Rectangle {
                        id: maskRect
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true 
                    }

                    Item {
                        id: artMaskedContainer
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: maskRect
                        }

                        Item {
                            id: artCrossfader
                            anchors.fill: parent
                            property string artSource: root.activeArtUrl ? (root.activeArtUrl.startsWith("file://") || root.activeArtUrl.startsWith("http") ? root.activeArtUrl : "file://" + root.activeArtUrl) : ""
                            property bool showingA: true

                            Image {
                                id: artImgA
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                opacity: artCrossfader.showingA && status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }
                            }

                            Image {
                                id: artImgB
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                opacity: !artCrossfader.showingA && status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.InOutQuad } }
                            }

                            onArtSourceChanged: {
                                if (!artSource) {
                                    artImgA.source = "";
                                    artImgB.source = "";
                                    return;
                                }
                                if (showingA) {
                                    artImgB.source = artSource;
                                    showingA = false;
                                } else {
                                    artImgA.source = artSource;
                                    showingA = true;
                                }
                            }

                            Component.onCompleted: {
                                if (artSource) {
                                    artImgA.source = artSource;
                                    showingA = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: fallbackPlaceholder
                        anchors.fill: parent
                        radius: width / 2
                        color: ThemeBackend.mantle || "#1e1e2e"
                        opacity: (root.hasTargetPlayer && root.activeArtUrl) ? 0.0 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 400 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            font.pixelSize: parent.width * 0.26
                            color: ThemeBackend.overlay1 || "#7f849c"
                        }
                    }

                    Rectangle {
                        id: discTinter
                        anchors.fill: parent
                        radius: width / 2
                        color: {
                            let m = ThemeBackend.mauve || Qt.rgba(0.8, 0.6, 0.9, 1);
                            return Qt.rgba(m.r, m.g, m.b, 0.08 + (root.kickLevel * 0.08));
                        }
                        opacity: (root.hasTargetPlayer && root.activeArtUrl) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 600 } }
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
                        color: ThemeBackend.crust || "#11111b"
                        opacity: 0.96
                        scale: 1.0 + (root.kickLevel * 0.0135)
                        border.width: 1.5
                        border.color: {
                            let m = ThemeBackend.mauve || Qt.rgba(0.8, 0.6, 0.9, 1);
                            return Qt.rgba(m.r, m.g, m.b, 0.45 + (root.kickLevel * 0.4));
                        }

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
                            color: ThemeBackend.surface2 || "#585b70"
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
