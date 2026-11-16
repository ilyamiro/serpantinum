import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import ".."
import "../../reusables"

Item {
    id: redactorMode
    anchors.fill: parent

    required property var host
    required property var redactorWindow

    function s(val) { return Scaler.s(val); }

    ListModel {
        id: activeWidgetsModel
        dynamicRoles: true
        onCountChanged: redactorMode.updateToolbarObscured()
    }

    property alias activeWidgetsModel: activeWidgetsModel
    property alias workspaceArea: workspaceArea
    property alias toolbar: toolbar
    property alias initTimer: initTimer
    property alias toolbarCheckTimer: toolbarCheckTimer
    property alias geometry: geometry

    property string selectedId: host.targetSelectedWidgetId
    property bool gridEnabled: false
    property string nudgeTargetId: ""
    readonly property bool canNudge: selectedId !== "" && !toolbar.panelOpen && !(imagePickerLoader.item && imagePickerLoader.item.visible)
    property bool toolbarObscured: false
    property bool isReady: false
    property bool isInitializing: true
    property int topZ: 1

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

    Connections {
        target: WidgetSync
        ignoreUnknownSignals: true

        function onPresetApplied(monitor, widgetsList) {
            if (String(monitor).replace(/[^a-zA-Z0-9_-]/g, "_") !== redactorWindow.safeMonitorName) return;
            redactorMode.loadLayoutFromText(JSON.stringify(widgetsList));
        }

        function onPositionChanged(monitor, widgetId, x, y) {
            if (monitor !== redactorWindow.safeMonitorName) return;
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
            if (monitor && monitor !== redactorWindow.safeMonitorName) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < activeWidgetsModel.count; i++) {
                let item = activeWidgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    activeWidgetsModel.setProperty(i, propName, val);
                    let proxy = widgetRepeater.itemAt(i);
                    if (proxy && proxy.preview && proxy.preview.item) {
                        try {
                            if (proxy.preview.item[propName] !== undefined) {
                                proxy.preview.item[propName] = val;
                            }
                        } catch (e) {}
                    }
                    break;
                }
            }
        }
    }
    RedactorGeometry {
        id: geometry
        safeWidth: redactorMode.safeWidth
        safeHeight: redactorMode.safeHeight
        gridEnabled: redactorMode.gridEnabled
        repeater: widgetRepeater
    }

    RedactorHistory {
        id: historyStore
        redactorMode: redactorMode
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
        if (activeWidgetsModel) {
            for (let i = activeWidgetsModel.count - 1; i >= 0; i--) {
                if (String(activeWidgetsModel.get(i).wId) === rmId) {
                    activeWidgetsModel.remove(i, 1);
                }
            }
            if (activeWidgetsModel.count === 0) {
                redactorMode.selectedId = "";
                host.targetSelectedWidgetId = "";
            }
        }
        redactorMode.updateToolbarObscured();
    }

    function removeAllWidgets() {
        redactorMode.selectedId = "";
        host.targetSelectedWidgetId = "";
        activeWidgetsModel.clear();
        WidgetSync.clearWidgets(redactorWindow.safeMonitorName);
        redactorMode.updateToolbarObscured();
    }

    function updateToolbarObscured() {
        if (!activeWidgetsModel || activeWidgetsModel.count === 0) {
            toolbarObscured = false;
            return;
        }

        let margin = s(50);
        let tbW = toolbar.width;
        let tbH = toolbar.height;
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
        else geometry.clearOverlay();
    }

    function nudgeSelected(dx, dy, large) {
        let proxy = proxyFor(selectedId);
        if (!proxy) return;
        if (nudgeTargetId !== "" && nudgeTargetId !== String(proxy.wId)) finishNudge();

        let x = proxy.x;
        let y = proxy.y;
        let step = large ? 10 : 1;
        if (gridEnabled) {
            let gridStep = s(20);
            step = gridStep * (large ? 5 : 1);
            x = Math.round(x / gridStep) * gridStep;
            y = Math.round(y / gridStep) * gridStep;
        }
        x = Math.max(0, Math.min(Math.max(0, safeWidth - proxy.width), x + dx * step));
        y = Math.max(0, Math.min(Math.max(0, safeHeight - proxy.height), y + dy * step));

        activeWidgetsModel.setProperty(proxy.wIndex, "wX", x);
        activeWidgetsModel.setProperty(proxy.wIndex, "wY", y);
        proxy.triggerSync();
        geometry.presentOverlay(proxy, { l: x, t: y, r: x + proxy.width, b: y + proxy.height }, null);
        nudgeTargetId = String(proxy.wId);
        nudgeTimer.restart();
    }

    function snapAllWidgetsToGrid() {
        for (let i = 0; i < widgetRepeater.count; i++) {
            let proxy = widgetRepeater.itemAt(i);
            if (!proxy || !proxy.preview || proxy.preview.status !== Loader.Ready) continue;

            let row = activeWidgetsModel.get(i);
            if (!row) continue;
            let res = geometry.snapBoxToGrid(proxy.preview.item, row.wX, row.wY, row.wWidth, row.wHeight);

            if (res.x !== row.wX || res.y !== row.wY || res.w !== row.wWidth || res.h !== row.wHeight) {
                activeWidgetsModel.setProperty(i, "wX", res.x);
                activeWidgetsModel.setProperty(i, "wY", res.y);
                activeWidgetsModel.setProperty(i, "wWidth", res.w);
                activeWidgetsModel.setProperty(i, "wHeight", res.h);
                proxy.finalizeSync();
            }
        }
    }

    function openImagePicker(targetIdx, targetId, curImg, isRound) {
        imagePickerLoader.active = true;
        let trigger = () => {
            if (imagePickerLoader.item) {
                imagePickerLoader.item.targetWidgetIndex = targetIdx;
                imagePickerLoader.item.targetWidgetId = String(targetId);
                imagePickerLoader.item.openPicker(curImg, isRound);
            }
        };
        if (imagePickerLoader.status === Loader.Ready) {
            trigger();
        } else {
            let conn = function() {
                if (imagePickerLoader.status === Loader.Ready) {
                    imagePickerLoader.statusChanged.disconnect(conn);
                    trigger();
                }
            };
            imagePickerLoader.statusChanged.connect(conn);
        }
    }

    function addWidget(typeKey) {
        let t = WidgetRegistry.types[typeKey];
        if (!t) return;
        if (t.requiresFilePicker) {
            openImagePicker(-1, "", "", false);
            return;
        }
        let def = WidgetRegistry.defaultSize(typeKey);
        let defW = def.w;
        let defH = def.h;
        let spawnX = Math.max(0, (redactorMode.safeWidth - s(defW)) / 2);
        let spawnY = Math.max(0, (redactorMode.safeHeight - s(defH)) / 2);
        let newId = "w_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

        if (redactorMode.gridEnabled) {
            let snapped = geometry.snapBoxToGrid(null, spawnX, spawnY, defW, defH);
            spawnX = snapped.x;
            spawnY = snapped.y;
            defW = snapped.w;
            defH = snapped.h;
        }

        let defVariant = WidgetRegistry.defaultVariant(typeKey);

        activeWidgetsModel.append({
            "wType": typeKey,
            "wVariant": defVariant,
            "wX": spawnX,
            "wY": spawnY,
            "wWidth": defW,
            "wHeight": defH,
            "wOpacity": 1.0,
            "wRotation": 0,
            "wImagePath": "",
            "wId": newId
        });

        redactorMode.topZ += 1;
        redactorMode.selectedId = newId;
        host.targetSelectedWidgetId = newId;
        WidgetSync.addWidget(redactorWindow.safeMonitorName, newId, typeKey, spawnX, spawnY, defW, defH, 1.0, "", 0, defVariant);
        WidgetSync.bringToFront(redactorWindow.safeMonitorName, newId);
        redactorMode.updateToolbarObscured();
    }

    function setWidgetProperty(propName, val, targetId) {
        let tid = targetId || redactorMode.selectedId;
        if (!tid) return;
        for (let i = 0; i < activeWidgetsModel.count; i++) {
            let row = activeWidgetsModel.get(i);
            if (String(row.wId) === String(tid)) {
                activeWidgetsModel.setProperty(i, propName, val);
                let proxy = widgetRepeater.itemAt(i);
                if (proxy) {
                    if (proxy.preview && proxy.preview.item) {
                        try {
                            if (proxy.preview.item[propName] !== undefined) {
                                proxy.preview.item[propName] = val;
                            }
                        } catch (e) {}
                    }
                    if (typeof WidgetSync !== "undefined") {
                        if (typeof WidgetSync.setProperty === "function") {
                            WidgetSync.setProperty(redactorWindow.safeMonitorName, String(tid), propName, val);
                        } else if (typeof WidgetSync.setWidgetProperty === "function") {
                            WidgetSync.setWidgetProperty(redactorWindow.safeMonitorName, String(tid), propName, val);
                        } else if (typeof WidgetSync.setCustomProperty === "function") {
                            WidgetSync.setCustomProperty(redactorWindow.safeMonitorName, String(tid), propName, val);
                        }
                    }
                    proxy.finalizeSync();
                }
                break;
            }
        }
    }

    function updateWidgetProperty(target, propName, val) {
        let tid = (target && (target.wId || target.id)) ? (target.wId || target.id) : redactorMode.selectedId;
        setWidgetProperty(propName, val, tid);
    }

    function resetHistory() {
        historyStore.resetHistory();
    }

    function commitHistory() {
        historyStore.commitHistory();
    }

    function undo() {
        historyStore.undo();
    }

    function redo() {
        historyStore.redo();
    }

    Timer {
        id: historyTimer
        interval: 400
        repeat: false
        onTriggered: redactorMode.commitHistory()
    }

    Connections {
        target: activeWidgetsModel
        function onCountChanged() { historyTimer.restart(); }
    }

    function saveConfig() {
        for (let i = 0; i < widgetRepeater.count; i++) {
            let proxy = widgetRepeater.itemAt(i);
            if (proxy) proxy.finalizeSync();
        }
    }

    function save() {
        saveConfig();
    }

    function handleAdditionalAction(action, itemIndex, itemId, proxy, extraArg) {
        if (action === "pickImage") {
            let row = (itemIndex >= 0 && itemIndex < activeWidgetsModel.count) ? activeWidgetsModel.get(itemIndex) : null;
            let curImg = row ? (row.wImagePath || "") : "";
            openImagePicker(itemIndex, itemId, curImg, proxy.wVariant === "round");
        } else if (action === "stretchWidth") {
            let item = (itemIndex >= 0 && itemIndex < activeWidgetsModel.count) ? activeWidgetsModel.get(itemIndex) : null;
            if (!item) return;

            let rot = Math.abs(Math.round(proxy.wRotation || 0)) % 360;
            if (rot % 180 === 0) {
                activeWidgetsModel.setProperty(itemIndex, "wX", 0);
                activeWidgetsModel.setProperty(itemIndex, "wWidth", redactorMode.safeWidth);
            } else {
                activeWidgetsModel.setProperty(itemIndex, "wY", 0);
                activeWidgetsModel.setProperty(itemIndex, "wWidth", redactorMode.safeHeight);
            }
            proxy.finalizeSync();
        } else if (extraArg !== undefined) {
            setWidgetProperty(action, extraArg, itemId);
        }
    }

    function resolveThemeColor(colorName) {
        if (colorName === "mauve") return ThemeBackend.mauve;
        if (colorName === "surface0") return ThemeBackend.surface0;
        if (colorName === "surface1") return ThemeBackend.surface1;
        if (colorName === "crust") return ThemeBackend.crust;
        if (colorName === "base") return ThemeBackend.base;
        if (colorName === "red") return ThemeBackend.red;
        return ThemeBackend.text;
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

    RedactorSnapOverlay {
        guideLines: geometry.guideLines
        measureLines: geometry.measureLines
    }

    Item {
        id: workspaceArea
        readonly property var owner: redactorMode
        anchors.fill: parent

        Loader {
            anchors.fill: parent
            active: redactorMode.gridEnabled
            sourceComponent: ShaderEffect {
                id: gridShader
                anchors.fill: parent
                property vector2d itemSize: Qt.vector2d(width, height)
                property real stepSize: s(20)
                property real lineWidth: 1.0
                property color lineColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.1)

                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/grid_pattern.frag.qsb"
            }
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
                    let type = item.wType || item.type || "time";
                    let variant = item.wVariant || item.variant || WidgetRegistry.defaultVariant(type);
                    let sVal = item.wScale !== undefined ? parseFloat(item.wScale) : 1.0;
                    let defSize = WidgetRegistry.defaultSize(type);
                    let defW = defSize.w;
                    let defH = defSize.h;
                    let w = item.wWidth !== undefined ? parseFloat(item.wWidth) : defW * sVal;
                    let h = item.wHeight !== undefined ? parseFloat(item.wHeight) : defH * sVal;
                    let op = item.wOpacity !== undefined ? parseFloat(item.wOpacity) : 1.0;
                    let rot = (item.wRotation !== undefined) ? parseFloat(item.wRotation) : (item.rotation !== undefined ? parseFloat(item.rotation) : 0);
                    if (isNaN(rot)) rot = 0;
                    rot = ((Math.round(rot) % 360) + 360) % 360;
                    let imgPath = item.wImagePath || item.imagePath || item.path || "";

                    let entry = {
                        wType: type,
                        wVariant: variant,
                        wX: item.wX !== undefined ? parseFloat(item.wX) : 100,
                        wY: item.wY !== undefined ? parseFloat(item.wY) : 100,
                        wWidth: w,
                        wHeight: h,
                        wOpacity: op,
                        wRotation: rot,
                        wImagePath: imgPath,
                        wId: String(item.wId || item.id || ("w_" + Date.now() + "_" + i))
                    };

                    for (let key in item) {
                        if (entry[key] === undefined && !WidgetRegistry.standardKeys.includes(key)) {
                            entry[key] = item[key];
                        }
                    }

                    activeWidgetsModel.append(entry);
                }
            } catch (e) {}
        }
        redactorMode.isReady = true;
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

    RedactorImagePicker {
        id: imagePickerLoader
        host: redactorMode.host
        redactorMode: redactorMode
        redactorWindow: redactorMode.redactorWindow
    }
}
