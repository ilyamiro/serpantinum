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
            accentColor: ThemeBackend.accent
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
            accentColor: ThemeBackend.accent
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
            accentColor: ThemeBackend.accent
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
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                card.tab.setMediaShowControls(c);
            }
        }
    }
}
