import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsGroup {
    id: section
    required property var tab

    readonly property bool carouselEnabled: Config.getSetting("wallpaperCarousel.enabled", false) === true
    readonly property int carouselInterval: Wallpaper.clampCarouselInterval(Config.getSetting("wallpaperCarousel.interval", Wallpaper.carouselDefaultInterval))

    rootObj: section.tab.rootObj
    settingId: "wallpaper_carousel"
    searchKeywords: "wallpaper carousel slideshow rotate cycle random automatic change shuffle timer"
    icon: "󰸉"
    title: I18n.t("guide.theme.wallpaper.carousel.title", "Wallpaper carousel")
    description: I18n.t("guide.theme.wallpaper.carousel.desc", "Show a random wallpaper from the directory on a schedule, going through every wallpaper before any repeats")
    expanded: section.carouselEnabled

    Toggle {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        checked: section.carouselEnabled
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
        onToggled: function(c) {
            Config.setSetting("wallpaperCarousel.enabled", c);
        }
    }

    subSettings: [
        SettingsRow {
            rootObj: section.tab.rootObj
            settingId: "wallpaper_carousel_interval"
            searchKeywords: "wallpaper carousel interval frequency how often seconds period delay timer"
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰔛"
            title: I18n.t("guide.theme.wallpaper.carousel.interval.title", "Change interval")
            description: I18n.t("guide.theme.wallpaper.carousel.interval.desc", "Seconds between wallpaper changes, from 10 seconds up to a week")

            NumberSelector {
                id: intervalSelector
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(140)
                implicitHeight: rootObj.s(32)
                from: Wallpaper.carouselMinInterval
                to: Wallpaper.carouselMaxInterval
                stepSize: 10
                decimals: 0
                suffix: "s"
                value: section.carouselInterval
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                buttonColor: ThemeBackend.surface1
                buttonTextColor: ThemeBackend.text
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: rootObj.s(11)
                onValueChanged: {
                    let v = Wallpaper.clampCarouselInterval(intervalSelector.value);
                    if (section.carouselInterval !== v) {
                        Config.setSetting("wallpaperCarousel.interval", v);
                    }
                }
            }
        }
    ]
}
