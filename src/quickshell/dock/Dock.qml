import QtQuick
import Quickshell
import "../"

Scope {
    id: dockRoot

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { dockRoot.configRevision++; }
        function onDataReadyChanged() { dockRoot.configRevision++; }
        function onRawSettingsChanged() { dockRoot.configRevision++; }
    }

    readonly property bool dockEnabled: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.dataReady === false) return false;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock && Config.rawSettings.dock.enabled !== undefined) {
            return Boolean(Config.rawSettings.dock.enabled);
        }
        return true;
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: dockScope
                required property var modelData

                LazyLoader {
                    active: dockRoot.dockEnabled

                    Scope {
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
        }
    }
}
