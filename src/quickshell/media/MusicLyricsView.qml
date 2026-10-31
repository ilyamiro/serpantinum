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

    Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    function tr(key, fallback) {
        return typeof I18n !== "undefined" ? I18n.t("music.lyrics_menu." + key, fallback) : fallback;
    }

    function fmtTime(sec) {
        if (sec === null || sec === undefined || isNaN(sec)) return "";
        let s = Math.max(0, Math.round(sec));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function sourceName(si) {
        if (!si) return "";
        return si.source === "local" ? tr("local_file", "local file") : si.source;
    }

    // "Lyrics: LRCLIB · Audio: YouTube (Limusic)"
    function sourceLine() {
        let si = Lyrics.sourceInfo;
        let parts = [];
        if (si) parts.push(tr("lyrics", "Lyrics") + ": " + sourceName(si) + (si.manual ? " (" + tr("chosen", "chosen") + ")" : ""));
        let a = Lyrics.audioSource;
        if (a && (a.kind || a.player))
            parts.push(tr("audio", "Audio") + ": " + (a.kind ? a.kind + (a.player ? " (" + a.player + ")" : "") : a.player));
        if (Lyrics.unsynced) parts.push(tr("unsynced", "no timing"));
        return parts.join("  ·  ");
    }

    Text {
        id: sourceLineText
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        z: 6
        visible: Lyrics.hasLyrics && !Lyrics.menuOpen && text !== ""
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: lyricsView.sourceLine()
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.s(10)
        color: ThemeBackend.subtext0 || "#a6adc8"
        opacity: 0.75
    }

    // Lyrics options: where they come from, other lyrics, search again, sync
    Rectangle {
        id: lyricsMenu
        anchors.fill: parent
        z: 10
        visible: Lyrics.menuOpen
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.base || "#1e1e2e", 0.95)

        MouseArea { anchors.fill: parent }            // don't click through to the lyrics

        Flickable {
            anchors.fill: parent
            anchors.margins: root.s(8)
            contentHeight: menuColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: menuColumn
                width: parent.width
                spacing: root.s(6)

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: {
                        let si = Lyrics.sourceInfo;
                        if (!si) return lyricsView.tr("none", "No lyrics");
                        let what = (si.artist || si.title) ? "«" + si.artist + (si.artist && si.title ? " - " : "") + si.title + "»" : "";
                        return lyricsView.tr("lyrics", "Lyrics") + ": " + lyricsView.sourceName(si) + " " + what
                            + (si.album ? " · " + si.album : "") + (si.duration ? " · " + lyricsView.fmtTime(si.duration) : "");
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    font.bold: true
                    color: ThemeBackend.text || "#cdd6f4"
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                    text: {
                        let a = Lyrics.audioSource;
                        return a && (a.kind || a.player) ? lyricsView.tr("audio", "Audio") + ": " + (a.kind || "?") + (a.player ? " (" + a.player + ")" : "") : "";
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(10.5)
                    color: ThemeBackend.subtext0 || "#a6adc8"
                }

                Text {
                    visible: Lyrics.candidates.length > 1
                    text: lyricsView.tr("other", "Other lyrics")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    font.bold: true
                    color: ThemeBackend.text || "#cdd6f4"
                }

                Repeater {
                    model: Lyrics.candidates.length > 1 ? Lyrics.candidates : []
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: candText.implicitHeight + root.s(8)
                        radius: root.s(6)
                        color: candMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Text {
                            id: candText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: root.s(6)
                            elide: Text.ElideRight
                            text: (index === 0 ? "✓ " : "    ") + modelData.source + " · " + modelData.artist + " - " + modelData.title
                                + (modelData.duration ? " · " + lyricsView.fmtTime(modelData.duration) : "")
                                + (modelData.first !== null && modelData.first !== undefined ? " · " + lyricsView.tr("starts", "starts") + " " + Number(modelData.first).toFixed(1) + "s" : "")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10.5)
                            color: index === 0 ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.text || "#cdd6f4")
                        }

                        MouseArea {
                            id: candMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (index > 0) Lyrics.chooseCandidate(index);
                                Lyrics.menuOpen = false;
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: root.s(6)

                    ClickButton {
                        Layout.preferredHeight: root.s(24)
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: root.s(8)
                        buttonText: lyricsView.tr("refetch", "Search again")
                        textFontSize: root.s(10.5)
                        accentColor: ThemeBackend.surface0 || "#313244"
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text || "#cdd6f4"
                        onClicked: { Lyrics.refetch(); Lyrics.menuOpen = false; }
                    }
                }

                RowLayout {
                    spacing: root.s(6)

                    Text {
                        text: lyricsView.tr("fine", "Fine tune")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(10.5)
                        color: ThemeBackend.subtext0 || "#a6adc8"
                    }

                    ClickButton {
                        Layout.preferredHeight: root.s(24)
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: root.s(8)
                        buttonText: "−0.5s"
                        textFontSize: root.s(10.5)
                        accentColor: ThemeBackend.surface0 || "#313244"
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text || "#cdd6f4"
                        onClicked: Lyrics.nudgeOffset(-0.5)
                    }

                    Text {
                        text: Lyrics.userOffset === 0 ? "0" : (Lyrics.userOffset > 0 ? "+" : "") + Lyrics.userOffset.toFixed(1) + " s"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(10.5)
                        font.bold: true
                        color: Lyrics.userOffset === 0 ? (ThemeBackend.subtext0 || "#a6adc8") : (ThemeBackend.mauve || "#cba6f7")
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lyrics.nudgeOffset(-Lyrics.userOffset)
                        }
                    }

                    ClickButton {
                        Layout.preferredHeight: root.s(24)
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: root.s(8)
                        buttonText: "+0.5s"
                        textFontSize: root.s(10.5)
                        accentColor: ThemeBackend.surface0 || "#313244"
                        bgOpacity: ThemeBackend.elementOpacity
                        textColor: ThemeBackend.text || "#cdd6f4"
                        onClicked: Lyrics.nudgeOffset(0.5)
                    }
                }
            }
        }
    }

    LyricsView {
        id: popupLyricsViewport
        anchors.fill: parent
        anchors.bottomMargin: sourceLineText.visible ? sourceLineText.implicitHeight + root.s(2) : 0
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

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width * 0.8
            visible: root.hasTargetPlayer && !!root.targetPlayer.trackTitle && !Lyrics.loading
            text: I18n.t("music.lyrics_menu.not_found_hint")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(10)
            color: ThemeBackend.subtext0 || "#a6adc8"
            opacity: 0.7
        }
    }
}
