import QtQuick
import "../../"

Item {
    id: root

    property string hours: ""
    property string minutes: ""
    property real pixelSize: 40
    property real fitWidth: 0
    property real fitHeight: 0
    property color colorA: ThemeBackend.onSurface ?? ThemeBackend.text
    property color colorB: ThemeBackend.primary ?? ThemeBackend.mauve

    readonly property string fontName: fontLoader.status === FontLoader.Ready && fontLoader.name !== ""
        ? fontLoader.name
        : (ThemeBackend.fontFamily !== "" ? ThemeBackend.fontFamily : "sans-serif")

    readonly property var inkRects: {
        var f = ref.font;
        var rects = [];
        for (var i = 0; i < 10; i++) rects.push(ref.tightBoundingRect(String(i)));
        return rects;
    }
    readonly property real refCellW: {
        var m = 1;
        for (var i = 0; i < inkRects.length; i++) m = Math.max(m, inkRects[i].width);
        return m;
    }
    readonly property real refCellH: {
        var m = 1;
        for (var i = 0; i < inkRects.length; i++) m = Math.max(m, inkRects[i].height);
        return m;
    }
    readonly property real effectivePixelSize: (fitWidth > 0 && fitHeight > 0)
        ? Math.min(fitWidth / (2 * refCellW), fitHeight / (2 * refCellH)) * 100
        : pixelSize
    readonly property real scaleFactor: effectivePixelSize / 100
    readonly property real cellW: refCellW * scaleFactor
    readonly property real cellH: refCellH * scaleFactor

    implicitWidth: cellW * 2
    implicitHeight: cellH * 2
    width: implicitWidth
    height: implicitHeight

    FontLoader {
        id: fontLoader
        source: (typeof Caching !== "undefined" && Caching.serpantinumDir && Caching.serpantinumDir !== "")
            ? ("file://" + Caching.serpantinumDir + "/assets/fonts/GoogleSansFlex.ttf")
            : Qt.resolvedUrl("../../../assets/fonts/GoogleSansFlex.ttf")
    }

    FontMetrics {
        id: ref
        font.family: root.fontName
        font.pixelSize: 100
        font.weight: Font.Black
        font.variableAxes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
    }

    readonly property string h: hours.padStart(2, "0")
    readonly property string m: minutes === "" ? "" : minutes.padStart(2, "0")

    Repeater {
        model: 4

        delegate: Item {
            id: cell

            readonly property int col: index % 2
            readonly property int row: Math.floor(index / 2)
            readonly property string digit: (row === 0 ? root.h : root.m).charAt(col)
            readonly property var ink: root.inkRects[digit >= "0" && digit <= "9" ? Number(digit) : 0]
            readonly property real textX: (root.cellW - ink.width * root.scaleFactor) / 2 - ink.x * root.scaleFactor
            readonly property color tint: (row + col) % 2 === 0 ? root.colorA : root.colorB

            x: col * root.cellW
            y: row * root.cellH
            width: root.cellW
            height: root.cellH
            visible: digit !== ""

            Repeater {
                model: [
                    { dy: 0.045, alpha: 0.14 },
                    { dy: 0.022, alpha: 0.26 }
                ]
                delegate: Text {
                    x: cell.textX
                    y: cell.height - baselineOffset + root.effectivePixelSize * modelData.dy
                    text: cell.digit
                    font.family: root.fontName
                    font.pixelSize: root.effectivePixelSize
                    font.weight: Font.Black
                    font.variableAxes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
                    renderType: Text.NativeRendering
                    color: Qt.rgba(0, 0, 0, modelData.alpha)
                }
            }

            Text {
                x: cell.textX
                y: cell.height - baselineOffset
                text: cell.digit
                font.family: root.fontName
                font.pixelSize: root.effectivePixelSize
                font.weight: Font.Black
                font.variableAxes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
                renderType: Text.NativeRendering
                color: cell.tint
            }
        }
    }
}
