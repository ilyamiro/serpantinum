import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

PanelWindow {
    id: popupWindow

    readonly property real sf: Scaler.baseScale

    function s(val) {
        return Math.round(val * popupWindow.sf);
    }

    property bool hasCriticalPopup: {
        for (let i = 0; i < NotificationManager.activePopupsModel.count; i++) {
            let p = NotificationManager.activePopupsModel.get(i);
            if (p && p.urgency === 2) return true;
        }
        return false;
    }

    visible: (!popupWindow.dndEnabled || popupWindow.hasCriticalPopup) && !NotificationManager.sysPanelOpen && NotificationManager.activePopupsModel.count > 0

    function storeNotif(uid, notif) {
        NotificationManager.liveNotifs[uid] = notif;
    }

    function getNotif(uid) {
        return NotificationManager.liveNotifs[uid] || null;
    }

    function removeNotif(uid) {
        NotificationManager.removePopup(uid);
    }

    readonly property string barPosition: SurfaceRegistry.barPosition
    readonly property bool barAutohide: SurfaceRegistry.barAutohide
    readonly property bool isFullscreenActive: Compositor.isFullscreenOn(popupWindow.screen)
    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive || !SurfaceRegistry.isBarEnabledOnScreen(popupWindow.screen)
    readonly property string barStyle: SurfaceRegistry.barStyle
    readonly property bool isBarFill: SurfaceRegistry.isFillBar
    readonly property int barThickness: s(40) + (isBarFill || isBarEffectivelyHidden ? 0 : s(4))

    property var notifSettings: Config.getSetting("notifications", { "dnd": false, "position": "top right", "horizontalPosition": 95, "verticalPosition": 5 })
    property string position: notifSettings.position !== undefined ? notifSettings.position : "top right"
    property real horizontalPosition: notifSettings.horizontalPosition !== undefined ? notifSettings.horizontalPosition : 95
    property real verticalPosition: notifSettings.verticalPosition !== undefined ? notifSettings.verticalPosition : 5

    property bool isPreset: position !== "custom"

    property bool isTop: position.indexOf("top") !== -1
    property bool isBottom: position.indexOf("bottom") !== -1
    property bool isCenter: position.indexOf("center") !== -1
    property bool isLeft: position.indexOf("left") !== -1
    property bool isRight: position.indexOf("right") !== -1 || (!isLeft && !isCenter)

    WlrLayershell.namespace: "qs-popups"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        bottom: true
        left: isPreset ? (popupWindow.isCenter || popupWindow.isLeft) : true
        right: isPreset ? (popupWindow.isCenter || popupWindow.isRight) : true
    }

    margins {
        top: isPreset ? ((popupWindow.barPosition === "top" && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + popupWindow.s(12)) : 0
        bottom: isPreset ? ((popupWindow.barPosition === "bottom" && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + popupWindow.s(12)) : 0
        left: isPreset ? ((popupWindow.barPosition === "left" && popupWindow.isLeft && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + (popupWindow.isLeft ? popupWindow.s(16) : 0)) : 0
        right: isPreset ? ((popupWindow.barPosition === "right" && popupWindow.isRight && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + (popupWindow.isRight ? popupWindow.s(16) : 0)) : 0
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    implicitWidth: s(350)

    mask: Region {
        item: popupContainer
    }

    property bool dndEnabled: {
        let n = Config.getSetting("notifications", { "dnd": false, "position": "top right" });
        return Boolean(n && n.dnd);
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let n = Config.getSetting("notifications", { "dnd": false, "position": "top right" });
            popupWindow.dndEnabled = Boolean(n && n.dnd);
            popupWindow.position = (n && n.position !== undefined) ? n.position : "top right";
            popupWindow.horizontalPosition = (n && n.horizontalPosition !== undefined) ? n.horizontalPosition : 95;
            popupWindow.verticalPosition = (n && n.verticalPosition !== undefined) ? n.verticalPosition : 5;
        }
    }

    Item {
        id: popupRoot
        anchors.fill: parent

        function s(val) {
            return popupWindow.s(val);
        }

        Item {
            id: popupContainer
            width: popupWindow.s(350)
            height: popupList.height

            x: popupWindow.isPreset ? (popupWindow.isCenter ? (popupWindow.width - width) / 2 : (popupWindow.isLeft ? 0 : (popupWindow.width - width))) : ((popupWindow.width - width) * (popupWindow.horizontalPosition / 100.0))
            y: popupWindow.isPreset ? (popupWindow.isTop ? 0 : (popupWindow.height - height)) : ((popupWindow.height - height) * (popupWindow.verticalPosition / 100.0))

            ListView {
                id: popupList
                width: parent.width
                height: Math.min(popupWindow.height, contentHeight)
                verticalLayoutDirection: (popupWindow.isPreset ? popupWindow.isBottom : (popupWindow.verticalPosition > 50)) ? ListView.BottomToTop : ListView.TopToBottom
                model: NotificationManager.activePopupsModel
                spacing: popupWindow.s(12)
                interactive: false
                clip: false
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation {
                            property: "x"
                            from: (popupWindow.isPreset ? (popupWindow.isCenter ? 0 : (popupWindow.isLeft ? -1 : 1)) : (popupWindow.horizontalPosition < 33 ? -1 : (popupWindow.horizontalPosition > 66 ? 1 : 0))) * popupWindow.s(350) * 0.35
                            to: 0
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "y"
                            from: (popupWindow.isPreset ? (popupWindow.isCenter ? (popupWindow.isBottom ? popupWindow.s(24) : -popupWindow.s(24)) : 0) : ((popupWindow.verticalPosition > 50) ? popupWindow.s(24) : -popupWindow.s(24)))
                            to: 0
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation {
                            property: "x"
                            to: (popupWindow.isPreset ? (popupWindow.isCenter ? 0 : (popupWindow.isLeft ? -1 : 1)) : (popupWindow.horizontalPosition < 33 ? -1 : (popupWindow.horizontalPosition > 66 ? 1 : 0))) * popupWindow.s(350) * 0.35
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "y"
                            to: (popupWindow.isPreset ? (popupWindow.isCenter ? (popupWindow.isBottom ? popupWindow.s(24) : -popupWindow.s(24)) : 0) : ((popupWindow.verticalPosition > 50) ? popupWindow.s(24) : -popupWindow.s(24)))
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutCubic }
                }

                removeDisplaced: Transition {
                    NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: delegateWrapper
                    width: ListView.view.width

                    property bool isSuppressedByDnd: popupWindow.dndEnabled && model.urgency !== 2

                    implicitHeight: isSuppressedByDnd ? 0 : (typeLoader.item ? typeLoader.item.implicitHeight : popupWindow.s(70))
                    height: implicitHeight
                    visible: !isSuppressedByDnd

                    property int popupUid: model.uid || model.latestUid
                    property var realNotif: popupWindow.getNotif(popupUid) || (model.notif ? model.notif : null)
                    property bool isPopupContext: true
                    property var msgModel: model
                    property bool isExpanded: typeLoader.item && typeLoader.item.expanded ? true : false
                    property bool isHovered: typeLoader.item && typeLoader.item.isHovered ? true : false
                    property bool isDragging: typeLoader.item && typeLoader.item.isDragging ? true : false

                    property var actionArray: {
                        try {
                            return model.actionsJson ? JSON.parse(model.actionsJson) : []
                        } catch (e) {
                            return []
                        }
                    }

                    readonly property var resolvedType: NotificationManager.resolveType(model, "types/")

                    property int effectiveTimeout: {
                        var cfg = popupWindow.notifSettings;
                        var key = model.urgency === 2 ? "timeoutCritical" : (model.urgency === 0 ? "timeoutLow" : "timeoutNormal");
                        var secs = cfg && typeof cfg[key] === "number" ? cfg[key] : (model.urgency === 2 ? 15 : 5);
                        var fallback = Math.max(0, Math.round(secs * 1000));
                        if (fallback > 0 && delegateWrapper.resolvedType.minTimeoutMs > 0) fallback = Math.max(fallback, delegateWrapper.resolvedType.minTimeoutMs);
                        var n = delegateWrapper.realNotif;
                        if (!n || (cfg && cfg.overrideAppTimeouts)) return fallback;
                        var t = typeof n.expireTimeout === "number" ? n.expireTimeout : (typeof n.timeout === "number" ? n.timeout : -1);
                        if (t === 0) return 0;
                        if (t > 0) return t;
                        return fallback;
                    }

                    Connections {
                        target: delegateWrapper.realNotif || null
                        function onClosed() {
                            popupWindow.removeNotif(delegateWrapper.popupUid);
                        }
                    }

                    Timer {
                        id: dismissTimer
                        interval: delegateWrapper.effectiveTimeout > 0 ? delegateWrapper.effectiveTimeout : 5000
                        running: delegateWrapper.effectiveTimeout > 0 && !delegateWrapper.isHovered && !delegateWrapper.isExpanded && !delegateWrapper.isDragging
                        repeat: false
                        onTriggered: popupWindow.removeNotif(delegateWrapper.popupUid)
                    }

                    function removeThisNotif() {
                        popupWindow.removeNotif(delegateWrapper.popupUid);
                    }

                    Loader {
                        id: typeLoader
                        width: parent.width
                        source: delegateWrapper.resolvedType.componentUrl
                        onLoaded: {
                            if (item) {
                                item.model = delegateWrapper.msgModel;
                                item.root = popupRoot;
                                item.delegateWrapper = delegateWrapper;
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: NotificationManager
        function onPopupAdded(uid, notif) {
            popupWindow.storeNotif(uid, notif);
        }
    }
}
