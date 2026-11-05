import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"
import "../../"

Item {
    id: root
    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module

    property string orientation: activeTarget && activeTarget.orientation !== undefined ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: activeTarget ? Boolean(activeTarget.isCompact) : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false
    readonly property bool showLayout: (barWindow && !isPreview) ? Boolean(barWindow.isStartupReady) : true
    readonly property real barOpacity: ThemeBackend.elementOpacity

    function s(val) {
        if (barWindow && typeof barWindow.cs === "function") return barWindow.cs(val);
        if (activeTarget && typeof activeTarget.s === "function") return activeTarget.s(val);
        return val;
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string menuStyle: {
        if (widget && widget !== root && widget.menuStyle !== undefined) return widget.menuStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.menuStyle) return Config.rawSettings.bar.menuStyle;
        return "button";
    }

    property var menuItems: {
        if (widget && widget !== root && widget.menuItems !== undefined) return widget.menuItems;
        let dummy = configRevision;
        let bs = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : {};
        return BarModuleRegistry.menuItemsFromSettings(bs);
    }

    readonly property bool showCaffeine: menuItems.indexOf("caffeine") !== -1
    readonly property bool iconOnly: menuStyle === "icon"

    readonly property var helpButton: {
        let dummy = menuRepeater.count;
        let found = null;
        for (let i = 0; i < menuRepeater.count; i++) {
            let it = menuRepeater.itemAt(i);
            if (!it) continue;
            if (it.itemId === "settings") return it;
            if (!found && it.itemId === "launcher") found = it;
        }
        return found || menuRepeater.itemAt(0);
    }

    property bool nightLightActive: {
        let dummy = configRevision;
        return (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") ? BlueLight.isAnyEnabled() : false;
    }

    property bool caffeineActive: {
        let dummy = configRevision;
        let idleObj = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.idle) ? Config.rawSettings.idle : null;
        if (!idleObj || !idleObj.manualInhibit) return false;
        let endTime = Number(idleObj.caffeineEndTime) || 0;
        return endTime <= 0 || endTime > Date.now();
    }

    Connections {
        target: (typeof BlueLight !== "undefined") ? BlueLight : null
        ignoreUnknownSignals: true
        function onSettingsChanged() { root.configRevision++; }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.showCaffeine && root.caffeineActive && !root.isPreview
        onTriggered: {
            let idleObj = Config.getSetting("idle", {}) || {};
            let endTime = Number(idleObj.caffeineEndTime) || 0;
            if (endTime > 0 && endTime <= Date.now()) root.setCaffeine(false);
        }
    }

    function toggleNightLight() {
        if (typeof BlueLight === "undefined" || typeof BlueLight.setEnabled !== "function") return;
        let target = !root.nightLightActive;
        let monNames = [];
        let ds = Config.getSetting("display", {"monitors": {}});
        let mons = (ds && ds.monitors) ? ds.monitors : {};
        for (let m in mons) {
            if (monNames.indexOf(m) === -1) monNames.push(m);
        }
        if (Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name && monNames.indexOf(scr.name) === -1) monNames.push(scr.name);
            }
        }
        if (monNames.length > 0) {
            for (let i = 0; i < monNames.length; i++) BlueLight.setEnabled(monNames[i], target);
        } else {
            BlueLight.setEnabled("", target);
        }
    }

    function shuffleWallpaper(btn) {
        let scr = barWindow ? barWindow.screen : null;
        let transition = "circle";
        if (btn && scr && scr.width > 0 && scr.height > 0) {
            let pt = btn.mapToItem(null, btn.width / 2, btn.height / 2);
            let pos = barWindow.barPosition;
            let x = pt.x + (pos === "right" ? scr.width - barWindow.width : 0);
            let y = pt.y + (pos === "bottom" ? scr.height - barWindow.height : 0);
            transition = "circle:" + Math.max(0, Math.min(1, x / scr.width)) + ":" + Math.max(0, Math.min(1, y / scr.height));
        }
        Wallpaper.shuffle(scr && scr.name ? scr.name : "", transition);
    }

    function setCaffeine(enabled) {
        let now = Date.now();
        let idleObj = Object.assign({}, Config.getSetting("idle", {}));
        idleObj.manualInhibit = enabled;
        idleObj.caffeineStartTime = enabled ? now : 0;
        idleObj.caffeineEndTime = enabled ? now + 3600 * 1000 : 0;
        Config.setSetting("idle", idleObj);
    }

    property real targetLength: (!module || module.moduleActive) ? ((isVertical ? buttonsFlow.implicitHeight : buttonsFlow.implicitWidth) + s(isCompact ? 6 : 8)) : 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    component MenuButton: Item {
        id: menuBtn
        property string glyph: ""
        property bool active: false
        property color activeColor: ThemeBackend.peach
        signal clicked()

        width: root.isVertical ? root.s(root.isCompact ? 28 : 30) : root.s(root.isCompact ? 30 : 32)
        height: root.s(root.isCompact ? 28 : 30)

        opacity: (root.isVertical || root.showLayout) ? 1.0 : 0.0
        transform: Translate {
            y: (root.isVertical || root.showLayout) ? 0 : root.s(15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        IconButton {
            anchors.fill: parent
            visible: !root.iconOnly
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
            buttonIcon: menuBtn.glyph
            iconFontSize: root.s(root.isCompact ? 14 : 15)
            accentColor: menuBtn.active ? menuBtn.activeColor : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            bgOpacity: menuBtn.active ? 1.0 : root.barOpacity
            textColor: menuBtn.active ? ThemeBackend.crust : (isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2))
            onClicked: menuBtn.clicked()
        }

        Text {
            anchors.centerIn: parent
            visible: root.iconOnly
            text: menuBtn.glyph
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(root.isCompact ? 15 : 16)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: menuBtn.active ? menuBtn.activeColor : (iconMouse.containsMouse ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2))
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            visible: root.iconOnly
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuBtn.clicked()
        }
    }

    AxisFlow {
        id: buttonsFlow
        vertical: root.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: root.s(root.isCompact ? 2 : 4)
        anchors.centerIn: root.isVertical ? parent : undefined
        anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
        anchors.left: root.isVertical ? undefined : parent.left
        anchors.leftMargin: root.isVertical ? 0 : root.s(root.isCompact ? 3 : 4)

        Repeater {
            id: menuRepeater
            model: root.menuItems

            MenuButton {
                id: menuItem
                required property string modelData
                readonly property string itemId: modelData
                glyph: BarModuleRegistry.menuItemIcon(itemId)
                active: itemId === "nightlight" ? root.nightLightActive : (itemId === "caffeine" ? root.caffeineActive : false)
                activeColor: itemId === "caffeine" ? Qt.tint(ThemeBackend.peach, "#5c3016") : ThemeBackend.peach
                onClicked: {
                    if (root.isPreview) return;
                    if (itemId === "settings") Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle settings"]);
                    else if (itemId === "launcher") Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle launcher"]);
                    else if (itemId === "nightlight") root.toggleNightLight();
                    else if (itemId === "caffeine") root.setCaffeine(!root.caffeineActive);
                    else if (itemId === "shuffle") root.shuffleWallpaper(menuItem);
                }
            }
        }
    }
}
