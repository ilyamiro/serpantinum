import QtQuick
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property bool previewMode: false
    property string type: ""
    property string metric: type !== "" ? type : "cpu"

    property real minWidth: 100
    property real minHeight: 70
    property real maxWidth: 600
    property real maxHeight: 400
    property real minAspect: 0.6
    property real maxAspect: 3.0
    property bool isRound: false

    property bool compactMode: root.height < Scaler.s(100) || root.width < Scaler.s(140)

    property real updatesPerMinute: 30
    readonly property int sampleInterval: Math.max(1, Math.min(10, Math.round(60 / Math.max(1, root.updatesPerMinute))))
    readonly property var track: historyGate.active ? SysData.historyFor(root.sampleInterval) : null

    SubscriptionGate {
        id: historyGate
        target: SysData
        acquire: "acquireHistory"
        release: "releaseHistory"
        acquireArg: root.sampleInterval
        wanted: root.visible
    }

    function lastOf(list) {
        return list && list.length > 0 ? list[list.length - 1] : 0;
    }

    readonly property var samples: {
        if (!root.track) return [];
        if (root.metric === "ram") return root.track.ramPercent || [];
        if (root.metric === "temp") return root.track.temp || [];
        return root.track.cpu || [];
    }

    readonly property var statsSamples: {
        if (!root.track) return [];
        if (root.metric === "ram") return root.track.ramGb || [];
        return root.samples;
    }

    readonly property real rawDisplay: root.lastOf(root.statsSamples)
    property real animDisplay: rawDisplay
    Behavior on animDisplay { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    readonly property color metricColor: {
        if (root.metric === "ram") return Qt.lighter(ThemeBackend.mauve, 1.15);
        if (root.metric === "temp") return ThemeBackend.mauve;
        return Qt.lighter(ThemeBackend.mauve, 1.35);
    }

    readonly property string metricTitle: {
        if (root.metric === "ram") return I18n.t("quickactions.systemusage.ram");
        if (root.metric === "temp") return I18n.t("quickactions.systemusage.temp");
        return I18n.t("quickactions.systemusage.cpu");
    }

    readonly property string metricValueText: {
        if (root.metric === "ram") return root.animDisplay.toFixed(1) + "G";
        if (root.metric === "temp") return Math.round(root.animDisplay) + "°";
        return Math.round(root.animDisplay) + "%";
    }

    SystemUsageGraph {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        history: root.samples.map(v => v / 100)
        statsSource: root.statsSamples
        formatValue: root.metric === "ram"
            ? (v => v.toFixed(1) + "G")
            : (root.metric === "temp" ? (v => Math.round(v) + "°") : (v => Math.round(v) + "%"))
        lineColor: root.metricColor
        title: root.metricTitle
        valueText: root.metricValueText
        sampleInterval: root.sampleInterval * 1000
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
