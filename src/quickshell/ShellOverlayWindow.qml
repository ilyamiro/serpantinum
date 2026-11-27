import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: overlayWindow

    property bool overlayOpen: false
    property bool interactiveFocus: true
    property bool exclusiveKeyboardFocus: false
    property bool dismissOnOutsideClick: false
    property bool carveBarHole: false
    property bool trackFullscreen: carveBarHole
    property int barHoleThickness: SurfaceRegistry.barInset
    property bool escapeEnabled: overlayOpen
    property bool mountedReady: false
    property Item focusTarget: null
    property int focusRetryInterval: 50
    property int maxFocusRetries: 4
    property int _focusAttempts: 0

    readonly property bool isFullscreenActive: overlayWindow.trackFullscreen ? Compositor.isFullscreenOn(overlayWindow.screen) : false
    readonly property bool isBarEffectivelyHidden: SurfaceRegistry.barAutohide || isFullscreenActive || !SurfaceRegistry.isBarEnabledOnScreen(overlayWindow.screen)
    readonly property Item barHoleItem: barHole

    signal outsideClicked()
    signal escapeDismissed()

    function s(val) {
        return Scaler.s(val);
    }

    function handleEscape() {
        return false;
    }

    function _focusOneShot() {
        let target = overlayWindow.focusTarget || overlayWindow.contentItem;
        if (!target) return false;
        if (typeof overlayWindow.requestActivate === "function") {
            overlayWindow.requestActivate();
        }
        if (typeof target.forceInputFocus === "function") {
            target.forceInputFocus();
        } else {
            target.forceActiveFocus();
        }
        return Boolean(target.activeFocus || target.hasFocus);
    }

    function acquireFocus() {
        if (!overlayWindow.overlayOpen) return;
        overlayWindow._focusAttempts = 0;
        overlayWindow._focusOneShot();
        focusAcquireTimer.restart();
    }

    function stopFocusAcquire() {
        focusAcquireTimer.stop();
        overlayWindow._focusAttempts = 0;
    }

    Timer {
        id: focusAcquireTimer
        interval: overlayWindow.focusRetryInterval
        repeat: true
        onTriggered: {
            if (!overlayWindow.overlayOpen) {
                stop();
                return;
            }
            overlayWindow._focusAttempts++;
            let got = overlayWindow._focusOneShot();
            if (got || overlayWindow._focusAttempts >= overlayWindow.maxFocusRetries) {
                stop();
            }
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: overlayWindow.overlayOpen && overlayWindow.interactiveFocus
        ? (overlayWindow.exclusiveKeyboardFocus ? WlrKeyboardFocus.Exclusive : Compositor.interactiveKeyboardFocus)
        : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: barHoleRegion
        item: barHole
        intersection: Intersection.Xor
    }

    mask: overlayWindow.carveBarHole ? barHoleRegion : null

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: overlayWindow.escapeEnabled
        onActivated: {
            if (!overlayWindow.handleEscape()) {
                overlayWindow.escapeDismissed();
            }
        }
    }

    Item {
        id: barHole

        readonly property int thickness: overlayWindow.barHoleThickness
        readonly property string bp: SurfaceRegistry.barPosition
        readonly property bool activeBar: overlayWindow.carveBarHole && !overlayWindow.isBarEffectivelyHidden

        x: {
            if (!activeBar) return 0;
            if (bp === "right") return overlayWindow.width - thickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "bottom") return overlayWindow.height - thickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return thickness;
            return overlayWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return thickness;
            return overlayWindow.height;
        }
    }

    MouseArea {
        id: outsideClickArea
        z: -10
        anchors.fill: parent
        enabled: overlayWindow.overlayOpen && overlayWindow.dismissOnOutsideClick
        onClicked: overlayWindow.outsideClicked()
    }

    onOverlayOpenChanged: {
        if (overlayOpen) {
            if (overlayWindow.interactiveFocus) {
                Qt.callLater(overlayWindow.acquireFocus);
            }
        } else {
            overlayWindow.stopFocusAcquire();
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            overlayWindow.mountedReady = true;
        });
    }
}
