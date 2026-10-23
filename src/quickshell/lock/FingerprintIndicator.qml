import QtQuick
import "../"

Item {
    id: fp

    property string status: "ready"
    property string label: ""
    property real glyphSize: 56
    property real labelPixelSize: 13
    property bool showLabel: true
    property string look: "classic"
    property int attempts: 0
    property int maxAttempts: 5

    readonly property bool shaderLook: look === "orbit" || look === "liquid"
    readonly property bool tintGlyph: look === "ring" || look === "pulse" || shaderLook
    readonly property bool halted: status === "blocked" || status === "error"
    readonly property bool pulsing: status === "ready" || status === "hold"
    readonly property color accent: {
        switch (status) {
        case "success": return ThemeBackend.green;
        case "failed":
        case "blocked":
        case "error": return ThemeBackend.red;
        case "hold": return ThemeBackend.peach;
        default: return ThemeBackend.mauve;
        }
    }
    readonly property real targetFill: {
        switch (status) {
        case "success": return 1.0;
        case "hold": return 0.5;
        default: return 0.0;
        }
    }

    property color shownAccent: accent
    property real shownFill: targetFill
    property real breath: 0.9
    property real scanPos: 0
    property real shaderTime: 0
    property real shaderBurst: 0
    property real successT: 0

    NumberAnimation {
        id: successAnim
        target: fp
        property: "successT"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.Linear
    }
    property real spin: pulsing ? 1 : 0
    Behavior on spin { NumberAnimation { duration: 260 } }

    NumberAnimation on shaderTime {
        running: fp.visible && fp.shaderLook
        from: 0
        to: 3600
        duration: 3600000
        loops: Animation.Infinite
    }

    NumberAnimation {
        id: shaderBurstAnim
        target: fp
        property: "shaderBurst"
        from: 0
        to: 1
        duration: 760
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        running: fp.visible && fp.status === "ready"
        loops: Animation.Infinite
        NumberAnimation { target: fp; property: "breath"; to: 0.72; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { target: fp; property: "breath"; to: 0.9; duration: 1100; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        running: fp.visible && fp.look === "scanner" && fp.pulsing
        loops: Animation.Infinite
        NumberAnimation { target: fp; property: "scanPos"; to: 1; duration: fp.status === "hold" ? 500 : 1300; easing.type: Easing.InOutSine }
        NumberAnimation { target: fp; property: "scanPos"; to: 0; duration: fp.status === "hold" ? 500 : 1300; easing.type: Easing.InOutSine }
    }

    onShownAccentChanged: { ringCanvas.requestPaint(); sweepCanvas.requestPaint(); bracketCanvas.requestPaint(); }
    onShownFillChanged: ringCanvas.requestPaint()

    Behavior on shownAccent { ColorAnimation { duration: 220 } }
    Behavior on shownFill { NumberAnimation { duration: status === "success" ? 300 : 360; easing.type: Easing.OutCubic } }

    readonly property real stageSize: glyphSize * 1.7

    implicitWidth: Math.max(stageSize, labelText.implicitWidth)
    implicitHeight: stageSize + (showLabel ? labelText.implicitHeight + glyphSize * 0.12 + pips.height : 0)

    onStatusChanged: {
        if (status !== "success") {
            successAnim.stop();
            successT = 0;
        }
        if (status === "success") {
            popAnim.restart();
            lockOnAnim.restart();
            successAnim.restart();
        } else if (status === "failed") {
            shakeAnim.restart();
            flashAnim.restart();
            shaderBurstAnim.restart();
        }
    }

    Item {
        id: stage
        width: fp.stageSize
        height: fp.stageSize
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            id: restRing
            anchors.centerIn: parent
            width: fp.glyphSize * 1.28
            height: width
            radius: width / 2
            visible: fp.look === "classic"
            color: Qt.rgba(fp.shownAccent.r, fp.shownAccent.g, fp.shownAccent.b, fp.halted ? 0.04 : 0.07)
        }

        Rectangle {
            id: rippleRing
            anchors.centerIn: parent
            width: restRing.width
            height: width
            radius: width / 2
            color: fp.shownAccent
            opacity: 0
            scale: 1
            visible: fp.look === "classic"

            SequentialAnimation {
                running: fp.visible && fp.pulsing && fp.look === "classic"
                loops: Animation.Infinite
                onRunningChanged: if (!running) { rippleRing.opacity = 0; rippleRing.scale = 1; }
                ParallelAnimation {
                    NumberAnimation { target: rippleRing; property: "scale"; from: 1; to: 1.3; duration: fp.status === "hold" ? 1100 : 2400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: rippleRing; property: "opacity"; from: 0.1; to: 0; duration: fp.status === "hold" ? 1100 : 2400; easing.type: Easing.OutQuad }
                }
                PauseAnimation { duration: fp.status === "hold" ? 200 : 700 }
            }
        }

        Rectangle {
            id: flashRing
            anchors.centerIn: parent
            width: restRing.width
            height: width
            radius: width / 2
            color: ThemeBackend.red
            opacity: 0
            visible: fp.look !== "scanner"

            SequentialAnimation {
                id: flashAnim
                NumberAnimation { target: flashRing; property: "opacity"; to: 0.3; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: flashRing; property: "opacity"; to: 0; duration: 520; easing.type: Easing.OutCubic }
            }
        }

        Canvas {
            id: ringCanvas
            anchors.centerIn: parent
            width: fp.glyphSize * 1.5
            height: width
            visible: fp.look === "ring"
            onWidthChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let lw = fp.glyphSize * 0.07;
                let c = width / 2;
                let r = (width - lw) / 2;
                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                ctx.strokeStyle = Qt.rgba(fp.shownAccent.r, fp.shownAccent.g, fp.shownAccent.b, 0.2);
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI * 2);
                ctx.stroke();
                if (fp.shownFill > 0.005) {
                    ctx.strokeStyle = fp.shownAccent;
                    ctx.beginPath();
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, fp.shownFill));
                    ctx.stroke();
                }
            }
        }

        Canvas {
            id: sweepCanvas
            anchors.centerIn: parent
            width: ringCanvas.width
            height: width
            visible: fp.look === "ring"
            opacity: fp.pulsing && fp.shownFill < 0.05 ? 1 : 0
            onWidthChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            Behavior on opacity { NumberAnimation { duration: 200 } }
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let lw = fp.glyphSize * 0.07;
                let c = width / 2;
                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                ctx.strokeStyle = fp.shownAccent;
                ctx.beginPath();
                ctx.arc(c, c, (width - lw) / 2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 0.5);
                ctx.stroke();
            }

            RotationAnimation on rotation {
                running: fp.visible && fp.look === "ring" && fp.pulsing
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: fp.status === "hold" ? 900 : 2600
            }
        }

        Repeater {
            model: fp.look === "pulse" ? 3 : 0

            Rectangle {
                id: pulseRing
                required property int index
                anchors.centerIn: parent
                width: fp.glyphSize * 1.1
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1, fp.glyphSize * 0.035)
                border.color: fp.shownAccent
                opacity: 0
                scale: 1

                SequentialAnimation {
                    running: fp.visible && fp.pulsing
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) { pulseRing.opacity = 0; pulseRing.scale = 1; }
                    PauseAnimation { duration: pulseRing.index * (fp.status === "hold" ? 260 : 700) }
                    ParallelAnimation {
                        NumberAnimation { target: pulseRing; property: "scale"; from: 1; to: 1.5; duration: fp.status === "hold" ? 800 : 2100; easing.type: Easing.OutCubic }
                        NumberAnimation { target: pulseRing; property: "opacity"; from: 0.55; to: 0; duration: fp.status === "hold" ? 800 : 2100; easing.type: Easing.OutQuad }
                    }
                    PauseAnimation { duration: (2 - pulseRing.index) * (fp.status === "hold" ? 260 : 700) }
                }
            }
        }

        ShaderEffect {
            id: shaderFx
            anchors.centerIn: parent
            width: fp.stageSize
            height: fp.stageSize
            visible: fp.shaderLook

            property vector2d itemSize: Qt.vector2d(width, height)
            property color accentColor: fp.shownAccent
            property vector4d params: Qt.vector4d(fp.shaderTime, fp.shownFill, fp.shaderBurst, fp.look === "liquid" ? 1.0 : 0.0)
            property vector4d cfg: Qt.vector4d(fp.spin, fp.status === "hold" ? (fp.look === "liquid" ? 2.0 : 5.0) : (fp.look === "liquid" ? 1.0 : 2.4), 0.0, 0.0)

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/lock/fingerprint_ring.frag.qsb"
        }

        Item {
            id: scanFrame
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: shakeShift.x
            width: fp.glyphSize * 1.45
            height: width
            visible: fp.look === "scanner"
            scale: 1

            SequentialAnimation {
                id: lockOnAnim
                NumberAnimation { target: scanFrame; property: "scale"; to: 1.18; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: scanFrame; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
            }

            Canvas {
                id: bracketCanvas
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    let lw = fp.glyphSize * 0.06;
                    let a = width * 0.24;
                    let o = lw / 2;
                    let e = width - o;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.strokeStyle = fp.shownAccent;
                    ctx.beginPath();
                    ctx.moveTo(o, o + a); ctx.lineTo(o, o); ctx.lineTo(o + a, o);
                    ctx.moveTo(e - a, o); ctx.lineTo(e, o); ctx.lineTo(e, o + a);
                    ctx.moveTo(e, e - a); ctx.lineTo(e, e); ctx.lineTo(e - a, e);
                    ctx.moveTo(o + a, e); ctx.lineTo(o, e); ctx.lineTo(o, e - a);
                    ctx.stroke();
                }
            }

            Rectangle {
                width: parent.width * 0.78
                height: Math.max(2, fp.glyphSize * 0.045)
                radius: height / 2
                x: (parent.width - width) / 2
                y: parent.height * 0.12 + fp.scanPos * (parent.height * 0.76 - height)
                color: fp.shownAccent
                opacity: fp.pulsing ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }

        Item {
            id: glyphBox
            anchors.centerIn: parent
            width: glyphMetrics.tightBoundingRect.width
            height: glyphMetrics.tightBoundingRect.height
            transform: Translate { id: shakeShift; x: 0 }

            TextMetrics {
                id: glyphMetrics
                font: baseGlyph.font
                text: baseGlyph.text
            }

            FontMetrics {
                id: glyphFontMetrics
                font: baseGlyph.font
            }

            Text {
                id: baseGlyph
                x: -glyphMetrics.tightBoundingRect.x
                y: -(glyphFontMetrics.ascent + glyphMetrics.tightBoundingRect.y)
                text: "󰈷"
                font.family: ThemeBackend.iconFont
                font.pixelSize: fp.glyphSize * 0.82
                color: fp.tintGlyph ? fp.shownAccent : ThemeBackend.overlay0
                opacity: fp.halted ? 0.45 : (fp.status === "ready" ? fp.breath : 0.85)
            }

            Item {
                id: fillClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: fp.tintGlyph ? 0 : parent.height * fp.shownFill
                clip: true

                Text {
                    x: baseGlyph.x
                    y: baseGlyph.y - fillClip.y
                    text: baseGlyph.text
                    font: baseGlyph.font
                    color: fp.shownAccent
                }
            }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: glyphBox; property: "scale"; to: 1.14; duration: 170; easing.type: Easing.OutCubic }
                NumberAnimation { target: glyphBox; property: "scale"; to: 1.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeShift; property: "x"; to: -fp.glyphSize * 0.14; duration: 55; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeShift; property: "x"; to: fp.glyphSize * 0.12; duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeShift; property: "x"; to: -fp.glyphSize * 0.08; duration: 80; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeShift; property: "x"; to: fp.glyphSize * 0.04; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 60; easing.type: Easing.InQuad }
            }
        }
        ShaderEffect {
            anchors.centerIn: parent
            width: fp.stageSize * 2.0
            height: width
            visible: fp.successT > 0
            z: 10

            property vector2d itemSize: Qt.vector2d(width, height)
            property color accentColor: ThemeBackend.green
            property vector4d params: Qt.vector4d(fp.successT, 2.0, 0.0, 0.0)

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/lock/fingerprint_success.frag.qsb"
        }
    }

    Text {
        id: labelText
        visible: fp.showLabel
        anchors.top: stage.bottom
        anchors.topMargin: fp.glyphSize * 0.04
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, fp.width > 0 ? fp.width : implicitWidth)
        text: fp.label
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: ThemeBackend.fontFamily
        font.pixelSize: fp.labelPixelSize
        font.weight: Font.Medium
        color: fp.status === "ready" ? ThemeBackend.subtext0 : fp.shownAccent

        Behavior on color { ColorAnimation { duration: 220 } }
    }

    SequentialAnimation {
        id: labelSwap
        NumberAnimation { target: labelText; property: "opacity"; to: 0; duration: 80; easing.type: Easing.InQuad }
        NumberAnimation { target: labelText; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }

    onLabelChanged: if (visible && showLabel) labelSwap.restart()

    Row {
        id: pips
        visible: fp.showLabel
        opacity: (fp.attempts > 0 && fp.status !== "success") ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        anchors.top: labelText.bottom
        anchors.topMargin: fp.glyphSize * 0.1
        anchors.horizontalCenter: parent.horizontalCenter
        height: fp.glyphSize * 0.1
        spacing: fp.glyphSize * 0.08

        Repeater {
            model: fp.maxAttempts

            Rectangle {
                required property int index
                readonly property bool used: index < fp.attempts
                width: fp.glyphSize * 0.1
                height: width
                radius: width / 2
                color: used ? ThemeBackend.red : ThemeBackend.surface2
                opacity: used ? 1.0 : 0.55
                scale: used ? 1.0 : 0.8

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
            }
        }
    }
}
