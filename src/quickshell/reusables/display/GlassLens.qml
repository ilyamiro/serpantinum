import QtQuick
import "../../"
import "../"

Item {
    id: root

    property bool shown: true
    property bool instant: false
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

    property real radius: 8
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    property color tintColor: ThemeBackend.base
    property real tintAmount: 0.4
    property real tintStrength: 0.5
    property real shadow: 1
    property real restPress: 0.35
    property real press: 0
    property real pulse: 0
    property bool allowed: true
    property bool forceClear: false
    property bool forceOpaque: false
    property bool followBackdropHover: true
    property Item backdropOverride: null

    property real magnify: 0
    property real maxMagnify: 0.16
    property int fastDuration: 200
    property int slowDuration: 350
    property int liftDuration: 240
    property int fadeDuration: 160

    readonly property bool glassActive: glass.active
    readonly property bool hasTarget: shown && targetWidth > 0 && targetHeight > 0
    readonly property bool moving: hasTarget && (Math.abs(actualLeft - targetX) > 0.5
        || Math.abs(actualRight - (targetX + targetWidth)) > 0.5
        || Math.abs(actualTop - targetY) > 0.5
        || Math.abs(actualBottom - (targetY + targetHeight)) > 0.5)

    property real actualLeft: 0
    property real actualRight: 0
    property real actualTop: 0
    property real actualBottom: 0
    property bool placed: false
    property bool settling: false
    property real lastCenterX: 0
    property real lastCenterY: 0

    property real lift: (glass.active && moving) ? 1.0 : 0.0
    Behavior on lift { NumberAnimation { duration: root.liftDuration; easing.type: Easing.OutCubic } }

    function runEdge(anim, value) {
        anim.stop();
        anim.to = value;
        anim.start();
    }

    function snap() {
        leftAnim.stop();
        rightAnim.stop();
        topAnim.stop();
        bottomAnim.stop();
        if (targetX > actualLeft) {
            actualRight = targetX + targetWidth;
            actualLeft = targetX;
        } else {
            actualLeft = targetX;
            actualRight = targetX + targetWidth;
        }
        if (targetY > actualTop) {
            actualBottom = targetY + targetHeight;
            actualTop = targetY;
        } else {
            actualTop = targetY;
            actualBottom = targetY + targetHeight;
        }
        lastCenterX = targetX + targetWidth / 2;
        lastCenterY = targetY + targetHeight / 2;
    }

    function sync() {
        if (!hasTarget) return;
        if (!placed || !glass.active || settling || instant) {
            snap();
            placed = true;
            return;
        }
        const cx = targetX + targetWidth / 2;
        const cy = targetY + targetHeight / 2;
        if (cx > lastCenterX) { rightAnim.duration = fastDuration; leftAnim.duration = slowDuration; }
        else if (cx < lastCenterX) { leftAnim.duration = fastDuration; rightAnim.duration = slowDuration; }
        if (cy > lastCenterY) { bottomAnim.duration = fastDuration; topAnim.duration = slowDuration; }
        else if (cy < lastCenterY) { topAnim.duration = fastDuration; bottomAnim.duration = slowDuration; }
        lastCenterX = cx;
        lastCenterY = cy;
        runEdge(leftAnim, targetX);
        runEdge(rightAnim, targetX + targetWidth);
        runEdge(topAnim, targetY);
        runEdge(bottomAnim, targetY + targetHeight);
    }

    function scheduleSync() { Qt.callLater(root.sync); }

    onTargetXChanged: scheduleSync()
    onTargetYChanged: scheduleSync()
    onTargetWidthChanged: scheduleSync()
    onTargetHeightChanged: scheduleSync()
    onHasTargetChanged: scheduleSync()
    onInstantChanged: if (instant) scheduleSync()
    Component.onCompleted: scheduleSync()

    Connections {
        target: glass
        function onActiveChanged() { Qt.callLater(root.handleGlassToggled); }
    }

    function handleGlassToggled() {
        settling = glass.active;
        if (glass.active) settleTimer.restart();
        if (!hasTarget) return;
        snap();
        placed = true;
    }

    Timer {
        id: settleTimer
        interval: 300
        onTriggered: root.settling = false
    }

    NumberAnimation { id: leftAnim; target: root; property: "actualLeft"; duration: root.slowDuration; easing.type: Easing.OutExpo }
    NumberAnimation { id: rightAnim; target: root; property: "actualRight"; duration: root.slowDuration; easing.type: Easing.OutExpo }
    NumberAnimation { id: topAnim; target: root; property: "actualTop"; duration: root.slowDuration; easing.type: Easing.OutExpo }
    NumberAnimation { id: bottomAnim; target: root; property: "actualBottom"; duration: root.slowDuration; easing.type: Easing.OutExpo }

    x: actualLeft
    y: actualTop
    width: Math.max(0, actualRight - actualLeft)
    height: Math.max(0, actualBottom - actualTop)
    visible: hasTarget || opacity > 0
    opacity: (hasTarget && placed) ? 1 : 0
    onOpacityChanged: {
        if (opacity === 0 && !hasTarget) placed = false;
    }
    Behavior on opacity { enabled: ThemeBackend.liquidGlass; NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic } }

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: 1 + Math.min(root.maxMagnify, root.magnify / Math.max(1, root.width)) * root.lift
        yScale: 1 + Math.min(root.maxMagnify, root.magnify / Math.max(1, root.height)) * root.lift
    }

    GlassFill {
        id: glass
        anchors.fill: parent
        allowed: root.allowed
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        tintColor: root.tintColor
        tintAmount: root.tintAmount
        tintStrength: root.tintStrength
        shadow: root.shadow
        forceClear: root.forceClear
        forceOpaque: root.forceOpaque
        followBackdropHover: root.followBackdropHover
        backdropOverride: root.backdropOverride
        press: Math.min(1, Math.max(root.press, root.restPress + (1 - root.restPress) * root.lift))
        pulse: root.pulse
    }
}
