import QtQuick
import "../"
import "../../"

Item {
    id: root
    clip: true
    visible: Lyrics.hasLyrics

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    property bool animate: false
    property bool userScrolling: false
    property real dragStartY: 0

    property real sideMargin: root.s(4)
    property real baseActiveFont: root.s(16)
    property real lineHeight: Math.max(root.s(24), baseActiveFont * 1.4)
    property real lineSpacing: Math.max(root.s(4), baseActiveFont * 0.25)
    readonly property real itemStep: lineHeight + lineSpacing

    property string alignment: "left"
    readonly property int effectiveHorizontalAlignment: {
        if (root.alignment === "center" || root.alignment === "middle") return Text.AlignHCenter;
        if (root.alignment === "right") return Text.AlignRight;
        return Text.AlignLeft;
    }
    readonly property int effectiveTransformOrigin: {
        if (root.alignment === "center" || root.alignment === "middle") return Item.Center;
        if (root.alignment === "right") return Item.Right;
        return Item.Left;
    }

    property int linesBehind: -1
    property int linesAfter: -1
    property int lyricsBehind: -1
    property int lyricsAfter: -1
    readonly property int effectiveLinesBehind: root.linesBehind >= 0 ? root.linesBehind : root.lyricsBehind
    readonly property int effectiveLinesAfter: root.linesAfter >= 0 ? root.linesAfter : root.lyricsAfter

    property real inactiveOpacity: -1

    property color activeLineColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7"
    property color inactiveLineColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4"
    property string fontFamily: (typeof ThemeBackend !== "undefined" && ThemeBackend.fontFamily) ? ThemeBackend.fontFamily : "sans-serif"
    property int fontWeight: Font.Bold
    property real centerRatio: 0.44

    property real activeItemCenterY: 0

    readonly property real autoY: {
        let center = root.height * root.centerRatio;
        if (Lyrics.currentIndex >= 0 && Lyrics.hasLyrics) {
            if (root.activeItemCenterY > 0) {
                return center - root.activeItemCenterY;
            }
            if (lyricsRepeater && lyricsRepeater.count > Lyrics.currentIndex) {
                let it = lyricsRepeater.itemAt(Lyrics.currentIndex);
                if (it && (Lyrics.currentIndex === 0 || it.y > 0)) {
                    return center - (it.y + it.height / 2);
                }
            }
            return center - (Lyrics.currentIndex * root.itemStep + root.lineHeight / 2);
        }
        return center - (root.lineHeight / 2);
    }

    property real targetY: autoY

    function clampY(val) {
        let center = root.height * root.centerRatio;
        let colH = lyricsColumn.height;
        if (colH <= 0) return val;

        let maxScrollY = center - (root.lineHeight / 2) + root.s(40);
        let minScrollY = center - colH + (root.lineHeight / 2) - root.s(40);

        if (minScrollY > maxScrollY) {
            return center - (root.lineHeight / 2);
        }
        return Math.max(minScrollY, Math.min(maxScrollY, val));
    }

    function scrollBy(delta) {
        if (!Lyrics.hasLyrics || !Lyrics.lyrics || Lyrics.lyrics.length === 0) return;

        let step = Math.max(root.s(20), root.itemStep);
        let scrollAmount = (delta / 120.0) * step * 1.5;

        root.userScrolling = true;
        root.animate = true;
        userScrollTimer.restart();

        root.targetY = root.clampY(root.targetY + scrollAmount);
    }

    function returnToPlayingLine() {
        userScrollTimer.stop();
        root.userScrolling = false;
        root.animate = true;
        root.targetY = root.autoY;
    }

    function seekToTimestamp(t) {
        let p = (typeof Lyrics !== "undefined" && Lyrics.player) ? Lyrics.player : ((typeof MprisController !== "undefined" && MprisController.activePlayer) ? MprisController.activePlayer : null);
        if (p && p.canSeek) {
            p.position = t;
            if (typeof Lyrics !== "undefined") {
                Lyrics.currentPosition = t;
            }
            if (typeof MprisController !== "undefined") {
                MprisController.livePosition = t;
            }
        }
    }

    Timer {
        id: userScrollTimer
        interval: 4000
        repeat: false
        onTriggered: {
            root.returnToPlayingLine();
        }
    }

    Connections {
        target: Lyrics
        function onLyricsChanged() {
            userScrollTimer.stop();
            root.userScrolling = false;
            root.animate = false;
            root.activeItemCenterY = 0;
            root.targetY = root.autoY;
        }
        function onCurrentIndexChanged() {
            if (root.activeItemCenterY > 0) {
                root.animate = true;
            }
            if (Lyrics.currentIndex >= 0 && lyricsRepeater && lyricsRepeater.count > Lyrics.currentIndex) {
                let it = lyricsRepeater.itemAt(Lyrics.currentIndex);
                if (it && (Lyrics.currentIndex === 0 || it.y > 0)) {
                    root.activeItemCenterY = it.y + it.height / 2;
                }
            }
            if (!root.userScrolling) {
                root.targetY = root.autoY;
            }
        }
    }

    onHeightChanged: {
        if (!root.userScrolling) {
            root.targetY = root.autoY;
        }
    }

    onAutoYChanged: {
        if (!root.userScrolling) {
            root.targetY = root.autoY;
        }
    }

    WheelHandler {
        id: wheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (delta === 0) return;
            root.scrollBy(delta);
        }
    }

    TapHandler {
        id: rightClickHandler
        target: null
        acceptedButtons: Qt.RightButton
        onTapped: {
            root.returnToPlayingLine();
        }
    }

    Item {
        id: scrollContainer
        width: parent.width
        height: lyricsColumn.height
        y: root.targetY

        Behavior on y {
            enabled: root.animate
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running && !root.userScrolling) {
                        root.animate = false;
                    }
                }
            }
        }

        Column {
            id: lyricsColumn
            width: parent.width
            spacing: root.lineSpacing

            Repeater {
                id: lyricsRepeater
                model: Lyrics.lyrics

                delegate: Item {
                    id: lineDelegate
                    width: lyricsColumn.width
                    height: Math.max(root.lineHeight, lineText.implicitHeight)

                    readonly property bool isCurrent: index === Lyrics.currentIndex

                    readonly property bool isWithinRange: {
                        if (root.userScrolling) return true;
                        let behind = root.effectiveLinesBehind;
                        let after = root.effectiveLinesAfter;
                        if (behind < 0 && after < 0) return true;

                        let cur = (typeof Lyrics !== "undefined" && Lyrics.currentIndex >= 0) ? Lyrics.currentIndex : 0;
                        let diff = index - cur;
                        if (diff < 0) {
                            return behind < 0 || (-diff) <= behind;
                        } else if (diff > 0) {
                            return after < 0 || diff <= after;
                        }
                        return true;
                    }

                    Component.onCompleted: {
                        if (isCurrent && (index === 0 || y > 0)) {
                            root.activeItemCenterY = y + height / 2;
                        }
                    }

                    onIsCurrentChanged: {
                        if (isCurrent && (index === 0 || y > 0)) {
                            root.activeItemCenterY = y + height / 2;
                        }
                    }

                    onYChanged: {
                        if (isCurrent && (index === 0 || y > 0)) {
                            root.activeItemCenterY = y + height / 2;
                        }
                    }

                    onHeightChanged: {
                        if (isCurrent && (index === 0 || y > 0)) {
                            root.activeItemCenterY = y + height / 2;
                        }
                    }

                    Text {
                        id: lineText
                        width: Math.min(parent.width - (root.sideMargin * 2), implicitWidth)
                        x: {
                            if (root.effectiveHorizontalAlignment === Text.AlignHCenter) {
                                return Math.round((parent.width - width) / 2);
                            }
                            if (root.effectiveHorizontalAlignment === Text.AlignRight) {
                                return parent.width - root.sideMargin - width;
                            }
                            return root.sideMargin;
                        }
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: root.effectiveHorizontalAlignment
                        wrapMode: Text.WordWrap
                        font.family: root.fontFamily
                        font.weight: root.fontWeight
                        font.pixelSize: root.baseActiveFont
                        color: (index === Lyrics.currentIndex && (!modelData.words || modelData.words.length === 0)) ? root.activeLineColor : root.inactiveLineColor
                        opacity: {
                            if (!lineDelegate.isWithinRange) return 0.0;
                            if (index === Lyrics.currentIndex) return 1.0;
                            if (root.inactiveOpacity >= 0) return root.inactiveOpacity;
                            return (typeof Lyrics !== "undefined" && typeof Lyrics.getLineOpacity === "function") ? Lyrics.getLineOpacity(index, Lyrics.currentIndex) : 0.4;
                        }
                        visible: opacity > 0.0
                        scale: {
                            if (index === Lyrics.currentIndex) return 1.0;
                            let d = Math.abs(index - Lyrics.currentIndex);
                            if (d === 1) return 0.88;
                            return 0.80;
                        }
                        transformOrigin: root.effectiveTransformOrigin

                        textFormat: (index === Lyrics.currentIndex && modelData.words && modelData.words.length > 0) ? Text.StyledText : Text.PlainText

                        text: {
                            if (index === Lyrics.currentIndex && modelData.words && modelData.words.length > 0) {
                                return Lyrics.renderActiveLineText(modelData, Lyrics.currentPosition, root.activeLineColor, root.inactiveLineColor);
                            }
                            return modelData.text !== "" ? modelData.text : "♪";
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 650
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 650
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 650
                                easing.type: Easing.OutCubic
                            }
                        }

                        MouseArea {
                            id: lineMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (modelData && modelData.time !== undefined) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton
                            preventStealing: isDragging

                            property real startY: 0
                            property bool isDragging: false

                            onPressed: mouse => {
                                let p = mapToItem(root, mouse.x, mouse.y);
                                startY = p.y;
                                root.dragStartY = scrollContainer.y;
                                isDragging = false;
                            }

                            onPositionChanged: mouse => {
                                if (pressed) {
                                    let p = mapToItem(root, mouse.x, mouse.y);
                                    let dy = p.y - startY;
                                    if (!isDragging && Math.abs(dy) > root.s(4)) {
                                        isDragging = true;
                                        root.userScrolling = true;
                                        userScrollTimer.stop();
                                        root.animate = false;
                                    }
                                    if (isDragging) {
                                        let newY = root.clampY(root.dragStartY + dy);
                                        scrollContainer.y = newY;
                                        root.targetY = newY;
                                    }
                                }
                            }

                            onReleased: mouse => {
                                if (isDragging) {
                                    isDragging = false;
                                    root.animate = true;
                                    userScrollTimer.restart();
                                    root.targetY = root.clampY(scrollContainer.y);
                                } else {
                                    if (modelData && modelData.time !== undefined && !isNaN(modelData.time)) {
                                        root.seekToTimestamp(modelData.time);
                                    }
                                }
                            }

                            onCanceled: {
                                if (isDragging) {
                                    isDragging = false;
                                    root.animate = true;
                                    userScrollTimer.restart();
                                    root.targetY = root.clampY(scrollContainer.y);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
