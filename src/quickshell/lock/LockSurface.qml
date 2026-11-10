import QtQuick
import QtQuick.Window
import Quickshell.Wayland

WlSessionLockSurface {
    id: lockSurface
    required property var sRoot
    required property var sRootLock
    required property var sPam
    required property var sLockUI
    required property var sSuspendProcess
    required property var sReloadProcess
    required property var sPoweroffProcess

    property int framesSwapped: 0

    Connections {
        target: lockScreen.Window.window
        enabled: lockSurface.framesSwapped < 2
        function onFrameSwapped() {
            lockSurface.framesSwapped++;
            if (lockSurface.framesSwapped === 1) lockScreen.Window.window.update();
            else lockSurface.sRoot.surfaceShown();
        }
    }

    LockScreen {
        id: lockScreen
        surface: lockSurface
        root: lockSurface.sRoot
        rootLock: lockSurface.sRootLock
        pam: lockSurface.sPam
        lockUI: lockSurface.sLockUI
        suspendProcess: lockSurface.sSuspendProcess
        reloadProcess: lockSurface.sReloadProcess
        poweroffProcess: lockSurface.sPoweroffProcess
    }
}
