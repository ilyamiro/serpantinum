import QtQuick
import Quickshell
import "../../"
import "../../widgets"
import "../../reusables/canvas"
import "../../reusables/canvas/CanvasGeometry.js" as CanvasGeometry

Item {
    id: scene

    property string scope: "screen"
    property real k: 0.5
    property bool active: false
    property bool gridEnabled: false
    property string selectedId: ""
    property Item selectedProxy: null
    property bool dragging: false
    property bool handleBlank: true
    property var guideLines: []
    property var measureLines: []

    signal imagePickRequested(string itemType, string itemId, string currentPath, bool rounded)
    signal blankClicked()

    readonly property var itemsModel: LockLayoutStore.modelFor(scene.scope)
    readonly property real gridStep: Scaler.s(20)
    readonly property real unit: 1 / Math.max(scene.k, 0.05)
    readonly property real snapThreshold: 12 * scene.unit
    readonly property bool showDistances: !(typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.widgets && Config.rawSettings.widgets.showDistances === false)
    readonly property var selectedWidget: scene.selectedProxy ? scene.selectedProxy.faceItem : null
    readonly property var currentWidget: scene.selectedWidget
    readonly property var activeWidget: scene.selectedWidget

    function indexOfId(id) {
        let m = scene.itemsModel;
        for (let i = 0; i < m.count; i++) {
            if (m.get(i).iid === id) return i;
        }
        return -1;
    }

    function proxyAt(index) {
        return itemRepeater.itemAt(index);
    }

    function otherBoxes(excluded) {
        return CanvasGeometry.otherBoxesFromRepeater(itemRepeater, excluded);
    }

    function presentOverlay(item, box, snap) {
        let overlay = CanvasGeometry.buildOverlay(box, otherBoxes(item), snap, scene.width, scene.height, scene.unit, scene.showDistances);
        scene.guideLines = overlay.guideLines;
        scene.measureLines = overlay.measureLines;
    }

    function clearOverlay() {
        if (scene.guideLines.length > 0) scene.guideLines = [];
        if (scene.measureLines.length > 0) scene.measureLines = [];
    }

    function constraints(proxy) {
        let lim = LockElementRegistry.limits(proxy.pType);
        if (lim) return CanvasGeometry.extractConstraints(null, lim);
        if (proxy.scaled) {
            let a = proxy.refH > 0 ? proxy.refW / proxy.refH : 1;
            return { minW: proxy.refW * 0.3, minH: proxy.refH * 0.3, maxW: proxy.refW * 3, maxH: proxy.refH * 3, minA: a, maxA: a };
        }
        return CanvasGeometry.extractConstraints(proxy.faceItem);
    }

    function snapAllToGrid() {
        for (let i = 0; i < itemRepeater.count; i++) {
            let p = itemRepeater.itemAt(i);
            if (!p || p.rot90) continue;
            let res = CanvasGeometry.snapBoxToGrid(scene.constraints(p), p.x, p.y, p.width, p.height, scene.width, scene.height, scene.gridStep);
            scene.itemsModel.setProperty(i, "ix", res.x);
            scene.itemsModel.setProperty(i, "iy", res.y);
            scene.itemsModel.setProperty(i, "iw", res.w);
            scene.itemsModel.setProperty(i, "ih", res.h);
        }
        LockLayoutStore.touch();
    }

    function removeItem(id) {
        if (scene.selectedId === id) scene.selectedId = "";
        LockLayoutStore.removeItem(id);
    }

    function removeSelected() {
        if (scene.selectedId === "") return;
        let i = scene.indexOfId(scene.selectedId);
        if (i < 0 || !LockElementRegistry.isDeletable(scene.itemsModel.get(i).itype)) return;
        scene.removeItem(scene.selectedId);
    }

    function setWidgetProperty(propName, val, targetId) {
        let tid = targetId || scene.selectedId;
        let i = scene.indexOfId(tid);
        if (i < 0) return;
        scene.itemsModel.setProperty(i, propName, val);
        let proxy = itemRepeater.itemAt(i);
        if (proxy && proxy.faceItem) {
            try {
                if (proxy.faceItem[propName] !== undefined) proxy.faceItem[propName] = val;
            } catch (e) {}
        }
        LockLayoutStore.touch();
    }

    function handleAdditionalAction(action, proxy, extraArg) {
        if (!proxy) return;
        let idx = proxy.pIndex;
        CanvasGeometry.handleGeometryAction(action, {
            safeWidth: scene.width,
            safeHeight: scene.height,
            isRotated90: proxy.rot90,
            gap: 50,
            extraArg: extraArg,
            pickImage: () => {
                let circleMask = LockElementRegistry.variantCircleMask(proxy.pType, proxy.pVariant);
                scene.imagePickRequested(proxy.pType, proxy.pId, proxy.pImage, circleMask);
            },
            setGeometry: (patch) => {
                if (patch.x !== undefined) scene.itemsModel.setProperty(idx, "ix", patch.x);
                if (patch.y !== undefined) scene.itemsModel.setProperty(idx, "iy", patch.y);
                if (patch.w !== undefined) scene.itemsModel.setProperty(idx, "iw", patch.w);
                if (patch.h !== undefined) scene.itemsModel.setProperty(idx, "ih", patch.h);
                proxy.finalizeSync();
            },
            setProperty: (prop, val) => scene.setWidgetProperty(prop, val, proxy.pId)
        });
    }

    MouseArea {
        anchors.fill: parent
        z: -3
        enabled: scene.handleBlank
        onClicked: {
            scene.selectedId = "";
            scene.blankClicked();
        }
    }

    GridOverlay {
        anchors.fill: parent
        z: -2
        gridActive: scene.gridEnabled
        stepSize: scene.gridStep
        lineWidth: scene.unit
        lineColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.14)
    }

    SnapOverlay {
        guideLines: scene.guideLines
        measureLines: scene.measureLines
        unit: scene.unit
    }

    Repeater {
        id: itemRepeater
        model: scene.itemsModel

        delegate: Item {
            id: proxy

            readonly property string pId: model.iid
            readonly property string pType: model.itype
            readonly property string pVariant: model.ivariant
            readonly property string pImage: model.iimage
            readonly property real pRotation: model.irotation ?? 0
            readonly property real pOpacity: model.iopacity ?? 1
            readonly property real gX: model.ix ?? 0
            readonly property real gY: model.iy ?? 0
            readonly property real gW: model.iw ?? 0
            readonly property real gH: model.ih ?? 0
            readonly property int pIndex: index
            readonly property var rowData: (index >= 0 && index < scene.itemsModel.count) ? scene.itemsModel.get(index) : null
            readonly property bool isSelected: scene.selectedId === proxy.pId
            readonly property bool rot90: Math.abs(Math.round(proxy.pRotation)) % 180 !== 0
            readonly property bool scaled: LockElementRegistry.isScaled(proxy.pType)
            readonly property bool deletable: LockElementRegistry.isDeletable(proxy.pType)
            readonly property Item faceItem: faceLoader.item
            readonly property real faceIW: faceLoader.item ? faceLoader.item.implicitWidth : 0
            readonly property real faceIH: faceLoader.item ? faceLoader.item.implicitHeight : 0
            readonly property bool aspectLocked: {
                let lim = LockElementRegistry.limits(proxy.pType);
                if (lim) return lim.aspect > 0;
                if (proxy.scaled) return true;
                let f = proxy.faceItem;
                return !!f && f.minAspect !== undefined && f.maxAspect !== undefined && f.minAspect === f.maxAspect && f.minAspect > 0;
            }
            readonly property real lockedAspectValue: {
                if (!proxy.aspectLocked) return 0;
                let lim = LockElementRegistry.limits(proxy.pType);
                if (lim && lim.aspect > 0) return lim.aspect;
                if (proxy.scaled && proxy.refH > 0) return proxy.refW / proxy.refH;
                let f = proxy.faceItem;
                return (f && f.minAspect > 0) ? f.minAspect : 0;
            }

            property real refW: 0
            property real refH: 0
            property real scaleMem: 1
            property bool needsRef: true
            property bool variantSwitch: false
            property bool hasUnsynced: false
            property var savedAspects: ({})
            property real resizeStartW: 0
            property real resizeStartH: 0
            property real resizeStartX: 0
            property real resizeStartY: 0

            x: proxy.gX
            y: proxy.gY
            width: proxy.rot90 ? proxy.gH : proxy.gW
            height: proxy.rot90 ? proxy.gW : proxy.gH
            z: (proxy.isSelected ? 50000 : 0) + index
            opacity: (scene.selectedId === "" || proxy.isSelected) ? 1.0 : 0.6
            Behavior on opacity { NumberAnimation { duration: 150 } }

            onIsSelectedChanged: {
                if (proxy.isSelected) {
                    scene.selectedProxy = proxy;
                } else if (scene.selectedProxy === proxy) {
                    scene.selectedProxy = null;
                }
            }

            Component.onCompleted: {
                if (proxy.isSelected) scene.selectedProxy = proxy;
            }

            onFaceIWChanged: proxy.settleScaled()
            onFaceIHChanged: proxy.settleScaled()

            function applyVariantAndCustomProps() {
                let it = faceLoader.item;
                if (!it) return;
                let vProps = LockElementRegistry.variantProps(proxy.pType, proxy.pVariant);
                if (vProps) CanvasGeometry.applyCustomProps(it, vProps);
                let row = (proxy.pIndex >= 0 && proxy.pIndex < scene.itemsModel.count) ? scene.itemsModel.get(proxy.pIndex) : null;
                if (row) CanvasGeometry.applyCustomProps(it, row, LockLayoutStore.standardKeys);
            }

            Connections {
                target: LockLayoutStore
                function onRevisionChanged() {
                    proxy.applyVariantAndCustomProps();
                }
            }

            function settleScaled() {
                if (!proxy.scaled || !proxy.needsRef || proxy.faceIW <= 0 || proxy.faceIH <= 0) return;
                proxy.needsRef = false;
                proxy.refW = proxy.faceIW;
                proxy.refH = proxy.faceIH;
                if (model.iw <= 0 || model.ih <= 0) {
                    model.ix = model.ix - proxy.refW / 2;
                    model.iy = model.iy - proxy.refH / 2;
                    model.iw = proxy.refW;
                    model.ih = proxy.refH;
                    proxy.scaleMem = 1;
                    proxy.finalizeSync();
                } else if (proxy.variantSwitch) {
                    model.iw = proxy.refW * proxy.scaleMem;
                    model.ih = proxy.refH * proxy.scaleMem;
                    proxy.variantSwitch = false;
                    proxy.finalizeSync();
                } else {
                    proxy.scaleMem = model.iw / proxy.refW;
                }
            }

            function bringToFront() {
                let last = scene.itemsModel.count - 1;
                if (proxy.pIndex < last) scene.itemsModel.move(proxy.pIndex, last, 1);
            }

            function triggerSync() {
                proxy.hasUnsynced = true;
                if (!syncTimer.running) syncTimer.restart();
            }

            function finalizeSync() {
                scene.clearOverlay();
                syncTimer.stop();
                proxy.hasUnsynced = false;
                if (proxy.scaled && proxy.refW > 0) proxy.scaleMem = model.iw / proxy.refW;
                LockLayoutStore.touch();
            }

            Timer {
                id: syncTimer
                interval: 100
                repeat: true
                onTriggered: {
                    if (!proxy.hasUnsynced) {
                        running = false;
                        return;
                    }
                    proxy.hasUnsynced = false;
                    LockLayoutStore.touch();
                }
            }

            function getDefaultSize() {
                if (proxy.scaled) return { w: proxy.refW, h: proxy.refH };
                let def = LockElementRegistry.defaultSize(proxy.pType);
                let f = proxy.faceItem;
                if (f && f.minAspect !== undefined && f.maxAspect !== undefined && f.minAspect === f.maxAspect && f.minAspect > 0) {
                    if (f.minAspect === 1.0) return { w: 180, h: 180 };
                    return { w: Math.round(120 * f.minAspect), h: 120 };
                }
                return def;
            }

            function applyVariant(variantId) {
                if (proxy.pVariant === variantId) return;
                if (proxy.scaled) {
                    proxy.scaleMem = proxy.refW > 0 ? model.iw / proxy.refW : 1;
                    proxy.variantSwitch = true;
                    proxy.needsRef = true;
                } else {
                    let nextSize = CanvasGeometry.applyVariantAspect(model.iw, model.ih, proxy.pVariant, variantId, proxy.savedAspects);
                    if (nextSize) {
                        model.iw = nextSize.w;
                        model.ih = nextSize.h;
                    }
                }
                model.ivariant = variantId;
                proxy.applyVariantAndCustomProps();
                proxy.finalizeSync();
            }

            function setOpacity(value) {
                model.iopacity = value;
                proxy.triggerSync();
            }

            function rotateItem() {
                let res = CanvasGeometry.rotateBounds(
                    model.ix, model.iy, model.iw, model.ih, proxy.pRotation,
                    scene.constraints(proxy), scene.width, scene.height,
                    { gridEnabled: false }
                );
                model.iw = res.w;
                model.ih = res.h;
                model.irotation = res.rotation;
                model.ix = res.x;
                model.iy = res.y;
                proxy.finalizeSync();
            }

            function resetItemSize() {
                let def = proxy.getDefaultSize();
                let res = CanvasGeometry.resetBounds(
                    model.ix, model.iy, model.iw, model.ih, proxy.pRotation,
                    def.w, def.h, scene.constraints(proxy), scene.width, scene.height,
                    { gridEnabled: false }
                );
                model.iopacity = res.opacity;
                model.irotation = res.rotation;
                model.iw = res.w;
                model.ih = res.h;
                model.ix = res.x;
                model.iy = res.y;
                proxy.finalizeSync();
            }

            function applyResize(ex, ey, dx, dy, modifiers) {
                let edges = { left: ex < 0, right: ex > 0, top: ey < 0, bottom: ey > 0 };
                let isCorner = ex !== 0 && ey !== 0;
                let free = !scene.gridEnabled && (modifiers & Qt.ControlModifier) === 0;
                let result = CanvasGeometry.calculateRotatedResize({
                    constraints: scene.constraints(proxy),
                    startX: proxy.resizeStartX,
                    startY: proxy.resizeStartY,
                    startW: proxy.resizeStartW,
                    startH: proxy.resizeStartH,
                    dx: dx,
                    dy: dy,
                    edges: edges,
                    isCorner: isCorner,
                    rot: proxy.pRotation || 0,
                    safeWidth: scene.width,
                    safeHeight: scene.height,
                    gridEnabled: scene.gridEnabled,
                    gridStep: scene.gridStep,
                    freeSnap: free,
                    otherBoxes: scene.otherBoxes(proxy),
                    snapThreshold: scene.snapThreshold,
                    lockedAspect: proxy.lockedAspectValue
                });

                model.iw = result.w;
                model.ih = result.h;
                model.ix = result.x;
                model.iy = result.y;
                scene.presentOverlay(proxy, result.box, { lines: result.lines, refs: [] });
                proxy.triggerSync();
            }

            MouseArea {
                id: dragMa
                z: 2
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real startX
                property real startY
                property real startItemX
                property real startItemY

                onPressed: (mouse) => {
                    scene.dragging = true;
                    scene.selectedId = proxy.pId;
                    proxy.bringToFront();
                    let p = mapToItem(scene, mouse.x, mouse.y);
                    startX = p.x;
                    startY = p.y;
                    startItemX = proxy.x;
                    startItemY = proxy.y;
                }

                onPositionChanged: (mouse) => {
                    if (!pressed) return;
                    let p = mapToItem(scene, mouse.x, mouse.y);
                    let snapInfo = CanvasGeometry.calculateSnap(
                        proxy.width, proxy.height,
                        startItemX + p.x - startX, startItemY + p.y - startY,
                        scene.otherBoxes(proxy),
                        scene.width, scene.height,
                        {
                            gridEnabled: scene.gridEnabled,
                            gridStep: scene.gridStep,
                            snapThreshold: scene.snapThreshold,
                            bypass: (mouse.modifiers & Qt.ControlModifier) !== 0
                        }
                    );
                    model.ix = snapInfo.x;
                    model.iy = snapInfo.y;
                    scene.presentOverlay(proxy, snapInfo.box, snapInfo);
                    proxy.triggerSync();
                }

                onReleased: {
                    scene.dragging = false;
                    proxy.finalizeSync();
                }

                onCanceled: {
                    scene.dragging = false;
                    proxy.finalizeSync();
                }
            }

            Item {
                id: rotatable
                z: 1
                width: proxy.gW
                height: proxy.gH
                anchors.centerIn: parent
                rotation: proxy.pRotation

                Loader {
                    id: faceLoader
                    readonly property real factor: proxy.scaled && proxy.refW > 0 ? rotatable.width / proxy.refW : 1
                    width: proxy.scaled && proxy.refW > 0 ? proxy.refW : rotatable.width
                    height: proxy.scaled && proxy.refH > 0 ? proxy.refH : rotatable.height
                    scale: faceLoader.factor
                    transformOrigin: Item.TopLeft
                    opacity: proxy.isSelected ? Math.max(0.35, proxy.pOpacity) : proxy.pOpacity
                    source: LockElementRegistry.faceSource(proxy.pType, proxy.pVariant)

                    onLoaded: {
                        if (!item) return;
                        proxy.needsRef = true;
                        if (LockElementRegistry.isWidget(proxy.pType)) {
                            try {
                                if (item.imagePath !== undefined) item.imagePath = Qt.binding(() => proxy.pImage);
                            } catch (e) {}
                            proxy.applyVariantAndCustomProps();
                            if (model.iw > 0 && model.ih > 0) {
                                let res = CanvasGeometry.clampResize(scene.constraints(proxy), model.iw, model.ih, 0, 0, true);
                                if (res.w !== model.iw || res.h !== model.ih) {
                                    model.iw = res.w;
                                    model.ih = res.h;
                                    proxy.triggerSync();
                                }
                            }
                        } else {
                            if (item.variant !== undefined) item.variant = Qt.binding(() => proxy.pVariant);
                            proxy.applyVariantAndCustomProps();
                        }
                        proxy.settleScaled();
                    }
                }
            }

            Item {
                id: handleLayer
                z: 3
                width: proxy.gW
                height: proxy.gH
                anchors.centerIn: parent
                rotation: proxy.pRotation

                SelectionFrame {
                    id: selectionFrame
                    z: 30
                    anchors.fill: parent
                    anchors.margins: -Scaler.s(8)
                    active: proxy.isSelected && scene.active
                    handlesEnabled: faceLoader.status === Loader.Ready
                    aspectLocked: proxy.aspectLocked
                    rot90: proxy.rot90
                    unit: scene.unit
                    coordinateItem: scene

                    onResizeStarted: (ex, ey) => {
                        scene.dragging = true;
                        proxy.bringToFront();
                        proxy.resizeStartW = proxy.gW;
                        proxy.resizeStartH = proxy.gH;
                        proxy.resizeStartX = proxy.gX;
                        proxy.resizeStartY = proxy.gY;
                    }

                    onResizeMoved: (ex, ey, dx, dy, modifiers) => {
                        proxy.applyResize(ex, ey, dx, dy, modifiers);
                    }

                    onResizeFinished: {
                        scene.dragging = false;
                        proxy.finalizeSync();
                    }
                }
            }
        }
    }
}
