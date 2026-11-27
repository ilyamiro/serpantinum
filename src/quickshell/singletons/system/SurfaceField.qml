pragma Singleton
import QtQuick
import "../../"

QtObject {
    id: root

    readonly property var shapes: SurfaceRegistry.shapes
    readonly property int revision: SurfaceRegistry.revision

    function publish(screenName, id, shape) {
        SurfaceRegistry.publishShape(screenName, id, shape);
    }

    function withdraw(screenName, id) {
        SurfaceRegistry.withdrawShape(screenName, id);
    }

    function shapesOn(screenName) {
        return SurfaceRegistry.shapesOn(screenName);
    }
}
