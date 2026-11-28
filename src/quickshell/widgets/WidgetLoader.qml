import QtQuick
import Quickshell
import Quickshell.Io
import "faces"
import "../"
import "../singletons/widgetcontrols"

Item {
    id: loaderRoot

    required property var screen
    required property string monitorName
    readonly property string safeMonitorName: (monitorName || (screen ? screen.name : "default")).replace(/[^a-zA-Z0-9_-]/g, "_")

    property bool isRedacting: false

    function s(val) {
        return Math.round(Scaler.s(val));
    }

    function resolveScreen() {
        if (loaderRoot.screen) return loaderRoot.screen;
        let byName = Compositor.screenByName(loaderRoot.monitorName);
        if (byName) return byName;
        return (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
    }

    function getScreenWidth() {
        let scr = loaderRoot.resolveScreen();
        return (scr && scr.width > 0) ? scr.width : 1920;
    }

    function getScreenHeight() {
        let scr = loaderRoot.resolveScreen();
        return (scr && scr.height > 0) ? scr.height : 1080;
    }

    function isTargetMonitor(mon) {
        if (!mon) return false;
        if (WidgetSync.matchesMonitor(mon, loaderRoot.safeMonitorName)) return true;
        if (WidgetSync.matchesMonitor(mon, loaderRoot.monitorName)) return true;
        if (loaderRoot.screen && loaderRoot.screen.name && WidgetSync.matchesMonitor(mon, loaderRoot.screen.name)) return true;
        return false;
    }

    function findWidgetIndex(widgetId) {
        let target = String(widgetId || "").trim();
        for (let i = 0; i < widgetsModel.count; i++) {
            if (String(widgetsModel.get(i).wId).trim() === target) return i;
        }
        return -1;
    }

    function syncStretchFlags(index, x, y, w, h) {
        let item = widgetsModel.get(index);
        if (item.stretchWidth && (Math.abs(x) > 0.5 || Math.abs(w - getScreenWidth()) > 0.5)) {
            widgetsModel.setProperty(index, "stretchWidth", false);
        }
        if (item.stretchHeight && (Math.abs(y) > 0.5 || Math.abs(h - getScreenHeight()) > 0.5)) {
            widgetsModel.setProperty(index, "stretchHeight", false);
        }
    }

    ListModel {
        id: widgetsModel
        dynamicRoles: true
    }

    function cloneProps(props) {
        let out = {};
        if (!props) return out;
        for (let k in props) {
            if (!k || typeof k !== "string" || k === "objectName" || k.endsWith("Changed") || k.startsWith("on") || typeof props[k] === "function" || props[k] === undefined) continue;
            out[k] = props[k];
        }
        return out;
    }

    function toRecord(item) {
        let defType = WidgetRegistry.defaultType;
        let t = item.wType || defType;
        return {
            wType: t,
            wVariant: item.wVariant || WidgetRegistry.defaultVariant(t),
            wX: item.wX,
            wY: item.wY,
            wWidth: item.wWidth,
            wHeight: item.wHeight,
            wOpacity: item.wOpacity !== undefined ? item.wOpacity : 1.0,
            wRotation: (item.wRotation !== undefined && !isNaN(item.wRotation)) ? item.wRotation : 0,
            wImagePath: item.wImagePath || "",
            wId: item.wId,
            stretchWidth: !!item.stretchWidth,
            stretchHeight: !!item.stretchHeight,
            wProps: loaderRoot.cloneProps(item.wProps),
            isRemoving: false
        };
    }

    function toJson(item) {
        let o = loaderRoot.cloneProps(item.wProps);
        let normRot = ((Math.round(parseFloat(item.wRotation) || 0) % 360) + 360) % 360;
        let t = item.wType || WidgetRegistry.defaultType;
        o.type = t;
        o.wType = t;
        o.wVariant = item.wVariant || WidgetRegistry.defaultVariant(t);
        o.wX = item.wX;
        o.wY = item.wY;
        o.wWidth = item.wWidth;
        o.wHeight = item.wHeight;
        o.wOpacity = item.wOpacity !== undefined ? item.wOpacity : 1.0;
        o.wRotation = normRot;
        o.wImagePath = item.wImagePath || "";
        o.imagePath = o.wImagePath;
        o.wId = item.wId;
        o.stretchWidth = !!item.stretchWidth;
        o.stretchHeight = !!item.stretchHeight;
        return o;
    }

    function normalizeWidgetRecord(item, index, sw, sh) {
        let generatedId = false;
        let itemId = item.wId || item.id;
        if (!itemId) {
            itemId = "w_" + Date.now() + "_" + index + "_" + Math.floor(Math.random() * 1000);
            generatedId = true;
        }

        let type = item.wType || item.type || WidgetRegistry.defaultType;
        let variant = item.wVariant || item.variant || WidgetRegistry.defaultVariant(type);
        let defSize = WidgetRegistry.defaultSize(type);

        let isStretchW = !!(item.stretchWidth || item.wStretchWidth);
        let isStretchH = !!(item.stretchHeight || item.wStretchHeight);

        let rawW = item.wWidth !== undefined ? item.wWidth : (item.w !== undefined ? item.w : (item.width !== undefined ? item.width : defSize.w));
        let rawH = item.wHeight !== undefined ? item.wHeight : (item.h !== undefined ? item.h : (item.height !== undefined ? item.height : defSize.h));
        let w = isStretchW ? sw : WidgetRegistry.resolveDimension(rawW, sw, defSize.w);
        let h = isStretchH ? sh : WidgetRegistry.resolveDimension(rawH, sh, defSize.h);

        let x = 100;
        let y = 100;
        let hasAnchor = !!(item.anchor || item.anchors || item.anchorH || item.anchorV || item.anchorX || item.anchorY || item.horizontalAnchor || item.verticalAnchor || item.hAnchor || item.vAnchor);
        if (hasAnchor) {
            let pos = WidgetRegistry.resolvePosition(item, sw, sh, w, h);
            x = pos.x;
            y = pos.y;
        } else {
            x = item.wX !== undefined ? parseFloat(item.wX) : (item.x !== undefined ? parseFloat(item.x) : 100);
            y = item.wY !== undefined ? parseFloat(item.wY) : (item.y !== undefined ? parseFloat(item.y) : 100);
        }

        if (isStretchW) x = 0;
        if (isStretchH) y = 0;
        if (isNaN(x)) x = 100;
        if (isNaN(y)) y = 100;

        let op = item.wOpacity !== undefined ? parseFloat(item.wOpacity) : (item.opacity !== undefined ? parseFloat(item.opacity) : 1.0);
        if (isNaN(op)) op = 1.0;
        let rot = item.wRotation !== undefined ? parseFloat(item.wRotation) : (item.rotation !== undefined ? parseFloat(item.rotation) : 0);
        if (isNaN(rot)) rot = 0;
        rot = ((Math.round(rot) % 360) + 360) % 360;
        let imgPath = item.wImagePath || item.imagePath || item.path || "";

        return {
            generatedId: generatedId,
            record: {
                wType: type,
                wVariant: variant,
                wX: x,
                wY: y,
                wWidth: w,
                wHeight: h,
                wOpacity: op,
                wRotation: rot,
                wImagePath: imgPath,
                wId: String(itemId),
                stretchWidth: isStretchW,
                stretchHeight: isStretchH,
                wProps: WidgetRegistry.extractProps(item),
                isRemoving: false
            }
        };
    }

    function applyWidgetsArray(list, forceSave) {
        if (!Array.isArray(list)) return;
        widgetsModel.clear();
        let needSave = !!forceSave;
        let sw = loaderRoot.getScreenWidth();
        let sh = loaderRoot.getScreenHeight();

        for (let i = 0; i < list.length; i++) {
            let norm = loaderRoot.normalizeWidgetRecord(list[i], i, sw, sh);
            if (norm.generatedId) needSave = true;
            widgetsModel.append(norm.record);
        }

        if (needSave) loaderRoot.saveNow();
    }

    function saveNow() {
        saveTimer.stop();
        let data = [];
        for (let i = 0; i < widgetsModel.count; i++) {
            let item = widgetsModel.get(i);
            if (item.isRemoving) continue;
            data.push(loaderRoot.toJson(item));
        }
        layoutFile.save(data);
    }

    JsonStateFile {
        id: layoutFile
        path: Caching.getStateDir("widgets/" + loaderRoot.safeMonitorName) + "/layout.json"
        watchChanges: true
        printErrors: false
        onLoaded: (data) => {
            if (Array.isArray(data)) {
                loaderRoot.applyWidgetsArray(data, false);
            } else if (data === null) {
                widgetsModel.clear();
            }
        }
        onLoadFailed: widgetsModel.clear()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: loaderRoot.saveNow()
    }

    Connections {
        target: WidgetSync

        function onPresetApplied(monitor, widgetsList) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            if (!widgetsList) return;
            let arr = [];
            let len = widgetsList.length !== undefined ? widgetsList.length : 0;
            for (let i = 0; i < len; i++) arr.push(widgetsList[i]);
            loaderRoot.applyWidgetsArray(arr, true);
        }

        function onPositionChanged(monitor, widgetId, x, y) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            let item = widgetsModel.get(idx);
            widgetsModel.setProperty(idx, "wX", x);
            widgetsModel.setProperty(idx, "wY", y);
            loaderRoot.syncStretchFlags(idx, x, y, item.wWidth, item.wHeight);
            saveTimer.restart();
        }

        function onGeometryChanged(monitor, widgetId, x, y, w, h, opacity, rotation) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            widgetsModel.setProperty(idx, "wX", x);
            widgetsModel.setProperty(idx, "wY", y);
            widgetsModel.setProperty(idx, "wWidth", w);
            widgetsModel.setProperty(idx, "wHeight", h);
            if (opacity !== undefined && !isNaN(opacity)) widgetsModel.setProperty(idx, "wOpacity", opacity);
            if (rotation !== undefined && !isNaN(rotation)) widgetsModel.setProperty(idx, "wRotation", rotation);
            loaderRoot.syncStretchFlags(idx, x, y, w, h);
            saveTimer.restart();
        }

        function onOpacityChanged(monitor, widgetId, opacity) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            widgetsModel.setProperty(idx, "wOpacity", opacity);
            saveTimer.restart();
        }

        function onRotationChanged(monitor, widgetId, rotation) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            widgetsModel.setProperty(idx, "wRotation", rotation);
            saveTimer.restart();
        }

        function onVariantChanged(monitor, widgetId, variant) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            widgetsModel.setProperty(idx, "wVariant", variant);
            loaderRoot.saveNow();
        }

        function onImagePathChanged(monitor, widgetId, imagePath) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            widgetsModel.setProperty(idx, "wImagePath", imagePath);
            loaderRoot.saveNow();
        }

        function onPropertyChanged(monitor, widgetId, propName, val) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            if (WidgetRegistry.standardKeys.includes(propName)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            let p = loaderRoot.cloneProps(widgetsModel.get(idx).wProps);
            p[propName] = val;
            widgetsModel.setProperty(idx, "wProps", p);
            saveTimer.restart();
        }

        function onWidgetAdded(monitor, widgetId, type, x, y, w, h, opacity, imagePath, rotation, variant) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            if (loaderRoot.findWidgetIndex(target) >= 0) return;
            let defSize = WidgetRegistry.defaultSize(type);
            let finalVariant = (variant && variant !== "") ? variant : WidgetRegistry.defaultVariant(type);
            widgetsModel.append({
                wType: type,
                wVariant: finalVariant,
                wX: x !== undefined ? x : 100,
                wY: y !== undefined ? y : 100,
                wWidth: w !== undefined ? w : defSize.w,
                wHeight: h !== undefined ? h : defSize.h,
                wOpacity: opacity !== undefined ? opacity : 1.0,
                wRotation: rotation !== undefined ? rotation : 0,
                wImagePath: imagePath || "",
                wId: target,
                stretchWidth: false,
                stretchHeight: false,
                wProps: {},
                isRemoving: false
            });
            loaderRoot.saveNow();
        }

        function onWidgetRemoved(monitor, widgetId) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0) return;
            widgetsModel.remove(idx, 1);
            loaderRoot.saveNow();
        }

        function onWidgetsCleared(monitor) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            widgetsModel.clear();
            loaderRoot.saveNow();
        }

        function onBringToFrontRequested(monitor, widgetId) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let idx = loaderRoot.findWidgetIndex(widgetId);
            if (idx < 0 || idx >= widgetsModel.count - 1) return;
            let obj = loaderRoot.toRecord(widgetsModel.get(idx));
            widgetsModel.remove(idx, 1);
            widgetsModel.append(obj);
            loaderRoot.saveNow();
        }

        function onRedactModeChanged(monitor, active) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            if (!active && loaderRoot.isRedacting) {
                loaderRoot.saveNow();
            }
            loaderRoot.isRedacting = active;
        }
    }

    IpcHandler {
        target: "widgets-" + loaderRoot.safeMonitorName

        function setRedactMode(active: string): string {
            let flag = (active === "true" || active === "1");
            WidgetSync.setRedactMode(loaderRoot.safeMonitorName, flag);
            return "ok";
        }

        function save(): string {
            loaderRoot.saveNow();
            return "ok";
        }

        function applyPreset(widgetsJson: string): string {
            try {
                WidgetSync.applyPreset(loaderRoot.safeMonitorName, JSON.parse(widgetsJson), true);
            } catch (e) {
                return "invalid";
            }
            return "ok";
        }

        function reload(): string {
            saveTimer.stop();
            layoutFile.reload();
            return "ok";
        }

        function add(id: string, type: string, x: string, y: string, w: string, h: string, op: string, imgPath: string, rot: string): string {
            let defSize = WidgetRegistry.defaultSize(type);
            let variant = WidgetRegistry.defaultVariant(type);
            let rotVal = (rot !== undefined && rot !== "") ? parseFloat(rot) : 0;
            if (isNaN(rotVal)) rotVal = 0;
            WidgetSync.addWidget(
                loaderRoot.safeMonitorName,
                String(id).trim(),
                type,
                x !== undefined ? parseFloat(x) : 100,
                y !== undefined ? parseFloat(y) : 100,
                w !== undefined ? parseFloat(w) : defSize.w,
                h !== undefined ? parseFloat(h) : defSize.h,
                op !== undefined ? parseFloat(op) : 1.0,
                imgPath !== undefined ? imgPath : "",
                rotVal,
                variant
            );
            return "ok";
        }

        function geometry(id: string, x: string, y: string, w: string, h: string, op: string, rot: string): string {
            let idx = loaderRoot.findWidgetIndex(id);
            if (idx < 0) return "not_found";
            let item = widgetsModel.get(idx);
            let opVal = op !== undefined && op !== "" ? parseFloat(op) : item.wOpacity;
            let rotVal = (rot !== undefined && rot !== "") ? parseFloat(rot) : item.wRotation;
            if (isNaN(rotVal)) rotVal = item.wRotation;
            WidgetSync.setGeometry(loaderRoot.safeMonitorName, String(id).trim(), parseFloat(x), parseFloat(y), parseFloat(w), parseFloat(h), opVal, rotVal);
            return "ok";
        }

        function rotate(id: string, rot: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            let r = (rot !== undefined && rot !== "") ? parseFloat(rot) : 0;
            if (isNaN(r)) r = 0;
            WidgetSync.setRotation(loaderRoot.safeMonitorName, String(id).trim(), r);
            return "ok";
        }

        function opacity(id: string, op: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            WidgetSync.setOpacity(loaderRoot.safeMonitorName, String(id).trim(), parseFloat(op));
            return "ok";
        }

        function imagePath(id: string, path: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            WidgetSync.setImagePath(loaderRoot.safeMonitorName, String(id).trim(), path);
            return "ok";
        }

        function move(id: string, x: string, y: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            WidgetSync.setPosition(loaderRoot.safeMonitorName, String(id).trim(), parseFloat(x), parseFloat(y));
            return "ok";
        }

        function resize(id: string, w: string, h: string): string {
            let idx = loaderRoot.findWidgetIndex(id);
            if (idx < 0) return "not_found";
            let item = widgetsModel.get(idx);
            WidgetSync.setGeometry(loaderRoot.safeMonitorName, String(id).trim(), item.wX, item.wY, parseFloat(w), parseFloat(h), item.wOpacity, item.wRotation);
            return "ok";
        }

        function variant(id: string, variant: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            WidgetSync.setVariant(loaderRoot.safeMonitorName, String(id).trim(), variant);
            return "ok";
        }

        function remove(id: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            WidgetSync.removeWidget(loaderRoot.safeMonitorName, String(id).trim());
            return "ok";
        }

        function bringToFront(id: string): string {
            if (loaderRoot.findWidgetIndex(id) < 0) return "not_found";
            WidgetSync.bringToFront(loaderRoot.safeMonitorName, String(id).trim());
            return "ok";
        }

        function clear(): string {
            WidgetSync.clearWidgets(loaderRoot.safeMonitorName);
            return "ok";
        }

        function list(): string {
            let data = [];
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (item.isRemoving) continue;
                data.push(loaderRoot.toJson(item));
            }
            return JSON.stringify(data);
        }
    }

    Instantiator {
        id: widgetInstantiator
        model: widgetsModel
        delegate: Widget {
            screen: loaderRoot.screen
            isRedacting: loaderRoot.isRedacting
            visible: !loaderRoot.isRedacting && !(model.isRemoving || false)
            wId: model.wId
            wType: model.wType
            wVariant: model.wVariant
            wX: model.wX
            wY: model.wY
            wWidth: model.wWidth
            wHeight: model.wHeight
            wOpacity: model.wOpacity !== undefined ? model.wOpacity : 1.0
            wRotation: (model.wRotation !== undefined && !isNaN(model.wRotation)) ? model.wRotation : 0
            wImagePath: model.wImagePath || ""
            customProps: model.wProps || ({})
        }
    }
}
