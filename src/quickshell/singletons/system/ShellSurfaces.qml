pragma Singleton
import QtQuick
import "../../"

QtObject {
    id: root

    readonly property var bars: SurfaceRegistry.windows["bars"] || ({})
    readonly property var docks: SurfaceRegistry.windows["docks"] || ({})

    function register(kind, screenName, window) {
        SurfaceRegistry.registerWindow(kind, screenName, window);
    }

    function unregister(kind, screenName, window) {
        SurfaceRegistry.unregisterWindow(kind, screenName, window);
    }
}
