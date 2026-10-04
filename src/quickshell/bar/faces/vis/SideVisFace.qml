import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? !!activeTarget.isPreview : (!barWindow)

    property bool showLayout: isPreview || !barWindow || barWindow.isStartupReady
    property bool isVisVisible: (activeTarget ? activeTarget.moduleActive : true) && showLayout
    property bool isFaceVisible: showLayout
    property bool isSubscribed: false
    readonly property bool shouldSubscribe: isVisVisible

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property int barCount: {
        if (widget && widget !== root && widget.barCount !== undefined) return widget.barCount;
        if (module && module.barCount !== undefined) return module.barCount;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let ss = Config.rawSettings.sideBar || {};
            let bs = Config.rawSettings.bar || {};
            if (ss.visBarCount !== undefined) return Math.max(4, Math.min(64, ss.visBarCount));
            if (bs.sideVisBarCount !== undefined) return Math.max(4, Math.min(64, bs.sideVisBarCount));
            if (bs.visBarCount !== undefined) return Math.max(4, Math.min(64, bs.visBarCount));
        }
        return 12;
    }

    property string visAlignment: {
        if (widget && widget !== root && widget.visAlignment !== undefined) return widget.visAlignment;
        if (module && module.visAlignment !== undefined) return module.visAlignment;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let ss = Config.rawSettings.sideBar || {};
            let bs = Config.rawSettings.bar || {};
            if (ss.visAlignment) return ss.visAlignment;
            if (bs.sideVisAlignment) return bs.sideVisAlignment;
            if (bs.visAlignment) return bs.visAlignment;
        }
        return "center";
    }

    property bool visContinuous: {
        if (widget && widget !== root && widget.visContinuous !== undefined) return widget.visContinuous;
        if (module && module.visContinuous !== undefined) return module.visContinuous;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let ss = Config.rawSettings.sideBar || {};
            let bs = Config.rawSettings.bar || {};
            if (ss.visContinuous !== undefined) return Boolean(ss.visContinuous);
            if (bs.sideVisContinuous !== undefined) return Boolean(bs.sideVisContinuous);
            if (bs.visContinuous !== undefined) return Boolean(bs.visContinuous);
        }
        return false;
    }

    onShouldSubscribeChanged: updateSubscription()

    function updateSubscription() {
        if (shouldSubscribe && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!shouldSubscribe && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Connections {
        target: (!isPreview && barWindow) ? barWindow : null
        function onIsStartupReadyChanged() {
            if (barWindow && barWindow.isStartupReady) {
                root.showLayout = true;
            }
        }
    }

    Component.onCompleted: {
        if (!barWindow || barWindow.isStartupReady) {
            root.showLayout = true;
        }
        updateSubscription();
    }

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    property int demoTick: 0
    Timer {
        interval: 33
        running: Boolean(isVisVisible && activeTarget && activeTarget.isPreview)
        repeat: true
        onTriggered: root.demoTick++
    }

    property var barLevels: {
        if (!root.isSubscribed || root.visContinuous) return [];
        let dummy = demoTick;
        let source = Cava.barLevels;
        let count = barCount;
        let out = [];

        if (activeTarget && activeTarget.isPreview && (!source || source.length === 0 || source.every(v => v === 0))) {
            let t = Date.now() / 600;
            for (let i = 0; i < count; i++) {
                let norm = count > 1 ? (i / (count - 1)) : 0.5;
                let wave1 = Math.sin(norm * Math.PI * 2 + t) * 0.5 + 0.5;
                let wave2 = Math.cos(norm * Math.PI * 3 - t * 0.8) * 0.3 + 0.3;
                let env = Math.sin(norm * Math.PI);
                let val = (wave1 * 0.6 + wave2 * 0.4) * env;
                out.push(Math.max(0.08, Math.min(1.0, val)));
            }
            return out;
        }

        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return out;
        }

        for (let i = 0; i < count; i++) {
            let norm = count > 1 ? (i / (count - 1)) : 0;
            let srcIdx = Math.min(source.length - 1, Math.floor(Math.pow(norm, 1.4) * (source.length - 1)));
            let val = source[srcIdx] || 0.0;
            out.push(val < 0.04 ? 0.0 : Math.pow((val - 0.04) / 0.96, 1.25));
        }
        return out;
    }

    property int sampleCount: Math.max(16, Math.min(128, root.barCount * 2))

    property var processedContinuousBars: {
        if (!root.isSubscribed || !root.visContinuous) return [];
        let dummy = demoTick;
        let source = Cava.barLevels;
        let count = sampleCount;
        let out = [];

        if (activeTarget && activeTarget.isPreview && (!source || source.length === 0 || source.every(v => v === 0))) {
            let t = Date.now() / 600;
            for (let i = 0; i < count; i++) {
                let norm = count > 1 ? (i / (count - 1)) : 0.5;
                let wave1 = Math.sin(norm * Math.PI * 2 + t) * 0.5 + 0.5;
                let wave2 = Math.cos(norm * Math.PI * 3 - t * 0.8) * 0.3 + 0.3;
                let env = Math.sin(norm * Math.PI);
                let val = (wave1 * 0.6 + wave2 * 0.4) * env;
                out.push(Math.max(0.0, Math.min(1.0, val)));
            }
        } else if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return out;
        } else {
            let srcLen = source.length;
            let half = (count - 1) / 2;

            for (let i = 0; i < count; i++) {
                let distFromCenter = Math.abs(i - half);
                let norm = half > 0 ? (distFromCenter / half) : 0;
                let pos = Math.pow(norm, 1.25) * (srcLen - 1);
                let idx0 = Math.floor(pos);
                let idx1 = Math.min(srcLen - 1, idx0 + 1);
                let frac = pos - idx0;

                let v0 = source[idx0] || 0.0;
                let v1 = source[idx1] || 0.0;
                let rawVal = v0 + (v1 - v0) * frac;

                let val = rawVal < 0.03 ? 0.0 : Math.pow((rawVal - 0.03) / 0.97, 1.15);
                val = Math.max(0.0, Math.min(1.0, val));
                out.push(val);
            }
        }

        let smoothed = [];
        for (let i = 0; i < count; i++) {
            let prev = i > 0 ? out[i - 1] : out[i];
            let curr = out[i];
            let next = i < count - 1 ? out[i + 1] : out[i];
            let sm = prev * 0.25 + curr * 0.5 + next * 0.25;

            let edgeNorm = Math.sin((i / Math.max(1, count - 1)) * Math.PI);
            let edgeFactor = Math.min(1.0, edgeNorm * 2.0);
            edgeFactor = edgeFactor * edgeFactor * (3.0 - 2.0 * edgeFactor);
            smoothed.push(sm * edgeFactor);
        }

        return smoothed;
    }

    property var smoothLevels: []
    property real totalEnergy: 0.0

    Timer {
        id: continuousTimer
        interval: 16
        running: root.isVisVisible && root.visContinuous
        repeat: true
        onTriggered: {
            let targets = root.processedContinuousBars;
            let current = root.smoothLevels;
            let updated = [];
            let sum = 0.0;
            let count = root.sampleCount;

            for (let i = 0; i < count; i++) {
                let target = (targets && i < targets.length) ? targets[i] : 0.0;
                let cur = (current && i < current.length) ? current[i] : 0.0;
                let factor = target > cur ? 0.25 : 0.12;
                let next = cur + (target - cur) * factor;
                updated.push(next);
                sum += next;
            }

            root.smoothLevels = updated;
            root.totalEnergy = count > 0 ? (sum / count) : 0.0;
            if (continuousCanvas) continuousCanvas.requestPaint();
        }
    }

    onVisContinuousChanged: {
        if (visContinuous && continuousCanvas) {
            continuousCanvas.requestPaint();
        }
    }

    onVisAlignmentChanged: {
        if (continuousCanvas) {
            continuousCanvas.requestPaint();
        }
    }

    readonly property real barH: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)
    readonly property real barSp: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)
    readonly property real contentHeight: root.barCount * barH + Math.max(0, root.barCount - 1) * barSp
    readonly property real paddingV: barWindow ? barWindow.s(root.isCompact ? 18 : 22) : (root.isCompact ? 18 : 22)

    property real targetHeight: ((activeTarget ? activeTarget.moduleActive : true) && contentHeight > 0) ? (contentHeight + paddingV) : 0

    implicitHeight: targetHeight
    implicitWidth: (barWindow && typeof barWindow.s === "function") ? barWindow.s(root.isCompact ? 24 : 32) : (root.isCompact ? 24 : 32)

    Timer {
        running: (activeTarget ? activeTarget.moduleActive : true) && barWindow && !root.showLayout
        interval: 100
        onTriggered: {
            if (barWindow && barWindow.isStartupReady) {
                root.showLayout = true;
            }
        }
    }

    Item {
        id: visContainer
        height: root.contentHeight
        width: Math.max(14, root.width - (barWindow ? barWindow.s(8) : 8))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Column {
            id: innerCol
            anchors.fill: parent
            spacing: root.barSp
            visible: !root.visContinuous

            Repeater {
                model: root.barCount
                delegate: Item {
                    id: sideBarSlot
                    width: parent.width
                    height: root.barH

                    Rectangle {
                        id: sideBarRect
                        height: parent.height
                        property real level: (root.barLevels && index < root.barLevels.length) ? root.barLevels[index] : 0.0
                        property real minW: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)
                        property real maxW: parent.width
                        width: Math.max(minW, level * maxW)
                        topLeftRadius: (root.visAlignment === "left" || root.visAlignment === "top") ? 0 : height * 0.5
                        bottomLeftRadius: (root.visAlignment === "left" || root.visAlignment === "top") ? 0 : height * 0.5
                        topRightRadius: (root.visAlignment === "right" || root.visAlignment === "bottom") ? 0 : height * 0.5
                        bottomRightRadius: (root.visAlignment === "right" || root.visAlignment === "bottom") ? 0 : height * 0.5
                        color: root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
                        opacity: 0.45 + (level * 0.55)

                        x: (root.visAlignment === "left" || root.visAlignment === "top")
                            ? 0
                            : ((root.visAlignment === "right" || root.visAlignment === "bottom")
                                ? (parent.width - width)
                                : Math.round((parent.width - width) / 2))

                        Behavior on width {
                            NumberAnimation {
                                duration: 55
                                easing.type: Easing.OutQuad
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 55 }
                        }
                    }
                }
            }
        }

        Canvas {
            id: continuousCanvas
            anchors.fill: parent
            visible: root.visContinuous
            opacity: 0.55 + Math.min(0.45, root.totalEnergy * 0.75)

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                let ctx = getContext("2d");
                let w = width;
                let h = height;

                ctx.reset();
                ctx.clearRect(0, 0, w, h);

                let levels = root.smoothLevels;
                if (!levels || levels.length === 0 || w <= 0 || h <= 0) return;

                let count = levels.length;
                let align = root.visAlignment;

                ctx.fillStyle = root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve;

                if (align === "left" || align === "top") {
                    let pts = [];
                    for (let i = 0; i < count; i++) {
                        let py = (i / (count - 1)) * h;
                        let px = levels[i] * (w - 2);
                        pts.push({ x: px, y: py });
                    }

                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(pts[0].x, pts[0].y);

                    for (let i = 0; i < pts.length - 1; i++) {
                        let p0 = pts[i];
                        let p1 = pts[i + 1];
                        let mx = (p0.x + p1.x) / 2;
                        let my = (p0.y + p1.y) / 2;
                        ctx.quadraticCurveTo(p0.x, p0.y, mx, my);
                    }

                    let last = pts[pts.length - 1];
                    ctx.lineTo(last.x, last.y);
                    ctx.lineTo(0, h);
                    ctx.closePath();
                    ctx.fill();

                } else if (align === "right" || align === "bottom") {
                    let pts = [];
                    for (let i = 0; i < count; i++) {
                        let py = (i / (count - 1)) * h;
                        let px = w - (levels[i] * (w - 2));
                        pts.push({ x: px, y: py });
                    }

                    ctx.beginPath();
                    ctx.moveTo(w, 0);
                    ctx.lineTo(pts[0].x, pts[0].y);

                    for (let i = 0; i < pts.length - 1; i++) {
                        let p0 = pts[i];
                        let p1 = pts[i + 1];
                        let mx = (p0.x + p1.x) / 2;
                        let my = (p0.y + p1.y) / 2;
                        ctx.quadraticCurveTo(p0.x, p0.y, mx, my);
                    }

                    let last = pts[pts.length - 1];
                    ctx.lineTo(last.x, last.y);
                    ctx.lineTo(w, h);
                    ctx.closePath();
                    ctx.fill();

                } else {
                    let cx = w / 2;
                    let maxHalf = (w / 2) - 1;
                    let leftPts = [];
                    let rightPts = [];

                    for (let i = 0; i < count; i++) {
                        let py = (i / (count - 1)) * h;
                        let halfW = levels[i] * maxHalf;
                        leftPts.push({ x: cx - halfW, y: py });
                        rightPts.push({ x: cx + halfW, y: py });
                    }

                    ctx.beginPath();
                    ctx.moveTo(cx, leftPts[0].y);
                    ctx.lineTo(leftPts[0].x, leftPts[0].y);

                    for (let i = 0; i < leftPts.length - 1; i++) {
                        let p0 = leftPts[i];
                        let p1 = leftPts[i + 1];
                        let mx = (p0.x + p1.x) / 2;
                        let my = (p0.y + p1.y) / 2;
                        ctx.quadraticCurveTo(p0.x, p0.y, mx, my);
                    }

                    let lastLeft = leftPts[leftPts.length - 1];
                    ctx.lineTo(lastLeft.x, lastLeft.y);
                    ctx.lineTo(cx, lastLeft.y);
                    ctx.lineTo(rightPts[rightPts.length - 1].x, rightPts[rightPts.length - 1].y);

                    for (let i = rightPts.length - 1; i > 0; i--) {
                        let p0 = rightPts[i];
                        let p1 = rightPts[i - 1];
                        let mx = (p0.x + p1.x) / 2;
                        let my = (p0.y + p1.y) / 2;
                        ctx.quadraticCurveTo(p0.x, p0.y, mx, my);
                    }

                    ctx.lineTo(rightPts[0].x, rightPts[0].y);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }
    }
}
