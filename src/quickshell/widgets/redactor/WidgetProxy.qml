import QtQuick
import "../../"
import ".."
import "../../reusables"

Item {
    id: widgetProxy

    required property var model
    required property int index
    readonly property var redactorMode: parent.owner

    function s(val) { return Scaler.s(val); }
    property real wRotation: (model.wRotation !== undefined && !isNaN(model.wRotation)) ? model.wRotation : 0

    x: model.wX
    y: model.wY
    width: (Math.abs(Math.round(widgetProxy.wRotation || 0)) % 180 === 0) ? model.wWidth : model.wHeight
    height: (Math.abs(Math.round(widgetProxy.wRotation || 0)) % 180 === 0) ? model.wHeight : model.wWidth

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
    property int wIndex: index

    property bool isSelected: redactorMode.selectedId === widgetProxy.wId
    property bool hasUnsyncedChanges: false

    property var savedAspects: ({})

    Connections {
        target: baseSelectMa
        function onPressedChanged() {
            if (!baseSelectMa.pressed) {
                bottomChrome.posMode = bottomChrome.calculatedPosMode;
            }
        }
    }

    function applyResize(mouse, startMouseX, startMouseY, startWidth, startHeight, startWidgetX, startWidgetY, mouseArea, edges, isCorner) {
        let localPos = mouseArea.mapToItem(redactorMode.workspaceArea, mouse.x, mouse.y);
        let dx = localPos.x - startMouseX;
        let dy = localPos.y - startMouseY;

        let rot = widgetProxy.wRotation || 0;
        let rad = rot * Math.PI / 180.0;
        let cos = Math.cos(rad);
        let sin = Math.sin(rad);

        let ldx = dx * cos + dy * sin;
        let ldy = -dx * sin + dy * cos;

        let passLdx = isCorner ? ldx : (edges.left || edges.right ? ldx : 0);
        let passLdy = isCorner ? ldy : (edges.top || edges.bottom ? ldy : 0);

        let rot90 = Math.abs(Math.round(rot)) % 180 !== 0;
        let startCX = startWidgetX + (rot90 ? startHeight : startWidth) / 2.0;
        let startCY = startWidgetY + (rot90 ? startWidth : startHeight) / 2.0;

        let pxFixed = edges.left ? startWidth / 2.0 : (edges.right ? -startWidth / 2.0 : 0);
        let pyFixed = edges.top ? startHeight / 2.0 : (edges.bottom ? -startHeight / 2.0 : 0);
        let fixedX = startCX + pxFixed * cos - pyFixed * sin;
        let fixedY = startCY + pxFixed * sin + pyFixed * cos;

        let place = (w, h) => {
            let pxNew = edges.left ? w / 2.0 : (edges.right ? -w / 2.0 : 0);
            let pyNew = edges.top ? h / 2.0 : (edges.bottom ? -h / 2.0 : 0);
            let bw = rot90 ? h : w;
            let bh = rot90 ? w : h;
            let x = fixedX - (pxNew * cos - pyNew * sin) - bw / 2.0;
            let y = fixedY - (pxNew * sin + pyNew * cos) - bh / 2.0;
            x = Math.max(0, Math.min(Math.max(0, redactorMode.safeWidth - bw), x));
            y = Math.max(0, Math.min(Math.max(0, redactorMode.safeHeight - bh), y));
            return { l: x, t: y, r: x + bw, b: y + bh };
        };

        let res = redactorMode.geometry.calculateResize(preview.item, startWidgetX, startWidgetY, startWidth, startHeight, passLdx, passLdy, edges, isCorner, rot);
        let box = place(res.w, res.h);
        let lines = { x: -1, y: -1 };
        let free = !redactorMode.gridEnabled && (mouse.modifiers & Qt.ControlModifier) === 0;

        if (free) {
            let sides = { x: 0, y: 0 };
            let addSide = (nx, ny) => {
                sides.x += Math.round(nx * cos - ny * sin);
                sides.y += Math.round(nx * sin + ny * cos);
            };
            if (edges.left) addSide(-1, 0);
            if (edges.right) addSide(1, 0);
            if (edges.top) addSide(0, -1);
            if (edges.bottom) addSide(0, 1);

            let hit = redactorMode.geometry.snapEdges(widgetProxy, box, sides);
            let aspect = selectionUI.isAspectLocked ? preview.item.minAspect : 0;
            if (aspect > 0 && hit.x && hit.y) {
                if (hit.x.diff <= hit.y.diff) hit.y = null;
                else hit.x = null;
            }

            if (hit.x || hit.y) {
                let w = res.w;
                let h = res.h;
                if (hit.x) {
                    let bw = sides.x < 0 ? box.r - hit.x.line : hit.x.line - box.l;
                    if (rot90) h = bw;
                    else w = bw;
                }
                if (hit.y) {
                    let bh = sides.y < 0 ? box.b - hit.y.line : hit.y.line - box.t;
                    if (rot90) w = bh;
                    else h = bh;
                }
                if (aspect > 0) {
                    if ((hit.x !== null) !== rot90) h = w / aspect;
                    else w = h * aspect;
                }

                let sdx = edges.left ? startWidth - w : (edges.right ? w - startWidth : 0);
                let sdy = edges.top ? startHeight - h : (edges.bottom ? h - startHeight : 0);
                let snappedRes = redactorMode.geometry.calculateResize(preview.item, startWidgetX, startWidgetY, startWidth, startHeight, sdx, sdy, edges, isCorner, rot);
                let snappedBox = place(snappedRes.w, snappedRes.h);

                let landsX = !hit.x || Math.abs((sides.x < 0 ? snappedBox.l : snappedBox.r) - hit.x.line) < 0.5;
                let landsY = !hit.y || Math.abs((sides.y < 0 ? snappedBox.t : snappedBox.b) - hit.y.line) < 0.5;
                if (landsX && landsY) {
                    res = snappedRes;
                    box = snappedBox;
                    lines = { x: hit.x ? hit.x.line : -1, y: hit.y ? hit.y.line : -1 };
                }
            }
        }

        let boxW = box.r - box.l;
        let boxH = box.b - box.t;
        let newX = box.l;
        let newY = box.t;

        if (redactorMode.gridEnabled) {
            let gridStep = s(20);
            let mX = Math.max(0, redactorMode.safeWidth - boxW);
            let mY = Math.max(0, redactorMode.safeHeight - boxH);
            newX = Math.max(0, Math.min(mX, Math.round(newX / gridStep) * gridStep));
            newY = Math.max(0, Math.min(mY, Math.round(newY / gridStep) * gridStep));
        }

        model.wWidth = res.w;
        model.wHeight = res.h;
        model.wX = newX;
        model.wY = newY;

        redactorMode.geometry.presentOverlay(widgetProxy, { l: newX, t: newY, r: newX + boxW, b: newY + boxH }, { lines: lines, refs: [] });
        widgetProxy.triggerSync();
    }

    function rotateWidget() {
        let currentRot = Math.abs(Math.round(widgetProxy.wRotation || 0)) % 360;
        let nextRot = currentRot + 90;

        let curBW = (currentRot % 180 === 0) ? model.wWidth : model.wHeight;
        let curBH = (currentRot % 180 === 0) ? model.wHeight : model.wWidth;

        let centerX = model.wX + curBW / 2.0;
        let centerY = model.wY + curBH / 2.0;

        let unscaledBW = (nextRot % 180 === 0) ? model.wWidth : model.wHeight;
        let unscaledBH = (nextRot % 180 === 0) ? model.wHeight : model.wWidth;

        let limitX = redactorMode.safeWidth;
        let limitY = redactorMode.safeHeight;

        if (redactorMode.toolbar && redactorMode.toolbar.visible && redactorMode.toolbar.opacity > 0.1 && redactorMode.toolbar.y > centerY) {
            limitY = redactorMode.toolbar.y;
        }

        let maxBW = Math.max(20, 2.0 * Math.min(centerX, limitX - centerX));
        let maxBH = Math.max(20, 2.0 * Math.min(centerY, limitY - centerY));

        let scaleX = (maxBW > 0 && unscaledBW > maxBW) ? (maxBW / unscaledBW) : 1.0;
        let scaleY = (maxBH > 0 && unscaledBH > maxBH) ? (maxBH / unscaledBH) : 1.0;
        let scale = Math.min(scaleX, scaleY);

        let targetW = model.wWidth;
        let targetH = model.wHeight;

        if (scale < 1.0) {
            targetW = model.wWidth * scale;
            targetH = model.wHeight * scale;
        }

        let clamped = redactorMode.geometry.clampResize(preview.item, targetW, targetH, 0, 0, true);
        let finalW = clamped.w;
        let finalH = clamped.h;

        let nextBW = (nextRot % 180 === 0) ? finalW : finalH;
        let nextBH = (nextRot % 180 === 0) ? finalH : finalW;

        let newX = centerX - nextBW / 2.0;
        let newY = centerY - nextBH / 2.0;

        let mX = Math.max(0, redactorMode.safeWidth - nextBW);
        let mY = Math.max(0, redactorMode.safeHeight - nextBH);
        newX = Math.max(0, Math.min(mX, newX));
        newY = Math.max(0, Math.min(mY, newY));

        if (redactorMode.gridEnabled) {
            let gridStep = s(20);
            newX = Math.round(newX / gridStep) * gridStep;
            newY = Math.round(newY / gridStep) * gridStep;
            newX = Math.max(0, Math.min(mX, newX));
            newY = Math.max(0, Math.min(mY, newY));
        }

        model.wWidth = finalW;
        model.wHeight = finalH;
        model.wRotation = nextRot;
        model.wX = newX;
        model.wY = newY;

        WidgetSync.setRotation(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), nextRot);
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

        let currentAspect = model.wWidth / model.wHeight;
        savedAspects[widgetProxy.wVariant] = currentAspect;

        let targetAspect = savedAspects[variantId];

        model.wVariant = variantId;

        if (targetAspect) {
            let area = model.wWidth * model.wHeight;
            let newH = Math.max(10, Math.sqrt(area / targetAspect));
            let newW = Math.max(10, newH * targetAspect);
            model.wWidth = newW;
            model.wHeight = newH;
        }

        WidgetSync.setVariant(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), variantId);
        finalizeSync();
    }

    function resetWidgetSize() {
        let currentRot = Math.abs(Math.round(widgetProxy.wRotation || 0)) % 360;
        let curBW = (currentRot % 180 === 0) ? model.wWidth : model.wHeight;
        let curBH = (currentRot % 180 === 0) ? model.wHeight : model.wWidth;
        let cx = model.wX + curBW / 2.0;
        let cy = model.wY + curBH / 2.0;

        let def = getDefaultSize(preview.item);
        let clamped = redactorMode.geometry.clampResize(preview.item, def.w, def.h, 0, 0, true);
        let finalW = clamped.w;
        let finalH = clamped.h;

        let newX = cx - finalW / 2.0;
        let newY = cy - finalH / 2.0;

        let mX = Math.max(0, redactorMode.safeWidth - finalW);
        let mY = Math.max(0, redactorMode.safeHeight - finalH);
        newX = Math.max(0, Math.min(mX, newX));
        newY = Math.max(0, Math.min(mY, newY));

        if (redactorMode.gridEnabled) {
            let snapped = redactorMode.geometry.snapBoxToGrid(preview.item, newX, newY, finalW, finalH);
            newX = snapped.x;
            newY = snapped.y;
            finalW = snapped.w;
            finalH = snapped.h;
        }

        model.wOpacity = 1.0;
        model.wRotation = 0;
        model.wWidth = finalW;
        model.wHeight = finalH;
        model.wX = newX;
        model.wY = newY;

        WidgetSync.setRotation(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), 0);
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
            let curOp = widgetProxy.wOpacity;
            let curRot = widgetProxy.wRotation;
            WidgetSync.setGeometry(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), model.wX, model.wY, model.wWidth, model.wHeight, curOp, curRot);
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
        redactorMode.geometry.clearOverlay();
        redactorMode.toolbarCheckTimer.stop();
        syncTimer.stop();
        widgetProxy.hasUnsyncedChanges = false;
        let curOp = widgetProxy.wOpacity;
        let curRot = widgetProxy.wRotation;
        WidgetSync.setGeometry(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), model.wX, model.wY, model.wWidth, model.wHeight, curOp, curRot);
        WidgetSync.setOpacity(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), curOp);
        WidgetSync.setRotation(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId), curRot);
        WidgetSync.bringToFront(redactorMode.redactorWindow.safeMonitorName, String(widgetProxy.wId));
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
            if (pressed) {
                let localPos = mapToItem(redactorMode.workspaceArea, mouse.x, mouse.y);
                let dx = localPos.x - startDragX;
                let dy = localPos.y - startDragY;

                let rawX = startWidgetX + dx;
                let rawY = startWidgetY + dy;

                let snapInfo = redactorMode.geometry.calculateSnap(widgetProxy, rawX, rawY, (mouse.modifiers & Qt.ControlModifier) !== 0);

                model.wX = snapInfo.x;
                model.wY = snapInfo.y;

                redactorMode.geometry.presentOverlay(widgetProxy, snapInfo.box, snapInfo);

                widgetProxy.triggerSync();
            }
        }

        onReleased: {
            widgetProxy.finalizeSync();
        }

        onCanceled: {
            widgetProxy.finalizeSync();
        }
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
            property string wImagePath: widgetProxy.wImagePath
            property string imagePath: widgetProxy.wImagePath
            property string path: widgetProxy.wImagePath
            anchors.fill: parent
            opacity: widgetProxy.isSelected ? Math.max(0.35, widgetProxy.wOpacity) : widgetProxy.wOpacity
            source: WidgetRegistry.faceFile(widgetProxy.wType, widgetProxy.wVariant)
            onLoaded: {
                if (item) {
                    try {
                        item.visible = Qt.binding(() => redactorMode.redactorWindow.visible);
                        if (item.imagePath !== undefined) {
                            item.imagePath = Qt.binding(() => widgetProxy.wImagePath);
                        }
                        if (item.wImagePath !== undefined) {
                            item.wImagePath = Qt.binding(() => widgetProxy.wImagePath);
                        }
                        if (item.path !== undefined) {
                            item.path = Qt.binding(() => widgetProxy.wImagePath);
                        }
                        if (item.source !== undefined && typeof item.source === "string") {
                            item.source = Qt.binding(() => widgetProxy.wImagePath);
                        }
                    } catch (e) {}

                    let activeModel = redactorMode.activeWidgetsModel;
                    let row = (activeModel && widgetProxy.wIndex >= 0 && widgetProxy.wIndex < activeModel.count) ? activeModel.get(widgetProxy.wIndex) : null;
                    if (row) {
                        let standardKeys = WidgetRegistry.standardKeys || [
                            "wType", "wVariant", "wX", "wY", "wWidth", "wHeight",
                            "wOpacity", "wRotation", "wImagePath", "wId"
                        ];
                        let ignoredProps = [
                            "objectName", "destroyed", "deleteLater", "parent", "data",
                            "resources", "children", "visible", "enabled", "x", "y", "z",
                            "width", "height", "opacity", "rotation", "scale"
                        ];
                        for (let k in row) {
                            if (!k || typeof k !== "string") continue;
                            if (k.endsWith("Changed") || k.startsWith("on") || typeof row[k] === "function" || row[k] === undefined) continue;
                            if (ignoredProps.includes(k) || standardKeys.includes(k)) continue;
                            try {
                                if (item[k] !== undefined && item[k] !== row[k]) {
                                    item[k] = row[k];
                                }
                            } catch (e) {}
                        }
                    }
                    let res = redactorMode.gridEnabled
                        ? redactorMode.geometry.snapBoxToGrid(item, model.wX, model.wY, model.wWidth, model.wHeight)
                        : redactorMode.geometry.clampResize(item, model.wWidth, model.wHeight, 0, 0, true);

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

        Item {
            id: selectionUI
            z: 30
            anchors.fill: parent
            anchors.margins: -widgetProxy.selectionGap
            opacity: widgetProxy.isSelected ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            property bool isAspectLocked: preview.item && preview.item.minAspect !== undefined && preview.item.maxAspect !== undefined && preview.item.minAspect === preview.item.maxAspect && preview.item.minAspect > 0
            readonly property bool isRotated90: Math.abs(Math.round(widgetProxy.wRotation || 0)) % 180 !== 0

            SelectionOutline {
                anchors.fill: parent
                running: widgetProxy.isSelected && selectionUI.opacity > 0.001
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                width: s(24)
                height: s(24)
                anchors.left: parent.left; anchors.top: parent.top
                anchors.margins: -s(6)
                cursorShape: selectionUI.isRotated90 ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                edges: ({left: true, top: true, right: false, bottom: false})
                isCorner: true
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                width: s(24)
                height: s(24)
                anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: -s(6)
                cursorShape: selectionUI.isRotated90 ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                edges: ({left: false, top: true, right: true, bottom: false})
                isCorner: true
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                width: s(24)
                height: s(24)
                anchors.left: parent.left; anchors.bottom: parent.bottom
                anchors.margins: -s(6)
                cursorShape: selectionUI.isRotated90 ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                edges: ({left: true, top: false, right: false, bottom: true})
                isCorner: true
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                width: s(24)
                height: s(24)
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: -s(6)
                cursorShape: selectionUI.isRotated90 ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                edges: ({left: false, top: false, right: true, bottom: true})
                isCorner: true
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                height: s(16)
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.leftMargin: s(18); anchors.rightMargin: s(18); anchors.topMargin: -s(8)
                visible: !selectionUI.isAspectLocked
                enabled: visible && preview.status === Loader.Ready && widgetProxy.isSelected
                cursorShape: selectionUI.isRotated90 ? Qt.SizeHorCursor : Qt.SizeVerCursor
                edges: ({left: false, top: true, right: false, bottom: false})
                isCorner: false
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                height: s(16)
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.leftMargin: s(18); anchors.rightMargin: s(18); anchors.bottomMargin: -s(8)
                visible: !selectionUI.isAspectLocked
                enabled: visible && preview.status === Loader.Ready && widgetProxy.isSelected
                cursorShape: selectionUI.isRotated90 ? Qt.SizeHorCursor : Qt.SizeVerCursor
                edges: ({left: false, top: false, right: false, bottom: true})
                isCorner: false
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                width: s(16)
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                anchors.topMargin: s(18); anchors.bottomMargin: s(18); anchors.leftMargin: -s(8)
                visible: !selectionUI.isAspectLocked
                enabled: visible && preview.status === Loader.Ready && widgetProxy.isSelected
                cursorShape: selectionUI.isRotated90 ? Qt.SizeVerCursor : Qt.SizeHorCursor
                edges: ({left: true, top: false, right: false, bottom: false})
                isCorner: false
            }

            RedactorResizeHandle {
                proxy: widgetProxy
                face: preview
                workspaceItem: redactorMode.workspaceArea
                width: s(16)
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                anchors.topMargin: s(18); anchors.bottomMargin: s(18); anchors.rightMargin: -s(8)
                visible: !selectionUI.isAspectLocked
                enabled: visible && preview.status === Loader.Ready && widgetProxy.isSelected
                cursorShape: selectionUI.isRotated90 ? Qt.SizeVerCursor : Qt.SizeHorCursor
                edges: ({left: false, top: false, right: true, bottom: false})
                isCorner: false
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

    RedactorChrome {
        id: bottomChrome
        backdropItem: chromeBackdrop
        dragging: baseSelectMa.pressed
    }
}
