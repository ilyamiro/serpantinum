import QtQuick
import "../../"
import ".."
import "../../reusables"
import "../../reusables/canvas"
import "../../reusables/canvas/CanvasGeometry.js" as CanvasGeometry

Item {
    id: widgetProxy

    required property var model
    required property int index
    readonly property var redactorMode: parent.owner

    function s(val) { return Scaler.s(val); }
    property real wRotation: (model.wRotation !== undefined && !isNaN(model.wRotation)) ? model.wRotation : 0
    readonly property bool isRotated90: Math.abs(Math.round(widgetProxy.wRotation || 0)) % 180 !== 0

    x: model.wX
    y: model.wY
    width: widgetProxy.isRotated90 ? model.wHeight : model.wWidth
    height: widgetProxy.isRotated90 ? model.wWidth : model.wHeight

    property int currentZ: index
    z: (widgetProxy.isSelected ? 50000 : 0) + currentZ
    opacity: (redactorMode.selectedId === "" || widgetProxy.isSelected) ? 1.0 : 0.6
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Component.onCompleted: {
        if (!redactorMode.isInitializing) {
            redactorMode.topZ += 1;
            widgetProxy.currentZ = redactorMode.topZ;
        }
    }

    Component.onDestruction: {
        preview.active = false;
        preview.source = "";
    }

    function bringToFront() {
        redactorMode.topZ += 1;
        widgetProxy.currentZ = redactorMode.topZ;
        WidgetSync.bringToFront(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId));
    }

    property real selectionGap: s(8)

    property alias preview: preview
    property string wType: model.wType || ""
    property string wVariant: model.wVariant || ""
    property string wImagePath: model.wImagePath || ""
    property string wId: model.wId || ""
    property real wOpacity: model.wOpacity !== undefined ? model.wOpacity : 1.0
    property var wProps: model.wProps || ({})
    property int wIndex: index

    property bool isSelected: redactorMode.selectedId === widgetProxy.wId
    property bool hasUnsyncedChanges: false
    property bool resizing: false
    property real resizeStartW: 0
    property real resizeStartH: 0
    property real resizeStartX: 0
    property real resizeStartY: 0

    property var savedAspects: ({})

    readonly property bool isAspectLocked: preview.item && preview.item.minAspect !== undefined && preview.item.maxAspect !== undefined && preview.item.minAspect === preview.item.maxAspect && preview.item.minAspect > 0

    function applyVariantAndCustomProps() {
        let item = preview.item;
        if (!item) return;
        let vProps = WidgetRegistry.variantProps(widgetProxy.wType, widgetProxy.wVariant);
        if (vProps) CanvasGeometry.applyCustomProps(item, vProps);
        CanvasGeometry.applyCustomProps(item, widgetProxy.wProps);
    }

    onWPropsChanged: applyVariantAndCustomProps()
    onWVariantChanged: applyVariantAndCustomProps()

    function applyResize(ex, ey, dx, dy, modifiers) {
        let edges = { left: ex < 0, right: ex > 0, top: ey < 0, bottom: ey > 0 };
        let isCorner = ex !== 0 && ey !== 0;
        let free = !redactorMode.gridEnabled && (modifiers & Qt.ControlModifier) === 0;
        let result = CanvasGeometry.calculateRotatedResize({
            constraints: preview.item,
            startX: widgetProxy.resizeStartX,
            startY: widgetProxy.resizeStartY,
            startW: widgetProxy.resizeStartW,
            startH: widgetProxy.resizeStartH,
            dx: dx,
            dy: dy,
            edges: edges,
            isCorner: isCorner,
            rot: widgetProxy.wRotation || 0,
            safeWidth: redactorMode.safeWidth,
            safeHeight: redactorMode.safeHeight,
            gridEnabled: redactorMode.gridEnabled,
            gridStep: redactorMode.gridStep,
            freeSnap: free,
            otherBoxes: redactorMode.otherBoxes(widgetProxy),
            snapThreshold: redactorMode.snapThreshold,
            lockedAspect: widgetProxy.isAspectLocked ? preview.item.minAspect : 0
        });

        model.wWidth = result.w;
        model.wHeight = result.h;
        model.wX = result.x;
        model.wY = result.y;

        redactorMode.presentOverlay(widgetProxy, result.box, { lines: result.lines, refs: [] });
        widgetProxy.triggerSync();
    }

    function rotateWidget() {
        let curRot = Math.abs(Math.round(widgetProxy.wRotation || 0)) % 360;
        let curBH = (curRot % 180 === 0) ? model.wHeight : model.wWidth;
        let centerY = model.wY + curBH / 2.0;
        let limitY = redactorMode.safeHeight;
        if (redactorMode.toolbar && redactorMode.toolbar.visible && redactorMode.toolbar.opacity > 0.1 && redactorMode.toolbar.y > centerY) {
            limitY = redactorMode.toolbar.y;
        }
        let res = CanvasGeometry.rotateBounds(
            model.wX, model.wY, model.wWidth, model.wHeight, widgetProxy.wRotation,
            preview.item, redactorMode.safeWidth, redactorMode.safeHeight,
            { limitY: limitY, gridEnabled: redactorMode.gridEnabled, gridStep: redactorMode.gridStep }
        );
        model.wWidth = res.w;
        model.wHeight = res.h;
        model.wRotation = res.rotation;
        model.wX = res.x;
        model.wY = res.y;
        finalizeSync();
    }

    function getDefaultSize(loaderItem) {
        let defSize = WidgetRegistry.defaultSize(widgetProxy.wType);
        let defW = defSize.w;
        let defH = defSize.h;
        if (loaderItem && loaderItem.minAspect !== undefined && loaderItem.maxAspect !== undefined && loaderItem.minAspect === loaderItem.maxAspect && loaderItem.minAspect > 0) {
            let aspect = loaderItem.minAspect;
            if (aspect === 1.0) {
                defW = 180;
                defH = 180;
            } else {
                defH = 120;
                defW = Math.round(defH * aspect);
            }
        }
        return { w: defW, h: defH };
    }

    function applyVariant(variantId) {
        if (widgetProxy.wVariant === variantId) return;
        let nextSize = CanvasGeometry.applyVariantAspect(model.wWidth, model.wHeight, widgetProxy.wVariant, variantId, savedAspects);
        model.wVariant = variantId;
        if (nextSize) {
            model.wWidth = nextSize.w;
            model.wHeight = nextSize.h;
        }
        WidgetSync.setVariant(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), variantId);
        finalizeSync();
    }

    function resetWidgetSize() {
        let def = getDefaultSize(preview.item);
        let res = CanvasGeometry.resetBounds(
            model.wX, model.wY, model.wWidth, model.wHeight, widgetProxy.wRotation,
            def.w, def.h, preview.item, redactorMode.safeWidth, redactorMode.safeHeight,
            { gridEnabled: redactorMode.gridEnabled, gridStep: redactorMode.gridStep }
        );
        model.wOpacity = res.opacity;
        model.wRotation = res.rotation;
        model.wWidth = res.w;
        model.wHeight = res.h;
        model.wX = res.x;
        model.wY = res.y;
        finalizeSync();
    }

    Timer {
        id: syncTimer
        interval: 100
        running: false
        repeat: true
        onTriggered: {
            if (!widgetProxy.hasUnsyncedChanges) {
                running = false;
                return;
            }
            widgetProxy.hasUnsyncedChanges = false;
            WidgetSync.setGeometry(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), model.wX, model.wY, model.wWidth, model.wHeight, widgetProxy.wOpacity, widgetProxy.wRotation);
        }
    }

    function triggerSync() {
        if (redactorMode.isInitializing) return;
        redactorMode.queueUpdateToolbarObscured();
        widgetProxy.hasUnsyncedChanges = true;
        if (!syncTimer.running) {
            syncTimer.restart();
        }
    }

    function finalizeSync() {
        redactorMode.clearOverlay();
        redactorMode.toolbarCheckTimer.stop();
        syncTimer.stop();
        widgetProxy.hasUnsyncedChanges = false;
        WidgetSync.setGeometry(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), model.wX, model.wY, model.wWidth, model.wHeight, widgetProxy.wOpacity, widgetProxy.wRotation);
        redactorMode.updateToolbarObscured();
        redactorMode.commitHistory();
    }

    MouseArea {
        id: baseSelectMa
        z: 0
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real startDragX
        property real startDragY
        property real startWidgetX
        property real startWidgetY

        onPressed: (mouse) => {
            redactorMode.selectedId = widgetProxy.wId;
            redactorMode.host.targetSelectedWidgetId = widgetProxy.wId;
            widgetProxy.bringToFront();
            let localPos = mapToItem(redactorMode.workspaceArea, mouse.x, mouse.y);
            startDragX = localPos.x;
            startDragY = localPos.y;
            startWidgetX = widgetProxy.x;
            startWidgetY = widgetProxy.y;
        }

        onPositionChanged: (mouse) => {
            if (!pressed) return;
            let localPos = mapToItem(redactorMode.workspaceArea, mouse.x, mouse.y);
            let rawX = startWidgetX + (localPos.x - startDragX);
            let rawY = startWidgetY + (localPos.y - startDragY);

            let snapInfo = CanvasGeometry.calculateSnap(
                widgetProxy.width, widgetProxy.height, rawX, rawY,
                redactorMode.otherBoxes(widgetProxy),
                redactorMode.safeWidth, redactorMode.safeHeight,
                {
                    gridEnabled: redactorMode.gridEnabled,
                    gridStep: redactorMode.gridStep,
                    snapThreshold: redactorMode.snapThreshold,
                    bypass: (mouse.modifiers & Qt.ControlModifier) !== 0
                }
            );

            model.wX = snapInfo.x;
            model.wY = snapInfo.y;

            redactorMode.presentOverlay(widgetProxy, snapInfo.box, snapInfo);
            widgetProxy.triggerSync();
        }

        onReleased: widgetProxy.finalizeSync()
        onCanceled: widgetProxy.finalizeSync()
    }

    Item {
        id: rotatableContainer
        z: 1
        width: model.wWidth
        height: model.wHeight
        anchors.centerIn: parent
        rotation: widgetProxy.wRotation

        Loader {
            id: preview
            anchors.fill: parent
            opacity: widgetProxy.isSelected ? Math.max(0.35, widgetProxy.wOpacity) : widgetProxy.wOpacity
            source: WidgetRegistry.faceFile(widgetProxy.wType, widgetProxy.wVariant)
            onLoaded: {
                if (item) {
                    try {
                        item.visible = Qt.binding(() => redactorMode.redactorWindow.visible);
                        if (item.widgetId !== undefined) {
                            item.widgetId = Qt.binding(() => String(widgetProxy.wId));
                        }
                        if (item.imagePath !== undefined) {
                            item.imagePath = Qt.binding(() => widgetProxy.wImagePath);
                        }
                    } catch (e) {}

                    widgetProxy.applyVariantAndCustomProps();

                    let res = redactorMode.gridEnabled
                        ? CanvasGeometry.snapBoxToGrid(item, model.wX, model.wY, model.wWidth, model.wHeight, redactorMode.safeWidth, redactorMode.safeHeight, redactorMode.gridStep)
                        : CanvasGeometry.clampResize(item, model.wWidth, model.wHeight, 0, 0, true);

                    let changed = false;
                    if (res.x !== undefined && (model.wX !== res.x || model.wY !== res.y)) {
                        model.wX = res.x;
                        model.wY = res.y;
                        changed = true;
                    }
                    if (res.w !== model.wWidth || res.h !== model.wHeight) {
                        model.wWidth = res.w;
                        model.wHeight = res.h;
                        changed = true;
                    }
                    if (changed && !redactorMode.isInitializing) {
                        widgetProxy.triggerSync();
                    }
                }
            }
        }

        SelectionFrame {
            id: selectionFrame
            z: 30
            anchors.fill: parent
            anchors.margins: -widgetProxy.selectionGap
            active: widgetProxy.isSelected
            handlesEnabled: preview.status === Loader.Ready
            aspectLocked: widgetProxy.isAspectLocked
            rot90: widgetProxy.isRotated90
            unit: Scaler.s(1)
            coordinateItem: redactorMode.workspaceArea

            onResizeStarted: (ex, ey) => {
                widgetProxy.resizing = true;
                widgetProxy.bringToFront();
                widgetProxy.resizeStartW = model.wWidth;
                widgetProxy.resizeStartH = model.wHeight;
                widgetProxy.resizeStartX = model.wX;
                widgetProxy.resizeStartY = model.wY;
            }

            onResizeMoved: (ex, ey, dx, dy, modifiers) => {
                widgetProxy.applyResize(ex, ey, dx, dy, modifiers);
            }

            onResizeFinished: {
                widgetProxy.resizing = false;
                widgetProxy.finalizeSync();
            }
        }
    }

    WallpaperBlur {
        id: chromeBackdrop
        standalone: true
        opacity: 0
        x: bottomChrome.x
        y: bottomChrome.y
        width: bottomChrome.width
        height: bottomChrome.height
        radius: 0
    }

    EditorChrome {
        id: bottomChrome
        active: widgetProxy.isSelected && !redactorMode.toolbar.panelOpen
        dragging: baseSelectMa.pressed || widgetProxy.resizing
        relativeToTarget: true
        targetX: widgetProxy.x
        targetY: widgetProxy.y
        targetWidth: widgetProxy.width
        targetHeight: widgetProxy.height
        boundsWidth: redactorMode.safeWidth
        boundsHeight: redactorMode.safeHeight
        limitY: (redactorMode.toolbar.opacity > 0.1 && !redactorMode.toolbarObscured) ? redactorMode.toolbar.y : redactorMode.safeHeight
        selectionGap: widgetProxy.selectionGap
        glassBackdropItem: chromeBackdrop

        itemWidth: model.wWidth
        itemHeight: model.wHeight
        defaultWidth: widgetProxy.getDefaultSize(preview.item).w
        itemOpacity: widgetProxy.wOpacity
        showScale: true
        showRotate: true
        showReset: true
        showDelete: true
        showBottomRow: true

        topSettings: WidgetRegistry.additionalSettings(widgetProxy.wType, "top", widgetProxy.wVariant)
        bottomSettings: WidgetRegistry.additionalSettings(widgetProxy.wType, "bottom", widgetProxy.wVariant)
        variants: WidgetRegistry.variantList(widgetProxy.wType)
        currentVariant: widgetProxy.wVariant
        targetItem: preview.item
        targetData: widgetProxy.wProps
        typeData: WidgetRegistry.types[widgetProxy.wType]
        hostOwner: redactorMode
        settingsRevision: redactorMode.propsRevision

        onRotateClicked: widgetProxy.rotateWidget()
        onResetClicked: widgetProxy.resetWidgetSize()
        onDeleteClicked: redactorMode.removeWidget(widgetProxy.wId)
        onVariantSelected: (variantId) => widgetProxy.applyVariant(variantId)
        onOpacityMoved: (op) => {
            model.wOpacity = op;
            widgetProxy.triggerSync();
        }
        onOpacityFinished: widgetProxy.finalizeSync()
        onSettingPropertyEdited: (propName, val) => redactorMode.setWidgetProperty(propName, val, widgetProxy.wId)
        onSettingActionTriggered: (actionName) => redactorMode.handleAdditionalAction(actionName, widgetProxy.wIndex, widgetProxy.wId, widgetProxy)
    }
}
