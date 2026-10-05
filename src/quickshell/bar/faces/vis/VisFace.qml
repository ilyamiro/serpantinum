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
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.visBarCount !== undefined) return Math.max(4, Math.min(64, bs.visBarCount));
            if (bs.vis && bs.vis.barCount !== undefined) return Math.max(4, Math.min(64, bs.vis.barCount));
            if (bs.visBars !== undefined) return Math.max(4, Math.min(64, bs.visBars));
        }
        return 16;
    }

    property string visAlignment: {
        if (widget && widget !== root && widget.visAlignment !== undefined) return widget.visAlignment;
        if (module && module.visAlignment !== undefined) return module.visAlignment;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.visAlignment) return bs.visAlignment;
            if (bs.vis && bs.vis.alignment) return bs.vis.alignment;
        }
        return "center";
    }

    property bool visContinuous: {
        if (widget && widget !== root && widget.visContinuous !== undefined) return widget.visContinuous;
        if (module && module.visContinuous !== undefined) return module.visContinuous;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.visContinuous !== undefined) return Boolean(bs.visContinuous);
            if (bs.vis && bs.vis.continuous !== undefined) return Boolean(bs.vis.continuous);
            if (bs.visStyle !== undefined) return bs.visStyle === "continuous";
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

    property int sampleCount: Math.max(16, Math.min(128, root.barCount * 2))

    readonly property real barW: barWindow ? barWindow.s(root.isCompact ? 4 : 5) : (root.isCompact ? 4 : 5)
    readonly property real barSp: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)
    readonly property real contentWidth: root.barCount * barW + Math.max(0, root.barCount - 1) * barSp
    readonly property real paddingH: barWindow ? barWindow.s(root.isCompact ? 20 : 24) : (root.isCompact ? 20 : 24)

    property real targetWidth: ((activeTarget ? activeTarget.moduleActive : true) && contentWidth > 0) ? (contentWidth + paddingH) : 0

    implicitWidth: targetWidth
    implicitHeight: (barWindow && typeof barWindow.s === "function") ? barWindow.s(root.isCompact ? 24 : 32) : (root.isCompact ? 24 : 32)

    Timer {
        running: (activeTarget ? activeTarget.moduleActive : true) && barWindow && !root.showLayout
        interval: 100
        onTriggered: {
            if (barWindow && barWindow.isStartupReady) {
                root.showLayout = true;
            }
        }
    }

    Visualizer {
        width: root.contentWidth
        height: Math.max(14, root.height - (root.barWindow ? root.barWindow.s(8) : 8))
        anchors.centerIn: parent
        active: root.isSubscribed
        continuous: root.visContinuous
        alignment: (root.visAlignment === "top" || root.visAlignment === "left")
            ? "start"
            : ((root.visAlignment === "bottom" || root.visAlignment === "right") ? "end" : "center")
        count: root.visContinuous ? root.sampleCount : root.barCount
        color: root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve
        previewDemo: Boolean(root.activeTarget && root.activeTarget.isPreview)

        // Bars: low frequencies first. Wave: low frequencies in the middle, mirrored
        mirrored: root.visContinuous
        curve: root.visContinuous ? 1.25 : 1.4
        interpolate: root.visContinuous
        threshold: root.visContinuous ? 0.03 : 0.04
        gamma: root.visContinuous ? 1.15 : 1.25
        rise: root.visContinuous ? 0.25 : 0.5
        fall: root.visContinuous ? 0.12 : 0.5

        maxLength: root.visContinuous ? height - 2 : height
        spacing: root.barSp
        minLength: root.barWindow ? root.barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)
        opacityBase: 0.45
        opacityRange: 0.55
        opacity: root.visContinuous ? 0.55 + Math.min(0.45, energy * 0.75) : 1.0
    }
}
