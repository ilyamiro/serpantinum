import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"

RowLayout {
    id: bottomHeader
    required property var root
    property alias bottomSectionSwitch: bottomSectionSwitch

    Layout.fillWidth: true
    opacity: root.introEqHeader
    transform: Translate { y: root.s(12) * (1 - root.introEqHeader) }

    Switch {
        id: bottomSectionSwitch
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.s(224)
        Layout.minimumWidth: root.s(168)
        Layout.maximumWidth: root.s(224)
        implicitHeight: root.s(26)
        implicitWidth: root.s(224)
        options: [
            typeof I18n !== "undefined" ? I18n.t("music.equalizer", "Equalizer") : "Equalizer",
            typeof I18n !== "undefined" ? I18n.t("music.audio.title", "Audio") : "Audio",
            typeof I18n !== "undefined" ? I18n.t("music.lyrics", "Lyrics") : "Lyrics"
        ]
        currentIndex: 0
        accentColor: ThemeBackend.mauve || "#cba6f7"
        baseColor: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity)
        textColor: ThemeBackend.subtext0 || "#a6adc8"
        activeTextColor: ThemeBackend.base || "#1e1e2e"
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: root.s(11.5)
        onCurrentIndexChanged: {
            if (currentIndex !== 1 && root.audioTestRunning) {
                root.toggleAudioTest();
            }
            root.updateLyricsSubscription();
            if (currentIndex === 2) {
                root.toEqAnim.stop();
                root.toAudioAnim.stop();
                root.toLyricsAnim.restart();
                root.restoreLastSavedEqualizer();
            } else if (currentIndex === 1) {
                root.toEqAnim.stop();
                root.toLyricsAnim.stop();
                root.toAudioAnim.restart();
                root.playAudioIntro();
                root.restoreLastSavedEqualizer();
            } else {
                root.toLyricsAnim.stop();
                root.toAudioAnim.stop();
                root.restoreLastSavedEqualizer();
                root.toEqAnim.restart();
            }
        }
        onValueChanged: (index, val) => {
            currentIndex = index;
        }
    }

    Item { Layout.fillWidth: true }

    ClickButton {
        id: audioTestBtn
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.audioTestBtnWidth * root.audioHeaderProgress
        implicitWidth: Layout.preferredWidth
        visible: root.audioHeaderProgress > 0.01
        opacity: root.audioHeaderProgress
        clip: true
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(8)
        buttonIcon: root.audioTestRunning ? "󰓛" : "󰋋"
        buttonText: root.audioTestRunning
            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.stop_test", "Stop") : "Stop")
            : (typeof I18n !== "undefined" ? I18n.t("music.audio.test", "Test") : "Test")
        textFontSize: root.s(11.5)
        iconFontSize: root.s(12)
        accentColor: root.audioTestRunning
            ? (ThemeBackend.mauve || "#cba6f7")
            : (ThemeBackend.surface0 || "#313244")
        bgOpacity: ThemeBackend.elementOpacity
        textColor: root.audioTestRunning
            ? (ThemeBackend.base || "#1e1e2e")
            : (ThemeBackend.text || "#cdd6f4")
        onClicked: root.toggleAudioTest()
    }

    ClickButton {
        id: dynamicEqBtn
        readonly property real showProgress: Math.max(0.0, 1.0 - root.actionBtnMorph)
        readonly property bool dynamicOn: !!root.eqData && root.eqData.dyneq === true
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.dynamicEqBtnWidth * showProgress
        implicitWidth: Layout.preferredWidth
        visible: showProgress > 0.01
        opacity: showProgress
        clip: true
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(12)
        contentAlignment: Qt.AlignLeft
        buttonText: typeof I18n !== "undefined" ? I18n.t("music.eq.dynamic", "Dynamic") : "Dynamic"
        textFontSize: root.s(11.5)
        clickSound: dynamicEqToggle.toggleSound
        accentColor: ThemeBackend.surface0 || "#313244"
        bgOpacity: ThemeBackend.elementOpacity
        textColor: ThemeBackend.text || "#cdd6f4"
        onClicked: root.setAudioFlag("dyneq", !dynamicOn)

        Toggle {
            id: dynamicEqToggle
            anchors.verticalCenter: parent.verticalCenter
            x: I18n.rtl ? root.s(5) : parent.width - width - root.s(5)
            horizontalPadding: 0
            trackWidth: root.s(30)
            trackHeight: root.s(16)
            implicitHeight: trackHeight
            cornerRadius: ThemeBackend.borderRadius
            checked: dynamicEqBtn.dynamicOn
            accentColor: ThemeBackend.mauve || "#cba6f7"
            baseColor: ThemeBackend.surface2 || "#585b70"
            onToggled: (isChecked) => {
                root.setAudioFlag("dyneq", isChecked);
                checked = Qt.binding(() => dynamicEqBtn.dynamicOn);
            }
        }
    }

    ClickButton {
        id: actionBtn
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.actionBtnCurrentWidth
        implicitWidth: root.actionBtnCurrentWidth
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(12)
        buttonIcon: bottomSectionSwitch.currentIndex === 2
            ? "󰈔"
            : (bottomSectionSwitch.currentIndex === 1 ? "󰑐" : "")
        buttonText: {
            if (bottomSectionSwitch.currentIndex === 2) {
                return typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select file") : "Select file";
            }
            if (bottomSectionSwitch.currentIndex === 1) {
                return typeof I18n !== "undefined" ? I18n.t("music.audio.reset", "Reset") : "Reset";
            }
            return root.eqData && root.eqData.pending ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved");
        }
        textFontSize: root.s(11.5)
        iconFontSize: root.s(13)
        accentColor: {
            if (bottomSectionSwitch.currentIndex !== 0) {
                return ThemeBackend.surface0 || "#313244";
            }
            return root.eqData && root.eqData.pending ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface0 || "#313244");
        }
        bgOpacity: ThemeBackend.elementOpacity
        textColor: {
            if (bottomSectionSwitch.currentIndex !== 0) {
                return ThemeBackend.text || "#cdd6f4";
            }
            return root.eqData && root.eqData.pending ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.text || "#cdd6f4");
        }
        enabled: bottomSectionSwitch.currentIndex === 2
            ? (root.hasTargetPlayer && !Lyrics.loading)
            : (bottomSectionSwitch.currentIndex === 1
                ? (Math.abs(root.balanceSlider.value) >= 0.005 || root.eqData.mono === true || root.eqData.swap === true || String(root.eqData.dynamics || "off") !== "off")
                : !(root.eqData && root.eqData.dyneq === true))
        opacity: bottomSectionSwitch.currentIndex === 2
            ? (root.hasTargetPlayer && !Lyrics.loading ? 1.0 : 0.45)
            : (enabled ? 1.0 : 0.45)
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Behavior on accentColor { ColorAnimation { duration: 250 } }
        Behavior on textColor { ColorAnimation { duration: 250 } }
        onClicked: {
            if (bottomSectionSwitch.currentIndex === 2) {
                root.lyricsPickerPopup.targetScreen = (root.Window && root.Window.window) ? root.Window.window.screen : null;
                root.lyricsPickerPopup.openPicker();
            } else if (bottomSectionSwitch.currentIndex === 1) {
                root.resetAudio();
            } else if (root.eqData && root.eqData.pending) {
                var temp = Object.assign({}, root.eqData);
                temp.pending = false;
                root.eqData = temp;
                root.savedEqData = Object.assign({}, temp);
                root.lastEqUpdate = Date.now();
                root.triggerEqLightning();
                root.execCmd(Caching.qsDir + "/media/equalizer.sh apply");
            }
        }
    }

    Item {
        id: presetTextContainer
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: (presetLabelText.implicitWidth + root.s(12)) * Math.max(0.0, 1.0 - root.presetSlideProgress)
        implicitWidth: Layout.preferredWidth
        visible: root.presetSlideProgress < 0.99
        opacity: Math.max(0.0, 1.0 - root.presetSlideProgress)
        clip: true

        Text {
            id: presetLabelText
            anchors.verticalCenter: parent.verticalCenter
            x: root.s(12) + (root.s(24) * root.presetSlideProgress)
            text: root.eqData && root.eqData.preset ? I18n.t("music.presets." + root.eqData.preset.toLowerCase()) : I18n.t("music.presets.flat")
            color: ThemeBackend.subtext0 || "#a6adc8"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
            font.bold: true
        }
    }
}
