import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

DockWindowApps {
    id: dockWindowRoot

    property alias pickerFilteredModel: pickerFilteredModel
    property alias dragOverlay: dragOverlay
    property alias pickerSearchInput: appPicker.pickerSearchInput
    property alias navContainer: dockContainerItem
    property alias dockHover: dockContainerItem.dockHover
    property alias dockTransform: dockContainerItem.dockTransform

    WlrLayershell.namespace: "qs-dock"
    WlrLayershell.layer: (dockWindowRoot.dockOnTop || dockWindowRoot.editMode) ? WlrLayer.Top : WlrLayer.Bottom
    focusable: dockWindowRoot.editMode
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    Timer {
        id: initTimer
        interval: 50
        repeat: false
        onTriggered: dockWindowRoot.initialized = true
    }

    onEffectiveAutohideChanged: hideTimer.stop()
    onActiveIndexChanged: {
        hideTimer.stop();
        if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible) {
            DockAppMenuController.hide();
        }
        dockWindowRoot._recomputeRunningInfo();
    }

    readonly property bool isEffectivelyExclusive: dockWindowRoot.initialized && dockEnabled && dockExclusive && !effectiveAutohide && !isFullscreenActive && !editMode && (dockAppsModel.count > 0)
    readonly property int dockReservedSpace: Math.round(dockContainerItem.fullThickness + effectiveMargin)

    Connections {
        target: (typeof DockAppMenuController !== "undefined") ? DockAppMenuController : null
        function onIsVisibleChanged() {
            dockWindowRoot.checkHideTimer();
        }
    }

    readonly property real hoverExpansion: Math.round(Math.max(s(24), s(dockElementSize) * (dockHoverScaleMultiplier - 1.0) + s(12)))

    property int dockElementSize: {
        if (overrideBoundsCorrection) return rawElementSize;
        if (enableScrolling) return rawElementSize;
        let countToCheck = editMode ? (dockContainerItem.effectiveItemCount + 1) : dockContainerItem.effectiveItemCount;
        if (countToCheck <= 0) return rawElementSize;
        let avail = (isVertical ? effectiveWindowHeight : effectiveWindowWidth) - s(40) - (sameSideAsBar ? barHeight : 0);
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
    readonly property bool dockBackground: rawDockSettings.background !== undefined ? Boolean(rawDockSettings.background) : true
    readonly property real dockOpacity: dockBackground ? ThemeBackend.elementOpacity : 0.0
    property real floatingMargin: dockFloating ? s(8) : 0
    Behavior on floatingMargin {
        enabled: dockWindowRoot.initialized && !dockWindowRoot.positionChanging
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    property int autohideTimeout: rawDockSettings.autohideTimeout !== undefined ? rawDockSettings.autohideTimeout : 1000
    property real autohideHitSize: s(18)

    property real editMargin: (editMode && !dockFloating) ? s(20) : 0
    Behavior on editMargin {
        enabled: dockWindowRoot.initialized && !dockWindowRoot.positionChanging
        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
    }
    readonly property real effectiveMargin: floatingMargin + editMargin

    property int dragSourceIndex: -1
    property int dropTargetIndex: -1

    property bool positionChanging: false

    Timer {
        id: positionChangeTimer
        interval: 300
        onTriggered: dockWindowRoot.positionChanging = false
    }

    onDockPositionChanged: {
        dockWindowRoot.positionChanging = true;
        dockContainerItem.scrollIndex = 0;
        dockContainerItem.hoveredItemIndex = -1;
        positionChangeTimer.restart();
    }

    visible: dockWindowRoot.initialized && dockEnabled && !isFullscreenActive && (dockAppsModel.count > 0 || editMode)

    property real dockTotalLength: {
        let len = (isVertical ? dockContainerItem.baseHeight : dockContainerItem.baseWidth) + (dockContainerItem.isAttached ? outerCornerRadius * 2 : 0) + s(12);
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
        interval: dockWindowRoot.autohideTimeout
    }

    function checkHideTimer() {
        let isMenuOpen = (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible && (!DockAppMenuController.screen || !dockWindowRoot.screen || DockAppMenuController.screen.name === dockWindowRoot.screen.name));
        if (!dockHover.hovered && !edgeHover.hovered && dockWindowRoot.effectiveAutohide && !dockWindowRoot.editMode && !isMenuOpen) {
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
    }

    Connections {
        target: dockHover
        function onHoveredChanged() { dockWindowRoot.checkHideTimer(); }
    }

    property bool isRevealed: {
        if (isFullscreenActive) return false;
        if (editMode) return true;
        if (!effectiveAutohide) return true;
        if (typeof DockNavController !== "undefined" && DockNavController.active && DockNavController.dock === dockWindowRoot) return true;
        if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible && (!DockAppMenuController.screen || !dockWindowRoot.screen || DockAppMenuController.screen.name === dockWindowRoot.screen.name)) return true;
        if (dockHover.hovered) return true;
        if (edgeHover.hovered) return true;
        if (hideTimer.running) return true;
        return false;
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
        onTriggered: dockWindowRoot.grabPickerFocus()
    }

    Timer {
        id: pickerFocusRetryTimer
        interval: 150
        repeat: false
        onTriggered: dockWindowRoot.grabPickerFocus()
    }

    Timer {
        id: pickerFocusFinalTimer
        interval: 300
        repeat: false
        onTriggered: dockWindowRoot.grabPickerFocus()
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
        dockWindowRoot.allDesktopApps = list;
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
        dockWindowRoot._syncRunningApps();
        dockContainerItem.hoveredItemIndex = -1;
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

    Component.onCompleted: {
        DockNavController.registerDock(dockWindowRoot);
        let de = (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : "";
        dockWindowRoot.isNiri = Boolean(Quickshell.env("NIRI_SOCKET")) || de.indexOf("niri") !== -1;
        dockWindowRoot.isSway = Boolean(Quickshell.env("SWAYSOCK")) || de.indexOf("sway") !== -1;
        dockWindowRoot.isHyprland = Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) || de.indexOf("hyprland") !== -1;
        if (dockWindowRoot.isNiri) {
            NiriState.subscribe();
        }
        if (dockWindowRoot.isSway) {
            swayPoller.running = true;
        }
        if (dockWindowRoot.isMango) {
            MangoState.subscribe();
        }
        if (typeof WindowTracker !== "undefined") {
            WindowTracker.subscribe();
        }
        loadApps();
        loadAllDesktopApps();
        initTimer.start();
    }

    Component.onDestruction: {
        DockNavController.unregisterDock(dockWindowRoot);
        if (dockWindowRoot.isNiri) {
            NiriState.unsubscribe();
        }
        if (dockWindowRoot.isMango) {
            MangoState.unsubscribe();
        }
        if (typeof WindowTracker !== "undefined") {
            WindowTracker.unsubscribe();
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            dockWindowRoot.loadAllDesktopApps();
        }
    }

    mask: Region {
        Region {
            item: dockWindowRoot.editMode ? dismissArea : null
        }
        Region {
            item: (dockWindowRoot.isRevealed || dockContainerItem.revealProgress > 0.01) ? dockMaskArea : null
        }
        Region {
            item: edgeTrigger
        }
        Region {
            item: dockWindowRoot.editMode ? appPicker : null
        }
    }

    Item {
        id: dismissArea
        width: dockWindowRoot.effectiveWindowWidth
        height: dockWindowRoot.effectiveWindowHeight
        visible: dockWindowRoot.editMode
        z: -1

        MouseArea {
            anchors.fill: parent
            onClicked: dockWindowRoot.setEditMode(false)
        }

        Keys.onEscapePressed: function(event) {
            dockWindowRoot.setEditMode(false);
            event.accepted = true;
        }
    }

    Item {
        id: edgeTrigger
        visible: dockWindowRoot.effectiveAutohide && !dockWindowRoot.isFullscreenActive && !dockWindowRoot.editMode
        x: {
            if (dockWindowRoot.isVertical) {
                if (dockWindowRoot.dockPosition === "right") {
                    return dockWindowRoot.effectiveWindowWidth - width - dockWindowRoot.barOffset;
                }
                if (dockWindowRoot.dockPosition === "left") {
                    return dockWindowRoot.barOffset;
                }
                return 0;
            }
            return Math.round((dockWindowRoot.effectiveWindowWidth - width) / 2);
        }
        y: {
            if (!dockWindowRoot.isVertical) {
                if (dockWindowRoot.dockPosition === "bottom") {
                    return dockWindowRoot.effectiveWindowHeight - height - dockWindowRoot.barOffset;
                }
                if (dockWindowRoot.dockPosition === "top") {
                    return dockWindowRoot.barOffset;
                }
                return 0;
            }
            return Math.round((dockWindowRoot.effectiveWindowHeight - height) / 2);
        }
        width: dockWindowRoot.isVertical ? dockWindowRoot.autohideHitSize : Math.min(dockWindowRoot.effectiveWindowWidth, dockWindowRoot.dockTotalLength)
        height: dockWindowRoot.isVertical ? Math.min(dockWindowRoot.effectiveWindowHeight, dockWindowRoot.dockTotalLength) : dockWindowRoot.autohideHitSize

        HoverHandler {
            id: edgeHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: dockWindowRoot.checkHideTimer()
        }
    }

    Item {
        id: dockMaskArea
        readonly property real rawX: dockContainerItem.x - (dockContainerItem.isAttached && !dockWindowRoot.isVertical ? dockWindowRoot.outerCornerRadius : 0) + dockTransform.x - dockWindowRoot.hoverExpansion
        readonly property real rawY: dockContainerItem.y - (dockContainerItem.isAttached && dockWindowRoot.isVertical ? dockWindowRoot.outerCornerRadius : 0) + dockTransform.y - dockWindowRoot.hoverExpansion
        readonly property real rawW: dockContainerItem.width + (dockContainerItem.isAttached && !dockWindowRoot.isVertical ? dockWindowRoot.outerCornerRadius * 2 : 0) + dockWindowRoot.hoverExpansion * 2
        readonly property real rawH: dockContainerItem.height + (dockContainerItem.isAttached && dockWindowRoot.isVertical ? dockWindowRoot.outerCornerRadius * 2 : 0) + dockWindowRoot.hoverExpansion * 2
        readonly property real minX: (dockWindowRoot.sameSideAsBar && dockWindowRoot.dockPosition === "left") ? dockWindowRoot.barOffset : 0
        readonly property real maxX: dockWindowRoot.effectiveWindowWidth - ((dockWindowRoot.sameSideAsBar && dockWindowRoot.dockPosition === "right") ? dockWindowRoot.barOffset : 0)
        readonly property real minY: (dockWindowRoot.sameSideAsBar && dockWindowRoot.dockPosition === "top") ? dockWindowRoot.barOffset : 0
        readonly property real maxY: dockWindowRoot.effectiveWindowHeight - ((dockWindowRoot.sameSideAsBar && dockWindowRoot.dockPosition === "bottom") ? dockWindowRoot.barOffset : 0)
        x: Math.max(rawX, minX)
        y: Math.max(rawY, minY)
        width: Math.max(0, Math.min(rawX + rawW, maxX) - x)
        height: Math.max(0, Math.min(rawY + rawH, maxY) - y)
    }

    Item {
        id: dragOverlay
        anchors.fill: parent
        z: 999999
    }

    DockContainer {
        id: dockContainerItem
        dockWindow: dockWindowRoot
    }

    DockAppPicker {
        id: appPicker
        dockWindow: dockWindowRoot
        dockContainer: dockContainerItem
    }
}
