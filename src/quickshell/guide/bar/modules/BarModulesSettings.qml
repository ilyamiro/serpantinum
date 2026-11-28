import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"
import "../../../"
import "../../../reusables"
import "../../../bar"

GuideTab {
    id: barModulesRoot

    property real cardRadius: ThemeBackend.clampedBorderRadius
    property bool isDesktop: (typeof UPower !== "undefined" && UPower.displayDevice && UPower.displayDevice.ready) ? !UPower.displayDevice.isLaptopBattery : (typeof SystemInfo !== "undefined" ? SystemInfo.isDesktop : false)

    ConfigSection {
        id: barCfg
        section: "bar"
        defaults: ({
            "position": "top",
            "workspacesStyle": "pills",
            "workspaceCount": 8,
            "hideEmptyWorkspaces": false,
            "timeStyle": "classic",
            "timeShowDate": true,
            "visBarCount": 16,
            "visAlignment": "center",
            "visContinuous": false,
            "sysmonStyle": "wave",
            "menuStyle": "button",
            "wifiStyle": "button",
            "wifiShowIcon": true,
            "wifiShowName": true,
            "btStyle": "button",
            "btShowIcon": true,
            "btShowName": true,
            "volStyle": "button",
            "volShowIcon": true,
            "volShowPercent": true,
            "kbStyle": "button",
            "kbShowIcon": true,
            "mediaInfoMode": "duration",
            "mediaWidth": 120,
            "mediaShowIcon": true,
            "mediaShowControls": true,
            "mediaHideWhenIdle": false,
            "mediaStyle": "classic",
            "batStyle": "classic",
            "batShowPercent": true,
            "batShowIcon": true
        })
    }

    readonly property var fallbackStyleKeys: ({
        "left": "menuStyle",
        "workspaces": "workspacesStyle",
        "timedate": "timeStyle",
        "sysmon": "sysmonStyle",
        "bat": "batStyle",
        "wifi": "wifiStyle",
        "bt": "btStyle",
        "vol": "volStyle",
        "kb": "kbStyle",
        "media": "mediaStyle"
    })

    function styleKeyFor(moduleId) {
        if (typeof BarModuleRegistry.styleKeyFor === "function") {
            let k = BarModuleRegistry.styleKeyFor(moduleId);
            if (k) return k;
        }
        let t = BarModuleRegistry.types ? BarModuleRegistry.types[moduleId] : null;
        if (t && t.styleKey) return t.styleKey;
        return fallbackStyleKeys[moduleId] || "";
    }

    readonly property var barValues: barCfg.values
    readonly property string barPosition: String(barValues.position !== undefined ? barValues.position : "top")
    readonly property bool isSideBar: barPosition === "left" || barPosition === "right"

    readonly property string workspacesStyle: String(barValues.workspacesStyle || "pills")
    readonly property int workspaceCount: Number(barValues.workspaceCount !== undefined ? barValues.workspaceCount : 8)
    readonly property bool hideEmptyWorkspaces: Boolean(barValues.hideEmptyWorkspaces)
    readonly property bool perMonitorNumbering: Boolean(barValues.workspaces && barValues.workspaces.perMonitorNumbering === true)
    property var workspaceMonitorNames: []
    readonly property var workspaceMonitorCounts: (barValues.workspaces && barValues.workspaces.monitors) ? barValues.workspaces.monitors : ({})

    Process {
        id: workspaceMonitorDetector
        running: false
        command: ["serpantinum-core", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    barModulesRoot.workspaceMonitorNames = JSON.parse(this.text).map(m => m.name);
                } catch (e) {
                    barModulesRoot.workspaceMonitorNames = [];
                }
            }
        }
    }

    function reloadWorkspaceMonitors() {
        workspaceMonitorDetector.running = false;
        workspaceMonitorDetector.running = true;
    }

    readonly property string timeStyle: String(barValues.timeStyle || "classic")
    readonly property bool timeShowDate: barValues.timeShowDate !== undefined ? Boolean(barValues.timeShowDate) : (barValues.showDate !== undefined ? Boolean(barValues.showDate) : true)
    readonly property int visBarCount: Number(barValues.visBarCount !== undefined ? barValues.visBarCount : 16)
    readonly property string visAlignment: String(barValues.visAlignment || "center")
    readonly property bool visContinuous: Boolean(barValues.visContinuous)

    readonly property string sysmonStyle: String(barValues.sysmonStyle || (barValues.sysmon && barValues.sysmon.style) || "wave")
    readonly property var sysmonStats: {
        if (Array.isArray(barValues.sysmonStats)) return barValues.sysmonStats;
        if (barValues.sysmon && Array.isArray(barValues.sysmon.stats)) return barValues.sysmon.stats;
        if (barValues.sysmonShowCpu !== undefined || barValues.sysmonShowRam !== undefined || barValues.sysmonShowTemp !== undefined || barValues.sysmonShowDisk !== undefined) {
            let stats = [];
            if (barValues.sysmonShowCpu !== false) stats.push("cpu");
            if (barValues.sysmonShowRam !== false) stats.push("ram");
            if (barValues.sysmonShowTemp !== false) stats.push("temp");
            if (barValues.sysmonShowDisk === true) stats.push("disk");
            return stats;
        }
        return ["cpu", "ram", "temp"];
    }

    readonly property var menuStyles: BarModuleRegistry.variantList("left")
    readonly property var workspaceStyles: BarModuleRegistry.variantList("workspaces")
    readonly property var timeStyles: BarModuleRegistry.variantList("timedate")
    readonly property var batStyles: BarModuleRegistry.variantList("bat")
    readonly property var wifiStyles: BarModuleRegistry.variantList("wifi")
    readonly property var btStyles: BarModuleRegistry.variantList("bt")
    readonly property var volStyles: BarModuleRegistry.variantList("vol")
    readonly property var kbStyles: BarModuleRegistry.variantList("kb")
    readonly property var sysmonStyles: BarModuleRegistry.variantList("sysmon")
    readonly property var mediaStyles: BarModuleRegistry.variantList("media")

    readonly property string menuStyle: String(barValues.menuStyle || "button")
    readonly property var menuItems: BarModuleRegistry.menuItemsFromSettings(barValues)

    readonly property string wifiStyle: String(barValues.wifiStyle || "button")
    readonly property bool wifiShowName: Boolean(barValues.wifiShowName !== undefined ? barValues.wifiShowName : true)
    readonly property bool wifiShowIcon: (!wifiShowName) ? true : Boolean(barValues.wifiShowIcon !== undefined ? barValues.wifiShowIcon : true)

    readonly property string btStyle: String(barValues.btStyle || "button")
    readonly property bool btShowName: Boolean(barValues.btShowName !== undefined ? barValues.btShowName : true)
    readonly property bool btShowIcon: (!btShowName) ? true : Boolean(barValues.btShowIcon !== undefined ? barValues.btShowIcon : true)

    readonly property string volStyle: String(barValues.volStyle || "button")
    readonly property bool volShowPercent: Boolean(barValues.volShowPercent !== undefined ? barValues.volShowPercent : true)
    readonly property bool volShowIcon: (!volShowPercent) ? true : Boolean(barValues.volShowIcon !== undefined ? barValues.volShowIcon : true)

    readonly property string kbStyle: String(barValues.kbStyle || "button")
    readonly property bool kbShowIcon: Boolean(barValues.kbShowIcon !== undefined ? barValues.kbShowIcon : true)

    readonly property string mediaInfoMode: String(barValues.mediaInfoMode || "duration")
    readonly property int mediaWidth: Math.round(Number(barValues.mediaWidth !== undefined ? barValues.mediaWidth : 120))
    readonly property bool mediaShowIcon: Boolean(barValues.mediaShowIcon !== undefined ? barValues.mediaShowIcon : true)
    readonly property bool mediaShowControls: Boolean(barValues.mediaShowControls !== undefined ? barValues.mediaShowControls : true)
    readonly property bool mediaHideWhenIdle: Boolean(barValues.mediaHideWhenIdle)
    readonly property string mediaStyle: String(barValues.mediaStyle || "classic")

    readonly property string batStyle: String(barValues.batStyle || "classic")
    readonly property bool batShowPercent: Boolean(barValues.batShowPercent !== undefined ? barValues.batShowPercent : true)
    readonly property bool batShowIcon: (!batShowPercent) ? true : Boolean(barValues.batShowIcon !== undefined ? barValues.batShowIcon : true)

    property real barOpacity: ThemeBackend.elementOpacity

    function setBarProp(key, value) {
        barCfg.set(key, value);
    }

    function setBarPropDebounced(key, value) {
        barCfg.setDebounced(key, value, 100);
    }

    function setModuleStyle(moduleId, styleName) {
        let k = styleKeyFor(moduleId);
        if (k) barCfg.set(k, styleName);
    }

    function setPairedToggle(key, peerKey, val) {
        if (!val && peerKey && !Boolean(barModulesRoot[peerKey])) return;
        barCfg.set(key, val);
    }

    function setWorkspacesStyle(styleName) { barCfg.set("workspacesStyle", styleName); }
    function setWorkspaceCount(count) { barCfg.set("workspaceCount", count); }
    function setHideEmptyWorkspaces(val) { barCfg.set("hideEmptyWorkspaces", val); }

    function setPerMonitorNumbering(val) {
        let ws = Object.assign({}, barValues.workspaces || {}, { perMonitorNumbering: val });
        barCfg.set("workspaces", ws);
        let names = barModulesRoot.workspaceMonitorNames;
        if (val && names.length > 0 && !barModulesRoot.workspaceMonitorCounts[names[0]]) {
            barModulesRoot.setMonitorWorkspaceCount(names[0], barModulesRoot.workspaceCountFor(names[0]));
        }
    }

    function workspaceCountFor(name) {
        let entry = barModulesRoot.workspaceMonitorCounts[name];
        let n = entry ? Math.floor(Number(entry.count)) : 0;
        return n >= 1 ? n : 10;
    }

    function setMonitorWorkspaceCount(name, count) {
        let monitors = {};
        let first = 1;
        for (let i = 0; i < barModulesRoot.workspaceMonitorNames.length; i++) {
            let mon = barModulesRoot.workspaceMonitorNames[i];
            let n = mon === name ? count : barModulesRoot.workspaceCountFor(mon);
            monitors[mon] = { "first": first, "count": n };
            first += n;
        }
        let ws = Object.assign({}, barValues.workspaces || {}, { monitors: monitors });
        barCfg.set("workspaces", ws);
    }

    function setTimeStyle(styleName) { barCfg.set("timeStyle", styleName); }
    function setTimeShowDate(show) { barCfg.set("timeShowDate", show); }
    function setVisBarCount(count) { barCfg.set("visBarCount", count); }
    function setVisAlignment(align) { barCfg.set("visAlignment", align); }
    function setVisContinuous(val) { barCfg.set("visContinuous", val); }
    function setSysmonStyle(styleName) { barCfg.set("sysmonStyle", styleName); }
    function setSysmonStats(list) { barCfg.set("sysmonStats", list); }
    function setMenuStyle(styleName) { barCfg.set("menuStyle", styleName); }
    function setMenuItems(list) { if (list && list.length > 0) barCfg.set("menuItems", list); }
    function setMediaInfoMode(val) { barCfg.set("mediaInfoMode", val); }
    function setMediaWidth(val) { barCfg.set("mediaWidth", val); }
    function setMediaShowIcon(val) { barCfg.set("mediaShowIcon", val); }
    function setMediaShowControls(val) { barCfg.set("mediaShowControls", val); }
    function setMediaHideWhenIdle(val) { barCfg.set("mediaHideWhenIdle", val); }
    function setMediaStyle(styleName) { barCfg.set("mediaStyle", styleName); }

    onVisibleChanged: {
        if (!visible) barCfg.flush();
    }

    Component.onCompleted: {
        reloadWorkspaceMonitors();
    }
}
