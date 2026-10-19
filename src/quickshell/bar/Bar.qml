import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../reusables"
import "../"

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindowRoot
            visible: barConfigReady && !shouldHideForRedact

            property bool pendingReload: false
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

            property var activeToplevel: ToplevelManager.activeToplevel
            property bool isFullscreenActive: {
                if (!activeToplevel || !activeToplevel.fullscreen) return false;
                if (activeToplevel.screens && activeToplevel.screens.length > 0) {
                    return activeToplevel.screens.indexOf(barWindowRoot.screen) !== -1;
                }
                return true;
            }

            onIsFullscreenActiveChanged: {
                if (barWindowRoot.isFullscreenActive) {
                    OsdController.isFullscreen = true;
                } else if (!OsdController.screen || OsdController.screen === barWindowRoot.screen) {
                    OsdController.isFullscreen = false;
                }
            }

            WlrLayershell.keyboardFocus: (barWindowRoot.isNotifOpen || barWindowRoot.isSysOpen)
                ? WlrKeyboardFocus.OnDemand
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
            }

            property string barStyle: {
                let dummy = configRevision;
                if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
                let s = Config.rawSettings.bar.style;
                if (typeof s === "string") return s;
                if (s && typeof s === "object") {
                    if (s.fill || s.mode === "fill") return "fill";
                    if (s.solid || s.mode === "solid") return "solid";
                }
                return "modular";
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

            Timer {
                id: hideTimer
                interval: barWindowRoot.autohideTimeout
            }

            function checkHideTimer() {
                if (!barHover.hovered && barWindowRoot.autohide) {
                    hideTimer.restart();
                } else {
                    hideTimer.stop();
                }
            }

            Connections {
                target: barHover
                function onHoveredChanged() { barWindowRoot.checkHideTimer(); }
            }

            property bool isRevealed: {
                if (shouldHideForRedact) return false;
                if (!autohide) return true;
                if (barHover.hovered) return true;
                if (hideTimer.running) return true;
                return false;
            }

            Timer {
                interval: 50
                running: true
                onTriggered: barWindowRoot.startupFilesReady = true
            }

            IpcHandler {
                target: "topbar"
                function setRedactMode(active: string): void {
                    barWindowRoot.isRedacting = (active === "true" || active === "1");
                }
                function forceReload() {
                    Quickshell.reload(true)
                }
                function queueReload() {
                    if (!barWindowRoot.isNotifOpen && !barWindowRoot.isSysOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindowRoot.pendingReload = true
                    }
                }
                function toggleUpdate() {
                    let target = null;
                    if (barWindowRoot.isVertical) target = verticalWrapper.getWidget("left");
                    else target = contentWrapper.getWidget("left");
                    if (target && typeof target.toggleUpdate === "function") {
                        target.toggleUpdate();
                    }
                }
            }

            required property var modelData
            screen: modelData

            property string barPosition: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) ? Config.rawSettings.bar.position : "top";
            }
            property bool positionChanging: false

            property real barWidthPercent: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.width !== undefined) ? Config.rawSettings.bar.width : 100;
            }
            property real edgePadding: (autohide && !isFill) ? s(4) : 0
            property real effectiveBarWidth: Math.round(isVertical ? barWindowRoot.width : ((barWindowRoot.width - (autohide ? edgePadding * 2 : 0)) * (barWidthPercent / 100.0)))
            property real horizontalOffset: Math.round(isVertical ? 0 : ((barWindowRoot.width - effectiveBarWidth) / 2))

            property real effectiveBarHeight: Math.round(!isVertical ? barWindowRoot.height : ((barWindowRoot.height - (autohide ? edgePadding * 2 : 0)) * (barWidthPercent / 100.0)))
            property real verticalOffset: Math.round(!isVertical ? 0 : ((barWindowRoot.height - effectiveBarHeight) / 2))

            property real currentBarMinX: (contentWrapper && contentWrapper.dynamicMaxX > contentWrapper.dynamicMinX) ? contentWrapper.dynamicMinX : horizontalOffset
            property real currentBarMaxX: (contentWrapper && contentWrapper.dynamicMaxX > contentWrapper.dynamicMinX) ? contentWrapper.dynamicMaxX : (horizontalOffset + effectiveBarWidth)

            property real currentBarMinY: (verticalWrapper && verticalWrapper.dynamicMaxY > verticalWrapper.dynamicMinY) ? verticalWrapper.dynamicMinY : verticalOffset
            property real currentBarMaxY: (verticalWrapper && verticalWrapper.dynamicMaxY > verticalWrapper.dynamicMinY) ? verticalWrapper.dynamicMaxY : (verticalOffset + effectiveBarHeight)

            property bool fillAttached: isFill && (isVertical
                ? (currentBarMinY > 0.5 || currentBarMaxY < barWindowRoot.height - 0.5)
                : (currentBarMinX > 0.5 || currentBarMaxX < barWindowRoot.width - 0.5))

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: barWindowRoot.positionChanging = false
            }

            onBarPositionChanged: {
                barWindowRoot.positionChanging = true;
                positionChangeTimer.restart();
            }

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
                if (!barWindowRoot.isNotifOpen && !barWindowRoot.isSysOpen && barWindowRoot.pendingReload) {
                    barWindowRoot.pendingReload = false;
                    Quickshell.reload(true);
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

            SideBar {
                id: verticalWrapper
                barWindow: barWindowRoot
                property real hideOffsetX: {
                    if (!barWindowRoot || barWindowRoot.isRevealed) return 0;
                    let offset = barWindowRoot.barHeight + barWindowRoot.edgePadding + barWindowRoot.s(10);
                    return barWindowRoot.barPosition === "right" ? offset : -offset;
                }
                transform: Translate {
                    x: verticalWrapper.hideOffsetX
                    Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                }
            }

            TopBar {
                id: contentWrapper
                barWindow: barWindowRoot
            }
        }
    }
}
