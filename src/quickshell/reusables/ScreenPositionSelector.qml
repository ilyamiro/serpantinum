import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

Item {
    id: root

    property real horizontalPosition: 50
    property real verticalPosition: 90
    property bool gridEnabled: false
    property bool showBar: false
    property real marginV: 0
    property real marginH: 0

    property int configRevision: 0
    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            root.configRevision++;
        }
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }

    property var targetScreen: (typeof OsdController !== "undefined" && OsdController.screen) ? OsdController.screen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    property real screenRealWidth: (targetScreen && targetScreen.width > 0) ? targetScreen.width : 1920
    property real screenRealHeight: (targetScreen && targetScreen.height > 0) ? targetScreen.height : 1080

    property string barPosition: (rawBarSettings && rawBarSettings.position) ? rawBarSettings.position : "top"
    property real barConfigHeight: (rawBarSettings && rawBarSettings.height) ? rawBarSettings.height : 40

    property real screenAspect: {
        let scr = targetScreen;
        if (scr && scr.width > 0 && scr.height > 0) {
            return scr.width / scr.height;
        }
        return 16.0 / 9.0;
    }

    property real dragWidth: 96
    property real dragHeight: 24

    property color baseColor: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.75)
    property color borderColor: ThemeBackend.surface0
    property color guideColor: ThemeBackend.mauve
    property real cornerRadius: ThemeBackend.borderRadius
    property string clickSound: "reusables/clickbutton/click.wav"

    readonly property real insetTop: (root.showBar && root.barPosition === "top") ? barPreviewBox.height : 0
    readonly property real insetBottom: (root.showBar && root.barPosition === "bottom") ? barPreviewBox.height : 0
    readonly property real insetLeft: (root.showBar && root.barPosition === "left") ? barPreviewBox.width : 0
    readonly property real insetRight: (root.showBar && root.barPosition === "right") ? barPreviewBox.width : 0

    readonly property real safeTopPercent: {
        let h = dragBox ? dragBox.availH : 0;
        if (h <= 0) return 5;
        return Math.max(0, Math.min(100, Math.round(((root.insetTop + root.marginV) / h) * 100.0)));
    }
    readonly property real safeBottomPercent: {
        let h = dragBox ? dragBox.availH : 0;
        if (h <= 0) return 95;
        return Math.max(0, Math.min(100, Math.round(((h - root.insetBottom - root.marginV) / h) * 100.0)));
    }
    readonly property real safeLeftPercent: {
        let w = dragBox ? dragBox.availW : 0;
        if (w <= 0) return 5;
        return Math.max(0, Math.min(100, Math.round(((root.insetLeft + root.marginH) / w) * 100.0)));
    }
    readonly property real safeRightPercent: {
        let w = dragBox ? dragBox.availW : 0;
        if (w <= 0) return 95;
        return Math.max(0, Math.min(100, Math.round(((w - root.insetRight - root.marginH) / w) * 100.0)));
    }

    readonly property real usableX: 0
    readonly property real usableY: 0
    readonly property real usableW: screenFrame.width
    readonly property real usableH: screenFrame.height

    default property alias contentData: dragTargetContainer.data

    signal positionChanged(real horizontalPosition, real verticalPosition)
    signal dragStarted()
    signal dragFinished()

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    implicitWidth: 300
    implicitHeight: width > 0 ? Math.round(width / screenAspect) : s(170)

    Rectangle {
        id: screenFrame
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        border.width: 1
        border.color: root.borderColor
        clip: true

        property real activeGuideX: -1
        property real activeGuideY: -1

        Rectangle {
            id: barPreviewBox
            visible: root.showBar
            z: 5
            color: ThemeBackend.surface0
            border.width: 1
            border.color: ThemeBackend.surface1
            radius: (root.rawBarSettings && root.rawBarSettings.style === "modular") ? root.s(3) : 0

            x: {
                if (root.barPosition === "right") return screenFrame.width - width;
                return 0;
            }
            y: {
                if (root.barPosition === "bottom") return screenFrame.height - height;
                return 0;
            }
            width: {
                if (root.barPosition === "left" || root.barPosition === "right") {
                    return Math.max(root.s(4), root.barConfigHeight * (screenFrame.width / root.screenRealWidth));
                }
                return screenFrame.width;
            }
            height: {
                if (root.barPosition === "left" || root.barPosition === "right") {
                    return screenFrame.height;
                }
                return Math.max(root.s(4), root.barConfigHeight * (screenFrame.height / root.screenRealHeight));
            }
        }

        Loader {
            anchors.fill: parent
            active: root.gridEnabled
            sourceComponent: Canvas {
                id: gridCanvas
                anchors.fill: parent
                property real stepSize: root.s(16)

                Connections {
                    target: screenFrame
                    function onWidthChanged() { gridCanvas.requestPaint() }
                    function onHeightChanged() { gridCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.08);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (let x = 0; x <= width; x += stepSize) {
                        ctx.moveTo(x, 0); ctx.lineTo(x, height);
                    }
                    for (let y = 0; y <= height; y += stepSize) {
                        ctx.moveTo(0, y); ctx.lineTo(width, y);
                    }
                    ctx.stroke();
                }
            }
        }

        Rectangle {
            x: screenFrame.activeGuideX
            y: 0
            width: root.s(1.5)
            height: parent.height
            color: root.guideColor
            visible: screenFrame.activeGuideX >= 0
            z: 30
        }

        Rectangle {
            x: 0
            y: screenFrame.activeGuideY
            width: parent.width
            height: root.s(1.5)
            color: root.guideColor
            visible: screenFrame.activeGuideY >= 0
            z: 30
        }

        MouseArea {
            id: frameMa
            anchors.fill: parent
            z: 25
            hoverEnabled: true
            preventStealing: true

            property bool isDragging: false
            property real dragOffsetX: 0
            property real dragOffsetY: 0

            readonly property bool isOverBox: mouseX >= dragBox.x && mouseX <= (dragBox.x + dragBox.width) &&
                                              mouseY >= dragBox.y && mouseY <= (dragBox.y + dragBox.height)

            cursorShape: isDragging ? Qt.ClosedHandCursor : (isOverBox ? Qt.OpenHandCursor : Qt.ArrowCursor)

            onPressed: mouse => {
                if (!isOverBox) return;

                isDragging = true;
                dragOffsetX = mouse.x - dragBox.x;
                dragOffsetY = mouse.y - dragBox.y;

                if (typeof Sounds !== "undefined") {
                    Sounds.playSfx(root.clickSound);
                }

                root.dragStarted();
            }

            onPositionChanged: mouse => {
                if (!isDragging) return;

                let availW = dragBox.availW;
                let availH = dragBox.availH;

                let rawX = mouse.x - dragOffsetX;
                let rawY = mouse.y - dragOffsetY;

                let guideX = -1;
                let guideY = -1;
                let finalX = rawX;
                let finalY = rawY;

                if (root.gridEnabled) {
                    let gridStep = root.s(16);
                    finalX = Math.round(rawX / gridStep) * gridStep;
                    finalY = Math.round(rawY / gridStep) * gridStep;
                } else {
                    let snapThreshold = root.s(5);
                    let bestDx = snapThreshold;
                    let bestDy = snapThreshold;

                    let dXEdges = [rawX, rawX + dragBox.width / 2.0, rawX + dragBox.width];
                    let dYEdges = [rawY, rawY + dragBox.height / 2.0, rawY + dragBox.height];

                    let screenCenterX = screenFrame.width / 2.0;
                    let screenCenterY = screenFrame.height / 2.0;

                    for (let j = 0; j < dXEdges.length; j++) {
                        let diff = Math.abs(dXEdges[j] - screenCenterX);
                        if (diff < bestDx) {
                            bestDx = diff;
                            finalX = rawX + (screenCenterX - dXEdges[j]);
                            guideX = screenCenterX;
                        }
                    }

                    for (let j = 0; j < dYEdges.length; j++) {
                        let diff = Math.abs(dYEdges[j] - screenCenterY);
                        if (diff < bestDy) {
                            bestDy = diff;
                            finalY = rawY + (screenCenterY - dYEdges[j]);
                            guideY = screenCenterY;
                        }
                    }

                    if (root.showBar) {
                        if (root.barPosition === "top") {
                            let barBottom = barPreviewBox.height + root.marginV;
                            let diff = Math.abs(rawY - barBottom);
                            if (diff < bestDy) {
                                bestDy = diff;
                                finalY = barBottom;
                                guideY = barBottom;
                            }
                        } else if (root.barPosition === "bottom") {
                            let barTop = screenFrame.height - barPreviewBox.height - root.marginV;
                            let diff = Math.abs((rawY + dragBox.height) - barTop);
                            if (diff < bestDy) {
                                bestDy = diff;
                                finalY = barTop - dragBox.height;
                                guideY = barTop;
                            }
                        } else if (root.barPosition === "left") {
                            let barRight = barPreviewBox.width + root.marginH;
                            let diff = Math.abs(rawX - barRight);
                            if (diff < bestDx) {
                                bestDx = diff;
                                finalX = barRight;
                                guideX = barRight;
                            }
                        } else if (root.barPosition === "right") {
                            let barLeft = screenFrame.width - barPreviewBox.width - root.marginH;
                            let diff = Math.abs((rawX + dragBox.width) - barLeft);
                            if (diff < bestDx) {
                                bestDx = diff;
                                finalX = barLeft - dragBox.width;
                                guideX = barLeft;
                            }
                        }
                    }

                    if (root.marginV > 0) {
                        if (!root.showBar || root.barPosition !== "top") {
                            let topEdge = root.marginV;
                            let diff = Math.abs(rawY - topEdge);
                            if (diff < bestDy) {
                                bestDy = diff;
                                finalY = topEdge;
                                guideY = topEdge;
                            }
                        }
                        if (!root.showBar || root.barPosition !== "bottom") {
                            let bottomEdge = screenFrame.height - root.marginV;
                            let diff = Math.abs((rawY + dragBox.height) - bottomEdge);
                            if (diff < bestDy) {
                                bestDy = diff;
                                finalY = bottomEdge - dragBox.height;
                                guideY = bottomEdge;
                            }
                        }
                    }

                    if (root.marginH > 0) {
                        if (!root.showBar || root.barPosition !== "left") {
                            let leftEdge = root.marginH;
                            let diff = Math.abs(rawX - leftEdge);
                            if (diff < bestDx) {
                                bestDx = diff;
                                finalX = leftEdge;
                                guideX = leftEdge;
                            }
                        }
                        if (!root.showBar || root.barPosition !== "right") {
                            let rightEdge = screenFrame.width - root.marginH;
                            let diff = Math.abs((rawX + dragBox.width) - rightEdge);
                            if (diff < bestDx) {
                                bestDx = diff;
                                finalX = rightEdge - dragBox.width;
                                guideX = rightEdge;
                            }
                        }
                    }
                }

                finalX = Math.max(0, Math.min(availW, finalX));
                finalY = Math.max(0, Math.min(availH, finalY));

                screenFrame.activeGuideX = guideX;
                screenFrame.activeGuideY = guideY;

                let newPctX = Math.max(0, Math.min(100, (finalX / availW) * 100.0));
                let newPctY = Math.max(0, Math.min(100, (finalY / availH) * 100.0));

                if (root.horizontalPosition !== newPctX || root.verticalPosition !== newPctY) {
                    root.horizontalPosition = newPctX;
                    root.verticalPosition = newPctY;
                    root.positionChanged(newPctX, newPctY);
                }
            }

            onReleased: {
                if (isDragging) {
                    isDragging = false;
                    screenFrame.activeGuideX = -1;
                    screenFrame.activeGuideY = -1;
                    root.dragFinished();
                }
            }

            onCanceled: {
                if (isDragging) {
                    isDragging = false;
                    screenFrame.activeGuideX = -1;
                    screenFrame.activeGuideY = -1;
                    root.dragFinished();
                }
            }
        }

        Item {
            id: dragBox
            z: 20
            width: root.dragWidth
            height: root.dragHeight

            readonly property real availW: Math.max(1, screenFrame.width - width)
            readonly property real availH: Math.max(1, screenFrame.height - height)

            x: Math.max(0, Math.min(availW, availW * (root.horizontalPosition / 100.0)))
            y: Math.max(0, Math.min(availH, availH * (root.verticalPosition / 100.0)))

            scale: frameMa.isDragging ? 1.04 : (frameMa.isOverBox ? 1.02 : 1.0)
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

            Item {
                id: dragTargetContainer
                anchors.fill: parent
            }
        }
    }
}
