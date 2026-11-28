import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "WindowRegistry.js" as Registry
import "notifications" as Notifs

ShellOverlayWindow {
    id: masterWindow

    WlrLayershell.namespace: "qs-master"
    overlayOpen: masterWindow.isVisible
    focusTarget: widgetStack
    dismissOnOutsideClick: false
    carveBarHole: false
    trackFullscreen: true

    readonly property var activeWidgetItem: widgetCache[currentActive] || widgetStack.currentItem

    escapeEnabled: masterWindow.isVisible && !masterWindow.isClosing
        && !(masterWindow.activeWidgetItem && masterWindow.activeWidgetItem.handlesEscape === true)

    function handleEscape() {
        let item = masterWindow.activeWidgetItem;
        if (item && typeof item.handleEscape === "function" && item.handleEscape()) {
            return true;
        }
        if (item && item.handlesEscape === true) {
            return true;
        }
        switchWidget("hidden", "");
        return true;
    }

    function reportWidgetState() {
        if (typeof Caching === "undefined" || !Caching.runDir) return;
        let sName = (masterWindow.currentActive === "hidden" || !masterWindow.screen) ? "" : (masterWindow.screen.name || "");
        let payload = JSON.stringify({
            widget: masterWindow.currentActive,
            screen: sName
        });
        currentWidgetFile.setText(payload + "\n");
    }

    FileView {
        id: currentWidgetFile
        path: (typeof Caching !== "undefined" && Caching.runDir) ? (Caching.runDir + "/current_widget") : ""
        blockWrites: true
    }

    Connections {
        target: (typeof Caching !== "undefined") ? Caching : null
        function onRunDirChanged() {
            masterWindow.reportWidgetState();
        }
    }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            ShellRouter.reload();
        }

        function clearNotifications(): void {
            ShellRouter.clearNotifications();
        }

        function embeddedSettings(action: string, tab: string): void {
            ShellRouter.embeddedSettings(action || "toggle", tab || "");
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            ShellRouter.handleCommand(cmd, targetWidget, arg);
        }
    }

    implicitWidth: masterWindow.screen ? masterWindow.screen.width : 0
    implicitHeight: masterWindow.screen ? masterWindow.screen.height : 0

    visible: isVisible

    mask: Region {
        item: masterWindow.isCurrentDraggable ? maskContent : topBarHole
        intersection: masterWindow.isCurrentDraggable ? Intersection.Combine : Intersection.Xor
    }

    readonly property string barPosition: SurfaceRegistry.barPosition
    readonly property bool screenReady: masterWindow.width >= 100 && masterWindow.height >= 100
    readonly property bool isCurrentDraggable: {
        let meta = Registry.getSurface(masterWindow.currentActive);
        return Boolean(meta && meta.draggable);
    }

    Item {
        id: maskContent
        x: masterWindow._animX
        y: masterWindow._animY
        width: masterWindow._animW
        height: masterWindow._animH
    }

    Item {
        id: topBarHole

        readonly property int barThickness: SurfaceRegistry.barThickness
        readonly property string bp: masterWindow.barPosition
        readonly property bool activeBar: !masterWindow.isBarEffectivelyHidden

        readonly property bool overlapTopLeft: masterWindow.currentActive !== "hidden" && masterWindow._animX < 10 && masterWindow._animY < barThickness
        readonly property bool overlapTopRight: masterWindow.currentActive !== "hidden" && (masterWindow._animX + masterWindow._animW) > (masterWindow.width - 10) && masterWindow._animY < barThickness
        readonly property bool overlapBottomLeft: masterWindow.currentActive !== "hidden" && masterWindow._animX < 10 && (masterWindow._animY + masterWindow._animH) > (masterWindow.height - barThickness)
        readonly property bool overlapBottomRight: masterWindow.currentActive !== "hidden" && (masterWindow._animX + masterWindow._animW) > (masterWindow.width - 10) && (masterWindow._animY + masterWindow._animH) > (masterWindow.height - barThickness)

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return masterWindow.width - barThickness;
            if (overlapTopLeft && bp === "top") return masterWindow._animW;
            if (overlapBottomLeft && bp === "bottom") return masterWindow._animW;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return masterWindow.height - barThickness;
            if (overlapTopLeft && bp === "left") return masterWindow._animH;
            if (overlapTopRight && bp === "right") return masterWindow._animH;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            let w = masterWindow.width;
            if (overlapTopLeft && bp === "top") w -= masterWindow._animW;
            if (overlapTopRight && bp === "top") w -= masterWindow._animW;
            if (overlapBottomLeft && bp === "bottom") w -= masterWindow._animW;
            if (overlapBottomRight && bp === "bottom") w -= masterWindow._animW;
            return Math.max(0, w);
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            let h = masterWindow.height;
            if (overlapTopLeft && bp === "left") h -= masterWindow._animH;
            if (overlapBottomLeft && bp === "left") h -= masterWindow._animH;
            if (overlapTopRight && bp === "right") h -= masterWindow._animH;
            if (overlapBottomRight && bp === "right") h -= masterWindow._animH;
            return Math.max(0, h);
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible && !masterWindow.isCurrentDraggable && !masterWindow.isClosing
        onClicked: switchWidget("hidden", "")
    }

    Item {
        id: preloaderContainer
        visible: false
    }

    property var widgetCache: ({})
    property var componentCache: ({})

    function evictWidgetCache() {
        if (masterWindow.isVisible || masterWindow.isClosing || masterWindow.currentActive !== "hidden" || masterWindow.targetActive !== "hidden") {
            return;
        }
        let keys = Object.keys(masterWindow.widgetCache);
        if (keys.length === 0) return;
        if (widgetStack.depth > 0) {
            widgetStack.clear(StackView.Immediate);
        }
        let cache = masterWindow.widgetCache;
        masterWindow.widgetCache = ({});
        for (let i = 0; i < keys.length; i++) {
            let it = cache[keys[i]];
            if (it) {
                it.visible = false;
                it.destroy();
            }
        }
        Qt.callLater(gc);
    }

    Timer {
        id: evictCacheTimer
        interval: 45000
        repeat: false
        onTriggered: masterWindow.evictWidgetCache()
    }

    function ensureWidgetItem(name, t) {
        let cached = widgetCache[name];
        if (cached) return { item: cached, error: false };

        let comp = componentCache[name];
        if (!comp) {
            comp = typeof t.comp === "string" ? Qt.createComponent(t.comp) : t.comp;
            if (comp) componentCache[name] = comp;
        }
        if (!comp) return { item: null, error: true };

        if (comp.status === Component.Loading) return { item: null, error: false };
        if (comp.status === Component.Error) {
            console.warn("Widget component failed to load:", name, comp.errorString());
            return { item: null, error: true };
        }

        let item = comp.createObject(preloaderContainer);
        if (item) {
            item.visible = false;
            if (item.dismissRequested && typeof item.dismissRequested.connect === "function") {
                item.dismissRequested.connect(function() {
                    if (masterWindow.currentActive === name || masterWindow.targetActive === name) {
                        masterWindow.switchWidget("hidden", "");
                    }
                });
            }
            widgetCache[name] = item;
            return { item: item, error: false };
        }
        return { item: null, error: true };
    }

    Component.onCompleted: {
        ShellRouter.registerMaster(masterWindow);
        applyConfigSettings();
        reportWidgetState();
    }

    Component.onDestruction: {
        ShellRouter.unregisterMaster(masterWindow);
        if (typeof Caching !== "undefined" && Caching.runDir) {
            currentWidgetFile.setText("{\"widget\":\"hidden\",\"screen\":\"\"}\n");
        }
    }

    property string targetActive: "hidden"
    property string currentActive: "hidden"

    onCurrentActiveChanged: {
        reportWidgetState();
    }

    onScreenChanged: {
        applyConfigSettings();
        if (currentActive !== "hidden") {
            reportWidgetState();
        }
    }

    property bool isVisible: false
    property bool isClosing: false
    property string activeArg: ""
    property var preferredScreen: null
    property bool disableMorph: true
    property int switchGeneration: 0
    property bool userMoved: false

    property int morphDuration:       300
    property int morphDurationSwitch: 300
    property int exitDuration:        180

    property real _animW: 1
    property real _animH: 1
    property real _animX: 0
    property real _animY: 0

    property real _stageW: 1
    property real _stageH: 1

    property real globalUiScale: 1.0

    Notifs.NotificationPopups {
        id: osdPopups
    }

    function applyConfigSettings() {
        let parsed = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings : {};
        let sVal = undefined;

        if (parsed.general && parsed.general.uiScale !== undefined) {
            sVal = parsed.general.uiScale;
        } else if (parsed.uiScale !== undefined) {
            sVal = parsed.uiScale;
        }

        let targetScale = (sVal !== undefined && typeof sVal === "number" && !isNaN(sVal) && sVal > 0) ? sVal : 1.0;
        if (masterWindow.globalUiScale !== targetScale) {
            masterWindow.globalUiScale = targetScale;
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            masterWindow.applyConfigSettings();
        }
    }

    function getLayout(name) {
        let bp = masterWindow.barPosition;
        let effHidden = masterWindow.isBarEffectivelyHidden;
        let scrW = masterWindow.screen ? masterWindow.screen.width : masterWindow.width;
        let scrH = masterWindow.screen ? masterWindow.screen.height : masterWindow.height;

        let result = Registry.getLayout(name, 0, 0, scrW, scrH, masterWindow.globalUiScale, bp);
        if (!result) return null;

        let scale = masterWindow.globalUiScale || 1.0;

        if (effHidden && result.barRelative) {
            let offsetAdjustment = Math.round(46 * scale);
            let adjusted = Object.assign({}, result);

            if (bp === "top") {
                adjusted.ry = Math.max(Math.round(6 * scale), result.ry - offsetAdjustment);
            } else if (bp === "bottom") {
                adjusted.ry = Math.min(masterWindow.height - result.h - Math.round(6 * scale), result.ry + offsetAdjustment);
            } else if (bp === "left") {
                adjusted.rx = Math.max(Math.round(6 * scale), result.rx - offsetAdjustment);
            } else if (bp === "right") {
                adjusted.rx = Math.min(masterWindow.width - result.w - Math.round(6 * scale), result.rx + offsetAdjustment);
            }

            return adjusted;
        }

        return result;
    }

    readonly property var targetLayout: {
        if (currentActive === "hidden" || currentActive === "") return null;
        if (!screenReady) return null;

        let t = getLayout(currentActive);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) return null;

        if (t.rx < -t.w - 50 || t.ry < -t.h - 50 ||
            t.rx > masterWindow.width + 50 || t.ry > masterWindow.height + 50) {
            return null;
        }

        return { x: t.rx, y: t.ry, w: t.w, h: t.h };
    }

    onTargetLayoutChanged: {
        if (!targetLayout || masterWindow.currentActive === "hidden" || !masterWindow.isVisible) return;
        if (!masterWindow.userMoved || !masterWindow.isCurrentDraggable) {
            masterWindow._animX = targetLayout.x;
            masterWindow._animY = targetLayout.y;
        }
        masterWindow._animW = targetLayout.w;
        masterWindow._animH = targetLayout.h;
        masterWindow._stageW = targetLayout.w;
        masterWindow._stageH = targetLayout.h;
    }

    onIsVisibleChanged: {
        if (isVisible) {
            masterWindow.acquireFocus();
        } else if (currentActive === "hidden") {
            for (let k in widgetCache) {
                let it = widgetCache[k];
                if (it) it.visible = false;
            }
        }
    }

    function applyItemArg(item, arg) {
        if (!item) return;
        let a = (arg !== undefined && arg !== null) ? String(arg) : "";
        if (typeof item.activate === "function") {
            item.activate(a);
        } else if (a !== "") {
            if (typeof item.gotoTab === "function") {
                item.gotoTab(a);
            } else if (item.activeMode !== undefined) {
                item.activeMode = a;
            }
        }
    }

    function activateCurrent(arg) {
        let a = (arg !== undefined && arg !== null) ? String(arg) : "";
        masterWindow.activeArg = a;
        let item = masterWindow.activeWidgetItem;
        if (item) {
            applyItemArg(item, a);
        }
    }

    function openSurface(id, arg, screen) {
        masterWindow.preferredScreen = screen !== undefined ? screen : null;
        switchWidget(id, arg || "");
    }

    Item {
        id: animContainer
        x: masterWindow._animX
        y: masterWindow._animY
        width: masterWindow._animW
        height: masterWindow._animH
        clip: true

        DragHandler {
            id: windowDragHandler
            target: null
            acceptedButtons: Qt.LeftButton
            enabled: masterWindow.isCurrentDraggable

            property real startX: 0
            property real startY: 0

            onActiveChanged: {
                if (active) {
                    masterWindow.disableMorph = true;
                    startX = masterWindow._animX;
                    startY = masterWindow._animY;
                } else {
                    masterWindow.disableMorph = false;
                }
            }

            onTranslationChanged: {
                if (active) {
                    masterWindow.userMoved = true;
                    masterWindow._animX = startX + translation.x;
                    masterWindow._animY = startY + translation.y;
                }
            }
        }

        Item {
            id: contentStage
            width: masterWindow._stageW
            height: masterWindow._stageH
            x: (animContainer.width - width) / 2
            y: (animContainer.height - height) / 2
            transformOrigin: Item.Center

            scale: masterWindow.isVisible ? 1.0 : 0.96
            Behavior on scale {
                NumberAnimation {
                    duration: masterWindow.isVisible ? 280 : 160
                    easing.type: masterWindow.isVisible ? Easing.OutCubic : Easing.InCubic
                }
            }

            opacity: masterWindow.isVisible ? 1.0 : 0.0
            visible: masterWindow.isVisible || opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: masterWindow.isVisible ? 200 : 140
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea { anchors.fill: parent }

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true

                replaceEnter: null
                replaceExit: null
                pushEnter: null
                pushExit: null
                popEnter: null
                popExit: null

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }
            }
        }

        Behavior on x {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    function switchWidget(newWidget, arg) {
        if (newWidget === "hidden" && masterWindow.isClosing) return;

        masterWindow.switchGeneration++;
        let gen = masterWindow.switchGeneration;
        masterWindow.targetActive = newWidget;

        let nextMeta = Registry.getSurface(newWidget);
        if (!nextMeta || !nextMeta.preservePosition) {
            masterWindow.userMoved = false;
        }

        if (exitSafetyTimer.running) {
            exitSafetyTimer.stop();
        }

        if (newWidget === "hidden") {
            masterWindow.preferredScreen = null;
            if (currentActive !== "hidden" && !masterWindow.isClosing) {
                let closingGen = gen;
                masterWindow.isClosing = true;
                masterWindow.targetActive = "hidden";

                let activeItem = widgetCache[currentActive] || widgetStack.currentItem;

                let finalizeClose = function() {
                    if (closingGen !== masterWindow.switchGeneration) return;
                    masterWindow.isClosing = false;
                    masterWindow.currentActive = "hidden";
                    masterWindow.morphDuration = masterWindow.exitDuration;
                    masterWindow.disableMorph = true;
                    masterWindow.isVisible = false;

                    for (let k in widgetCache) {
                        let it = widgetCache[k];
                        if (it) it.visible = false;
                    }
                    reportWidgetState();
                    evictCacheTimer.restart();
                };

                if (activeItem && typeof activeItem.startExit === "function") {
                    exitSafetyTimer.scheduledGeneration = closingGen;
                    exitSafetyTimer.restart();
                    activeItem.startExit(finalizeClose);
                } else {
                    finalizeClose();
                }
            }
        } else {
            evictCacheTimer.stop();
            masterWindow.isClosing = false;
            let targetScreen = Compositor.resolveTargetScreen(masterWindow.preferredScreen);
            if (targetScreen && masterWindow.screen !== targetScreen) {
                masterWindow.screen = targetScreen;
            }
            executeSwitch(newWidget, arg, gen, 0);
        }
    }

    function executeSwitch(newWidget, arg, gen, attempt) {
        if (gen !== masterWindow.switchGeneration || newWidget === "hidden") return;
        let tries = attempt || 0;
        if (tries >= 20) {
            masterWindow.targetActive = masterWindow.currentActive;
            return;
        }

        let targetScreen = Compositor.resolveTargetScreen(masterWindow.preferredScreen);
        if (targetScreen && masterWindow.screen !== targetScreen) {
            masterWindow.screen = targetScreen;
        }

        let t = getLayout(newWidget);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration) {
                    executeSwitch(newWidget, arg, gen, tries + 1);
                }
            });
            return;
        }

        let ensured = ensureWidgetItem(newWidget, t);
        if (ensured.error) {
            masterWindow.targetActive = masterWindow.currentActive;
            return;
        }
        if (!ensured.item) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration) {
                    executeSwitch(newWidget, arg, gen, tries + 1);
                }
            });
            return;
        }

        if (gen !== masterWindow.switchGeneration) return;

        let cachedItem = ensured.item;
        let isComingFromHidden = (!masterWindow.isVisible || widgetStack.currentItem === null || masterWindow.currentActive === "hidden");

        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;

        if (!masterWindow.userMoved || !masterWindow.isCurrentDraggable) {
            masterWindow._animX = t.rx;
            masterWindow._animY = t.ry;
        }
        masterWindow._animW = t.w;
        masterWindow._animH = t.h;
        masterWindow._stageW = t.w;
        masterWindow._stageH = t.h;

        if (isComingFromHidden) {
            masterWindow.disableMorph = true;
        } else {
            masterWindow.morphDuration = masterWindow.morphDurationSwitch;
            masterWindow.disableMorph = false;
        }

        applyItemArg(cachedItem, arg);

        if (widgetStack.currentItem !== cachedItem) {
            widgetStack.replace(cachedItem, {}, StackView.Immediate);
        }

        for (let k in widgetCache) {
            let it = widgetCache[k];
            if (it && it !== cachedItem) {
                it.visible = false;
            }
        }
        cachedItem.visible = true;

        masterWindow.isVisible = true;

        if (isComingFromHidden) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration && masterWindow.isVisible && masterWindow.currentActive === newWidget) {
                    masterWindow.disableMorph = false;
                }
            });
        }
    }

    Timer {
        id: exitSafetyTimer
        interval: 450
        property int scheduledGeneration: -1
        onTriggered: {
            if (scheduledGeneration === masterWindow.switchGeneration && masterWindow.isClosing) {
                masterWindow.isClosing = false;
                masterWindow.currentActive = "hidden";
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = true;
                masterWindow.isVisible = false;
                for (let k in widgetCache) {
                    let it = widgetCache[k];
                    if (it) it.visible = false;
                }
                reportWidgetState();
                evictCacheTimer.restart();
            }
        }
    }
}
