import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../reusables"
import "../"
import "."
import "../WindowRegistry.js" as WindowRegistry

Item {
    id: contentWrapper
    property var barWindow

    property string barStyle: {
        if (barWindow && barWindow.barStyle !== undefined) return barWindow.barStyle;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.style) {
            let s = Config.rawSettings.bar.style;
            if (typeof s === "string") return s;
            if (typeof s === "object") {
                if (s.fill || s.mode === "fill") return "fill";
                if (s.solid || s.mode === "solid") return "solid";
            }
        }
        return "modular";
    }
    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property real cornerRadius: barWindow ? barWindow.cornerRadius : 12
    property bool barAtBottom: !!barWindow && barWindow.barPosition === "bottom"
    property real fillAttachProgress: (isFill && barWindow && barWindow.fillAttached) ? 1.0 : 0.0
    property real fillFarRadius: Math.min(cornerRadius, barWindow ? barWindow.barHeight / 2 : cornerRadius) * fillAttachProgress

    Behavior on fillAttachProgress {
        enabled: contentWrapper.layoutAnimationsEnabled
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    property bool fillDetached: isFill && !!barWindow && !barWindow.fillAttached
    property bool outerCornersReady: fillDetached && solidBackground.x <= 3 && solidBackground.x + solidBackground.width >= contentWrapper.width - 3

    property bool suppressAnimation: false
    property bool layoutAnimationsEnabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging && !contentWrapper.suppressAnimation

    Timer {
        id: snapTimer
        interval: 200
        onTriggered: contentWrapper.suppressAnimation = false
    }

    Connections {
        target: contentWrapper.barWindow || null
        function onBarPositionChanged() {
            contentWrapper.suppressAnimation = true;
            snapTimer.restart();
        }
        function onPositionChangingChanged() {
            if (contentWrapper.barWindow && contentWrapper.barWindow.positionChanging) {
                contentWrapper.suppressAnimation = true;
            } else {
                snapTimer.restart();
            }
        }
        function onBaseOffsetYChanged() {
            contentWrapper.suppressAnimation = true;
            snapTimer.restart();
        }
        function onIsVerticalChanged() {
            contentWrapper.suppressAnimation = true;
            snapTimer.restart();
        }
    }

    property var defaultModuleSettings: {
        "left": ["left", "workspaces", "focus"],
        "center": ["timedate", "info", "weather", "media", "vis"],
        "right": ["tray", "sysmon", "kb", "wifi", "bt", "vol", "bat"]
    }

    function parseModuleSettings(ms) {
        if (!ms) return defaultModuleSettings;

        function migrate(arr) {
            if (!arr) return [];
            let res = [];
            for (let i = 0; i < arr.length; i++) {
                if (Array.isArray(arr[i])) {
                    let group = [];
                    for (let j = 0; j < arr[i].length; j++) {
                        if (arr[i][j] === "system") group.push("sysmon", "kb", "wifi", "bt", "vol", "bat");
                        else group.push(arr[i][j]);
                    }
                    if (group.length === 1) res.push(group[0]);
                    else if (group.length > 1) res.push(group);
                } else {
                    if (arr[i] === "system") res.push(["sysmon", "kb", "wifi", "bt", "vol", "bat"]);
                    else res.push(arr[i]);
                }
            }
            return res;
        }

        let l = migrate(ms.left);
        let c = migrate(ms.center);
        let r = migrate(ms.right);

        if (ms.active && !l.length && !c.length && !r.length) {
            let order = migrate(ms.active);
            let cIdx = -1;
            for (let i = 0; i < order.length; i++) {
                if (order[i] === "center" || (Array.isArray(order[i]) && order[i].indexOf("center") !== -1)) { cIdx = i; break; }
            }
            l = []; c = []; r = [];
            for (let i = 0; i < order.length; i++) {
                if (order[i] === "center" || (Array.isArray(order[i]) && order[i].indexOf("center") !== -1)) continue;
                if (cIdx === -1 || i < cIdx) l.push(order[i]);
                else r.push(order[i]);
            }
            c = ["timedate", "info", "weather"];
        }

        function filterCenter(arr) {
            let out = [];
            for (let i = 0; i < arr.length; i++) {
                if (Array.isArray(arr[i])) {
                    let filtered = arr[i].filter(id => id !== "center" && id !== "centerbox");
                    if (filtered.length === 1) out.push(filtered[0]);
                    else if (filtered.length > 1) out.push(filtered);
                } else if (arr[i] !== "center" && arr[i] !== "centerbox") {
                    out.push(arr[i]);
                }
            }
            return out;
        }

        return {
            "left": filterCenter(l),
            "center": filterCenter(c),
            "right": filterCenter(r)
        };
    }

    property var moduleSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.modules) ? parseModuleSettings(Config.rawSettings.bar.modules) : defaultModuleSettings

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            let ms = Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.modules ? Config.rawSettings.bar.modules : null;
            contentWrapper.moduleSettings = parseModuleSettings(ms);
        }
    }

    property string layoutState: {
        if (isFill) return "default";
        if (barWindow && barWindow.isNotifOpen) return "settings";
        if (barWindow && barWindow.isSysOpen) return "sys";
        return "default";
    }

    property var leftArr: contentWrapper.moduleSettings["left"] || []
    property var centerArr: contentWrapper.moduleSettings["center"] || []
    property var rightArr: contentWrapper.moduleSettings["right"] || []

    property var flatLeftArr: { let r=[]; for(let i=0; i<leftArr.length; i++){ if(Array.isArray(leftArr[i])) r.push(...leftArr[i]); else r.push(leftArr[i]); } return r; }
    property var flatCenterArr: { let r=[]; for(let i=0; i<centerArr.length; i++){ if(Array.isArray(centerArr[i])) r.push(...centerArr[i]); else r.push(centerArr[i]); } return r; }
    property var flatRightArr: { let r=[]; for(let i=0; i<rightArr.length; i++){ if(Array.isArray(rightArr[i])) r.push(...rightArr[i]); else r.push(rightArr[i]); } return r; }

    property var groupDefs: {
        let defs = [];
        let all = [contentWrapper.leftArr, contentWrapper.centerArr, contentWrapper.rightArr];
        for (let i = 0; i < all.length; i++) {
            for (let j = 0; j < all[i].length; j++) {
                if (Array.isArray(all[i][j])) defs.push(all[i][j]);
            }
        }
        return defs;
    }

    property bool trayInLeft: flatLeftArr.indexOf("tray") !== -1
    property bool trayInCenter: flatCenterArr.indexOf("tray") !== -1
    property bool trayInRight: flatRightArr.indexOf("tray") !== -1

    property bool trayAlignRight: {
        if (trayInLeft) return false;
        if (trayInRight) return true;
        if (trayInCenter) return layoutState !== "sys";
        return true;
    }

    property var moduleInstances: ({})
    property int modulesRev: 0

    function registerModuleInstance(id, inst) {
        moduleInstances[id] = inst;
        modulesRev++;
    }

    function getModuleItem(id) {
        let dummy = modulesRev;
        let norm = BarModuleRegistry.normalizeId(id);
        return moduleInstances[norm] || null;
    }

    readonly property var leftWidget: getModuleItem("left")
    readonly property var workspacesWidget: getModuleItem("workspaces")
    readonly property var focusWidget: getModuleItem("focus")
    readonly property var mediaWidget: getModuleItem("media")
    readonly property var visWidget: getModuleItem("vis")
    readonly property var trayWidget: getModuleItem("tray")
    readonly property var timeDateWidget: getModuleItem("timedate")
    readonly property var infoWidget: getModuleItem("info")
    readonly property var weatherWidget: getModuleItem("weather")
    readonly property var sysMonWidget: getModuleItem("sysmon")
    readonly property var kbWidget: getModuleItem("kb")
    readonly property var wifiWidget: getModuleItem("wifi")
    readonly property var btWidget: getModuleItem("bt")
    readonly property var volWidget: getModuleItem("vol")
    readonly property var batWidget: getModuleItem("bat")

    function isModuleActive(moduleId) {
        let norm = BarModuleRegistry.normalizeId(moduleId);
        let checkFlat = arr => {
            for (let i = 0; i < arr.length; i++) {
                if (BarModuleRegistry.normalizeId(arr[i]) === norm) return true;
            }
            return false;
        };
        return checkFlat(flatLeftArr) || checkFlat(flatCenterArr) || checkFlat(flatRightArr);
    }

    property int groupRev: 0

    function backdropFor(id) {
        void groupRev;
        if (isSolid) return solidBlur;
        if (!isModuleGrouped(id)) return null;
        for (let i = 0; i < groupBgRepeater.count; i++) {
            const g = groupBgRepeater.itemAt(i);
            if (g && g.groupIds && g.groupIds.indexOf(id) !== -1) return g.blurSurface;
        }
        return null;
    }

    function isModuleGrouped(id) {
        let norm = BarModuleRegistry.normalizeId(id);
        let allArrs = [leftArr, centerArr, rightArr];
        for (let a = 0; a < allArrs.length; a++) {
            for (let i = 0; i < allArrs[a].length; i++) {
                if (Array.isArray(allArrs[a][i])) {
                    for (let k = 0; k < allArrs[a][i].length; k++) {
                        if (BarModuleRegistry.normalizeId(allArrs[a][i][k]) === norm) return true;
                    }
                }
            }
        }
        return false;
    }

    property real wLeft: (isModuleActive("left") && leftWidget) ? (leftWidget.targetWidth !== undefined ? leftWidget.targetWidth : leftWidget.width) : 0
    property real wWorkspaces: (isModuleActive("workspaces") && workspacesWidget) ? (workspacesWidget.targetWidth !== undefined ? workspacesWidget.targetWidth : workspacesWidget.width) : 0
    property real wFocus: (isModuleActive("focus") && focusWidget) ? (focusWidget.targetWidth !== undefined ? focusWidget.targetWidth : focusWidget.width) : 0
    property real wMedia: (isModuleActive("media") && mediaWidget) ? (mediaWidget.targetWidth !== undefined ? mediaWidget.targetWidth : mediaWidget.width) : 0
    property real wVis: (isModuleActive("vis") && visWidget) ? (visWidget.targetWidth !== undefined ? visWidget.targetWidth : visWidget.width) : 0
    property real wTray: (isModuleActive("tray") && trayWidget) ? (trayWidget.targetWidth !== undefined ? trayWidget.targetWidth : trayWidget.width) : 0
    property real wSysmon: (isModuleActive("sysmon") && sysMonWidget) ? (sysMonWidget.targetWidth !== undefined ? sysMonWidget.targetWidth : sysMonWidget.width) : 0
    property real wKb: (isModuleActive("kb") && kbWidget) ? (kbWidget.targetWidth !== undefined ? kbWidget.targetWidth : kbWidget.width) : 0
    property real wWifi: (isModuleActive("wifi") && wifiWidget) ? (wifiWidget.targetWidth !== undefined ? wifiWidget.targetWidth : wifiWidget.width) : 0
    property real wBt: (isModuleActive("bt") && btWidget) ? (btWidget.targetWidth !== undefined ? btWidget.targetWidth : btWidget.width) : 0
    property real wVol: (isModuleActive("vol") && volWidget) ? (volWidget.targetWidth !== undefined ? volWidget.targetWidth : volWidget.width) : 0
    property real wBat: (isModuleActive("bat") && batWidget) ? (batWidget.targetWidth !== undefined ? batWidget.targetWidth : batWidget.width) : 0
    property real wTimedate: (isModuleActive("timedate") && timeDateWidget) ? (timeDateWidget.targetWidth !== undefined ? timeDateWidget.targetWidth : timeDateWidget.width) : 0
    property real wInfo: (isModuleActive("info") && infoWidget) ? (infoWidget.targetWidth !== undefined ? infoWidget.targetWidth : infoWidget.width) : 0
    property real wWeather: (isModuleActive("weather") && weatherWidget) ? (weatherWidget.targetWidth !== undefined ? weatherWidget.targetWidth : weatherWidget.width) : 0

    function getW(moduleId) {
        let norm = BarModuleRegistry.normalizeId(moduleId);
        if (norm === "left") return wLeft;
        if (norm === "workspaces") return wWorkspaces;
        if (norm === "focus") return wFocus;
        if (norm === "media") return wMedia;
        if (norm === "vis") return wVis;
        if (norm === "tray") return wTray;
        if (norm === "sysmon") return wSysmon;
        if (norm === "kb") return wKb;
        if (norm === "wifi") return wWifi;
        if (norm === "bt") return wBt;
        if (norm === "vol") return wVol;
        if (norm === "bat") return wBat;
        if (norm === "timedate") return wTimedate;
        if (norm === "info") return wInfo;
        if (norm === "weather") return wWeather;
        let w = getModuleItem(norm);
        return (w && isModuleActive(norm)) ? (w.targetWidth !== undefined ? w.targetWidth : w.width) : 0;
    }

    property real gap: barWindow ? barWindow.s(2) : 2
    property real groupGap: barWindow ? -barWindow.s(4) : -4
    property real gap8: barWindow ? barWindow.s(10) : 10
    property real groupPad: (!isSolid || distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 0

    function calcTargetWidth(arr) {
        let total = 0;
        let groupCount = 0;
        for (let i = 0; i < arr.length; i++) {
            if (Array.isArray(arr[i])) {
                let gw = 0;
                let gItems = 0;
                for (let j = 0; j < arr[i].length; j++) {
                    let w = getW(arr[i][j]);
                    if (w > 0) {
                        if (gItems > 0) gw += groupGap;
                        gw += w;
                        gItems++;
                    }
                }
                if (gItems > 0) {
                    total += gw + groupPad * 2;
                    groupCount++;
                }
            } else {
                let w = getW(arr[i]);
                if (w > 0) { total += w; groupCount++; }
            }
        }
        return total + (groupCount > 1 ? gap * (groupCount - 1) : 0);
    }

    property real lWidthTarget: calcTargetWidth(leftArr)
    property real cWidthTarget: calcTargetWidth(centerArr)
    property real rWidthTarget: calcTargetWidth(rightArr)

    property real lcGap: (lWidthTarget > 0 && cWidthTarget > 0) ? gap8 : 0
    property real crGap: (cWidthTarget > 0 && rWidthTarget > 0) ? gap8 : 0

    property real distinctEdgePadding: (isSolid && distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 4
    property real fillInset: distinctEdgePadding

    property bool centerByEdges: !!barWindow && barWindow.centerByEdges === true && layoutState === "default"
    property real borderInset: (!isFill && barWindow) ? barWindow.s(1) : 0
    property real edgeInset: borderInset + distinctEdgePadding
    property real packedSpan: lWidthTarget + lcGap + cWidthTarget + crGap + rWidthTarget + edgeInset * 2
    property real edgeSpan: centerByEdges ? Math.min(contentWrapper.width, Math.max(barWindow.effectiveBarWidth, packedSpan)) : 0
    property real edgeStart: (contentWrapper.width - edgeSpan) / 2

    property real baseMinLeft: centerByEdges ? (edgeStart + edgeInset) : (barWindow ? (barWindow.horizontalOffset + borderInset + distinctEdgePadding) : distinctEdgePadding)
    property real baseMaxRight: centerByEdges ? (edgeStart + edgeSpan - edgeInset) : (barWindow ? (contentWrapper.width - barWindow.horizontalOffset - borderInset - distinctEdgePadding) : (contentWrapper.width - distinctEdgePadding))

    property real screenMinLeft: isFill ? fillInset : (barWindow ? (barWindow.s(1) + distinctEdgePadding) : distinctEdgePadding)
    property real screenMaxRight: isFill ? (contentWrapper.width - fillInset) : (barWindow ? (contentWrapper.width - barWindow.s(1) - distinctEdgePadding) : (contentWrapper.width - distinctEdgePadding))

    property real sysPanelWidth: {
        let fallback = (barWindow && typeof barWindow.s === "function") ? barWindow.s(500) : 500;
        if (typeof WindowRegistry !== "undefined" && typeof WindowRegistry.getLayout === "function") {
            let scrW = (barWindow && barWindow.screen) ? barWindow.screen.width : (contentWrapper.width || 1920);
            let scrH = (barWindow && barWindow.screen) ? barWindow.screen.height : 1080;
            let scale = (typeof Scaler !== "undefined" && Scaler.uiScale !== undefined) ? Scaler.uiScale : 1.0;
            let bp = (barWindow && barWindow.barPosition) ? barWindow.barPosition : "top";
            let layout = WindowRegistry.getLayout("system", 0, 0, scrW, scrH, scale, bp);
            if (layout && layout.w) return layout.w;
        }
        return fallback;
    }

    property real sysBoundary: Math.max(0, contentWrapper.width - sysPanelWidth)
    property real sysMaxRight: isFill ? (contentWrapper.width - fillInset) : Math.max(screenMinLeft, sysBoundary - (barWindow ? barWindow.s(1) : 0) - distinctEdgePadding)
    property real sysEffectiveMaxRight: Math.min(baseMaxRight, sysMaxRight)
    property real effectiveMaxRight: (layoutState === "sys") ? sysEffectiveMaxRight : screenMaxRight

    property real rawCNaturalX: {
        if (layoutState === "settings") return screenMaxRight - rWidthTarget - crGap - cWidthTarget;
        if (layoutState === "sys") return (sysBoundary - cWidthTarget) / 2;
        return (contentWrapper.width - cWidthTarget) / 2;
    }

    property real minBoundC: centerByEdges ? baseMinLeft : screenMinLeft
    property real maxBoundC: centerByEdges ? baseMaxRight : effectiveMaxRight
    property real absMinC: (lWidthTarget > 0) ? (minBoundC + lWidthTarget + lcGap) : minBoundC
    property real absMaxC: (rWidthTarget > 0) ? (maxBoundC - rWidthTarget - crGap - cWidthTarget) : (maxBoundC - cWidthTarget)

    property real cResolvedX: {
        if (absMinC <= absMaxC) {
            return Math.max(absMinC, Math.min(absMaxC, rawCNaturalX));
        }
        return absMinC;
    }

    property real cFinalX: cResolvedX

    property real lFinalX: {
        if (lWidthTarget <= 0) return baseMinLeft;
        if (layoutState === "settings") {
            return Math.max(screenMinLeft, cFinalX - lcGap - lWidthTarget);
        }
        let pushedX = Math.min(baseMinLeft, cFinalX - lcGap - lWidthTarget);
        return Math.max(screenMinLeft, pushedX);
    }

    property real rFinalX: {
        if (rWidthTarget <= 0) return (layoutState === "sys" ? sysEffectiveMaxRight : baseMaxRight);
        let naturalR = (layoutState === "sys") ? (sysEffectiveMaxRight - rWidthTarget) : (baseMaxRight - rWidthTarget);
        let minR = (cWidthTarget > 0) ? (cFinalX + cWidthTarget + crGap) : ((lWidthTarget > 0) ? (lFinalX + lWidthTarget + lcGap) : screenMinLeft);
        let pushedX = Math.max(naturalR, minR);
        return Math.min(screenMaxRight - rWidthTarget, pushedX);
    }
    property real rFinalClampedX: Math.max(screenMinLeft, Math.min(screenMaxRight - rWidthTarget, rFinalX))

    property real dynamicMinX: {
        let m = contentWrapper.width;
        let hasModules = (lWidthTarget > 0 || cWidthTarget > 0 || rWidthTarget > 0);
        if (lWidthTarget > 0) m = Math.min(m, lFinalX - borderInset - distinctEdgePadding);
        if (cWidthTarget > 0) m = Math.min(m, cFinalX - borderInset - distinctEdgePadding);
        if (rWidthTarget > 0) m = Math.min(m, rFinalClampedX - borderInset - distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.max(0, m) : contentWrapper.width / 2;
        }
        return Math.max(0, Math.min(m, barWindow ? barWindow.horizontalOffset : 0));
    }

    property real dynamicMaxX: {
        let m = 0;
        let hasModules = (lWidthTarget > 0 || cWidthTarget > 0 || rWidthTarget > 0);
        if (lWidthTarget > 0) m = Math.max(m, lFinalX + lWidthTarget + borderInset + distinctEdgePadding);
        if (cWidthTarget > 0) m = Math.max(m, cFinalX + cWidthTarget + borderInset + distinctEdgePadding);
        if (rWidthTarget > 0) m = Math.max(m, rFinalClampedX + rWidthTarget + borderInset + distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.min(contentWrapper.width, m) : contentWrapper.width / 2;
        }
        return Math.min(contentWrapper.width, Math.max(m, barWindow ? (barWindow.horizontalOffset + barWindow.effectiveBarWidth) : contentWrapper.width));
    }

    function matchId(item, id) {
        if (item === id) return true;
        if (id === "timedate" && (item === "time" || item === "clock")) return true;
        if (id === "info" && (item === "indicator" || item === "indicators" || item === "record")) return true;
        return false;
    }

    function getModuleX(id, state) {
        let arr = null, isLeft = false, isCenter = false, isRight = false;
        let checkFlat = (fArr) => {
            for (let i = 0; i < fArr.length; i++) {
                if (matchId(fArr[i], id)) return true;
            }
            return false;
        };

        if (checkFlat(flatLeftArr)) { arr = leftArr; isLeft = true; }
        else if (checkFlat(flatCenterArr)) { arr = centerArr; isCenter = true; }
        else if (checkFlat(flatRightArr)) { arr = rightArr; isRight = true; }

        if (!arr) return 0;

        let offset = 0;
        let baseX = isLeft ? lFinalX : (isCenter ? cFinalX : rFinalClampedX);

        for (let i = 0; i < arr.length; i++) {
            let item = arr[i];
            if (Array.isArray(item)) {
                let groupHasId = false;
                for (let k = 0; k < item.length; k++) {
                    if (matchId(item[k], id)) { groupHasId = true; break; }
                }
                let gItems = 0;
                let groupOffset = offset + groupPad;
                for (let j = 0; j < item.length; j++) {
                    let mId = item[j];
                    let w = getW(mId);
                    if (matchId(mId, id)) {
                        if (gItems > 0) groupOffset += groupGap;
                        return baseX + groupOffset;
                    }
                    if (w > 0) {
                        if (gItems > 0) groupOffset += groupGap;
                        groupOffset += w;
                        gItems++;
                    }
                }
                if (gItems > 0 && !groupHasId) {
                    offset = groupOffset + groupPad + gap;
                }
            } else {
                if (matchId(item, id)) {
                    return baseX + offset;
                }
                let w = getW(item);
                if (w > 0) {
                    offset += w + gap;
                }
            }
        }
        return 0;
    }

    function getPositionedWidget(id) {
        return getModuleItem(id);
    }

    function getWidget(widgetName) {
        let norm = BarModuleRegistry.normalizeId(widgetName);
        let w = getPositionedWidget(norm);
        if (widgetName === "left" || widgetName === "top") return w;
        if (widgetName === "help" || widgetName === "guide") {
            let lw = getPositionedWidget("left");
            return lw ? lw.helpButton : null;
        }
        if (widgetName === "record") {
            let iw = getPositionedWidget("info");
            return iw ? iw.recRow : null;
        }
        if (widgetName === "kb") return w ? (w.kbPill || w) : null;
        if (widgetName === "wifi") return w ? (w.wifiPill || w) : null;
        if (widgetName === "bt") return w ? (w.btPill || w) : null;
        if (widgetName === "volume" || widgetName === "vol") return w ? (w.volPill || w) : null;
        if (widgetName === "battery" || widgetName === "bat") return w ? (w.batPill || w) : null;
        if (widgetName === "system" || widgetName === "pills") return systemWidget;
        return w;
    }

    function getModuleY(widget) {
        if (!barWindow) return 0;
        let base = barWindow.baseOffsetY;
        let bHeight = barWindow.barHeight;
        let h = widget ? widget.height : 0;
        if (h > 0 && h < bHeight) {
            return base + Math.round((bHeight - h) / 2);
        }
        return base;
    }

    anchors.fill: parent
    visible: barWindow ? (!barWindow.isVertical && !barWindow.positionChanging) : true
    opacity: (visible && (!barWindow || !barWindow.positionChanging) && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0

    property real hideOffsetY: {
        if (!barWindow || barWindow.isRevealed) return 0;
        let offset = barWindow.barHeight + (barWindow.edgePadding !== undefined ? barWindow.edgePadding : 0) + barWindow.s(10);
        return barWindow.barPosition === "bottom" ? offset : -offset;
    }

    transform: Translate {
        y: contentWrapper.hideOffsetY
        Behavior on y {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
        }
    }

    Behavior on opacity {
        enabled: barWindow ? (!barWindow.positionChanging && barWindow.startupCascadeFinished) : true
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: solidBackground
        x: Math.round(contentWrapper.dynamicMinX)
        width: Math.round(contentWrapper.dynamicMaxX) - Math.round(contentWrapper.dynamicMinX)
        height: barWindow ? barWindow.barHeight : 0
        y: barWindow ? barWindow.baseOffsetY : 0
        color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
        radius: isFill ? 0 : ThemeBackend.borderRadius
        topLeftRadius: isFill ? (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0) : radius
        topRightRadius: isFill ? (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0) : radius
        bottomLeftRadius: isFill ? (contentWrapper.barAtBottom ? 0 : contentWrapper.fillFarRadius) : radius
        bottomRightRadius: isFill ? (contentWrapper.barAtBottom ? 0 : contentWrapper.fillFarRadius) : radius
        visible: (isSolid || isFill) && (barWindow ? !barWindow.positionChanging : true)
        opacity: visible ? 1.0 : 0.0

        WallpaperBlur {
            id: solidBlur
            z: -1
            anchors.fill: parent
            rim: (ThemeBackend.liquidGlass && contentWrapper.isFill) ? 0 : 0.45
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
        }

        Behavior on x {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: leftOuterCorner
        x: 0
        y: barWindow ? (barWindow.barPosition === "bottom" ? (barWindow.baseOffsetY - height) : (barWindow.baseOffsetY + barWindow.barHeight)) : 0
        width: contentWrapper.cornerRadius
        height: contentWrapper.cornerRadius
        visible: !ThemeBackend.liquidGlass && contentWrapper.outerCornersReady && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: (barWindow && barWindow.barPosition === "bottom") ? 2.0 : 0.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: rightOuterCorner
        x: parent.width - width
        y: barWindow ? (barWindow.barPosition === "bottom" ? (barWindow.baseOffsetY - height) : (barWindow.baseOffsetY + barWindow.barHeight)) : 0
        width: contentWrapper.cornerRadius
        height: contentWrapper.cornerRadius
        visible: !ThemeBackend.liquidGlass && contentWrapper.outerCornersReady && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: (barWindow && barWindow.barPosition === "bottom") ? 3.0 : 1.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: leftEdgeFillet
        property real radius: Math.min(contentWrapper.cornerRadius, Math.max(0, solidBackground.x)) * contentWrapper.fillAttachProgress
        x: solidBackground.x - width
        y: barWindow ? (contentWrapper.barAtBottom ? (barWindow.baseOffsetY + barWindow.barHeight - height) : barWindow.baseOffsetY) : 0
        width: radius
        height: radius
        visible: !ThemeBackend.liquidGlass && contentWrapper.isFill && radius > 0.5 && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: contentWrapper.barAtBottom ? 3.0 : 1.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: rightEdgeFillet
        property real radius: Math.min(contentWrapper.cornerRadius, Math.max(0, contentWrapper.width - solidBackground.x - solidBackground.width)) * contentWrapper.fillAttachProgress
        x: solidBackground.x + solidBackground.width
        y: barWindow ? (contentWrapper.barAtBottom ? (barWindow.baseOffsetY + barWindow.barHeight - height) : barWindow.baseOffsetY) : 0
        width: radius
        height: radius
        visible: !ThemeBackend.liquidGlass && contentWrapper.isFill && radius > 0.5 && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: contentWrapper.barAtBottom ? 2.0 : 0.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: outerCornerCard
        visible: false
        readonly property real overshoot: contentWrapper.cornerRadius * 2 + 8
        x: 0
        width: contentWrapper.width
        y: contentWrapper.barAtBottom ? solidBackground.y : -overshoot
        height: contentWrapper.barAtBottom ? (contentWrapper.height + overshoot - solidBackground.y) : (solidBackground.y + solidBackground.height + overshoot)
        radius: 0
    }

    Repeater {
        model: [-1, 1]

        GlassFillets {
            required property int modelData
            card: outerCornerCard
            filletDir: Qt.vector2d(modelData, 0)
            rim: 0
            filletRadius: (ThemeBackend.liquidGlass && contentWrapper.outerCornersReady) ? contentWrapper.cornerRadius : 0
            visible: filletRadius > 0.5 && (barWindow ? !barWindow.positionChanging : true)
            opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
            z: 0

            Behavior on opacity {
                enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
            }
        }
    }

    GlassFillets {
        card: solidBackground
        rim: 0
        filletDir: contentWrapper.barAtBottom ? Qt.vector2d(0, 1) : Qt.vector2d(0, -1)
        filletRadius: ThemeBackend.liquidGlass && contentWrapper.isFill
            ? Math.min(contentWrapper.cornerRadius, Math.max(0, solidBackground.x), Math.max(0, contentWrapper.width - solidBackground.x - solidBackground.width)) * contentWrapper.fillAttachProgress
            : 0
        visible: filletRadius > 0.5 && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    Repeater {
        id: groupBgRepeater
        model: contentWrapper.groupDefs
        onItemAdded: contentWrapper.groupRev++
        onItemRemoved: contentWrapper.groupRev++
        delegate: Rectangle {
            id: groupBgRect
            z: 0
            property var groupIds: modelData

            function getGroupMetrics() {
                let firstX = -1;
                let lastX = -1;
                let lastW = 0;
                let groupH = barWindow ? ((contentWrapper.isSolid && contentWrapper.distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight) : ((contentWrapper.isSolid && contentWrapper.distinctPills) ? 24 : 30);
                for (let i = 0; i < groupIds.length; i++) {
                    let id = groupIds[i];
                    let widget = contentWrapper.getPositionedWidget(id);
                    if (!widget || !widget.visible) continue;

                    let targetW = (widget.targetWidth !== undefined) ? widget.targetWidth : widget.width;
                    if (targetW <= 0) continue;

                    let mx = (widget.targetX !== undefined) ? widget.targetX : widget.x;
                    let mw = targetW;

                    if (firstX === -1) firstX = mx;
                    lastX = mx;
                    lastW = mw;
                }
                if (firstX === -1) return { x: 0, w: 0, h: groupH, v: false };
                return { x: firstX - contentWrapper.groupPad, w: (lastX + lastW - firstX) + contentWrapper.groupPad * 2, h: groupH, v: true };
            }

            property var metrics: getGroupMetrics()

            x: metrics.x
            height: metrics.h
            y: barWindow ? (barWindow.baseOffsetY + (barWindow.barHeight - height) / 2) : 0
            width: metrics.w
            visible: metrics.v && (barWindow ? !barWindow.positionChanging : true) && width > 0 && (!contentWrapper.isSolid || contentWrapper.distinctPills)
            opacity: visible ? 1.0 : 0.0

            color: (groupGlass.active || (ThemeBackend.liquidGlass && groupBlur.active)) ? "transparent" : ((contentWrapper.isSolid && contentWrapper.distinctPills)
                ? Qt.alpha(Qt.darker(ThemeBackend.surface0, 1.15), (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
                : Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0))
            radius: ThemeBackend.borderRadius
            property Item blurSurface: groupBlur

            WallpaperBlur {
                id: groupBlur
                z: -1
                anchors.fill: parent
                radius: parent.radius
                surfaceEnabled: !contentWrapper || !contentWrapper.isSolid
                standalone: true
            }

            GlassFill {
                id: groupGlass
                anchors.fill: parent
                z: -1
                radius: parent.radius
                allowed: !!contentWrapper && contentWrapper.isSolid && contentWrapper.distinctPills
                tintColor: ThemeBackend.surface0
                tintAmount: 0.3
            }

            Behavior on x {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
        }
    }

    Repeater {
        id: moduleRepeater
        model: BarModuleRegistry.moduleIds()
        delegate: BarModule {
            id: barMod
            moduleId: modelData
            z: BarModuleRegistry.moduleZ(modelData)
            barWindow: contentWrapper.barWindow
            isSolid: contentWrapper.isSolid || contentWrapper.isFill
            distinctPills: contentWrapper.distinctPills
            moduleActive: contentWrapper.isModuleActive(modelData)
            isGrouped: contentWrapper.isModuleGrouped(modelData)
            providedBackdrop: { void groupBgRepeater.count; void contentWrapper.groupRev; return contentWrapper ? contentWrapper.backdropFor(modelData) : null; }
            targetX: contentWrapper.getModuleX(modelData, contentWrapper.layoutState)
            suppressAnimation: contentWrapper.suppressAnimation
            layoutAnimationsEnabled: contentWrapper.layoutAnimationsEnabled
            isRightAligned: (modelData === "tray") ? contentWrapper.trayAlignRight : false

            Component.onCompleted: {
                contentWrapper.registerModuleInstance(modelData, barMod);
            }
        }
    }

    Item {
        id: systemWidget
        readonly property var kbPill: kbWidget ? kbWidget.kbPill : null
        readonly property var wifiPill: wifiWidget ? wifiWidget.wifiPill : null
        readonly property var btPill: btWidget ? btWidget.btPill : null
        readonly property var volPill: volWidget ? volWidget.volPill : null
        readonly property var batPill: batWidget ? batWidget.batPill : null

        function getBounds() {
            let pills = [sysMonWidget, kbWidget, wifiWidget, btWidget, volWidget, batWidget];
            let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            let found = false;
            for (let i = 0; i < pills.length; i++) {
                let p = pills[i];
                if (p && p.visible && p.width > 0) {
                    found = true;
                    minX = Math.min(minX, p.x);
                    minY = Math.min(minY, p.y);
                    maxX = Math.max(maxX, p.x + p.width);
                    maxY = Math.max(maxY, p.y + p.height);
                }
            }
            if (!found) return { x: 0, y: 0, width: 0, height: 0 };
            return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
        }

        x: getBounds().x
        y: getBounds().y
        width: getBounds().width
        height: getBounds().height
    }
}
