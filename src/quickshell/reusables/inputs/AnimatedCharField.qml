import QtQuick
import "../../"

Item {
    id: root
    clip: true

    property string text: ""
    property string placeholderText: ""
    property string fontFamily: ThemeBackend.fontFamily
    property int fontPixelSize: 12
    property color textColor: ThemeBackend.text
    property color placeholderColor: ThemeBackend.subtext0
    property real placeholderOpacity: 0.45
    property bool hidePlaceholderOnFocus: false
    property color selectionColor: ThemeBackend.blue
    property color caretColor: ThemeBackend.blue

    property int horizontalAlignment: I18n.rtl ? TextInput.AlignRight : TextInput.AlignLeft
    property int charSlotWidth: -1
    property real customSlotWidth: -1
    property int charSpacing: 1
    property int maximumLength: -1
    property var validator: null

    property bool masked: false
    property bool revealTyping: true
    property int revealDuration: 300
    property var maskPainter: function(ctx, size, color) {
        ctx.beginPath();
        ctx.arc(size / 2, size / 2, size * 0.18, 0, Math.PI * 2);
        ctx.fillStyle = color.toString();
        ctx.fill();
    }

    property bool enabled: true
    property bool inputFocus: false
    property bool showCaret: true
    property bool caretVisible: root.showCaret && (root.hasFocus || root.actionHighlight)
    property bool caretBlinkRunning: root.caretVisible && root.isWidgetVisible
    property real caretHeightFactor: 1.2
    property int caretMoveDuration: 250
    property int caretBlinkDuration: 100
    property int caretBlinkPause: 400
    property bool actionHighlight: false
    property bool isWidgetVisible: true

    property bool blockCopy: false
    property bool blockAutoRepeatExceptBackspace: false
    property bool suffixOnlySync: false
    property bool handleEscape: false

    property int entranceDuration: 420
    property real entranceOvershoot: 3.2
    property int exitDuration: 160
    property Component charDelegate: null

    readonly property bool hasFocus: innerInput.activeFocus
    readonly property string inputText: innerInput.text
    readonly property int cursorPosition: innerInput.cursorPosition
    readonly property int charCount: charModel.count
    readonly property real measuredCharWidth: globalCharMetrics.width
    readonly property real resolvedSlotWidth: root.customSlotWidth > 0 ? root.customSlotWidth : (root.charSlotWidth > 0 ? root.charSlotWidth : globalCharMetrics.width)
    readonly property real charSlotStep: root.resolvedSlotWidth + root.charSpacing
    readonly property bool contentFits: charRow.contentWidth <= root.width
    readonly property real alignOffset: root.contentFits ? root.computeRowX(charRow.contentWidth, root.width) : 0
    property real scrollShift: 0
    readonly property real scrollOffset: root.alignOffset + root.scrollShift
    readonly property alias textInput: innerInput
    readonly property alias charListView: charRow
    readonly property alias model: charModel

    Behavior on scrollShift { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    signal textEdited(string newText)
    signal accepted(string finalText)
    signal escapePressed()
    signal copyRequested(string selectedText)
    signal lengthGrew()
    signal inputActiveFocusChanged(bool active)

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
        let visibleW = root.width;

        if (visibleW <= 0) return;

        if (totalW <= visibleW) {
            root.scrollShift = 0;
            return;
        }

        let curX = innerInput.cursorPosition * root.charSlotStep;
        let minOffset = visibleW - totalW;
        let maxOffset = 0;
        let margin = 4;
        let curScreenX = curX + root.scrollOffset;

        if (curScreenX < margin) {
            root.scrollShift = Math.min(maxOffset, Math.max(minOffset, margin - curX));
        } else if (curScreenX > visibleW - margin - 2) {
            root.scrollShift = Math.min(maxOffset, Math.max(minOffset, visibleW - margin - 2 - curX));
        } else {
            root.scrollShift = Math.min(maxOffset, Math.max(minOffset, root.scrollShift));
        }
    }

    function syncModel() {
        let str = innerInput.text;
        let oldCount = charModel.count;
        let newCount = str.length;

        if (root.suffixOnlySync) {
            let minLen = Math.min(newCount, oldCount);
            let matchLen = 0;
            while (matchLen < minLen && str[matchLen] === charModel.get(matchLen).glyph) {
                matchLen++;
            }
            while (charModel.count > matchLen) {
                charModel.remove(charModel.count - 1);
            }
            if (newCount > oldCount) {
                root.lengthGrew();
            }
            for (let i = matchLen; i < newCount; i++) {
                charModel.append({ glyph: str[i], stillPeeking: false });
            }
        } else {
            let prefix = 0;
            while (prefix < oldCount && prefix < newCount && charModel.get(prefix).glyph === str[prefix]) {
                prefix++;
            }

            let suffix = 0;
            while (suffix < (oldCount - prefix) && suffix < (newCount - prefix) && charModel.get(oldCount - 1 - suffix).glyph === str[newCount - 1 - suffix]) {
                suffix++;
            }

            let deleteCount = oldCount - prefix - suffix;
            if (deleteCount > 0) {
                charModel.remove(prefix, deleteCount);
            }

            let insertStr = str.slice(prefix, newCount - suffix);
            for (let i = 0; i < insertStr.length; i++) {
                charModel.insert(prefix + i, { glyph: insertStr[i], stillPeeking: true });
            }

            if (root.masked && root.revealTyping) {
                globalRevealTimer.restart();
            }
        }
        updateScroll();
    }

    function clear() {
        innerInput.text = "";
        charModel.clear();
        root.scrollShift = 0;
        if (root.text !== "") root.text = "";
    }

    function forceInputFocus() {
        innerInput.forceActiveFocus();
    }

    function releaseFocus() {
        innerInput.focus = false;
    }

    function insertText(newStr) {
        if (!root.enabled) return "";
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
        return updated;
    }

    onWidthChanged: updateScroll()
    onHorizontalAlignmentChanged: updateScroll()
    onCustomSlotWidthChanged: updateScroll()
    onTextChanged: {
        if (innerInput.text !== root.text) {
            innerInput.text = root.text;
            syncModel();
        }
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

    Timer {
        id: globalRevealTimer
        interval: root.revealDuration
        onTriggered: {
            for (let i = 0; i < charModel.count; i++) {
                charModel.setProperty(i, "stillPeeking", false);
            }
        }
    }

    Text {
        id: placeholderLabel
        text: root.placeholderText
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        color: root.placeholderColor
        opacity: (innerInput.text.length === 0 && charModel.count === 0 && (!root.hidePlaceholderOnFocus || !root.hasFocus)) ? root.placeholderOpacity : 0.0
        x: root.computeRowX(implicitWidth, root.width)
        anchors.verticalCenter: parent.verticalCenter
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Rectangle {
        id: selectionHighlight
        readonly property int selMin: Math.min(innerInput.selectionStart, innerInput.selectionEnd)
        readonly property int selMax: Math.max(innerInput.selectionStart, innerInput.selectionEnd)
        readonly property bool hasSelection: selMax > selMin

        anchors.verticalCenter: parent.verticalCenter
        height: Math.min(parent.height - 4, root.fontPixelSize * 1.7)
        radius: 4
        color: root.selectionColor
        opacity: hasSelection ? 0.28 : 0.0

        property real selX: selMin * root.charSlotStep - 2
        x: root.scrollOffset + selX
        width: hasSelection ? ((selMax - selMin) * root.charSlotStep - root.charSpacing + 4) : 0

        Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on selX { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
        Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
    }

    Component {
        id: defaultCharDelegate
        Item {
            id: slot
            property bool stillPeeking: model.stillPeeking !== undefined ? model.stillPeeking : true
            width: root.resolvedSlotWidth
            height: charRow.height
            transformOrigin: Item.Center
            property bool revealed: !root.masked || (root.revealTyping && stillPeeking)

            Text {
                anchors.centerIn: parent
                visible: slot.revealed
                text: model.glyph
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
            }

            Loader {
                anchors.centerIn: parent
                active: root.masked
                sourceComponent: Canvas {
                    id: maskCanvas
                    visible: !slot.revealed
                    width: root.fontPixelSize
                    height: root.fontPixelSize
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        root.maskPainter(ctx, width, root.textColor);
                    }
                    Connections {
                        target: root
                        function onTextColorChanged() { maskCanvas.requestPaint(); }
                    }
                }
            }
        }
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
        delegate: root.charDelegate ? root.charDelegate : defaultCharDelegate

        onContentWidthChanged: root.updateScroll()

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "scale"; from: 0.3; to: 1.0; duration: root.entranceDuration; easing.type: Easing.OutBack; easing.overshoot: root.entranceOvershoot }
                NumberAnimation { property: "y"; from: 10; to: 0; duration: root.entranceDuration; easing.type: Easing.OutBack; easing.overshoot: root.entranceOvershoot * 0.8 }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "scale"; to: 0.3; duration: root.exitDuration; easing.type: Easing.InBack }
                NumberAnimation { property: "y"; to: -8; duration: root.exitDuration; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: root.exitDuration * 0.9; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    Rectangle {
        id: caretRect
        width: 2
        height: root.fontPixelSize * root.caretHeightFactor
        color: root.caretColor
        visible: root.caretVisible
        anchors.verticalCenter: parent.verticalCenter
        property real slotX: innerInput.cursorPosition * root.charSlotStep
        x: root.scrollOffset + slotX

        Behavior on slotX { NumberAnimation { duration: root.caretMoveDuration; easing.type: Easing.OutQuad } }

        SequentialAnimation on opacity {
            running: root.caretBlinkRunning
            loops: Animation.Infinite
            NumberAnimation { to: 0; duration: root.caretBlinkDuration; easing.type: Easing.InQuad }
            PauseAnimation { duration: root.caretBlinkPause }
            NumberAnimation { to: 1; duration: root.caretBlinkDuration; easing.type: Easing.OutQuad }
            PauseAnimation { duration: root.caretBlinkPause }
        }
    }

    TextInput {
        id: innerInput
        anchors.fill: parent
        focus: root.inputFocus
        opacity: 0
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        selectByMouse: true
        mouseSelectionMode: TextInput.SelectCharacters
        horizontalAlignment: root.horizontalAlignment
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        enabled: root.enabled
        maximumLength: root.maximumLength > 0 ? root.maximumLength : 32767
        validator: root.validator

        onCursorPositionChanged: root.updateScroll()
        onSelectionStartChanged: root.updateScroll()
        onSelectionEndChanged: root.updateScroll()
        onActiveFocusChanged: root.inputActiveFocusChanged(activeFocus)

        Keys.onPressed: function(event) {
            if (root.blockAutoRepeatExceptBackspace && event.isAutoRepeat && event.key !== Qt.Key_Backspace) {
                event.accepted = true;
                return;
            }
            if (event.matches(StandardKey.Copy) || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C)) {
                if (root.blockCopy) {
                    event.accepted = true;
                    return;
                }
                if (innerInput.selectedText.length > 0) {
                    root.copyRequested(innerInput.selectedText);
                    event.accepted = true;
                }
            }
        }

        Keys.onEscapePressed: function(event) {
            if (root.handleEscape) {
                root.escapePressed();
                event.accepted = true;
            }
        }

        onTextEdited: {
            root.text = text;
            root.syncModel();
            root.textEdited(text);
        }

        onAccepted: {
            root.accepted(text);
        }
    }
}
