import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

BarModuleCard {
    id: card
    title: I18n.t("guide.bar.modules.media", "Media")
    moduleId: "media"
    previewSideHeight: 160

    readonly property var sources: MprisController.musicSources
    readonly property var musicSources: ["automatic"].concat(sources.map(source => source.key))

    SettingsRow {
        rootObj: card.rootObj
        settingId: "media_music_source"
        searchKeywords: "media music source player application mpris automatic"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰎈"
        title: I18n.t("guide.bar.media.source.title", "Media source")
        description: I18n.t("guide.bar.media.source.desc", "Choose an MPRIS application for bars and desktop widgets. The music popup can select its own player.")

        Dropdown {
            id: musicSourceDropdown
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: rootObj.s(200)
            Layout.preferredHeight: rootObj.s(32)
            fontPixelSize: rootObj.s(11)
            options: [I18n.t("guide.bar.media.source.automatic", "Automatic")].concat(card.sources.map(source => {
                let name = source.name;
                if (card.sources.filter(other => other.name === name).length > 1)
                    name += " (" + source.key + ")";
                return source.available ? name : name + " — " + I18n.t("guide.bar.media.source.unavailable", "Unavailable");
            }))
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            dropdownColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            onSelected: function(index, value) {
                if (index >= 0 && index < card.musicSources.length)
                    card.tab.setMusicSource(card.musicSources[index], index > 0 ? card.sources[index - 1].name : "");
            }
            onVisibleChanged: if (!visible) closePopup()
        }
        Binding {
            target: musicSourceDropdown
            property: "currentIndex"
            value: Math.max(0, card.musicSources.indexOf(card.tab.musicSource))
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "media_hide_when_idle"
        searchKeywords: "media music hide idle paused stopped unavailable track"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰏤"
        title: I18n.t("guide.bar.media.hide_idle.title", "Hide media when no track is available")
        description: I18n.t("guide.bar.media.hide_idle.desc", "Keep Media visible while paused. Hide it when no track is available.")
        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.mediaHideWhenIdle
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) { card.tab.setMediaHideWhenIdle(c); }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "media_hide_unavailable_lyrics"
        searchKeywords: "media music lyrics hide unavailable empty desktop"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰍜"
        title: I18n.t("guide.bar.media.hide_lyrics.title", "Hide unavailable lyrics")
        description: I18n.t("guide.bar.media.hide_lyrics.desc", "Hide desktop lyrics and their background while no lyrics are available or a search is in progress. Widgets remain editable in the desktop editor.")
        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.hideUnavailableLyrics
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) { card.tab.setHideUnavailableLyrics(c); }
        }
    }

    widgetComponent: Component {
        BarPreviewWidget {
            property string mediaInfoMode: tab.mediaInfoMode
            property int mediaWidth: tab.mediaWidth
            property bool mediaShowIcon: tab.mediaShowIcon
            property bool mediaShowControls: tab.mediaShowControls
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_media_info_mode"
        searchKeywords: "media song track duration time position length author artist"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰥔"
        title: I18n.t("guide.bar.media.info_mode.title", "Secondary info")
        description: I18n.t("guide.bar.media.info_mode.desc", "Choose whether to show the song duration or its author")
        visible: !card.tab.isSideBar
        searchable: !card.tab.isSideBar
        hiddenByConfig: card.tab.isSideBar

        Switch {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(200)
            implicitHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            options: [
                I18n.t("guide.bar.media.info_mode.duration", "Duration"),
                I18n.t("guide.bar.media.info_mode.author", "Author")
            ]
            currentIndex: card.tab.mediaInfoMode === "author" ? 1 : 0
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            onToggled: function(idx) {
                card.tab.setMediaInfoMode(idx === 1 ? "author" : "duration");
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_media_width"
        searchKeywords: "media song track size width length resize"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰩨"
        title: I18n.t("guide.bar.media.width.title", "Width")
        description: I18n.t("guide.bar.media.width.desc", "Width of the song title area")
        visible: !card.tab.isSideBar
        searchable: !card.tab.isSideBar
        hiddenByConfig: card.tab.isSideBar

        Draggable {
            id: mediaSizeSlider
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: rootObj.s(8)
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(18)
            from: 80
            to: 300
            stepSize: 1
            defaultValue: 120
            showValueBubble: true
            valueFormatter: function(v) { return Math.round(v) + "px" }
            value: card.tab.mediaWidth
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                card.tab.mediaWidth = Math.round(val);
            }
            onDragFinished: {
                card.tab.setMediaWidth(card.tab.mediaWidth);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_media_show_icon"
        searchKeywords: "media song track icon album art cover thumbnail"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰎈"
        title: I18n.t("guide.bar.media.show_icon.title", "Show icon")
        description: I18n.t("guide.bar.media.show_icon.desc", "Display the album art or music icon")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.mediaShowIcon
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setMediaShowIcon(c);
            }
        }
    }

    SettingsRow {
        rootObj: card.rootObj
        settingId: "bar_media_show_controls"
        searchKeywords: "media song track controls buttons play pause previous next"
        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
        icon: "󰐊"
        title: I18n.t("guide.bar.media.show_controls.title", "Show controls")
        description: I18n.t("guide.bar.media.show_controls.desc", "Display the previous, play and next buttons")

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: card.tab.mediaShowControls
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setMediaShowControls(c);
            }
        }
    }
}
