import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import ".."
import "../../reusables"
import "../../reusables/canvas"
import "../../reusables/canvas/CanvasGeometry.js" as CanvasGeometry

Item {
    id: redactorMode
    anchors.fill: parent

    required property var host
    required property var redactorWindow

    function s(val) { return Scaler.s(val); }

    ListModel {
        id: activeWidgetsModel
        dynamicRoles: true
        onCountChanged: {
            redactorMode.updateToolbarObscured();
            historyStore.scheduleCommit();
        }
    }

    property alias activeWidgetsModel: activeWidgetsModel
    property alias workspaceArea: workspaceArea
    property alias toolbar: toolbar
    property alias initTimer: initTimer
    property alias toolbarCheckTimer: toolbarCheckTimer

    property string selectedId: host.targetSelectedWidgetId
    property bool gridEnabled: false
    property string nudgeTargetId: ""
    readonly property bool canNudge: selectedId !== "" && !toolbar.panelOpen && !imagePickerHost.isOpen
    property bool toolbarObscured: false
    property bool isReady: false
    property bool isInitializing: true
    property int topZ: 1
    property int propsRevision: 0

    property var guideLines: []
    property var measureLines: []
    readonly property real gridStep: s(20)
    readonly property real snapThreshold: s(12)
    readonly property bool showDistances: !(typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.widgets && Config.rawSettings.widgets.showDistances === false)

    readonly property var selectedWidget: {
        if (!selectedId) return null;
        for (let i = 0; i < widgetRepeater.count; i++) {
            let p = widgetRepeater.itemAt(i);
            if (p && String(p.wId) === String(selectedId)) {
                return (p.preview && p.preview.item) ? p.preview.item : p;
            }
        }
        return null;
    }

    readonly property var currentWidget: selectedWidget
    readonly property var activeWidget: selectedWidget

    onSelectedIdChanged: updateToolbarObscured()
    onWidthChanged: updateToolbarObscured()
    onHeightChanged: updateToolbarObscured()

    Connections {
        target: host
        function onTargetSelectedWidgetIdChanged() {
            redactorMode.selectedId = host.targetSelectedWidgetId;
        }
    }

    property real safeMinX: 0
    property real safeMinY: 0
    property real safeWidth: redactorMode.width
    property real safeHeight: redactorMode.height

    function cloneProps(props) {
        let out = {};
        if (!props) return out;
        for (let k in props) {
            if (!k || typeof k !== "string" || k === "objectName" || k.endsWith("Changed") || k.startsWith("on") || typeof props[k] === "function" || props[k] === undefined) continue;
            out[k] = props[k];
        }
        return out;
    }

    function otherBoxes(excluded) {
        return CanvasGeometry.otherBoxesFromRepeater(widgetRepeater, excluded);
    }

    function presentOverlay(item, box, snap) {
        let overlay = CanvasGeometry.buildOverlay(box, otherBoxes(item), snap, safeWidth, safeHeight, s(1), showDistances);
        guideLines = overlay.guideLines;
        measureLines = overlay.measureLines;
    }

    function clearOverlay() {
        if (guideLines.length > 0) guideLines = [];
        if (measureLines.length > 0) measureLines = [];
    }

    function matchesSelfMonitor(monitor) {
        return WidgetSync.matchesMonitor(monitor, redactorWindow.safeMonitorName) || WidgetSync.matchesMonitor(monitor, redactorWindow.monitorName);
    }

    Connections {
        target: WidgetSync

        function onPresetApplied(monitor, widgetsList) {
            if (!redactorMode.matchesSelfMonitor(monitor)) return;
            redactorMode.loadLayoutFromText(JSON.stringify(widgetsList));
        }

        function onPositionChanged(monitor, widgetId, x, y) {
            if (!redactorMode.matchesSelfMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < activeWidgetsModel.count; i++) {
                let item = activeWidgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    activeWidgetsModel.setProperty(i, "wX", x);
                    activeWidgetsModel.setProperty(i, "wY", y);
                    redactorMode.queueUpdateToolbarObscured();
                    break;
                }
            }
        }

        function onPropertyChanged(monitor, widgetId, propName, val) {
            if (monitor && !redactorMode.matchesSelfMonitor(monitor)) return;
            if (WidgetRegistry.standardKeys.includes(propName)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < activeWidgetsModel.count; i++) {
                let item = activeWidgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    let p = redactorMode.cloneProps(item.wProps);
                    if (p[propName] !== val) {
                        p[propName] = val;
                        activeWidgetsModel.setProperty(i, "wProps", p);
                    }
                    let proxy = widgetRepeater.itemAt(i);
                    if (proxy && proxy.preview && proxy.preview.item) {
                        try {
                            if (proxy.preview.item[propName] !== undefined && proxy.preview.item[propName] !== val) {
                                proxy.preview.item[propName] = val;
                            }
                        } catch (e) {}
                    }
                    redactorMode.propsRevision++;
                    break;
                }
            }
        }

        function onWidgetRemoved(monitor, widgetId) {
            if (!redactorMode.matchesSelfMonitor(monitor)) return;
            let rmId = String(widgetId).trim();
            if (redactorMode.selectedId === rmId) {
                redactorMode.selectedId = "";
                host.targetSelectedWidgetId = "";
            }
            for (let i = activeWidgetsModel.count - 1; i >= 0; i--) {
                if (String(activeWidgetsModel.get(i).wId).trim() === rmId) {
                    activeWidgetsModel.remove(i, 1);
                }
            }
            redactorMode.updateToolbarObscured();
        }

        function onWidgetsCleared(monitor) {
            if (!redactorMode.matchesSelfMonitor(monitor)) return;
            redactorMode.selectedId = "";
            host.targetSelectedWidgetId = "";
            activeWidgetsModel.clear();
            redactorMode.updateToolbarObscured();
        }
    }

    function snapshotModel() {
        let out = [];
        for (let i = 0; i < activeWidgetsModel.count; i++) {
            let row = activeWidgetsModel.get(i);
            out.push({
                wType: row.wType,
                wVariant: row.wVariant,
                wX: row.wX,
                wY: row.wY,
                wWidth: row.wWidth,
                wHeight: row.wHeight,
                wOpacity: row.wOpacity,
                wRotation: row.wRotation,
                wImagePath: row.wImagePath || "",
                wId: String(row.wId),
                wProps: redactorMode.cloneProps(row.wProps)
            });
        }
        return JSON.stringify(out);
    }

    function restoreSnapshot(text) {
        let target = JSON.parse(text);
        let current = JSON.parse(snapshotModel());
        let mon = redactorWindow.safeMonitorName;
        let currentById = {};
        let targetById = {};
        for (let i = 0; i < current.length; i++) currentById[String(current[i].wId)] = current[i];
        for (let i = 0; i < target.length; i++) targetById[String(target[i].wId)] = target[i];

        redactorMode.isInitializing = true;

        for (let id in currentById) {
            if (!targetById[id]) WidgetSync.removeWidget(mon, id);
        }

        for (let i = 0; i < target.length; i++) {
            let e = target[i];
            let id = String(e.wId);
            let old = currentById[id];
            let nextProps = e.wProps || {};
            if (!old) {
                WidgetSync.addWidget(mon, id, e.wType, e.wX, e.wY, e.wWidth, e.wHeight, e.wOpacity, e.wImagePath || "", e.wRotation, e.wVariant);
                for (let k in nextProps) WidgetSync.setProperty(mon, id, k, nextProps[k]);
                continue;
            }
            if (old.wX !== e.wX || old.wY !== e.wY || old.wWidth !== e.wWidth || old.wHeight !== e.wHeight || old.wOpacity !== e.wOpacity || old.wRotation !== e.wRotation) {
                WidgetSync.setGeometry(mon, id, e.wX, e.wY, e.wWidth, e.wHeight, e.wOpacity, e.wRotation);
            }
            if (old.wVariant !== e.wVariant) WidgetSync.setVariant(mon, id, e.wVariant);
            if ((old.wImagePath || "") !== (e.wImagePath || "")) WidgetSync.setImagePath(mon, id, e.wImagePath || "");
            let oldProps = old.wProps || {};
            for (let k in nextProps) {
                if (JSON.stringify(oldProps[k]) !== JSON.stringify(nextProps[k])) WidgetSync.setProperty(mon, id, k, nextProps[k]);
            }
        }

        if (redactorMode.selectedId !== "" && !targetById[redactorMode.selectedId]) {
            redactorMode.selectedId = "";
            host.targetSelectedWidgetId = "";
        }

        activeWidgetsModel.clear();
        for (let i = 0; i < target.length; i++) activeWidgetsModel.append(target[i]);
        redactorMode.propsRevision++;
        redactorMode.updateToolbarObscured();
        initTimer.restart();
    }

    HistoryStack {
        id: historyStore
        debounceMs: 400
        enabled: !redactorMode.isInitializing && redactorMode.isReady
        snapshotFn: () => redactorMode.snapshotModel()
        restoreFn: (text) => redactorMode.restoreSnapshot(text)
        beforeStepFn: () => redactorMode.saveConfig()
    }

    Timer {
        id: toolbarCheckTimer
        interval: 100
        repeat: false
        onTriggered: redactorMode.updateToolbarObscured()
    }

    function queueUpdateToolbarObscured() {
        toolbarCheckTimer.restart();
    }

    function removeWidget(widgetId) {
        let rmId = String(widgetId);
        if (!rmId) return;
        if (redactorMode.selectedId === rmId) {
            redactorMode.selectedId = "";
            host.targetSelectedWidgetId = "";
        }
        WidgetSync.removeWidget(redactorWindow.safeMonitorName, rmId);
    }

    function removeAllWidgets() {
        redactorMode.selectedId = "";
        host.targetSelectedWidgetId = "";
        WidgetSync.clearWidgets(redactorWindow.safeMonitorName);
    }

    function updateToolbarObscured() {
        if (!activeWidgetsModel || activeWidgetsModel.count === 0) {
            toolbarObscured = false;
            return;
        }

        let margin = s(50);
        let tbW = toolbar.width;
        let tbX = (redactorMode.width - tbW) / 2;
        let tbY = toolbar.y;

        let zX1 = tbX - margin;
        let zX2 = tbX + tbW + margin;
        let zY1 = tbY - margin;
        let zY2 = redactorMode.height;

        let obscured = false;
        let repCount = widgetRepeater.count;

        if (repCount > 0) {
            for (let i = 0; i < repCount; i++) {
                let proxy = widgetRepeater.itemAt(i);
                if (!proxy) continue;

                let isSel = (redactorMode.selectedId === proxy.wId);
                let gap = isSel ? s(20) : 0;
                let chromeH = isSel ? s(90) : 0;

                let wX1 = proxy.x - gap;
                let wY1 = proxy.y - gap;
                let wX2 = proxy.x + proxy.width + gap;
                let wY2 = proxy.y + proxy.height + gap + chromeH;

                if (wX1 < zX2 && wX2 > zX1 && wY1 < zY2 && wY2 > zY1) {
                    obscured = true;
                    break;
                }
            }
        } else {
            for (let i = 0; i < activeWidgetsModel.count; i++) {
                let item = activeWidgetsModel.get(i);
                if (!item) continue;
                let rot = (item.wRotation !== undefined && !isNaN(item.wRotation)) ? Math.abs(Math.round(item.wRotation)) : 0;
                let bw = (rot % 180 === 0) ? item.wWidth : item.wHeight;
                let bh = (rot % 180 === 0) ? item.wHeight : item.wWidth;
                let isSel = (redactorMode.selectedId === item.wId);
                let gap = isSel ? s(20) : 0;
                let chromeH = isSel ? s(90) : 0;

                let wX1 = item.wX - gap;
                let wY1 = item.wY - gap;
                let wX2 = item.wX + bw + gap;
                let wY2 = item.wY + bh + gap + chromeH;

                if (wX1 < zX2 && wX2 > zX1 && wY1 < zY2 && wY2 > zY1) {
                    obscured = true;
                    break;
                }
            }
        }
        toolbarObscured = obscured;
    }

    function proxyFor(widgetId) {
        for (let i = 0; i < widgetRepeater.count; i++) {
            let p = widgetRepeater.itemAt(i);
            if (p && String(p.wId) === String(widgetId)) return p;
        }
        return null;
    }

    Timer {
        id: nudgeTimer
        interval: 600
        repeat: false
        onTriggered: redactorMode.finishNudge()
    }

    function finishNudge() {
        nudgeTimer.stop();
        let proxy = proxyFor(nudgeTargetId);
        nudgeTargetId = "";
        if (proxy) proxy.finalizeSync();
        else clearOverlay();
    }

    function nudgeSelected(dx, dy, large) {
        let proxy = proxyFor(selectedId);
        if (!proxy) return;
        if (nudgeTargetId !== "" && nudgeTargetId !== String(proxy.wId)) finishNudge();

        let x = proxy.x;
        let y = proxy.y;
        let step = large ? 10 : 1;
        if (gridEnabled) {
            step = gridStep * (large ? 5 : 1);
            x = Math.round(x / gridStep) * gridStep;
            y = Math.round(y / gridStep) * gridStep;
        }
        x = Math.max(0, Math.min(Math.max(0, safeWidth - proxy.width), x + dx * step));
        y = Math.max(0, Math.min(Math.max(0, safeHeight - proxy.height), y + dy * step));

        activeWidgetsModel.setProperty(proxy.wIndex, "wX", x);
        activeWidgetsModel.setProperty(proxy.wIndex, "wY", y);
        proxy.triggerSync();
        presentOverlay(proxy, { l: x, t: y, r: x + proxy.width, b: y + proxy.height }, null);
        nudgeTargetId = String(proxy.wId);
        nudgeTimer.restart();
    }

    function snapAllWidgetsToGrid() {
        for (let i = 0; i < widgetRepeater.count; i++) {
            let proxy = widgetRepeater.itemAt(i);
            if (!proxy || !proxy.preview || proxy.preview.status !== Loader.Ready) continue;

            let row = activeWidgetsModel.get(i);
            if (!row) continue;
            let res = CanvasGeometry.snapBoxToGrid(proxy.preview.item, row.wX, row.wY, row.wWidth, row.wHeight, safeWidth, safeHeight, gridStep);

            if (res.x !== row.wX || res.y !== row.wY || res.w !== row.wWidth || res.h !== row.wHeight) {
                activeWidgetsModel.setProperty(i, "wX", res.x);
                activeWidgetsModel.setProperty(i, "wY", res.y);
                activeWidgetsModel.setProperty(i, "wWidth", res.w);
                activeWidgetsModel.setProperty(i, "wHeight", res.h);
                proxy.finalizeSync();
            }
        }
    }

    function appendWidget(typeKey, imagePath) {
        let def = WidgetRegistry.defaultSize(typeKey);
        let defW = def.w;
        let defH = def.h;
        let spawnX = Math.max(0, (redactorMode.safeWidth - s(defW)) / 2);
        let spawnY = Math.max(0, (redactorMode.safeHeight - s(defH)) / 2);
        let newId = "w_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

        if (redactorMode.gridEnabled) {
            let snapped = CanvasGeometry.snapBoxToGrid(null, spawnX, spawnY, defW, defH, safeWidth, safeHeight, gridStep);
            spawnX = snapped.x;
            spawnY = snapped.y;
            defW = snapped.w;
            defH = snapped.h;
        }

        let defVariant = WidgetRegistry.defaultVariant(typeKey);
        let img = imagePath || "";

        activeWidgetsModel.append({
            wType: typeKey,
            wVariant: defVariant,
            wX: spawnX,
            wY: spawnY,
            wWidth: defW,
            wHeight: defH,
            wOpacity: 1.0,
            wRotation: 0,
            wImagePath: img,
            wId: newId,
            wProps: {}
        });

        redactorMode.topZ += 1;
        redactorMode.selectedId = newId;
        host.targetSelectedWidgetId = newId;
        WidgetSync.addWidget(redactorWindow.safeMonitorName, newId, typeKey, spawnX, spawnY, defW, defH, 1.0, img, 0, defVariant);
        WidgetSync.bringToFront(redactorWindow.safeMonitorName, newId);
        redactorMode.updateToolbarObscured();
    }

    function addWidget(typeKey) {
        let t = WidgetRegistry.types[typeKey];
        if (!t) return;
        let picker = WidgetRegistry.pickerFor(typeKey);
        if (picker || t.requiresFilePicker) {
            imagePickerHost.open(typeKey, "", "", false);
            return;
        }
        redactorMode.appendWidget(typeKey, "");
    }

    function setWidgetProperty(propName, val, targetId) {
        let tid = targetId || redactorMode.selectedId;
        if (!tid) return;
        for (let i = 0; i < activeWidgetsModel.count; i++) {
            let row = activeWidgetsModel.get(i);
            if (String(row.wId) === String(tid)) {
                let p = redactorMode.cloneProps(row.wProps);
                p[propName] = val;
                activeWidgetsModel.setProperty(i, "wProps", p);
                let proxy = widgetRepeater.itemAt(i);
                if (proxy && proxy.preview && proxy.preview.item) {
                    try {
                        if (proxy.preview.item[propName] !== undefined) {
                            proxy.preview.item[propName] = val;
                        }
                    } catch (e) {}
                }
                WidgetSync.setProperty(redactorWindow.safeMonitorName, String(tid), propName, val);
                redactorMode.propsRevision++;
                historyStore.scheduleCommit();
                break;
            }
        }
    }

    function resetHistory() {
        historyStore.reset();
    }

    function commitHistory() {
        historyStore.commit();
    }

    function undo() {
        historyStore.undo();
    }

    function redo() {
        historyStore.redo();
    }

    function saveConfig() {
        for (let i = 0; i < widgetRepeater.count; i++) {
            let proxy = widgetRepeater.itemAt(i);
            if (proxy && proxy.hasUnsyncedChanges) proxy.finalizeSync();
        }
    }

    function handleAdditionalAction(action, itemIndex, itemId, proxy, extraArg) {
        if (!proxy || itemIndex < 0 || itemIndex >= activeWidgetsModel.count) return;
        let row = activeWidgetsModel.get(itemIndex);
        let isRot90 = (Math.abs(Math.round(proxy.wRotation || 0)) % 180) !== 0;
        CanvasGeometry.handleGeometryAction(action, {
            safeWidth: redactorMode.safeWidth,
            safeHeight: redactorMode.safeHeight,
            isRotated90: isRot90,
            gap: 50,
            extraArg: extraArg,
            pickImage: () => {
                let curImg = row ? (row.wImagePath || "") : "";
                let circleMask = WidgetRegistry.variantCircleMask(proxy.wType, proxy.wVariant);
                imagePickerHost.open(proxy.wType, itemId, curImg, circleMask);
            },
            setGeometry: (patch) => {
                if (patch.x !== undefined) activeWidgetsModel.setProperty(itemIndex, "wX", patch.x);
                if (patch.y !== undefined) activeWidgetsModel.setProperty(itemIndex, "wY", patch.y);
                if (patch.w !== undefined) activeWidgetsModel.setProperty(itemIndex, "wWidth", patch.w);
                if (patch.h !== undefined) activeWidgetsModel.setProperty(itemIndex, "wHeight", patch.h);
                proxy.finalizeSync();
            },
            setProperty: (prop, val) => redactorMode.setWidgetProperty(prop, val, itemId)
        });
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.55)
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            redactorMode.selectedId = "";
            host.targetSelectedWidgetId = "";
        }
    }

    SnapOverlay {
        guideLines: redactorMode.guideLines
        measureLines: redactorMode.measureLines
    }

    Item {
        id: workspaceArea
        readonly property var owner: redactorMode
        anchors.fill: parent

        GridOverlay {
            anchors.fill: parent
            gridActive: redactorMode.gridEnabled
            stepSize: redactorMode.gridStep
        }

        Repeater {
            id: widgetRepeater
            model: redactorMode.activeWidgetsModel
            delegate: WidgetProxy {}
        }
    }

    RedactorEmptyState {
        anchors.centerIn: workspaceArea
        visible: redactorMode.isReady && (redactorMode.activeWidgetsModel ? redactorMode.activeWidgetsModel.count === 0 : true)
    }

    FileView {
        id: layoutFile
        path: (Caching.getStateDir && redactorWindow.safeMonitorName) ? (Caching.getStateDir("widgets/" + redactorWindow.safeMonitorName) + "/layout.json") : ""
        watchChanges: false
        onLoaded: redactorMode.loadLayoutFromText(text())
    }

    function loadLayoutFromText(content) {
        let trimmed = (content || "").trim();
        activeWidgetsModel.clear();
        redactorMode.isInitializing = true;
        if (trimmed !== "" && trimmed !== "[]") {
            try {
                let data = JSON.parse(trimmed);
                redactorMode.topZ = data.length + 10;
                for (let i = 0; i < data.length; i++) {
                    let item = data[i];
                    let type = item.wType || item.type || WidgetRegistry.defaultType;
                    let variant = item.wVariant || item.variant || WidgetRegistry.defaultVariant(type);
                    let sVal = item.wScale !== undefined ? parseFloat(item.wScale) : 1.0;
                    let defSize = WidgetRegistry.defaultSize(type);
                    let w = item.wWidth !== undefined ? parseFloat(item.wWidth) : defSize.w * sVal;
                    let h = item.wHeight !== undefined ? parseFloat(item.wHeight) : defSize.h * sVal;
                    let op = item.wOpacity !== undefined ? parseFloat(item.wOpacity) : 1.0;
                    let rot = (item.wRotation !== undefined) ? parseFloat(item.wRotation) : (item.rotation !== undefined ? parseFloat(item.rotation) : 0);
                    if (isNaN(rot)) rot = 0;
                    rot = ((Math.round(rot) % 360) + 360) % 360;
                    let imgPath = item.wImagePath || item.imagePath || item.path || "";

                    activeWidgetsModel.append({
                        wType: type,
                        wVariant: variant,
                        wX: item.wX !== undefined ? parseFloat(item.wX) : 100,
                        wY: item.wY !== undefined ? parseFloat(item.wY) : 100,
                        wWidth: w,
                        wHeight: h,
                        wOpacity: op,
                        wRotation: rot,
                        wImagePath: imgPath,
                        wId: String(item.wId || item.id || ("w_" + Date.now() + "_" + i)),
                        wProps: WidgetRegistry.extractProps(item)
                    });
                }
            } catch (e) {}
        }
        redactorMode.isReady = true;
        redactorMode.propsRevision++;
        redactorMode.resetHistory();
        redactorMode.updateToolbarObscured();
        Qt.callLater(() => {
            WidgetSync.setRedactMode(redactorWindow.safeMonitorName, true);
        });
        initTimer.restart();
    }

    Timer {
        id: initTimer
        interval: 200
        repeat: false
        onTriggered: redactorMode.isInitializing = false
    }

    function reloadLayout() {
        layoutFile.reload();
    }

    Connections {
        target: redactorWindow
        function onSafeMonitorNameChanged() {
            redactorMode.reloadLayout();
        }
    }

    Component.onCompleted: {
        let envData = Quickshell.env("QS_WIDGET_DATA") || Quickshell.env("QS_LAYOUT_DATA") || Quickshell.env("QS_LAYOUT_JSON");
        if (envData && envData.trim() !== "") {
            redactorMode.loadLayoutFromText(envData);
        }
    }

    RedactorToolbar {
        id: toolbar
        redactor: redactorMode
        host: redactorMode.host
        redactorWindow: redactorMode.redactorWindow
    }

    RedactorImagePickerHost {
        id: imagePickerHost
        rootObj: redactorMode
        onImagePicked: (targetType, targetId, filePath, fileName) => {
            if (targetId !== "") {
                for (let i = 0; i < activeWidgetsModel.count; i++) {
                    if (String(activeWidgetsModel.get(i).wId) === targetId) {
                        activeWidgetsModel.setProperty(i, "wImagePath", filePath);
                        break;
                    }
                }
                WidgetSync.setImagePath(redactorWindow.safeMonitorName, targetId, filePath);
                historyStore.scheduleCommit();
            } else if (filePath !== "" && targetType !== "") {
                redactorMode.appendWidget(targetType, filePath);
            }
        }
    }
}
