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

    LockScreen {
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
