import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../"
import "../"
import "glassNesting.js" as Nesting

Item {
    id: root

    property real radius: ThemeBackend.borderRadius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property real blurStrength: 1.0
    property real tint: 0.0
    property real rim: 0.45
    property vector2d filletDir: Qt.vector2d(0, 0)
    property real filletRadius: 0
    property real filletInset: 0
    property bool earsOnly: false
    property rect boxRect: Qt.rect(0, 0, 0, 0)
    property Item maskItem: null
    property real bezelSize: Math.max(5, Math.min(26, Math.min(width, height) * 0.36))

    readonly property bool liquid: ThemeBackend.liquidGlass
    readonly property real blurPad: liquid ? 0 : 64
    readonly property bool isGlassBackdrop: true
    readonly property Item texture: sceneLoader.item ? sceneLoader.item.texture : null
    property int consumers: 0
    property int nestLevel: 0
    readonly property real nest: Math.min(1, nestLevel * 0.5)

    property bool standalone: false
    property bool surfaceEnabled: true

    Component.onCompleted: {
        inheritedOwner = findInheritedOwner();
        nestLevel = (standalone || inheritedOwner !== null) ? 0 : Nesting.nestLevel(root, null, true);
    }
    readonly property bool transitioning: engine ? (engine.transitionProgress > 0.0 && engine.transitionProgress < 1.0) : false
    property int frame: 0

    property var screenOverride: null
    property bool useSnapshot: false
    property Item inheritedOwner: null
    readonly property var inheritedScreen: inheritedOwner ? inheritedOwner.glassScreen : null

    function findInheritedOwner() {
        let e = root.parent;
        let d = 0;
        while (e && d < 64) {
            if (e.glassScreen !== undefined) return e;
            e = e.parent;
            d++;
        }
        return null;
    }

    onParentChanged: inheritedOwner = findInheritedOwner()
    readonly property var effectiveScreenOverride: screenOverride ? screenOverride : inheritedScreen
    readonly property bool snapshotMode: useSnapshot || inheritedOwner !== null

    readonly property var hostWindow: QsWindow.window
    readonly property var hostScreen: effectiveScreenOverride ? effectiveScreenOverride : (hostWindow ? hostWindow.screen : null)
    readonly property string screenName: hostScreen && hostScreen.name ? hostScreen.name : ""
    readonly property bool parentVisible: parent ? parent.visible : true
    readonly property bool active: surfaceEnabled && parentVisible && ThemeBackend.blurBackground && ThemeBackend.elementOpacity < 0.999 && width > 0 && height > 0 && hostScreen !== null && (hostWindow ? hostWindow.visible : true)

    readonly property var engine: snapshotMode ? null : (Wallpaper.engines[screenName] || null)

    property real imageX: 0
    property real imageY: 0
    property real imageScale: 1
    property real imageRotation: 0
    property rect validRect: Qt.rect(0, 0, 1, 1)
    property int revision: 0

    readonly property string snapshotDir: Caching.getCacheDir("wallpaper")
    readonly property string snapshotPath: snapshotDir + (screenName !== "" ? "/current_wallpaper_" + screenName + ".png" : "/current_wallpaper.png")
    readonly property string snapshotUrl: "file://" + snapshotPath + "?rev=" + revision

    function layerSource(slot) {
        if (!root.active) return "";
        if (!root.engine) return slot === 0 ? root.snapshotUrl : "";
        const e = root.engine;
        if (slot === 0) {
            if (e.isVideoA) return e.snapReadyA ? "file://" + e.layerSnapshotPathA + "?rev=" + e.snapRevA : "";
            return e.pathA !== "" ? "file://" + e.pathA : "";
        }
        if (e.isVideoB) return e.snapReadyB ? "file://" + e.layerSnapshotPathB + "?rev=" + e.snapRevB : "";
        return e.pathB !== "" ? "file://" + e.pathB : "";
    }

    readonly property int incomingSlot: engine ? engine.activeLayer : 0
    readonly property string newSource: layerSource(incomingSlot)
    readonly property string oldSource: engine ? layerSource(incomingSlot === 0 ? 1 : 0) : ""
    readonly property real screenWidth: hostScreen ? hostScreen.width : 1
    readonly property real screenHeight: hostScreen ? hostScreen.height : 1
    readonly property size textureSize: Qt.size(Math.max(1, Math.round(screenWidth / (liquid ? 2 : 4))), Math.max(1, Math.round(screenHeight / (liquid ? 2 : 4))))

    visible: active
    clip: false

    function refreshTexture() {
        if (root.liquid && root.consumers > 0 && root.texture) root.texture.scheduleUpdate();
    }

    onImageXChanged: refreshTexture()
    onImageYChanged: refreshTexture()
    onImageScaleChanged: refreshTexture()
    onImageRotationChanged: refreshTexture()
    onWidthChanged: refreshTexture()
    onHeightChanged: refreshTexture()
    onNewSourceChanged: refreshTexture()
    onOldSourceChanged: refreshTexture()
    onRevisionChanged: refreshTexture()
    onConsumersChanged: refreshTexture()
    onLiquidChanged: refreshTexture()
    onTintChanged: refreshTexture()
    onBlurStrengthChanged: refreshTexture()

    property var geoSig: [NaN, 0, 0, 0, 0, 0, 0, 0]

    function refreshGeometry() {
        const w = root.hostWindow;
        const scr = root.hostScreen;
        if (!scr) return;
        let wx = 0;
        let wy = 0;
        if (w && w.anchors && !root.effectiveScreenOverride) {
            const a = w.anchors;
            const m = w.margins;
            if (a.left) wx = m.left;
            else if (a.right) wx = scr.width - w.width - m.right;
            else wx = (scr.width - w.width) / 2;
            if (a.top) wy = m.top;
            else if (a.bottom) wy = scr.height - w.height - m.bottom;
            else wy = (scr.height - w.height) / 2;
        }
        const p0 = root.mapFromItem(null, -wx, -wy);
        const px = root.mapFromItem(null, 1 - wx, -wy);
        const gs = root.geoSig;
        if (p0.x === gs[0] && p0.y === gs[1] && px.x === gs[2] && px.y === gs[3] && scr.width === gs[4] && scr.height === gs[5] && root.width === gs[6] && root.height === gs[7]) return;
        gs[0] = p0.x; gs[1] = p0.y; gs[2] = px.x; gs[3] = px.y; gs[4] = scr.width; gs[5] = scr.height; gs[6] = root.width; gs[7] = root.height;
        const dx = px.x - p0.x;
        const dy = px.y - p0.y;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (!isFinite(len) || len <= 0) return;
        root.imageX = p0.x;
        root.imageY = p0.y;
        root.imageScale = len;
        root.imageRotation = Math.atan2(dy, dx) * 180 / Math.PI;
        const p1 = root.mapFromItem(null, scr.width - wx, scr.height - wy);
        const iw = Math.max(1, root.width);
        const ih = Math.max(1, root.height);
        const x0 = Math.max(0, Math.min(1, Math.min(p0.x, p1.x) / iw));
        const y0 = Math.max(0, Math.min(1, Math.min(p0.y, p1.y) / ih));
        const x1 = Math.max(x0, Math.min(1, Math.max(p0.x, p1.x) / iw));
        const y1 = Math.max(y0, Math.min(1, Math.max(p0.y, p1.y) / ih));
        if (x0 !== root.validRect.x || y0 !== root.validRect.y || x1 - x0 !== root.validRect.width || y1 - y0 !== root.validRect.height)
            root.validRect = Qt.rect(x0, y0, x1 - x0, y1 - y0);
    }

    FrameAnimation {
        running: root.active
        onTriggered: {
            root.refreshGeometry();
            if (root.consumers > 0) root.frame++;
        }
    }

    onActiveChanged: {
        if (active) refreshGeometry();
    }

    FileView {
        path: root.active ? root.snapshotPath : ""
        watchChanges: true
        onFileChanged: root.revision++
    }

    Loader {
        id: sceneLoader
        anchors.fill: parent
        active: root.active
        onLoaded: root.refreshTexture()
        sourceComponent: Component {
            Item {
                property alias texture: glassTexture

                Item {
                    id: oldLayer
                    width: root.screenWidth
                    height: root.screenHeight
                    visible: false
                    layer.enabled: true
                    layer.textureSize: root.textureSize
                    layer.smooth: true

                    Image {
                        anchors.fill: parent
                        source: root.oldSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize: root.textureSize
                        onStatusChanged: root.refreshTexture()
                    }
                }

                Item {
                    id: newLayer
                    width: root.screenWidth
                    height: root.screenHeight
                    visible: false
                    layer.enabled: true
                    layer.textureSize: root.textureSize
                    layer.smooth: true

                    Image {
                        anchors.fill: parent
                        source: root.newSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize: root.textureSize
                        onStatusChanged: root.refreshTexture()
                    }
                }

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: -root.blurPad
                    visible: false
                    layer.enabled: true
                    layer.mipmap: root.liquid
                    layer.smooth: true

                    ShaderEffect {
                        id: blend
                        x: root.imageX + root.blurPad
                        y: root.imageY + root.blurPad
                        width: root.screenWidth
                        height: root.screenHeight
                        scale: root.imageScale
                        transformOrigin: Item.TopLeft
                        rotation: root.imageRotation

                        property variant oldTex: oldLayer
                        property variant newTex: newLayer
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real progress: root.engine ? (root.engine.isPreloading ? -1.0 : root.engine.transitionProgress) : 1.0
                        property real transitionType: root.engine ? root.engine.activeTransitionType : 0
                        property vector2d origin: Qt.vector2d(root.engine ? root.engine.transitionOriginX : 0.5, root.engine ? root.engine.transitionOriginY : 0.5)
                        property vector4d params: Qt.vector4d(root.engine && root.engine.wipeIsVertical ? 1.0 : 0.0, root.engine ? root.engine.swipeDirection : 0, 0.0, 0.0)

                        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/transitions/wallpaper_blend.frag.qsb"
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: root.tint > 0
                        color: Qt.alpha(ThemeBackend.base, root.tint)
                    }
                }

                Item {
                    id: rendered
                    anchors.fill: parent

                    MultiEffect {
                        id: blurred
                        x: -root.blurPad
                        y: -root.blurPad
                        width: root.width + 2 * root.blurPad
                        height: root.height + 2 * root.blurPad
                        visible: false
                        source: root.liquid ? null : content
                        autoPaddingEnabled: false
                        blurEnabled: !root.liquid
                        blurMax: 64
                        blur: Math.min(1.0, root.blurStrength)
                    }

                    ShaderEffectSource {
                        id: blurCrop
                        anchors.fill: parent
                        visible: false
                        sourceItem: root.liquid ? null : blurred
                        sourceRect: Qt.rect(root.blurPad, root.blurPad, root.width, root.height)
                        smooth: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        visible: !root.liquid && root.maskItem !== null
                        source: visible ? blurCrop : null
                        maskEnabled: true
                        maskSource: root.maskItem
                    }

                    ShaderEffect {
                        anchors.fill: parent
                        visible: !root.liquid && root.maskItem === null
                        property variant src: blurCrop
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
                        property real fillAlpha: Math.min(0.98, ThemeBackend.elementOpacity)
                        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/rounded_mask.frag.qsb"
                    }

                    LiquidGlass {
                        id: glassEffect
                        anchors.fill: parent
                        visible: root.liquid
                        src: content
                        topLeftRadius: root.topLeftRadius
                        topRightRadius: root.topRightRadius
                        bottomLeftRadius: root.bottomLeftRadius
                        bottomRightRadius: root.bottomRightRadius
                        tintColor: ThemeBackend.base
                        tintAmount: Math.max(root.tint, 0.12) * (1 - 0.5 * root.nest)
                        frost: Math.max(0.5, root.blurStrength * 2.5) * 1.08 * (1 - 0.5 * root.nest)
                        rim: root.rim * (1 - 0.35 * root.nest)
                        nest: root.nest
                        bezel: root.bezelSize
                        filletDir: root.filletDir
                        filletRadius: root.filletRadius
                        filletInset: root.filletInset
                        earsOnly: root.earsOnly
                        boxRect: root.boxRect
                        validRect: root.validRect
                        unpremul: 1
                        clear: root.nestLevel >= 1 ? 1 : 0
                        cursorPos: Qt.point(root.cursorX, root.cursorY)
                        hover: root.hoverAmount
                    }
                }

                ShaderEffectSource {
                    id: glassTexture
                    anchors.fill: parent
                    sourceItem: rendered
                    live: root.liquid && root.consumers > 0 && root.transitioning
                    mipmap: true
                    visible: false
                    smooth: true
                    format: ShaderEffectSource.RGBA8
                }
            }
        }
    }

    HoverHandler {
        id: pointer
        enabled: root.liquid && root.active
    }

    property real hoverAmount: pointer.hovered ? 1.0 : 0.0
    Behavior on hoverAmount { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    property real cursorX: width / 2
    property real cursorY: height / 2
    Behavior on cursorX { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on cursorY { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Connections {
        target: pointer
        function onPointChanged() {
            if (pointer.hovered) {
                root.cursorX = pointer.point.position.x;
                root.cursorY = pointer.point.position.y;
            }
        }
    }
}
