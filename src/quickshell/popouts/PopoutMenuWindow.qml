import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: popoutWin

    property bool menuOpen: false
    property real anchorX: 0
    property real anchorY: 0
    property real menuX: 0
    property real menuY: 0
    property real menuWidth: s(200)
    property real menuHeight: 0
    property int openDuration: 150
    property int closeDuration: 75
    property real overshoot: 1.05

    property alias animProgress: menuContainer.animProgress
    property alias containerItem: menuContainer
    property alias rootContainerItem: rootContainer
    default property alias menuContent: menuContainer.data

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: menuOpen || menuContainer.animProgress > 0.001

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: (popoutWin.menuOpen || menuContainer.animProgress > 0.001) ? maskTarget : null
    }

    function s(val) {
        return Scaler.s(val);
    }

    function restartOpenAnim() {
        closeAnim.stop();
        openAnim.restart();
    }

    function startCloseAnim() {
        openAnim.stop();
        closeAnim.restart();
    }

    onMenuOpenChanged: {
        if (menuOpen) {
            restartOpenAnim();
        } else {
            startCloseAnim();
        }
    }

    Item {
        id: rootContainer
        anchors.fill: parent

        Item {
            id: maskTarget
            x: popoutWin.menuX
            y: popoutWin.menuY
            width: popoutWin.menuWidth
            height: popoutWin.menuHeight
        }

        Item {
            id: menuContainer

            property real animProgress: 0.0

            NumberAnimation {
                id: openAnim
                target: menuContainer
                property: "animProgress"
                from: menuContainer.animProgress > 0.8 ? 0.2 : 0.0
                to: 1.0
                duration: popoutWin.openDuration
                easing.type: Easing.OutBack
                easing.overshoot: popoutWin.overshoot
            }

            NumberAnimation {
                id: closeAnim
                target: menuContainer
                property: "animProgress"
                to: 0.0
                duration: popoutWin.closeDuration
                easing.type: Easing.InCubic
                onFinished: {
                    if (!popoutWin.menuOpen) {
                        menuContainer.animProgress = 0.0;
                    }
                }
            }

            x: popoutWin.menuX
            y: popoutWin.menuY
            width: popoutWin.menuWidth
            height: popoutWin.menuHeight

            opacity: Math.max(0.0, Math.min(1.0, animProgress * 2.5))

            transform: Scale {
                origin.x: popoutWin.anchorX - popoutWin.menuX
                origin.y: popoutWin.anchorY - popoutWin.menuY
                xScale: Math.max(0.0, menuContainer.animProgress)
                yScale: Math.max(0.0, menuContainer.animProgress)
            }
        }
    }
}
