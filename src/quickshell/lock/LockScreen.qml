import QtQuick
import QtQuick.Window
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"

FocusScope {
    id: lockScreenRoot
    required property var surface
    required property var root
    required property var rootLock
    required property var pam
    required property var lockUI
    required property var suspendProcess
    required property var reloadProcess
    required property var poweroffProcess

    property alias passwordInput: dashboard.passwordInput
    property alias freezeWallpaperView: backdrop.freezeWallpaperView
    property alias idleTimer: idleTimer
    property alias introStartDelayTimer: introStartDelayTimer
    property alias introSequence: introSequence

    anchors.fill: parent
    focus: true

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
        z: -1
    }

    function s(val) {
        return Scaler.s(val);
    }

    readonly property var glassScreen: surface.screen
    property string safeScreenName: (surface.screen && surface.screen.name) ? surface.screen.name : (surface.output && surface.output.name ? surface.output.name : "")
    readonly property var lockSettings: Config.getSetting("lockscreen", {})
    readonly property string customBackgroundPath: lockSettings.customBackground ? String(lockSettings.customBackground) : ""
    readonly property bool customBackgroundActive: lockSettings.backgroundMode === "custom" && customBackgroundPath !== ""
    readonly property string desktopWallpaperPath: {
        Wallpaper.screenWallpaperPaths;
        return Wallpaper.getWallpaperPath(safeScreenName);
    }
    readonly property string backgroundPath: customBackgroundActive ? customBackgroundPath : desktopWallpaperPath
    readonly property bool backgroundIsVideo: isVideoPath(backgroundPath)

    function isVideoPath(path) {
        let lp = String(path || "").toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
    }

    property string wallpaperSource: {
        if (customBackgroundActive && !isVideoPath(customBackgroundPath)) {
            return "file://" + customBackgroundPath;
        }
        let cacheDir = Caching.getCacheDir("wallpaper");
        if (safeScreenName !== "" && safeScreenName !== "default") {
            return "file://" + cacheDir + "/current_wallpaper_" + safeScreenName + ".png";
        }
        return "file://" + cacheDir + "/current_wallpaper.png";
    }
    property string currentFreezePath: {
        if (root.freezeTimestamp === "") return "";
        let scrName = (safeScreenName !== "" && safeScreenName !== "default") ? safeScreenName : "default";
        return Caching.getRunDir("screenshot") + "/lock_freeze_" + scrName + "_" + root.freezeTimestamp + ".png";
    }

    property bool isUnlocking: root.isUnlocking
    property real foldScaleX: 1.0
    property real foldScaleY: 1.0

    property bool wingsEverNeeded: false

    onIsUnlockingChanged: {
        if (isUnlocking) {
            openDashboardAnim.stop();
            closeDashboardAnim.stop();
            unlockSequence.restart();
        } else {
            foldScaleX = 1.0;
            foldScaleY = 1.0;
            mainOpacity = 1.0;
        }
    }

    property string currentUser: SystemInfo.username !== "" ? SystemInfo.username : I18n.t("lock.default_user")
    property string faceIconPath: SystemInfo.avatarPath !== "" ? (SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath) : ""
    property string weatherIcon: Weather.currentIcon
    property string weatherTemp: Weather.currentTempFormatted

    property bool dndEnabled: {
        let n = Config.getSetting("notifications", { "dnd": false });
        return Boolean(n && n.dnd);
    }

    property var quoteData: (typeof Config !== "undefined" && typeof Config.getSetting === "function") ? Config.getSetting("quote", {}) : ({})
    property bool quoteEnabled: quoteData && quoteData.enabled !== false && quoteData.enabled !== undefined ? !!quoteData.enabled : true
    readonly property string defaultQuoteText: "The only way to do great work is to love what you do."
    property string quoteText: {
        let _lang = (typeof I18n !== "undefined") ? I18n.currentLang : "";
        let _ready = (typeof I18n !== "undefined") ? I18n.isReady : false;
        let customText = quoteData && quoteData.text !== undefined ? String(quoteData.text).trim() : "";
        if (customText !== "") return customText;
        return I18n.t("quote.default") || defaultQuoteText;
    }
    property string quoteLockPosition: (quoteData && quoteData.lockScreenPosition !== undefined) ? String(quoteData.lockScreenPosition) : "both"

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            lockScreenRoot.quoteData = Config.getSetting("quote", {});
        }
    }

    property var weatherFullData: Weather.data
    property var hourlyForecastList: []

    function formatHour(timeStr) {
        if (!timeStr) return "";
        let str = String(timeStr).trim();
        if (str.toLowerCase().indexOf("am") !== -1 || str.toLowerCase().indexOf("pm") !== -1) {
            return str;
        }
        let hour = 0;
        if (str.indexOf(":") !== -1) {
            hour = parseInt(str.split(":")[0], 10);
        } else {
            let num = parseInt(str, 10);
            if (!isNaN(num)) {
                hour = num >= 100 ? Math.floor(num / 100) : num;
            }
        }
        if (isNaN(hour)) return str;

        if (typeof DateTime !== "undefined" && DateTime.is12Hour) {
            let period = hour >= 12 ? "PM" : "AM";
            let h12 = hour % 12;
            if (h12 === 0) h12 = 12;
            return h12 + period;
        }

        return (hour < 10 ? "0" + hour : hour) + ":00";
    }

    function getFeelsLike() {
        let wData = Weather.data;
        if (!wData) return Weather.currentTemp !== "" ? Math.round(parseFloat(Weather.currentTemp)) + "°" : "--°";
        let fl = wData.current_feels_like ?? wData.feels_like ?? wData.current_feelslike;
        if (fl !== undefined && fl !== null && fl !== "") {
            return Math.round(parseFloat(fl)) + "°";
        }
        if (wData.forecast && wData.forecast[0]) {
            let f0 = wData.forecast[0];
            if (f0.feels_like !== undefined) return Math.round(parseFloat(f0.feels_like)) + "°";
            if (f0.hourly && f0.hourly[0] && f0.hourly[0].feels_like !== undefined) {
                return Math.round(parseFloat(f0.hourly[0].feels_like)) + "°";
            }
        }
        if (Weather.currentTemp !== "") {
            return Math.round(parseFloat(Weather.currentTemp)) + "°";
        }
        return "--°";
    }

    function updateForecastData() {
        let wData = Weather.data;
        if (!wData || !wData.forecast || !Array.isArray(wData.forecast) || wData.forecast.length === 0) {
            lockScreenRoot.hourlyForecastList = [];
            return;
        }

        let allHourly = [];
        for (let d = 0; d < wData.forecast.length; d++) {
            if (wData.forecast[d] && wData.forecast[d].hourly) {
                allHourly = allHourly.concat(wData.forecast[d].hourly);
            }
        }

        if (allHourly.length === 0) {
            lockScreenRoot.hourlyForecastList = [];
            return;
        }

        let ch = (typeof DateTime !== "undefined" && DateTime.now) ? DateTime.now.getHours() : new Date().getHours();
        let bestIdx = 0;
        let minDiff = 999;
        for (let i = 0; i < allHourly.length; i++) {
            let timeStr = allHourly[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0], 10);
            if (isNaN(h)) {
                let n = parseInt(timeStr, 10);
                h = n >= 100 ? Math.floor(n / 100) : n;
            }
            let diff = h - ch;
            if (diff >= 0 && diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }

        if (minDiff === 999) {
            for (let i = 0; i < allHourly.length; i++) {
                let timeStr = allHourly[i].time || "00:00";
                let h = parseInt(timeStr.split(":")[0], 10);
                if (isNaN(h)) {
                    let n = parseInt(timeStr, 10);
                    h = n >= 100 ? Math.floor(n / 100) : n;
                }
                let diff = Math.abs(h - ch);
                if (diff < minDiff) {
                    minDiff = diff;
                    bestIdx = i;
                }
            }
        }

        lockScreenRoot.hourlyForecastList = allHourly.slice(bestIdx, bestIdx + 4);
    }

    onWeatherFullDataChanged: updateForecastData()

    Connections {
        target: typeof DateTime !== "undefined" ? DateTime : null
        function onHourChanged() {
            lockScreenRoot.updateForecastData();
        }
    }

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

    function formatMusicTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    property bool powerMenuOpen: false
    property bool inputActive: false
    property bool isPlayingIntro: !root.staticLock

    property real centerReveal: 0.0
    property real wingsReveal: 0.0

    function restoreFocus() {
        if (!rootLock.locked || lockScreenRoot.isUnlocking) return;
        if (lockScreenRoot.inputActive) {
            if (!passwordInput.activeFocus) {
                lockScreenRoot.focus = true;
                lockScreenRoot.forceActiveFocus();
                passwordInput.focus = true;
                passwordInput.forceInputFocus();
            }
        } else {
            if (!lockScreenRoot.activeFocus) {
                lockScreenRoot.focus = true;
                lockScreenRoot.forceActiveFocus();
            }
        }
    }

    onActiveFocusChanged: {
        if (!activeFocus && rootLock.locked && !isUnlocking) {
            Qt.callLater(lockScreenRoot.restoreFocus);
        }
    }

    Keys.onPressed: (event) => {
        if (!lockScreenRoot.isPlayingIntro && !lockScreenRoot.isUnlocking) {
            if (!lockScreenRoot.inputActive) {
                if (event.key !== Qt.Key_Escape) {
                    lockScreenRoot.inputActive = true;
                    lockScreenRoot.restoreFocus();
                    if (event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace) {
                        passwordInput.insertText(event.text);
                    }
                    event.accepted = true;
                }
            } else {
                lockScreenRoot.restoreFocus();
                if (event.key === Qt.Key_Escape) {
                    if (lockScreenRoot.powerMenuOpen) {
                        lockScreenRoot.powerMenuOpen = false;
                    } else {
                        lockScreenRoot.inputActive = false;
                    }
                    passwordInput.clear();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (passwordInput.text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                        lockUI.authenticating = true;
                        lockUI.statusText = I18n.t("lock.status.authenticating");
                        lockUI.failed = false;
                        pam.respond(passwordInput.text);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                } else if (event.text.length > 0 && event.key !== Qt.Key_Backspace) {
                    passwordInput.insertText(event.text);
                    event.accepted = true;
                }
            }
        }
    }

    SequentialAnimation {
        id: openDashboardAnim
        running: false
        NumberAnimation {
            target: lockScreenRoot
            property: "centerReveal"
            to: 1.0
            duration: 180
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
        NumberAnimation {
            target: lockScreenRoot
            property: "wingsReveal"
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
        }
    }

    ParallelAnimation {
        id: closeDashboardAnim
        running: false
        NumberAnimation {
            target: lockScreenRoot
            property: "wingsReveal"
            to: 0.0
            duration: 110
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: lockScreenRoot
            property: "centerReveal"
            to: 0.0
            duration: 100
            easing.type: Easing.InQuad
        }
    }

    SequentialAnimation {
        id: unlockSequence
        running: false

        ScriptAction {
            script: {
                lockScreenRoot.powerMenuOpen = false;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: lockScreenRoot
                property: "wingsReveal"
                to: 0.0
                duration: 130
                easing.type: Easing.InQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: lockScreenRoot
                property: "foldScaleX"
                to: 0.0
                duration: 220
                easing.type: Easing.InBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "foldScaleY"
                to: 0.0
                duration: 220
                easing.type: Easing.InBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "centerReveal"
                to: 0.0
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "contentReveal"
                to: 0.0
                duration: 220
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "panelReveal"
                to: 0.0
                duration: 250
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "mainOpacity"
                to: 0.0
                duration: 250
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: {
                root.completeUnlock();
            }
        }
    }

    onInputActiveChanged: {
        if (lockScreenRoot.isUnlocking) return;
        if (inputActive) {
            closeDashboardAnim.stop();
            openDashboardAnim.restart();
            lockScreenRoot.restoreFocus();
        } else {
            openDashboardAnim.stop();
            closeDashboardAnim.restart();
            powerMenuOpen = false;
            lockScreenRoot.restoreFocus();
        }
    }

    property real panelReveal: root.staticLock ? 1.0 : 0.0
    property real contentReveal: root.staticLock ? 1.0 : 0.0
    property real mainOpacity: 1.0

    property bool isSysSubscribed: false
    property bool isCavaSubscribed: false
    function updateSysSubscription() {
        if (lockScreenRoot.wingsReveal > 0.98 && !isSysSubscribed) {
            SysData.subscribe();
            isSysSubscribed = true;
        } else if (lockScreenRoot.wingsReveal <= 0.98 && isSysSubscribed) {
            SysData.unsubscribe();
            isSysSubscribed = false;
        }
    }

    function updateCavaConsumer() {
        let shouldSubscribe = lockScreenRoot.wingsReveal > 0.98;
        if (shouldSubscribe && !lockScreenRoot.isCavaSubscribed) {
            Cava.registerConsumer();
            lockScreenRoot.isCavaSubscribed = true;
        } else if (!shouldSubscribe && lockScreenRoot.isCavaSubscribed) {
            Cava.unregisterConsumer();
            lockScreenRoot.isCavaSubscribed = false;
        }
    }

    onWingsRevealChanged: {
        if (wingsReveal > 0 && !wingsEverNeeded) wingsEverNeeded = true;
        updateSysSubscription();
        updateCavaConsumer();
    }


    property real rawCpu: isNaN(SysData.cpu) ? 0.0 : SysData.cpu / 100.0
    property real cpuUsage: rawCpu
    Behavior on cpuUsage { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawTemp: isNaN(SysData.temp) ? 0.0 : SysData.temp
    property real tempC: rawTemp
    Behavior on tempC { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRam: isNaN(SysData.ramPercent) ? 0.0 : SysData.ramPercent / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(SysData.ramGb) ? 0.0 : SysData.ramGb
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property real netRx: isNaN(SysData.netRx) ? 0 : SysData.netRx
    Behavior on netRx { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
    property real netTx: isNaN(SysData.netTx) ? 0 : SysData.netTx
    Behavior on netTx { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
    function formatBytes(bytes) {
        if (!(bytes >= 1)) return "0 B/s";
        let k = 1024, sizes = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = Math.min(sizes.length - 1, Math.floor(Math.log(bytes) / Math.log(k)));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
    }
    property string rxSpeedStr: formatBytes(netRx)
    property string txSpeedStr: formatBytes(netTx)

    property real rawDisk: isNaN(SysData.diskPercent) ? 0.0 : SysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: lockScreenRoot.wingsReveal > 0.98; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    property string diskUsedText: SysData.diskGb > 0 ? (SysData.diskGb.toFixed(1) + "G") : "..."
    property string diskTotalText: SysData.diskTotalGb > 0 ? (SysData.diskTotalGb.toFixed(1) + "G") : ""

    Timer {
        id: introStartDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (lockScreenRoot.isPlayingIntro && !introSequence.running) {
                introSequence.start();
            }
        }
    }

    Component.onCompleted: {
        lockScreenRoot.updateForecastData();
        lockScreenRoot.restoreFocus();
        if (freezeWallpaperView.status === Image.Ready) {
            introSequence.start();
        } else {
            introStartDelayTimer.start();
        }
    }

    Component.onDestruction: {
        if (lockScreenRoot.isCavaSubscribed) {
            Cava.unregisterConsumer();
            lockScreenRoot.isCavaSubscribed = false;
        }
        if (isSysSubscribed) {
            SysData.unsubscribe();
            isSysSubscribed = false;
        }
    }

    Connections {
        target: rootLock
        function onLockedChanged() {
            if (rootLock.locked) {
                lockScreenRoot.restoreFocus();
            }
        }
    }

    Connections {
        target: surface
        function onVisibleChanged() {
            if (surface.visible && rootLock.locked && !lockScreenRoot.isUnlocking) {
                lockScreenRoot.restoreFocus();
            }
        }
    }

    Connections {
        target: root
        function onResumeRevisionChanged() {
            if (rootLock.locked && !lockScreenRoot.isUnlocking) {
                lockScreenRoot.restoreFocus();
                if (typeof clockModule !== "undefined") {
                    clockModule.currentTime = (typeof DateTime !== "undefined" && DateTime.now) ? DateTime.now : new Date();
                }
            }
        }
    }

    Timer {
        id: idleTimer
        interval: 15000
        running: lockScreenRoot.inputActive && passwordInput.text.length === 0
        repeat: false
        onTriggered: {
            lockScreenRoot.inputActive = false;
            lockScreenRoot.restoreFocus();
        }
    }

    LockBackdrop {
        id: backdrop
        screenRoot: lockScreenRoot
    }

    SequentialAnimation {
        id: introSequence

        ParallelAnimation {
            NumberAnimation {
                target: lockScreenRoot
                property: "panelReveal"
                from: 0.0
                to: 1.0
                duration: 750
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation { duration: 200 }
                NumberAnimation {
                    target: lockScreenRoot
                    property: "contentReveal"
                    from: 0.0
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        PropertyAction { target: lockScreenRoot; property: "isPlayingIntro"; value: false }
        ScriptAction {
            script: {
                lockScreenRoot.restoreFocus();
            }
        }
    }

    Item {
        id: rootContent
        anchors.fill: parent
        z: 20
        opacity: lockScreenRoot.mainOpacity

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            enabled: !lockScreenRoot.isPlayingIntro && !lockScreenRoot.isUnlocking
            onPressed: {
                lockScreenRoot.restoreFocus();
            }
            onClicked: {
                if (lockScreenRoot.powerMenuOpen) lockScreenRoot.powerMenuOpen = false;
                if (!lockScreenRoot.inputActive) {
                    lockScreenRoot.inputActive = true;
                }
                lockScreenRoot.restoreFocus();
            }
        }

        Item {
            anchors.fill: parent
            opacity: lockScreenRoot.contentReveal
            transform: Translate { y: lockScreenRoot.s(20) * (1.0 - lockScreenRoot.contentReveal) }


            LockClock {
                id: clockModule
                screenRoot: lockScreenRoot
            }

            LockDashboard {
                id: dashboard
                screenRoot: lockScreenRoot
            }

            LockPowerControls {
                screenRoot: lockScreenRoot
            }
    }
    }
}
