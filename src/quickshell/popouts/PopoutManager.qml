import QtQuick
import Quickshell
import "../reusables"
import "../"

Scope {
    id: root

    IdleLazyLoader {
        wanted: OsdController.isVisible
        Osd {}
    }
    IdleLazyLoader {
        wanted: TrayMenuController.isVisible
        TrayBase {}
    }
    IdleLazyLoader {
        wanted: SideMusicController.isVisible
        SideMusicPopout {}
    }
    IdleLazyLoader {
        wanted: DesktopMenuController.isVisible
        DesktopMenu {}
    }
    IdleLazyLoader {
        wanted: DockAppMenuController.isVisible
        DockAppMenu {}
    }
}
