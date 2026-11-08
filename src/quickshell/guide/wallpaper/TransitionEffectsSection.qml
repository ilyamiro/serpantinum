import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

ColumnLayout {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    spacing: rootObj.s(6)

    component DurationSelector: NumberSelector {
        id: selector
        required property var tab
        required property string transitionId

        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: tab.rootObj.s(130)
        implicitHeight: tab.rootObj.s(32)
        from: 0.1
        to: 10.0
        stepSize: 0.1
        decimals: 1
        suffix: "s"
        value: (Number(tab.effect(transitionId).duration) || 1000) / 1000
        baseColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        buttonColor: ThemeBackend.surface1
        buttonTextColor: ThemeBackend.text
        textColor: ThemeBackend.text
        subTextColor: ThemeBackend.subtext0
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        cornerRadius: ThemeBackend.borderRadius
        fontFamily: ThemeBackend.fontFamily
        fontPixelSize: tab.rootObj.s(11)
        onValueChanged: {
            let ms = Math.round(selector.value * 1000);
            if (!isNaN(ms) && ms >= 100 && ms !== Number(tab.effect(transitionId).duration)) {
                tab.updateEffect(transitionId, "duration", ms);
            }
        }
    }

    component OptionSwitch: Switch {
        id: optionSwitch
        required property var tab
        required property string transitionId
        required property string key
        required property var values

        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: tab.rootObj.s(80) * values.length
        implicitHeight: tab.rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: tab.rootObj.s(11)
        options: values.map(v => I18n.t("guide.theme.wallpaper.transition." + key + "." + v))
        currentIndex: Math.max(0, values.indexOf(tab.effect(transitionId)[key]))
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        textColor: ThemeBackend.text
        activeTextColor: ThemeBackend.crust
        onValueChanged: function(index, value) {
            tab.updateEffect(optionSwitch.transitionId, optionSwitch.key, optionSwitch.values[index]);
        }
    }

    SettingsRow {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_fade"
        icon: "󰃟"
        title: section.tab.transitionName("fade")
        description: I18n.t("guide.theme.wallpaper.transition.fade.desc", "Cross-fade smoothly into the new wallpaper")
        searchKeywords: "wallpaper transition fade crossfade dissolve duration speed"

        DurationSelector { tab: section.tab; transitionId: "fade" }
    }

    SettingsGroup {
        rootObj: section.rootObj
        icon: "󰡎"
        title: section.tab.transitionName("wipe")
        description: I18n.t("guide.theme.wallpaper.transition.wipe.desc", "Split open from the middle of the screen")

        DurationSelector { tab: section.tab; transitionId: "wipe" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_wipe_orientation"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰡎"
                title: I18n.t("guide.theme.wallpaper.transition.orientation.title", "Orientation")
                description: I18n.t("guide.theme.wallpaper.transition.orientation.desc", "Axis the wipe opens along")
                searchKeywords: "wallpaper transition wipe orientation horizontal vertical split"

                OptionSwitch {
                    tab: section.tab
                    transitionId: "wipe"
                    key: "orientation"
                    values: Wallpaper.wipeOrientations
                }
            }
        ]
    }

    SettingsGroup {
        rootObj: section.rootObj
        icon: "󰝦"
        title: section.tab.transitionName("circle")
        description: I18n.t("guide.theme.wallpaper.transition.circle.desc", "Grow a circle outward until it covers the screen")

        DurationSelector { tab: section.tab; transitionId: "circle" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_circle_origin"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰓾"
                title: I18n.t("guide.theme.wallpaper.transition.origin.title", "Origin")
                description: I18n.t("guide.theme.wallpaper.transition.origin.desc", "Where the circle starts. The desktop menu always starts it where you clicked")
                searchKeywords: "wallpaper transition circle origin center random point"

                OptionSwitch {
                    tab: section.tab
                    transitionId: "circle"
                    key: "origin"
                    values: Wallpaper.circleOrigins
                }
            }
        ]
    }

    SettingsGroup {
        rootObj: section.rootObj
        icon: "󰓡"
        title: section.tab.transitionName("swipe")
        description: I18n.t("guide.theme.wallpaper.transition.swipe.desc", "Sweep across the screen from an edge or a corner")

        DurationSelector { tab: section.tab; transitionId: "swipe" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_swipe_direction"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰆌"
                title: I18n.t("guide.theme.wallpaper.transition.direction.title", "Direction")
                description: I18n.t("guide.theme.wallpaper.transition.direction.desc", "Edge or corner the swipe starts from")
                searchKeywords: "wallpaper transition swipe direction edge corner left right top bottom"

                Dropdown {
                    id: swipeDirectionDropdown
                    readonly property var values: ["random"].concat(Wallpaper.swipeDirections)
                    Layout.preferredWidth: section.rootObj.s(200)
                    Layout.preferredHeight: section.rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    options: values.map(v => I18n.t("guide.theme.wallpaper.transition.direction." + v))
                    currentIndex: Math.max(0, values.indexOf(section.tab.effect("swipe").direction))
                    fuzzySearch: false
                    fontFamily: ThemeBackend.fontFamily
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: section.rootObj.s(11)
                    onValueChanged: function(index, value) {
                        if (index >= 0 && index < values.length) section.tab.updateEffect("swipe", "direction", values[index]);
                    }
                }
            }
        ]
    }

    SettingsRow {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_paint"
        icon: "󰏘"
        title: section.tab.transitionName("paint")
        description: I18n.t("guide.theme.wallpaper.transition.paint.desc", "Paint the new wallpaper in, cell by cell, from colonies that grow across the screen")
        searchKeywords: "wallpaper transition paint grow organic cells pixels colonies spread duration speed"

        DurationSelector { tab: section.tab; transitionId: "paint" }
    }
}
