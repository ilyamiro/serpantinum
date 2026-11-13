import QtQuick
import "../../"
import "../../../"
import "../../../reusables"

BarFaceBase {
    id: root

    readonly property bool moduleActive: !activeTarget || activeTarget.moduleActive !== false
    // Subscribe by configuration, not visibility: an empty face must still fetch lyrics.
    readonly property bool wantsLyrics: moduleActive && !isPreview
    property bool lyricsSubscribed: false
    readonly property bool isPlaying: isPreview || Boolean(Lyrics.player && Lyrics.player.isPlaying)

    readonly property string lineText: {
        if (isPreview) return I18n.t("music.lyrics", "Lyrics");
        if (!moduleActive || !isPlaying || !Lyrics.isMediaActive || !Lyrics.hasLyrics) return "";
        let index = Lyrics.currentIndex;
        if (index < 0 || index >= Lyrics.lyrics.length) return "";
        return Lyrics.lyrics[index].text.trim();
    }
    readonly property bool isFaceVisible: lineText !== ""
    // Reserve a stable lane so changing line lengths do not move adjacent modules.
    readonly property real targetLength: isFaceVisible ? s(300) : 0

    implicitWidth: isVertical ? s(30) : targetLength
    implicitHeight: isVertical ? targetLength : s(30)

    function syncSubscription() {
        if (wantsLyrics === lyricsSubscribed) return;
        lyricsSubscribed = wantsLyrics;
        if (lyricsSubscribed) Lyrics.subscribe();
        else Lyrics.unsubscribe();
    }

    onWantsLyricsChanged: syncSubscription()
    Component.onCompleted: {
        syncSubscription();
        updateLine();
    }
    Component.onDestruction: {
        if (lyricsSubscribed) Lyrics.unsubscribe();
    }

    property string displayedLine: ""
    property string previousLine: ""
    property real previousOffset: 0
    property real lineProgress: 1

    function updateLine() {
        if (displayedLine === lineText) return;
        lineTransition.stop();
        previousLine = lineText === "" ? "" : displayedLine;
        previousOffset = currentLine ? currentLine.scrollX : 0;
        displayedLine = lineText;
        lineProgress = lineText === "" ? 1 : 0;
        if (lineText !== "") lineTransition.start();
    }

    onLineTextChanged: updateLine()

    SequentialAnimation {
        id: lineTransition
        NumberAnimation {
            target: root
            property: "lineProgress"
            to: 1
            duration: 240
            easing.type: Easing.OutCubic
        }
        ScriptAction { script: root.previousLine = ""; }
    }

    Item {
        anchors.centerIn: parent
        width: Math.max(0, (root.isVertical ? root.height : root.width) - root.s(20))
        height: root.isVertical ? root.width : root.height
        rotation: root.isVertical ? (root.module && root.module.isRightBar ? -90 : 90) : 0
        clip: true

        Text {
            x: root.previousOffset
            width: implicitWidth
            height: parent.height
            y: -root.s(6) * root.lineProgress
            text: root.previousLine
            textFormat: Text.PlainText
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(root.isCompact ? 11 : 12)
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
            opacity: 1 - root.lineProgress
        }

        MarqueeText {
            id: currentLine
            width: parent.width
            height: parent.height
            y: root.s(6) * (1 - root.lineProgress)
            text: root.displayedLine
            textFormat: Text.PlainText
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(root.isCompact ? 11 : 12)
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            opacity: root.lineProgress
            pauseDuration: 1200
            speed: 20
            marqueeSpacing: root.s(40)
            active: root.isFaceVisible && root.visible && (!root.barWindow || root.barWindow.visible) && !lineTransition.running
        }
    }
}
