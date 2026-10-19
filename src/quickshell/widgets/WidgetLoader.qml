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

    function getScreenWidth() {
        if (loaderRoot.screen && loaderRoot.screen.width > 0) {
            return loaderRoot.screen.width;
        }
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && (scr.name === loaderRoot.monitorName || scr === loaderRoot.screen)) {
                    if (scr.width > 0) return scr.width;
                }
            }
            if (Quickshell.screens[0].width > 0) return Quickshell.screens[0].width;
        }
        return 1920;
    }

    function getScreenHeight() {
        if (loaderRoot.screen && loaderRoot.screen.height > 0) {
            return loaderRoot.screen.height;
        }
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && (scr.name === loaderRoot.monitorName || scr === loaderRoot.screen)) {
                    if (scr.height > 0) return scr.height;
                }
            }
            if (Quickshell.screens[0].height > 0) return Quickshell.screens[0].height;
        }
        return 1080;
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

    function isTargetMonitor(mon) {
        if (!mon) return false;
        let m = String(mon).trim().toLowerCase();
        let safe = String(loaderRoot.safeMonitorName).trim().toLowerCase();
        let raw = String(loaderRoot.monitorName).trim().toLowerCase();
        let scr = (loaderRoot.screen && loaderRoot.screen.name) ? String(loaderRoot.screen.name).trim().toLowerCase() : "";
        let scrSafe = scr.replace(/[^a-zA-Z0-9_-]/g, "_");
        let matches = (m === safe || m === raw || (scr !== "" && (m === scr || m === scrSafe)));
        return matches;
    }

    function toBase64(str) {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
        let utf8 = [];
        for (let i = 0; i < str.length; i++) {
            let c = str.charCodeAt(i);
            if (c < 128) {
                utf8.push(c);
            } else if (c < 2048) {
                utf8.push((c >> 6) | 192, (c & 63) | 128);
            } else if (((c & 0xFC00) === 0xD800) && (i + 1 < str.length) && ((str.charCodeAt(i + 1) & 0xFC00) === 0xDC00)) {
                let c2 = str.charCodeAt(++i);
                let cp = 0x10000 + (((c & 0x3FF) << 10) | (c2 & 0x3FF));
                utf8.push((cp >> 18) | 240, ((cp >> 12) & 63) | 128, ((cp >> 6) & 63) | 128, (cp & 63) | 128);
            } else {
                utf8.push((c >> 12) | 224, ((c >> 6) & 63) | 128, (c & 63) | 128);
            }
        }
        let res = "";
        let idx = 0;
        while (idx < utf8.length) {
            let b1 = utf8[idx++];
            let b2 = idx < utf8.length ? utf8[idx++] : NaN;
            let b3 = idx < utf8.length ? utf8[idx++] : NaN;

            let e1 = b1 >> 2;
            let e2 = ((b1 & 3) << 4) | (isNaN(b2) ? 0 : b2 >> 4);
            let e3 = isNaN(b2) ? 64 : (((b2 & 15) << 2) | (isNaN(b3) ? 0 : b3 >> 6));
            let e4 = isNaN(b3) ? 64 : (b3 & 63);

            res += chars.charAt(e1) + chars.charAt(e2) + chars.charAt(e3) + chars.charAt(e4);
        }
        return res;
    }

    function toRecord(item) {
        return {
            wType: item.wType || "time",
            wVariant: item.wVariant || WidgetRegistry.defaultVariant(item.wType || "time"),
            wX: item.wX,
            wY: item.wY,
            wWidth: item.wWidth,
            wHeight: item.wHeight,
            wOpacity: item.wOpacity !== undefined ? item.wOpacity : 1.0,
            wRotation: (item.wRotation !== undefined && !isNaN(item.wRotation)) ? item.wRotation : 0,
            wImagePath: item.wImagePath || "",
            imagePath: item.wImagePath || "",
            wId: item.wId,
            stretchWidth: !!item.stretchWidth,
            stretchHeight: !!item.stretchHeight,
            wProps: item.wProps || {},
            isRemoving: false
        };
    }

    function toJson(item) {
        let o = Object.assign({}, item.wProps || {});
        let normRot = ((Math.round(parseFloat(item.wRotation) || 0) % 360) + 360) % 360;
        o.type = item.wType || "time";
        o.wType = o.type;
        o.wVariant = item.wVariant || WidgetRegistry.defaultVariant(o.type);
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

    function saveNow() {
        saveTimer.stop();
        let data = [];
        for (let i = 0; i < widgetsModel.count; i++) {
            let item = widgetsModel.get(i);
            if (item.isRemoving) continue;
            data.push(toJson(item));
        }
        let jsonStr = JSON.stringify(data);
        let b64Data = toBase64(jsonStr);
        let targetDir = Caching.getStateDir("widgets/" + loaderRoot.safeMonitorName);
        let targetFile = targetDir + "/layout.json";
        let saveScript = "mkdir -p '" + targetDir + "' && printf '%s' '" + b64Data + "' | base64 -d > '" + targetFile + "'";
        Quickshell.execDetached(["bash", "-c", saveScript]);
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: loaderRoot.saveNow()
    }

    Process {
        id: loadProcess
        command: ["bash", "-c", "cat '" + Caching.getStateDir("widgets/" + loaderRoot.safeMonitorName) + "/layout.json' 2>/dev/null || echo '[]'"]
        property string output: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => loadProcess.output += data
        }
        onExited: {
            let trimmed = output.trim();
            if (trimmed !== "") {
                try {
                    let data = JSON.parse(trimmed);
                    widgetsModel.clear();
                    let needSave = false;
                    let sw = loaderRoot.getScreenWidth();
                    let sh = loaderRoot.getScreenHeight();

                    for (let i = 0; i < data.length; i++) {
                        let item = data[i];
                        let itemId = item.wId || item.id;
                        if (!itemId) {
                            itemId = "w_" + Date.now() + "_" + i + "_" + Math.floor(Math.random() * 1000);
                            needSave = true;
                        }

                        let type = item.wType || item.type || "time";
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

                        let op = item.wOpacity !== undefined ? parseFloat(item.wOpacity) : 1.0;
                        let rot = (item.wRotation !== undefined) ? parseFloat(item.wRotation) : (item.rotation !== undefined ? parseFloat(item.rotation) : 0);
                        if (isNaN(rot)) rot = 0;
                        rot = ((Math.round(rot) % 360) + 360) % 360;
                        let imgPath = item.wImagePath || item.imagePath || item.path || "";

                        widgetsModel.append({
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
                        });
                    }
                    if (needSave) {
                        loaderRoot.saveNow();
                    }
                } catch (e) {
                }
            }
        }
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    Connections {
        target: WidgetSync

        function onPresetApplied(monitor, widgetsList) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            if (!widgetsList) return;
            let len = widgetsList.length !== undefined ? widgetsList.length : 0;
            widgetsModel.clear();

            let sw = loaderRoot.getScreenWidth();
            let sh = loaderRoot.getScreenHeight();

            for (let i = 0; i < len; i++) {
                let item = widgetsList[i];
                let type = item.wType || item.type || "time";
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
                let rot = (item.wRotation !== undefined) ? parseFloat(item.wRotation) : (item.rotation !== undefined ? parseFloat(item.rotation) : 0);
                if (isNaN(rot)) rot = 0;
                rot = ((Math.round(rot) % 360) + 360) % 360;
                let imgPath = item.wImagePath || item.imagePath || item.path || "";
                let itemId = item.wId || item.id || ("w_" + Date.now() + "_" + i + "_" + Math.floor(Math.random() * 1000));

                widgetsModel.append({
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
                });
            }
            loaderRoot.saveNow();
        }

        function onPositionChanged(monitor, widgetId, x, y) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wX", x);
                    widgetsModel.setProperty(i, "wY", y);
                    loaderRoot.syncStretchFlags(i, x, y, item.wWidth, item.wHeight);
                    saveTimer.restart();
                    break;
                }
            }
        }

        function onGeometryChanged(monitor, widgetId, x, y, w, h, opacity, rotation) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wX", x);
                    widgetsModel.setProperty(i, "wY", y);
                    widgetsModel.setProperty(i, "wWidth", w);
                    widgetsModel.setProperty(i, "wHeight", h);
                    if (opacity !== undefined) widgetsModel.setProperty(i, "wOpacity", opacity);
                    if (rotation !== undefined && !isNaN(rotation)) widgetsModel.setProperty(i, "wRotation", rotation);
                    loaderRoot.syncStretchFlags(i, x, y, w, h);
                    saveTimer.restart();
                    break;
                }
            }
        }

        function onOpacityChanged(monitor, widgetId, opacity) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                if (String(widgetsModel.get(i).wId).trim() === target) {
                    widgetsModel.setProperty(i, "wOpacity", opacity);
                    saveTimer.restart();
                    break;
                }
            }
        }

        function onRotationChanged(monitor, widgetId, rotation) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                if (String(widgetsModel.get(i).wId).trim() === target) {
                    widgetsModel.setProperty(i, "wRotation", rotation);
                    saveTimer.restart();
                    break;
                }
            }
        }

        function onVariantChanged(monitor, widgetId, variant) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                if (String(widgetsModel.get(i).wId).trim() === target) {
                    widgetsModel.setProperty(i, "wVariant", variant);
                    loaderRoot.saveNow();
                    break;
                }
            }
        }

        function onImagePathChanged(monitor, widgetId, imagePath) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                if (String(widgetsModel.get(i).wId).trim() === target) {
                    widgetsModel.setProperty(i, "wImagePath", imagePath);
                    loaderRoot.saveNow();
                    break;
                }
            }
        }

        function onPropertyChanged(monitor, widgetId, propName, val) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            if (WidgetRegistry.standardKeys.includes(propName)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    let p = Object.assign({}, item.wProps || {});
                    p[propName] = val;
                    widgetsModel.setProperty(i, "wProps", p);
                    saveTimer.restart();
                    break;
                }
            }
        }

        function onWidgetAdded(monitor, widgetId, type, x, y, w, h, opacity, imagePath, rotation, variant) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                if (String(widgetsModel.get(i).wId).trim() === target) return;
            }
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
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (item && String(item.wId).trim() === target) {
                    widgetsModel.remove(i, 1);
                    loaderRoot.saveNow();
                    break;
                }
            }
        }

        function onWidgetsByTypeRemoved(monitor, type) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let matched = false;
            for (let i = widgetsModel.count - 1; i >= 0; i--) {
                let item = widgetsModel.get(i);
                if (item && item.wType === type) {
                    widgetsModel.remove(i, 1);
                    matched = true;
                }
            }
            if (matched) {
                loaderRoot.saveNow();
            }
        }

        function onWidgetsCleared(monitor) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            widgetsModel.clear();
            loaderRoot.saveNow();
        }

        function onBringToFrontRequested(monitor, widgetId) {
            if (!loaderRoot.isTargetMonitor(monitor)) return;
            let target = String(widgetId).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    if (i < widgetsModel.count - 1) {
                        let obj = toRecord(item);
                        widgetsModel.remove(i, 1);
                        widgetsModel.append(obj);
                        loaderRoot.saveNow();
                    }
                    break;
                }
            }
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
            if (!flag && loaderRoot.isRedacting) {
                loaderRoot.saveNow();
            }
            loaderRoot.isRedacting = flag;
            return "ok";
        }

        function save(): string {
            loaderRoot.saveNow();
            return "ok";
        }

        function reload(): string {
            saveTimer.stop();
            loadProcess.output = "";
            loadProcess.running = false;
            loadProcess.running = true;
            return "ok";
        }

        function add(id: string, type: string, x: string, y: string, w: string, h: string, op: string, imgPath: string, rot: string): string {
            let defSize = WidgetRegistry.defaultSize(type);
            let variant = WidgetRegistry.defaultVariant(type);
            let rotVal = (rot !== undefined && rot !== "") ? parseFloat(rot) : 0;
            if (isNaN(rotVal)) rotVal = 0;

            widgetsModel.append({
                wType: type,
                wVariant: variant,
                wX: x !== undefined ? parseFloat(x) : 100,
                wY: y !== undefined ? parseFloat(y) : 100,
                wWidth: w !== undefined ? parseFloat(w) : defSize.w,
                wHeight: h !== undefined ? parseFloat(h) : defSize.h,
                wOpacity: op !== undefined ? parseFloat(op) : 1.0,
                wRotation: rotVal,
                wImagePath: imgPath !== undefined ? imgPath : "",
                wId: String(id).trim(),
                stretchWidth: false,
                stretchHeight: false,
                wProps: {},
                isRemoving: false
            });
            loaderRoot.saveNow();
            return "ok";
        }

        function geometry(id: string, x: string, y: string, w: string, h: string, op: string, rot: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wX", parseFloat(x));
                    widgetsModel.setProperty(i, "wY", parseFloat(y));
                    widgetsModel.setProperty(i, "wWidth", parseFloat(w));
                    widgetsModel.setProperty(i, "wHeight", parseFloat(h));
                    if (op !== undefined) {
                        widgetsModel.setProperty(i, "wOpacity", parseFloat(op));
                    }
                    if (rot !== undefined && rot !== "") {
                        let r = parseFloat(rot);
                        if (!isNaN(r)) widgetsModel.setProperty(i, "wRotation", r);
                    }
                    saveTimer.restart();
                    return "ok";
                }
            }
            return "not_found";
        }

        function rotate(id: string, rot: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    let r = (rot !== undefined && rot !== "") ? parseFloat(rot) : 0;
                    if (isNaN(r)) r = 0;
                    widgetsModel.setProperty(i, "wRotation", r);
                    saveTimer.restart();
                    return "ok";
                }
            }
            return "not_found";
        }

        function opacity(id: string, op: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wOpacity", parseFloat(op));
                    saveTimer.restart();
                    return "ok";
                }
            }
            return "not_found";
        }

        function imagePath(id: string, path: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wImagePath", path);
                    loaderRoot.saveNow();
                    return "ok";
                }
            }
            return "not_found";
        }

        function move(id: string, x: string, y: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                if (String(widgetsModel.get(i).wId).trim() === target) {
                    widgetsModel.setProperty(i, "wX", parseFloat(x));
                    widgetsModel.setProperty(i, "wY", parseFloat(y));
                    saveTimer.restart();
                    return "ok";
                }
            }
            return "not_found";
        }

        function resize(id: string, w: string, h: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wWidth", parseFloat(w));
                    widgetsModel.setProperty(i, "wHeight", parseFloat(h));
                    saveTimer.restart();
                    return "ok";
                }
            }
            return "not_found";
        }

        function variant(id: string, variant: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    widgetsModel.setProperty(i, "wVariant", variant);
                    loaderRoot.saveNow();
                    return "ok";
                }
            }
            return "not_found";
        }

        function remove(id: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (item && String(item.wId).trim() === target) {
                    widgetsModel.remove(i, 1);
                    loaderRoot.saveNow();
                    return "ok";
                }
            }
            return "not_found";
        }

        function bringToFront(id: string): string {
            let target = String(id).trim();
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (String(item.wId).trim() === target) {
                    if (i < widgetsModel.count - 1) {
                        let obj = toRecord(item);
                        widgetsModel.remove(i, 1);
                        widgetsModel.append(obj);
                        loaderRoot.saveNow();
                    }
                    return "ok";
                }
            }
            return "not_found";
        }

        function clear(): string {
            widgetsModel.clear();
            loaderRoot.saveNow();
            return "ok";
        }

        function list(): string {
            let data = [];
            for (let i = 0; i < widgetsModel.count; i++) {
                let item = widgetsModel.get(i);
                if (item.isRemoving) continue;
                data.push(toJson(item));
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
