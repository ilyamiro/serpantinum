import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

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

    property bool showSettings: {
        if (widget && widget !== root && widget.menuShowSettings !== undefined) return widget.menuShowSettings;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.menuShowSettings !== undefined) return Boolean(Config.rawSettings.bar.menuShowSettings);
        return true;
    }

    property bool showLauncher: {
        if (widget && widget !== root && widget.menuShowLauncher !== undefined) return widget.menuShowLauncher;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.menuShowLauncher !== undefined) return Boolean(Config.rawSettings.bar.menuShowLauncher);
        return true;
    }

    readonly property bool effectiveShowSettings: showSettings || !showLauncher
    readonly property bool iconOnly: menuStyle === "icon"

    readonly property var helpButton: effectiveShowSettings ? settingsBtn : launcherBtn

    property real targetLength: (!module || module.moduleActive) ? ((isVertical ? buttonsFlow.implicitHeight : buttonsFlow.implicitWidth) + s(isCompact ? 6 : 8)) : 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    component MenuButton: Item {
        id: menuBtn
        property string glyph: ""
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
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            bgOpacity: root.barOpacity
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
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
            color: iconMouse.containsMouse ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
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

        MenuButton {
            id: settingsBtn
            visible: root.effectiveShowSettings
            glyph: "󰒓"
            onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh open settings"])
        }

        MenuButton {
            id: launcherBtn
            visible: root.showLauncher
            glyph: "󰍉"
            onClicked: if (!root.isPreview) Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle launcher"])
        }
    }
}
