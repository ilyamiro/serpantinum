import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: displayTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property var defaultDisplaySettings: ({
        "monitors": {}
    })

    property var displaySettings: JSON.parse(JSON.stringify(Config.getSetting("display", defaultDisplaySettings)))
    property var monitorsList: []

    readonly property string compositor: DisplayManager.compositor

    property string pendingMonName: ""
    property real pendingMonTemp: 50

    property string pendingModeName: ""
    property var pendingModeData: null

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

    function formatRate(rv) {
        let n = Number(rv);
        if (isNaN(n)) return "60";
        let s = n.toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        return s === "" ? "0" : s;
    }

    function normalizeRates(rates) {
        let seen = {};
        let out = [];
        for (let i = 0; i < rates.length; i++) {
            let r = rates[i];
            if (!r || isNaN(r.rate)) continue;
            let key = Number(r.rate).toFixed(2);
            if (seen[key]) continue;
            seen[key] = true;
            out.push({ rate: Number(r.rate), mode: r.mode });
        }
        out.sort((a, b) => a.rate - b.rate);
        return out;
    }

    function nearestRateIndex(validRates, target) {
        if (!validRates || validRates.length === 0) return 0;
        let best = 0;
        let bestDiff = Math.abs(validRates[0].rate - target);
        for (let i = 1; i < validRates.length; i++) {
            let diff = Math.abs(validRates[i].rate - target);
            if (diff < bestDiff) {
                best = i;
                bestDiff = diff;
            }
        }
        return best;
    }

    function buildResolutions(pairs) {
        let map = {};
        for (let i = 0; i < pairs.length; i++) {
            let p = pairs[i];
            if (!p || !p.width || !p.height || isNaN(p.rate)) continue;
            let key = p.width + "x" + p.height;
            if (!map[key]) map[key] = { width: p.width, height: p.height, rates: [] };
            map[key].rates.push({ rate: p.rate, mode: p.mode });
        }
        let out = [];
        let keys = Object.keys(map);
        for (let j = 0; j < keys.length; j++) {
            let res = map[keys[j]];
            res.rates = displayTabRoot.normalizeRates(res.rates);
            if (res.rates.length > 0) out.push(res);
        }
        out.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.width - a.width));
        return out;
    }

    function ratesForResolution(resolutions, width, height) {
        for (let i = 0; i < resolutions.length; i++) {
            if (resolutions[i].width === width && resolutions[i].height === height) {
                return resolutions[i].rates;
            }
        }
        return [];
    }

    function queueModeApply(monName, data) {
        if (!monName || !data) return;
        pendingModeName = monName;
        pendingModeData = data;
        modeDebounceTimer.restart();
    }

    function persistMode(monName, data) {
        if (!monName || !data) return;
        let current = Config.getSetting("display", defaultDisplaySettings);
        if (!current.monitors) current.monitors = {};
        if (!current.monitors[monName]) current.monitors[monName] = {};
        let m = current.monitors[monName];
        if (data.mode !== undefined && data.mode !== "") m.mode = data.mode;
        if (data.resolution !== undefined) m.resolution = data.resolution;
        if (data.rate !== undefined && data.rate !== null) m.refreshRate = data.rate;
        if (data.scale !== undefined && data.scale !== null) m.scale = data.scale;
        Config.setSetting("display", current);
        displayTabRoot.displaySettings = JSON.parse(JSON.stringify(current));
    }

    function flushModeApply(monName) {
        modeDebounceTimer.stop();
        if (pendingModeName === monName && pendingModeData) {
            let name = pendingModeName;
            let data = pendingModeData;
            pendingModeName = "";
            pendingModeData = null;
            DisplayManager.applyMode(name, data.mode, data.scale);
            displayTabRoot.persistMode(name, data);
        }
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
                    : "hyprctl monitors all -j 2>/dev/null || hyprctl monitors -j 2>/dev/null")
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
                            let rr = m.refresh_rate ? (m.refresh_rate / 1000) : 60;
                            let sc = item.scale !== undefined ? item.scale : 1.0;
                            let isOff = item.active === false || item.is_active === false || (modes.length > 0 && (item.current_mode === null || item.current_mode === undefined));
                            let pairs = [];
                            for (let j = 0; j < modes.length; j++) {
                                let mo = modes[j];
                                if (!mo || !mo.width || !mo.height) continue;
                                let rv = (mo.refresh_rate || 60000) / 1000;
                                pairs.push({ width: mo.width, height: mo.height, rate: rv, mode: mo.width + "x" + mo.height + "@" + displayTabRoot.formatRate(rv) });
                            }
                            if (w > 0 && h > 0) {
                                pairs.push({ width: w, height: h, rate: rr, mode: w + "x" + h + "@" + displayTabRoot.formatRate(rr) });
                            }
                            let resolutions = displayTabRoot.buildResolutions(pairs);
                            let rates = displayTabRoot.ratesForResolution(resolutions, w, h);
                            mList.push({
                                name: k,
                                dimensions: w + "x" + h,
                                framerate: Math.round(rr).toString(),
                                refreshRate: rr,
                                resolutions: resolutions,
                                refreshRates: rates,
                                scale: sc,
                                active: !isOff
                            });
                        }
                    } else if (displayTabRoot.compositor === "sway") {
                        if (Array.isArray(data)) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                let name = item.name || "";
                                let cm = item.current_mode || {};
                                let w = cm.width || item.rect?.width || 0;
                                let h = cm.height || item.rect?.height || 0;
                                let rr = cm.refresh ? (cm.refresh / 1000) : 60;
                                let sc = item.scale !== undefined ? item.scale : 1.0;
                                let isOff = item.active === false;
                                let pairs = [];
                                let modes = item.modes || [];
                                for (let j = 0; j < modes.length; j++) {
                                    let mo = modes[j];
                                    if (!mo || !mo.width || !mo.height) continue;
                                    let rv = (mo.refresh || 60000) / 1000;
                                    pairs.push({ width: mo.width, height: mo.height, rate: rv, mode: mo.width + "x" + mo.height + "@" + displayTabRoot.formatRate(rv) + "Hz" });
                                }
                                if (w > 0 && h > 0) {
                                    pairs.push({ width: w, height: h, rate: rr, mode: w + "x" + h + "@" + displayTabRoot.formatRate(rr) + "Hz" });
                                }
                                let resolutions = displayTabRoot.buildResolutions(pairs);
                                let rates = displayTabRoot.ratesForResolution(resolutions, w, h);
                                mList.push({
                                    name: name,
                                    dimensions: w + "x" + h,
                                    framerate: Math.round(rr).toString(),
                                    refreshRate: rr,
                                    resolutions: resolutions,
                                    refreshRates: rates,
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
                                let rr = item.refreshRate ? item.refreshRate : 60;
                                let sc = item.scale !== undefined ? item.scale : 1.0;
                                let isOff = item.disabled === true;
                                let pairs = [];
                                let modes = item.availableModes || [];
                                for (let j = 0; j < modes.length; j++) {
                                    let mm = /^(\d+)x(\d+)@([\d.]+)(?:Hz)?$/.exec(modes[j]);
                                    if (!mm) continue;
                                    pairs.push({ width: parseInt(mm[1]), height: parseInt(mm[2]), rate: parseFloat(mm[3]), mode: mm[1] + "x" + mm[2] + "@" + mm[3] });
                                }
                                if (w > 0 && h > 0) {
                                    pairs.push({ width: w, height: h, rate: rr, mode: w + "x" + h + "@" + displayTabRoot.formatRate(rr) });
                                }
                                let resolutions = displayTabRoot.buildResolutions(pairs);
                                let rates = displayTabRoot.ratesForResolution(resolutions, w, h);
                                mList.push({
                                    name: name,
                                    dimensions: w + "x" + h,
                                    framerate: Math.round(rr).toString(),
                                    refreshRate: rr,
                                    resolutions: resolutions,
                                    refreshRates: rates,
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
        let mon = displayTabRoot.monitorsList.find(m => m.name === monName);
        let modeStr = mon ? (mon.dimensions + "@" + mon.framerate) : "";
        let scaleVal = mon ? mon.scale : 1.0;
        DisplayManager.applyPower(monName, enabled, modeStr, scaleVal);
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

    Timer {
        id: modeDebounceTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (displayTabRoot.pendingModeName !== "" && displayTabRoot.pendingModeData) {
                let name = displayTabRoot.pendingModeName;
                let data = displayTabRoot.pendingModeData;
                displayTabRoot.pendingModeName = "";
                displayTabRoot.pendingModeData = null;
                DisplayManager.applyMode(name, data.mode, data.scale);
                displayTabRoot.persistMode(name, data);
            }
        }
    }

    Component.onCompleted: {
        displayTabRoot.refreshDisplaySettings();
        displayTabRoot.reloadMonitors();
    }

    onVisibleChanged: {
        if (visible) {
            displayTabRoot.refreshDisplaySettings();
            displayTabRoot.reloadMonitors();
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

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(12)

            Repeater {
                model: displayTabRoot.monitorsList
                delegate: Rectangle {
                    id: monDelegate
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    clip: true
                    radius: ThemeBackend.borderRadius

                    property string monName: modelData.name
                    property var monSettings: (displayTabRoot.displaySettings && displayTabRoot.displaySettings.monitors && displayTabRoot.displaySettings.monitors[monName]) ? displayTabRoot.displaySettings.monitors[monName] : ({})

                    property bool monitorPowered: monSettings.powerEnabled !== undefined ? monSettings.powerEnabled : (modelData.active !== undefined ? modelData.active : true)
                    property bool filterEnabled: monSettings.enabled !== undefined ? monSettings.enabled : false
                    property bool filterAuto: monSettings.auto !== undefined ? monSettings.auto : false
                    property real currentTemp: monSettings.temperature !== undefined ? monSettings.temperature : 50
                    property real currentScale: modelData.scale !== undefined ? modelData.scale : 1.0

                    color: monitorPowered ? Qt.alpha(ThemeBackend.surface0, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface0, 0.4), 1.1)
                    border.color: monitorPowered ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface1, 0.4), 1.1)
                    border.width: 1

                    property real targetHeight: boxLayout.implicitHeight + rootObj.s(24)
                    property bool appeared: false

                    implicitHeight: appeared ? targetHeight : 0
                    opacity: appeared ? 1.0 : 0.0

                    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }

                    Component.onCompleted: {
                        appeared = true;
                        syncResIndexFromModel();
                    }

                    property var resDims: modelData.dimensions ? modelData.dimensions.split("x") : ["1920", "1080"]
                    property int monWidth: parseInt(resDims[0]) || 1920
                    property int monHeight: parseInt(resDims[1]) || 1080
                    property var validScales: displayTabRoot.validScalesForResolution(monWidth, monHeight)
                    readonly property int currentScaleIndex: {
                        let i = validScales.indexOf(currentScale);
                        if (i >= 0) return i;
                        let nearest = displayTabRoot.nearestValidScaleFromList(validScales, currentScale);
                        let ni = validScales.indexOf(nearest);
                        return ni >= 0 ? ni : 0;
                    }

                    property var resList: {
                        if (modelData.resolutions !== undefined && modelData.resolutions.length > 0) return modelData.resolutions;
                        if (modelData.dimensions) {
                            return [{ width: monWidth, height: monHeight, rates: modelData.refreshRates || [] }];
                        }
                        return [];
                    }
                    readonly property var resOptions: resList.map(function(r) { return r.width + " × " + r.height; })
                    property int currentResIndex: 0
                    readonly property var currentRes: (currentResIndex >= 0 && currentResIndex < resList.length) ? resList[currentResIndex] : null
                    property var validRates: currentRes ? currentRes.rates : (modelData.refreshRates !== undefined ? modelData.refreshRates : [])
                    property real currentRate: modelData.refreshRate !== undefined ? modelData.refreshRate : (parseFloat(modelData.framerate) || 60)
                    readonly property int currentRateIndex: displayTabRoot.nearestRateIndex(validRates, currentRate)
                    readonly property string currentResolution: currentRes ? (currentRes.width + "x" + currentRes.height) : (modelData.dimensions || "")
                    readonly property string resolutionDisplay: currentResolution !== "" ? currentResolution.split("x").join(" × ") : ""
                    readonly property string currentModeStr: {
                        let d = validRates[currentRateIndex];
                        return d ? d.mode : "";
                    }

                    function syncResIndexFromModel() {
                        if (!modelData.dimensions) return;
                        let p = modelData.dimensions.split("x");
                        let w = parseInt(p[0]);
                        let h = parseInt(p[1]);
                        for (let i = 0; i < resList.length; i++) {
                            if (resList[i].width === w && resList[i].height === h) {
                                currentResIndex = i;
                                return;
                            }
                        }
                    }

                    onMonSettingsChanged: {
                        if (monSettings.powerEnabled !== undefined) {
                            monitorPowered = monSettings.powerEnabled;
                        }
                        filterEnabled = monSettings.enabled !== undefined ? monSettings.enabled : false;
                        filterAuto = monSettings.auto !== undefined ? monSettings.auto : false;
                        if (displayTabRoot.pendingMonName !== monName && !temperatureSlider.pressed) {
                            currentTemp = monSettings.temperature !== undefined ? monSettings.temperature : 50;
                        }
                    }

                    onModelDataChanged: {
                        if (monSettings.powerEnabled === undefined && modelData.active !== undefined) {
                            monitorPowered = modelData.active;
                        }
                        if (displayTabRoot.pendingModeName !== monName) {
                            currentScale = modelData.scale !== undefined ? modelData.scale : 1.0;
                            currentRate = modelData.refreshRate !== undefined ? modelData.refreshRate : (parseFloat(modelData.framerate) || 60);
                            syncResIndexFromModel();
                        }
                    }

                    ColumnLayout {
                        id: boxLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: rootObj.s(12)
                        spacing: rootObj.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: rootObj.s(6)
                            Layout.leftMargin: rootObj.s(4)
                            Layout.rightMargin: rootObj.s(4)
                            spacing: rootObj.s(8)

                            Text {
                                text: modelData.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(16)
                                font.bold: true
                                color: ThemeBackend.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: monDelegate.resolutionDisplay + " • " + Math.round(monDelegate.currentRate) + "Hz"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Rectangle {
                            visible: displayTabRoot.monitorsList.length > 1
                            Layout.fillWidth: true
                            implicitHeight: rowPowerToggleLayout.implicitHeight + rootObj.s(24)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowPowerToggleLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰐥"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.enable.title", "Enable Monitor")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.enable.desc", "Turn display output on or off")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Toggle {
                                    id: powerToggle
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: monDelegate.monitorPowered
                                    accentColor: ThemeBackend.mauve
                                    baseColor: ThemeBackend.surface1
                                    handleColor: ThemeBackend.crust
                                    handleOffColor: ThemeBackend.text
                                    onToggled: function(c) {
                                        monDelegate.monitorPowered = c;
                                        displayTabRoot.updateMonitorSetting(monDelegate.monName, "powerEnabled", c);
                                        displayTabRoot.applyMonitorPower(monDelegate.monName, c);
                                    }

                                    Binding {
                                        target: powerToggle
                                        property: "checked"
                                        value: monDelegate.monitorPowered
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowToggleLayout.implicitHeight + rootObj.s(24)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowToggleLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰖔"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.bluelight.title")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.bluelight.desc")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Toggle {
                                    id: filterToggle
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: monDelegate.filterEnabled
                                    accentColor: ThemeBackend.mauve
                                    baseColor: ThemeBackend.surface1
                                    handleColor: ThemeBackend.crust
                                    handleOffColor: ThemeBackend.text
                                    onToggled: function(c) {
                                        monDelegate.filterEnabled = c;
                                        BlueLight.setEnabled(monDelegate.monName, c);
                                        displayTabRoot.refreshDisplaySettings();
                                    }

                                    Binding {
                                        target: filterToggle
                                        property: "checked"
                                        value: monDelegate.filterEnabled
                                    }
                                }
                            }
                        }

                        Item {
                            id: bluelightSectionWrapper
                            Layout.fillWidth: true
                            property bool isOpen: monDelegate.filterEnabled
                            clip: true
                            visible: implicitHeight > 0
                            opacity: isOpen ? 1.0 : 0.0
                            implicitHeight: isOpen ? bluelightInnerCol.implicitHeight : 0

                            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                            ColumnLayout {
                                id: bluelightInnerCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: rootObj.s(6)

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: rowAutoLayout.implicitHeight + rootObj.s(24)
                                    radius: ThemeBackend.borderRadius
                                    color: Qt.alpha(ThemeBackend.surface1, 0.35)
                                    border.width: 0

                                    RowLayout {
                                        id: rowAutoLayout
                                        anchors.left: parent.left
                                        anchors.leftMargin: rootObj.s(14)
                                        anchors.right: parent.right
                                        anchors.rightMargin: rootObj.s(14)
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: rootObj.s(12)

                                        IconButton {
                                            enabled: false
                                            size: rootObj.s(32)
                                            Layout.preferredWidth: rootObj.s(32)
                                            Layout.preferredHeight: rootObj.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰥔"
                                            iconFontSize: rootObj.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: rootObj.s(2)

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.t("guide.display.schedule.title")
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(13)
                                                color: ThemeBackend.text
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.t("guide.display.schedule.desc") + " " + displayTabRoot.scheduleDescription
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(11)
                                                color: ThemeBackend.subtext0
                                            }
                                        }

                                        Toggle {
                                            id: autoToggle
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            checked: monDelegate.filterAuto
                                            accentColor: ThemeBackend.mauve
                                            baseColor: ThemeBackend.surface1
                                            handleColor: ThemeBackend.crust
                                            handleOffColor: ThemeBackend.text
                                            onToggled: function(c) {
                                                monDelegate.filterAuto = c;
                                                BlueLight.setAuto(monDelegate.monName, c);
                                                displayTabRoot.refreshDisplaySettings();
                                            }

                                            Binding {
                                                target: autoToggle
                                                property: "checked"
                                                value: monDelegate.filterAuto
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: tempSectionWrapper
                                    Layout.fillWidth: true
                                    property bool isOpen: !monDelegate.filterAuto
                                    clip: true
                                    visible: implicitHeight > 0
                                    opacity: isOpen ? 1.0 : 0.0
                                    implicitHeight: isOpen ? tempInnerBox.implicitHeight : 0

                                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                                    Rectangle {
                                        id: tempInnerBox
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        implicitHeight: rowTempLayout.implicitHeight + rootObj.s(24)
                                        radius: ThemeBackend.borderRadius
                                        color: Qt.alpha(ThemeBackend.surface1, 0.35)
                                        border.width: 0

                                        RowLayout {
                                            id: rowTempLayout
                                            anchors.left: parent.left
                                            anchors.leftMargin: rootObj.s(14)
                                            anchors.right: parent.right
                                            anchors.rightMargin: rootObj.s(14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: rootObj.s(12)

                                            IconButton {
                                                enabled: false
                                                size: rootObj.s(32)
                                                Layout.preferredWidth: rootObj.s(32)
                                                Layout.preferredHeight: rootObj.s(32)
                                                Layout.alignment: Qt.AlignVCenter
                                                cornerRadius: ThemeBackend.borderRadius
                                                buttonIcon: "󰔏"
                                                iconFontSize: rootObj.s(16)
                                                accentColor: ThemeBackend.surface0
                                                textColor: "#ffffff"
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: rootObj.s(2)

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: I18n.t("guide.display.temperature.title")
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: rootObj.s(13)
                                                    color: ThemeBackend.text
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: I18n.t("guide.display.temperature.desc")
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: rootObj.s(11)
                                                    color: ThemeBackend.subtext0
                                                }
                                            }

                                            RowLayout {
                                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                                spacing: rootObj.s(12)
                                                Layout.rightMargin: rootObj.s(8)

                                                Draggable {
                                                    id: temperatureSlider
                                                    implicitWidth: rootObj.s(220)
                                                    implicitHeight: rootObj.s(18)
                                                    from: 0
                                                    to: 100
                                                    stepSize: 1
                                                    defaultValue: 50
                                                    showValueBubble: true
                                                    valueFormatter: function(v) { return Math.round(v).toString() }
                                                    value: monDelegate.currentTemp
                                                    backgroundColor: ThemeBackend.surface0
                                                    accentColor: ThemeBackend.mauve
                                                    handleColor: ThemeBackend.text
                                                    handleBorderColor: ThemeBackend.mantle
                                                    onMoved: function(val) {
                                                        let rounded = Math.round(val);
                                                        if (monDelegate.currentTemp !== rounded) {
                                                            monDelegate.currentTemp = rounded;
                                                            displayTabRoot.updateMonitorSettingDebounced(monDelegate.monName, rounded);
                                                        }
                                                    }
                                                    onDragFinished: {
                                                        displayTabRoot.flushMonitorSetting(monDelegate.monName);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowResolutionLayout.implicitHeight + rootObj.s(24)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowResolutionLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰍹"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.resolution.title")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.resolution.desc")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                Dropdown {
                                    id: resolutionDropdown
                                    Layout.preferredWidth: rootObj.s(150)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    options: monDelegate.resOptions
                                    currentIndex: monDelegate.currentResIndex
                                    enabled: monDelegate.resOptions.length > 1
                                    fontFamily: ThemeBackend.fontFamily
                                    fontPixelSize: rootObj.s(11)
                                    accentColor: ThemeBackend.mauve
                                    baseColor: ThemeBackend.surface0
                                    hoverColor: Qt.alpha(ThemeBackend.surface1, 0.6)
                                    dropdownColor: ThemeBackend.surface0
                                    borderColor: Qt.alpha(ThemeBackend.surface1, 0.5)
                                    textColor: ThemeBackend.text
                                    activeTextColor: ThemeBackend.crust
                                    subTextColor: ThemeBackend.subtext0
                                    onSelected: function(index, value) {
                                        if (index === monDelegate.currentResIndex) return;
                                        if (index < 0 || index >= monDelegate.resList.length) return;
                                        monDelegate.currentResIndex = index;
                                        let res = monDelegate.resList[index];
                                        let rates = (res && res.rates) ? res.rates : [];
                                        let chosen = rates.length > 0 ? rates[displayTabRoot.nearestRateIndex(rates, monDelegate.currentRate)] : null;
                                        if (chosen) {
                                            monDelegate.currentRate = chosen.rate;
                                            displayTabRoot.queueModeApply(monDelegate.monName, {
                                                mode: chosen.mode,
                                                rate: chosen.rate,
                                                resolution: res.width + "x" + res.height,
                                                scale: monDelegate.currentScale
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowRefreshLayout.implicitHeight + rootObj.s(24)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowRefreshLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰑓"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.refreshrate.title")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.refreshrate.desc")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    spacing: rootObj.s(4)

                                    LoaderIcon {
                                        id: refreshLoader
                                        Layout.preferredWidth: rootObj.s(32)
                                        Layout.preferredHeight: rootObj.s(32)
                                        Layout.alignment: Qt.AlignVCenter
                                        running: modeDebounceTimer.running && displayTabRoot.pendingModeName === monDelegate.monName
                                        accentColor: ThemeBackend.mauve
                                    }

                                    Draggable {
                                        id: refreshRateSlider
                                        implicitWidth: rootObj.s(220)
                                        implicitHeight: rootObj.s(18)
                                        enabled: monDelegate.validRates.length > 1
                                        from: 0
                                        to: Math.max(0, monDelegate.validRates.length - 1)
                                        stepSize: 1
                                        defaultValue: Math.max(0, monDelegate.validRates.length - 1)
                                        showValueBubble: true
                                        showTooltip: true
                                        alwaysShowHandle: false
                                        valueFormatter: function(idx) {
                                            let i = Math.round(idx);
                                            let data = monDelegate.validRates[i];
                                            let r = data ? data.rate : monDelegate.currentRate;
                                            return Math.round(r) + " Hz";
                                        }
                                        value: monDelegate.currentRateIndex
                                        backgroundColor: ThemeBackend.surface0
                                        accentColor: ThemeBackend.mauve
                                        handleColor: ThemeBackend.text
                                        handleBorderColor: ThemeBackend.mantle
                                        onMoved: function(idx) {
                                            let i = Math.round(idx);
                                            let data = monDelegate.validRates[i];
                                            if (data && Math.abs(monDelegate.currentRate - data.rate) > 0.01) {
                                                monDelegate.currentRate = data.rate;
                                                displayTabRoot.queueModeApply(monDelegate.monName, {
                                                    mode: data.mode,
                                                    rate: data.rate,
                                                    resolution: monDelegate.currentResolution,
                                                    scale: monDelegate.currentScale
                                                });
                                            }
                                        }
                                        onDragFinished: {
                                            displayTabRoot.flushModeApply(monDelegate.monName);
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowScaleLayout.implicitHeight + rootObj.s(24)
                            radius: ThemeBackend.borderRadius
                            color: Qt.alpha(ThemeBackend.surface1, 0.35)
                            border.width: 0

                            RowLayout {
                                id: rowScaleLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰍍"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.uiscale.title")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.display.uiscale.desc")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    spacing: rootObj.s(4)

                                    LoaderIcon {
                                        id: scaleLoader
                                        Layout.preferredWidth: rootObj.s(32)
                                        Layout.preferredHeight: rootObj.s(32)
                                        Layout.alignment: Qt.AlignVCenter
                                        running: modeDebounceTimer.running && displayTabRoot.pendingModeName === monDelegate.monName
                                        accentColor: ThemeBackend.mauve
                                    }

                                    Draggable {
                                        id: uiScaleSlider
                                        implicitWidth: rootObj.s(220)
                                        implicitHeight: rootObj.s(18)
                                        from: 0
                                        to: Math.max(0, monDelegate.validScales.length - 1)
                                        stepSize: 1
                                        defaultValue: monDelegate.validScales.indexOf(1.0) >= 0 ? monDelegate.validScales.indexOf(1.0) : 0
                                        showValueBubble: true
                                        showTooltip: true
                                        alwaysShowHandle: false
                                        valueFormatter: function(idx) {
                                            let i = Math.round(idx);
                                            let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                                            return s.toFixed(3).replace(/0+$/,'').replace(/\.$/,'.0');
                                        }
                                        value: monDelegate.currentScaleIndex
                                        backgroundColor: ThemeBackend.surface0
                                        accentColor: ThemeBackend.mauve
                                        handleColor: ThemeBackend.text
                                        handleBorderColor: ThemeBackend.mantle
                                        onMoved: function(idx) {
                                            let i = Math.round(idx);
                                            let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                                            if (monDelegate.currentScale !== s) {
                                                monDelegate.currentScale = s;
                                                displayTabRoot.queueModeApply(monDelegate.monName, {
                                                    mode: monDelegate.currentModeStr,
                                                    rate: monDelegate.currentRate,
                                                    resolution: monDelegate.currentResolution,
                                                    scale: s
                                                });
                                            }
                                        }
                                        onDragFinished: {
                                            displayTabRoot.flushModeApply(monDelegate.monName);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
