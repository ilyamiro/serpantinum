import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import "../"
import "../reusables"

MusicEqualizerState {
    id: popupRoot
    visible: false
    focus: true

    property alias maskRectOuter: borderLayer.maskRectOuter
    property alias chargeAnim: borderLayer.chargeAnim
    property alias bottomSectionSwitch: bottomHeader.bottomSectionSwitch
    property alias balanceSlider: audioView.balanceSlider
    property alias toAudioAnim: toAudioAnim
    property alias toEqAnim: toEqAnim
    property alias toLyricsAnim: toLyricsAnim
    property alias lyricsPickerPopup: lyricsPickerPopup

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        chargeAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        introMain = 0;
        introCover = 0;
        introText = 0;
        introControls = 0;
        introSeparator = 0;
        introEqHeader = 0;
        introEqSliders = 0;
        introPresets = 0;
        maskRectOuter.drawProgress = 0;
        introAnim.restart();
        chargeAnim.restart();
        if (bottomSectionSwitch.currentIndex === 1) playAudioIntro();
    }

    property bool lyricsSubscribed: false

    function updateLyricsSubscription() {
        let shouldSub = popupRoot.active && (bottomSectionSwitch.currentIndex === 2);
        if (shouldSub && !lyricsSubscribed) {
            lyricsSubscribed = true;
            Lyrics.customPlayer = popupRoot.targetPlayer;
            Lyrics.subscribe();
        } else if (!shouldSub && lyricsSubscribed) {
            lyricsSubscribed = false;
            Lyrics.customPlayer = null;
            Lyrics.unsubscribe();
        } else if (shouldSub && lyricsSubscribed) {
            Lyrics.customPlayer = popupRoot.targetPlayer;
        }
    }

    Shortcut {
        sequence: "Tab"
        enabled: popupRoot.active
        onActivated: {
            bottomSectionSwitch.currentIndex = (bottomSectionSwitch.currentIndex + 1) % 3;
            popupRoot.updateLyricsSubscription();
        }
    }

    Shortcut {
        sequence: "Backtab"
        enabled: popupRoot.active
        onActivated: {
            bottomSectionSwitch.currentIndex = (bottomSectionSwitch.currentIndex + 2) % 3;
            popupRoot.updateLyricsSubscription();
        }
    }

    onActiveChanged: {
        updateLyricsSubscription();
        if (active) {
            forceActiveFocus();
            resetAndPlayIntro();
            registerCava();
            triggerLocalArtFetch();
        } else {
            exitAnim.stop();
            unregisterCava();
            if (lyricsPickerPopup.visible || lyricsPickerPopup.opened) {
                lyricsPickerPopup.closePicker();
            }
            if (popupRoot.eqData && popupRoot.eqData.pending) {
                popupRoot.restoreLastSavedEqualizer();
            }
        }
    }

    Component.onCompleted: {
        if (popupRoot.eqData) {
            popupRoot.savedEqData = Object.assign({}, popupRoot.eqData);
        }
        if (active) {
            forceActiveFocus();
            resetAndPlayIntro();
            registerCava();
            triggerLocalArtFetch();
            updateLyricsSubscription();
        }
    }

    Component.onDestruction: {
        unregisterCava();
        if (lyricsSubscribed) {
            lyricsSubscribed = false;
            Lyrics.unsubscribe();
        }
    }

    Text {
        id: eqMeasureText
        visible: false
        text: popupRoot.eqData && popupRoot.eqData.pending ? (typeof I18n !== "undefined" ? I18n.t("music.eq.apply") : "Apply") : (typeof I18n !== "undefined" ? I18n.t("music.eq.saved") : "Saved")
        font.family: ThemeBackend.fontFamily
        font.pixelSize: popupRoot.s(11.5)
        font.bold: true
    }

    Text {
        id: lyricsMeasureText
        visible: false
        text: typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select file") : "Select file"
        font.family: ThemeBackend.fontFamily
        font.pixelSize: popupRoot.s(11.5)
        font.bold: true
    }

    Text {
        id: resetMeasureText
        visible: false
        text: typeof I18n !== "undefined" ? I18n.t("music.audio.reset", "Reset") : "Reset"
        font.family: ThemeBackend.fontFamily
        font.pixelSize: popupRoot.s(11.5)
        font.bold: true
    }

    Text {
        id: testMeasureText
        visible: false
        text: popupRoot.audioTestRunning
            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.stop_test", "Stop") : "Stop")
            : (typeof I18n !== "undefined" ? I18n.t("music.audio.test", "Test") : "Test")
        font.family: ThemeBackend.fontFamily
        font.pixelSize: popupRoot.s(11.5)
        font.bold: true
    }

    property real actionBtnMorph: 0.0
    property real audioHeaderProgress: 0.0
    property real presetSlideProgress: 0.0

    readonly property real eqActionBtnWidth: Math.max(popupRoot.s(68), eqMeasureText.implicitWidth + popupRoot.s(26))
    readonly property real audioActionBtnWidth: Math.max(popupRoot.s(84), resetMeasureText.implicitWidth + popupRoot.s(46))
    readonly property real audioTestBtnWidth: Math.max(popupRoot.s(64), Math.min(popupRoot.s(82), testMeasureText.implicitWidth + popupRoot.s(34)))
    readonly property real lyricsActionBtnWidth: Math.max(popupRoot.s(116), lyricsMeasureText.implicitWidth + popupRoot.s(44))
    readonly property real actionBtnCurrentWidth: actionBtnMorph <= 1.0
        ? eqActionBtnWidth + (audioActionBtnWidth - eqActionBtnWidth) * actionBtnMorph
        : audioActionBtnWidth + (lyricsActionBtnWidth - audioActionBtnWidth) * (actionBtnMorph - 1.0)

    ParallelAnimation {
        id: toLyricsAnim
        running: false
        NumberAnimation {
            target: popupRoot
            property: "actionBtnMorph"
            to: 2.0
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupRoot
            property: "presetSlideProgress"
            to: 1.0
            duration: 400
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupRoot
            property: "audioHeaderProgress"
            to: 0.0
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: toAudioAnim
        running: false
        NumberAnimation {
            target: popupRoot
            property: "actionBtnMorph"
            to: 1.0
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupRoot
            property: "presetSlideProgress"
            to: 1.0
            duration: 400
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupRoot
            property: "audioHeaderProgress"
            to: 1.0
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: toEqAnim
        running: false
        NumberAnimation {
            target: popupRoot
            property: "actionBtnMorph"
            to: 0.0
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupRoot
            property: "presetSlideProgress"
            to: 0.0
            duration: 400
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupRoot
            property: "audioHeaderProgress"
            to: 0.0
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    onTargetPlayerChanged: {
        if (targetPlayer) currentLivePosition = targetPlayer.position;
        triggerLocalArtFetch();
        updateLyricsSubscription();
    }

    property real introMain: 0
    property real introCover: 0
    property real introText: 0
    property real introControls: 0
    property real introSeparator: 0
    property real introEqHeader: 0
    property real introEqSliders: 0
    property real introPresets: 0
    property real audioIntroBalance: 0
    property real audioIntroFlags: 0
    property real audioIntroDynamics: 0

    ParallelAnimation {
        id: audioIntroAnim
        running: false

        NumberAnimation { target: popupRoot; property: "audioIntroBalance"; from: 0; to: 1.0; duration: 560; easing.type: Easing.OutQuart }

        SequentialAnimation {
            PauseAnimation { duration: 70 }
            NumberAnimation { target: popupRoot; property: "audioIntroFlags"; from: 0; to: 1.0; duration: 560; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 140 }
            NumberAnimation { target: popupRoot; property: "audioIntroDynamics"; from: 0; to: 1.0; duration: 560; easing.type: Easing.OutQuart }
        }
    }

    function playAudioIntro() {
        audioIntroBalance = 0;
        audioIntroFlags = 0;
        audioIntroDynamics = 0;
        audioIntroAnim.restart();
    }

    ParallelAnimation {
        id: introAnim
        running: false

        NumberAnimation { target: popupRoot; property: "introMain"; from: 0; to: 1.0; duration: 760; easing.type: Easing.OutQuart }

        SequentialAnimation {
            PauseAnimation { duration: 70 }
            NumberAnimation { target: popupRoot; property: "introCover"; from: 0; to: 1.0; duration: 810; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }

        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: popupRoot; property: "introText"; from: 0; to: 1.0; duration: 760; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 230 }
            NumberAnimation { target: popupRoot; property: "introControls"; from: 0; to: 1.0; duration: 760; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }

        SequentialAnimation {
            PauseAnimation { duration: 310 }
            NumberAnimation { target: popupRoot; property: "introSeparator"; from: 0; to: 1.0; duration: 660; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 370 }
            NumberAnimation { target: popupRoot; property: "introEqHeader"; from: 0; to: 1.0; duration: 710; easing.type: Easing.OutQuart }
        }

        SequentialAnimation {
            PauseAnimation { duration: 430 }
            NumberAnimation { target: popupRoot; property: "introEqSliders"; from: 0; to: 1.0; duration: 860; easing.type: Easing.OutExpo }
        }

        SequentialAnimation {
            PauseAnimation { duration: 550 }
            NumberAnimation { target: popupRoot; property: "introPresets"; from: 0; to: 1.0; duration: 810; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: popupRoot; property: "introPresets"; to: 0.0; duration: 130; easing.type: Easing.InBack }
            NumberAnimation { target: popupRoot; property: "introEqSliders"; to: 0.0; duration: 140; easing.type: Easing.InExpo }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: popupRoot; property: "introEqHeader"; to: 0.0; duration: 130; easing.type: Easing.InCubic }
                NumberAnimation { target: popupRoot; property: "introSeparator"; to: 0.0; duration: 130; easing.type: Easing.InCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: popupRoot; property: "introControls"; to: 0.0; duration: 140; easing.type: Easing.InBack }
                NumberAnimation { target: popupRoot; property: "introText"; to: 0.0; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { target: popupRoot; property: "introCover"; to: 0.0; duration: 150; easing.type: Easing.InBack }
            }
            SequentialAnimation {
                PauseAnimation { duration: 70 }
                NumberAnimation { target: popupRoot; property: "introMain"; to: 0.0; duration: 170; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (popupRoot.exitCallback) {
                    let cb = popupRoot.exitCallback;
                    popupRoot.exitCallback = null;
                    cb();
                }
            }
        }
    }

    LyricsPicker {
        id: lyricsPickerPopup
        targetScreen: (popupRoot.Window && popupRoot.Window.window) ? popupRoot.Window.window.screen : null
        onLyricsSelected: function(filePath, fileName) {
            Lyrics.loadLocalLyricsFile(filePath);
        }
    }

    Item {
        id: mainWrapper
        anchors.fill: parent
        
        scale: 0.92 + (0.08 * popupRoot.introMain)
        opacity: popupRoot.introMain
        transform: Translate { y: popupRoot.s(12) * (1 - popupRoot.introMain) }

        MusicBorder {
            id: borderLayer
            root: popupRoot
        }

        Rectangle {
            id: innerBg
            anchors.fill: parent
            anchors.margins: ThemeBackend.liquidGlass ? 0 : popupRoot.s(3)
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            radius: ThemeBackend.borderRadius

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: parent.radius
            }

            Rectangle {
                id: innerBgMask
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                visible: false
                layer.enabled: true 
            }

            Item {
                id: bgEffectsLayer
                anchors.fill: parent
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: innerBgMask
                }

                MusicBlurCrossfader {
                    root: popupRoot
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: popupRoot.s(18)
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: popupRoot.s(224)
                    spacing: popupRoot.s(16)

                    MusicCover {
                        root: popupRoot
                    }

                    MusicTrackControls {
                        root: popupRoot
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: popupRoot.s(2)
                    Layout.topMargin: popupRoot.s(16)
                    Layout.bottomMargin: popupRoot.s(16)
                    color: "#1AFFFFFF"
                    radius: popupRoot.s(1)

                    opacity: popupRoot.introSeparator
                    transform: Translate { y: popupRoot.s(12) * (1 - popupRoot.introSeparator) }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: popupRoot.s(12)

                    MusicBottomHeader {
                        id: bottomHeader
                        root: popupRoot
                    }

                    Item {
                        id: bottomViewsContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: popupRoot.s(235)

                        MusicEqView {
                            root: popupRoot
                        }

                        MusicAudioView {
                            id: audioView
                            root: popupRoot
                        }

                        MusicLyricsView {
                            root: popupRoot
                        }
                    }
                }
            }
        }
    }
}
