import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../reusables"
import "../"

Item {
    id: picker

    property bool active: false
    property string freezeImg: ""
    property int imageWidth: 0
    property int imageHeight: 0
    property real initialX: width / 2
    property real initialY: height / 2
    property bool animateChanges: true
    property int formatIndex: 0

    signal exited()
    signal formatChanged(int index)
    signal colorPicked(string formatted, string hex, string rgb, string hsl, int r, int g, int b, bool keepOpen)

    function s(val) { return Scaler.s(val); }

    readonly property int gridSize: 11
    readonly property int halfGrid: 5
    readonly property var formats: ["HEX", "RGB", "HSL"]

    property real cursorX: initialX
    property real cursorY: initialY
    property int pixelX: 0
    property int pixelY: 0
    property bool hasSample: false
    property bool pointerActive: false

    property int sampleR: 0
    property int sampleG: 0
    property int sampleB: 0
    property color sampledColor: Qt.rgba(sampleR / 255, sampleG / 255, sampleB / 255, 1.0)
    property real sampledLuma: (0.2126 * sampleR + 0.7152 * sampleG + 0.0722 * sampleB) / 255.0
    property var gridData: null

    property string hexText: formatHex(sampleR, sampleG, sampleB)
    property string rgbText: formatRgb(sampleR, sampleG, sampleB)
    property string hslText: formatHsl(sampleR, sampleG, sampleB)
    property string formattedColor: formatValue(formatIndex, sampleR, sampleG, sampleB)
    property string secondaryColor: formatIndex === 0 ? rgbText : hexText

    property bool copiedFlash: false
    property string copiedBadgeText: ""

    opacity: active ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity {
        enabled: picker.animateChanges
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    function toHexByte(v) {
        let clamped = Math.max(0, Math.min(255, Math.round(v)));
        let h = clamped.toString(16).toUpperCase();
        return h.length < 2 ? ("0" + h) : h;
    }

    function formatHex(r, g, b) {
        return "#" + toHexByte(r) + toHexByte(g) + toHexByte(b);
    }

    function formatRgb(r, g, b) {
        return "rgb(" + r + ", " + g + ", " + b + ")";
    }

    function formatHsl(r, g, b) {
        let rn = r / 255.0;
        let gn = g / 255.0;
        let bn = b / 255.0;
        let max = Math.max(rn, gn, bn);
        let min = Math.min(rn, gn, bn);
        let l = (max + min) / 2.0;
        let h = 0;
        let sat = 0;
        if (max !== min) {
            let d = max - min;
            sat = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
            if (max === rn) {
                h = ((gn - bn) / d) + (gn < bn ? 6 : 0);
            } else if (max === gn) {
                h = ((bn - rn) / d) + 2;
            } else {
                h = ((rn - gn) / d) + 4;
            }
            h *= 60;
        }
        return "hsl(" + Math.round(h) + ", " + Math.round(sat * 100) + "%, " + Math.round(l * 100) + "%)";
    }

    function formatValue(idx, r, g, b) {
        if (idx === 1) return formatRgb(r, g, b);
        if (idx === 2) return formatHsl(r, g, b);
        return formatHex(r, g, b);
    }

    function logicalToPixel(lx, ly) {
        let iw = picker.imageWidth > 0 ? picker.imageWidth : picker.width;
        let ih = picker.imageHeight > 0 ? picker.imageHeight : picker.height;
        let vw = Math.max(1, picker.width);
        let vh = Math.max(1, picker.height);
        let scale = Math.max(vw / Math.max(1, iw), vh / Math.max(1, ih));
        let drawnW = iw * scale;
        let drawnH = ih * scale;
        let offX = (drawnW - vw) / 2.0;
        let offY = (drawnH - vh) / 2.0;
        let px = Math.floor((lx + offX) / scale);
        let py = Math.floor((ly + offY) / scale);
        return {
            x: Math.max(0, Math.min(iw - 1, px)),
            y: Math.max(0, Math.min(ih - 1, py))
        };
    }

    function sampleAtLogical(lx, ly) {
        picker.cursorX = Math.max(0, Math.min(picker.width, lx));
        picker.cursorY = Math.max(0, Math.min(picker.height, ly));
        let pt = logicalToPixel(picker.cursorX, picker.cursorY);
        picker.pixelX = pt.x;
        picker.pixelY = pt.y;
        samplerCanvas.requestPaint();
    }

    function cycleFormat(delta) {
        let count = picker.formats.length;
        let next = (picker.formatIndex + delta + count) % count;
        if (next !== picker.formatIndex) {
            picker.formatIndex = next;
            picker.formatChanged(next);
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx("reusables/switch/sfx.wav");
            }
        }
    }

    function pickCurrent(keepOpen) {
        if (!picker.active || !picker.hasSample) return;
        let val = picker.formattedColor;
        let hex = picker.hexText;
        let rgb = picker.rgbText;
        let hsl = picker.hslText;
        let r = picker.sampleR;
        let g = picker.sampleG;
        let b = picker.sampleB;
        if (typeof Sounds !== "undefined") {
            Sounds.playSfx("reusables/iconbutton/click.wav");
        }
        if (keepOpen) {
            triggerCopiedFlash(val);
        }
        picker.colorPicked(val, hex, rgb, hsl, r, g, b, keepOpen);
    }

    function triggerCopiedFlash(label) {
        picker.copiedBadgeText = label;
        picker.copiedFlash = true;
        copiedFlashTimer.restart();
    }

    function reset() {
        copiedFlashTimer.stop();
        picker.copiedFlash = false;
        picker.hasSample = false;
        picker.pointerActive = false;
        picker.gridData = null;
        samplerCanvas.unloadCurrent();
    }

    onActiveChanged: {
        if (picker.active) {
            picker.copiedFlash = false;
            picker.cursorX = Math.max(0, Math.min(picker.width, picker.initialX));
            picker.cursorY = Math.max(0, Math.min(picker.height, picker.initialY));
            let pt = logicalToPixel(picker.cursorX, picker.cursorY);
            picker.pixelX = pt.x;
            picker.pixelY = pt.y;
            picker.pointerActive = true;
            samplerCanvas.ensureLoaded();
        } else {
            copiedFlashTimer.stop();
            picker.copiedFlash = false;
            samplerCanvas.unloadCurrent();
        }
    }

    onFreezeImgChanged: {
        if (picker.active) {
            samplerCanvas.ensureLoaded();
        } else {
            samplerCanvas.unloadCurrent();
        }
    }

    onImageWidthChanged: {
        if (picker.active && picker.imageWidth > 0 && picker.imageHeight > 0) {
            picker.sampleAtLogical(picker.cursorX, picker.cursorY);
        }
    }

    onImageHeightChanged: {
        if (picker.active && picker.imageWidth > 0 && picker.imageHeight > 0) {
            picker.sampleAtLogical(picker.cursorX, picker.cursorY);
        }
    }

    Timer {
        id: copiedFlashTimer
        interval: 1100
        repeat: false
        onTriggered: picker.copiedFlash = false
    }

    Canvas {
        id: samplerCanvas
        x: -200
        y: -200
        width: picker.gridSize
        height: picker.gridSize
        opacity: 0.001
        visible: picker.active
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        property string loadedUrl: ""

        function unloadCurrent() {
            if (loadedUrl !== "") {
                unloadImage(loadedUrl);
                loadedUrl = "";
            }
        }

        function ensureLoaded() {
            let nextUrl = picker.freezeImg !== "" ? ("file://" + picker.freezeImg) : "";
            if (nextUrl === loadedUrl) {
                if (loadedUrl !== "" && isImageLoaded(loadedUrl)) {
                    requestPaint();
                }
                return;
            }
            unloadCurrent();
            if (nextUrl !== "") {
                loadedUrl = nextUrl;
                loadImage(nextUrl);
            }
        }

        onImageLoaded: {
            if (picker.active && loadedUrl !== "" && isImageLoaded(loadedUrl)) {
                requestPaint();
            }
        }

        onPaint: {
            if (!picker.active || loadedUrl === "" || !isImageLoaded(loadedUrl)) return;
            let iw = picker.imageWidth > 0 ? picker.imageWidth : picker.width;
            let ih = picker.imageHeight > 0 ? picker.imageHeight : picker.height;
            if (iw <= 0 || ih <= 0) return;

            let ctx = getContext("2d");
            let gs = picker.gridSize;
            let half = picker.halfGrid;
            let sx = picker.pixelX - half;
            let sy = picker.pixelY - half;

            ctx.fillStyle = "#000000";
            ctx.fillRect(0, 0, gs, gs);

            let clipLeft = Math.max(0, sx);
            let clipTop = Math.max(0, sy);
            let clipRight = Math.min(iw, sx + gs);
            let clipBottom = Math.min(ih, sy + gs);
            let sw = clipRight - clipLeft;
            let sh = clipBottom - clipTop;

            if (sw > 0 && sh > 0) {
                ctx.drawImage(loadedUrl, clipLeft, clipTop, sw, sh, clipLeft - sx, clipTop - sy, sw, sh);
            }

            let imgData = ctx.getImageData(0, 0, gs, gs).data;
            let centerOffset = (half * gs + half) * 4;
            picker.sampleR = imgData[centerOffset];
            picker.sampleG = imgData[centerOffset + 1];
            picker.sampleB = imgData[centerOffset + 2];
            picker.gridData = imgData;
            picker.hasSample = true;
            loupeCanvas.requestPaint();
        }
    }

    MouseArea {
        id: pickerArea
        anchors.fill: parent
        enabled: picker.active
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.BlankCursor
        z: 10

        onEntered: {
            if (!picker.active) return;
            picker.pointerActive = true;
            picker.sampleAtLogical(mouseX, mouseY);
        }

        onPositionChanged: (mouse) => {
            if (!picker.active) return;
            picker.pointerActive = true;
            picker.sampleAtLogical(mouse.x, mouse.y);
        }

        onWheel: (wheel) => {
            if (!picker.active) return;
            if (wheel.angleDelta.y > 0) {
                picker.cycleFormat(-1);
            } else if (wheel.angleDelta.y < 0) {
                picker.cycleFormat(1);
            }
            wheel.accepted = true;
        }

        onClicked: (mouse) => {
            if (!picker.active) return;
            if (mouse.button === Qt.RightButton) {
                picker.exited();
                return;
            }
            picker.sampleAtLogical(mouse.x, mouse.y);
            let keepOpen = (mouse.button === Qt.MiddleButton) || ((mouse.modifiers & Qt.ShiftModifier) !== 0);
            picker.pickCurrent(keepOpen);
        }
    }

    Item {
        id: loupeContainer
        z: 25
        readonly property real loupeSize: s(134)
        readonly property real ringThickness: s(4)
        readonly property real innerSize: loupeSize - ringThickness * 2

        visible: picker.active && picker.pointerActive && picker.hasSample
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.84

        Behavior on opacity {
            enabled: picker.animateChanges
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: picker.animateChanges
            NumberAnimation { duration: 220; easing.type: Easing.OutBack }
        }

        x: picker.cursorX - width / 2
        y: picker.cursorY - height / 2
        width: loupeSize
        height: loupeSize

        MultiEffect {
            source: loupeFrame
            anchors.fill: loupeFrame
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.52
            shadowBlur: 0.85
            shadowVerticalOffset: s(6)
        }

        Rectangle {
            id: loupeFrame
            anchors.fill: parent
            radius: width / 2
            color: picker.sampledColor
            border.width: s(1.5)
            border.color: picker.sampledLuma > 0.62 ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.35)

            Canvas {
                id: loupeCanvas
                anchors.centerIn: parent
                width: loupeContainer.innerSize
                height: loupeContainer.innerSize
                renderTarget: Canvas.Image
                renderStrategy: Canvas.Immediate

                onPaint: {
                    let ctx = getContext("2d");
                    let w = width;
                    let h = height;
                    let r = w / 2;
                    let gs = picker.gridSize;
                    let half = picker.halfGrid;
                    let data = picker.gridData;

                    ctx.clearRect(0, 0, w, h);
                    ctx.save();
                    ctx.beginPath();
                    ctx.arc(r, r, r, 0, Math.PI * 2);
                    ctx.clip();

                    if (data && data.length >= gs * gs * 4) {
                        let cell = w / gs;
                        for (let row = 0; row < gs; row++) {
                            let y0 = Math.floor(row * cell);
                            let y1 = Math.ceil((row + 1) * cell);
                            for (let col = 0; col < gs; col++) {
                                let x0 = Math.floor(col * cell);
                                let x1 = Math.ceil((col + 1) * cell);
                                let idx = (row * gs + col) * 4;
                                ctx.fillStyle = "rgb(" + data[idx] + "," + data[idx + 1] + "," + data[idx + 2] + ")";
                                ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
                            }
                        }

                        ctx.lineWidth = 1;
                        ctx.strokeStyle = picker.sampledLuma > 0.55 ? "rgba(0, 0, 0, 0.14)" : "rgba(255, 255, 255, 0.12)";
                        for (let i = 1; i < gs; i++) {
                            let pos = Math.round(i * cell) + 0.5;
                            ctx.beginPath();
                            ctx.moveTo(pos, 0);
                            ctx.lineTo(pos, h);
                            ctx.stroke();

                            ctx.beginPath();
                            ctx.moveTo(0, pos);
                            ctx.lineTo(w, pos);
                            ctx.stroke();
                        }

                        let cx = Math.floor(half * cell);
                        let cy = Math.floor(half * cell);
                        let cw = Math.ceil((half + 1) * cell) - cx;
                        let ch = Math.ceil((half + 1) * cell) - cy;

                        ctx.lineWidth = Math.max(1.5, s(1.5));
                        ctx.strokeStyle = "rgba(0, 0, 0, 0.85)";
                        ctx.strokeRect(cx - 0.5, cy - 0.5, cw + 1, ch + 1);

                        ctx.lineWidth = Math.max(1.5, s(1.5));
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.96)";
                        ctx.strokeRect(cx + 1, cy + 1, cw - 2, ch - 2);
                    }

                    ctx.restore();

                    ctx.beginPath();
                    ctx.arc(r, r, r - 0.75, 0, Math.PI * 2);
                    ctx.lineWidth = Math.max(1.2, s(1.2));
                    ctx.strokeStyle = picker.sampledLuma > 0.62 ? "rgba(0, 0, 0, 0.25)" : "rgba(255, 255, 255, 0.55)";
                    ctx.stroke();
                }
            }
        }
    }

    Item {
        id: readoutPill
        z: 28

        readonly property real pillGap: s(12)
        readonly property real loupeHalf: loupeContainer.loupeSize / 2
        readonly property bool fitsBelow: (picker.cursorY + loupeHalf + pillGap + height + s(12)) <= picker.height

        width: Math.max(s(186), readoutCol.implicitWidth + s(20))
        height: readoutCol.implicitHeight + s(16)

        x: Math.max(s(12), Math.min(picker.width - width - s(12), picker.cursorX - width / 2))
        y: fitsBelow
            ? (picker.cursorY + loupeHalf + pillGap)
            : Math.max(s(12), picker.cursorY - loupeHalf - pillGap - height)

        visible: loupeContainer.visible
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.92

        Behavior on opacity {
            enabled: picker.animateChanges
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: picker.animateChanges
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        MultiEffect {
            source: readoutBg
            anchors.fill: readoutBg
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.42
            shadowBlur: 0.75
            shadowVerticalOffset: s(4)
        }

        Rectangle {
            id: readoutBg
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.liquidGlass ? Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity) : ThemeBackend.base
            border.width: s(1)
            border.color: picker.copiedFlash ? ThemeBackend.green : Qt.alpha(ThemeBackend.surface2, 0.5)
            Behavior on border.color { ColorAnimation { duration: 160 } }

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                surfaceEnabled: ThemeBackend.liquidGlass
                topLeftRadius: parent.radius
                topRightRadius: parent.radius
                bottomLeftRadius: parent.radius
                bottomRightRadius: parent.radius
            }
        }

        ColumnLayout {
            id: readoutCol
            anchors.fill: parent
            anchors.margins: s(8)
            spacing: s(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                Rectangle {
                    width: s(26)
                    height: s(26)
                    radius: s(7)
                    color: picker.copiedFlash ? ThemeBackend.green : picker.sampledColor
                    border.width: s(1)
                    border.color: picker.sampledLuma > 0.65 ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(1, 1, 1, 0.25)

                    Text {
                        anchors.centerIn: parent
                        visible: picker.copiedFlash
                        text: "󰄬"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: s(14)
                        color: ThemeBackend.crust
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: s(1)

                    Text {
                        text: picker.copiedFlash
                            ? (I18n.t("screenshot.color_picker.copied", "Copied") + " " + picker.copiedBadgeText)
                            : picker.formattedColor
                        color: picker.copiedFlash ? ThemeBackend.green : ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(12.5)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: picker.secondaryColor + "  ·  " + picker.pixelX + ", " + picker.pixelY
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(10)
                    }
                }
            }

            Switch {
                id: formatSwitch
                Layout.fillWidth: true
                implicitWidth: s(168)
                implicitHeight: s(26)
                height: s(26)
                options: picker.formats
                currentIndex: picker.formatIndex
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                cornerRadius: Math.max(s(6), ThemeBackend.borderRadius - s(2))
                fontPixelSize: s(10.5)

                Connections {
                    target: picker
                    function onFormatIndexChanged() {
                        formatSwitch.currentIndex = picker.formatIndex;
                    }
                }
            }
        }
    }
}
