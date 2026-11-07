import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 50
    property real minHeight: 50
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    property bool isVisVisible: visible

    SubscriptionGate {
        id: cavaGate
        target: Cava
        acquire: "registerConsumer"
        release: "unregisterConsumer"
        wanted: root.isVisVisible
    }

    property real barSpacing: Scaler.s(4)
    property real minBarWidth: Scaler.s(6)
    property int activeBars: Math.max(4, Math.min(128, Math.floor((width + barSpacing) / (minBarWidth + barSpacing))))

    Visualizer {
        anchors.fill: parent
        active: cavaGate.active
        count: root.activeBars
        spacing: root.barSpacing
        maxLength: height * 0.96
        minLength: Scaler.s(3)
        radiusRatio: 0.35
        opacityBase: 0.3
        opacityRange: 0.7
        edgeFade: true
    }
}
