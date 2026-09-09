import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../reusables"

Variants {
    model: Quickshell.screens

    delegate: Component {
        id: dockDelegate
        Scope {
            id: dockScope
            required property var modelData

            PanelWindow {
                id: dockExclusionWindow
                screen: dockScope.modelData

                WlrLayershell.namespace: "qs-dock-exclusion"
                WlrLayershell.layer: WlrLayer.Top
                color: "transparent"
                visible: dockWindow.isEffectivelyExclusive

                exclusionMode: ExclusionMode.Normal
                exclusiveZone: dockWindow.isEffectivelyExclusive ? dockWindow.dockReservedSpace : 0

                anchors {
                    top: dockWindow.dockPosition === "top" || dockWindow.isVertical
                    bottom: dockWindow.dockPosition === "bottom" || dockWindow.isVertical
                    left: dockWindow.dockPosition === "left" || !dockWindow.isVertical
                    right: dockWindow.dockPosition === "right" || !dockWindow.isVertical
                }

                implicitHeight: dockWindow.isVertical ? 0 : dockWindow.dockReservedSpace
                implicitWidth: dockWindow.isVertical ? dockWindow.dockReservedSpace : 0

                mask: Region {}
            }

            PanelWindow {
                id: dockWindow
                property var modelData: dockScope.modelData
                screen: dockScope.modelData

                WlrLayershell.namespace: "qs-dock"
                WlrLayershell.layer: WlrLayer.Top
                focusable: dockWindow.editMode
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore

                property int configRevision: 0
                property bool initialized: false

                Timer {
                    id: initTimer
                    interval: 50
                    repeat: false
                    onTriggered: dockWindow.initialized = true
                }

                Connections {
                    target: (typeof Config !== "undefined") ? Config : null
                    function onSettingsLoaded() { dockWindow.configRevision++; }
                    function onDataReadyChanged() { dockWindow.configRevision++; }
                    function onRawSettingsChanged() { dockWindow.configRevision++; }
                }

                property var defaultDockSettings: ({
                    "enabled": true,
                    "position": "bottom",
                    "elementSize": 44,
                    "floating": false,
                    "opacity": 100,
                    "exclusive": false,
                    "autohide": false,
                    "autohideTimeout": 1000,
                    "editing": false,
                    "apps": [],
                    "overrideBoundsCorrection": false,
                    "enableScrolling": false,
                    "visibleElements": 7,
                    "scrollingElements": 7,
                    "maxVisibleElements": 7,
                    "maxElements": 7,
                    "hoverScale": 120,
                    "cascadeScale": false
                })

                property var rawDockSettings: {
                    let dummy = configRevision;
                    if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock) {
                        return Config.rawSettings.dock;
                    }
                    if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
                        return Config.getSetting("dock", defaultDockSettings);
                    }
                    return defaultDockSettings;
                }

                property var defaultLauncherSettings: ({
                    "position": "top",
                    "width": 600,
                    "itemCount": 6,
                    "terminalCommand": "kitty -e",
                    "smartRanking": true
                })

                property var rawLauncherSettings: {
                    let dummy = configRevision;
                    if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.launcher) {
                        return Config.rawSettings.launcher;
                    }
                    if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
                        return Config.getSetting("launcher", defaultLauncherSettings);
                    }
                    return defaultLauncherSettings;
                }

                property real launcherCustomWidth: (rawLauncherSettings && rawLauncherSettings.width !== undefined && !isNaN(rawLauncherSettings.width) && rawLauncherSettings.width > 0) ? rawLauncherSettings.width : 600
                property int launcherCustomItemCount: (rawLauncherSettings && rawLauncherSettings.itemCount !== undefined && !isNaN(rawLauncherSettings.itemCount) && rawLauncherSettings.itemCount > 0) ? rawLauncherSettings.itemCount : 6

                property bool dockEnabled: rawDockSettings.enabled !== undefined ? rawDockSettings.enabled : true
                property string dockPosition: rawDockSettings.position !== undefined ? rawDockSettings.position : "bottom"
                property int rawElementSize: rawDockSettings.elementSize !== undefined ? rawDockSettings.elementSize : 44
                property bool overrideBoundsCorrection: rawDockSettings.overrideBoundsCorrection !== undefined ? Boolean(rawDockSettings.overrideBoundsCorrection) : false

                property bool dockExclusive: {
                    let val = undefined;
                    if (rawDockSettings) {
                        val = rawDockSettings.exclusive !== undefined ? rawDockSettings.exclusive : rawDockSettings.exclusiveMode;
                    }
                    if (val === undefined && typeof Config !== "undefined" && Config.rawSettings) {
                        val = Config.rawSettings["dock.exclusive"] !== undefined ? Config.rawSettings["dock.exclusive"] : Config.rawSettings["dock.exclusiveMode"];
                    }
                    if (val === undefined || val === null) return false;
                    if (typeof val === "boolean") return val;
                    if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
                    return Boolean(val);
                }

                readonly property bool isEffectivelyExclusive: dockWindow.initialized && dockEnabled && dockExclusive && !autohide && !isFullscreenActive && !editMode && (dockAppsModel.count > 0)
                readonly property int dockReservedSpace: Math.round(dockContainer.fullThickness + effectiveMargin)

                property real dockHoverScaleMultiplier: {
                    let val = undefined;
                    if (rawDockSettings && rawDockSettings.hoverScale !== undefined) {
                        val = rawDockSettings.hoverScale;
                    } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.hoverScale"] !== undefined) {
                        val = Config.rawSettings["dock.hoverScale"];
                    }
                    let parsed = parseFloat(val);
                    if (isNaN(parsed) || parsed < 100) return 1.20;
                    return parsed / 100.0;
                }

                property bool dockCascadeScale: {
                    let val = undefined;
                    if (rawDockSettings && rawDockSettings.cascadeScale !== undefined) {
                        val = rawDockSettings.cascadeScale;
                    } else if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings["dock.cascadeScale"] !== undefined) {
                        val = Config.rawSettings["dock.cascadeScale"];
                    }
                    if (val === undefined || val === null) return false;
                    if (typeof val === "boolean") return val;
                    if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
                    return Boolean(val);
                }

                property bool enableScrolling: {
                    let val = undefined;
                    if (rawDockSettings) {
                        val = rawDockSettings.enableScrolling !== undefined ? rawDockSettings.enableScrolling :
                              (rawDockSettings.scrollingEnabled !== undefined ? rawDockSettings.scrollingEnabled :
                              (rawDockSettings.scrollEnabled !== undefined ? rawDockSettings.scrollEnabled :
                              (rawDockSettings.scrolling !== undefined ? rawDockSettings.scrolling : undefined)));
                    }
                    if (val === undefined && typeof Config !== "undefined" && Config.rawSettings) {
                        val = Config.rawSettings["dock.enableScrolling"] !== undefined ? Config.rawSettings["dock.enableScrolling"] :
                              (Config.rawSettings["dock.scrollingEnabled"] !== undefined ? Config.rawSettings["dock.scrollingEnabled"] :
                              (Config.rawSettings["enableScrolling"] !== undefined ? Config.rawSettings["enableScrolling"] : undefined));
                    }
                    if (val === undefined || val === null) return false;
                    if (typeof val === "boolean") return val;
                    if (typeof val === "string") return val.toLowerCase() === "true" || val === "1";
                    if (typeof val === "number") return val !== 0;
                    return Boolean(val);
                }

                property int dockVisibleElements: {
                    let val = undefined;
                    if (rawDockSettings) {
                        val = rawDockSettings.visibleElements !== undefined ? rawDockSettings.visibleElements :
                              (rawDockSettings.scrollingElements !== undefined ? rawDockSettings.scrollingElements :
                              (rawDockSettings.maxVisibleElements !== undefined ? rawDockSettings.maxVisibleElements :
                              (rawDockSettings.maxElements !== undefined ? rawDockSettings.maxElements :
                              (rawDockSettings.visibleItems !== undefined ? rawDockSettings.visibleItems :
                              (rawDockSettings.scrollElements !== undefined ? rawDockSettings.scrollElements :
                              (rawDockSettings.scrollingLimit !== undefined ? rawDockSettings.scrollingLimit :
                              (rawDockSettings.scrollingItemCount !== undefined ? rawDockSettings.scrollingItemCount :
                              (rawDockSettings.itemCount !== undefined ? rawDockSettings.itemCount : undefined))))))));
                    }
                    if (val === undefined && typeof Config !== "undefined" && Config.rawSettings) {
                        val = Config.rawSettings["dock.visibleElements"] !== undefined ? Config.rawSettings["dock.visibleElements"] :
                              (Config.rawSettings["dock.scrollingElements"] !== undefined ? Config.rawSettings["dock.scrollingElements"] :
                              (Config.rawSettings["visibleElements"] !== undefined ? Config.rawSettings["visibleElements"] : undefined));
                    }
                    let parsed = parseInt(val);
                    return (!isNaN(parsed) && parsed > 0) ? parsed : 7;
                }

                property int dockElementSize: {
                    if (overrideBoundsCorrection) return rawElementSize;
                    if (enableScrolling) return rawElementSize;
                    let countToCheck = editMode ? (dockContainer.effectiveItemCount + 1) : dockContainer.effectiveItemCount;
                    if (countToCheck <= 0) return rawElementSize;
                    let avail = (isVertical ? dockWindow.height : dockWindow.width) - s(40) - (sameSideAsBar ? barHeight : 0);
                    let spacing = editMode ? s(10) : s(8);
                    let pad = s(20);
                    let needed = countToCheck * s(rawElementSize) + Math.max(0, countToCheck - 1) * spacing + pad;
                    if (needed > avail) {
                        let maxElemPx = (avail - pad - Math.max(0, countToCheck - 1) * spacing) / countToCheck;
                        let scaleRatio = s(100) / 100.0;
                        if (scaleRatio <= 0) scaleRatio = 1.0;
                        let adjusted = Math.floor(maxElemPx / scaleRatio);
                        return Math.max(20, Math.min(rawElementSize, adjusted));
                    }
                    return rawElementSize;
                }

                property bool rawDockFloating: rawDockSettings.floating !== undefined ? rawDockSettings.floating : false
                property bool dockFloating: rawDockFloating || (sameSideAsBar && !isBarSolid)
                property real dockOpacitySetting: {
                    if (rawDockSettings.opacity !== undefined) return Number(rawDockSettings.opacity);
                    if (rawDockSettings.transparency !== undefined) return Math.max(0, 100 - Number(rawDockSettings.transparency));
                    return 100;
                }
                readonly property real dockOpacity: Math.max(0.0, Math.min(1.0, dockOpacitySetting / 100.0))
                property real floatingMargin: dockFloating ? s(8) : 0
                Behavior on floatingMargin {
                    enabled: dockWindow.initialized && !dockWindow.positionChanging
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }
                property bool autohide: rawDockSettings.autohide !== undefined ? rawDockSettings.autohide : false
                property int autohideTimeout: rawDockSettings.autohideTimeout !== undefined ? rawDockSettings.autohideTimeout : 1000
                property real autohideHitSize: s(18)
                property bool editMode: rawDockSettings.editing !== undefined ? rawDockSettings.editing : false

                property real editMargin: (editMode && !dockFloating) ? s(20) : 0
                Behavior on editMargin {
                    enabled: dockWindow.initialized && !dockWindow.positionChanging
                    NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                }
                readonly property real effectiveMargin: floatingMargin + editMargin

                property int dragSourceIndex: -1
                property int dropTargetIndex: -1

                property bool positionChanging: false

                Timer {
                    id: positionChangeTimer
                    interval: 300
                    onTriggered: dockWindow.positionChanging = false
                }

                onDockPositionChanged: {
                    dockWindow.positionChanging = true;
                    dockContainer.scrollIndex = 0;
                    dockContainer.hoveredItemIndex = -1;
                    positionChangeTimer.restart();
                }

                visible: dockWindow.initialized && dockEnabled && !isFullscreenActive && (dockAppsModel.count > 0 || editMode)

                property var rawBarSettings: {
                    let dummy = configRevision;
                    return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
                }

                property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
                property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false
                property real barHeight: (rawBarSettings && rawBarSettings.height !== undefined) ? s(rawBarSettings.height) : s(40)

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
                readonly property bool isBarSolid: barStyle === "solid" || barStyle === "fill"

                readonly property bool isOsdFullscreen: (typeof OsdController !== "undefined") ? Boolean(OsdController.isFullscreen) : false
                readonly property bool isToplevelFullscreen: {
                    try {
                        if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen) {
                            let atl = ToplevelManager.activeToplevel;
                            if (atl.screens && atl.screens.length > 0) {
                                return atl.screens.indexOf(dockWindow.screen) !== -1;
                            }
                            return true;
                        }
                    } catch (e) {}
                    return false;
                }
                readonly property bool isHyprlandFullscreen: {
                    try {
                        if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                            return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
                        }
                    } catch (e) {}
                    return false;
                }
                readonly property bool isFullscreenActive: isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen

                readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive
                readonly property bool sameSideAsBar: (dockPosition === barPosition) && !isBarEffectivelyHidden
                readonly property real barMarginOffset: (!isBarSolid && !barAutohide) ? s(4) : 0
                readonly property real barOffset: sameSideAsBar ? (barHeight + barMarginOffset) : 0

                readonly property bool isVertical: dockPosition === "left" || dockPosition === "right"

                function s(val) {
                    return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
                }

                property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
                property real outerCornerRadius: cornerRadius

                property real dockTotalLength: {
                    let len = (isVertical ? dockContainer.baseHeight : dockContainer.baseWidth) + (dockContainer.isAttached ? outerCornerRadius * 2 : 0) + s(12);
                    return len * 1.2;
                }

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                Timer {
                    id: hideTimer
                    interval: dockWindow.autohideTimeout
                }

                function checkHideTimer() {
                    if (!dockHover.hovered && !edgeHover.hovered && dockWindow.autohide && !dockWindow.editMode) {
                        hideTimer.restart();
                    } else {
                        hideTimer.stop();
                    }
                }

                Connections {
                    target: dockHover
                    function onHoveredChanged() { dockWindow.checkHideTimer(); }
                }

                property bool isRevealed: {
                    if (isFullscreenActive) return false;
                    if (editMode) return true;
                    if (!autohide) return true;
                    if (dockHover.hovered) return true;
                    if (edgeHover.hovered) return true;
                    if (hideTimer.running) return true;
                    return false;
                }

                ListModel {
                    id: dockAppsModel
                }

                function loadApps() {
                    let customApps = rawDockSettings.apps;
                    if (!customApps || !Array.isArray(customApps)) customApps = [];
                    if (dockAppsModel.count === customApps.length) {
                        let matches = true;
                        for (let i = 0; i < customApps.length; i++) {
                            let cur = dockAppsModel.get(i);
                            let app = customApps[i];
                            let id = app.desktop_id || app.id || "";
                            if (!cur || cur.desktop_id !== id || cur.name !== (app.name || "") || cur.icon !== (app.icon || "")) {
                                matches = false;
                                break;
                            }
                        }
                        if (matches) return;
                    }
                    dockAppsModel.clear();
                    for (let k = 0; k < customApps.length; k++) {
                        let app = customApps[k];
                        dockAppsModel.append({
                            name: app.name || "",
                            comment: app.comment || "",
                            desktop_id: app.desktop_id || app.id || "",
                            icon: app.icon || ""
                        });
                    }
                }

                function saveApps() {
                    let arr = [];
                    for (let i = 0; i < dockAppsModel.count; i++) {
                        let item = dockAppsModel.get(i);
                        if (item) {
                            arr.push({
                                "name": item.name || "",
                                "comment": item.comment || "",
                                "desktop_id": item.desktop_id || "",
                                "icon": item.icon || ""
                            });
                        }
                    }
                    let current = JSON.parse(JSON.stringify(rawDockSettings || defaultDockSettings));
                    current.apps = arr;
                    current.visibleElements = dockVisibleElements;
                    current.enableScrolling = enableScrolling;
                    current.exclusive = dockExclusive;
                    if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
                        Config.setSetting("dock", current);
                    }
                }

                function isAppInDock(desktopId) {
                    if (!desktopId) return false;
                    for (let i = 0; i < dockAppsModel.count; i++) {
                        let it = dockAppsModel.get(i);
                        if (it && it.desktop_id === desktopId) return true;
                    }
                    return false;
                }

                function addApp(entry) {
                    if (!entry) return;
                    let id = entry.id || entry.desktop_id || "";
                    if (isAppInDock(id)) return;
                    dockAppsModel.append({
                        name: entry.name || "",
                        comment: entry.comment || "",
                        desktop_id: id,
                        icon: entry.icon || ""
                    });
                    saveApps();
                }

                function removeAppByDesktopId(desktopId) {
                    for (let i = 0; i < dockAppsModel.count; i++) {
                        let it = dockAppsModel.get(i);
                        if (it && it.desktop_id === desktopId) {
                            dockAppsModel.remove(i, 1);
                            saveApps();
                            return;
                        }
                    }
                }

                function setEditMode(val) {
                    let current = JSON.parse(JSON.stringify(rawDockSettings || defaultDockSettings));
                    current.editing = val;
                    current.visibleElements = dockVisibleElements;
                    current.enableScrolling = enableScrolling;
                    current.exclusive = dockExclusive;
                    if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
                        Config.setSetting("dock", current);
                    }
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx(val ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
                    }
                }

                function grabPickerFocus() {
                    if (pickerSearchInput) {
                        pickerSearchInput.forceActiveFocus();
                        if (typeof pickerSearchInput.forceInputFocus === "function") {
                            pickerSearchInput.forceInputFocus();
                        }
                    }
                }

                Timer {
                    id: pickerFocusTimer
                    interval: 50
                    repeat: false
                    onTriggered: dockWindow.grabPickerFocus()
                }

                Timer {
                    id: pickerFocusRetryTimer
                    interval: 150
                    repeat: false
                    onTriggered: dockWindow.grabPickerFocus()
                }

                Timer {
                    id: pickerFocusFinalTimer
                    interval: 300
                    repeat: false
                    onTriggered: dockWindow.grabPickerFocus()
                }

                property var allDesktopApps: []
                ListModel { id: pickerFilteredModel }

                function loadAllDesktopApps() {
                    let list = [];
                    if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) {
                        let entries = DesktopEntries.applications.values;
                        for (let i = 0; i < entries.length; i++) {
                            let e = entries[i];
                            if (e.noDisplay) continue;
                            list.push({
                                id: e.id || "",
                                name: e.name || "",
                                comment: e.comment || "",
                                icon: e.icon || ""
                            });
                        }
                    }
                    list.sort(function(a, b) {
                        return (a.name || "").localeCompare(b.name || "");
                    });
                    dockWindow.allDesktopApps = list;
                    let currentQuery = (pickerSearchInput && pickerSearchInput.text !== undefined) ? pickerSearchInput.text : "";
                    filterPickerApps(currentQuery);
                }

                function filterPickerApps(query) {
                    pickerFilteredModel.clear();
                    let q = (query || "").trim().toLowerCase();
                    for (let i = 0; i < allDesktopApps.length; i++) {
                        let app = allDesktopApps[i];
                        if (!q || app.name.toLowerCase().includes(q) || app.comment.toLowerCase().includes(q) || app.id.toLowerCase().includes(q)) {
                            pickerFilteredModel.append({
                                id: app.id || "",
                                name: app.name || "",
                                comment: app.comment || "",
                                icon: app.icon || "",
                                modelData: app
                            });
                        }
                    }
                }

                onEditModeChanged: {
                    dockContainer.hoveredItemIndex = -1;
                    if (editMode) {
                        loadAllDesktopApps();
                        pickerFocusTimer.restart();
                        pickerFocusRetryTimer.restart();
                        pickerFocusFinalTimer.restart();
                    } else {
                        if (pickerSearchInput && typeof pickerSearchInput.clear === "function") {
                            pickerSearchInput.clear();
                        } else if (pickerSearchInput && pickerSearchInput.text !== undefined) {
                            pickerSearchInput.text = "";
                        }
                        pickerFocusTimer.stop();
                        pickerFocusRetryTimer.stop();
                        pickerFocusFinalTimer.stop();
                    }
                }

                function launchApp(desktopId) {
                    if (typeof DesktopEntries !== "undefined") {
                        let entry = DesktopEntries.byId(desktopId);
                        if (entry) {
                            entry.execute();
                        }
                    }
                }

                Component.onCompleted: {
                    loadApps();
                    loadAllDesktopApps();
                    initTimer.start();
                }

                onConfigRevisionChanged: loadApps()

                Connections {
                    target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
                    function onValuesChanged() {
                        dockWindow.loadAllDesktopApps();
                    }
                }

                mask: Region {
                    Region {
                        item: dockWindow.editMode ? dismissArea : null
                    }
                    Region {
                        item: (dockWindow.isRevealed || dockContainer.revealProgress > 0.01) ? dockMaskArea : null
                    }
                    Region {
                        item: edgeTrigger
                    }
                    Region {
                        item: dockWindow.editMode ? appPicker : null
                    }
                }

                Item {
                    id: dismissArea
                    width: dockWindow.width
                    height: dockWindow.height
                    visible: dockWindow.editMode
                    z: -1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: dockWindow.setEditMode(false)
                    }

                    Keys.onEscapePressed: function(event) {
                        dockWindow.setEditMode(false);
                        event.accepted = true;
                    }
                }

                Item {
                    id: edgeTrigger
                    visible: dockWindow.autohide && !dockWindow.isFullscreenActive && !dockWindow.editMode
                    x: {
                        if (dockWindow.isVertical) {
                            if (dockWindow.dockPosition === "right") {
                                return parent.width - width - dockWindow.barOffset;
                            }
                            if (dockWindow.dockPosition === "left") {
                                return dockWindow.barOffset;
                            }
                            return 0;
                        }
                        return Math.round((parent.width - width) / 2);
                    }
                    y: {
                        if (!dockWindow.isVertical) {
                            if (dockWindow.dockPosition === "bottom") {
                                return parent.height - height - dockWindow.barOffset;
                            }
                            if (dockWindow.dockPosition === "top") {
                                return dockWindow.barOffset;
                            }
                            return 0;
                        }
                        return Math.round((parent.height - height) / 2);
                    }
                    width: dockWindow.isVertical ? dockWindow.autohideHitSize : Math.min(parent.width, dockWindow.dockTotalLength)
                    height: dockWindow.isVertical ? Math.min(parent.height, dockWindow.dockTotalLength) : dockWindow.autohideHitSize

                    HoverHandler {
                        id: edgeHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onHoveredChanged: dockWindow.checkHideTimer()
                    }
                }

                Item {
                    id: dockMaskArea
                    x: dockContainer.x - (dockContainer.isAttached && !dockWindow.isVertical ? dockWindow.outerCornerRadius : 0) + dockTransform.x - dockWindow.s(6)
                    y: dockContainer.y - (dockContainer.isAttached && dockWindow.isVertical ? dockWindow.outerCornerRadius : 0) + dockTransform.y - dockWindow.s(6)
                    width: dockContainer.width + (dockContainer.isAttached && !dockWindow.isVertical ? dockWindow.outerCornerRadius * 2 : 0) + dockWindow.s(12)
                    height: dockContainer.height + (dockContainer.isAttached && dockWindow.isVertical ? dockWindow.outerCornerRadius * 2 : 0) + dockWindow.s(12)
                }

                Item {
                    id: dragOverlay
                    anchors.fill: parent
                    z: 999999
                }

                Item {
                    id: dockContainer

                    readonly property bool isAttached: !dockWindow.dockFloating && !dockWindow.editMode && !(dockWindow.sameSideAsBar && !dockWindow.isBarSolid)
                    property real outerCornerProgress: isAttached ? 1.0 : 0.0

                    Behavior on outerCornerProgress {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation {
                            duration: dockContainer.isAttached ? 240 : 320
                            easing.type: dockContainer.isAttached ? Easing.OutQuad : Easing.InQuad
                        }
                    }

                    property real dynamicCornerRadius: (dockWindow.dockFloating || dockWindow.editMode)
                        ? ThemeBackend.borderRadius
                        : Math.max(0, Math.min(dockWindow.outerCornerRadius, (dockWindow.isVertical ? width : height) * 0.5))

                    Behavior on dynamicCornerRadius {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    readonly property int placeholderCount: 6
                    property int totalItemCount: {
                        if (dockAppsModel.count > 0) return dockAppsModel.count;
                        if (dockWindow.editMode) return placeholderCount;
                        return 0;
                    }
                    property int effectiveItemCount: {
                        if (dockWindow.enableScrolling && totalItemCount > 0) {
                            return Math.min(totalItemCount, Math.max(1, dockWindow.dockVisibleElements));
                        }
                        return totalItemCount;
                    }

                    property int scrollIndex: 0
                    readonly property int maxScrollIndex: Math.max(0, totalItemCount - effectiveItemCount)

                    property int hoveredItemIndex: -1

                    Timer {
                        id: hoverResetTimer
                        interval: 80
                        repeat: false
                        onTriggered: dockContainer.hoveredItemIndex = -1
                    }

                    function checkHoverReset() {
                        hoverResetTimer.restart();
                    }

                    function cancelHoverReset() {
                        hoverResetTimer.stop();
                    }

                    onTotalItemCountChanged: {
                        if (scrollIndex > maxScrollIndex) scrollIndex = maxScrollIndex;
                    }
                    onEffectiveItemCountChanged: {
                        if (scrollIndex > maxScrollIndex) scrollIndex = maxScrollIndex;
                    }

                    function scrollNext() {
                        if (scrollIndex < maxScrollIndex) scrollIndex++;
                    }

                    function scrollPrev() {
                        if (scrollIndex > 0) scrollIndex--;
                    }

                    WheelHandler {
                        id: dockWheelHandler
                        target: null
                        orientation: Qt.Vertical | Qt.Horizontal
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            if (!dockWindow.enableScrolling) return;
                            let dy = (event.angleDelta && event.angleDelta.y !== 0) ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0);
                            let dx = (event.angleDelta && event.angleDelta.x !== 0) ? event.angleDelta.x : (event.pixelDelta ? event.pixelDelta.x : 0);
                            let delta = Math.abs(dy) >= Math.abs(dx) ? dy : dx;
                            if (delta < 0) {
                                dockContainer.scrollNext();
                            } else if (delta > 0) {
                                dockContainer.scrollPrev();
                            }
                            event.accepted = true;
                        }
                    }

                    property real itemSpacing: dockWindow.editMode ? dockWindow.s(10) : dockWindow.s(8)
                    property real itemSize: dockWindow.s(dockWindow.dockElementSize)
                    property real itemStep: itemSize + itemSpacing

                    property real dockContentLength: effectiveItemCount * itemSize + Math.max(0, effectiveItemCount - 1) * itemSpacing
                    property real dockThickness: itemSize

                    property real fullThickness: dockThickness + dockWindow.s(16)
                    property real fullContentLength: dockContentLength + dockWindow.s(20)

                    property real baseWidth: Math.round(dockWindow.isVertical ? fullThickness : fullContentLength)
                    property real baseHeight: Math.round(dockWindow.isVertical ? fullContentLength : fullThickness)

                    Behavior on baseWidth {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                    Behavior on baseHeight {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    property real revealProgress: dockWindow.isRevealed ? 1.0 : 0.0
                    Behavior on revealProgress {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation {
                            duration: dockWindow.isRevealed ? 240 : 180
                            easing.type: dockWindow.isRevealed ? Easing.OutCubic : Easing.InCubic
                        }
                    }

                    width: (dockWindow.sameSideAsBar && dockWindow.isVertical)
                        ? Math.round(baseWidth * revealProgress)
                        : baseWidth

                    height: (dockWindow.sameSideAsBar && !dockWindow.isVertical)
                        ? Math.round(baseHeight * revealProgress)
                        : baseHeight

                    x: {
                        if (!dockWindow.isVertical) return Math.round((dockWindow.width - width) / 2);
                        if (dockWindow.dockPosition === "left") {
                            return Math.round(dockWindow.barOffset + dockWindow.effectiveMargin);
                        }
                        if (dockWindow.dockPosition === "right") {
                            return Math.round(dockWindow.width - width - dockWindow.barOffset - dockWindow.effectiveMargin);
                        }
                        return Math.round((dockWindow.width - width) / 2);
                    }

                    y: {
                        if (dockWindow.isVertical) return Math.round((dockWindow.height - height) / 2);
                        if (dockWindow.dockPosition === "top") {
                            return Math.round(dockWindow.barOffset + dockWindow.effectiveMargin);
                        }
                        if (dockWindow.dockPosition === "bottom") {
                            return Math.round(dockWindow.height - height - dockWindow.barOffset - dockWindow.effectiveMargin);
                        }
                        return Math.round((dockWindow.height - height) / 2);
                    }

                    Behavior on x {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging && dockWindow.isVertical && !dockWindow.sameSideAsBar
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging && !dockWindow.isVertical && !dockWindow.sameSideAsBar
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }

                    property real hideOffset: {
                        if (dockWindow.isVertical) {
                            let dist = width + dockWindow.barOffset + dockWindow.effectiveMargin + dockWindow.s(20);
                            return dockWindow.dockPosition === "left" ? -dist : dist;
                        } else {
                            let dist = height + dockWindow.barOffset + dockWindow.effectiveMargin + dockWindow.s(20);
                            return dockWindow.dockPosition === "top" ? -dist : dist;
                        }
                    }

                    transform: Translate {
                        id: dockTransform
                        x: (!dockWindow.sameSideAsBar && dockWindow.isVertical) ? (dockWindow.isRevealed ? 0 : dockContainer.hideOffset) : 0
                        y: (!dockWindow.sameSideAsBar && !dockWindow.isVertical) ? (dockWindow.isRevealed ? 0 : dockContainer.hideOffset) : 0

                        Behavior on x {
                            enabled: dockWindow.initialized && !dockWindow.positionChanging && !dockWindow.sameSideAsBar
                            NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                        }
                        Behavior on y {
                            enabled: dockWindow.initialized && !dockWindow.positionChanging && !dockWindow.sameSideAsBar
                            NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                        }
                    }

                    HoverHandler {
                        id: dockHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onHoveredChanged: {
                            if (!hovered) {
                                dockContainer.hoveredItemIndex = -1;
                                dockContainer.cancelHoverReset();
                            }
                        }
                    }

                    function calculateDropIndex(mx, my) {
                        if (dockAppsModel.count <= 1) return 0;
                        let spacing = itemSpacing;
                        let size = itemSize;
                        let step = size + spacing;
                        if (dockWindow.isVertical) {
                            let layoutY = dockViewport.y + dockLayout.y;
                            let relY = my - layoutY;
                            let idx = Math.floor((relY + spacing / 2) / step);
                            return Math.max(0, Math.min(dockAppsModel.count - 1, idx));
                        } else {
                            let layoutX = dockViewport.x + dockLayout.x;
                            let relX = mx - layoutX;
                            let idx = Math.floor((relX + spacing / 2) / step);
                            return Math.max(0, Math.min(dockAppsModel.count - 1, idx));
                        }
                    }

                    Item {
                        id: dockBgWrapper
                        anchors.fill: parent
                        opacity: dockWindow.dockOpacity
                        layer.enabled: dockWindow.dockOpacity < 1.0

                        Rectangle {
                            id: dockBg
                            anchors.fill: parent
                            radius: dockContainer.dynamicCornerRadius
                            color: ThemeBackend.base
                            border.width: (dockWindow.dockFloating || dockWindow.editMode || dockContainer.outerCornerProgress < 0.99) ? 1 : 0
                            border.color: (dockWindow.dockFloating || dockWindow.editMode || dockContainer.outerCornerProgress < 0.99) ? Qt.alpha(ThemeBackend.surface1, 0.4 * (1.0 - dockContainer.outerCornerProgress * 0.5)) : "transparent"
                            clip: true

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "bottom" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: 0
                                y: parent.height - dockWindow.outerCornerRadius
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "bottom" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: parent.width - dockWindow.outerCornerRadius
                                y: parent.height - dockWindow.outerCornerRadius
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "top" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: 0
                                y: 0
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "top" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: parent.width - dockWindow.outerCornerRadius
                                y: 0
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "left" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: 0
                                y: 0
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "left" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: 0
                                y: parent.height - dockWindow.outerCornerRadius
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "right" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: parent.width - dockWindow.outerCornerRadius
                                y: 0
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }

                            Rectangle {
                                visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "right" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                                opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                                x: parent.width - dockWindow.outerCornerRadius
                                y: parent.height - dockWindow.outerCornerRadius
                                width: dockWindow.outerCornerRadius
                                height: dockWindow.outerCornerRadius
                                color: ThemeBackend.base
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "bottom" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: -dockWindow.outerCornerRadius
                            y: parent.height - dockWindow.outerCornerRadius
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: 0
                                startY: dockWindow.outerCornerRadius
                                PathLine { x: dockWindow.outerCornerRadius; y: dockWindow.outerCornerRadius }
                                PathLine { x: dockWindow.outerCornerRadius; y: 0 }
                                PathArc {
                                    x: 0
                                    y: dockWindow.outerCornerRadius
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Clockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "bottom" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: parent.width
                            y: parent.height - dockWindow.outerCornerRadius
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: dockWindow.outerCornerRadius
                                startY: dockWindow.outerCornerRadius
                                PathLine { x: 0; y: dockWindow.outerCornerRadius }
                                PathLine { x: 0; y: 0 }
                                PathArc {
                                    x: dockWindow.outerCornerRadius
                                    y: dockWindow.outerCornerRadius
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Counterclockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "top" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: -dockWindow.outerCornerRadius
                            y: 0
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: 0
                                startY: 0
                                PathLine { x: dockWindow.outerCornerRadius; y: 0 }
                                PathLine { x: dockWindow.outerCornerRadius; y: dockWindow.outerCornerRadius }
                                PathArc {
                                    x: 0
                                    y: 0
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Counterclockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "top" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.height >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: parent.width
                            y: 0
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: dockWindow.outerCornerRadius
                                startY: 0
                                PathLine { x: 0; y: 0 }
                                PathLine { x: 0; y: dockWindow.outerCornerRadius }
                                PathArc {
                                    x: dockWindow.outerCornerRadius
                                    y: 0
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Clockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "left" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: 0
                            y: -dockWindow.outerCornerRadius
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: 0
                                startY: 0
                                PathLine { x: 0; y: dockWindow.outerCornerRadius }
                                PathLine { x: dockWindow.outerCornerRadius; y: dockWindow.outerCornerRadius }
                                PathArc {
                                    x: 0
                                    y: 0
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Clockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "left" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: 0
                            y: parent.height
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: 0
                                startY: dockWindow.outerCornerRadius
                                PathLine { x: 0; y: 0 }
                                PathLine { x: dockWindow.outerCornerRadius; y: 0 }
                                PathArc {
                                    x: 0
                                    y: dockWindow.outerCornerRadius
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Counterclockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "right" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: parent.width - dockWindow.outerCornerRadius
                            y: -dockWindow.outerCornerRadius
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: dockWindow.outerCornerRadius
                                startY: 0
                                PathLine { x: dockWindow.outerCornerRadius; y: dockWindow.outerCornerRadius }
                                PathLine { x: 0; y: dockWindow.outerCornerRadius }
                                PathArc {
                                    x: dockWindow.outerCornerRadius
                                    y: 0
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Counterclockwise
                                }
                            }
                        }

                        Shape {
                            visible: dockContainer.outerCornerProgress > 0.001 && dockWindow.dockPosition === "right" && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || dockContainer.width >= dockWindow.outerCornerRadius)
                            opacity: dockContainer.outerCornerProgress * (dockWindow.sameSideAsBar ? dockContainer.revealProgress : 1.0)
                            x: parent.width - dockWindow.outerCornerRadius
                            y: parent.height
                            width: dockWindow.outerCornerRadius
                            height: dockWindow.outerCornerRadius
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: ThemeBackend.base
                                strokeColor: "transparent"
                                startX: dockWindow.outerCornerRadius
                                startY: dockWindow.outerCornerRadius
                                PathLine { x: dockWindow.outerCornerRadius; y: 0 }
                                PathLine { x: 0; y: 0 }
                                PathArc {
                                    x: dockWindow.outerCornerRadius
                                    y: dockWindow.outerCornerRadius
                                    radiusX: dockWindow.outerCornerRadius
                                    radiusY: dockWindow.outerCornerRadius
                                    direction: PathArc.Clockwise
                                }
                            }
                        }
                    }

                    Item {
                        id: dockViewport
                        x: {
                            if (dockWindow.sameSideAsBar && dockWindow.isVertical) {
                                if (dockWindow.dockPosition === "left") return 0;
                                if (dockWindow.dockPosition === "right") return Math.round(dockContainer.width - width);
                            }
                            return Math.round((dockContainer.width - width) / 2);
                        }
                        y: {
                            if (dockWindow.sameSideAsBar && !dockWindow.isVertical) {
                                if (dockWindow.dockPosition === "top") return 0;
                                if (dockWindow.dockPosition === "bottom") return Math.round(dockContainer.height - height);
                            }
                            return Math.round((dockContainer.height - height) / 2);
                        }

                        width: dockWindow.isVertical ? Math.min(dockContainer.width, dockContainer.dockThickness + dockWindow.s(16)) : dockContainer.dockContentLength
                        height: dockWindow.isVertical ? dockContainer.dockContentLength : Math.min(dockContainer.height, dockContainer.dockThickness + dockWindow.s(16))
                        clip: dockWindow.enableScrolling && (dockContainer.totalItemCount > dockContainer.effectiveItemCount)
                        visible: width > 0 && height > 0

                        GridLayout {
                            id: dockLayout
                            columns: dockWindow.isVertical ? 1 : Math.max(1, dockContainer.totalItemCount)
                            rows: dockWindow.isVertical ? Math.max(1, dockContainer.totalItemCount) : 1
                            columnSpacing: dockContainer.itemSpacing
                            rowSpacing: dockContainer.itemSpacing
                            width: implicitWidth
                            height: implicitHeight

                            Behavior on columnSpacing {
                                enabled: dockWindow.initialized && !dockWindow.positionChanging
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }
                            Behavior on rowSpacing {
                                enabled: dockWindow.initialized && !dockWindow.positionChanging
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            x: {
                                if (dockWindow.isVertical) {
                                    if (dockWindow.sameSideAsBar && dockWindow.dockPosition === "right") {
                                        return Math.round(dockViewport.width - width - dockWindow.s(8));
                                    }
                                    if (dockWindow.sameSideAsBar && dockWindow.dockPosition === "left") {
                                        return Math.round(dockWindow.s(8));
                                    }
                                    return Math.round((dockViewport.width - width) / 2);
                                }
                                if (!dockWindow.enableScrolling || dockContainer.totalItemCount <= dockContainer.effectiveItemCount) {
                                    return 0;
                                }
                                return Math.round(-dockContainer.scrollIndex * dockContainer.itemStep);
                            }

                            y: {
                                if (!dockWindow.isVertical) {
                                    if (dockWindow.sameSideAsBar && dockWindow.dockPosition === "bottom") {
                                        return Math.round(dockViewport.height - height - dockWindow.s(8));
                                    }
                                    if (dockWindow.sameSideAsBar && dockWindow.dockPosition === "top") {
                                        return Math.round(dockWindow.s(8));
                                    }
                                    return Math.round((dockViewport.height - height) / 2);
                                }
                                if (!dockWindow.enableScrolling || dockContainer.totalItemCount <= dockContainer.effectiveItemCount) {
                                    return 0;
                                }
                                return Math.round(-dockContainer.scrollIndex * dockContainer.itemStep);
                            }

                            Behavior on x {
                                enabled: dockWindow.initialized && dockWindow.enableScrolling && dockContainer.revealProgress >= 0.99 && !dockWindow.positionChanging
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                            Behavior on y {
                                enabled: dockWindow.initialized && dockWindow.enableScrolling && dockContainer.revealProgress >= 0.99 && !dockWindow.positionChanging
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }

                            Repeater {
                                model: dockAppsModel

                                delegate: Item {
                                    id: dockButton
                                    implicitWidth: dockWindow.s(dockWindow.dockElementSize)
                                    implicitHeight: dockWindow.s(dockWindow.dockElementSize)
                                    Layout.preferredWidth: dockWindow.s(dockWindow.dockElementSize)
                                    Layout.preferredHeight: dockWindow.s(dockWindow.dockElementSize)
                                    Layout.alignment: Qt.AlignCenter
                                    z: (dockButton.isBeingDragged || dockWindow.dragSourceIndex === index) ? 99999 : Math.round(btnShape.scale * 100)

                                    property int itemIndex: index
                                    property real popScale: 1.0
                                    property real flashOpacity: 0.0
                                    property color btnColor: ThemeBackend.surface0
                                    property int cornerRadius: Math.round(dockWindow.s(dockWindow.dockElementSize) * 0.28)
                                    property bool isDropTarget: dockWindow.dropTargetIndex === index && dockWindow.dragSourceIndex !== index
                                    property bool isBeingDragged: btnMa.drag.active
                                    property int btnSize: dockWindow.s(dockWindow.dockElementSize)

                                    readonly property bool canHoverScale: !dockWindow.editMode && dockWindow.dragSourceIndex === -1 && !btnMa.drag.active
                                    readonly property real maxHoverScale: dockWindow.dockHoverScaleMultiplier
                                    readonly property real hoverScaleDelta: Math.max(0.0, maxHoverScale - 1.0)

                                    property real baseHoverScale: {
                                        if (!canHoverScale || dockContainer.hoveredItemIndex < 0) return 1.0;
                                        let diff = Math.abs(dockButton.itemIndex - dockContainer.hoveredItemIndex);
                                        if (diff === 0) return maxHoverScale;
                                        if (dockWindow.dockCascadeScale) {
                                            if (diff === 1) return 1.0 + hoverScaleDelta * 0.45;
                                            if (diff === 2) return 1.0 + hoverScaleDelta * 0.15;
                                        }
                                        return 1.0;
                                    }

                                    property real targetScale: {
                                        let s = baseHoverScale;
                                        if (btnMa.pressed && canHoverScale) {
                                            return s > 1.0 ? (s * 1.04) : 1.06;
                                        }
                                        return s;
                                    }

                                    property real animSpread: {
                                        if (!canHoverScale || dockContainer.hoveredItemIndex < 0) return 0.0;
                                        let diff = itemIndex - dockContainer.hoveredItemIndex;
                                        if (diff === 0) return 0.0;
                                        let sign = diff > 0 ? 1.0 : -1.0;
                                        let d = Math.abs(diff);
                                        let maxAllowedShift = Math.min(dockWindow.s(10), dockButton.btnSize * hoverScaleDelta * 0.65);
                                        if (dockWindow.dockCascadeScale) {
                                            let shift = (d === 1) ? (maxAllowedShift * 0.70) : maxAllowedShift;
                                            return sign * shift;
                                        } else {
                                            return (d === 1) ? (sign * maxAllowedShift * 0.45) : 0.0;
                                        }
                                    }

                                    property real animLift: {
                                        if (!canHoverScale || targetScale <= 1.0) return 0.0;
                                        let liftProgress = (targetScale - 1.0) / Math.max(0.01, maxHoverScale - 1.0);
                                        return dockWindow.s(5) * Math.min(1.0, Math.max(0.0, liftProgress));
                                    }

                                    property real targetOffsetX: {
                                        if (dockWindow.isVertical) {
                                            if (dockWindow.dockPosition === "left") return animLift;
                                            if (dockWindow.dockPosition === "right") return -animLift;
                                            return 0.0;
                                        } else {
                                            return animSpread;
                                        }
                                    }

                                    property real targetOffsetY: {
                                        if (dockWindow.isVertical) {
                                            return animSpread;
                                        } else {
                                            if (dockWindow.dockPosition === "bottom") return -animLift;
                                            if (dockWindow.dockPosition === "top") return animLift;
                                            return 0.0;
                                        }
                                    }

                                    property real currentOffsetX: btnMa.drag.active ? 0 : targetOffsetX
                                    property real currentOffsetY: btnMa.drag.active ? 0 : targetOffsetY

                                    Behavior on currentOffsetX {
                                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on currentOffsetY {
                                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: dockButton.isBeingDragged
                                        radius: dockButton.cornerRadius
                                        color: Qt.alpha(ThemeBackend.surface0, 0.25)
                                        border.color: Qt.alpha(ThemeBackend.mauve, 0.5)
                                        border.width: 1
                                    }

                                    Rectangle {
                                        id: dropIndicator
                                        anchors.fill: parent
                                        anchors.margins: -dockWindow.s(3)
                                        radius: dockButton.cornerRadius + dockWindow.s(3)
                                        color: "transparent"
                                        border.color: ThemeBackend.mauve
                                        border.width: 2
                                        visible: dockButton.isDropTarget
                                        opacity: dockButton.isDropTarget ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    Item {
                                        id: floatWrapper
                                        anchors.fill: !btnMa.drag.active ? parent : undefined
                                        width: dockButton.btnSize
                                        height: dockButton.btnSize
                                        z: btnMa.drag.active ? 999999 : 1

                                        transform: Translate {
                                            id: buttonTransform
                                            x: dockButton.currentOffsetX
                                            y: dockButton.currentOffsetY
                                        }

                                        Drag.active: btnMa.drag.active
                                        Drag.source: dockButton
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2

                                        states: [
                                            State {
                                                when: btnMa.drag.active
                                                ParentChange { target: floatWrapper; parent: dragOverlay }
                                                PropertyChanges {
                                                    target: floatWrapper
                                                    width: dockButton.btnSize
                                                    height: dockButton.btnSize
                                                    scale: 1.15
                                                    opacity: 0.92
                                                    z: 999999
                                                }
                                            }
                                        ]

                                        Rectangle {
                                            id: btnShape
                                            anchors.fill: parent
                                            radius: dockButton.cornerRadius
                                            clip: true
                                            color: btnMa.pressed ? Qt.darker(dockButton.btnColor, 1.12) : (btnMa.containsMouse ? Qt.lighter(dockButton.btnColor, 1.12) : dockButton.btnColor)

                                            Behavior on color {
                                                ColorAnimation { duration: 180 }
                                            }

                                            transformOrigin: Item.Center

                                            scale: dockButton.targetScale * dockButton.popScale
                                            Behavior on scale {
                                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                            }

                                            SequentialAnimation {
                                                id: btnPopAnim
                                                NumberAnimation { target: dockButton; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
                                                NumberAnimation { target: dockButton; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
                                            }

                                            Image {
                                                id: appIcon
                                                anchors.fill: parent
                                                anchors.margins: dockWindow.s(Math.round(dockWindow.dockElementSize * 0.14))
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                mipmap: true
                                                property bool failedLoad: false

                                                visible: source !== "" && status === Image.Ready && !failedLoad

                                                source: {
                                                    let ic = model.icon || "";
                                                    if (!ic) return "";
                                                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                                                }

                                                onStatusChanged: {
                                                    if (status === Image.Error) {
                                                        failedLoad = true;
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: appIcon.source === "" || appIcon.failedLoad || appIcon.status === Image.Error
                                                text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: dockWindow.s(Math.round(dockWindow.dockElementSize * 0.42))
                                                font.weight: Font.Bold
                                                color: ThemeBackend.text
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: dockButton.cornerRadius
                                                color: "#ffffff"
                                                opacity: dockButton.flashOpacity
                                                PropertyAnimation on opacity {
                                                    id: btnFlashAnim
                                                    to: 0
                                                    duration: 400
                                                    easing.type: Easing.OutExpo
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: btnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: (dockWindow.editMode || inDragHold)
                                                ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                                : Qt.PointingHandCursor

                                            property bool inDragHold: false

                                            pressAndHoldInterval: 350

                                            drag.target: floatWrapper
                                            drag.axis: Drag.XAndYAxis
                                            drag.threshold: (dockWindow.editMode || inDragHold) ? 5 : 99999

                                            onEntered: {
                                                dockContainer.cancelHoverReset();
                                                if (dockButton.canHoverScale) {
                                                    dockContainer.hoveredItemIndex = dockButton.itemIndex;
                                                }
                                            }

                                            onExited: {
                                                if (dockContainer.hoveredItemIndex === dockButton.itemIndex) {
                                                    dockContainer.checkHoverReset();
                                                }
                                            }

                                            onPressed: {
                                                inDragHold = false;
                                                if (dockWindow.editMode) {
                                                    dockWindow.dragSourceIndex = dockButton.itemIndex;
                                                    dockWindow.dropTargetIndex = dockButton.itemIndex;
                                                    if (typeof Sounds !== "undefined") {
                                                        Sounds.playSfx("guide/barconfig/out.wav");
                                                    }
                                                }
                                            }

                                            onPressAndHold: {
                                                inDragHold = true;
                                                if (!dockWindow.editMode) {
                                                    dockWindow.setEditMode(true);
                                                }
                                                dockWindow.dragSourceIndex = dockButton.itemIndex;
                                                dockWindow.dropTargetIndex = dockButton.itemIndex;
                                                if (typeof Sounds !== "undefined") {
                                                    Sounds.playSfx("guide/barconfig/out.wav");
                                                }
                                            }

                                            onPositionChanged: function(mouse) {
                                                if ((dockWindow.editMode || inDragHold) && drag.active) {
                                                    let pt = mapToItem(dockContainer, mouse.x, mouse.y);
                                                    dockWindow.dropTargetIndex = dockContainer.calculateDropIndex(pt.x, pt.y);
                                                }
                                            }

                                            onReleased: {
                                                let wasHold = inDragHold;
                                                inDragHold = false;
                                                if (dockWindow.editMode || wasHold) {
                                                    let wasDragging = drag.active;
                                                    floatWrapper.Drag.drop();
                                                    if (wasDragging) {
                                                        let pt = btnMa.mapToItem(dockContainer, btnMa.mouseX, btnMa.mouseY);
                                                        let fwPos = floatWrapper.mapToItem(dockContainer, 0, 0);
                                                        let completelyOutside = (fwPos.x + floatWrapper.width <= 0 || fwPos.x >= dockContainer.width ||
                                                                                 fwPos.y + floatWrapper.height <= 0 || fwPos.y >= dockContainer.height) ||
                                                                                (pt.x < -dockWindow.s(16) || pt.x > dockContainer.width + dockWindow.s(16) ||
                                                                                 pt.y < -dockWindow.s(16) || pt.y > dockContainer.height + dockWindow.s(16));
                                                        if (completelyOutside) {
                                                            if (typeof Sounds !== "undefined") {
                                                                Sounds.playSfx("guide/barconfig/in.wav");
                                                            }
                                                            if (model.desktop_id && model.desktop_id !== "") {
                                                                dockWindow.removeAppByDesktopId(model.desktop_id);
                                                            } else if (dockWindow.dragSourceIndex >= 0 && dockWindow.dragSourceIndex < dockAppsModel.count) {
                                                                dockAppsModel.remove(dockWindow.dragSourceIndex, 1);
                                                                dockWindow.saveApps();
                                                            }
                                                        } else if (dockWindow.dragSourceIndex !== -1 && dockWindow.dropTargetIndex !== -1 && dockWindow.dragSourceIndex !== dockWindow.dropTargetIndex) {
                                                            if (typeof Sounds !== "undefined") {
                                                                Sounds.playSfx("guide/barconfig/in.wav");
                                                            }
                                                            dockAppsModel.move(dockWindow.dragSourceIndex, dockWindow.dropTargetIndex, 1);
                                                            dockWindow.saveApps();
                                                        } else if (typeof Sounds !== "undefined") {
                                                            Sounds.playSfx("guide/barconfig/in.wav");
                                                        }
                                                    }
                                                    dockWindow.dragSourceIndex = -1;
                                                    dockWindow.dropTargetIndex = -1;
                                                    floatWrapper.x = 0;
                                                    floatWrapper.y = 0;
                                                }
                                            }

                                            onClicked: {
                                                if (dockWindow.editMode || inDragHold || drag.active) return;
                                                btnPopAnim.start();
                                                dockButton.flashOpacity = 0.4;
                                                btnFlashAnim.start();
                                                if (typeof Sounds !== "undefined") {
                                                    Sounds.playSfx("reusables/iconbutton/click.wav");
                                                }
                                                dockWindow.launchApp(model.desktop_id);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: appPicker
                    visible: dockWindow.editMode || opacity > 0.001
                    opacity: dockWindow.editMode ? 1.0 : 0.0
                    scale: dockWindow.editMode ? 1.0 : 0.94
                    z: 100

                    Behavior on opacity {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    }

                    width: Math.min(dockWindow.width - dockWindow.s(16), dockWindow.isVertical ? dockWindow.s(320) : dockWindow.s(480))

                    readonly property int maxPickerItems: dockWindow.isVertical ? 9 : 6
                    property int targetItemCount: {
                        if (pickerFilteredModel.count > 0) {
                            return Math.min(pickerFilteredModel.count, maxPickerItems);
                        }
                        return maxPickerItems;
                    }
                    property real targetPickerHeight: dockWindow.s(70) + (targetItemCount * dockWindow.s(48))
                    property real animatedPickerHeight: targetPickerHeight
                    Behavior on animatedPickerHeight {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    height: animatedPickerHeight

                    x: {
                        if (!dockWindow.isVertical) return Math.round((dockWindow.width - width) / 2);
                        if (dockWindow.dockPosition === "left") {
                            return Math.round(dockContainer.x + dockContainer.width + dockWindow.s(12));
                        }
                        if (dockWindow.dockPosition === "right") {
                            return Math.round(dockContainer.x - width - dockWindow.s(12));
                        }
                        return Math.round((dockWindow.width - width) / 2);
                    }

                    y: {
                        if (dockWindow.isVertical) return Math.round((dockWindow.height - height) / 2);
                        if (dockWindow.dockPosition === "top") {
                            return Math.round(dockContainer.y + dockContainer.height + dockWindow.s(12));
                        }
                        if (dockWindow.dockPosition === "bottom") {
                            return Math.round(dockContainer.y - height - dockWindow.s(12));
                        }
                        return Math.round((dockWindow.height - height) / 2);
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 1.5 : 24
                        color: ThemeBackend.base
                        border.width: 1
                        border.color: Qt.alpha(ThemeBackend.surface1, 0.45)
                        clip: true

                        Item {
                            id: pickerContent
                            anchors.fill: parent
                            anchors.margins: dockWindow.s(12)

                            readonly property bool isSearchAtBottom: dockWindow.dockPosition === "top"

                            RowLayout {
                                id: pickerSearchRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                y: pickerContent.isSearchAtBottom ? (parent.height - height) : 0
                                height: dockWindow.s(34)
                                spacing: dockWindow.s(8)

                                Input {
                                    id: pickerSearchInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: dockWindow.s(34)
                                    placeholderText: I18n.t("guide.dock.picker.search", "Search apps...")
                                    baseColor: ThemeBackend.surface0
                                    accentColor: ThemeBackend.mauve
                                    textColor: ThemeBackend.text
                                    subTextColor: ThemeBackend.subtext0
                                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                    cornerRadius: ThemeBackend.borderRadius
                                    fontPixelSize: dockWindow.s(11)
                                    showClearButton: true
                                    focus: dockWindow.editMode
                                    onTextEdited: function(newText) {
                                        dockWindow.filterPickerApps(newText);
                                    }
                                    onCleared: {
                                        dockWindow.filterPickerApps("");
                                    }
                                    Keys.onEscapePressed: function(event) {
                                        dockWindow.setEditMode(false);
                                        event.accepted = true;
                                    }
                                }

                                ClickButton {
                                    implicitHeight: dockWindow.s(34)
                                    maxWidth: dockWindow.s(70)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonText: I18n.t("guide.dock.picker.done", "Done")
                                    accentColor: ThemeBackend.mauve
                                    textColor: ThemeBackend.crust
                                    textFontSize: dockWindow.s(11)
                                    onClicked: {
                                        dockWindow.setEditMode(false);
                                    }
                                }
                            }

                            Rectangle {
                                id: pickerDivider
                                anchors.left: parent.left
                                anchors.right: parent.right
                                y: pickerContent.isSearchAtBottom
                                   ? (pickerSearchRow.y - dockWindow.s(10) - height)
                                   : (pickerSearchRow.y + pickerSearchRow.height + dockWindow.s(10))
                                height: 1
                                color: Qt.alpha(ThemeBackend.surface1, 0.3)
                            }

                            Item {
                                id: pickerListWrapper
                                anchors.left: parent.left
                                anchors.right: parent.right
                                y: pickerContent.isSearchAtBottom ? 0 : (pickerDivider.y + pickerDivider.height + dockWindow.s(10))
                                height: pickerContent.isSearchAtBottom
                                        ? Math.max(0, pickerDivider.y - dockWindow.s(10))
                                        : Math.max(0, parent.height - y)
                                clip: true

                                ListView {
                                    id: pickerList
                                    anchors.fill: parent
                                    clip: true
                                    model: pickerFilteredModel
                                    spacing: dockWindow.s(4)
                                    boundsBehavior: Flickable.StopAtBounds

                                    ScrollBar.vertical: ScrollBar {
                                        active: parent.moving || parent.movingVertically
                                        width: dockWindow.s(4)
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: dockWindow.s(4)
                                            radius: dockWindow.s(2)
                                            color: ThemeBackend.surface2
                                        }
                                    }

                                    delegate: Rectangle {
                                        id: pickerDelegate
                                        required property var modelData
                                        required property int index

                                        width: pickerList.width - dockWindow.s(6)
                                        height: dockWindow.s(44)
                                        radius: ThemeBackend.borderRadius
                                        readonly property var resolvedItem: (modelData !== undefined && modelData) ? modelData : model
                                        readonly property bool isAdded: dockWindow.isAppInDock(resolvedItem.id || "")

                                        color: isAdded ? ThemeBackend.mauve : (pickerMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.surface0, 0.25))
                                        border.width: 0

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: dockWindow.s(8)
                                            anchors.rightMargin: dockWindow.s(8)
                                            spacing: dockWindow.s(8)

                                            Rectangle {
                                                implicitWidth: dockWindow.s(28)
                                                implicitHeight: dockWindow.s(28)
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: Math.round(dockWindow.s(28) * 0.28)
                                                color: pickerDelegate.isAdded ? Qt.tint(ThemeBackend.surface0, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface0
                                                clip: true

                                                Image {
                                                    id: pIcon
                                                    anchors.fill: parent
                                                    anchors.margins: dockWindow.s(3)
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                    mipmap: true
                                                    property bool failedLoad: false

                                                    visible: source !== "" && status === Image.Ready && !failedLoad

                                                    source: {
                                                        let ic = pickerDelegate.resolvedItem.icon || "";
                                                        if (!ic) return "";
                                                        if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                                        return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                                                    }

                                                    onStatusChanged: {
                                                        if (status === Image.Error) failedLoad = true;
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: pIcon.source === "" || pIcon.failedLoad || pIcon.status === Image.Error
                                                    text: pickerDelegate.resolvedItem.name ? pickerDelegate.resolvedItem.name.charAt(0).toUpperCase() : "?"
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: dockWindow.s(12)
                                                    font.bold: true
                                                    color: pickerDelegate.isAdded ? ThemeBackend.mauve : ThemeBackend.text
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: dockWindow.s(1)

                                                Text {
                                                    text: pickerDelegate.resolvedItem.name || pickerDelegate.resolvedItem.id || ""
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: dockWindow.s(11)
                                                    font.weight: pickerDelegate.isAdded ? Font.Bold : Font.Medium
                                                    color: pickerDelegate.isAdded ? ThemeBackend.crust : ThemeBackend.text
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }

                                                Text {
                                                    text: pickerDelegate.resolvedItem.comment || pickerDelegate.resolvedItem.id || ""
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: dockWindow.s(9)
                                                    color: pickerDelegate.isAdded ? ThemeBackend.crust : ThemeBackend.subtext0
                                                    opacity: pickerDelegate.isAdded ? 0.9 : 0.85
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: pickerMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (typeof Sounds !== "undefined") {
                                                    Sounds.playSfx("reusables/iconbutton/click.wav");
                                                }
                                                if (pickerDelegate.isAdded) {
                                                    dockWindow.removeAppByDesktopId(pickerDelegate.resolvedItem.id);
                                                } else {
                                                    dockWindow.addApp(pickerDelegate.resolvedItem);
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        anchors.fill: parent
                                        visible: pickerFilteredModel.count === 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: I18n.t("guide.dock.picker.empty", "No matching applications")
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: dockWindow.s(11)
                                            color: ThemeBackend.subtext0
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
