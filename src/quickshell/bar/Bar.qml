import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../reusables"
import "../"

Scope {
    id: barScope

    property bool pendingReload: false
    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { barScope.configRevision++; }
        function onDataReadyChanged() { barScope.configRevision++; }
        function onRawSettingsChanged() { barScope.configRevision++; }
    }

    function hasBlockingPanel() {
        let list = SurfaceRegistry.windowsOf("bars");
        for (let i = 0; i < list.length; i++) {
            let win = list[i];
            if (win && (win.isNotifOpen || win.isSysOpen)) {
                return true;
            }
        }
        return false;
    }

    function tryPendingReload() {
        if (barScope.pendingReload && !barScope.hasBlockingPanel()) {
            barScope.pendingReload = false;
            Quickshell.reload(true);
        }
    }

    IpcHandler {
        target: "topbar"
        function setRedactMode(active: string): void {
            let flag = (active === "true" || active === "1");
            let list = SurfaceRegistry.windowsOf("bars");
            for (let i = 0; i < list.length; i++) {
                let win = list[i];
                if (win) win.isRedacting = flag;
            }
        }
        function forceReload() {
            barScope.pendingReload = false;
            Quickshell.reload(true);
        }
        function queueReload() {
            if (!barScope.hasBlockingPanel()) {
                barScope.pendingReload = false;
                Quickshell.reload(true);
            } else {
                barScope.pendingReload = true;
            }
        }
        function toggleUpdate() {
            let list = SurfaceRegistry.windowsOf("bars");
            for (let i = 0; i < list.length; i++) {
                let win = list[i];
                if (win && typeof win.toggleUpdate === "function") {
                    win.toggleUpdate();
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: screenBarScope
                required property var modelData
                readonly property string screenName: (screenBarScope.modelData && screenBarScope.modelData.name) ? screenBarScope.modelData.name : ""
                readonly property bool monitorEnabled: {
                    let dummy = barScope.configRevision;
                    if (typeof Config !== "undefined" && Config.dataReady === false) return false;
                    return (typeof Config !== "undefined" && typeof Config.isBarEnabledOnScreen === "function")
                        ? Config.isBarEnabledOnScreen(screenBarScope.screenName)
                        : true;
                }

                LazyLoader {
                    active: screenBarScope.monitorEnabled

                    PanelWindow {
                        id: barWindowRoot
                        readonly property var modelData: screenBarScope.modelData
                        property string registeredScreenName: ""
                        visible: barConfigReady && !shouldHideForRedact

                        property bool startupFilesReady: false
                        property bool isRedacting: false

                        property bool hideBarInRedactor: {
                            let dummy = configRevision;
                            if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.widgets && Config.rawSettings.widgets.hideBarInRedactor !== undefined) {
                                return Config.rawSettings.widgets.hideBarInRedactor;
                            }
                            if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.hideBarInRedactor !== undefined) {
                                return Config.rawSettings.bar.hideBarInRedactor;
                            }
                            return true;
                        }

                        property bool shouldHideForRedact: isRedacting && hideBarInRedactor

                        readonly property bool isFullscreenActive: Compositor.isFullscreenOn(screenBarScope.modelData)

                        WlrLayershell.keyboardFocus: (barWindowRoot.isNotifOpen || barWindowRoot.isSysOpen)
                            ? Compositor.interactiveKeyboardFocus
                            : WlrKeyboardFocus.None

                        property int configRevision: 0

                        Connections {
                            target: (typeof Config !== "undefined") ? Config : null
                            function onSettingsLoaded() {
                                barWindowRoot.configRevision++;
                            }
                            function onDataReadyChanged() {
                                barWindowRoot.configRevision++;
                            }
                            function onRawSettingsChanged() {
                                barWindowRoot.configRevision++;
                            }
                        }

                        Component.onCompleted: {
                            if (typeof Config !== "undefined" && Config.dataReady) {
                                barWindowRoot.configRevision++;
                            }
                            let name = (barWindowRoot.modelData && barWindowRoot.modelData.name) ? barWindowRoot.modelData.name : (barWindowRoot.screen ? barWindowRoot.screen.name : "");
                            barWindowRoot.registeredScreenName = name;
                            if (name) {
                                SurfaceRegistry.registerWindow("bars", name, barWindowRoot);
                            }
                        }

                        Component.onDestruction: {
                            let name = barWindowRoot.registeredScreenName || ((barWindowRoot.modelData && barWindowRoot.modelData.name) ? barWindowRoot.modelData.name : "");
                            SurfaceRegistry.unregisterWindow("bars", name, barWindowRoot);
                            if (barScope.pendingReload && SurfaceRegistry.windowsOf("bars").length > 0) {
                                barScope.tryPendingReload();
                            }
                        }

                        property string barStyle: {
                            let dummy = configRevision;
                            return SurfaceRegistry.barStyle;
                        }
                        property bool isFill: barStyle === "fill"
                        property bool isSolid: barStyle === "solid" || barStyle === "fill"
                        property bool distinctPills: {
                            let dummy = configRevision;
                            return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.distinctPills !== undefined) ? Config.rawSettings.bar.distinctPills : false;
                        }
                        property bool centerByEdges: {
                            let dummy = configRevision;
                            return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.centerByEdges !== undefined) ? Config.rawSettings.bar.centerByEdges : true;
                        }

                        property bool barConfigReady: {
                            let dummy = configRevision;
                            if (typeof Config === "undefined") return true;
                            if (Config.dataReady !== undefined) return Config.dataReady;
                            return true;
                        }

                        property bool autohide: {
                            let dummy = configRevision;
                            return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohide !== undefined) ? Config.rawSettings.bar.autohide : false;
                        }
                        property int autohideTimeout: {
                            let dummy = configRevision;
                            return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohideTimeout !== undefined) ? Config.rawSettings.bar.autohideTimeout : 1000;
                        }
                        property real barOpacity: ThemeBackend.elementOpacity

                        HoverHandler {
                            id: barHover
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        }

                        readonly property bool trayMenuHovered: TrayMenuController.isVisible && TrayMenuController.menuHovered && TrayMenuController.screen === barWindowRoot.screen
                        readonly property bool pointerInside: barHover.hovered || trayMenuHovered

                        EdgeAutohideController {
                            id: autohideCtrl
                            autohide: barWindowRoot.autohide
                            timeout: barWindowRoot.autohideTimeout
                            hovered: barWindowRoot.pointerInside
                            forceHidden: barWindowRoot.shouldHideForRedact
                            positionChangeDuration: 200
                        }

                        readonly property bool isRevealed: autohideCtrl.isRevealed
                        readonly property bool positionChanging: autohideCtrl.positionChanging

                        Timer {
                            interval: 50
                            running: true
                            onTriggered: barWindowRoot.startupFilesReady = true
                        }

                        Connections {
                            target: WidgetSync
                            function onRedactModeChanged(monitor, active) {
                                let name = barWindowRoot.screen ? barWindowRoot.screen.name : "";
                                if (monitor === name || monitor === name.replace(/[^a-zA-Z0-9_-]/g, "_")) barWindowRoot.isRedacting = active;
                            }
                        }

                        function toggleUpdate() {
                            let target = barLayout.getModuleItem("left");
                            if (target && target.faceItem && typeof target.faceItem.toggleUpdate === "function") {
                                target.faceItem.toggleUpdate();
                            }
                        }

                        screen: screenBarScope.modelData

                        property string barPosition: {
                            let dummy = configRevision;
                            return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) ? Config.rawSettings.bar.position : "top";
                        }

                        onBarPositionChanged: autohideCtrl.triggerPositionChange()

                        property real barWidthPercent: {
                            let dummy = configRevision;
                            return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.width !== undefined) ? Config.rawSettings.bar.width : 100;
                        }
                        property real edgePadding: (autohide && !isFill) ? s(4) : 0
                        property real effectiveBarWidth: Math.round(isVertical ? barWindowRoot.width : ((barWindowRoot.width - (autohide ? edgePadding * 2 : 0)) * (barWidthPercent / 100.0)))
                        property real horizontalOffset: Math.round(isVertical ? 0 : ((barWindowRoot.width - effectiveBarWidth) / 2))

                        property real effectiveBarHeight: Math.round(!isVertical ? barWindowRoot.height : ((barWindowRoot.height - (autohide ? edgePadding * 2 : 0)) * (barWidthPercent / 100.0)))
                        property real verticalOffset: Math.round(!isVertical ? 0 : ((barWindowRoot.height - effectiveBarHeight) / 2))

                        property real currentBarMinX: (!isVertical && barLayout.dynamicMaxX > barLayout.dynamicMinX) ? barLayout.dynamicMinX : horizontalOffset
                        property real currentBarMaxX: (!isVertical && barLayout.dynamicMaxX > barLayout.dynamicMinX) ? barLayout.dynamicMaxX : (horizontalOffset + effectiveBarWidth)

                        property real currentBarMinY: (isVertical && barLayout.dynamicMaxY > barLayout.dynamicMinY) ? barLayout.dynamicMinY : verticalOffset
                        property real currentBarMaxY: (isVertical && barLayout.dynamicMaxY > barLayout.dynamicMinY) ? barLayout.dynamicMaxY : (verticalOffset + effectiveBarHeight)

                        property bool fillAttached: isFill && (isVertical
                            ? (currentBarMinY > 0.5 || currentBarMaxY < barWindowRoot.height - 0.5)
                            : (currentBarMinX > 0.5 || currentBarMaxX < barWindowRoot.width - 0.5))

                        property bool isVertical: barPosition === "left" || barPosition === "right"

                        property real baseScale: Scaler.baseScale

                        function s(val) {
                            return Math.round(Scaler.s(val));
                        }

                        readonly property real baseThickness: 40
                        readonly property real minThickness: 28
                        readonly property real maxThickness: 48
                        property real thicknessSetting: {
                            let dummy = configRevision;
                            let v = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height !== undefined) ? Number(Config.rawSettings.bar.height) : baseThickness;
                            if (isNaN(v)) v = baseThickness;
                            return Math.max(minThickness, Math.min(maxThickness, v));
                        }
                        property real contentRatio: thicknessSetting / baseThickness

                        function cs(val) {
                            return Math.round(Scaler.s(val) * contentRatio);
                        }

                        property int barHeight: s(thicknessSetting)
                        property real cornerRadius: s(12)

                        property real baseOffsetY: {
                            if (barPosition === "bottom") {
                                return isFill ? (barWindowRoot.height - barWindowRoot.barHeight) : (barWindowRoot.height - barWindowRoot.barHeight - edgePadding);
                            } else {
                                return isFill ? 0 : edgePadding;
                            }
                        }

                        anchors {
                            top: barPosition === "top" || barWindowRoot.isVertical
                            bottom: barPosition === "bottom" || barWindowRoot.isVertical
                            left: barPosition === "left" || !barWindowRoot.isVertical
                            right: barPosition === "right" || !barWindowRoot.isVertical
                        }

                        implicitHeight: barWindowRoot.isVertical ? 0 : (barHeight + (isFill ? cornerRadius : edgePadding))
                        implicitWidth: barWindowRoot.isVertical ? (barHeight + (isFill ? cornerRadius : edgePadding)) : 0

                        margins {
                            top: isFill ? 0 : (barPosition === "bottom" ? 0 : (autohide ? 0 : s(4)))
                            bottom: isFill ? 0 : (barPosition === "top" ? 0 : (autohide ? 0 : s(4)))
                            left: isFill ? 0 : (barPosition === "right" ? 0 : (autohide ? 0 : s(4)))
                            right: isFill ? 0 : (barPosition === "left" ? 0 : (autohide ? 0 : s(4)))
                        }

                        exclusiveZone: (!barConfigReady || autohide || shouldHideForRedact) ? 0 : barHeight
                        color: "transparent"

                        property real activeMaskHeight: shouldHideForRedact ? 0 : ((autohide && !isRevealed) ? s(4) : (isVertical ? (isFill ? barWindowRoot.height : (effectiveBarHeight + edgePadding * 2)) : (isFill ? (barHeight + cornerRadius) : (barHeight + edgePadding))))
                        property real activeMaskWidth: shouldHideForRedact ? 0 : ((autohide && !isRevealed) ? s(4) : (isVertical ? (isFill ? (barHeight + cornerRadius) : (barHeight + edgePadding)) : (isFill ? barWindowRoot.width : (effectiveBarWidth + edgePadding * 2))))

                        mask: Region {
                            Region {
                                x: barWindowRoot.isVertical ? (barWindowRoot.barPosition === "right" ? (barWindowRoot.width - barWindowRoot.activeMaskWidth) : 0) : barWindowRoot.currentBarMinX
                                y: barWindowRoot.isVertical ? barWindowRoot.currentBarMinY : (barWindowRoot.barPosition === "bottom" ? barWindowRoot.baseOffsetY : 0)
                                width: barWindowRoot.isVertical ? barWindowRoot.activeMaskWidth : (barWindowRoot.currentBarMaxX - barWindowRoot.currentBarMinX)
                                height: barWindowRoot.isVertical ? (barWindowRoot.currentBarMaxY - barWindowRoot.currentBarMinY) : (isFill ? barWindowRoot.barHeight : barWindowRoot.activeMaskHeight)
                            }
                            Region {
                                x: barWindowRoot.isVertical ? (barWindowRoot.barPosition === "right" ? (barWindowRoot.width - barWindowRoot.barHeight - barWindowRoot.cornerRadius) : barWindowRoot.barHeight) : 0
                                y: barWindowRoot.isVertical ? 0 : (barWindowRoot.barPosition === "bottom" ? (barWindowRoot.baseOffsetY - barWindowRoot.cornerRadius) : (barWindowRoot.baseOffsetY + barWindowRoot.barHeight))
                                width: (barWindowRoot.isFill && !barWindowRoot.fillAttached) ? barWindowRoot.cornerRadius : 0
                                height: (barWindowRoot.isFill && !barWindowRoot.fillAttached) ? barWindowRoot.cornerRadius : 0
                            }
                            Region {
                                x: barWindowRoot.isVertical ? (barWindowRoot.barPosition === "right" ? (barWindowRoot.width - barWindowRoot.barHeight - barWindowRoot.cornerRadius) : barWindowRoot.barHeight) : (barWindowRoot.width - barWindowRoot.cornerRadius)
                                y: barWindowRoot.isVertical ? (barWindowRoot.height - barWindowRoot.cornerRadius) : (barWindowRoot.barPosition === "bottom" ? (barWindowRoot.baseOffsetY - barWindowRoot.cornerRadius) : (barWindowRoot.baseOffsetY + barWindowRoot.barHeight))
                                width: (barWindowRoot.isFill && !barWindowRoot.fillAttached) ? barWindowRoot.cornerRadius : 0
                                height: (barWindowRoot.isFill && !barWindowRoot.fillAttached) ? barWindowRoot.cornerRadius : 0
                            }
                        }

                        property string activeWidget: ""
                        property bool isNotifOpen: activeWidget === "notifications"
                        property bool isSysOpen: activeWidget === "system"

                        onActiveWidgetChanged: {
                            if (!barWindowRoot.isNotifOpen && !barWindowRoot.isSysOpen) {
                                barScope.tryPendingReload();
                            }
                        }

                        FileView {
                            id: widgetWatcher
                            path: (barWindowRoot.startupFilesReady && Caching.runDir) ? (Caching.runDir + "/current_widget") : ""
                            watchChanges: true
                            onFileChanged: reload()
                            onLoaded: {
                                let txt = text().trim();
                                let widget = "";
                                let targetScreen = "";

                                try {
                                    let parsed = JSON.parse(txt);
                                    if (parsed && typeof parsed === "object") {
                                        widget = parsed.widget || "";
                                        targetScreen = parsed.screen || "";
                                    } else if (typeof parsed === "string") {
                                        widget = parsed;
                                    }
                                } catch (e) {
                                    widget = txt;
                                }

                                let myScreenName = (barWindowRoot.screen && barWindowRoot.screen.name) ? barWindowRoot.screen.name : "";
                                let effectiveWidget = "";
                                if (widget === "notifications" || widget === "system") {
                                    if (!targetScreen || targetScreen === myScreenName) {
                                        effectiveWidget = widget;
                                    }
                                }

                                if (barWindowRoot.activeWidget !== effectiveWidget) {
                                    barWindowRoot.activeWidget = effectiveWidget;
                                }
                            }
                        }

                        property bool isStartupReady: false
                        Timer { interval: 10; running: true; onTriggered: barWindowRoot.isStartupReady = true }

                        property bool startupCascadeFinished: false
                        Timer { interval: 1050; running: true; onTriggered: barWindowRoot.startupCascadeFinished = true }

                        property bool fastPollerLoaded: false
                        property bool isDataReady: fastPollerLoaded
                        Timer { interval: 400; running: true; onTriggered: barWindowRoot.isDataReady = true }

                        readonly property Item snapshotItem: barLayout

                        BarLayout {
                            id: barLayout
                            barWindow: barWindowRoot
                        }
                    }
                }
            }
        }
    }
}
