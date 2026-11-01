import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"

GuideTab {
    id: displayTabRoot
    subTabIndex: 0

    property var defaultDisplaySettings: ({
        "monitors": {}
    })

    property var displaySettings: JSON.parse(JSON.stringify(Config.getSetting("display", defaultDisplaySettings)))
    property var monitorsList: []

    readonly property string compositor: {
        let de = (SystemInfo.desktopEnv || "").toLowerCase();
        if (de.indexOf("niri") !== -1) return "niri";
        if (de.indexOf("sway") !== -1) return "sway";
        if (de.indexOf("mango") !== -1) return "mango";
        return "hyprland";
    }

    property string pendingMonName: ""
    property real pendingMonTemp: 50

    property string pendingMonScaleName: ""
    property real pendingMonScaleVal: 1.0

    readonly property string detectedCity: {
        if (typeof Location !== "undefined" && Location.city && Location.city !== "Unknown") {
            return Location.city;
        }
        let genSet = Config.getSetting("general", {});
        if (genSet && genSet.location && genSet.location.city && genSet.location.city !== "Unknown") {
            return genSet.location.city;
        }
        return "";
    }

    readonly property real detectedLat: {
        if (typeof Location !== "undefined" && Location.latitude !== undefined && Location.latitude !== 0) {
            return Location.latitude;
        }
        let genSet = Config.getSetting("general", {});
        if (genSet && genSet.location && genSet.location.latitude !== undefined) {
            return Number(genSet.location.latitude);
        }
        return 0;
    }

    readonly property real detectedLon: {
        if (typeof Location !== "undefined" && Location.longitude !== undefined && Location.longitude !== 0) {
            return Location.longitude;
        }
        let genSet = Config.getSetting("general", {});
        if (genSet && genSet.location && genSet.location.longitude !== undefined) {
            return Number(genSet.location.longitude);
        }
        return 0;
    }

    readonly property bool is24Hour: {
        if (typeof DateTime !== "undefined") {
            if (typeof DateTime.is24Hour === "boolean") return DateTime.is24Hour;
            if (typeof DateTime.use24Hour === "boolean") return DateTime.use24Hour;
            if (typeof DateTime.clock24 === "boolean") return DateTime.clock24;
            if (typeof DateTime.clock24h === "boolean") return DateTime.clock24h;
            if (DateTime.timeOnly && typeof DateTime.timeOnly === "string") {
                return !/am|pm/i.test(DateTime.timeOnly);
            }
            if (DateTime.time && typeof DateTime.time === "string") {
                return !/am|pm/i.test(DateTime.time);
            }
        }
        let dtSet = Config.getSetting("datetime", {});
        if (typeof dtSet.clock24 === "boolean") return dtSet.clock24;
        if (typeof dtSet.clock24h === "boolean") return dtSet.clock24h;
        if (typeof dtSet.use24Hour === "boolean") return dtSet.use24Hour;
        if (typeof dtSet.is24Hour === "boolean") return dtSet.is24Hour;
        let genSet = Config.getSetting("general", {});
        if (typeof genSet.clock24 === "boolean") return genSet.clock24;
        if (typeof genSet.clock24h === "boolean") return genSet.clock24h;
        if (typeof genSet.use24Hour === "boolean") return genSet.use24Hour;
        if (typeof genSet.is24Hour === "boolean") return genSet.is24Hour;
        return true;
    }

    function formatTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        let hours = date.getHours();
        let minutes = date.getMinutes();
        let minStr = minutes < 10 ? "0" + minutes : minutes.toString();
        if (displayTabRoot.is24Hour) {
            let hrStr = hours < 10 ? "0" + hours : hours.toString();
            return hrStr + ":" + minStr;
        } else {
            let ampm = hours >= 12 ? "PM" : "AM";
            let h12 = hours % 12;
            if (h12 === 0) h12 = 12;
            return h12 + ":" + minStr + " " + ampm;
        }
    }

    function calculateSunTimes(lat, lon, date) {
        if (!date) date = new Date();
        let latNum = Number(lat) || 0;
        let lonNum = Number(lon) || 0;

        if (latNum === 0 && lonNum === 0) {
            let sr = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 6, 0, 0);
            let ss = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 19, 0, 0);
            return { sunrise: sr, sunset: ss };
        }

        let rad = Math.PI / 180.0;
        let deg = 180.0 / Math.PI;

        let year = date.getFullYear();
        let month = date.getMonth();
        let day = date.getDate();

        let noonUtc = Date.UTC(year, month, day, 12, 0, 0);
        let d = (noonUtc - 946728000000) / 86400000;

        let M = (357.529 + 0.98560028 * d) % 360;
        if (M < 0) M += 360;

        let L = (280.459 + 0.98564736 * d) % 360;
        if (L < 0) L += 360;

        let lambda = (L + 1.915 * Math.sin(M * rad) + 0.020 * Math.sin(2 * M * rad)) % 360;
        if (lambda < 0) lambda += 360;

        let eps = 23.439 - 0.00000036 * d;

        let sinDec = Math.sin(eps * rad) * Math.sin(lambda * rad);
        let cosDec = Math.sqrt(Math.max(0, 1 - sinDec * sinDec));

        let alt0 = -0.833 * rad;
        let latRad = latNum * rad;

        let cosH = (Math.sin(alt0) - Math.sin(latRad) * sinDec) / (Math.cos(latRad) * cosDec);
        if (cosH > 1 || cosH < -1) {
            return null;
        }

        let H0 = Math.acos(cosH) * deg;

        let RA = Math.atan2(Math.cos(eps * rad) * Math.sin(lambda * rad), Math.cos(lambda * rad)) * deg;
        RA = (RA % 360 + 360) % 360;

        let GMST = (280.46061837 + 360.98564736629 * d) % 360;
        if (GMST < 0) GMST += 360;

        let noonDiff = (RA - GMST - lonNum) % 360;
        if (noonDiff > 180) noonDiff -= 360;
        if (noonDiff < -180) noonDiff += 360;

        let solarNoonUtcHours = 12.0 + (noonDiff / 15.0);

        let sunriseUtcHours = solarNoonUtcHours - (H0 / 15.0);
        let sunsetUtcHours = solarNoonUtcHours + (H0 / 15.0);

        let sunriseDate = new Date(Date.UTC(year, month, day, 0, 0, 0) + Math.round(sunriseUtcHours * 3600 * 1000));
        let sunsetDate = new Date(Date.UTC(year, month, day, 0, 0, 0) + Math.round(sunsetUtcHours * 3600 * 1000));

        return { sunrise: sunriseDate, sunset: sunsetDate };
    }

    readonly property string scheduleDescription: {
        let city = displayTabRoot.detectedCity;
        let lat = displayTabRoot.detectedLat;
        let lon = displayTabRoot.detectedLon;
        let sun = displayTabRoot.calculateSunTimes(lat, lon, new Date());
        let timeRange = "";
        if (sun && sun.sunrise && sun.sunset) {
            timeRange = displayTabRoot.formatTime(sun.sunrise) + " - " + displayTabRoot.formatTime(sun.sunset);
        }
        let place = city ? city : "location";
        let target = timeRange !== "" ? (place + " (" + timeRange + ")") : place;
        return target;
    }

    function refreshDisplaySettings() {
        displayTabRoot.displaySettings = JSON.parse(JSON.stringify(Config.getSetting("display", displayTabRoot.defaultDisplaySettings)));
    }

    function validScalesForResolution(width, height) {
        if (!width || !height) return [1.0];

        let commonScales = [
            0.5, 0.6, 0.667, 0.75, 0.8, 0.9, 1.0, 1.1, 1.2, 1.25,
            1.333, 1.4, 1.5, 1.6, 1.667, 1.75, 1.8, 1.9, 2.0,
            2.25, 2.5, 2.667, 2.75, 3.0
        ];

        let candidates = [];
        let seen = {};

        function tryAddScale(s, requireInteger) {
            let sRounded = Math.round(s * 1000) / 1000;
            let key = sRounded.toFixed(3);
            if (seen[key]) return;

            if (requireInteger) {
                let lw = width / sRounded;
                let lh = height / sRounded;
                let epsilon = 0.001;
                if (Math.abs(lw - Math.round(lw)) >= epsilon || Math.abs(lh - Math.round(lh)) >= epsilon) {
                    return;
                }
            }

            seen[key] = true;
            candidates.push(sRounded);
        }

        for (let s = 0.50; s <= 3.00; s += 0.05) {
            tryAddScale(Math.round(s * 100) / 100, true);
        }

        for (let i = 0; i < commonScales.length; i++) {
            tryAddScale(commonScales[i], true);
        }

        candidates.sort((a, b) => a - b);
        return candidates.length > 0 ? candidates : [1.0];
    }

    function nearestValidScaleFromList(validList, target) {
        if (!validList || validList.length === 0) return 1.0;
        let best = validList[0];
        let bestDiff = Math.abs(validList[0] - target);
        for (let i = 1; i < validList.length; i++) {
            let diff = Math.abs(validList[i] - target);
            if (diff < bestDiff) {
                best = validList[i];
                bestDiff = diff;
            }
        }
        return best;
    }

    Process {
        id: monitorDetector
        running: false
        command: [
            "bash",
            "-c",
            displayTabRoot.compositor === "niri"
                ? "niri msg -j outputs 2>/dev/null"
                : (displayTabRoot.compositor === "sway"
                    ? "swaymsg -t get_outputs -r 2>/dev/null"
                    : (displayTabRoot.compositor === "mango"
                        ? "mmsg get all-monitors 2>/dev/null | jq -c '.monitors' 2>/dev/null"
                        : "hyprctl monitors all -j 2>/dev/null || hyprctl monitors -j 2>/dev/null"))
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text;
                if (!out) return;
                let mList = [];
                try {
                    let data = JSON.parse(out.trim());
                    if (displayTabRoot.compositor === "niri") {
                        let keys = Object.keys(data);
                        for (let i = 0; i < keys.length; i++) {
                            let k = keys[i];
                            let item = data[k];
                            let modeIdx = (item.current_mode !== undefined && item.current_mode !== null) ? item.current_mode : 0;
                            let modes = item.modes || [];
                            let m = modes[modeIdx] || modes[0] || {};
                            let w = m.width || 0;
                            let h = m.height || 0;
                            let rr = m.refresh_rate ? Math.round(m.refresh_rate / 1000) : 60;
                            let sc = item.scale !== undefined ? item.scale : 1.0;
                            let isOff = item.active === false || item.is_active === false || (modes.length > 0 && (item.current_mode === null || item.current_mode === undefined));
                            mList.push({
                                name: k,
                                dimensions: w + "x" + h,
                                framerate: rr.toString(),
                                scale: sc,
                                active: !isOff
                            });
                        }
                    } else if (displayTabRoot.compositor === "mango") {
                        if (Array.isArray(data)) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                mList.push({
                                    name: item.name || "",
                                    dimensions: (item.width || 0) + "x" + (item.height || 0),
                                    framerate: "60",
                                    scale: item.scale !== undefined ? item.scale : 1.0,
                                    active: item.active !== false
                                });
                            }
                        }
                    } else if (displayTabRoot.compositor === "sway") {
                        if (Array.isArray(data)) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                let name = item.name || "";
                                let cm = item.current_mode || {};
                                let w = cm.width || item.rect?.width || 0;
                                let h = cm.height || item.rect?.height || 0;
                                let rr = cm.refresh ? Math.round(cm.refresh / 1000) : 60;
                                let sc = item.scale !== undefined ? item.scale : 1.0;
                                let isOff = item.active === false;
                                mList.push({
                                    name: name,
                                    dimensions: w + "x" + h,
                                    framerate: rr.toString(),
                                    scale: sc,
                                    active: !isOff
                                });
                            }
                        }
                    } else {
                        if (Array.isArray(data)) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                let name = item.name || "";
                                let w = item.width || 0;
                                let h = item.height || 0;
                                let rr = item.refreshRate ? Math.round(item.refreshRate) : 60;
                                let sc = item.scale !== undefined ? item.scale : 1.0;
                                let isOff = item.disabled === true;
                                mList.push({
                                    name: name,
                                    dimensions: w + "x" + h,
                                    framerate: rr.toString(),
                                    scale: sc,
                                    active: !isOff
                                });
                            }
                        }
                    }
                } catch (e) {
                }
                if (mList.length > 0) {
                    displayTabRoot.monitorsList = mList;
                    displayTabRoot.refreshDisplaySettings();
                }
            }
        }
    }

    function reloadMonitors() {
        monitorDetector.running = false;
        monitorDetector.running = true;
    }

    function updateMonitorSetting(monName, key, value) {
        if (!monName) return;
        if (key === "enabled") {
            BlueLight.setEnabled(monName, value);
            displayTabRoot.refreshDisplaySettings();
            return;
        }
        if (key === "auto") {
            BlueLight.setAuto(monName, value);
            displayTabRoot.refreshDisplaySettings();
            return;
        }
        if (key === "temperature") {
            BlueLight.setTemperature(monName, value);
            displayTabRoot.refreshDisplaySettings();
            return;
        }

        let current = Config.getSetting("display", defaultDisplaySettings);
        if (!current.monitors) current.monitors = {};
        if (!current.monitors[monName]) current.monitors[monName] = {};

        current.monitors[monName][key] = value;
        Config.setSetting("display", current);
        displayTabRoot.displaySettings = JSON.parse(JSON.stringify(current));
    }

    function applyMonitorPower(monName, enabled) {
        if (!monName) return;
        if (displayTabRoot.compositor === "niri") {
            Quickshell.execDetached(["bash", "-c", enabled ? "niri msg output " + monName + " on" : "niri msg output " + monName + " off"]);
        } else if (displayTabRoot.compositor === "sway") {
            Quickshell.execDetached(["bash", "-c", "swaymsg output " + monName + (enabled ? " enable" : " disable")]);
        } else if (displayTabRoot.compositor === "mango") {
            Quickshell.execDetached(["mmsg", "dispatch", (enabled ? "wakeup_monitor," : "sleep_monitor,") + monName]);
        } else {
            let mon = displayTabRoot.monitorsList.find(m => m.name === monName);
            let modeStr = mon ? (mon.dimensions + "@" + mon.framerate) : "preferred";
            let scaleVal = mon ? mon.scale : 1.0;
            if (enabled) {
                let luaCmd =
                    'hl.monitor({' +
                    ' output = "' + monName + '",' +
                    ' mode = "' + modeStr + '",' +
                    ' position = "auto",' +
                    ' scale = ' + scaleVal.toString() + ',' +
                    ' disabled = false' +
                    ' })';
                Quickshell.execDetached(["bash", "-c", "hyprctl eval '" + luaCmd + "'"]);
            } else {
                let luaCmd =
                    'hl.monitor({ output = "' + monName + '", disabled = true })';
                Quickshell.execDetached(["bash", "-c", "hyprctl eval '" + luaCmd + "'"]);
            }
        }
    }

    function applyMonitorScale(monName, scaleVal) {
        if (!monName || !scaleVal) return;
        if (displayTabRoot.compositor === "niri") {
            Quickshell.execDetached(["bash", "-c", "niri msg output " + monName + " scale " + scaleVal.toString()]);
        } else if (displayTabRoot.compositor === "sway") {
            Quickshell.execDetached(["bash", "-c", "swaymsg output " + monName + " scale " + scaleVal.toString()]);
        } else if (displayTabRoot.compositor !== "mango") {
            let mon = displayTabRoot.monitorsList.find(m => m.name === monName);
            let modeStr = mon ? (mon.dimensions + "@" + mon.framerate) : "preferred";
            let luaCmd = 'hl.monitor({ output = "' + monName + '", mode = "' + modeStr + '", position = "auto", scale = ' + scaleVal.toString() + ' })';
            Quickshell.execDetached(["bash", "-c", "hyprctl eval '" + luaCmd + "' || hyprctl keyword monitor " + monName + "," + modeStr + ",auto," + scaleVal.toString()]);
        }
    }

    function updateMonitorSettingDebounced(monName, tempVal) {
        pendingMonName = monName;
        pendingMonTemp = tempVal;
        tempDebounceTimer.restart();
    }

    function flushMonitorSetting(monName) {
        tempDebounceTimer.stop();
        if (pendingMonName === monName) {
            let name = pendingMonName;
            let val = pendingMonTemp;
            pendingMonName = "";
            BlueLight.setTemperature(name, val);
            displayTabRoot.refreshDisplaySettings();
        }
    }

    Timer {
        id: tempDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (displayTabRoot.pendingMonName !== "") {
                let name = displayTabRoot.pendingMonName;
                let val = displayTabRoot.pendingMonTemp;
                displayTabRoot.pendingMonName = "";
                BlueLight.setTemperature(name, val);
                displayTabRoot.refreshDisplaySettings();
            }
        }
    }

    property alias scaleDebounceTimer: scaleDebounceTimer

    Timer {
        id: scaleDebounceTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (displayTabRoot.pendingMonScaleName !== "") {
                displayTabRoot.applyMonitorScale(displayTabRoot.pendingMonScaleName, displayTabRoot.pendingMonScaleVal);
                displayTabRoot.updateMonitorSetting(displayTabRoot.pendingMonScaleName, "scale", displayTabRoot.pendingMonScaleVal);
                displayTabRoot.pendingMonScaleName = "";
            }
        }
    }

    Timer {
        id: reloadMonitorsDebounceTimer
        interval: 220
        repeat: false
        onTriggered: displayTabRoot.reloadMonitors()
    }

    Component.onCompleted: {
        displayTabRoot.refreshDisplaySettings();
        if (visible) {
            reloadMonitorsDebounceTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            displayTabRoot.refreshDisplaySettings();
            reloadMonitorsDebounceTimer.restart();
        } else {
            reloadMonitorsDebounceTimer.stop();
        }
    }

    Connections {
        target: rootObj
        function onVisibleChanged() {
            if (rootObj && rootObj.visible && displayTabRoot.visible) {
                displayTabRoot.refreshDisplaySettings();
                displayTabRoot.reloadMonitors();
            }
        }
        function onCurrentTabChanged() {
            if (rootObj && rootObj.currentTab === displayTabRoot.tabIndex) {
                displayTabRoot.refreshDisplaySettings();
                displayTabRoot.reloadMonitors();
            }
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            displayTabRoot.refreshDisplaySettings();
            displayTabRoot.reloadMonitors();
        }
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            displayTabRoot.refreshDisplaySettings();
        }
    }

    Connections {
        target: typeof Location !== "undefined" ? Location : null
        function onLocationUpdated() {
            displayTabRoot.refreshDisplaySettings();
        }
    }

    Connections {
        target: typeof BlueLight !== "undefined" ? BlueLight : null
        ignoreUnknownSignals: true
        function onSettingsChanged() {
            displayTabRoot.refreshDisplaySettings();
        }
    }
}
