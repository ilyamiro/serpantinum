import QtQuick
import "../"

Item {
    id: fp

    property string status: "ready"
    property string label: ""
    property real glyphSize: 56
    property real labelPixelSize: 13
    property bool showLabel: true
    property int attempts: 0
    property int maxAttempts: 5

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
    SequentialAnimation {
        running: fp.visible && fp.status === "ready"
        loops: Animation.Infinite
        NumberAnimation { target: fp; property: "breath"; to: 0.72; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { target: fp; property: "breath"; to: 0.9; duration: 1100; easing.type: Easing.InOutSine }
    }

    Behavior on shownAccent { ColorAnimation { duration: 220 } }
    Behavior on shownFill { NumberAnimation { duration: status === "success" ? 300 : 360; easing.type: Easing.OutCubic } }

    readonly property real stageSize: glyphSize * 1.7

    implicitWidth: Math.max(stageSize, labelText.implicitWidth)
    implicitHeight: stageSize + (showLabel ? labelText.implicitHeight + glyphSize * 0.12 + pips.height : 0)

    onStatusChanged: {
        if (status === "success") {
            popAnim.restart();
            burstAnim.restart();
        } else if (status === "failed") {
            shakeAnim.restart();
            flashAnim.restart();
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

            SequentialAnimation {
                running: fp.visible && fp.pulsing
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
            id: burstRing
            anchors.centerIn: parent
            width: restRing.width
            height: width
            radius: width / 2
            color: ThemeBackend.green
            opacity: 0
            scale: 1

            ParallelAnimation {
                id: burstAnim
                NumberAnimation { target: burstRing; property: "scale"; from: 1; to: 1.75; duration: 560; easing.type: Easing.OutCubic }
                NumberAnimation { target: burstRing; property: "opacity"; from: 0.4; to: 0; duration: 560; easing.type: Easing.OutQuad }
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

            SequentialAnimation {
                id: flashAnim
                NumberAnimation { target: flashRing; property: "opacity"; to: 0.3; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: flashRing; property: "opacity"; to: 0; duration: 520; easing.type: Easing.OutCubic }
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
                font.family: "Iosevka Nerd Font"
                font.pixelSize: fp.glyphSize * 0.82
                color: ThemeBackend.overlay0
                opacity: fp.halted ? 0.45 : (fp.status === "ready" ? fp.breath : 0.85)
            }

            Item {
                id: fillClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * fp.shownFill
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
