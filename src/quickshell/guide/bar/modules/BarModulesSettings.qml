import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"
import "../../../"
import "../../../bar"

GuideTab {
    id: barModulesRoot

    property real cardRadius: ThemeBackend.clampedBorderRadius

    property bool isDesktop: (typeof UPower !== "undefined" && UPower.displayDevice && UPower.displayDevice.ready) ? !UPower.displayDevice.isLaptopBattery : (typeof SystemInfo !== "undefined" ? SystemInfo.isDesktop : false)

    property string barPosition: {
        let bs = Config.getSetting("bar", {});
        return bs && bs.position !== undefined ? bs.position : "top";
    }
    readonly property bool isSideBar: barPosition === "left" || barPosition === "right"

    property string workspacesStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.workspacesStyle) return bs.workspacesStyle;
        return "pills";
    }

    property int workspaceCount: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.workspaceCount !== undefined) return bs.workspaceCount;
        return 8;
    }

    property bool hideEmptyWorkspaces: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.hideEmptyWorkspaces !== undefined) return Boolean(bs.hideEmptyWorkspaces);
        return false;
    }

    property bool perMonitorNumbering: {
        let bs = Config.getSetting("bar", {});
        return !!(bs && bs.workspaces && bs.workspaces.perMonitorNumbering === true);
    }

    property var workspaceMonitorNames: []

    property var workspaceMonitorCounts: {
        let bs = Config.getSetting("bar", {});
        return (bs && bs.workspaces && bs.workspaces.monitors) ? bs.workspaces.monitors : {};
    }

    Process {
        id: workspaceMonitorDetector
        running: false
        command: ["bash", Caching.serpantinumDir + "/scripts/monitors_detect.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                barModulesRoot.workspaceMonitorNames = this.text.trim().split("\n").map(n => n.trim()).filter(n => n.length > 0);
            }
        }
    }

    function reloadWorkspaceMonitors() {
        workspaceMonitorDetector.running = false;
        workspaceMonitorDetector.running = true;
    }

    property string timeStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.timeStyle) return bs.timeStyle;
        return "classic";
    }

    property bool timeShowDate: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.timeShowDate !== undefined) return bs.timeShowDate;
        if (bs && bs.showDate !== undefined) return bs.showDate;
        return true;
    }

    property string timeFormat: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.time && bs.time.format !== undefined) return bs.time.format;
        return "HH:mm:ss";
    }

    property int visBarCount: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.visBarCount !== undefined) return bs.visBarCount;
        return 16;
    }

    property string visAlignment: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.visAlignment) return bs.visAlignment;
        return "center";
    }

    property bool visContinuous: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.visContinuous !== undefined) return Boolean(bs.visContinuous);
        return false;
    }

    property string sysmonStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.sysmonStyle) return bs.sysmonStyle;
        if (bs && bs.sysmon && bs.sysmon.style) return bs.sysmon.style;
        return "wave";
    }

    property var sysmonStats: {
        let bs = Config.getSetting("bar", {});
        if (bs && Array.isArray(bs.sysmonStats)) return bs.sysmonStats;
        if (bs && bs.sysmon && Array.isArray(bs.sysmon.stats)) return bs.sysmon.stats;
        if (bs && (bs.sysmonShowCpu !== undefined || bs.sysmonShowRam !== undefined || bs.sysmonShowTemp !== undefined || bs.sysmonShowDisk !== undefined)) {
            let stats = [];
            if (bs.sysmonShowCpu !== false) stats.push("cpu");
            if (bs.sysmonShowRam !== false) stats.push("ram");
            if (bs.sysmonShowTemp !== false) stats.push("temp");
            if (bs.sysmonShowDisk === true) stats.push("disk");
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

    property string menuStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.menuStyle) return bs.menuStyle;
        return "button";
    }

    property var menuItems: BarModuleRegistry.menuItemsFromSettings(Config.getSetting("bar", {}))

    property string wifiStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.wifiStyle) return bs.wifiStyle;
        return "button";
    }

    property bool wifiShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.wifiShowIcon !== undefined) return Boolean(bs.wifiShowIcon);
        return true;
    }

    property bool wifiShowName: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.wifiShowName !== undefined) return Boolean(bs.wifiShowName);
        return true;
    }

    property string btStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.btStyle) return bs.btStyle;
        return "button";
    }

    property bool btShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.btShowIcon !== undefined) return Boolean(bs.btShowIcon);
        return true;
    }

    property bool btShowName: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.btShowName !== undefined) return Boolean(bs.btShowName);
        return true;
    }

    property string volStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.volStyle) return bs.volStyle;
        return "button";
    }

    property bool volShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.volShowIcon !== undefined) return Boolean(bs.volShowIcon);
        return true;
    }

    property bool volShowPercent: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.volShowPercent !== undefined) return Boolean(bs.volShowPercent);
        return true;
    }

    property string kbStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.kbStyle) return bs.kbStyle;
        return "button";
    }

    property bool kbShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.kbShowIcon !== undefined) return Boolean(bs.kbShowIcon);
        return true;
    }

    property string mediaInfoMode: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.mediaInfoMode) return bs.mediaInfoMode;
        return "duration";
    }

    property int mediaWidth: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.mediaWidth !== undefined) return Math.round(Number(bs.mediaWidth));
        return 120;
    }

    property bool mediaShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.mediaShowIcon !== undefined) return Boolean(bs.mediaShowIcon);
        return true;
    }

    property bool mediaShowControls: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.mediaShowControls !== undefined) return Boolean(bs.mediaShowControls);
        return true;
    }

    property bool mediaHideWhenIdle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.mediaHideWhenIdle !== undefined) return Boolean(bs.mediaHideWhenIdle);
        return false;
    }

    property string batStyle: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.batStyle) return bs.batStyle;
        return "classic";
    }

    property bool batShowPercent: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.batShowPercent !== undefined) return Boolean(bs.batShowPercent);
        return true;
    }

    property bool batShowIcon: {
        let bs = Config.getSetting("bar", {});
        if (bs && bs.batShowIcon !== undefined) return Boolean(bs.batShowIcon);
        return true;
    }

    property real barOpacity: ThemeBackend.elementOpacity

    function syncSettings() {
        let bs = Config.getSetting("bar", {});
        barModulesRoot.barPosition = (bs && bs.position !== undefined) ? bs.position : "top";

        if (bs && bs.workspacesStyle) {
            barModulesRoot.workspacesStyle = bs.workspacesStyle;
        } else {
            barModulesRoot.workspacesStyle = "pills";
        }

        if (bs && bs.workspaceCount !== undefined) {
            barModulesRoot.workspaceCount = bs.workspaceCount;
        } else {
            barModulesRoot.workspaceCount = 8;
        }

        if (bs && bs.hideEmptyWorkspaces !== undefined) {
            barModulesRoot.hideEmptyWorkspaces = Boolean(bs.hideEmptyWorkspaces);
        } else {
            barModulesRoot.hideEmptyWorkspaces = false;
        }

        barModulesRoot.perMonitorNumbering = !!(bs && bs.workspaces && bs.workspaces.perMonitorNumbering === true);
        barModulesRoot.workspaceMonitorCounts = (bs && bs.workspaces && bs.workspaces.monitors) ? bs.workspaces.monitors : {};

        if (bs && bs.timeStyle) {
            barModulesRoot.timeStyle = bs.timeStyle;
        } else {
            barModulesRoot.timeStyle = "classic";
        }

        if (bs && bs.timeShowDate !== undefined) {
            barModulesRoot.timeShowDate = bs.timeShowDate;
        } else if (bs && bs.showDate !== undefined) {
            barModulesRoot.timeShowDate = bs.showDate;
        } else {
            barModulesRoot.timeShowDate = true;
        }

        if (bs && bs.time && bs.time.format !== undefined) {
            barModulesRoot.timeFormat = bs.time.format;
        } else {
            barModulesRoot.timeFormat = "HH:mm:ss";
        }

        if (bs && bs.visBarCount !== undefined) {
            barModulesRoot.visBarCount = bs.visBarCount;
        } else {
            barModulesRoot.visBarCount = 16;
        }

        if (bs && bs.visAlignment) {
            barModulesRoot.visAlignment = bs.visAlignment;
        } else {
            barModulesRoot.visAlignment = "center";
        }

        if (bs && bs.visContinuous !== undefined) {
            barModulesRoot.visContinuous = Boolean(bs.visContinuous);
        } else {
            barModulesRoot.visContinuous = false;
        }

        if (bs && bs.sysmonStyle) {
            barModulesRoot.sysmonStyle = bs.sysmonStyle;
        } else {
            barModulesRoot.sysmonStyle = "wave";
        }

        if (bs && Array.isArray(bs.sysmonStats)) {
            barModulesRoot.sysmonStats = bs.sysmonStats;
        } else if (bs && (bs.sysmonShowCpu !== undefined || bs.sysmonShowRam !== undefined || bs.sysmonShowTemp !== undefined || bs.sysmonShowDisk !== undefined)) {
            let stats = [];
            if (bs.sysmonShowCpu !== false) stats.push("cpu");
            if (bs.sysmonShowRam !== false) stats.push("ram");
            if (bs.sysmonShowTemp !== false) stats.push("temp");
            if (bs.sysmonShowDisk === true) stats.push("disk");
            barModulesRoot.sysmonStats = stats;
        } else {
            barModulesRoot.sysmonStats = ["cpu", "ram", "temp"];
        }

        if (bs && bs.batStyle) {
            barModulesRoot.batStyle = bs.batStyle;
        } else {
            barModulesRoot.batStyle = "classic";
        }

        if (bs && bs.batShowPercent !== undefined) {
            barModulesRoot.batShowPercent = Boolean(bs.batShowPercent);
        } else {
            barModulesRoot.batShowPercent = true;
        }

        if (bs && bs.batShowIcon !== undefined) {
            barModulesRoot.batShowIcon = Boolean(bs.batShowIcon);
        } else {
            barModulesRoot.batShowIcon = true;
        }

        barModulesRoot.menuStyle = (bs && bs.menuStyle) ? bs.menuStyle : "button";
        barModulesRoot.menuItems = BarModuleRegistry.menuItemsFromSettings(bs);

        if (bs && bs.wifiStyle) {
            barModulesRoot.wifiStyle = bs.wifiStyle;
        } else {
            barModulesRoot.wifiStyle = "button";
        }

        if (bs && bs.wifiShowIcon !== undefined) {
            barModulesRoot.wifiShowIcon = Boolean(bs.wifiShowIcon);
        } else {
            barModulesRoot.wifiShowIcon = true;
        }

        if (bs && bs.wifiShowName !== undefined) {
            barModulesRoot.wifiShowName = Boolean(bs.wifiShowName);
        } else {
            barModulesRoot.wifiShowName = true;
        }

        if (bs && bs.btStyle) {
            barModulesRoot.btStyle = bs.btStyle;
        } else {
            barModulesRoot.btStyle = "button";
        }

        if (bs && bs.btShowIcon !== undefined) {
            barModulesRoot.btShowIcon = Boolean(bs.btShowIcon);
        } else {
            barModulesRoot.btShowIcon = true;
        }

        if (bs && bs.btShowName !== undefined) {
            barModulesRoot.btShowName = Boolean(bs.btShowName);
        } else {
            barModulesRoot.btShowName = true;
        }

        if (bs && bs.volStyle) {
            barModulesRoot.volStyle = bs.volStyle;
        } else {
            barModulesRoot.volStyle = "button";
        }

        if (bs && bs.volShowIcon !== undefined) {
            barModulesRoot.volShowIcon = Boolean(bs.volShowIcon);
        } else {
            barModulesRoot.volShowIcon = true;
        }

        if (bs && bs.volShowPercent !== undefined) {
            barModulesRoot.volShowPercent = Boolean(bs.volShowPercent);
        } else {
            barModulesRoot.volShowPercent = true;
        }

        if (bs && bs.kbStyle) {
            barModulesRoot.kbStyle = bs.kbStyle;
        } else {
            barModulesRoot.kbStyle = "button";
        }

        if (bs && bs.kbShowIcon !== undefined) {
            barModulesRoot.kbShowIcon = Boolean(bs.kbShowIcon);
        } else {
            barModulesRoot.kbShowIcon = true;
        }

        barModulesRoot.mediaInfoMode = (bs && bs.mediaInfoMode) ? bs.mediaInfoMode : "duration";
        barModulesRoot.mediaWidth = (bs && bs.mediaWidth !== undefined) ? Math.round(Number(bs.mediaWidth)) : 120;

        if (bs && bs.mediaShowIcon !== undefined) {
            barModulesRoot.mediaShowIcon = Boolean(bs.mediaShowIcon);
        } else {
            barModulesRoot.mediaShowIcon = true;
        }

        if (bs && bs.mediaShowControls !== undefined) {
            barModulesRoot.mediaShowControls = Boolean(bs.mediaShowControls);
        } else {
            barModulesRoot.mediaShowControls = true;
        }

        barModulesRoot.mediaHideWhenIdle = (bs && bs.mediaHideWhenIdle !== undefined) ? Boolean(bs.mediaHideWhenIdle) : false;

        if (!barModulesRoot.batShowPercent && !barModulesRoot.batShowIcon) {
            barModulesRoot.batShowIcon = true;
        }
        if (!barModulesRoot.wifiShowIcon && !barModulesRoot.wifiShowName) {
            barModulesRoot.wifiShowIcon = true;
        }
        if (!barModulesRoot.btShowIcon && !barModulesRoot.btShowName) {
            barModulesRoot.btShowIcon = true;
        }
        if (!barModulesRoot.volShowIcon && !barModulesRoot.volShowPercent) {
            barModulesRoot.volShowIcon = true;
        }
    }

    function setWorkspacesStyle(styleName) {
        barModulesRoot.workspacesStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.workspacesStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setWorkspaceCount(count) {
        barModulesRoot.workspaceCount = count;
        let current = Config.getSetting("bar", {});
        current.workspaceCount = count;
        Config.setSetting("bar", current);
    }

    function setHideEmptyWorkspaces(val) {
        barModulesRoot.hideEmptyWorkspaces = val;
        let current = Config.getSetting("bar", {});
        current.hideEmptyWorkspaces = val;
        Config.setSetting("bar", current);
    }

    function setPerMonitorNumbering(val) {
        barModulesRoot.perMonitorNumbering = val;
        let current = Config.getSetting("bar", {});
        current.workspaces = Object.assign({}, current.workspaces, { perMonitorNumbering: val });
        Config.setSetting("bar", current);
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
        barModulesRoot.workspaceMonitorCounts = monitors;
        let current = Config.getSetting("bar", {});
        current.workspaces = Object.assign({}, current.workspaces, { monitors: monitors });
        Config.setSetting("bar", current);
    }

    function setTimeStyle(styleName) {
        barModulesRoot.timeStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.timeStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setTimeShowDate(show) {
        barModulesRoot.timeShowDate = show;
        let current = Config.getSetting("bar", {});
        current.timeShowDate = show;
        if (current.showDate !== undefined) delete current.showDate;
        Config.setSetting("bar", current);
    }

    function setTimeFormat(fmt) {
        barModulesRoot.timeFormat = fmt;
        let current = Config.getSetting("bar", {});
        if (!current.time) current.time = {};
        current.time.format = fmt;
        Config.setSetting("bar", current);
    }

    function setVisBarCount(count) {
        barModulesRoot.visBarCount = count;
        let current = Config.getSetting("bar", {});
        current.visBarCount = count;
        Config.setSetting("bar", current);
    }

    function setVisAlignment(align) {
        barModulesRoot.visAlignment = align;
        let current = Config.getSetting("bar", {});
        current.visAlignment = align;
        Config.setSetting("bar", current);
    }

    function setVisContinuous(val) {
        barModulesRoot.visContinuous = val;
        let current = Config.getSetting("bar", {});
        current.visContinuous = val;
        Config.setSetting("bar", current);
    }

    function setSysmonStyle(styleName) {
        barModulesRoot.sysmonStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.sysmonStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setSysmonStats(list) {
        barModulesRoot.sysmonStats = list;
        let current = Config.getSetting("bar", {});
        current.sysmonStats = list;
        Config.setSetting("bar", current);
    }

    function setBatStyle(styleName) {
        barModulesRoot.batStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.batStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setBatShowPercent(val) {
        if (!val && !barModulesRoot.batShowIcon) return;
        barModulesRoot.batShowPercent = val;
        let current = Config.getSetting("bar", {});
        current.batShowPercent = val;
        Config.setSetting("bar", current);
    }

    function setBatShowIcon(val) {
        if (!val && !barModulesRoot.batShowPercent) return;
        barModulesRoot.batShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.batShowIcon = val;
        Config.setSetting("bar", current);
    }

    function setMenuStyle(styleName) {
        barModulesRoot.menuStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.menuStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setMenuItems(list) {
        if (!list || list.length === 0) return;
        barModulesRoot.menuItems = list;
        let current = Config.getSetting("bar", {});
        current.menuItems = list;
        Config.setSetting("bar", current);
    }

    function setWifiStyle(styleName) {
        barModulesRoot.wifiStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.wifiStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setWifiShowIcon(val) {
        if (!val && !barModulesRoot.wifiShowName) return;
        barModulesRoot.wifiShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.wifiShowIcon = val;
        Config.setSetting("bar", current);
    }

    function setWifiShowName(val) {
        if (!val && !barModulesRoot.wifiShowIcon) return;
        barModulesRoot.wifiShowName = val;
        let current = Config.getSetting("bar", {});
        current.wifiShowName = val;
        Config.setSetting("bar", current);
    }

    function setBtStyle(styleName) {
        barModulesRoot.btStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.btStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setBtShowIcon(val) {
        if (!val && !barModulesRoot.btShowName) return;
        barModulesRoot.btShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.btShowIcon = val;
        Config.setSetting("bar", current);
    }

    function setBtShowName(val) {
        if (!val && !barModulesRoot.btShowIcon) return;
        barModulesRoot.btShowName = val;
        let current = Config.getSetting("bar", {});
        current.btShowName = val;
        Config.setSetting("bar", current);
    }

    function setVolStyle(styleName) {
        barModulesRoot.volStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.volStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setVolShowIcon(val) {
        if (!val && !barModulesRoot.volShowPercent) return;
        barModulesRoot.volShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.volShowIcon = val;
        Config.setSetting("bar", current);
    }

    function setVolShowPercent(val) {
        if (!val && !barModulesRoot.volShowIcon) return;
        barModulesRoot.volShowPercent = val;
        let current = Config.getSetting("bar", {});
        current.volShowPercent = val;
        Config.setSetting("bar", current);
    }

    function setKbStyle(styleName) {
        barModulesRoot.kbStyle = styleName;
        let current = Config.getSetting("bar", {});
        current.kbStyle = styleName;
        Config.setSetting("bar", current);
    }

    function setKbShowIcon(val) {
        barModulesRoot.kbShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.kbShowIcon = val;
        Config.setSetting("bar", current);
    }

    function setMediaInfoMode(val) {
        barModulesRoot.mediaInfoMode = val;
        let current = Config.getSetting("bar", {});
        current.mediaInfoMode = val;
        Config.setSetting("bar", current);
    }

    function setMediaWidth(val) {
        let current = Config.getSetting("bar", {});
        current.mediaWidth = val;
        Config.setSetting("bar", current);
    }

    function setMediaShowIcon(val) {
        barModulesRoot.mediaShowIcon = val;
        let current = Config.getSetting("bar", {});
        current.mediaShowIcon = val;
        Config.setSetting("bar", current);
    }

    function setMediaShowControls(val) {
        barModulesRoot.mediaShowControls = val;
        let current = Config.getSetting("bar", {});
        current.mediaShowControls = val;
        Config.setSetting("bar", current);
    }

    function setMediaHideWhenIdle(val) {
        barModulesRoot.mediaHideWhenIdle = val;
        let current = Config.getSetting("bar", {});
        current.mediaHideWhenIdle = val;
        Config.setSetting("bar", current);
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
        }
    }

    Component.onCompleted: {
        syncSettings();
        reloadWorkspaceMonitors();
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            barModulesRoot.syncSettings();
        }
        function onRawSettingsChanged() {
            barModulesRoot.syncSettings();
        }
    }
}
