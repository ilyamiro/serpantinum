pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: root
    visible: false

    readonly property string compositor: {
        let de = (SystemInfo.desktopEnv || "").toLowerCase();
        if (de.indexOf("niri") !== -1) return "niri";
        if (de.indexOf("sway") !== -1) return "sway";
        return "hyprland";
    }

    property bool initialApplied: false

    function sh(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function formatRate(rv) {
        let n = Number(rv);
        if (isNaN(n)) return "60";
        let s = n.toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        return s === "" ? "0" : s;
    }

    function buildMode(resolution, rate) {
        if (!resolution) return "";
        let r = root.formatRate(rate);
        return root.compositor === "sway" ? (resolution + "@" + r + "Hz") : (resolution + "@" + r);
    }

    function applyPower(monName, enabled, modeStr, scaleVal) {
        if (!monName) return;
        if (root.compositor === "niri") {
            root.sh(enabled ? "niri msg output " + monName + " on" : "niri msg output " + monName + " off");
        } else if (root.compositor === "sway") {
            root.sh("swaymsg output " + monName + (enabled ? " enable" : " disable"));
        } else {
            if (!enabled) {
                root.sh("hyprctl eval 'hl.monitor({ output = \"" + monName + "\", disabled = true })'");
                return;
            }
            let mode = (modeStr && modeStr !== "") ? modeStr : "preferred";
            let sc = (scaleVal !== undefined && scaleVal !== null) ? scaleVal : 1.0;
            let luaCmd = 'hl.monitor({ output = "' + monName + '", mode = "' + mode + '", position = "auto", scale = ' + sc.toString() + ', disabled = false })';
            root.sh("hyprctl eval '" + luaCmd + "' || hyprctl keyword monitor " + monName + "," + mode + ",auto," + sc.toString());
        }
    }

    function applyMode(monName, modeStr, scaleVal) {
        if (!monName) return;
        let hasMode = modeStr !== undefined && modeStr !== null && modeStr !== "";
        let hasScale = scaleVal !== undefined && scaleVal !== null;
        if (root.compositor === "niri") {
            let parts = [];
            if (hasMode) parts.push("niri msg output " + monName + " mode " + modeStr);
            if (hasScale) parts.push("niri msg output " + monName + " scale " + scaleVal.toString());
            if (parts.length > 0) root.sh(parts.join(" && "));
        } else if (root.compositor === "sway") {
            let parts = [];
            if (hasMode) parts.push("swaymsg output " + monName + " mode " + modeStr);
            if (hasScale) parts.push("swaymsg output " + monName + " scale " + scaleVal.toString());
            if (parts.length > 0) root.sh(parts.join(" && "));
        } else {
            let mode = hasMode ? modeStr : "preferred";
            let sc = hasScale ? scaleVal : 1.0;
            let luaCmd = 'hl.monitor({ output = "' + monName + '", mode = "' + mode + '", position = "auto", scale = ' + sc.toString() + ' })';
            root.sh("hyprctl eval '" + luaCmd + "' || hyprctl keyword monitor " + monName + "," + mode + ",auto," + sc.toString());
        }
    }

    function reapplyAll() {
        if (typeof Config === "undefined") return;
        let ds = Config.getSetting("display", {"monitors": {}});
        if (!ds || !ds.monitors) return;
        let keys = Object.keys(ds.monitors);
        for (let i = 0; i < keys.length; i++) {
            let name = keys[i];
            let m = ds.monitors[name];
            if (!m) continue;
            let scale = m.scale !== undefined ? m.scale : 1.0;
            if (m.powerEnabled === false) {
                root.applyPower(name, false, "", scale);
                continue;
            }
            let mode = m.mode !== undefined ? m.mode : "";
            if (mode === "" && m.resolution !== undefined && m.refreshRate !== undefined) {
                mode = root.buildMode(m.resolution, m.refreshRate);
            }
            if (mode !== "") {
                root.applyMode(name, mode, scale);
            }
        }
    }

    function ensureInitialApply() {
        if (root.initialApplied) return;
        if (typeof Config === "undefined") return;
        let ds = Config.getSetting("display", null);
        if (!ds || !ds.monitors || Object.keys(ds.monitors).length === 0) return;
        root.initialApplied = true;
        root.reapplyAll();
    }

    Component.onCompleted: startupTimer.start()

    Timer {
        id: startupTimer
        interval: 1500
        repeat: false
        onTriggered: root.ensureInitialApply()
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        ignoreUnknownSignals: true
        function onSettingsLoaded() {
            root.ensureInitialApply();
        }
    }
}
