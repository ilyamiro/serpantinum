import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    property bool showLayout: isPreview || !barWindow || barWindow.isStartupReady
    property bool isVisVisible: moduleActive && showLayout
    property bool isFaceVisible: showLayout
    readonly property bool shouldSubscribe: isVisVisible

    property int barCount: {
        if (widget && widget !== root && widget.barCount !== undefined) return widget.barCount;
        if (module && module.barCount !== undefined) return module.barCount;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let bs = Config.rawSettings.bar || {};
            if (bs.visBarCount !== undefined) return Math.max(4, Math.min(64, bs.visBarCount));
            if (!isVertical && bs.vis && bs.vis.barCount !== undefined) return Math.max(4, Math.min(64, bs.vis.barCount));
            if (!isVertical && bs.visBars !== undefined) return Math.max(4, Math.min(64, bs.visBars));
        }
        return isVertical ? 12 : 16;
    }

    property string visAlignment: {
        if (widget && widget !== root && widget.visAlignment !== undefined) return widget.visAlignment;
        if (module && module.visAlignment !== undefined) return module.visAlignment;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let bs = Config.rawSettings.bar || {};
            if (bs.visAlignment) return bs.visAlignment;
            if (!isVertical && bs.vis && bs.vis.alignment) return bs.vis.alignment;
        }
        return "center";
    }

    property bool visContinuous: {
        if (widget && widget !== root && widget.visContinuous !== undefined) return widget.visContinuous;
        if (module && module.visContinuous !== undefined) return module.visContinuous;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            let bs = Config.rawSettings.bar || {};
            if (bs.visContinuous !== undefined) return Boolean(bs.visContinuous);
            if (!isVertical && bs.vis && bs.vis.continuous !== undefined) return Boolean(bs.vis.continuous);
            if (!isVertical && bs.visStyle !== undefined) return bs.visStyle === "continuous";
        }
        return false;
    }

    SubscriptionGate {
        id: spectrumGate
        target: Spectrum
        wanted: root.shouldSubscribe
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
    }

    property int sampleCount: Math.max(16, Math.min(128, root.barCount * 2))

    readonly property real barThickness: isVertical ? s(root.isCompact ? 3 : 4) : s(root.isCompact ? 4 : 5)
    readonly property real barSp: s(root.isCompact ? 3 : 4)
    readonly property real contentLength: root.barCount * barThickness + Math.max(0, root.barCount - 1) * barSp
    readonly property real padding: isVertical ? s(root.isCompact ? 18 : 22) : s(root.isCompact ? 20 : 24)

    property real targetLength: (moduleActive && contentLength > 0) ? (contentLength + padding) : 0

    readonly property real crossSize: s(root.isCompact ? 24 : 32)
    implicitWidth: isVertical ? crossSize : targetLength
    implicitHeight: isVertical ? targetLength : crossSize

    Timer {
        running: root.moduleActive && barWindow && !root.showLayout
        interval: 100
        onTriggered: {
            if (barWindow && barWindow.isStartupReady) {
                root.showLayout = true;
            }
        }
    }

    Visualizer {
        width: root.isVertical ? Math.max(14, root.width - root.s(8)) : root.contentLength
        height: root.isVertical ? root.contentLength : Math.max(14, root.height - root.s(8))
        anchors.centerIn: parent
        vertical: root.isVertical
        active: spectrumGate.active
        continuous: root.visContinuous
        alignment: (root.visAlignment === "top" || root.visAlignment === "left")
            ? "start"
            : ((root.visAlignment === "bottom" || root.visAlignment === "right") ? "end" : "center")
        count: root.visContinuous ? root.sampleCount : root.barCount
        color: root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
        previewDemo: root.isPreview

        mirrored: root.visContinuous
        curve: root.visContinuous ? 1.25 : 1.4
        interpolate: root.visContinuous
        threshold: root.visContinuous ? 0.03 : 0.04
        gamma: root.visContinuous ? 1.15 : 1.25
        rise: root.visContinuous ? 0.25 : 0.5
        fall: root.visContinuous ? 0.12 : 0.5

        maxLength: root.visContinuous ? (root.isVertical ? width : height) - 2 : (root.isVertical ? width : height)
        spacing: root.barSp
        minLength: root.s(root.isCompact ? 3 : 4)
        opacityBase: 0.45
        opacityRange: 0.55
        opacity: root.visContinuous ? 0.55 + Math.min(0.45, energy * 0.75) : 1.0
    }
}
