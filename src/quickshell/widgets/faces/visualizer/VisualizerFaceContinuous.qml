import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
        id: spectrumGate
        target: Spectrum
        acquire: "registerConsumer"
        release: "unregisterConsumer"
        wanted: root.isVisVisible
    }

    Visualizer {
        anchors.fill: parent
        active: spectrumGate.active
        continuous: true
        count: 64
        rise: 0.25
        fall: 0.12
        maxLength: height * 0.92
    }
}
