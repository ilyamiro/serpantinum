import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import "../"

FocusScope {
    id: root
    implicitWidth: 240
    implicitHeight: 36

    property color baseColor: ThemeBackend.surface0
    property color hoverColor: root.baseColor
    property color focusColor: root.hoverColor
    property color activeColor: root.focusColor
    property color accentColor: ThemeBackend.blue
    property color textColor: ThemeBackend.text
    property color subTextColor: ThemeBackend.subtext0
    property color errorColor: ThemeBackend.red
    property color successColor: ThemeBackend.green ?? "#a6e3a1"
    property color busyColor: ThemeBackend.peach
    property color lockBoxColor: ThemeBackend.surface1 ?? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)

    property real cornerRadius: ThemeBackend.borderRadius ?? 12
    property real horizontalPadding: 8
    property real verticalPadding: 4

    property string fontFamily: ThemeBackend.fontFamily
    property int fontPixelSize: 12

    property string text: ""
    property string placeholderText: ""
    property int maximumLength: -1
    property var validator: null

    Settings {
        id: persistentSettings
        category: "PasswordInput"
        property bool isRevealed: false
    }

    property alias isRevealed: persistentSettings.isRevealed
    property real revealProgress: isRevealed ? 1.0 : 0.0
    Behavior on revealProgress {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.25
        }
    }

    property int horizontalAlignment: TextInput.AlignLeft
    property int charSlotWidth: -1
    property int charSpacing: 2
    property alias symbolSpacing: root.charSpacing
    readonly property real dotSize: Math.round(root.implicitHeight * 0.44)
    readonly property real charSlotStep: (root.charSlotWidth > 0 ? root.charSlotWidth : (root.revealProgress > 0.5 ? globalCharMetrics.width : root.dotSize)) + root.charSpacing
    property real scrollOffset: 0

    property bool enabled: true
    property bool hasError: false
    property bool hasSuccess: false
    property bool isBusy: false
    readonly property bool hasFocus: innerInput.activeFocus || root.activeFocus
    property bool action_highlight: false
    property bool isHoveredOrHighlighted: mainHover.hovered || root.action_highlight
    property bool isWidgetVisible: true
    property bool showCaret: true

    property bool showLockIcon: true
    property bool showSubmitButton: true
    property int lockButtonSize: Math.max(20, root.height - 8)

    readonly property color activeSignalColor: root.hasError ? root.errorColor : (root.hasSuccess ? root.successColor : (root.isBusy ? root.busyColor : root.accentColor))
    property color caretColor: root.activeSignalColor

    property string keySound: "reusables/input/type.wav"
    property string errorSound: "reusables/inputfield/error.wav"

    property real focusPop: 1.0

    signal textEdited(string newText)
    signal accepted(string finalText)
    signal cleared()
    signal clicked()
    signal triggered()

    function revealAll() {
        root.isRevealed = true;
    }

    function hideAll() {
        root.isRevealed = false;
    }

    function toggleReveal() {
        root.isRevealed = !root.isRevealed;
    }

    function clear() {
        if (innerInput.text !== "" && typeof Sounds !== "undefined") {
            Sounds.playSfx(root.keySound);
        }
        innerInput.text = "";
        root.text = "";
        charModel.clear();
        root.scrollOffset = 0;
        root.hasSuccess = false;
        root.hasError = false;
        root.cleared();
    }

    function forceInputFocus() {
        innerInput.forceActiveFocus();
    }

    function insertText(newStr) {
        if (!root.enabled || root.isBusy) return;
        let pos = innerInput.cursorPosition;
        let cur = innerInput.text;
        let updated = cur.slice(0, pos) + newStr + cur.slice(pos);
        if (root.maximumLength > 0 && updated.length > root.maximumLength) {
            updated = updated.slice(0, root.maximumLength);
        }
        innerInput.text = updated;
        innerInput.cursorPosition = Math.min(updated.length, pos + newStr.length);
        root.text = updated;
        syncModel();
        if (typeof Sounds !== "undefined") {
            Sounds.playSfx(root.keySound);
        }
        root.textEdited(updated);
    }

    function triggerShake() {
        shakeAnim.restart();
        if (typeof Sounds !== "undefined") {
            Sounds.playSfx(root.errorSound);
        }
    }

    function markSuccess() {
        root.hasSuccess = true;
        root.hasError = false;
    }

    function markError() {
        root.hasSuccess = false;
        root.hasError = true;
        root.triggerShake();
    }

    function resetVerification() {
        root.hasSuccess = false;
        root.hasError = false;
    }

    function verify(validatorFn) {
        if (typeof validatorFn === "function") {
            var isValid = validatorFn(innerInput.text);
            if (isValid) {
                root.markSuccess();
            } else {
                root.markError();
            }
            return isValid;
        }
        return false;
    }

    function submit() {
        root.accepted(innerInput.text);
        root.triggered();
    }

    function computeRowX(rowWidth, fieldWidth) {
        switch (root.horizontalAlignment) {
            case TextInput.AlignHCenter:
            case Qt.AlignHCenter:
                return (fieldWidth - rowWidth) / 2;
            case TextInput.AlignRight:
            case Qt.AlignRight:
                return fieldWidth - rowWidth;
            default:
                return 0;
        }
    }

    function updateScroll() {
        let totalW = charRow.contentWidth;
        let visibleW = fieldArea.width;

        if (visibleW <= 0) {
            return;
        }

        if (totalW <= visibleW) {
            switch (root.horizontalAlignment) {
                case TextInput.AlignHCenter:
                case Qt.AlignHCenter:
                    root.scrollOffset = (visibleW - totalW) / 2;
                    break;
                case TextInput.AlignRight:
                case Qt.AlignRight:
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

    onHorizontalAlignmentChanged: updateScroll()

    onRevealProgressChanged: {
        updateScroll();
        lockButton.requestPaint();
    }

    onIsRevealedChanged: {
        submitButton.triggerSpin();
    }

    onTextChanged: {
        if (innerInput.text !== root.text) {
            innerInput.text = root.text;
            syncModel();
        }
        root.hasSuccess = false;
        root.hasError = false;
    }

    onHasFocusChanged: {
        if (hasFocus) {
            focusPopAnim.restart();
        }
        lockButton.requestPaint();
    }

    onHasErrorChanged: lockButton.requestPaint()
    onHasSuccessChanged: lockButton.requestPaint()
    onIsBusyChanged: {
        if (!isBusy) {
            lockButton.busyRotation = 0;
            lockButton.spinBlur = 0;
        }
        lockButton.requestPaint();
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

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeT; property: "x"; from: 0; to: -6; duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; from: -6; to: 6; duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; from: 6; to: -4; duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; from: -4; to: 4; duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; from: 4; to: 0; duration: 50 }
    }

    SequentialAnimation {
        id: focusPopAnim
        NumberAnimation { target: root; property: "focusPop"; to: 1.02; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "focusPop"; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
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
        cursorShape: Qt.IBeamCursor
    }

    TapHandler {
        onTapped: {
            root.forceInputFocus();
            root.clicked();
        }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        scale: (root.hasError ? 1.02 : (root.isBusy ? 0.98 : 1.0)) * root.focusPop
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        transform: Translate { id: shakeT; x: 0 }

        Rectangle {
            id: bgShape
            anchors.fill: parent
            radius: root.cornerRadius
            clip: true
            opacity: root.enabled ? 1.0 : 0.5
            color: {
                if (root.hasFocus) return root.focusColor;
                if (innerInput.text.length > 0) return root.activeColor;
                if (root.isHoveredOrHighlighted) return root.hoverColor;
                return root.baseColor;
            }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        CanvasIconButton {
            id: lockButton
            visible: root.showLockIcon
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            size: root.lockButtonSize
            iconSize: Math.round(root.lockButtonSize * 0.72)
            cornerRadius: Math.max(4, root.cornerRadius - 4)

            property real busyRotation: 0.0
            property real spinBlur: 0.0

            onBusyRotationChanged: requestPaint()
            onSpinBlurChanged: requestPaint()

            SequentialAnimation {
                id: busySpinLoop
                running: root.isBusy
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: lockButton
                        property: "busyRotation"
                        from: 0
                        to: 360
                        duration: 540
                        easing.type: Easing.InOutCubic
                    }

                    SequentialAnimation {
                        NumberAnimation {
                            target: lockButton
                            property: "spinBlur"
                            from: 0.0
                            to: 1.0
                            duration: 220
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: lockButton
                            property: "spinBlur"
                            from: 1.0
                            to: 0.0
                            duration: 320
                            easing.type: Easing.InQuad
                        }
                    }
                }

                PauseAnimation {
                    duration: 480
                }
            }

            accentColor: root.hasError
                ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.16)
                : (root.hasSuccess
                    ? Qt.rgba(root.successColor.r, root.successColor.g, root.successColor.b, 0.16)
                    : (root.isBusy
                        ? Qt.rgba(root.busyColor.r, root.busyColor.g, root.busyColor.b, 0.16)
                        : root.lockBoxColor))

            textColor: root.hasError
                ? root.errorColor
                : (root.hasSuccess
                    ? root.successColor
                    : (root.isBusy
                        ? root.busyColor
                        : root.subTextColor))

            action_highlight: false

            paintCanvas: function(ctx, canvas) {
                var w = canvas.width;
                var h = canvas.height;
                var color = lockButton.textColor;

                ctx.clearRect(0, 0, w, h);

                var bodyW = Math.round(w * 0.52);
                var bodyH = Math.round(bodyW * 0.76);
                var shackleStroke = Math.max(1.8, bodyW * 0.14);
                var shackleOuterW = Math.round(bodyW * 0.62);
                var shackleRadius = (shackleOuterW - shackleStroke) / 2;
                var shackleH = Math.round(shackleRadius + (bodyH * 0.30));

                var shackleTop = Math.round((h - (shackleH + bodyH)) / 2);
                var bodyY = shackleTop + shackleH;
                var shackleTopY = shackleTop + (shackleStroke / 2);

                var centerX = Math.round(w / 2);
                var centerY = Math.round(h / 2);
                var bodyX = Math.round((w - bodyW) / 2);

                var prog = root.revealProgress;
                var pivotX = centerX - shackleRadius;
                var pivotY = bodyY + (shackleStroke / 2);
                var lift = Math.round((shackleH * 0.28) * prog);
                var swingAngle = -0.38 * prog;
                var rightLegBottom = bodyY + 1.0 - Math.round(shackleH * 0.32 * prog);

                function renderLockGraphic(rotAngle, alphaVal) {
                    ctx.save();
                    ctx.globalAlpha = alphaVal;

                    if (rotAngle !== 0) {
                        ctx.translate(centerX, centerY);
                        ctx.rotate(rotAngle * Math.PI / 180);
                        ctx.translate(-centerX, -centerY);
                    }

                    ctx.save();
                    ctx.strokeStyle = color;
                    ctx.lineWidth = shackleStroke;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";

                    ctx.translate(pivotX, pivotY);
                    ctx.translate(0, -lift);
                    ctx.rotate(swingAngle);
                    ctx.translate(-pivotX, -pivotY);

                    ctx.beginPath();
                    ctx.arc(centerX, shackleTopY + shackleRadius, shackleRadius, Math.PI, 0, false);
                    ctx.lineTo(centerX + shackleRadius, rightLegBottom);
                    ctx.moveTo(centerX - shackleRadius, shackleTopY + shackleRadius);
                    ctx.lineTo(centerX - shackleRadius, bodyY + 1.5 + lift);
                    ctx.stroke();
                    ctx.restore();

                    ctx.fillStyle = color;
                    var r = Math.max(2, Math.round(bodyW * 0.16));
                    ctx.beginPath();
                    ctx.moveTo(bodyX + r, bodyY);
                    ctx.lineTo(bodyX + bodyW - r, bodyY);
                    ctx.arcTo(bodyX + bodyW, bodyY, bodyX + bodyW, bodyY + r, r);
                    ctx.lineTo(bodyX + bodyW, bodyY + bodyH - r);
                    ctx.arcTo(bodyX + bodyW, bodyY + bodyH, bodyX + bodyW - r, bodyY + bodyH, r);
                    ctx.lineTo(bodyX + r, bodyY + bodyH);
                    ctx.arcTo(bodyX, bodyY + bodyH, bodyX, bodyY + bodyH - r, r);
                    ctx.lineTo(bodyX, bodyY + r);
                    ctx.arcTo(bodyX, bodyY, bodyX + r, bodyY, r);
                    ctx.closePath();
                    ctx.fill();

                    ctx.fillStyle = root.baseColor;
                    var keyholeR = Math.max(1.4, bodyH * 0.16);
                    var keyholeCenterY = bodyY + Math.round(bodyH * 0.42);
                    ctx.beginPath();
                    ctx.arc(centerX, keyholeCenterY, keyholeR, 0, Math.PI * 2);
                    ctx.fill();

                    var slotW = Math.max(1.4, keyholeR * 0.85);
                    var slotH = Math.round(bodyH * 0.28);
                    ctx.beginPath();
                    ctx.rect(centerX - (slotW / 2), keyholeCenterY, slotW, slotH);
                    ctx.fill();

                    ctx.restore();
                }

                if (root.isBusy && lockButton.spinBlur > 0.02) {
                    var blurPasses = 3;
                    for (var i = blurPasses; i >= 1; i--) {
                        var trailAngle = lockButton.busyRotation - (i * lockButton.spinBlur * 16);
                        var trailAlpha = (0.24 / i) * lockButton.spinBlur;
                        renderLockGraphic(trailAngle, trailAlpha);
                    }
                }

                renderLockGraphic(lockButton.busyRotation, 1.0);
            }

            onClicked: {
                root.forceInputFocus();
                root.toggleReveal();
            }
        }

        Item {
            id: submitButton
            visible: root.showSubmitButton
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size

            property int size: Math.max(20, root.height - 8)
            property int cornerRadius: Math.max(4, root.cornerRadius - 4)
            property real popScale: 1.0
            property real flashOpacity: 0.0
            property bool isHoveredOrHighlighted: (submitMa.containsMouse || root.action_highlight) && root.enabled && !root.isBusy
            property color currentAccent: root.hasSuccess
                ? root.successColor
                : (root.hasError
                    ? root.errorColor
                    : (root.isBusy ? root.busyColor : root.accentColor))

            function triggerSpin() {
                submitPopAnim.restart();
                submitButton.flashOpacity = 0.4;
                submitFlashAnim.restart();
                chevronSpinAnim.restart();
            }

            Rectangle {
                id: submitBtnShape
                anchors.fill: parent
                radius: submitButton.cornerRadius
                clip: true
                color: !root.enabled || root.isBusy
                    ? submitButton.currentAccent
                    : (submitMa.pressed
                        ? Qt.darker(submitButton.currentAccent, 1.12)
                        : (submitButton.isHoveredOrHighlighted
                            ? Qt.lighter(submitButton.currentAccent, 1.12)
                            : submitButton.currentAccent))
                opacity: root.enabled && !root.isBusy ? 1.0 : 0.5

                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                scale: (!root.enabled || root.isBusy ? 1.0 : (submitMa.pressed ? 1.08 : (submitButton.isHoveredOrHighlighted ? 1.04 : 1.0))) * submitButton.popScale
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                SequentialAnimation {
                    id: submitPopAnim
                    NumberAnimation { target: submitButton; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
                    NumberAnimation { target: submitButton; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
                }

                Item {
                    id: chevronWrapper
                    anchors.centerIn: parent
                    width: submitButton.size * 0.38
                    height: submitButton.size * 0.38
                    rotation: 180

                    property real armThickness: Math.max(1.5, submitButton.size * 0.048)
                    property real armLength: Math.max(5, submitButton.size * 0.19)
                    property real dotSize: armThickness

                    NumberAnimation {
                        id: chevronSpinAnim
                        target: chevronWrapper
                        property: "rotation"
                        from: 180
                        to: 540
                        duration: 400
                        easing.type: Easing.OutCubic
                    }

                    Item {
                        id: pivotNode
                        x: (chevronWrapper.width - (chevronWrapper.armLength * 0.766)) / 2
                        y: chevronWrapper.height / 2
                        width: 0
                        height: 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: chevronWrapper.dotSize
                            height: chevronWrapper.dotSize
                            radius: width / 2
                            color: root.baseColor
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        Rectangle {
                            x: 0
                            y: -chevronWrapper.armThickness / 2
                            width: chevronWrapper.armLength
                            height: chevronWrapper.armThickness
                            radius: height / 2
                            transformOrigin: Item.Left
                            rotation: 40
                            color: root.baseColor
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        Rectangle {
                            x: 0
                            y: -chevronWrapper.armThickness / 2
                            width: chevronWrapper.armLength
                            height: chevronWrapper.armThickness
                            radius: height / 2
                            transformOrigin: Item.Left
                            rotation: -40
                            color: root.baseColor
                            antialiasing: true
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: submitButton.cornerRadius
                    color: "#ffffff"
                    opacity: submitButton.flashOpacity
                    PropertyAnimation on opacity { id: submitFlashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
                }

                MouseArea {
                    id: submitMa
                    anchors.fill: parent
                    hoverEnabled: root.enabled && !root.isBusy
                    enabled: root.enabled && !root.isBusy
                    cursorShape: (root.enabled && !root.isBusy) ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: {
                        if (!root.enabled || root.isBusy) return;
                        submitButton.triggerSpin();
                        root.forceInputFocus();
                        root.submit();
                    }
                }
            }
        }

        Item {
            id: fieldArea
            anchors.left: root.showLockIcon ? lockButton.right : parent.left
            anchors.leftMargin: root.showLockIcon ? 6 : root.horizontalPadding
            anchors.right: root.showSubmitButton ? submitButton.left : parent.right
            anchors.rightMargin: root.showSubmitButton ? 6 : root.horizontalPadding
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: root.verticalPadding
            anchors.bottomMargin: root.verticalPadding
            clip: true
            onWidthChanged: root.updateScroll()

            Text {
                id: placeholderLabel
                text: root.placeholderText
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                color: root.subTextColor
                opacity: (innerInput.text.length === 0 && !root.hasFocus && charModel.count === 0) ? 0.45 : 0.0
                x: root.computeRowX(implicitWidth, fieldArea.width)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            Rectangle {
                id: selectionHighlight
                readonly property int selMin: Math.min(innerInput.selectionStart, innerInput.selectionEnd)
                readonly property int selMax: Math.max(innerInput.selectionStart, innerInput.selectionEnd)
                readonly property bool hasSelection: selMax > selMin

                anchors.verticalCenter: parent.verticalCenter
                height: Math.min(parent.height - 6, root.fontPixelSize * 1.6)
                radius: 4
                color: root.activeSignalColor
                opacity: hasSelection ? 0.28 : 0.0

                x: root.scrollOffset + (selMin * root.charSlotStep) - 2
                width: hasSelection ? ((selMax - selMin) * root.charSlotStep - root.charSpacing + 4) : 0

                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
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

                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "scale"
                            from: 0.60
                            to: 1.0
                            duration: 240
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.35
                        }
                        NumberAnimation {
                            property: "y"
                            from: 3.5
                            to: 0
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.25
                        }
                        NumberAnimation {
                            property: "rotation"
                            from: -9
                            to: 0
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "scale"
                            to: 0.0
                            duration: 130
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            property: "y"
                            to: 2
                            duration: 130
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            property: "rotation"
                            to: 6
                            duration: 130
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 100
                            easing.type: Easing.InQuad
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Item {
                    id: charSlot
                    required property int index
                    required property string char

                    property real baseWidth: root.charSlotWidth > 0
                        ? root.charSlotWidth
                        : (root.revealProgress > 0.5
                            ? globalCharMetrics.width
                            : root.dotSize)

                    width: baseWidth
                    height: charRow.height
                    transformOrigin: Item.Center

                    Rectangle {
                        id: charShape
                        anchors.centerIn: parent
                        width: root.dotSize
                        height: width
                        radius: Math.round(width * 0.24)

                        color: root.textColor
                        antialiasing: true

                        property real dotPop: 1.0

                        opacity: 1.0 - root.revealProgress
                        scale: (1.0 - root.revealProgress) * dotPop
                        rotation: root.revealProgress * -12

                        visible: opacity > 0.01

                        Component.onCompleted: {
                            dotPop = 0.82
                            dotPopAnim.restart()
                        }

                        SequentialAnimation {
                            id: dotPopAnim
                            NumberAnimation {
                                target: charShape
                                property: "dotPop"
                                to: 1.11
                                duration: 110
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.25
                            }
                            NumberAnimation {
                                target: charShape
                                property: "dotPop"
                                to: 1.0
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        id: charText
                        anchors.centerIn: parent
                        text: charSlot.char
                        color: root.textColor

                        font.family: root.fontFamily
                        font.pixelSize: root.fontPixelSize

                        opacity: root.revealProgress
                        scale: 0.88 + (0.12 * root.revealProgress)
                        rotation: (1.0 - root.revealProgress) * 12

                        visible: opacity > 0.01
                    }
                }
            }

            Rectangle {
                id: caretRect
                width: 2
                height: root.fontPixelSize * 1.3
                color: root.caretColor
                visible: root.showCaret && (root.hasFocus || root.action_highlight) && (root.isRevealed || root.revealProgress > 0.01)
                anchors.verticalCenter: parent.verticalCenter
                x: root.scrollOffset + (innerInput.cursorPosition * root.charSlotStep)

                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                SequentialAnimation on opacity {
                    running: root.showCaret && (root.hasFocus || root.action_highlight) && (root.isRevealed || root.revealProgress > 0.01) && root.isWidgetVisible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 120; easing.type: Easing.InQuad }
                    PauseAnimation { duration: 380 }
                    NumberAnimation { to: 1; duration: 120; easing.type: Easing.OutQuad }
                    PauseAnimation { duration: 380 }
                }
            }

            TextInput {
                id: innerInput
                anchors.fill: parent
                focus: true
                opacity: 0
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                selectByMouse: true
                mouseSelectionMode: TextInput.SelectCharacters
                horizontalAlignment: root.horizontalAlignment
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                enabled: root.enabled && !root.isBusy
                maximumLength: root.maximumLength > 0 ? root.maximumLength : 32767
                validator: root.validator

                onCursorPositionChanged: root.updateScroll()
                onSelectionStartChanged: root.updateScroll()
                onSelectionEndChanged: root.updateScroll()

                Keys.onPressed: function(event) {
                    if (event.matches(StandardKey.Copy) || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C)) {
                        event.accepted = true;
                    }
                }

                onTextEdited: {
                    root.hasSuccess = false;
                    root.hasError = false;
                    root.text = text;
                    syncModel();
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx(root.keySound);
                    }
                    root.textEdited(text);
                }

                onAccepted: {
                    root.submit();
                }
            }
        }
    }
}
