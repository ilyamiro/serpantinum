import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"
import "."

ShellOverlayWindow {
    id: dashboardWindow

    screen: DashboardController.screen

    WlrLayershell.namespace: "qs-dashboard"
    overlayOpen: DashboardController.isVisible
    carveBarHole: true
    barHoleThickness: SurfaceRegistry.barInset
    dismissOnOutsideClick: true
    focusTarget: content
    focusRetryInterval: 60
    maxFocusRetries: 4

    onOutsideClicked: dashboardWindow.closeDashboard()
    onEscapeDismissed: dashboardWindow.closeDashboard()

    readonly property bool isOpen: DashboardController.isVisible

    SpringProgress {
        id: reveal
        open: dashboardWindow.mountedReady && dashboardWindow.isOpen
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

    function applyOpenState() {
        if (isOpen) {
            if (content.visible) content.visible = false;
            content.visible = true;
            dashboardWindow.acquireFocus();
        } else {
            dashboardWindow.stopFocusAcquire();
        }
    }

    onIsOpenChanged: {
        if (mountedReady) applyOpenState();
    }

    onMountedReadyChanged: {
        if (mountedReady && dashboardWindow.isOpen) dashboardWindow.applyOpenState();
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            DashboardController.hide();
        }
    }

    readonly property string barStyle: SurfaceRegistry.barStyle
    readonly property string barPosition: SurfaceRegistry.barPosition
    readonly property real barHeight: Math.round(s(SurfaceRegistry.barRawHeight))
    readonly property real barInset: SurfaceRegistry.barInset

    readonly property bool isSolid: SurfaceRegistry.isSolidBar || SurfaceRegistry.isFillBar
    property real cornerRadius: Math.min(ThemeBackend.borderRadius || s(12), s(28))

    readonly property bool isSideBar: SurfaceRegistry.isSideBar
    readonly property real modularGap: isSolid ? 0 : Math.round(s(10))
    readonly property real edgeOffset: (isBarEffectivelyHidden ? 0 : barInset) + modularGap

    readonly property var barSpan: {
        let _rev = SurfaceRegistry.windowsRevision;
        let name = dashboardWindow.screen ? dashboardWindow.screen.name : "";
        return SurfaceRegistry.barSpanOn(name);
    }
    readonly property bool hasBarSpan: barSpan.valid
    readonly property real spanStart: hasBarSpan ? (isSideBar ? barSpan.minY : barSpan.minX) : 0
    readonly property real spanEnd: hasBarSpan ? (isSideBar ? barSpan.maxY : barSpan.maxX) : (isSideBar ? height : width)
    readonly property real barEndRadius: Math.min(barStyle === "fill" ? s(12) : ThemeBackend.borderRadius, barHeight / 2)
    readonly property real panelLength: isSideBar ? panel.fullHeight : panel.fullWidth

    function fitToBar(pos, len, lo, hi) {
        let extent = hi + len + lo;
        return SurfaceRegistry.fitToBar(pos, len, hasBarSpan ? spanStart : 0, hasBarSpan ? spanEnd : 0, extent, lo, barEndRadius, cornerRadius, isSolid);
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

    onBarPositionChanged: if (mountedReady) DashboardController.hide()
    onBarStyleChanged: if (mountedReady) DashboardController.hide()

    AttachedSurface {
        kind: "dashboard"
        visible: dashboardWindow.visible && panel.width > 0 && panel.height > 0
        rects: [{ x: panel.x, y: panel.y, w: panel.width, h: panel.height, r: [panelCard.topLeftRadius, panelCard.topRightRadius, panelCard.bottomRightRadius, panelCard.bottomLeftRadius] }]
        filletRadius: dashboardWindow.isSolid ? dashboardWindow.cornerRadius : 0
        attachTo: dashboardWindow.isSolid && !dashboardWindow.isBarEffectivelyHidden ? ["bar"] : []
        publishShape: dashboardWindow.isSolid && !dashboardWindow.isBarEffectivelyHidden
        edges: dashboardWindow.isSolid && dashboardWindow.isBarEffectivelyHidden ? [dashboardWindow.barPosition] : []
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
                x: dashboardWindow.isSideBar ? (dashboardWindow.barPosition === "right" ? panel.width - width : 0) : panel.alongFinalStart - panel.x
                y: dashboardWindow.isSideBar ? panel.alongFinalStart - panel.y : (dashboardWindow.barPosition === "bottom" ? panel.height - height : 0)
                vertical: dashboardWindow.isSideBar
                cornerTopLeft: panelCard.topLeftRadius
                cornerTopRight: panelCard.topRightRadius
                cornerBottomLeft: panelCard.bottomLeftRadius
                cornerBottomRight: panelCard.bottomRightRadius
                backgroundColor: "transparent"
            }
        }
    }
}
