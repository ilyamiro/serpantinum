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
        openDuration: dashboardWindow.barSmaller ? 750 : 700
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
    readonly property real modularGap: isSolid ? 0 : Math.round(s(10))
    readonly property real edgeOffset: (isBarEffectivelyHidden ? 0 : barInset) + modularGap

    readonly property var barWin: dashboardWindow.screen ? ShellSurfaces.bars[dashboardWindow.screen.name] : null
    readonly property bool hasBarSpan: barWin ? (isSideBar ? barWin.currentBarMaxY > barWin.currentBarMinY : barWin.currentBarMaxX > barWin.currentBarMinX) : false
    readonly property real spanOrigin: barWin ? (isSideBar ? barWin.margins.top : barWin.margins.left) : 0
    readonly property real spanStart: hasBarSpan ? spanOrigin + (isSideBar ? barWin.currentBarMinY : barWin.currentBarMinX) : 0
    readonly property real spanEnd: hasBarSpan ? spanOrigin + (isSideBar ? barWin.currentBarMaxY : barWin.currentBarMaxX) : (isSideBar ? height : width)
    readonly property real barEndRadius: Math.min(barStyle === "fill" ? s(12) : ThemeBackend.borderRadius, barHeight / 2)
    readonly property real spanInset: barEndRadius + cornerRadius
    readonly property real panelLength: isSideBar ? panel.fullHeight : panel.fullWidth
    readonly property bool fitsBar: isSolid && cornerRadius > 0.5 && panelLength <= spanEnd - spanStart - 2 * spanInset

    function fitToBar(pos, len, lo, hi) {
        if (fitsBar) return Math.max(spanStart + spanInset, Math.min(spanEnd - spanInset - len, pos));
        if (!isSolid || !hasBarSpan) return pos;
        let r = barEndRadius;
        if (pos + len > spanEnd - r && pos + len < spanEnd) pos = spanEnd - len;
        if (pos > spanStart && pos < spanStart + r) pos = spanStart;
        return Math.max(lo, Math.min(hi, pos));
    }

    readonly property bool barSmaller: !isBarEffectivelyHidden && hasBarSpan && panelLength > spanEnd - spanStart
    readonly property real perpProgress: !barSmaller ? animProgress
        : (isOpen ? reveal.springValue(Math.min(1, reveal.time / 0.2)) : Math.min(1, animProgress / 0.55))
    readonly property real alongProgress: !barSmaller ? 1
        : (isOpen ? reveal.springValue(Math.max(0, (reveal.time - 0.15) / 0.55)) : Math.max(0, (animProgress - 0.55) / 0.45))

    readonly property bool startOnBar: (isSideBar ? panel.y : panel.x) >= spanStart + barEndRadius - 1
    readonly property bool endOnBar: (isSideBar ? panel.y + panel.height : panel.x + panel.width) <= spanEnd - barEndRadius + 1
    readonly property bool flatStart: isSolid && startOnBar
    readonly property bool flatEnd: isSolid && endOnBar
    readonly property bool pastBarStart: isSolid && hasBarSpan && barEndRadius > 0.5 && (isSideBar ? panel.y : panel.x) <= spanStart + 1
    readonly property bool pastBarEnd: isSolid && hasBarSpan && barEndRadius > 0.5 && (isSideBar ? panel.y + panel.height : panel.x + panel.width) >= spanEnd - 1

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

    component BarCornerFill: Item {
        id: cornerFill
        property bool atStart: true
        property bool outward: false
        readonly property real thickness: dashboardWindow.isSideBar ? panel.width : panel.height
        readonly property real openGate: dashboardWindow.isOpen ? Math.max(0, Math.min(1, (dashboardWindow.perpProgress - 0.5) / 0.4)) : 1
        readonly property real size: Math.min(dashboardWindow.barEndRadius, thickness) * openGate
        width: size
        height: size
        x: {
            if (dashboardWindow.isSideBar) return dashboardWindow.barPosition === "right" ? parent.width : -width;
            let along = outward ? (atStart ? dashboardWindow.spanStart - width : dashboardWindow.spanEnd) : (atStart ? dashboardWindow.spanStart : dashboardWindow.spanEnd - width);
            return along - panel.x;
        }
        y: {
            if (!dashboardWindow.isSideBar) return dashboardWindow.barPosition === "bottom" ? parent.height : -height;
            let along = outward ? (atStart ? dashboardWindow.spanStart - height : dashboardWindow.spanEnd) : (atStart ? dashboardWindow.spanStart : dashboardWindow.spanEnd - height);
            return along - panel.y;
        }
        readonly property real cornerIndex: {
            if (outward) {
                if (dashboardWindow.barPosition === "top") return atStart ? 3.0 : 2.0;
                if (dashboardWindow.barPosition === "bottom") return atStart ? 1.0 : 0.0;
                if (dashboardWindow.barPosition === "left") return atStart ? 3.0 : 1.0;
                return atStart ? 2.0 : 0.0;
            }
            if (dashboardWindow.isSideBar) {
                if (dashboardWindow.barPosition === "right") return atStart ? 0.0 : 2.0;
                return atStart ? 1.0 : 3.0;
            }
            if (dashboardWindow.barPosition === "bottom") return atStart ? 0.0 : 1.0;
            return atStart ? 2.0 : 3.0;
        }

        WallpaperBlur {
            anchors.fill: parent
            standalone: true
            surfaceEnabled: !ThemeBackend.liquidGlass
            maskItem: cornerFillMask
            radius: 0
        }

        Item {
            id: cornerFillMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            ShaderEffect {
                anchors.fill: parent
                property vector2d itemSize: Qt.vector2d(width, height)
                property real cornerIndex: cornerFill.cornerIndex
                property color color: "black"
                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
            }
        }

        ShaderEffect {
            anchors.fill: parent
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: cornerFill.cornerIndex
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }
    }

    Item {
        id: panel

        readonly property real fullWidth: content.implicitWidth
        readonly property real fullHeight: content.implicitHeight

        readonly property real alongLength: dashboardWindow.isSideBar ? fullHeight : fullWidth
        readonly property real alongExtent: dashboardWindow.isSideBar ? dashboardWindow.height : dashboardWindow.width
        readonly property real alongFinalStart: Math.round(dashboardWindow.fitToBar(Math.floor((alongExtent - alongLength) / 2), alongLength, 0, alongExtent - alongLength))
        readonly property real alongStart: dashboardWindow.barSmaller ? dashboardWindow.spanStart + (alongFinalStart - dashboardWindow.spanStart) * dashboardWindow.alongProgress : alongFinalStart
        readonly property real alongEnd: dashboardWindow.barSmaller ? dashboardWindow.spanEnd + (alongFinalStart + alongLength - dashboardWindow.spanEnd) * dashboardWindow.alongProgress : alongFinalStart + alongLength

        width: dashboardWindow.isSideBar ? Math.round(fullWidth * dashboardWindow.perpProgress) : Math.round(alongEnd - alongStart)
        height: dashboardWindow.isSideBar ? Math.round(alongEnd - alongStart) : Math.round(fullHeight * dashboardWindow.perpProgress)

        x: {
            if (dashboardWindow.barPosition === "left") return dashboardWindow.edgeOffset;
            if (dashboardWindow.barPosition === "right") return dashboardWindow.width - dashboardWindow.edgeOffset - width;
            return Math.round(alongStart);
        }

        y: {
            if (dashboardWindow.barPosition === "top") return dashboardWindow.edgeOffset;
            if (dashboardWindow.barPosition === "bottom") return dashboardWindow.height - dashboardWindow.edgeOffset - height;
            return Math.round(alongStart);
        }

        property real filletSize: dashboardWindow.fitsBar
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

        BarCornerFill {
            atStart: true
            visible: dashboardWindow.pastBarStart
        }

        BarCornerFill {
            atStart: false
            visible: dashboardWindow.pastBarEnd
        }

        BarCornerFill {
            atStart: true
            outward: true
            visible: dashboardWindow.pastBarStart
        }

        BarCornerFill {
            atStart: false
            outward: true
            visible: dashboardWindow.pastBarEnd
        }

        Rectangle {
            id: panelCard
            anchors.fill: parent
            color: "transparent"
            radius: dashboardWindow.cornerRadius
            topLeftRadius: (dashboardWindow.barPosition === "top" || dashboardWindow.barPosition === "left") && dashboardWindow.flatStart ? 0 : dashboardWindow.cornerRadius
            topRightRadius: ((dashboardWindow.barPosition === "top" && dashboardWindow.flatEnd) || (dashboardWindow.barPosition === "right" && dashboardWindow.flatStart)) ? 0 : dashboardWindow.cornerRadius
            bottomLeftRadius: ((dashboardWindow.barPosition === "bottom" && dashboardWindow.flatStart) || (dashboardWindow.barPosition === "left" && dashboardWindow.flatEnd)) ? 0 : dashboardWindow.cornerRadius
            bottomRightRadius: (dashboardWindow.barPosition === "bottom" || dashboardWindow.barPosition === "right") && dashboardWindow.flatEnd ? 0 : dashboardWindow.cornerRadius
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
                x: dashboardWindow.isSideBar ? (dashboardWindow.barPosition === "left" ? panel.width - width : 0) : panel.alongFinalStart - panel.x
                y: dashboardWindow.isSideBar ? panel.alongFinalStart - panel.y : (dashboardWindow.barPosition === "top" ? panel.height - height : 0)
                vertical: dashboardWindow.isSideBar
                cornerTopLeft: panelCard.topLeftRadius
                cornerTopRight: panelCard.topRightRadius
                cornerBottomLeft: panelCard.bottomLeftRadius
                cornerBottomRight: panelCard.bottomRightRadius
            }
        }
    }
}
