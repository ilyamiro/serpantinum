import QtQuick
import "PetArt.js" as Art

Canvas {
    id: root

    property var scene: null
    property var colors: ({})
    property int px: 3

    width: (scene ? scene.cw : Art.CW) * px
    height: (scene ? scene.ch : Art.CH) * px
    smooth: false
    antialiasing: false

    onSceneChanged: requestPaint()
    onColorsChanged: requestPaint()
    onPxChanged: requestPaint()

    onPaint: {
        let ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (root.scene && root.colors) Art.paint(ctx, root.scene, root.colors, root.px);
    }
}
