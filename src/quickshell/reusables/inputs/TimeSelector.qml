import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: root
    implicitWidth: mainRow.implicitWidth + root.horizontalPadding * 2
    implicitHeight: mainRow.implicitHeight + root.verticalPadding * 2

    property int valueMs: 0
    property int _internalValueMs: valueMs
    property int activeSegment: 1
    property bool isActive: false
    property bool isWidgetVisible: true
    property bool showSeconds: true
    property bool isEditing: hoursSeg.isEditing || minsSeg.isEditing || secsSeg.isEditing

    property string iconFont: "Iosevka Nerd Font"
    property color accentColor: "#cba6f7"
    property color textColor: "#cdd6f4"
    property color subTextColor: "#a6adc8"
    property color baseColor: "#313244"
    property color borderColor: root.alpha(root.subTextColor, 0.15)
    property color activeTextColor: "#11111b"
    property real scaleMultiplier: 1.0

    property real cornerRadius: root.s(14)
    property real horizontalPadding: root.s(12)
    property real verticalPadding: root.s(8)
    property int fontPixelSize: root.s(24)
    property int iconFontSize: root.s(14)

    property string clickSound: "reusables/timeselector/click.wav"
    property string switchSound: "reusables/timeselector/switch.wav"
    property string tickSound: "reusables/timeselector/tick.wav"

    signal valueChanged(int newMs)
    signal segmentChanged(int segment)

    onValueMsChanged: {
        if (!debounceTimer.running) {
            _internalValueMs = valueMs;
        }
    }

    Timer {
        id: debounceTimer
        interval: 300
        onTriggered: {
            root.valueChanged(root._internalValueMs)
        }
    }

    function s(val) { return Math.round(val * root.scaleMultiplier); }
    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    function setSegmentValue(seg, newVal) {
        let h = Math.floor(root._internalValueMs / 3600000);
        let m = Math.floor((root._internalValueMs % 3600000) / 60000);
        let sec = root.showSeconds ? Math.floor((root._internalValueMs % 60000) / 1000) : 0;

        if (seg === 0) {
            h = Math.max(0, Math.min(99, newVal));
        } else if (seg === 1) {
            m = Math.max(0, newVal > 59 ? 60 : newVal);
        } else if (seg === 2 && root.showSeconds) {
            sec = Math.max(0, newVal > 59 ? 60 : newVal);
        }

        let total = (h * 3600 + m * 60 + sec) * 1000;
        root._internalValueMs = total;
        debounceTimer.restart();
    }

    function adjustSegment(dir) {
        let maxSeg = root.showSeconds ? 2 : 1;
        if (root.activeSegment > maxSeg) root.activeSegment = maxSeg;

        let h = Math.floor(root._internalValueMs / 3600000);
        let m = Math.floor((root._internalValueMs % 3600000) / 60000);
        let sec = root.showSeconds ? Math.floor((root._internalValueMs % 60000) / 1000) : 0;

        if (root.activeSegment === 0) {
            h = Math.max(0, Math.min(99, h + dir));
        } else if (root.activeSegment === 1) {
            m += dir;
            if (m > 59) { m = 0; h++; }
            else if (m < 0) { if (h > 0) { m = 59; h--; } else { m = 0; } }
        } else if (root.activeSegment === 2 && root.showSeconds) {
            sec += dir;
            if (sec > 59) { 
                sec = 0; m++; 
                if (m > 59) { m = 0; h++; } 
            } else if (sec < 0) { 
                if (m > 0) { sec = 59; m--; } 
                else if (h > 0) { sec = 59; m = 59; h--; } 
                else { sec = 0; }
            }
        }

        let total = (h * 3600 + m * 60 + sec) * 1000;
        root._internalValueMs = total;
        debounceTimer.restart();
    }

    function pulseActiveSegment() {
        if (root.activeSegment === 0) {
            hoursSeg.pulse();
        } else if (root.activeSegment === 1) {
            minsSeg.pulse();
        } else if (root.activeSegment === 2 && root.showSeconds) {
            secsSeg.pulse();
        }
    }

    Shortcut { enabled: root.enabled && root.isActive && !root.isEditing; sequence: "Left"; onActivated: { root.activeSegment = Math.max(0, root.activeSegment - 1); root.segmentChanged(root.activeSegment); root.pulseActiveSegment(); if (typeof Sounds !== "undefined") Sounds.playSfx(root.switchSound); } }
    Shortcut { enabled: root.enabled && root.isActive && !root.isEditing; sequence: "Right"; onActivated: { let maxSeg = root.showSeconds ? 2 : 1; root.activeSegment = Math.min(maxSeg, root.activeSegment + 1); root.segmentChanged(root.activeSegment); root.pulseActiveSegment(); if (typeof Sounds !== "undefined") Sounds.playSfx(root.switchSound); } }
    Shortcut { enabled: root.enabled && root.isActive && !root.isEditing; sequence: "Up"; onActivated: { root.adjustSegment(1); root.pulseActiveSegment(); if (typeof Sounds !== "undefined") Sounds.playSfx(root.tickSound); } }
    Shortcut { enabled: root.enabled && root.isActive && !root.isEditing; sequence: "Down"; onActivated: { root.adjustSegment(-1); root.pulseActiveSegment(); if (typeof Sounds !== "undefined") Sounds.playSfx(root.tickSound); } }

    component TimerSegment : Item {
        id: segRoot
        property int value: 0
        property int segmentIndex: 0
        property bool isSelected: false
        property bool isEditing: false

        implicitWidth: root.s(44)
        implicitHeight: root.s(44)

        signal segmentClicked()
        signal editFinished(int newVal)

        property real flashOpacity: 0.0
        property real popScale: 1.0
        property bool isHovered: hoverMa.containsMouse

        function pulse() {
            segRoot.popScale = 1.0;
            segPopAnim.restart();
            segRoot.flashOpacity = 0.2;
            segFlashAnim.restart();
        }

        MouseArea {
            id: hoverMa
            anchors.fill: parent
            hoverEnabled: root.enabled
            acceptedButtons: Qt.NoButton
        }

        scale: (!root.enabled ? 1.0 : (segmentMa.pressed && !isEditing ? 0.94 : (isHovered && !isEditing ? 1.04 : 1.0))) * popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: segPopAnim
            NumberAnimation { target: segRoot; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: segRoot; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.s(8)
            color: "#ffffff"
            opacity: flashOpacity
            visible: !pillGlass.active
            PropertyAnimation on opacity { id: segFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
        }

        Text {
            id: valText
            anchors.centerIn: parent
            text: segRoot.value.toString().padStart(2, '0')
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: root.fontPixelSize
            color: (isSelected && !pillGlass.active) ? root.activeTextColor : root.textColor
            visible: !isEditing
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        TextInput {
            id: valInput
            anchors.centerIn: parent
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: root.fontPixelSize
            color: (isSelected && !pillGlass.active) ? root.activeTextColor : root.accentColor
            visible: isEditing
            maximumLength: 2
            validator: RegularExpressionValidator { regularExpression: /^[0-9]{1,2}$/ }
            selectByMouse: false
            selectionColor: "transparent"
            selectedTextColor: (isSelected && !pillGlass.active) ? root.activeTextColor : root.accentColor
            horizontalAlignment: TextInput.AlignHCenter

            function commitValue() {
                if (isEditing) {
                    isEditing = false;
                    let parsed = parseInt(text);
                    if (isNaN(parsed)) parsed = 0;
                    editFinished(parsed);
                }
            }

            Keys.onReturnPressed: commitValue()
            Keys.onEnterPressed: commitValue()
            onEditingFinished: commitValue()
            onActiveFocusChanged: {
                if (!activeFocus && isEditing) {
                    commitValue();
                }
            }
        }

        MouseArea {
            id: segmentMa
            anchors.fill: parent
            hoverEnabled: root.enabled
            enabled: root.enabled
            cursorShape: isEditing ? Qt.IBeamCursor : (root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor)
            
            property real wheelAccumulator: 0

            onClicked: {
                if (!root.enabled) return;
                segRoot.segmentClicked();
                segRoot.pulse();
                if (typeof Sounds !== "undefined") Sounds.playSfx(root.clickSound);
            }

            onDoubleClicked: {
                if (!root.enabled) return;
                segRoot.segmentClicked();
                segRoot.isEditing = true;
                valInput.text = segRoot.value.toString().padStart(2, '0');
                valInput.forceActiveFocus();
                valInput.deselect();
            }

            onWheel: wheel => {
                if (!root.enabled) return;
                wheelAccumulator += wheel.angleDelta.y;
                const threshold = 120;
                while (wheelAccumulator >= threshold) {
                    root.activeSegment = segRoot.segmentIndex;
                    root.segmentChanged(segRoot.segmentIndex);
                    root.adjustSegment(1);
                    segRoot.pulse();
                    if (typeof Sounds !== "undefined") Sounds.playSfx(root.tickSound);
                    wheelAccumulator -= threshold;
                }
                while (wheelAccumulator <= -threshold) {
                    root.activeSegment = segRoot.segmentIndex;
                    root.segmentChanged(segRoot.segmentIndex);
                    root.adjustSegment(-1);
                    segRoot.pulse();
                    if (typeof Sounds !== "undefined") Sounds.playSfx(root.tickSound);
                    wheelAccumulator += threshold;
                }
            }
        }
    }

    Rectangle {
        id: bgShape
        anchors.fill: parent
        radius: root.cornerRadius
        color: glass.active ? "transparent" : root.baseColor
        border.color: root.borderColor
        border.width: 1
        clip: true
        opacity: root.enabled ? 1.0 : 0.5
        
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        GlassFill {
            id: glass
            anchors.fill: parent
            radius: parent.radius
            tintColor: root.baseColor
            tintAmount: 0.22
            Behavior on tintAmount { NumberAnimation { duration: 180 } }
        }

        Rectangle {
            id: activePill
            property var activeSegItem: root.activeSegment === 0 ? hoursSeg : (root.activeSegment === 1 ? minsSeg : secsSeg)
            readonly property real targetX: mainRow.x + activeSegItem.x
            readonly property real targetWidth: activeSegItem.width
            readonly property bool isMoving: Math.abs(x - targetX) > 0.5 || Math.abs(width - targetWidth) > 0.5
            property real lift: (pillGlass.active && isMoving) ? 1.0 : 0.0
            Behavior on lift { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            scale: 1.0 + 0.12 * lift
            width: targetWidth
            height: activeSegItem.height
            x: targetX
            y: mainRow.y + activeSegItem.y
            radius: root.s(8)
            z: pillGlass.active ? 2 : 0
            color: pillGlass.active ? "transparent" : root.accentColor

            GlassFill {
                id: pillGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: root.accentColor
                tintAmount: 0.4
                shadow: 1
                press: 0.35 + 0.65 * activePill.lift
                pulse: Math.min(1, activePill.activeSegItem.flashOpacity * 2.5)
                Behavior on tintAmount { NumberAnimation { duration: 180 } }
            }

            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Row {
            id: mainRow
            anchors.centerIn: parent
            spacing: root.s(8)

            TimerSegment {
                id: hoursSeg
                segmentIndex: 0
                value: Math.floor(root._internalValueMs / 3600000)
                isSelected: root.activeSegment === 0
                onSegmentClicked: { root.activeSegment = 0; root.segmentChanged(0); }
                onEditFinished: newVal => root.setSegmentValue(0, newVal)
            }

            Text { 
                text: ":"
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: root.fontPixelSize
                color: root.alpha(root.subTextColor, 0.4)
                anchors.verticalCenter: parent.verticalCenter 
            }

            TimerSegment {
                id: minsSeg
                segmentIndex: 1
                value: Math.floor((root._internalValueMs % 3600000) / 60000)
                isSelected: root.activeSegment === 1
                onSegmentClicked: { root.activeSegment = 1; root.segmentChanged(1); }
                onEditFinished: newVal => root.setSegmentValue(1, newVal)
            }

            Text { 
                text: ":"
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.pixelSize: root.fontPixelSize
                color: root.alpha(root.subTextColor, 0.4)
                anchors.verticalCenter: parent.verticalCenter 
                visible: root.showSeconds
            }

            TimerSegment {
                id: secsSeg
                segmentIndex: 2
                visible: root.showSeconds
                value: Math.floor((root._internalValueMs % 60000) / 1000)
                isSelected: root.activeSegment === 2 && root.showSeconds
                onSegmentClicked: { root.activeSegment = 2; root.segmentChanged(2); }
                onEditFinished: newVal => root.setSegmentValue(2, newVal)
            }
        }
    }
}
