import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

Item {
    id: root
    property bool vertical: false
    implicitWidth: vertical ? 24 : 200
    implicitHeight: vertical ? 200 : 24
    activeFocusOnTab: true

    property real from: 0.0
    property real to: 100.0
    property real value: 0.0
    property real dragPreview: value
    readonly property real effectiveValue: root.isDragging ? root.dragPreview : root.value
    property real stepSize: 0.0
    property real defaultValue: from

    property color accentColor: "#89b4fa"
    property color gradColor1: root.accentColor
    property color gradColor2: Qt.lighter(root.accentColor, 1.05)
    property color gradColor3: Qt.lighter(root.accentColor, 1.10)
    property color backgroundColor: "#1e1e2e"

    property color handleColor: root.accentColor
    property color handleHoverColor: Qt.lighter(root.handleColor, 1.15)
    property color handleDragColor: Qt.lighter(root.handleColor, 1.30)
    property color handleBorderColor: Qt.rgba(0, 0, 0, root.isDragging ? 0.20 : 0.10)

    property real cornerRadius: (root.vertical ? width : height) / 2
    property real handleSize: root.vertical ? root.width : root.height
    property real handleRadius: handleSize / 2

    property bool enabled: true
    property bool isDragging: false
    property bool action_highlight: false
    property bool alwaysShowHandle: false

    property bool showValueBubble: true
    property bool showTooltip: false
    property var valueFormatter: function(v) { return Math.round(v).toString() }

    property string dragTickSound: "reusables/draggable/tick.wav"

    signal moved(real val)
    signal dragStarted()
    signal dragFinished()
    signal triggered()

    property real visualPosition: Math.max(0.0, Math.min(1.0, (root.effectiveValue - from) / Math.max(0.0001, to - from)))
    property real animPosition: visualPosition
    readonly property real percentage: root.visualPosition * 100

    property bool _keyboardActive: false

    Behavior on animPosition {
        enabled: !root.isDragging
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: kbdTimer
        interval: 1500
        onTriggered: root._keyboardActive = false
    }

    property bool isHoveredOrHighlighted: (sliderMa.containsMouse || root.action_highlight) && root.enabled
    property bool handleShouldShow: root.enabled && (root.alwaysShowHandle || root.isDragging || (root.activeFocus && root._keyboardActive))

    property real targetScale: {
        if (!root.handleShouldShow) return 0.0;
        if (root.isDragging) return 1.40;
        if (root.alwaysShowHandle || root.isHoveredOrHighlighted) return 1.23;
        return 1.0;
    }

    Behavior on targetScale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutBack
        }
    }

    property real _lastStepValue: effectiveValue
    property double _lastTickTime: 0

    function clampVal(v) {
        return Math.max(root.from, Math.min(root.to, v));
    }

    function snapVal(v) {
        if (root.stepSize > 0) return Math.round(v / root.stepSize) * root.stepSize;
        return v;
    }

    function valueAtPos(mx, my) {
        let pct = root.vertical
            ? Math.max(0.0, Math.min(1.0, (root.height - my) / Math.max(1, root.height)))
            : Math.max(0.0, Math.min(1.0, mx / Math.max(1, root.width)));
        return clampVal(snapVal(root.from + pct * (root.to - root.from)));
    }

    function valueAtX(mx) {
        return valueAtPos(mx, 0);
    }

    function playTickThrottled(vol) {
        if (typeof Sounds === "undefined") return;
        let now = Date.now();
        if (now - root._lastTickTime >= 50) {
            root._lastTickTime = now;
            Sounds.playSfx(root.dragTickSound, vol);
        }
    }

    function setValue(v, playTick) {
        if (!root.enabled) return;
        let snapped = clampVal(snapVal(v));
        if (snapped === root.effectiveValue) return;
        root.dragPreview = snapped;
        root.moved(snapped);
        pulseHandle();
        if (playTick) {
            playTickThrottled(0.6);
        }
    }

    function nudge(dir) {
        if (!root.enabled) return;
        let step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 100;
        setValue(root.effectiveValue + dir * step, true);
    }

    function pulseHandle() {
        handle.popScale = 1.0;
        handlePopAnim.restart();
    }

    Keys.onPressed: event => {
        root._keyboardActive = true;
        kbdTimer.restart();
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            root.nudge(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            root.nudge(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.setValue(root.from, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.setValue(root.to, false);
            event.accepted = true;
        }
    }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.backgroundColor
        opacity: root.enabled ? 1.0 : 0.5
        clip: true

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: fillTrack
            x: 0
            y: root.vertical ? Math.max(0, Math.min(bgTrack.height, handle.y)) : 0
            width: root.vertical ? bgTrack.width : Math.max(0, Math.min(bgTrack.width, handle.x + handle.width))
            height: root.vertical ? Math.max(0, Math.min(bgTrack.height, bgTrack.height - handle.y)) : bgTrack.height
            opacity: root.animPosition > 0.001 ? 1.0 : 0.0
            radius: root.cornerRadius

            gradient: Gradient {
                orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
                GradientStop { position: 0.0; color: root.vertical ? root.gradColor3 : root.gradColor1; Behavior on color { ColorAnimation { duration: 150 } } }
                GradientStop { position: 0.5; color: root.gradColor2; Behavior on color { ColorAnimation { duration: 150 } } }
                GradientStop { position: 1.0; color: root.vertical ? root.gradColor1 : root.gradColor3; Behavior on color { ColorAnimation { duration: 150 } } }
            }

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
    }

    Rectangle {
        id: focusRing
        anchors.centerIn: handle
        width: handle.width + 8
        height: handle.height + 8
        radius: Math.min(width, height) / 2
        color: "transparent"
        border.width: 2
        border.color: root.accentColor
        visible: root.activeFocus && root._keyboardActive
    }

    Rectangle {
        id: handle
        readonly property int textLength: handleText.text ? handleText.text.length : 0
        readonly property real fontScale: textLength <= 2 ? 1.0 : Math.max(0.65, 1.0 - (textLength - 2) * 0.09)
        readonly property real textPadding: Math.min(10, Math.max(4, Math.round(root.handleSize * 0.25)))

        width: root.showValueBubble ? Math.max(root.handleSize, Math.round(handleText.contentWidth + textPadding)) : root.handleSize
        height: root.handleSize
        radius: Math.min(width, height) / 2
        x: root.vertical ? (root.width - width) / 2 : root.animPosition * (root.width - width)
        y: root.vertical ? (1.0 - root.animPosition) * (root.height - height) : (root.height - height) / 2
        color: root.isDragging ? root.handleDragColor : (root.isHoveredOrHighlighted ? root.handleHoverColor : root.handleColor)
        border.color: root.handleBorderColor
        border.width: 0

        property real popScale: 1.0
        property real flashOpacity: 0.0

        opacity: root.enabled ? 1.0 : 0.5
        scale: root.targetScale * popScale

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            id: handlePopAnim
            NumberAnimation {
                target: handle
                property: "popScale"
                to: 1.12
                duration: 100
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: handle
                property: "popScale"
                to: 1.0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            opacity: handle.flashOpacity
            PropertyAnimation on opacity { id: handleFlashAnim; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }

        Text {
            id: handleText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.valueFormatter(root.effectiveValue)
            color: Qt.hsla(root.accentColor.hslHue, root.accentColor.hslSaturation, 0.12, 1.0)
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: Math.max(8, Math.round(root.handleSize * 0.42 * handle.fontScale))
            visible: root.showValueBubble
        }
    }

    Rectangle {
        id: valueBubble
        property real previewVal: root._keyboardActive ? root.effectiveValue : root.valueAtPos(sliderMa.mouseX, sliderMa.mouseY)
        property bool shouldShow: root.showTooltip && !root.isDragging && (root.isHoveredOrHighlighted || root._keyboardActive) && (previewVal !== root.effectiveValue)

        visible: opacity > 0.001
        opacity: shouldShow ? 1.0 : 0.0
        scale: shouldShow ? 1.0 : 0.85

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutQuint
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }
        }

        width: bubbleText.contentWidth + 16
        height: 22
        radius: 8
        color: root.accentColor

        property real targetCenter: root.vertical
            ? (root._keyboardActive ? handle.y + handle.height / 2 : Math.max(0, Math.min(root.height, sliderMa.mouseY)))
            : (root._keyboardActive ? handle.x + handle.width / 2 : Math.max(0, Math.min(root.width, sliderMa.mouseX)))

        x: root.vertical
            ? handle.x - width - 8
            : Math.max(0, Math.min(root.width - width, targetCenter - width / 2))
        y: root.vertical
            ? Math.max(0, Math.min(root.height - height, targetCenter - height / 2))
            : handle.y - height - 8

        Behavior on x {
            enabled: !root.isDragging && !root.vertical
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: !root.isDragging && root.vertical
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            width: 8
            height: 8
            color: parent.color
            rotation: 45
            x: root.vertical ? parent.width - 4 : (parent.width - width) / 2
            y: root.vertical ? (parent.height - height) / 2 : parent.height - 4
        }

        Text {
            id: bubbleText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.valueFormatter(valueBubble.previewVal)
            color: Qt.hsla(root.accentColor.hslHue, root.accentColor.hslSaturation, 0.12, 1.0)
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: sliderMa
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        preventStealing: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        property real wheelAccumulator: 0

        onPressed: mouse => {
            if (!root.enabled) return;
            root.forceActiveFocus();
            root.isDragging = true;
            root.dragPreview = root.value;
            root._lastStepValue = root.value;
            root.dragStarted();
            updateVal(mouse.x, mouse.y);
        }

        onPositionChanged: mouse => {
            if (pressed && root.enabled) {
                updateVal(mouse.x, mouse.y);
            }
        }

        onReleased: {
            if (!root.enabled) return;
            root.isDragging = false;
            root.dragFinished();
            root.triggered();
            handle.flashOpacity = 0.35;
            handleFlashAnim.start();
        }

        onDoubleClicked: {
            if (!root.enabled) return;
            root.setValue(root.defaultValue, false);
            root.dragFinished();
        }

        onWheel: wheel => {
            if (!root.enabled) return;
            wheelAccumulator += wheel.angleDelta.y;
            const threshold = 120;
            while (wheelAccumulator >= threshold) {
                root.nudge(1);
                wheelAccumulator -= threshold;
            }
            while (wheelAccumulator <= -threshold) {
                root.nudge(-1);
                wheelAccumulator += threshold;
            }
        }

        function updateVal(mx, my) {
            let pct = root.vertical
                ? Math.max(0.0, Math.min(1.0, (height - my) / height))
                : Math.max(0.0, Math.min(1.0, mx / width));
            let raw = root.from + pct * (root.to - root.from);
            let newVal = root.clampVal(root.snapVal(raw));

            let changed = (root.stepSize > 0 && newVal !== root._lastStepValue);
            if (changed) {
                root._lastStepValue = newVal;
            }

            root.dragPreview = newVal;
            root.moved(newVal);

            if (changed) {
                root.playTickThrottled(0.5);
            }
        }
    }
}
