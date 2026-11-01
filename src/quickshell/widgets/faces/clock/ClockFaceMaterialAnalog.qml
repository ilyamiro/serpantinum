import QtQuick
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 100
    property real maxWidth: 800
    property real maxHeight: 800
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    property bool showSeconds: true

    property var currentTime: new Date()
    property int lastSecond: (new Date()).getSeconds()
    property real secondHeadAngle: lastSecond * 6
    property real secondTailAngle: secondHeadAngle

    function morphSecond(sec) {
        if (!root.showSeconds) return;

        if (morphAnim.running) {
            morphAnim.stop();
            root.secondHeadAngle = Math.round(((headAnim.to % 360) + 360) % 360);
            root.secondTailAngle = root.secondHeadAngle;
        }

        var target = sec * 6;
        var currentNorm = Math.round(((root.secondTailAngle % 360) + 360) % 360);
        var diff = (target - currentNorm + 360) % 360;

        if (diff === 0) {
            return;
        }

        if (diff > 12) {
            root.secondHeadAngle = target;
            root.secondTailAngle = target;
            return;
        }

        var startAngle = root.secondTailAngle;
        var endAngle = startAngle + diff;

        headAnim.from = startAngle;
        headAnim.to = endAngle;
        tailAnim.from = startAngle;
        tailAnim.to = endAngle;

        morphAnim.restart();
    }

    ParallelAnimation {
        id: morphAnim

        NumberAnimation {
            id: headAnim
            target: root
            property: "secondHeadAngle"
            duration: 250
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation {
                id: tailAnim
                target: root
                property: "secondTailAngle"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        onFinished: {
            root.secondHeadAngle = Math.round(((root.secondHeadAngle % 360) + 360) % 360);
            root.secondTailAngle = root.secondHeadAngle;
        }
    }

    Timer {
        id: clockTimer
        interval: Math.max(20, 1000 - (new Date()).getMilliseconds())
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date();
            root.currentTime = now;
            var sec = now.getSeconds();
            if (sec !== root.lastSecond) {
                root.lastSecond = sec;
                root.morphSecond(sec);
            }
            interval = Math.max(20, 1000 - now.getMilliseconds());
        }
    }

    Component.onCompleted: {
        var now = new Date();
        root.currentTime = now;
        root.lastSecond = now.getSeconds();
        root.secondHeadAngle = root.lastSecond * 6;
        root.secondTailAngle = root.secondHeadAngle;
    }

    function resolveColor(token, fallback) {
        if (ThemeBackend.matugenColors) {
            var val = ThemeBackend.matugenColors[token];
            if (val) {
                if (typeof val === "string") return Qt.color(val);
                if (typeof val === "object") {
                    if (val.hex) return Qt.color(val.hex);
                    if (val.color) return Qt.color(val.color);
                    if (val.default && val.default.hex) return Qt.color(val.default.hex);
                }
            }
        }
        return fallback;
    }

    readonly property color dialColor: resolveColor("primary_container", ThemeBackend.surface0)
    readonly property color hourHandColor: resolveColor("secondary", ThemeBackend.peach)
    readonly property color minuteHandColor: resolveColor("primary", ThemeBackend.accent)
    readonly property color secondHandColor: resolveColor("tertiary", ThemeBackend.teal)
    readonly property color indicatorColor: resolveColor("tertiary", resolveColor("secondary", ThemeBackend.peach))

    Item {
        anchors.fill: parent

        Canvas {
            id: dialCanvas
            anchors.fill: parent
            antialiasing: true

            property color fillColor: root.dialColor

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onFillColorChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2;
                var cy = height / 2;
                var size = Math.min(width, height);
                var lobes = 12;
                var rMid = size * 0.46;
                var rAmp = size * 0.012;
                var steps = 240;

                ctx.beginPath();
                for (var i = 0; i <= steps; i++) {
                    var a = (i / steps) * Math.PI * 2;
                    var r = rMid + rAmp * Math.cos(lobes * a);
                    var x = cx + r * Math.sin(a);
                    var y = cy - r * Math.cos(a);

                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.closePath();
                ctx.fillStyle = fillColor;
                ctx.fill();
            }
        }

        ShaderEffect {
            id: secondCanvas
            anchors.fill: parent
            visible: root.showSeconds
            z: 3

            property vector2d itemSize: Qt.vector2d(width, height)
            property real headAngle: root.secondHeadAngle
            property real tailAngle: root.secondTailAngle
            property color indicatorColor: root.indicatorColor
            property vector4d params: Qt.vector4d(0.0, 0.0, 0.0, 0.0)

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/gauges/clock_second_arc.frag.qsb"
        }

        Item {
            id: hourPivot
            anchors.centerIn: parent
            z: 1
            rotation: (root.currentTime.getHours() % 12) * 30 + root.currentTime.getMinutes() * 0.5 + root.currentTime.getSeconds() * (0.5 / 60)

            Behavior on rotation {
                RotationAnimation {
                    duration: 400
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                width: Math.min(root.width, root.height) * 0.076
                height: Math.min(root.width, root.height) * 0.24
                radius: width / 2
                color: root.hourHandColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: -width / 2
                antialiasing: true
            }
        }

        Item {
            id: minutePivot
            anchors.centerIn: parent
            z: 2
            rotation: root.currentTime.getMinutes() * 6 + root.currentTime.getSeconds() * 0.1

            Behavior on rotation {
                RotationAnimation {
                    duration: 400
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                width: Math.min(root.width, root.height) * 0.082
                height: Math.min(root.width, root.height) * 0.36
                radius: width / 2
                color: root.minuteHandColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: -width / 2
                antialiasing: true
            }
        }
    }
}
