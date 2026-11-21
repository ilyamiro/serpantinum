import QtQuick
import "../../"
import "../"

Item {
    id: root

    property var history: []
    property var statsSource: history
    property var formatValue: function(v) { return Math.round(v) + "%"; }
    property int visibleSamples: 60
    property int sampleInterval: 2000
    property color colorBase: ThemeBackend.surface0
    property color lineColor: ThemeBackend.mauve
    property string title: ""
    property string valueText: ""
    property bool isLive: true
    property bool blurred: false
    property real bgOpacity: 1.0
    property bool compact: false

    property var scaleFunc: null
    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : (typeof Scaler !== "undefined" ? Scaler.s(val) : val);
    }

    property real cardRadius: compact ? s(Math.max(0, ThemeBackend.clampedBorderRadius - 2)) : s(ThemeBackend.clampedBorderRadius)
    property real contentMargins: compact ? s(10) : s(12)
    property real titleFontSize: compact ? s(10.5) : s(13)
    property real valueFontSize: compact ? s(18) : s(24)
    property real chipFontSize: compact ? s(10) : s(11)
    property real lineWidth: s(2.5)
    property string fontFamily: ThemeBackend.fontFamily

    readonly property bool showChips: root.height >= s(115)
    readonly property var windowValues: (root.statsSource || []).slice(-root.visibleSamples)
    readonly property real average: windowValues.length > 0 ? windowValues.reduce((a, b) => a + b, 0) / windowValues.length : 0
    readonly property real peak: windowValues.length > 0 ? windowValues.reduce((a, b) => Math.max(a, b), windowValues[0]) : 0

    property real shift: 0

    component UsageChip: Rectangle {
        property string label: ""
        property real fontSize: 11
        property real padding: 8
        property string family: ""
        width: chipText.implicitWidth + padding * 2
        height: chipText.implicitHeight + padding
        color: Qt.alpha(ThemeBackend.surface1, 0.6)

        Text {
            id: chipText
            anchors.centerIn: parent
            font.family: parent.family
            font.weight: Font.DemiBold
            font.pixelSize: parent.fontSize
            color: ThemeBackend.subtext0
            text: parent.label
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: root
        property: "shift"
        from: 1
        to: 0
        duration: Math.min(700, root.sampleInterval * 0.8)
        easing.type: Easing.OutCubic
    }

    function packLevels(v, o) {
        let m = [];
        for (let k = 0; k < 16; k++) m.push(v[o + k] || 0.0);
        return Qt.matrix4x4(m);
    }

    function uploadHistory() {
        let v = (root.history || []).slice(-64);
        for (let m = 0; m < 4; m++) graph["levels" + m] = packLevels(v, m * 16);
        graph.count = v.length;
    }

    onHistoryChanged: {
        uploadHistory();
        if (root.visible && root.isLive && graph.count > 1) {
            scrollAnimation.restart();
        } else {
            scrollAnimation.stop();
            root.shift = 0;
        }
    }

    Component.onCompleted: uploadHistory()

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: cardGlass.active ? "transparent" : Qt.alpha(root.colorBase, root.bgOpacity)

        GlassFill {
            id: cardGlass
            anchors.fill: parent
            allowed: !root.blurred
            radius: root.cardRadius
            tintColor: root.colorBase
            tintAmount: 0.3 * root.bgOpacity
        }

        Loader {
            z: -1
            anchors.fill: parent
            active: root.blurred
            sourceComponent: WallpaperBlur {
                radius: root.cardRadius
                standalone: true
            }
        }
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.contentMargins
        spacing: root.s(2)

        Text {
            width: parent.width
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: root.titleFontSize
            color: ThemeBackend.subtext0
            text: root.title
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.weight: Font.Black
            font.pixelSize: root.valueFontSize
            color: ThemeBackend.text
            text: root.valueText
        }
    }

    Row {
        id: chips
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: root.contentMargins
        spacing: root.s(6)
        visible: root.showChips

        UsageChip {
            label: I18n.t("widgets.usageGraph.average", "Avg") + " " + root.formatValue(root.average)
            fontSize: root.chipFontSize
            padding: root.s(8)
            family: root.fontFamily
            radius: Math.min(height / 2, root.s(ThemeBackend.borderRadius))
        }

        UsageChip {
            label: I18n.t("widgets.usageGraph.peak", "Peak") + " " + root.formatValue(root.peak)
            fontSize: root.chipFontSize
            padding: root.s(8)
            family: root.fontFamily
            radius: Math.min(height / 2, root.s(ThemeBackend.borderRadius))
        }
    }

    ShaderEffect {
        id: graph
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: root.showChips ? chips.top : parent.bottom
        anchors.topMargin: root.s(6)
        anchors.bottomMargin: root.showChips ? root.s(6) : root.contentMargins
        visible: count > 0 && height > root.lineWidth

        property matrix4x4 levels0
        property matrix4x4 levels1
        property matrix4x4 levels2
        property matrix4x4 levels3
        property color color: root.lineColor
        property vector2d itemSize: Qt.vector2d(width, height)
        property real count: 0
        property real capacity: root.visibleSamples
        property real shift: root.shift
        property real strokeWidth: root.lineWidth
        property real padX: root.contentMargins

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/gauges/history_graph.frag.qsb"
    }
}
