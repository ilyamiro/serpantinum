import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/media"

Item {
    id: lyricsView
    required property var root
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width
    x: root.bottomSectionSwitch.currentIndex === 2 ? 0 : parent.width + root.s(24)
    opacity: root.bottomSectionSwitch.currentIndex === 2 ? 1.0 : 0.0
    visible: opacity > 0.0
    clip: true

    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    LyricsView {
        id: popupLyricsViewport
        anchors.fill: parent
        visible: Lyrics.hasLyrics
        sideMargin: root.s(4)
        baseActiveFont: root.s(18)
        lineHeight: Math.max(root.s(30), baseActiveFont * 1.4)
        lineSpacing: Math.max(root.s(6), baseActiveFont * 0.25)
        activeLineColor: ThemeBackend.mauve || root.dynamicTextColor
        inactiveLineColor: ThemeBackend.text || "#cdd6f4"
        fontFamily: ThemeBackend.fontFamily
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: root.s(6)
        visible: !Lyrics.hasLyrics
        z: 5

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰎈"
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(28)
            color: root.dynamicTextColor
            opacity: 0.75
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (!root.hasTargetPlayer || !root.targetPlayer.trackTitle) return I18n.t("music.nothing_playing");
                if (Lyrics.loading) return I18n.t("music.searching_lyrics");
                return I18n.t("music.no_lyrics");
            }
            font.family: ThemeBackend.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: root.s(12)
            color: ThemeBackend.subtext0 || "#a6adc8"
        }
    }
}
