import QtQuick
import Quickshell

Variants {
    model: Quickshell.screens

    delegate: Component {
        Scope {
            id: dockScope
            required property var modelData

            DockExclusionWindow {
                modelData: dockScope.modelData
                dockWindow: dockPanel
            }

            DockWindow {
                id: dockPanel
                modelData: dockScope.modelData
            }
        }
    }
}
