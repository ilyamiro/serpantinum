import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
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

    property bool persistReveal: true
    property bool isRevealed: (persistReveal && typeof Config !== "undefined") ? Config.getSetting("inputs.passwordReveal", false) : false
    property bool _isUpdatingFromConfig: false

    Connections {
        target: (root.persistReveal && typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            let saved = Config.getSetting("inputs.passwordReveal", false);
            if (root.isRevealed !== saved) {
                root._isUpdatingFromConfig = true;
                root.isRevealed = saved;
                root._isUpdatingFromConfig = false;
            }
        }
    }

    property real revealProgress: isRevealed ? 1.0 : 0.0
    Behavior on revealProgress {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 1.25
        }
    }

    property int horizontalAlignment: I18n.rtl ? TextInput.AlignRight : TextInput.AlignLeft
    property int charSlotWidth: -1
    property int charSpacing: 1
    property alias symbolSpacing: root.charSpacing
    readonly property real dotSize: Math.round(root.implicitHeight * 0.50)
    readonly property real charSlotStep: charField.charSlotStep
    readonly property real scrollOffset: charField.scrollOffset
    property int activeShapeIdx: 0

    property bool enabled: true
    property bool hasError: false
    property bool hasSuccess: false
    property bool _markedError: false
    property bool _markedSuccess: false
    property bool _statusDismissed: false
    readonly property bool showError: (root.hasError && !root._statusDismissed) || root._markedError
    readonly property bool showSuccess: (root.hasSuccess && !root._statusDismissed) || root._markedSuccess
    property bool isBusy: false
    readonly property bool hasFocus: charField.hasFocus || root.activeFocus
    property bool action_highlight: false
    property bool isHoveredOrHighlighted: mainHover.hovered || root.action_highlight
    property bool isWidgetVisible: true
    property bool showCaret: true

    property bool showLockIcon: true
    property bool showSubmitButton: true
    property int lockButtonSize: Math.max(20, root.height - 8)

    readonly property color activeSignalColor: root.showError ? root.errorColor : (root.showSuccess ? root.successColor : (root.isBusy ? root.busyColor : root.accentColor))
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
        if (charField.inputText !== "" && typeof Sounds !== "undefined") {
            Sounds.playSfx(root.keySound);
        }
        charField.clear();
        root.text = "";
        root._markedSuccess = false;
        root._markedError = false;
        root.cleared();
    }

    function forceInputFocus() {
        charField.forceInputFocus();
    }

    function insertText(newStr) {
        if (!root.enabled || root.isBusy) return;
        root.dismissStatus();
        let updated = charField.insertText(newStr);
        root.text = updated;
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

    function dismissStatus() {
        root._markedSuccess = false;
        root._markedError = false;
        root._statusDismissed = true;
    }

    function markSuccess() {
        root._markedError = false;
        root._markedSuccess = true;
        root._statusDismissed = true;
    }

    function markError() {
        root._markedSuccess = false;
        root._markedError = true;
        root.triggerShake();
    }

    function resetVerification() {
        root.dismissStatus();
    }

    function verify(validatorFn) {
        if (typeof validatorFn === "function") {
            var isValid = validatorFn(charField.inputText);
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
        root.accepted(charField.inputText);
        root.triggered();
    }

    function updateScroll() {
        charField.updateScroll();
    }

    onRevealProgressChanged: {
        charField.updateScroll();
        lockButton.requestPaint();
    }

    onIsRevealedChanged: {
        submitButton.triggerSpin();
        if (!root.persistReveal || root._isUpdatingFromConfig) return;
        if (typeof Config !== "undefined") {
            Config.setSetting("inputs.passwordReveal", root.isRevealed);
        }
    }

    property real typePulse: 0.0
    property real errorPulse: 0.0

    SequentialAnimation {
        id: typePulseAnim
        NumberAnimation { target: root; property: "typePulse"; to: 0.55; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "typePulse"; to: 0.0; duration: 380; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: errorPulseAnim
        NumberAnimation { target: root; property: "errorPulse"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "errorPulse"; to: 0.0; duration: 620; easing.type: Easing.OutCubic }
    }

    onTextChanged: {
        if (charField.text !== root.text) {
            charField.text = root.text;
        }
        if (glass.active) typePulseAnim.restart();
    }

    onHasFocusChanged: {
        if (hasFocus) {
            focusPopAnim.restart();
        }
        lockButton.requestPaint();
    }

    onHasErrorChanged: {
        if (hasError) root._statusDismissed = false;
    }
    onHasSuccessChanged: {
        if (hasSuccess) root._statusDismissed = false;
    }
    onShowErrorChanged: {
        if (showError && glass.active) errorPulseAnim.restart();
        lockButton.requestPaint();
    }
    onShowSuccessChanged: lockButton.requestPaint()
    onIsBusyChanged: {
        if (!isBusy) {
            lockButton.busyRotation = 0;
            lockButton.spinBlur = 0;
        }
        lockButton.requestPaint();
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
        NumberAnimation { target: root; property: "focusPop"; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
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
        scale: (root.showError ? 1.02 : (root.isBusy ? 0.98 : 1.0)) * root.focusPop
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        transform: Translate { id: shakeT; x: 0 }

        Rectangle {
            id: bgShape
            anchors.fill: parent
            radius: root.cornerRadius
            clip: true
            opacity: root.enabled ? 1.0 : 0.5
            readonly property color stateColor: {
                if (root.hasFocus) return root.focusColor;
                if (charField.inputText.length > 0) return root.activeColor;
                if (root.isHoveredOrHighlighted) return root.hoverColor;
                return root.baseColor;
            }
            color: glass.active ? "transparent" : stateColor
            Behavior on color { ColorAnimation { duration: 150 } }

            GlassFill {
                id: glass
                anchors.fill: parent
                radius: parent.radius
                tintColor: bgShape.stateColor
                tintAmount: root.hasFocus ? 0.38 : 0.26
                press: root.hasFocus ? 0.55 : (root.isHoveredOrHighlighted ? 0.2 : 0)
                pulse: Math.min(1, root.typePulse + root.errorPulse)
                Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on tintAmount { NumberAnimation { duration: 150 } }
            }
        }

        CanvasIconButton {
            id: lockButton
            visible: root.showLockIcon
            x: I18n.rtl ? (parent.width - width - 4) : 4
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
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: lockButton
                            property: "spinBlur"
                            from: 1.0
                            to: 0.0
                            duration: 250
                            easing.type: Easing.InQuad
                        }
                    }
                }

                PauseAnimation {
                    duration: 480
                }
            }

            accentColor: root.showError
                ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.16)
                : (root.showSuccess
                    ? Qt.rgba(root.successColor.r, root.successColor.g, root.successColor.b, 0.16)
                    : (root.isBusy
                        ? Qt.rgba(root.busyColor.r, root.busyColor.g, root.busyColor.b, 0.16)
                        : root.lockBoxColor))

            textColor: root.showError
                ? root.errorColor
                : (root.showSuccess
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
            x: I18n.rtl ? 4 : (parent.width - width - 4)
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size

            property int size: Math.max(20, root.height - 8)
            property int cornerRadius: Math.max(4, root.cornerRadius - 4)
            property real popScale: 1.0
            property real flashOpacity: 0.0
            property bool isHoveredOrHighlighted: (submitMa.containsMouse || root.action_highlight) && root.enabled && !root.isBusy
            property color currentAccent: root.showSuccess
                ? root.successColor
                : (root.showError
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

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                scale: (!root.enabled || root.isBusy ? 1.0 : (submitMa.pressed ? 1.08 : (submitButton.isHoveredOrHighlighted ? 1.04 : 1.0))) * submitButton.popScale
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                SequentialAnimation {
                    id: submitPopAnim
                    NumberAnimation { target: submitButton; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
                    NumberAnimation { target: submitButton; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
                }

                ChevronIcon {
                    id: chevronWrapper
                    anchors.centerIn: parent
                    width: submitButton.size * 0.38
                    height: submitButton.size * 0.38
                    rotation: I18n.rtl ? 0 : 180
                    color: root.baseColor

                    NumberAnimation {
                        id: chevronSpinAnim
                        target: chevronWrapper
                        property: "rotation"
                        from: I18n.rtl ? 0 : 180
                        to: I18n.rtl ? 360 : 540
                        duration: 400
                        easing.type: Easing.OutCubic
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

        AnimatedCharField {
            id: charField
            anchors.left: !I18n.rtl ? (root.showLockIcon ? lockButton.right : parent.left) : (root.showSubmitButton ? submitButton.right : parent.left)
            anchors.leftMargin: !I18n.rtl ? (root.showLockIcon ? 6 : root.horizontalPadding) : (root.showSubmitButton ? 6 : root.horizontalPadding)
            anchors.right: !I18n.rtl ? (root.showSubmitButton ? submitButton.left : parent.right) : (root.showLockIcon ? lockButton.left : parent.right)
            anchors.rightMargin: !I18n.rtl ? (root.showSubmitButton ? 6 : root.horizontalPadding) : (root.showLockIcon ? 6 : root.horizontalPadding)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: root.verticalPadding
            anchors.bottomMargin: root.verticalPadding

            text: root.text
            placeholderText: root.placeholderText
            fontFamily: root.fontFamily
            fontPixelSize: root.fontPixelSize
            textColor: root.textColor
            placeholderColor: root.subTextColor
            placeholderOpacity: 0.45
            hidePlaceholderOnFocus: true
            selectionColor: root.activeSignalColor
            caretColor: root.caretColor
            horizontalAlignment: root.horizontalAlignment
            charSlotWidth: root.charSlotWidth
            customSlotWidth: root.charSlotWidth > 0 ? root.charSlotWidth : (root.revealProgress > 0.5 ? measuredCharWidth : root.dotSize)
            charSpacing: root.charSpacing
            maximumLength: root.maximumLength
            validator: root.validator
            enabled: root.enabled && !root.isBusy
            inputFocus: true
            showCaret: root.showCaret
            caretVisible: root.showCaret && (root.hasFocus || root.action_highlight) && (root.isRevealed || root.revealProgress > 0.01)
            caretBlinkRunning: caretVisible && root.isWidgetVisible
            caretHeightFactor: 1.3
            caretMoveDuration: 150
            caretBlinkDuration: 120
            caretBlinkPause: 380
            actionHighlight: root.action_highlight
            isWidgetVisible: root.isWidgetVisible
            blockCopy: true
            blockAutoRepeatExceptBackspace: true
            suffixOnlySync: true
            entranceDuration: 250
            entranceOvershoot: 1.35
            exitDuration: 130

            onLengthGrew: root.activeShapeIdx = (root.activeShapeIdx + 1) % 8

            onTextEdited: function(newText) {
                root.dismissStatus();
                root.text = newText;
                if (typeof Sounds !== "undefined") {
                    Sounds.playSfx(root.keySound);
                }
                root.textEdited(newText);
            }

            onAccepted: root.submit()

            charDelegate: Component {
                Item {
                    id: charSlot
                    required property int index
                    required property string glyph

                    readonly property bool isLastChar: charSlot.index === charField.charCount - 1
                    readonly property bool morphActive: root.isWidgetVisible && root.visible && !root.isRevealed && root.revealProgress < 0.99
                    readonly property var activeShapes: [8, 5, 9, 6, 10, 7, 11, 4]

                    property bool ready: false
                    property real shapeFrom: 0
                    property real shapeTo: isLastChar ? activeShapes[root.activeShapeIdx] : 0
                    property real shapeBlend: 1.0
                    property real spinAngle: 0.0
                    property real idleSpin: 0.0

                    Behavior on shapeBlend {
                        id: blendBehavior
                        enabled: charSlot.ready
                        SpringAnimation {
                            spring: 4.4
                            damping: 0.56
                            mass: 1.0
                            epsilon: 0.0008
                        }
                    }

                    Behavior on spinAngle {
                        enabled: charSlot.ready
                        SpringAnimation {
                            spring: 4.2
                            damping: 0.58
                            mass: 1.0
                            epsilon: 0.01
                        }
                    }

                    NumberAnimation on idleSpin {
                        from: 0.0
                        to: 360.0
                        duration: 18000
                        loops: Animation.Infinite
                        running: charSlot.isLastChar && charSlot.morphActive
                    }

                    NumberAnimation {
                        id: activeMorphAnim
                        target: charSlot
                        property: "shapeBlend"
                        from: 0.0
                        to: 1.0
                        duration: 950
                        easing.type: Easing.InOutSine
                    }

                    function morphTo(nextShape, turnDeg, smooth) {
                        if (nextShape === charSlot.shapeTo) return;
                        activeMorphAnim.stop();
                        blendBehavior.enabled = false;
                        charSlot.shapeFrom = charSlot.shapeTo;
                        charSlot.shapeBlend = 0.0;
                        charSlot.shapeTo = nextShape;
                        if (smooth && charSlot.ready) {
                            activeMorphAnim.start();
                        } else {
                            blendBehavior.enabled = charSlot.ready;
                            charSlot.shapeBlend = 1.0;
                        }
                        if (charSlot.ready && turnDeg !== 0) {
                            if (charSlot.isLastChar) {
                                charSlot.spinAngle += turnDeg;
                            } else {
                                let total = charSlot.spinAngle + charSlot.idleSpin;
                                let snapped = Math.round((total + turnDeg) / 90.0) * 90.0;
                                charSlot.spinAngle = snapped - charSlot.idleSpin;
                            }
                        }
                    }

                    onIsLastCharChanged: {
                        let target = isLastChar ? activeShapes[root.activeShapeIdx] : 0;
                        if (!ready) {
                            shapeTo = target;
                            return;
                        }
                        morphTo(target, 90.0, false);
                    }

                    Timer {
                        id: activeMorphTimer
                        interval: 2800
                        repeat: true
                        running: charSlot.ready && charSlot.isLastChar && charSlot.morphActive
                        onTriggered: {
                            let step = 1 + Math.floor(Math.random() * (charSlot.activeShapes.length - 1));
                            root.activeShapeIdx = (root.activeShapeIdx + step) % charSlot.activeShapes.length;
                            charSlot.morphTo(charSlot.activeShapes[root.activeShapeIdx], 0.0, true);
                        }
                    }

                    Component.onCompleted: {
                        if (root.isRevealed || !isLastChar) {
                            let target = isLastChar ? activeShapes[root.activeShapeIdx] : 0;
                            shapeFrom = target;
                            shapeTo = target;
                            shapeBlend = 1.0;
                            spinAngle = 0.0;
                            Qt.callLater(function() {
                                if (!charSlot) return;
                                charSlot.ready = true;
                            });
                        } else {
                            shapeFrom = 0;
                            shapeTo = activeShapes[root.activeShapeIdx];
                            shapeBlend = 0.0;
                            spinAngle = -90.0;
                            Qt.callLater(function() {
                                if (!charSlot) return;
                                if (!charSlot.isLastChar) {
                                    charSlot.shapeFrom = 0;
                                    charSlot.shapeTo = 0;
                                    charSlot.shapeBlend = 1.0;
                                    charSlot.spinAngle = 0.0;
                                    charSlot.ready = true;
                                    return;
                                }
                                charSlot.shapeTo = charSlot.activeShapes[root.activeShapeIdx];
                                charSlot.ready = true;
                                charSlot.shapeBlend = 1.0;
                                charSlot.spinAngle = 0.0;
                            });
                        }
                    }

                    width: charField.resolvedSlotWidth
                    height: charField.charListView.height
                    transformOrigin: Item.Center

                    ShaderEffect {
                        id: charShape
                        anchors.centerIn: parent
                        width: root.dotSize * 1.36
                        height: width

                        opacity: Math.max(0.0, Math.min(1.0, 1.0 - root.revealProgress))
                        scale: Math.max(0.0, 1.0 - root.revealProgress)
                        visible: opacity > 0.01

                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real shapeFrom: charSlot.shapeFrom
                        property real shapeTo: charSlot.shapeTo
                        property real shapeBlend: charSlot.shapeBlend
                        property real angleRad: (charSlot.spinAngle + charSlot.idleSpin - root.revealProgress * 30.0) * Math.PI / 180.0
                        property real hoverAmt: 0.0
                        property real activeAmt: 0.0
                        property real glassMode: 0.0
                        property color fillColor: root.textColor
                        property color rimColor: root.textColor

                        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/widgets/workspace_morph.frag.qsb"
                    }

                    Text {
                        id: charText
                        anchors.centerIn: parent
                        text: charSlot.glyph
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
        }
    }
}
