import QtQuick
import QtQuick.Shapes
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 120
    property real maxWidth: 900
    property real maxHeight: 1200
    property real minAspect: 0.3
    property real maxAspect: 2.5
    property bool isRound: false

    readonly property real areaTop: height * 0.03
    readonly property real areaWidth: width * 0.94
    readonly property real areaHeight: Math.max(1, height - areaTop - height * 0.03)
    readonly property real gapRatio: 0.12
    readonly property real colonRatio: 0.4
    readonly property real cw: Math.max(1, Math.min(areaHeight * 0.32, areaWidth / (4 + colonRatio + 4 * gapRatio)))
    readonly property real gap: cw * gapRatio
    readonly property real colonW: cw * colonRatio
    readonly property real contentWidth: cw * (4 + colonRatio) + gap * 4
    readonly property real stroke: cw * 0.24
    readonly property var chars: (DateTime.hour + ":" + DateTime.minute).split("")
    readonly property real fillOpacity: 0.78

    function roundRect(x0, y0, x1, y1, r) {
        return "M" + (x0 + r) + " " + y0
            + " H" + (x1 - r) + " A" + r + " " + r + " 0 0 1 " + x1 + " " + (y0 + r)
            + " V" + (y1 - r) + " A" + r + " " + r + " 0 0 1 " + (x1 - r) + " " + y1
            + " H" + (x0 + r) + " A" + r + " " + r + " 0 0 1 " + x0 + " " + (y1 - r)
            + " V" + (y0 + r) + " A" + r + " " + r + " 0 0 1 " + (x0 + r) + " " + y0 + " Z";
    }

    function glyphPath(ch, w, h, s) {
        let x0 = s / 2, x1 = w - s / 2, y0 = s / 2, y1 = h - s / 2;
        let ym = h / 2, r = (x1 - x0) / 2;
        switch (ch) {
        case "0":
            return roundRect(x0, y0, x1, y1, r);
        case "1":
            return "M" + x0 + " " + (y0 + r) + " L" + x1 + " " + y0 + " V" + h;
        case "2": {
            let d = (y1 - y0 - r) * 0.45;
            return "M" + x0 + " " + (y0 + r) + " A" + r + " " + r + " 0 0 1 " + x1 + " " + (y0 + r)
                + " C" + x1 + " " + (y0 + r + d) + " " + x0 + " " + (y1 - d) + " " + x0 + " " + y1
                + " H" + x1;
        }
        case "3":
            return "M" + x0 + " " + (y0 + r) + " A" + r + " " + r + " 0 0 1 " + x1 + " " + (y0 + r)
                + " V" + (ym - r) + " A" + r + " " + r + " 0 0 1 " + (x1 - r) + " " + ym
                + " H" + (x0 + r * 0.3)
                + " M" + (x1 - r) + " " + ym + " A" + r + " " + r + " 0 0 1 " + x1 + " " + (ym + r)
                + " V" + (y1 - r) + " A" + r + " " + r + " 0 0 1 " + x0 + " " + (y1 - r);
        case "4": {
            let xs = x0 + (x1 - x0) * 0.68, yb = y0 + (y1 - y0) * 0.7;
            return "M" + xs + " " + h + " V0 M" + xs + " " + s * 0.2 + " L" + x0 + " " + yb
                + " M0 " + yb + " H" + w;
        }
        case "5": {
            let yq = ym + 0.04 * h;
            return "M" + x1 + " " + y0 + " H" + x0 + " V" + yq + " H" + (x1 - r)
                + " A" + r + " " + r + " 0 0 1 " + x1 + " " + (yq + r)
                + " V" + (y1 - r) + " A" + r + " " + r + " 0 0 1 " + (x1 - r) + " " + y1 + " H" + x0;
        }
        case "6":
        case "9": {
            let yq = ym + 0.04 * h;
            return "M" + x1 + " " + y0 + " H" + (x0 + r)
                + " A" + r + " " + r + " 0 0 0 " + x0 + " " + (y0 + r)
                + " V" + (y1 - r) + " A" + r + " " + r + " 0 0 0 " + (x0 + r) + " " + y1
                + " H" + (x1 - r) + " A" + r + " " + r + " 0 0 0 " + x1 + " " + (y1 - r)
                + " V" + (yq + r) + " A" + r + " " + r + " 0 0 0 " + (x1 - r) + " " + yq
                + " H" + x0;
        }
        case "7":
            return "M0 " + y0 + " H" + x1 + " L" + (x0 + (x1 - x0) * 0.3) + " " + y1 + " V" + h;
        case "8":
            return roundRect(x0, y0, x1, ym, r) + " " + roundRect(x0, ym, x1, y1, r);
        }
        return "";
    }

    component Glyphs: Row {
        id: glyphs
        property real strokeW: root.stroke
        property color col: "white"
        spacing: root.gap

        Repeater {
            model: root.chars

            Item {
                id: cell
                required property string modelData
                readonly property bool isColon: modelData === ":"
                width: isColon ? root.colonW : root.cw
                height: root.areaHeight

                Shape {
                    anchors.fill: parent
                    visible: !cell.isColon
                    rotation: cell.modelData === "9" ? 180 : 0
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: glyphs.strokeW
                        strokeColor: glyphs.col
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg {
                            path: root.glyphPath(cell.modelData, cell.width, cell.height, root.stroke)
                        }
                    }
                }

                Repeater {
                    model: cell.isColon ? 2 : 0

                    Rectangle {
                        required property int index
                        width: Math.max(1, root.stroke * 1.1 - (root.stroke - glyphs.strokeW))
                        height: width
                        radius: width / 2
                        color: glyphs.col
                        x: (cell.width - width) / 2
                        y: cell.height * (index === 0 ? 0.35 : 0.65) - height / 2
                    }
                }
            }
        }
    }

    Item {
        id: digits
        x: (root.width - root.contentWidth) / 2
        y: root.areaTop
        width: root.contentWidth
        height: root.areaHeight

        Glyphs {
            col: ThemeBackend.text
            opacity: root.fillOpacity
            layer.enabled: true
            layer.smooth: true
        }
    }
}
