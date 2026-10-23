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
    property bool barAtRight: !!barWindow && barWindow.barPosition === "right"
    property real fillAttachProgress: (isFill && barWindow && barWindow.fillAttached) ? 1.0 : 0.0
    property real fillFarRadius: Math.min(cornerRadius, barWindow ? barWindow.barHeight / 2 : cornerRadius) * fillAttachProgress

    Behavior on fillAttachProgress {
        enabled: contentWrapper.layoutAnimationsEnabled
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    property bool fillDetached: isFill && !!barWindow && !barWindow.fillAttached
    property bool outerCornersReady: fillDetached && solidBackground.y <= 3 && solidBackground.y + solidBackground.height >= contentWrapper.height - 3

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

    property string layoutState: "default"

    property var topArr: contentWrapper.moduleSettings["left"] || []
    property var centerArr: contentWrapper.moduleSettings["center"] || []
    property var bottomArr: contentWrapper.moduleSettings["right"] || []

    property var flatTopArr: { let r=[]; for(let i=0; i<topArr.length; i++){ if(Array.isArray(topArr[i])) r.push(...topArr[i]); else r.push(topArr[i]); } return r; }
    property var flatCenterArr: { let r=[]; for(let i=0; i<centerArr.length; i++){ if(Array.isArray(centerArr[i])) r.push(...centerArr[i]); else r.push(centerArr[i]); } return r; }
    property var flatBottomArr: { let r=[]; for(let i=0; i<bottomArr.length; i++){ if(Array.isArray(bottomArr[i])) r.push(...bottomArr[i]); else r.push(bottomArr[i]); } return r; }

    property var groupDefs: {
        let defs = [];
        let all = [contentWrapper.topArr, contentWrapper.centerArr, contentWrapper.bottomArr];
        for (let i = 0; i < all.length; i++) {
            for (let j = 0; j < all[i].length; j++) {
                if (Array.isArray(all[i][j])) defs.push(all[i][j]);
            }
        }
        return defs;
    }

    property bool trayInTop: flatTopArr.indexOf("tray") !== -1
    property bool trayInCenter: flatCenterArr.indexOf("tray") !== -1
    property bool trayInBottom: flatBottomArr.indexOf("tray") !== -1

    property bool trayAlignBottom: {
        if (trayInTop) return false;
        if (trayInBottom) return true;
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
        return checkFlat(flatTopArr) || checkFlat(flatCenterArr) || checkFlat(flatBottomArr);
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
        let allArrs = [topArr, centerArr, bottomArr];
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

    property real hLeft: (isModuleActive("left") && leftWidget) ? (leftWidget.targetHeight !== undefined ? leftWidget.targetHeight : leftWidget.height) : 0
    property real hWorkspaces: (isModuleActive("workspaces") && workspacesWidget) ? (workspacesWidget.targetHeight !== undefined ? workspacesWidget.targetHeight : workspacesWidget.height) : 0
    property real hFocus: (isModuleActive("focus") && focusWidget) ? (focusWidget.targetHeight !== undefined ? focusWidget.targetHeight : focusWidget.height) : 0
    property real hMedia: (isModuleActive("media") && mediaWidget) ? (mediaWidget.targetHeight !== undefined ? mediaWidget.targetHeight : mediaWidget.height) : 0
    property real hVis: (isModuleActive("vis") && visWidget) ? (visWidget.targetHeight !== undefined ? visWidget.targetHeight : visWidget.height) : 0
    property real hTray: (isModuleActive("tray") && trayWidget) ? (trayWidget.targetHeight !== undefined ? trayWidget.targetHeight : trayWidget.height) : 0
    property real hSysmon: (isModuleActive("sysmon") && sysMonWidget) ? (sysMonWidget.targetHeight !== undefined ? sysMonWidget.targetHeight : sysMonWidget.height) : 0
    property real hKb: (isModuleActive("kb") && kbWidget) ? (kbWidget.targetHeight !== undefined ? kbWidget.targetHeight : kbWidget.height) : 0
    property real hWifi: (isModuleActive("wifi") && wifiWidget) ? (wifiWidget.targetHeight !== undefined ? wifiWidget.targetHeight : wifiWidget.height) : 0
    property real hBt: (isModuleActive("bt") && btWidget) ? (btWidget.targetHeight !== undefined ? btWidget.targetHeight : btWidget.height) : 0
    property real hVol: (isModuleActive("vol") && volWidget) ? (volWidget.targetHeight !== undefined ? volWidget.targetHeight : volWidget.height) : 0
    property real hBat: (isModuleActive("bat") && batWidget) ? (batWidget.targetHeight !== undefined ? batWidget.targetHeight : batWidget.height) : 0
    property real hTimedate: (isModuleActive("timedate") && timeDateWidget) ? (timeDateWidget.targetHeight !== undefined ? timeDateWidget.targetHeight : timeDateWidget.height) : 0
    property real hInfo: (isModuleActive("info") && infoWidget) ? (infoWidget.targetHeight !== undefined ? infoWidget.targetHeight : infoWidget.height) : 0
    property real hWeather: (isModuleActive("weather") && weatherWidget) ? (weatherWidget.targetHeight !== undefined ? weatherWidget.targetHeight : weatherWidget.height) : 0

    function getH(moduleId) {
        let norm = BarModuleRegistry.normalizeId(moduleId);
        if (norm === "left" || norm === "top") return hLeft;
        if (norm === "workspaces") return hWorkspaces;
        if (norm === "focus") return hFocus;
        if (norm === "media") return hMedia;
        if (norm === "vis") return hVis;
        if (norm === "tray") return hTray;
        if (norm === "sysmon") return hSysmon;
        if (norm === "kb") return hKb;
        if (norm === "wifi") return hWifi;
        if (norm === "bt") return hBt;
        if (norm === "vol") return hVol;
        if (norm === "bat") return hBat;
        if (norm === "timedate") return hTimedate;
        if (norm === "info") return hInfo;
        if (norm === "weather") return hWeather;
        let w = getModuleItem(norm);
        return (w && isModuleActive(norm)) ? (w.targetHeight !== undefined ? w.targetHeight : w.height) : 0;
    }

    property real gap: barWindow ? barWindow.s(2) : 2
    property real groupGap: barWindow ? -barWindow.s(4) : -4
    property real gap8: barWindow ? barWindow.s(10) : 10
    property real groupPad: (!isSolid || distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 0

    function calcTargetHeight(arr) {
        let total = 0;
        let groupCount = 0;
        for (let i = 0; i < arr.length; i++) {
            if (Array.isArray(arr[i])) {
                let gh = 0;
                let gItems = 0;
                for (let j = 0; j < arr[i].length; j++) {
                    let h = getH(arr[i][j]);
                    if (h > 0) {
                        if (gItems > 0) gh += groupGap;
                        gh += h;
                        gItems++;
                    }
                }
                if (gItems > 0) {
                    total += gh + groupPad * 2;
                    groupCount++;
                }
            } else {
                let h = getH(arr[i]);
                if (h > 0) { total += h; groupCount++; }
            }
        }
        return total + (groupCount > 1 ? gap * (groupCount - 1) : 0);
    }

    property real tHeightTarget: calcTargetHeight(topArr)
    property real cHeightTarget: calcTargetHeight(centerArr)
    property real bHeightTarget: calcTargetHeight(bottomArr)

    property real tcGap: (tHeightTarget > 0 && cHeightTarget > 0) ? gap8 : 0
    property real cbGap: (cHeightTarget > 0 && bHeightTarget > 0) ? gap8 : 0

    property real distinctEdgePadding: barWindow ? barWindow.s(4) : 4
    property real fillInset: distinctEdgePadding

    property bool centerByEdges: !!barWindow && barWindow.centerByEdges === true
    property real borderInset: (!isFill && barWindow) ? barWindow.s(1) : 0
    property real edgeInset: borderInset + distinctEdgePadding
    property real packedSpan: tHeightTarget + tcGap + cHeightTarget + cbGap + bHeightTarget + edgeInset * 2
    property real edgeSpan: centerByEdges ? Math.min(contentWrapper.height, Math.max(barWindow.effectiveBarHeight, packedSpan)) : 0
    property real edgeStart: (contentWrapper.height - edgeSpan) / 2

    property real baseMinTop: centerByEdges ? (edgeStart + edgeInset) : (barWindow ? (barWindow.verticalOffset + borderInset + distinctEdgePadding) : distinctEdgePadding)
    property real baseMaxBottom: centerByEdges ? (edgeStart + edgeSpan - edgeInset) : (barWindow ? (contentWrapper.height - barWindow.verticalOffset - borderInset - distinctEdgePadding) : (contentWrapper.height - distinctEdgePadding))

    property real screenMinTop: isFill ? fillInset : (barWindow ? (barWindow.s(1) + distinctEdgePadding) : distinctEdgePadding)
    property real screenMaxBottom: isFill ? (contentWrapper.height - fillInset) : (barWindow ? (contentWrapper.height - barWindow.s(1) - distinctEdgePadding) : (contentWrapper.height - distinctEdgePadding))

    property real rawCNaturalY: (contentWrapper.height - cHeightTarget) / 2

    property real minBoundC: centerByEdges ? baseMinTop : screenMinTop
    property real maxBoundC: centerByEdges ? baseMaxBottom : screenMaxBottom
    property real absMinC: (tHeightTarget > 0) ? (minBoundC + tHeightTarget + tcGap) : minBoundC
    property real absMaxC: (bHeightTarget > 0) ? (maxBoundC - bHeightTarget - cbGap - cHeightTarget) : (maxBoundC - cHeightTarget)

    property real cResolvedY: {
        if (absMinC <= absMaxC) {
            return Math.max(absMinC, Math.min(absMaxC, rawCNaturalY));
        }
        return Math.max(screenMinTop, Math.min(screenMaxBottom - cHeightTarget, rawCNaturalY));
    }

    property real cFinalY: cResolvedY

    property real tFinalY: {
        if (tHeightTarget <= 0) return baseMinTop;
        let pushedY = Math.min(baseMinTop, cFinalY - tcGap - tHeightTarget);
        return Math.max(screenMinTop, pushedY);
    }

    property real bFinalY: {
        if (bHeightTarget <= 0) return baseMaxBottom;
        let pushedY = Math.max(baseMaxBottom - bHeightTarget, cFinalY + cHeightTarget + cbGap);
        return Math.min(screenMaxBottom - bHeightTarget, pushedY);
    }
    property real bFinalClampedY: Math.max(0, Math.min(contentWrapper.height - bHeightTarget, bFinalY))

    property real dynamicMinY: {
        let m = contentWrapper.height;
        let hasModules = (tHeightTarget > 0 || cHeightTarget > 0 || bHeightTarget > 0);
        if (tHeightTarget > 0) m = Math.min(m, tFinalY - borderInset - distinctEdgePadding);
        if (cHeightTarget > 0) m = Math.min(m, cFinalY - borderInset - distinctEdgePadding);
        if (bHeightTarget > 0) m = Math.min(m, bFinalClampedY - borderInset - distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.max(0, m) : contentWrapper.height / 2;
        }
        return Math.max(0, Math.min(m, barWindow ? barWindow.verticalOffset : 0));
    }

    property real dynamicMaxY: {
        let m = 0;
        let hasModules = (tHeightTarget > 0 || cHeightTarget > 0 || bHeightTarget > 0);
        if (tHeightTarget > 0) m = Math.max(m, tFinalY + tHeightTarget + borderInset + distinctEdgePadding);
        if (cHeightTarget > 0) m = Math.max(m, cFinalY + cHeightTarget + borderInset + distinctEdgePadding);
        if (bHeightTarget > 0) m = Math.max(m, bFinalClampedY + bHeightTarget + borderInset + distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.min(contentWrapper.height, m) : contentWrapper.height / 2;
        }
        return Math.min(contentWrapper.height, Math.max(m, barWindow ? (barWindow.verticalOffset + barWindow.effectiveBarHeight) : contentWrapper.height));
    }

    function matchId(item, id) {
        if (item === id) return true;
        if (id === "timedate" && (item === "time" || item === "clock")) return true;
        if (id === "info" && (item === "indicator" || item === "indicators" || item === "record")) return true;
        return false;
    }

    function getModuleY(id, state) {
        let arr = null, isTop = false, isCenter = false, isBottom = false;
        let checkFlat = (fArr) => {
            for (let i = 0; i < fArr.length; i++) {
                if (matchId(fArr[i], id)) return true;
            }
            return false;
        };

        if (checkFlat(flatTopArr)) { arr = topArr; isTop = true; }
        else if (checkFlat(flatCenterArr)) { arr = centerArr; isCenter = true; }
        else if (checkFlat(flatBottomArr)) { arr = bottomArr; isBottom = true; }

        if (!arr) return 0;

        let offset = 0;
        let baseY = isTop ? tFinalY : (isCenter ? cFinalY : bFinalClampedY);

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
                    let h = getH(mId);
                    if (matchId(mId, id)) {
                        if (gItems > 0) groupOffset += groupGap;
                        return baseY + groupOffset;
                    }
                    if (h > 0) {
                        if (gItems > 0) groupOffset += groupGap;
                        groupOffset += h;
                        gItems++;
                    }
                }
                if (gItems > 0 && !groupHasId) {
                    offset = groupOffset + groupPad + gap;
                }
            } else {
                if (matchId(item, id)) {
                    return baseY + offset;
                }
                let h = getH(item);
                if (h > 0) {
                    offset += h + gap;
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
            return iw ? iw.recCol : null;
        }
        if (widgetName === "kb") return w ? (w.kbPill || w) : null;
        if (widgetName === "wifi") return w ? (w.wifiPill || w) : null;
        if (widgetName === "bt") return w ? (w.btPill || w) : null;
        if (widgetName === "volume" || widgetName === "vol") return w ? (w.volPill || w) : null;
        if (widgetName === "battery" || widgetName === "bat") return w ? (w.batPill || w) : null;
        if (widgetName === "system" || widgetName === "pills") return systemWidget;
        return w;
    }

    function getModuleX(widget) {
        if (!barWindow) return 0;
        let bThick = barWindow.barHeight;
        let isRight = barWindow.barPosition === "right";
        let base = (barWindow.baseOffsetX !== undefined) ? barWindow.baseOffsetX : (isRight ? (contentWrapper.width - bThick) : 0);
        let w = widget ? widget.width : 0;
        if (w > 0 && w < bThick) {
            return base + Math.round((bThick - w) / 2);
        }
        if (w > bThick && isRight) {
            return contentWrapper.width - w;
        }
        return base;
    }

    anchors.fill: parent
    visible: barWindow ? (barWindow.isVertical && !barWindow.positionChanging) : true
    opacity: (visible && (!barWindow || !barWindow.positionChanging) && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0

    Behavior on opacity {
        enabled: barWindow ? (!barWindow.positionChanging && barWindow.startupCascadeFinished) : true
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: solidBackground
        x: barWindow && barWindow.barPosition === "right" ? (parent.width - width) : 0
        y: Math.round(contentWrapper.dynamicMinY)
        width: barWindow ? barWindow.barHeight : 40
        height: Math.round(contentWrapper.dynamicMaxY) - Math.round(contentWrapper.dynamicMinY)
        color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
        radius: isFill ? 0 : ThemeBackend.borderRadius
        topLeftRadius: isFill ? (contentWrapper.barAtRight ? contentWrapper.fillFarRadius : 0) : radius
        bottomLeftRadius: isFill ? (contentWrapper.barAtRight ? contentWrapper.fillFarRadius : 0) : radius
        topRightRadius: isFill ? (contentWrapper.barAtRight ? 0 : contentWrapper.fillFarRadius) : radius
        bottomRightRadius: isFill ? (contentWrapper.barAtRight ? 0 : contentWrapper.fillFarRadius) : radius
        border.width: (isSolid || isFill) ? 0 : 1
        border.color: (isSolid || isFill) ? "transparent" : Qt.alpha(ThemeBackend.surface0, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
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

        Behavior on y {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: topOuterCorner
        x: barWindow && barWindow.barPosition === "right" ? (parent.width - (barWindow ? barWindow.barHeight : 40) - width) : (barWindow ? barWindow.barHeight : 40)
        y: 0
        width: contentWrapper.cornerRadius
        height: contentWrapper.cornerRadius
        visible: !ThemeBackend.liquidGlass && contentWrapper.outerCornersReady && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: (barWindow && barWindow.barPosition === "right") ? 1.0 : 0.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: bottomOuterCorner
        x: barWindow && barWindow.barPosition === "right" ? (parent.width - (barWindow ? barWindow.barHeight : 40) - width) : (barWindow ? barWindow.barHeight : 40)
        y: parent.height - height
        width: contentWrapper.cornerRadius
        height: contentWrapper.cornerRadius
        visible: !ThemeBackend.liquidGlass && contentWrapper.outerCornersReady && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: (barWindow && barWindow.barPosition === "right") ? 3.0 : 2.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: topEdgeFillet
        property real radius: Math.min(contentWrapper.cornerRadius, Math.max(0, solidBackground.y)) * contentWrapper.fillAttachProgress
        x: contentWrapper.barAtRight ? (solidBackground.x + solidBackground.width - width) : solidBackground.x
        y: solidBackground.y - height
        width: radius
        height: radius
        visible: !ThemeBackend.liquidGlass && contentWrapper.isFill && radius > 0.5 && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: contentWrapper.barAtRight ? 3.0 : 2.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: bottomEdgeFillet
        property real radius: Math.min(contentWrapper.cornerRadius, Math.max(0, contentWrapper.height - solidBackground.y - solidBackground.height)) * contentWrapper.fillAttachProgress
        x: contentWrapper.barAtRight ? (solidBackground.x + solidBackground.width - width) : solidBackground.x
        y: solidBackground.y + solidBackground.height
        width: radius
        height: radius
        visible: !ThemeBackend.liquidGlass && contentWrapper.isFill && radius > 0.5 && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: contentWrapper.barAtRight ? 1.0 : 0.0
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
        x: contentWrapper.barAtRight ? solidBackground.x : -overshoot
        width: contentWrapper.barAtRight ? (contentWrapper.width + overshoot - solidBackground.x) : (solidBackground.x + solidBackground.width + overshoot)
        y: 0
        height: contentWrapper.height
        radius: 0
    }

    Repeater {
        model: [-1, 1]

        GlassFillets {
            required property int modelData
            card: outerCornerCard
            filletDir: Qt.vector2d(0, modelData)
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
        filletDir: contentWrapper.barAtRight ? Qt.vector2d(1, 0) : Qt.vector2d(-1, 0)
        filletRadius: ThemeBackend.liquidGlass && contentWrapper.isFill
            ? Math.min(contentWrapper.cornerRadius, Math.max(0, solidBackground.y), Math.max(0, contentWrapper.height - solidBackground.y - solidBackground.height)) * contentWrapper.fillAttachProgress
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
                let firstY = -1;
                let lastY = -1;
                let lastH = 0;
                let groupW = barWindow ? ((contentWrapper.isSolid && contentWrapper.distinctPills) ? barWindow.barHeight - barWindow.s(6) : barWindow.barHeight) : ((contentWrapper.isSolid && contentWrapper.distinctPills) ? 24 : 30);
                for (let i = 0; i < groupIds.length; i++) {
                    let id = groupIds[i];
                    let widget = contentWrapper.getPositionedWidget(id);
                    if (!widget || !widget.visible) continue;

                    let targetH = (widget.targetHeight !== undefined) ? widget.targetHeight : widget.height;
                    if (targetH <= 0) continue;

                    let my = (widget.targetY !== undefined) ? widget.targetY : widget.y;
                    let mh = targetH;

                    if (firstY === -1) firstY = my;
                    lastY = my;
                    lastH = mh;

                    if (id === "timedate" || id === "info" || id === "weather" || id === "media") continue;

                    if (widget.width > groupW) {
                        groupW = widget.width;
                    }
                }
                if (firstY === -1) return { y: 0, h: 0, w: groupW, v: false };
                return { y: firstY - contentWrapper.groupPad, h: (lastY + lastH - firstY) + contentWrapper.groupPad * 2, w: groupW, v: true };
            }

            property var metrics: getGroupMetrics()

            x: {
                let bThick = barWindow ? barWindow.barHeight : 40;
                let base = (barWindow && barWindow.baseOffsetX !== undefined) ? barWindow.baseOffsetX : (barWindow && barWindow.barPosition === "right" ? (parent.width - bThick) : 0);
                return base + Math.round((bThick - width) / 2);
            }
            y: metrics.y
            width: metrics.w
            height: metrics.h
            visible: metrics.v && (barWindow ? !barWindow.positionChanging : true) && height > 0 && (!contentWrapper.isSolid || contentWrapper.distinctPills)
            opacity: visible ? 1.0 : 0.0

            color: (groupGlass.active || (ThemeBackend.liquidGlass && groupBlur.active)) ? "transparent" : ((contentWrapper.isSolid && contentWrapper.distinctPills)
                ? Qt.alpha(Qt.darker(ThemeBackend.surface0, 1.15), (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
                : Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0))
            radius: ThemeBackend.borderRadius
            border.width: 0
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

            Behavior on y {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on height {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
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
            orientation: "vertical"
            moduleId: modelData
            z: BarModuleRegistry.moduleZ(modelData)
            barWindow: contentWrapper.barWindow
            isSolid: contentWrapper.isSolid || contentWrapper.isFill
            distinctPills: contentWrapper.distinctPills
            moduleActive: contentWrapper.isModuleActive(modelData)
            isGrouped: contentWrapper.isModuleGrouped(modelData)
            providedBackdrop: { void groupBgRepeater.count; void contentWrapper.groupRev; return contentWrapper ? contentWrapper.backdropFor(modelData) : null; }
            targetY: contentWrapper.getModuleY(modelData, contentWrapper.layoutState)
            targetX: contentWrapper.getModuleX(barMod)
            suppressAnimation: contentWrapper.suppressAnimation
            layoutAnimationsEnabled: contentWrapper.layoutAnimationsEnabled

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
                if (p && p.visible && p.height > 0) {
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
