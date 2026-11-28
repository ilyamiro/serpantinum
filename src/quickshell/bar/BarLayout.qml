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

    readonly property bool isVertical: barWindow ? barWindow.isVertical : false
    readonly property bool barAtBottom: !!barWindow && barWindow.barPosition === "bottom"
    readonly property bool barAtRight: !!barWindow && barWindow.barPosition === "right"
    readonly property real mainSize: isVertical ? height : width

    property string barStyle: {
        if (barWindow && barWindow.barStyle !== undefined) return barWindow.barStyle;
        return SurfaceRegistry.barStyle;
    }
    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property real cornerRadius: barWindow ? barWindow.cornerRadius : 12
    property real fillAttachProgress: (isFill && barWindow && barWindow.fillAttached) ? 1.0 : 0.0
    property real fillFarRadius: Math.min(cornerRadius, barWindow ? barWindow.barHeight / 2 : cornerRadius) * fillAttachProgress

    Behavior on fillAttachProgress {
        enabled: contentWrapper.layoutAnimationsEnabled
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

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

    property var defaultModuleSettings: ({
        "left": ["left", "workspaces", "focus"],
        "center": ["timedate", "info", "weather", "media", "vis"],
        "right": ["tray", "sysmon", "kb", "wifi", "bt", "vol", "bat"]
    })

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
        if (isVertical || isFill) return "default";
        if (barWindow && barWindow.isNotifOpen) return "settings";
        if (barWindow && barWindow.isSysOpen) return "sys";
        return "default";
    }

    property var startArr: contentWrapper.moduleSettings["left"] || []
    property var centerArr: contentWrapper.moduleSettings["center"] || []
    property var endArr: contentWrapper.moduleSettings["right"] || []

    function flattenZone(arr) {
        let r = [];
        for (let i = 0; i < arr.length; i++) {
            if (Array.isArray(arr[i])) r.push(...arr[i]);
            else r.push(arr[i]);
        }
        return r;
    }

    property var flatStartArr: flattenZone(startArr)
    property var flatCenterArr: flattenZone(centerArr)
    property var flatEndArr: flattenZone(endArr)

    property var groupDefs: {
        let defs = [];
        let all = [contentWrapper.startArr, contentWrapper.centerArr, contentWrapper.endArr];
        for (let i = 0; i < all.length; i++) {
            for (let j = 0; j < all[i].length; j++) {
                if (Array.isArray(all[i][j])) defs.push(all[i][j]);
            }
        }
        return defs;
    }

    property bool trayInStart: flatStartArr.indexOf("tray") !== -1
    property bool trayInCenter: flatCenterArr.indexOf("tray") !== -1
    property bool trayInEnd: flatEndArr.indexOf("tray") !== -1

    property bool trayAlignEnd: {
        if (trayInStart) return false;
        if (trayInEnd) return true;
        if (trayInCenter) return isVertical ? true : (layoutState !== "sys");
        return true;
    }

    property var moduleInstances: ({})
    property int modulesRev: 0
    property int moduleSizesRev: 0

    function registerModuleInstance(id, inst) {
        moduleInstances[id] = inst;
        modulesRev++;
    }

    function getModuleItem(id) {
        let dummy = modulesRev;
        let norm = BarModuleRegistry.normalizeId(id);
        return moduleInstances[norm] || null;
    }

    function isModuleActive(moduleId) {
        let norm = BarModuleRegistry.normalizeId(moduleId);
        let checkFlat = arr => {
            for (let i = 0; i < arr.length; i++) {
                if (BarModuleRegistry.normalizeId(arr[i]) === norm) return true;
            }
            return false;
        };
        return checkFlat(flatStartArr) || checkFlat(flatCenterArr) || checkFlat(flatEndArr);
    }

    property int groupRev: 0

    function backdropFor(id) {
        void groupRev;
        if (isSolid) return barSurface.backdrop;
        if (!isModuleGrouped(id)) return null;
        for (let i = 0; i < groupBgRepeater.count; i++) {
            const g = groupBgRepeater.itemAt(i);
            if (g && g.groupIds && g.groupIds.indexOf(id) !== -1) return g.blurSurface;
        }
        return null;
    }

    function isModuleGrouped(id) {
        let norm = BarModuleRegistry.normalizeId(id);
        let allArrs = [startArr, centerArr, endArr];
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

    function getModuleLength(moduleId) {
        let dummy = moduleSizesRev + modulesRev;
        let norm = BarModuleRegistry.normalizeId(moduleId);
        let w = moduleInstances[norm];
        if (!w || !isModuleActive(norm)) return 0;
        return w.effectiveTargetLength || 0;
    }

    property real gap: barWindow ? barWindow.s(2) : 2
    property real groupGap: barWindow ? -barWindow.s(4) : -4
    property real gap8: barWindow ? barWindow.s(10) : 10
    property real groupPad: (!isSolid || distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 0

    function calcZoneLength(arr) {
        let total = 0;
        let groupCount = 0;
        for (let i = 0; i < arr.length; i++) {
            if (Array.isArray(arr[i])) {
                let gl = 0;
                let gItems = 0;
                for (let j = 0; j < arr[i].length; j++) {
                    let len = getModuleLength(arr[i][j]);
                    if (len > 0) {
                        if (gItems > 0) gl += groupGap;
                        gl += len;
                        gItems++;
                    }
                }
                if (gItems > 0) {
                    total += gl + groupPad * 2;
                    groupCount++;
                }
            } else {
                let len = getModuleLength(arr[i]);
                if (len > 0) { total += len; groupCount++; }
            }
        }
        return total + (groupCount > 1 ? gap * (groupCount - 1) : 0);
    }

    property real sLenTarget: calcZoneLength(startArr)
    property real cLenTarget: calcZoneLength(centerArr)
    property real eLenTarget: calcZoneLength(endArr)

    property real scGap: (sLenTarget > 0 && cLenTarget > 0) ? gap8 : 0
    property real ceGap: (cLenTarget > 0 && eLenTarget > 0) ? gap8 : 0

    property real distinctEdgePadding: (isSolid && distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 4
    property real fillInset: distinctEdgePadding

    property bool centerByEdges: !!barWindow && barWindow.centerByEdges === true && (isVertical || layoutState === "default")
    property real borderInset: (!isFill && barWindow) ? barWindow.s(1) : 0
    property real edgeInset: borderInset + distinctEdgePadding
    property real barEffectiveLen: barWindow ? (isVertical ? barWindow.effectiveBarHeight : barWindow.effectiveBarWidth) : mainSize
    property real barAxisOffset: barWindow ? (isVertical ? barWindow.verticalOffset : barWindow.horizontalOffset) : 0
    property real packedSpan: sLenTarget + scGap + cLenTarget + ceGap + eLenTarget + edgeInset * 2
    property real edgeSpan: centerByEdges ? Math.min(mainSize, Math.max(barEffectiveLen, packedSpan)) : 0
    property real edgeStart: (mainSize - edgeSpan) / 2

    property real baseMinStart: centerByEdges ? (edgeStart + edgeInset) : (barAxisOffset + borderInset + distinctEdgePadding)
    property real baseMaxEnd: centerByEdges ? (edgeStart + edgeSpan - edgeInset) : (mainSize - barAxisOffset - borderInset - distinctEdgePadding)

    property real screenMinStart: isFill ? fillInset : (barWindow ? (barWindow.s(1) + distinctEdgePadding) : distinctEdgePadding)
    property real screenMaxEnd: isFill ? (mainSize - fillInset) : (barWindow ? (mainSize - barWindow.s(1) - distinctEdgePadding) : (mainSize - distinctEdgePadding))

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

    property real sysBoundary: Math.max(0, mainSize - sysPanelWidth)
    property real sysMaxEnd: isFill ? (mainSize - fillInset) : Math.max(screenMinStart, sysBoundary - (barWindow ? barWindow.s(1) : 0) - distinctEdgePadding)
    property real sysEffectiveMaxEnd: Math.min(baseMaxEnd, sysMaxEnd)
    property real effectiveMaxEnd: (!isVertical && layoutState === "sys") ? sysEffectiveMaxEnd : screenMaxEnd

    property real rawCNaturalPos: {
        if (!isVertical && layoutState === "settings") return screenMaxEnd - eLenTarget - ceGap - cLenTarget;
        return (mainSize - cLenTarget) / 2;
    }

    property real minBoundC: centerByEdges ? baseMinStart : screenMinStart
    property real maxBoundC: centerByEdges ? baseMaxEnd : effectiveMaxEnd
    property real absMinC: (sLenTarget > 0) ? (minBoundC + sLenTarget + scGap) : minBoundC
    property real absMaxC: (eLenTarget > 0) ? (maxBoundC - eLenTarget - ceGap - cLenTarget) : (maxBoundC - cLenTarget)

    property real cFinalPos: {
        if (absMinC <= absMaxC) {
            return Math.max(absMinC, Math.min(absMaxC, rawCNaturalPos));
        }
        if (isVertical) {
            return Math.max(screenMinStart, Math.min(screenMaxEnd - cLenTarget, rawCNaturalPos));
        }
        return absMinC;
    }

    property real sFinalPos: {
        if (sLenTarget <= 0) return baseMinStart;
        if (!isVertical && layoutState === "settings") {
            return Math.max(screenMinStart, cFinalPos - scGap - sLenTarget);
        }
        let pushed = Math.min(baseMinStart, cFinalPos - scGap - sLenTarget);
        return Math.max(screenMinStart, pushed);
    }

    property real eFinalPos: {
        if (eLenTarget <= 0) return (!isVertical && layoutState === "sys" ? sysEffectiveMaxEnd : baseMaxEnd);
        let naturalE = (!isVertical && layoutState === "sys") ? (sysEffectiveMaxEnd - eLenTarget) : (baseMaxEnd - eLenTarget);
        let minE = isVertical
            ? (cFinalPos + cLenTarget + ceGap)
            : ((cLenTarget > 0) ? (cFinalPos + cLenTarget + ceGap) : ((sLenTarget > 0) ? (sFinalPos + sLenTarget + scGap) : screenMinStart));
        let pushed = Math.max(naturalE, minE);
        return Math.min(screenMaxEnd - eLenTarget, pushed);
    }
    property real eFinalClampedPos: isVertical
        ? Math.max(0, Math.min(mainSize - eLenTarget, eFinalPos))
        : Math.max(screenMinStart, Math.min(screenMaxEnd - eLenTarget, eFinalPos))

    property real dynamicMin: {
        let m = mainSize;
        let hasModules = (sLenTarget > 0 || cLenTarget > 0 || eLenTarget > 0);
        if (sLenTarget > 0) m = Math.min(m, sFinalPos - borderInset - distinctEdgePadding);
        if (cLenTarget > 0) m = Math.min(m, cFinalPos - borderInset - distinctEdgePadding);
        if (eLenTarget > 0) m = Math.min(m, eFinalClampedPos - borderInset - distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.max(0, m) : mainSize / 2;
        }
        return Math.max(0, Math.min(m, barAxisOffset));
    }

    property real dynamicMax: {
        let m = 0;
        let hasModules = (sLenTarget > 0 || cLenTarget > 0 || eLenTarget > 0);
        if (sLenTarget > 0) m = Math.max(m, sFinalPos + sLenTarget + borderInset + distinctEdgePadding);
        if (cLenTarget > 0) m = Math.max(m, cFinalPos + cLenTarget + borderInset + distinctEdgePadding);
        if (eLenTarget > 0) m = Math.max(m, eFinalClampedPos + eLenTarget + borderInset + distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.min(mainSize, m) : mainSize / 2;
        }
        return Math.min(mainSize, Math.max(m, barAxisOffset + barEffectiveLen));
    }

    readonly property real dynamicMinX: isVertical ? 0 : dynamicMin
    readonly property real dynamicMaxX: isVertical ? 0 : dynamicMax
    readonly property real dynamicMinY: isVertical ? dynamicMin : 0
    readonly property real dynamicMaxY: isVertical ? dynamicMax : 0

    function matchId(item, id) {
        return BarModuleRegistry.normalizeId(item) === BarModuleRegistry.normalizeId(id);
    }

    function getModuleAxisPos(id, state) {
        let arr = null, isStart = false, isCenter = false;
        let checkFlat = (fArr) => {
            for (let i = 0; i < fArr.length; i++) {
                if (matchId(fArr[i], id)) return true;
            }
            return false;
        };

        if (checkFlat(flatStartArr)) { arr = startArr; isStart = true; }
        else if (checkFlat(flatCenterArr)) { arr = centerArr; isCenter = true; }
        else if (checkFlat(flatEndArr)) { arr = endArr; }

        if (!arr) return 0;

        let offset = 0;
        let basePos = isStart ? sFinalPos : (isCenter ? cFinalPos : eFinalClampedPos);

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
                    let len = getModuleLength(mId);
                    if (matchId(mId, id)) {
                        if (gItems > 0) groupOffset += groupGap;
                        return basePos + groupOffset;
                    }
                    if (len > 0) {
                        if (gItems > 0) groupOffset += groupGap;
                        groupOffset += len;
                        gItems++;
                    }
                }
                if (gItems > 0 && !groupHasId) {
                    offset = groupOffset + groupPad + gap;
                }
            } else {
                if (matchId(item, id)) {
                    return basePos + offset;
                }
                let len = getModuleLength(item);
                if (len > 0) {
                    offset += len + gap;
                }
            }
        }
        return 0;
    }

    function getCrossX(widget) {
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
    visible: barWindow ? !barWindow.positionChanging : true
    opacity: (visible && (!barWindow || !barWindow.positionChanging) && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0

    property real hideOffsetX: {
        if (!isVertical || !barWindow || barWindow.isRevealed) return 0;
        let offset = barWindow.barHeight + (barWindow.edgePadding !== undefined ? barWindow.edgePadding : 0) + barWindow.s(10);
        return barWindow.barPosition === "right" ? offset : -offset;
    }

    property real hideOffsetY: {
        if (isVertical || !barWindow || barWindow.isRevealed) return 0;
        let offset = barWindow.barHeight + (barWindow.edgePadding !== undefined ? barWindow.edgePadding : 0) + barWindow.s(10);
        return barWindow.barPosition === "bottom" ? offset : -offset;
    }

    transform: Translate {
        id: hideShift
        x: contentWrapper.hideOffsetX
        y: contentWrapper.hideOffsetY
        Behavior on x {
            enabled: contentWrapper.isVertical && (barWindow ? !barWindow.positionChanging : true)
            NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: !contentWrapper.isVertical && (barWindow ? !barWindow.positionChanging : true)
            NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
        }
    }

    Behavior on opacity {
        enabled: barWindow ? (!barWindow.positionChanging && barWindow.startupCascadeFinished) : true
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: solidBackground
        x: contentWrapper.isVertical
            ? (barWindow && barWindow.barPosition === "right" ? (parent.width - width) : 0)
            : Math.round(contentWrapper.dynamicMin)
        y: contentWrapper.isVertical
            ? Math.round(contentWrapper.dynamicMin)
            : (barWindow ? barWindow.baseOffsetY : 0)
        width: contentWrapper.isVertical
            ? (barWindow ? barWindow.barHeight : 40)
            : (Math.round(contentWrapper.dynamicMax) - Math.round(contentWrapper.dynamicMin))
        height: contentWrapper.isVertical
            ? (Math.round(contentWrapper.dynamicMax) - Math.round(contentWrapper.dynamicMin))
            : (barWindow ? barWindow.barHeight : 0)
        color: "transparent"
        radius: isFill ? 0 : ThemeBackend.borderRadius
        topLeftRadius: isFill ? (contentWrapper.isVertical ? (contentWrapper.barAtRight ? contentWrapper.fillFarRadius : 0) : (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0)) : radius
        topRightRadius: isFill ? (contentWrapper.isVertical ? (contentWrapper.barAtRight ? 0 : contentWrapper.fillFarRadius) : (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0)) : radius
        bottomLeftRadius: isFill ? (contentWrapper.isVertical ? (contentWrapper.barAtRight ? contentWrapper.fillFarRadius : 0) : (contentWrapper.barAtBottom ? 0 : contentWrapper.fillFarRadius)) : radius
        bottomRightRadius: isFill ? (contentWrapper.isVertical ? (contentWrapper.barAtRight ? 0 : contentWrapper.fillFarRadius) : (contentWrapper.barAtBottom ? 0 : contentWrapper.fillFarRadius)) : radius
        visible: (isSolid || isFill) && (barWindow ? !barWindow.positionChanging : true)
        opacity: visible ? 1.0 : 0.0

        Behavior on x {
            enabled: !contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on y {
            enabled: contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            enabled: !contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            enabled: contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    AttachedSurface {
        id: barSurface
        kind: "bar"
        publishShape: true
        filletRadius: Math.max(contentWrapper.isFill ? contentWrapper.cornerRadius : 0, solidBackground.topLeftRadius, solidBackground.topRightRadius, solidBackground.bottomRightRadius, solidBackground.bottomLeftRadius)
        visible: solidBackground.visible
        opacity: solidBackground.opacity
        color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
        rects: [{ x: solidBackground.x, y: solidBackground.y, w: solidBackground.width, h: solidBackground.height, r: [solidBackground.topLeftRadius, solidBackground.topRightRadius, solidBackground.bottomRightRadius, solidBackground.bottomLeftRadius] }]
        offset: Qt.point(contentWrapper.isVertical ? hideShift.x : 0, contentWrapper.isVertical ? 0 : hideShift.y)
        readonly property var scr: barWindow && barWindow.screen ? barWindow.screen : null
        screenRects: {
            if (!contentWrapper.isFill || !scr) return [];
            if (contentWrapper.isVertical) {
                return [
                    { x: contentWrapper.barAtRight ? scr.width : -10000, y: -10000, w: 10000, h: scr.height + 20000 },
                    { x: contentWrapper.barAtRight ? -10000 : 2 * contentWrapper.cornerRadius, y: -10000, w: scr.width + 10000 - 2 * contentWrapper.cornerRadius, h: 10000 },
                    { x: contentWrapper.barAtRight ? -10000 : 2 * contentWrapper.cornerRadius, y: scr.height, w: scr.width + 10000 - 2 * contentWrapper.cornerRadius, h: 10000 }
                ];
            }
            return [
                { x: -10000, y: contentWrapper.barAtBottom ? scr.height : -10000, w: scr.width + 20000, h: 10000 },
                { x: -10000, y: contentWrapper.barAtBottom ? -10000 : 2 * contentWrapper.cornerRadius, w: 10000, h: scr.height + 10000 - 2 * contentWrapper.cornerRadius },
                { x: scr.width, y: contentWrapper.barAtBottom ? -10000 : 2 * contentWrapper.cornerRadius, w: 10000, h: scr.height + 10000 - 2 * contentWrapper.cornerRadius }
            ];
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
                let dummy = contentWrapper.moduleSizesRev + contentWrapper.modulesRev;
                let firstPos = -1;
                let lastPos = -1;
                let lastLen = 0;
                let groupCross = barWindow ? ((contentWrapper.isSolid && contentWrapper.distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight) : ((contentWrapper.isSolid && contentWrapper.distinctPills) ? 24 : 30);
                for (let i = 0; i < groupIds.length; i++) {
                    let id = groupIds[i];
                    let norm = BarModuleRegistry.normalizeId(id);
                    let widget = contentWrapper.getModuleItem(norm);
                    if (!widget || !widget.visible) continue;

                    let targetLen = contentWrapper.isVertical
                        ? ((widget.targetHeight !== undefined) ? widget.targetHeight : widget.height)
                        : ((widget.targetWidth !== undefined) ? widget.targetWidth : widget.width);
                    if (targetLen <= 0) continue;

                    let mp = contentWrapper.isVertical
                        ? ((widget.targetY !== undefined) ? widget.targetY : widget.y)
                        : ((widget.targetX !== undefined) ? widget.targetX : widget.x);

                    if (firstPos === -1) firstPos = mp;
                    lastPos = mp;
                    lastLen = targetLen;

                    if (contentWrapper.isVertical) {
                        let meta = BarModuleRegistry.types[norm];
                        if (meta && meta.expandGroupCross === false) continue;
                        if (widget.width > groupCross) groupCross = widget.width;
                    }
                }
                if (firstPos === -1) return { pos: 0, len: 0, cross: groupCross, v: false };
                return { pos: firstPos - contentWrapper.groupPad, len: (lastPos + lastLen - firstPos) + contentWrapper.groupPad * 2, cross: groupCross, v: true };
            }

            property var metrics: getGroupMetrics()

            x: contentWrapper.isVertical
                ? (function() {
                    let bThick = barWindow ? barWindow.barHeight : 40;
                    let base = (barWindow && barWindow.baseOffsetX !== undefined) ? barWindow.baseOffsetX : (barWindow && barWindow.barPosition === "right" ? (parent.width - bThick) : 0);
                    return base + Math.round((bThick - width) / 2);
                })()
                : metrics.pos
            y: contentWrapper.isVertical
                ? metrics.pos
                : (barWindow ? (barWindow.baseOffsetY + (barWindow.barHeight - height) / 2) : 0)
            width: contentWrapper.isVertical ? metrics.cross : metrics.len
            height: contentWrapper.isVertical ? metrics.len : metrics.cross
            visible: metrics.v && (barWindow ? !barWindow.positionChanging : true) && (contentWrapper.isVertical ? height > 0 : width > 0) && (!contentWrapper.isSolid || contentWrapper.distinctPills)
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
                enabled: !contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on y {
                enabled: contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on height {
                enabled: contentWrapper.isVertical && contentWrapper.layoutAnimationsEnabled
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
            orientation: contentWrapper.isVertical ? "vertical" : "horizontal"
            moduleId: modelData
            z: BarModuleRegistry.moduleZ(modelData)
            barWindow: contentWrapper.barWindow
            isSolid: contentWrapper.isSolid || contentWrapper.isFill
            distinctPills: contentWrapper.distinctPills
            moduleActive: contentWrapper.isModuleActive(modelData)
            isGrouped: contentWrapper.isModuleGrouped(modelData)
            providedBackdrop: { void groupBgRepeater.count; void contentWrapper.groupRev; return contentWrapper ? contentWrapper.backdropFor(modelData) : null; }
            targetX: contentWrapper.isVertical ? contentWrapper.getCrossX(barMod) : contentWrapper.getModuleAxisPos(modelData, contentWrapper.layoutState)
            targetY: contentWrapper.isVertical ? contentWrapper.getModuleAxisPos(modelData, contentWrapper.layoutState) : 0
            suppressAnimation: contentWrapper.suppressAnimation
            layoutAnimationsEnabled: contentWrapper.layoutAnimationsEnabled
            isRightAligned: (modelData === "tray") ? contentWrapper.trayAlignEnd : false

            onEffectiveTargetLengthChanged: contentWrapper.moduleSizesRev++

            Component.onCompleted: {
                contentWrapper.registerModuleInstance(modelData, barMod);
            }
        }
    }
}
