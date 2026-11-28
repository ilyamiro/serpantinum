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

    SubscriptionGate {
        target: SysData
        wanted: root.visible
    }

    readonly property real rawValue: {
        if (root.metric === "ram") return isNaN(SysData.ramPercent) ? 0.0 : SysData.ramPercent / 100.0;
        if (root.metric === "temp") return isNaN(SysData.temp) ? 0.0 : Math.max(0.0, Math.min(1.0, SysData.temp / 100.0));
        if (root.metric === "disk") return isNaN(SysData.diskPercent) ? 0.0 : SysData.diskPercent / 100.0;
        return isNaN(SysData.cpu) ? 0.0 : SysData.cpu / 100.0;
    }

    property real animValue: rawValue
    Behavior on animValue { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    readonly property real rawAux: {
        if (root.metric === "ram") return isNaN(SysData.ramGb) ? 0.0 : SysData.ramGb;
        if (root.metric === "temp") return isNaN(SysData.temp) ? 0.0 : SysData.temp;
        return 0.0;
    }

    property real animAux: rawAux
    Behavior on animAux { enabled: root.visible; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    readonly property color metricColor: {
        if (root.metric === "ram") return Qt.lighter(ThemeBackend.mauve, 1.15);
        if (root.metric === "temp") return ThemeBackend.mauve;
        if (root.metric === "disk") return Qt.darker(ThemeBackend.mauve, 1.15);
        return Qt.lighter(ThemeBackend.mauve, 1.35);
    }

    readonly property string metricIcon: {
        if (root.metric === "ram") return String.fromCodePoint(0xF035C);
        if (root.metric === "temp") return String.fromCodePoint(0xF050F);
        if (root.metric === "disk") return String.fromCodePoint(0xF02CA);
        return String.fromCodePoint(0xF035B);
    }

    readonly property string metricTitle: {
        if (root.metric === "ram") return I18n.t("quickactions.systemusage.ram");
        if (root.metric === "temp") return I18n.t("quickactions.systemusage.temp");
        if (root.metric === "disk") return SysData.diskTotalGb > 0 ? (SysData.diskTotalGb.toFixed(1) + "G") : "";
        return I18n.t("quickactions.systemusage.cpu");
    }

    readonly property string metricSubText: root.metric === "disk" ? (SysData.diskGb > 0 ? (SysData.diskGb.toFixed(1) + "G") : "...") : ""

    readonly property string metricValueText: {
        if (root.metric === "ram") return root.animAux.toFixed(1) + "G";
        if (root.metric === "temp") return Math.round(root.animAux) + "°";
        return Math.round(root.animValue * 100) + "%";
    }

    SystemUsageCard {
        anchors.fill: parent
        blurred: true
        bgOpacity: ThemeBackend.elementOpacity
        value: root.animValue
        colorBase: ThemeBackend.surface0
        colorFill: root.metricColor
        icon: root.metricIcon
        title: root.metricTitle
        subText: root.metricSubText
        valueText: root.metricValueText
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: Scaler.s
    }
}
