import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../"
import "../"

Item {
    id: root

    activeFocusOnTab: root.enabled
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left) { I18n.rtl ? root.stepUp() : root.stepDown(); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { I18n.rtl ? root.stepDown() : root.stepUp(); event.accepted = true; }
        else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.startEditing(); event.accepted = true; }
    }
    implicitWidth: 160
    implicitHeight: 32

    property real value: 0.0
    property real from: 0.0
    property real to: 100.0
    property real stepSize: 1.0
    property int decimals: 0

    property string prefix: ""
    property string suffix: ""
    property string specialZeroText: ""

    property color baseColor: ThemeBackend.surface0
    property color accentColor: ThemeBackend.accent
    property color buttonColor: ThemeBackend.surface1
    property color buttonTextColor: ThemeBackend.text
    property color textColor: ThemeBackend.text
    property color subTextColor: ThemeBackend.subtext0
    property color borderColor: ThemeBackend.surface1
    property color activeTextColor: ThemeBackend.crust
    property color errorColor: ThemeBackend.red

    property int cornerRadius: 10
    property int horizontalPadding: 4
    property int verticalPadding: 4
    property int buttonSize: root.height - (root.verticalPadding * 2)
    property int buttonCornerRadius: Math.max(2, root.cornerRadius - 2)

    property string fontFamily: ThemeBackend.fontFamily
    property int fontPixelSize: 12
    property string iconFont: ThemeBackend.iconFont
    property int iconFontSize: 14
    property string leftIcon: "󰅁"
    property string rightIcon: "󰅂"

    property int horizontalAlignment: TextInput.AlignHCenter
    property int charSlotWidth: -1
    property int charSpacing: 1
    property alias symbolSpacing: root.charSpacing
    readonly property real charSlotStep: (root.charSlotWidth > 0 ? root.charSlotWidth : globalCharMetrics.width) + root.charSpacing
    property real scrollOffset: 0

    property bool enabled: true
    property bool action_highlight: false
    property bool isEditing: false
    property bool isHoveredOrHighlighted: (mainHover.hovered || root.action_highlight) && root.enabled

    property real focusPop: 1.0
    property real valueDrop: 0.0
    property int valueDir: 0
    property real shownValue: 0.0

    Component.onCompleted: shownValue = value

    onValueChanged: {
        if (glass.active && !root.isEditing) {
            root.valueDir = root.value >= root.shownValue ? 1 : -1;
            valueDropAnim.restart();
        }
        root.shownValue = root.value;
    }

    property int holdDirection: 0
    property bool holdTriggered: false
    property int holdInitialDelay: 400
    property int holdStartInterval: 130
    property int holdMinInterval: 30

    signal triggered()
    signal clicked()

    function copyToClipboard(str) {
        if (!str || str.length === 0) return;
        copyProc.running = false;
        copyProc.command = ["wl-copy", "--", str];
        copyProc.running = true;
    }

    function clampVal(v) {
        return Math.max(root.from, Math.min(root.to, v));
    }

    function formatValue(v) {
        if (root.specialZeroText !== "" && Math.abs(v) < 0.00001) {
            return root.specialZeroText;
        }
        let fixed = root.decimals > 0 ? v.toFixed(root.decimals) : Math.round(v).toString();
        return root.prefix + fixed + root.suffix;
    }

    function setValue(v) {
        if (!root.enabled) return;
        let clamped = clampVal(v);
        if (root.decimals === 0) {
            clamped = Math.round(clamped);
        } else {
            clamped = parseFloat(clamped.toFixed(root.decimals));
        }

        if (clamped === root.value && (v < root.from || v > root.to)) {
            triggerShake();
            return;
        }

        if (clamped !== root.value) {
            root.value = clamped;
        }
    }

    function stepUp() {
        if (!root.enabled) return;
        if (root.value >= root.to) {
            triggerShake();
            return;
        }
        setValue(root.value + root.stepSize);
        root.triggered();
    }

    function stepDown() {
        if (!root.enabled) return;
        if (root.value <= root.from) {
            triggerShake();
            return;
        }
        setValue(root.value - root.stepSize);
        root.triggered();
    }

    function triggerShake() {
        shakeAnim.restart();
    }

    function beginHold(direction) {
        root.holdDirection = direction;
        root.holdTriggered = false;
        holdDelay.restart();
    }

    function endHold() {
        holdDelay.stop();
        holdRepeat.stop();
        root.holdDirection = 0;
    }

    function holdStep() {
        if (root.isEditing) root.commitValue();
        if (root.holdDirection > 0) {
            if (root.value >= root.to) { root.endHold(); return; }
            root.stepUp();
        } else if (root.holdDirection < 0) {
            if (root.value <= root.from) { root.endHold(); return; }
            root.stepDown();
        }
    }

    function updateScroll() {
        let totalW = charRow.contentWidth;
        let visibleW = centerField.width;

        if (visibleW <= 0) {
            return;
        }

        if (totalW <= visibleW) {
            switch (root.horizontalAlignment) {
                case TextInput.AlignHCenter:
                    root.scrollOffset = (visibleW - totalW) / 2;
                    break;
                case TextInput.AlignRight:
                    root.scrollOffset = visibleW - totalW;
                    break;
                default:
                    root.scrollOffset = 0;
                    break;
            }
            return;
        }

        let curX = innerInput.cursorPosition * root.charSlotStep;
        let minOffset = visibleW - totalW;
        let maxOffset = 0;
        let margin = 4;
        let curScreenX = curX + root.scrollOffset;

        if (curScreenX < margin) {
            root.scrollOffset = Math.min(maxOffset, Math.max(minOffset, margin - curX));
        } else if (curScreenX > visibleW - margin - 2) {
            root.scrollOffset = Math.min(maxOffset, Math.max(minOffset, visibleW - margin - 2 - curX));
        } else {
            root.scrollOffset = Math.min(maxOffset, Math.max(minOffset, root.scrollOffset));
        }
    }

    function syncModel() {
        let str = innerInput.text;
        let minLen = Math.min(str.length, charModel.count);
        let matchLen = 0;

        while (matchLen < minLen && str[matchLen] === charModel.get(matchLen).char) {
            matchLen++;
        }

        while (charModel.count > matchLen) {
            charModel.remove(charModel.count - 1);
        }

        for (let i = matchLen; i < str.length; i++) {
            charModel.append({ char: str[i] });
        }

        updateScroll();
    }

    function startEditing() {
        root.isEditing = true;
        innerInput.text = root.value.toString();
        syncModel();
        innerInput.forceActiveFocus();
        innerInput.selectAll();
        focusPopAnim.restart();
    }

    function commitValue() {
        if (!root.isEditing) return;
        root.isEditing = false;
        innerInput.focus = false;
        let parsed = parseFloat(innerInput.text);
        if (isNaN(parsed)) {
            triggerShake();
        } else {
            root.setValue(parsed);
        }
        charModel.clear();
        root.triggered();
    }

    function cancelEditing() {
        root.isEditing = false;
        innerInput.focus = false;
        charModel.clear();
    }

    Process {
        id: copyProc
    }

    Timer {
        id: holdDelay
        interval: root.holdInitialDelay
        repeat: false
        onTriggered: {
            root.holdTriggered = true;
            holdRepeat.interval = root.holdStartInterval;
            root.holdStep();
            if (root.holdDirection !== 0) holdRepeat.restart();
        }
    }

    Timer {
        id: holdRepeat
        repeat: true
        onTriggered: {
            root.holdStep();
            interval = Math.max(root.holdMinInterval, Math.round(interval * 0.88));
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeT; property: "x"; from: 0; to: -5; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; from: -5; to: 5; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; from: 5; to: -3; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; from: -3; to: 3; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; from: 3; to: 0; duration: 45 }
    }

    SequentialAnimation {
        id: valueDropAnim
        NumberAnimation { target: root; property: "valueDrop"; to: 1.0; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "valueDrop"; to: 0.0; duration: 460; easing.type: Easing.OutQuint }
    }

    SequentialAnimation {
        id: focusPopAnim
        NumberAnimation { target: root; property: "focusPop"; to: 1.03; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "focusPop"; to: 1.0; duration: 380; easing.type: Easing.OutQuint }
    }

    TextMetrics {
        id: globalCharMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        text: "0"
    }

    ListModel {
        id: charModel
    }

    HoverHandler {
        id: mainHover
        enabled: root.enabled
    }

    Rectangle {
        id: bgShape
        anchors.fill: parent
        radius: root.cornerRadius
        clip: true
        color: glass.active ? "transparent" : (root.isHoveredOrHighlighted ? Qt.darker(root.baseColor, 1.14) : root.baseColor)
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlassFill {
            id: glass
            anchors.fill: parent
            radius: parent.radius
            tintColor: root.baseColor
            press: root.isEditing ? 0.55 : (root.isHoveredOrHighlighted ? 0.2 : 0)
            Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            tintAmount: (root.isEditing ? 0.38 : (root.isHoveredOrHighlighted ? 0.3 : 0.22))
            Behavior on tintAmount { NumberAnimation { duration: 150 } }
        }

        scale: (root.isEditing ? 1.02 : 1.0) * root.focusPop
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
        transform: Translate { id: shakeT; x: 0 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
        spacing: 4

        IconButton {
            id: decBtn
            size: root.buttonSize
            cornerRadius: root.buttonCornerRadius
            buttonIcon: root.leftIcon
            iconFontSize: root.iconFontSize
            accentColor: root.buttonColor
            textColor: root.buttonTextColor
            enabled: root.enabled && root.value > root.from
            Layout.alignment: Qt.AlignVCenter

            onPressedChanged: pressed ? root.beginHold(-1) : root.endHold()

            onClicked: {
                if (root.holdTriggered) {
                    root.holdTriggered = false;
                    return;
                }
                if (root.isEditing) {
                    root.commitValue();
                }
                root.stepDown();
                root.clicked();
            }
        }

        Item {
            id: centerField
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            onWidthChanged: root.updateScroll()

            Rectangle {
                anchors.fill: parent
                radius: Math.max(2, root.buttonCornerRadius - 2)
                color: root.isEditing ? Qt.rgba(255, 255, 255, 0.05) : (centerMa.containsMouse ? Qt.rgba(255, 255, 255, 0.03) : "transparent")
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item {
                id: valueLens
                visible: glass.active && !root.isEditing && root.valueDrop > 0.001
                width: Math.min(parent.width, displayLabel.width + 18) * (0.82 + 0.18 * root.valueDrop)
                height: parent.height * (0.78 + 0.22 * root.valueDrop)
                x: (parent.width - width) / 2 + root.valueDir * 7 * (1 - root.valueDrop)
                y: (parent.height - height) / 2
                opacity: Math.min(1, root.valueDrop * 1.6)

                GlassFill {
                    anchors.fill: parent
                    radius: height / 2
                    tintColor: root.textColor
                    tintAmount: 0.14
                    tintStrength: 1.0
                    press: 0.3 + 0.7 * root.valueDrop
                    pulse: root.valueDrop
                }
            }

            Text {
                id: displayLabel
                anchors.centerIn: parent
                scale: glass.active ? 1.0 + 0.1 * root.valueDrop : 1.0
                visible: !root.isEditing
                text: root.formatValue(root.value)
                font.family: root.fontFamily
                font.weight: Font.Bold
                font.pixelSize: root.fontPixelSize
                color: root.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - 4)

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item {
                id: editArea
                anchors.fill: parent
                visible: root.isEditing

                Rectangle {
                    id: selectionHighlight
                    readonly property int selMin: Math.min(innerInput.selectionStart, innerInput.selectionEnd)
                    readonly property int selMax: Math.max(innerInput.selectionStart, innerInput.selectionEnd)
                    readonly property bool hasSelection: selMax > selMin

                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.min(parent.height - 4, root.fontPixelSize * 1.7)
                    radius: 4
                    color: root.accentColor
                    opacity: hasSelection ? 0.28 : 0.0

                    x: root.scrollOffset + (selMin * root.charSlotStep) - 2
                    width: hasSelection ? ((selMax - selMin) * root.charSlotStep - root.charSpacing + 4) : 0

                    Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                    Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }

                ListView {
                    id: charRow
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    orientation: ListView.Horizontal
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: root.charSpacing
                    width: contentWidth
                    x: root.scrollOffset
                    model: charModel

                    onContentWidthChanged: root.updateScroll()

                    property int entranceDuration: 420
                    property real entranceOvershoot: 3.2
                    property int exitDuration: 160

                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "scale"; from: 0.3; to: 1.0; duration: charRow.entranceDuration; easing.type: Easing.OutBack; easing.overshoot: charRow.entranceOvershoot }
                            NumberAnimation { property: "y"; from: 10; to: 0; duration: charRow.entranceDuration; easing.type: Easing.OutBack; easing.overshoot: charRow.entranceOvershoot * 0.8 }
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "scale"; to: 0.3; duration: charRow.exitDuration; easing.type: Easing.InBack }
                            NumberAnimation { property: "y"; to: -8; duration: charRow.exitDuration; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; to: 0; duration: charRow.exitDuration * 0.9; easing.type: Easing.InCubic }
                        }
                    }

                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }

                    delegate: Item {
                        id: slot
                        width: root.charSlotWidth > 0 ? root.charSlotWidth : globalCharMetrics.width
                        height: charRow.height
                        transformOrigin: Item.Center

                        Text {
                            anchors.centerIn: parent
                            text: model.char
                            color: root.accentColor
                            font.family: root.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: root.fontPixelSize
                        }
                    }
                }

                Rectangle {
                    id: caretRect
                    width: 2
                    height: root.fontPixelSize * 1.2
                    color: root.accentColor
                    visible: root.isEditing
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.scrollOffset + (innerInput.cursorPosition * root.charSlotStep)

                    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    SequentialAnimation on opacity {
                        running: root.isEditing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 100; easing.type: Easing.InQuad }
                        PauseAnimation { duration: 400 }
                        NumberAnimation { to: 1; duration: 100; easing.type: Easing.OutQuad }
                        PauseAnimation { duration: 400 }
                    }
                }

                TextInput {
                    id: innerInput
                    anchors.fill: parent
                    opacity: 0
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    selectByMouse: true
                    mouseSelectionMode: TextInput.SelectCharacters
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: root.fontPixelSize
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    validator: RegularExpressionValidator {
                        regularExpression: root.decimals > 0 ? /^-?[0-9]*\.?[0-9]*$/ : /^-?[0-9]*$/
                    }

                    onCursorPositionChanged: root.updateScroll()
                    onSelectionStartChanged: root.updateScroll()
                    onSelectionEndChanged: root.updateScroll()

                    Keys.onPressed: function(event) {
                        if (event.matches(StandardKey.Copy) || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C)) {
                            if (innerInput.selectedText.length > 0) {
                                root.copyToClipboard(innerInput.selectedText);
                                event.accepted = true;
                            }
                        }
                    }

                    Keys.onReturnPressed: root.commitValue()
                    Keys.onEnterPressed: root.commitValue()
                    Keys.onEscapePressed: root.cancelEditing()
                    onEditingFinished: root.commitValue()
                    onActiveFocusChanged: {
                        if (!activeFocus && root.isEditing) {
                            root.commitValue();
                        }
                    }

                    onTextEdited: {
                        syncModel();
                    }
                }

                TapHandler {
                    enabled: root.isEditing
                    onTapped: {
                        root.commitValue();
                    }
                }
            }

            MouseArea {
                id: centerMa
                anchors.fill: parent
                hoverEnabled: root.enabled
                enabled: root.enabled && !root.isEditing
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                property real wheelAccumulator: 0

                onDoubleClicked: {
                    if (!root.enabled) return;
                    root.startEditing();
                }

                onClicked: {
                    if (!root.enabled) return;
                    root.clicked();
                }

                onWheel: wheel => {
                    if (!root.enabled) return;
                    wheelAccumulator += wheel.angleDelta.y;
                    const threshold = 120;
                    while (wheelAccumulator >= threshold) {
                        root.stepUp();
                        wheelAccumulator -= threshold;
                    }
                    while (wheelAccumulator <= -threshold) {
                        root.stepDown();
                        wheelAccumulator += threshold;
                    }
                }
            }
        }

        IconButton {
            id: incBtn
            size: root.buttonSize
            cornerRadius: root.buttonCornerRadius
            buttonIcon: root.rightIcon
            iconFontSize: root.iconFontSize
            accentColor: root.buttonColor
            textColor: root.buttonTextColor
            enabled: root.enabled && root.value < root.to
            Layout.alignment: Qt.AlignVCenter

            onPressedChanged: pressed ? root.beginHold(1) : root.endHold()

            onClicked: {
                if (root.holdTriggered) {
                    root.holdTriggered = false;
                    return;
                }
                if (root.isEditing) {
                    root.commitValue();
                }
                root.stepUp();
                root.clicked();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: (typeof root.cornerRadius === "number" ? root.cornerRadius : 10) + 2
        color: "transparent"
        visible: root.activeFocus
        z: 100
    }
}
