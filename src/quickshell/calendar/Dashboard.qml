import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../reusables"
import "."

PanelWindow {
    id: dashboardWindow

    screen: DashboardController.screen

    WlrLayershell.namespace: "qs-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: dashboardWindow.isOpen
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    property bool isOpen: DashboardController.isVisible
    property int configRevision: 0

    SpringProgress {
        id: reveal
        open: dashboardWindow.isOpen
        onActiveChanged: {
            if (!active) content.visible = false;
        }
    }

    readonly property real animProgress: reveal.value

    visible: reveal.active

    function closeDashboard() {
        DashboardController.hide();
    }

    function grabInputFocus() {
        content.forceActiveFocus();
    }

    onIsOpenChanged: {
        if (isOpen) {
            if (content.visible) content.visible = false;
            content.visible = true;
            grabInputFocus();
            focusRetries = 0;
            focusTimer.restart();
        } else {
            focusTimer.stop();
        }
    }

    property int focusRetries: 0

    Timer {
        id: focusTimer
        interval: 60
        repeat: true
        onTriggered: {
            dashboardWindow.grabInputFocus();
            dashboardWindow.focusRetries++;
            if (dashboardWindow.focusRetries >= 4) stop();
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: dashboardWindow.isOpen
        onActivated: dashboardWindow.closeDashboard()
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            DashboardController.hide();
            dashboardWindow.configRevision++;
        }
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
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

    property string barPosition: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "top";
        return Config.rawSettings.bar.position || "top";
    }

    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isOsdFullscreen: (typeof OsdController !== "undefined") ? Boolean(OsdController.isFullscreen) : false

    readonly property bool isToplevelFullscreen: {
        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen) {
                let atl = ToplevelManager.activeToplevel;
                if (atl.screens && atl.screens.length > 0) {
                    return atl.screens.indexOf(dashboardWindow.screen) !== -1;
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

    property real barHeight: {
        let dummy = configRevision;
        let v = (rawBarSettings && rawBarSettings.height !== undefined) ? Number(rawBarSettings.height) : 40;
        if (isNaN(v)) v = 40;
        return Math.round(s(Math.max(28, Math.min(48, v))));
    }

    property real barInset: barHeight + (barStyle === "solid" && !barAutohide ? Math.round(s(4)) : 0)

    readonly property bool isSolid: barStyle === "solid" || barStyle === "fill"
    property real cornerRadius: Math.min(ThemeBackend.borderRadius || s(12), s(28))

    readonly property bool isSideBar: barPosition === "left" || barPosition === "right"
    readonly property real edgeOffset: isBarEffectivelyHidden ? 0 : barInset

    onBarPositionChanged: DashboardController.hide()
    onBarStyleChanged: DashboardController.hide()

    Item {
        id: topBarHole

        property int barThickness: dashboardWindow.barInset
        property string bp: dashboardWindow.barPosition
        property bool activeBar: !dashboardWindow.isBarEffectivelyHidden

        x: {
            if (!activeBar) return 0;
            if (bp === "right") return dashboardWindow.width - barThickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "bottom") return dashboardWindow.height - barThickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            return dashboardWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            return dashboardWindow.height;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: dashboardWindow.isOpen
        onClicked: dashboardWindow.closeDashboard()
    }

    Item {
        id: panel

        readonly property real fullWidth: content.implicitWidth
        readonly property real fullHeight: content.implicitHeight

        width: dashboardWindow.isSideBar ? Math.round(fullWidth * dashboardWindow.animProgress) : fullWidth
        height: dashboardWindow.isSideBar ? fullHeight : Math.round(fullHeight * dashboardWindow.animProgress)

        x: {
            if (dashboardWindow.barPosition === "left") return dashboardWindow.edgeOffset;
            if (dashboardWindow.barPosition === "right") return dashboardWindow.width - dashboardWindow.edgeOffset - width;
            return Math.floor((dashboardWindow.width - width) / 2);
        }

        y: {
            if (dashboardWindow.barPosition === "top") return dashboardWindow.edgeOffset;
            if (dashboardWindow.barPosition === "bottom") return dashboardWindow.height - dashboardWindow.edgeOffset - height;
            return Math.floor((dashboardWindow.height - height) / 2);
        }

        property real filletSize: dashboardWindow.isSolid
            ? Math.round(Math.max(0, Math.min(dashboardWindow.cornerRadius, dashboardWindow.isSideBar ? width : height)))
            : 0

        GlassFillets {
            id: panelFillets
            card: panelCard
            filletRadius: panel.filletSize > 0.5 ? panel.filletSize : 0
            filletDir: dashboardWindow.barPosition === "top" ? Qt.vector2d(0, -1)
                     : dashboardWindow.barPosition === "bottom" ? Qt.vector2d(0, 1)
                     : dashboardWindow.barPosition === "left" ? Qt.vector2d(-1, 0)
                     : Qt.vector2d(1, 0)
        }

        ShaderEffect {
            visible: panel.filletSize > 0.5
            x: {
                if (dashboardWindow.barPosition === "left") return 0;
                if (dashboardWindow.barPosition === "right") return parent.width - panel.filletSize;
                return -panel.filletSize;
            }
            y: {
                if (dashboardWindow.barPosition === "bottom") return parent.height - panel.filletSize;
                if (dashboardWindow.isSideBar) return -panel.filletSize;
                return 0;
            }
            width: panel.filletSize
            height: panel.filletSize
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (dashboardWindow.barPosition === "bottom") return 3.0;
                if (dashboardWindow.barPosition === "left") return 2.0;
                if (dashboardWindow.barPosition === "right") return 3.0;
                return 1.0;
            }
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        ShaderEffect {
            visible: panel.filletSize > 0.5
            x: {
                if (dashboardWindow.barPosition === "left") return 0;
                if (dashboardWindow.barPosition === "right") return parent.width - panel.filletSize;
                return parent.width;
            }
            y: {
                if (dashboardWindow.barPosition === "bottom") return parent.height - panel.filletSize;
                if (dashboardWindow.isSideBar) return parent.height;
                return 0;
            }
            width: panel.filletSize
            height: panel.filletSize
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (dashboardWindow.barPosition === "bottom") return 2.0;
                if (dashboardWindow.barPosition === "left") return 0.0;
                if (dashboardWindow.barPosition === "right") return 1.0;
                return 0.0;
            }
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        Rectangle {
            id: panelCard
            anchors.fill: parent
            color: "transparent"
            radius: dashboardWindow.cornerRadius
            topLeftRadius: (dashboardWindow.barPosition === "top" || dashboardWindow.barPosition === "left") ? 0 : dashboardWindow.cornerRadius
            topRightRadius: (dashboardWindow.barPosition === "top" || dashboardWindow.barPosition === "right") ? 0 : dashboardWindow.cornerRadius
            bottomLeftRadius: (dashboardWindow.barPosition === "bottom" || dashboardWindow.barPosition === "left") ? 0 : dashboardWindow.cornerRadius
            bottomRightRadius: (dashboardWindow.barPosition === "bottom" || dashboardWindow.barPosition === "right") ? 0 : dashboardWindow.cornerRadius
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.fill: parent
            clip: true

            CalendarPopup {
                id: content
                width: Math.max(panel.fullWidth, panel.width)
                height: Math.max(panel.fullHeight, panel.height)
                x: dashboardWindow.barPosition === "left" ? panel.width - width : 0
                y: dashboardWindow.barPosition === "top" ? panel.height - height : 0
                vertical: dashboardWindow.isSideBar
                attachEdge: dashboardWindow.barPosition
            }
        }
    }
}
