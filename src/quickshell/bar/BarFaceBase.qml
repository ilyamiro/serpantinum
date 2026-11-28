import QtQuick
import "../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: (widget && widget !== root) ? widget : ((module && module !== root) ? module : null)
    readonly property bool isCompact: activeTarget ? Boolean(activeTarget.isCompact) : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false
    readonly property bool moduleActive: activeTarget ? (activeTarget.moduleActive !== undefined ? Boolean(activeTarget.moduleActive) : true) : true
    readonly property bool isRightBar: (module && module.isRightBar !== undefined) ? Boolean(module.isRightBar) : (barWindow ? (barWindow.barPosition === "right") : false)
    readonly property real barOpacity: ThemeBackend.elementOpacity

    function s(val) {
        if (barWindow && typeof barWindow.cs === "function") return barWindow.cs(val);
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (activeTarget && activeTarget !== root && typeof activeTarget.s === "function") return activeTarget.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    function readSetting(key, nestedKey, fallback) {
        if (widget && widget !== root) {
            if (widget[key] !== undefined) return widget[key];
            if (nestedKey && typeof nestedKey === "string") {
                let parts = nestedKey.split(".");
                let leaf = parts[parts.length - 1];
                if (leaf && widget[leaf] !== undefined) return widget[leaf];
            }
        }
        if (module) {
            if (module[key] !== undefined) return module[key];
            if (nestedKey && typeof nestedKey === "string") {
                let parts = nestedKey.split(".");
                let leaf = parts[parts.length - 1];
                if (leaf && module[leaf] !== undefined) return module[leaf];
            }
        }
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs[key] !== undefined) return bs[key];
            if (nestedKey && typeof nestedKey === "string") {
                let parts = nestedKey.split(".");
                let cur = bs;
                for (let i = 0; i < parts.length; i++) {
                    if (cur && typeof cur === "object" && cur[parts[i]] !== undefined) {
                        cur = cur[parts[i]];
                    } else {
                        cur = undefined;
                        break;
                    }
                }
                if (cur !== undefined) return cur;
            }
        }
        return fallback;
    }

    function togglePanel(id, arg) {
        if (root.isPreview) return;
        if (typeof ShellRouter !== "undefined" && ShellRouter) {
            ShellRouter.toggle(id, arg !== undefined ? arg : "");
        }
    }

    function anchorPointFor(item) {
        let target = item || root;
        let pt = target.mapToItem(null, 0, 0);
        let pos = barWindow ? barWindow.barPosition : "top";
        let globX = isVertical ? (pos === "right" ? pt.x : (pt.x + target.width)) : (pt.x + target.width / 2);
        let globY = isVertical ? (pt.y + target.height / 2) : (pos === "bottom" ? pt.y : (pt.y + target.height));
        return Qt.point(globX, globY);
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }
}
