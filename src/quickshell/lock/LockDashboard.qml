import QtQuick
import QtQuick.Window
import "../"
import "../reusables"
import "redactor"
import "redactor/elements"

Item {
    id: dashboard
    required property var screenRoot
    readonly property var passwordInput: panelView.passwordInput ? panelView.passwordInput : (fallbackPassword.item ? fallbackPassword.item.input : null)

    readonly property real fit: Math.min(width / LockLayoutStore.refW, height / LockLayoutStore.refH)
    readonly property real coreWidth: Math.min(LockLayoutStore.panelW, screenRoot.s(440))
    readonly property real shellWidth: dashboard.coreWidth + screenRoot.wingsReveal * (LockLayoutStore.panelW - dashboard.coreWidth)
    readonly property real panelLeft: LockLayoutStore.panelX >= 0 ? LockLayoutStore.panelX : (LockLayoutStore.refW - LockLayoutStore.panelW) / 2
    readonly property real panelTop: LockLayoutStore.panelY >= 0 ? LockLayoutStore.panelY : (LockLayoutStore.refH - LockLayoutStore.panelH) / 2

    anchors.fill: parent

    Item {
        width: LockLayoutStore.refW
        height: LockLayoutStore.refH
        anchors.centerIn: parent
        scale: dashboard.fit

        Rectangle {
            id: mainDashboardShellShadow
            x: mainDashboardShell.x
            y: mainDashboardShell.y + screenRoot.s(1.5)
            width: mainDashboardShell.width
            height: mainDashboardShell.height
            radius: mainDashboardShell.radius
            color: Qt.rgba(0, 0, 0, 0.14 * LockLayoutStore.panelOpacity)
            opacity: mainDashboardShell.opacity
            scale: mainDashboardShell.scale
            visible: mainDashboardShell.visible
            transform: Scale {
                origin.x: mainDashboardShell.width / 2
                origin.y: mainDashboardShell.height / 2
                xScale: screenRoot.isUnlocking ? screenRoot.foldScaleX : 1.0
                yScale: screenRoot.isUnlocking ? screenRoot.foldScaleY : 1.0
            }
        }

        Rectangle {
            id: mainDashboardShell
            x: dashboard.panelLeft + (LockLayoutStore.panelW - dashboard.shellWidth) / 2
            y: dashboard.panelTop + (screenRoot.inputActive ? 0 : screenRoot.s(90))
            width: dashboard.shellWidth
            height: LockLayoutStore.panelH
            radius: ThemeBackend.borderRadius * 1.5
            color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity * LockLayoutStore.panelOpacity)
            clip: true

            opacity: screenRoot.centerReveal
            scale: 0.92 + (screenRoot.centerReveal * 0.08)
            visible: opacity > 0.01

            transform: Scale {
                origin.x: mainDashboardShell.width / 2
                origin.y: mainDashboardShell.height / 2
                xScale: screenRoot.isUnlocking ? screenRoot.foldScaleX : 1.0
                yScale: screenRoot.isUnlocking ? screenRoot.foldScaleY : 1.0
            }

            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: mainDashboardShell.radius
                opacity: LockLayoutStore.panelOpacity
                screenOverride: screenRoot.surface.screen
                useSnapshot: true
            }

            LockLayoutView {
                id: panelView
                x: (mainDashboardShell.width - LockLayoutStore.panelW) / 2
                width: LockLayoutStore.panelW
                height: LockLayoutStore.panelH
                scope: "panel"
                reveal: screenRoot.wingsReveal
                coreLeft: (LockLayoutStore.panelW - dashboard.coreWidth) / 2
                coreRight: (LockLayoutStore.panelW + dashboard.coreWidth) / 2
                ctx: dashboard.screenRoot
            }
        }
    }

    Loader {
        id: fallbackPassword
        active: panelView.passwordInput === null
        width: screenRoot.s(380)
        height: screenRoot.s(44)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2
        visible: screenRoot.centerReveal > 0.01
        sourceComponent: LockPasswordElement { ctx: dashboard.screenRoot }

        onLoaded: item.ctx = Qt.binding(() => dashboard.screenRoot)
    }

    Connections {
        target: screenRoot.lockUI
        function onFailedChanged() {
            if (screenRoot.lockUI.failed && dashboard.passwordInput) {
                dashboard.passwordInput.triggerShake();
                dashboard.passwordInput.clear();
                screenRoot.restoreFocus();
            }
        }
    }
}
