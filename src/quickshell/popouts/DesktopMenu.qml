import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

PanelWindow {
    id: desktopMenuWindow

    screen: DesktopMenuController.screen

    WlrLayershell.namespace: "desktopmenu"
    WlrLayershell.layer: WlrLayer.Bottom
    focusable: desktopMenuWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    onIsVisibleChanged: {
        if (isVisible) {
            rootContainer.forceActiveFocus();
            updateNightLightState();
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Component.onCompleted: {
        updateNightLightState();
    }

    mask: Region {
        item: (desktopMenuWindow.isVisible || menuContainer.animProgress > 0.001) ? maskTarget : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: DesktopMenuController.isVisible
    property bool isWidgetMode: DesktopMenuController.mode === "widget"
    property real targetX: DesktopMenuController.targetX
    property real targetY: DesktopMenuController.targetY
    property bool isNightLightActive: false

    property int configRevision: 0

    Connections {
        target: DesktopMenuController

        function onMenuTriggered() {
            rootContainer.forceActiveFocus();
            closeAnim.stop();
            openAnim.restart();
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        ignoreUnknownSignals: true
        function onSettingsLoaded() {
            desktopMenuWindow.configRevision++;
            desktopMenuWindow.updateNightLightState();
        }
    }

    Connections {
        target: (typeof BlueLight !== "undefined") ? BlueLight : null
        ignoreUnknownSignals: true
        function onSettingsChanged() {
            desktopMenuWindow.updateNightLightState();
        }
    }

    property real cornerRadius: {
        let dummy = configRevision;
        return (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
            ? ThemeBackend.borderRadius
            : s(12);
    }

    property color menuBackgroundColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.base) {
            return ThemeBackend.base;
        }
        return "#1e1e2e";
    }

    property color buttonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) {
            return ThemeBackend.surface0;
        }
        return "#313244";
    }

    property color primaryButtonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.primary) {
            return ThemeBackend.primary;
        }
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.blue) {
            return ThemeBackend.blue;
        }
        return "#89b4fa";
    }

    property color primaryTextColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.base) {
            return ThemeBackend.base;
        }
        return "#1e1e2e";
    }

    property real menuWidth: s(170)
    property real menuHeight: contentCol.implicitHeight
    property real menuOffset: s(3)

    property real clampedX: {
        let w = menuWidth;
        let margin = s(8);
        let dockMargin = 0;
        let isDockRight = false;
        let isDockLeft = false;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock && Config.rawSettings.dock.enabled !== false) {
            let pos = Config.rawSettings.dock.position || "bottom";
            let sz = s((Config.rawSettings.dock.elementSize || 44) + 20);
            if (pos === "right") { isDockRight = true; dockMargin = sz; }
            else if (pos === "left") { isDockLeft = true; dockMargin = sz; }
        }
        let maxRight = desktopMenuWindow.width - margin - (isDockRight ? dockMargin : 0);
        let minLeft = margin + (isDockLeft ? dockMargin : 0);
        let off = (targetX + w > maxRight) ? -menuOffset : menuOffset;
        if (targetX + w > maxRight) {
            return Math.max(minLeft, targetX - w + off);
        }
        return Math.max(minLeft, Math.min(maxRight - w, targetX + off));
    }

    property real clampedY: {
        let h = menuHeight;
        let margin = s(8);
        let dockMargin = 0;
        let isDockBottom = false;
        let isDockTop = false;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock && Config.rawSettings.dock.enabled !== false) {
            let pos = Config.rawSettings.dock.position || "bottom";
            let sz = s((Config.rawSettings.dock.elementSize || 44) + 20);
            if (pos === "bottom") { isDockBottom = true; dockMargin = sz; }
            else if (pos === "top") { isDockTop = true; dockMargin = sz; }
        }
        let maxBottom = desktopMenuWindow.height - margin - (isDockBottom ? dockMargin : 0);
        let minTop = margin + (isDockTop ? dockMargin : 0);
        let off = (targetY + h > maxBottom) ? -menuOffset : menuOffset;
        if (targetY + h > maxBottom) {
            return Math.max(minTop, targetY - h + off);
        }
        return Math.max(minTop, Math.min(maxBottom - h, targetY + off));
    }

    property bool alignRight: (targetX + menuWidth > desktopMenuWindow.width - s(8))

    visible: isVisible || menuContainer.animProgress > 0.001

    Timer {
        id: reloadTimer
        interval: 50
        repeat: false
        onTriggered: desktopMenuWindow.reloadShell()
    }

    Process {
        id: shuffleProcess
        running: false
        property string targetScreenName: ""
        property real originX: 0.5
        property real originY: 0.5

        stdout: StdioCollector {
            onStreamFinished: {
                let picked = this.text.trim();
                if (picked && picked !== "") {
                    desktopMenuWindow.applyWallpaper(shuffleProcess.targetScreenName, picked, {
                        type: 2,
                        originX: shuffleProcess.originX,
                        originY: shuffleProcess.originY
                    });
                }
            }
        }
    }

    function updateNightLightState() {
        let anyEnabled = false;
        if (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") {
            anyEnabled = BlueLight.isAnyEnabled();
        } else if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            let ds = Config.getSetting("display", {"monitors": {}});
            let mons = (ds && ds.monitors) ? ds.monitors : {};
            for (let mName in mons) {
                if (mons[mName] && mons[mName].enabled) {
                    anyEnabled = true;
                    break;
                }
            }
        }
        isNightLightActive = anyEnabled;
    }

    function toggleNightLight() {
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("system/quick_click.wav");
        }
        let target = !isNightLightActive;
        isNightLightActive = target;

        let monNames = [];
        let ds = (typeof Config !== "undefined" && typeof Config.getSetting === "function") ? Config.getSetting("display", {"monitors": {}}) : {"monitors": {}};
        let mons = (ds && ds.monitors) ? ds.monitors : {};
        for (let m in mons) {
            if (monNames.indexOf(m) === -1) {
                monNames.push(m);
            }
        }
        if (typeof Quickshell !== "undefined" && Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name && monNames.indexOf(scr.name) === -1) {
                    monNames.push(scr.name);
                }
            }
        }

        if (typeof BlueLight !== "undefined" && typeof BlueLight.setEnabled === "function") {
            if (monNames.length > 0) {
                for (let i = 0; i < monNames.length; i++) {
                    BlueLight.setEnabled(monNames[i], target);
                }
            } else {
                BlueLight.setEnabled("", target);
            }
        }
        updateNightLightState();
    }

    function applyWallpaper(scrName, path, transitionData) {
        if (!path) return;
        let mon = scrName || "all";
        let trans = transitionData !== undefined ? transitionData : "fade";

        if (typeof Wallpaper !== "undefined") {
            if (typeof Wallpaper.setWallpaper === "function") {
                Wallpaper.setWallpaper(mon, path, trans);
            } else if (typeof Wallpaper.changeWallpaper === "function") {
                Wallpaper.changeWallpaper(mon, path, trans);
            } else if (typeof Wallpaper.wallpaperChanged === "function") {
                Wallpaper.wallpaperChanged(mon, path, trans);
            }
        }
    }

    function shuffleWallpaper() {
        let scr = desktopMenuWindow.screen || DesktopMenuController.screen;
        let scrName = (scr && scr.name) ? scr.name : "all";
        let cacheDir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? Caching.getCacheDir("wallpaper") : "";
        let stateFile = cacheDir ? (cacheDir + "/current_" + scrName) : "";
        let customDir = "";
        if (typeof Wallpaper !== "undefined") {
            if (Wallpaper.wallpaperDir) customDir = Wallpaper.wallpaperDir;
            else if (Wallpaper.directory) customDir = Wallpaper.directory;
            else if (Wallpaper.folder) customDir = Wallpaper.folder;
        }
        if (!customDir && typeof Config !== "undefined") {
            if (Config.wallpaperDir) customDir = Config.wallpaperDir;
            else if (Config.wallpapersDir) customDir = Config.wallpapersDir;
        }

        let scrW = desktopMenuWindow.width > 0 ? desktopMenuWindow.width : ((scr && scr.geometry && scr.geometry.width) ? scr.geometry.width : 1920);
        let scrH = desktopMenuWindow.height > 0 ? desktopMenuWindow.height : ((scr && scr.geometry && scr.geometry.height) ? scr.geometry.height : 1080);
        let posX = Math.max(desktopMenuWindow.clampedX, Math.min(desktopMenuWindow.clampedX + desktopMenuWindow.menuWidth, desktopMenuWindow.targetX));
        let posY = Math.max(desktopMenuWindow.clampedY, Math.min(desktopMenuWindow.clampedY + desktopMenuWindow.menuHeight, desktopMenuWindow.targetY));
        let normX = scrW > 0 ? Math.max(0.0, Math.min(1.0, posX / scrW)) : 0.5;
        let normY = scrH > 0 ? Math.max(0.0, Math.min(1.0, posY / scrH)) : 0.5;

        shuffleProcess.originX = normX;
        shuffleProcess.originY = normY;
        DesktopMenuController.menuOriginX = normX;
        DesktopMenuController.menuOriginY = normY;
        DesktopMenuController.isMenuShuffle = true;

        let cmd =
            "STATE_FILE='" + stateFile + "'; " +
            "CUSTOM_DIR='" + customDir + "'; " +
            "DIR=''; " +
            "if [ -n \"$CUSTOM_DIR\" ] && [ -d \"$CUSTOM_DIR\" ]; then " +
            "    DIR=\"$CUSTOM_DIR\"; " +
            "elif [ -f \"$STATE_FILE\" ]; then " +
            "    CUR=$(cat \"$STATE_FILE\" 2>/dev/null); " +
            "    if [ -n \"$CUR\" ]; then " +
            "        CANDIDATE=$(dirname \"$CUR\"); " +
            "        if [ -d \"$CANDIDATE\" ]; then DIR=\"$CANDIDATE\"; fi; " +
            "    fi; " +
            "fi; " +
            "if [ -z \"$DIR\" ] || [ ! -d \"$DIR\" ]; then " +
            "    for d in \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"$HOME/Pictures\" \"$HOME/.config/serpantinum/wallpapers\" \"/usr/share/backgrounds\"; do " +
            "        if [ -d \"$d\" ]; then DIR=\"$d\"; break; fi; " +
            "    done; " +
            "fi; " +
            "if [ -n \"$DIR\" ] && [ -d \"$DIR\" ]; then " +
            "    find -L \"$DIR\" -maxdepth 2 -type f \\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.webp\" -o -iname \"*.bmp\" -o -iname \"*.avif\" \\) 2>/dev/null | shuf -n 1; " +
            "fi";

        shuffleProcess.targetScreenName = scrName;
        shuffleProcess.command = ["bash", "-c", cmd];
        shuffleProcess.running = false;
        shuffleProcess.running = true;
    }

    function lockScreen() {
        DesktopMenuController.hide();
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/lock.sh") : "lock.sh";
        Quickshell.execDetached(["bash", scriptPath]);
    }

    function reloadShell() {
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let cmd = (dir ? "if [ -f '" + dir + "/scripts/reload.sh' ]; then bash '" + dir + "/scripts/reload.sh'; else " : "")
            + "if command -v serpantinum >/dev/null 2>&1; then serpantinum reload; elif command -v qs_manager.sh >/dev/null 2>&1; then qs_manager.sh reload; else pkill -USR1 quickshell || pkill -HUP quickshell; fi"
            + (dir ? "; fi" : "");
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function openRedactor(selectedWidgetId) {
        DesktopMenuController.hide();
        let targetId = selectedWidgetId !== undefined ? String(selectedWidgetId) : "";
        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/redactor.sh") : "redactor.sh";
        Quickshell.execDetached(["bash", scriptPath, mon, targetId]);
    }

    function openGuide(tab) {
        DesktopMenuController.hide();
        let targetTab = tab !== undefined ? String(tab).trim() : "";
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let args = "open settings" + (targetTab ? (" " + targetTab) : "");
        let cmd = (dir ? ("if [ -f '" + dir + "/scripts/qs_manager.sh' ]; then bash '" + dir + "/scripts/qs_manager.sh' " + args + "; else ") : "")
            + "if command -v serpantinum >/dev/null 2>&1; then serpantinum msg " + args + "; elif command -v qs_manager.sh >/dev/null 2>&1; then qs_manager.sh " + args + "; fi"
            + (dir ? "; fi" : "");
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    Item {
        id: rootContainer
        anchors.fill: parent
        focus: desktopMenuWindow.isVisible
        Keys.onEscapePressed: DesktopMenuController.hide()

        onActiveFocusChanged: {
            if (!activeFocus && desktopMenuWindow.isVisible && menuContainer.animProgress > 0.5) {
                DesktopMenuController.hide();
            }
        }

        Item {
            id: maskTarget
            x: desktopMenuWindow.clampedX
            y: desktopMenuWindow.clampedY
            width: desktopMenuWindow.menuWidth
            height: desktopMenuWindow.menuHeight
        }

        Item {
            id: menuContainer

            property real animProgress: 0.0

            NumberAnimation {
                id: openAnim
                target: menuContainer
                property: "animProgress"
                from: menuContainer.animProgress > 0.8 ? 0.2 : 0.0
                to: 1.0
                duration: 140
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
            }

            NumberAnimation {
                id: closeAnim
                target: menuContainer
                property: "animProgress"
                to: 0.0
                duration: 75
                easing.type: Easing.InCubic
                onFinished: {
                    if (!desktopMenuWindow.isVisible) {
                        menuContainer.animProgress = 0.0;
                    }
                }
            }

            x: desktopMenuWindow.clampedX
            y: desktopMenuWindow.clampedY
            width: desktopMenuWindow.menuWidth
            height: desktopMenuWindow.menuHeight

            opacity: Math.max(0.0, Math.min(1.0, animProgress * 2.5))

            transform: Scale {
                origin.x: desktopMenuWindow.targetX - desktopMenuWindow.clampedX
                origin.y: desktopMenuWindow.targetY - desktopMenuWindow.clampedY
                xScale: Math.max(0.0, menuContainer.animProgress)
                yScale: Math.max(0.0, menuContainer.animProgress)
            }

            Column {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: desktopMenuWindow.s(2)

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    Item {
                        visible: desktopMenuWindow.alignRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        id: iconButtonsBox
                        Layout.preferredWidth: iconRow.implicitWidth + desktopMenuWindow.s(8)
                        Layout.preferredHeight: iconRow.implicitHeight + desktopMenuWindow.s(8)
                        color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, ThemeBackend.elementOpacity)
                        radius: desktopMenuWindow.cornerRadius
                        clip: true

                        WallpaperBlur {
                            z: -1
                            anchors.fill: parent
                            radius: parent.radius
                        }

                        Row {
                            id: iconRow
                            anchors.centerIn: parent
                            spacing: desktopMenuWindow.s(3)

                            IconButton {
                                visible: desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.primaryButtonColor
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: desktopMenuWindow.primaryTextColor
                                buttonIcon: "󰏫"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.openRedactor(DesktopMenuController.targetWidgetId);
                                }
                            }

                            IconButton {
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.primaryButtonColor
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: desktopMenuWindow.primaryTextColor
                                buttonIcon: "󰒝"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.shuffleWallpaper();
                                    DesktopMenuController.hide();
                                }
                            }

                            IconButton {
                                id: nightLightBtn
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.isNightLightActive ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.peach) ? ThemeBackend.peach : "#fab387") : desktopMenuWindow.buttonColor
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: desktopMenuWindow.isNightLightActive ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.crust) ? ThemeBackend.crust : ((typeof ThemeBackend !== "undefined" && ThemeBackend.base) ? ThemeBackend.base : "#1e1e2e")) : ((typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4")
                                buttonIcon: "󰖔"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.toggleNightLight();
                                }
                            }

                            IconButton {
                                id: reloadBtn
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.buttonColor
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.text
                                buttonIcon: "󰑐"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    DesktopMenuController.hide();
                                    reloadTimer.restart();
                                }
                            }

                            IconButton {
                                id: lockBtn
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.buttonColor
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.text
                                buttonIcon: ""
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.lockScreen();
                                }
                            }

                            DeleteButton {
                                visible: desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.22) : "#452026"
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? ThemeBackend.red : "#f38ba8"
                                onClicked: {
                                    let wId = DesktopMenuController.targetWidgetId;
                                    if (wId) {
                                        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
                                        let safeMon = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                                        if (typeof WidgetSync !== "undefined") {
                                            WidgetSync.removeWidget(mon, wId);
                                        }
                                        let mainQml = (typeof Caching !== "undefined" && Caching.mainQml) ? Caching.mainQml : "";
                                        if (mainQml) {
                                            Quickshell.execDetached(["quickshell", "-p", mainQml, "ipc", "call", "widgets-" + safeMon, "remove", wId]);
                                        }
                                    }
                                    DesktopMenuController.hide();
                                }
                            }
                        }
                    }

                    Item {
                        visible: !desktopMenuWindow.alignRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    id: clickButtonsBox
                    width: parent.width
                    height: clickButtonsCol.implicitHeight + desktopMenuWindow.s(8)
                    color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, ThemeBackend.elementOpacity)
                    radius: desktopMenuWindow.cornerRadius
                    clip: true

                    WallpaperBlur {
                        z: -1
                        anchors.fill: parent
                        radius: parent.radius
                    }

                    Column {
                        id: clickButtonsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: desktopMenuWindow.s(4)
                        spacing: desktopMenuWindow.s(2)

                        ClickButton {
                            visible: desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰕰"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.display.widgets.open", "Open Redactor");
                                    if (val && val !== "guide.display.widgets.open") return val;
                                    return "Open Redactor";
                                }
                                return "Open Redactor";
                            }
                            accentColor: desktopMenuWindow.primaryButtonColor
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: desktopMenuWindow.primaryTextColor
                            onClicked: {
                                desktopMenuWindow.openRedactor("");
                            }
                        }

                        ClickButton {
                            visible: !desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰸉"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.theme.wallpaper.select_wallpaper", "Select Wallpaper");
                                    if (val && val !== "guide.theme.wallpaper.select_wallpaper") return val;
                                    return "Select Wallpaper";
                                }
                                return "Select Wallpaper";
                            }
                            accentColor: desktopMenuWindow.buttonColor
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.text
                            onClicked: {
                                DesktopMenuController.hide();
                                let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
                                if (dir) {
                                    Quickshell.execDetached(["bash", "-c", dir + "/scripts/qs_manager.sh toggle wallpaper"]);
                                } else {
                                    Quickshell.execDetached(["bash", "-c", "qs_manager.sh toggle wallpaper"]);
                                }
                            }
                        }

                        ClickButton {
                            visible: !desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰕰"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.display.widgets.open", "Widget Redactor");
                                    if (val && val !== "guide.display.widgets.open") return val;
                                    return "Widget Redactor";
                                }
                                return "Widget Redactor";
                            }
                            accentColor: desktopMenuWindow.buttonColor
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.text
                            onClicked: {
                                desktopMenuWindow.openRedactor("");
                            }
                        }

                        ClickButton {
                            visible: !desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰏘"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.tabs.theme", "Theme");
                                    if (val && val !== "guide.tabs.theme") return val;
                                    return "Theme";
                                }
                                return "Theme";
                            }
                            accentColor: desktopMenuWindow.buttonColor
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.text
                            onClicked: {
                                desktopMenuWindow.openGuide("theme");
                            }
                        }
                    }
                }

                Rectangle {
                    id: settingsBox
                    width: parent.width
                    height: settingsCol.implicitHeight + desktopMenuWindow.s(8)
                    color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, ThemeBackend.elementOpacity)
                    radius: desktopMenuWindow.cornerRadius
                    clip: true

                    WallpaperBlur {
                        z: -1
                        anchors.fill: parent
                        radius: parent.radius
                    }

                    Column {
                        id: settingsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: desktopMenuWindow.s(4)

                        ClickButton {
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰒓"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("widgets.guide.name", "Settings");
                                    if (val && val !== "widgets.guide.name") return val;
                                    return "Settings";
                                }
                                return "Settings";
                            }
                            accentColor: desktopMenuWindow.buttonColor
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.text
                            onClicked: {
                                if (desktopMenuWindow.isWidgetMode) {
                                    desktopMenuWindow.openGuide("display_widgets");
                                } else {
                                    desktopMenuWindow.openGuide("");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
