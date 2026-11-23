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
        settingId: "wallpaper_transition_wipe"
        searchKeywords: "wallpaper transition wipe split curtain duration speed"
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
        settingId: "wallpaper_transition_circle"
        searchKeywords: "wallpaper transition circle radial ripple grow duration speed"
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
        settingId: "wallpaper_transition_swipe"
        searchKeywords: "wallpaper transition swipe slide sweep duration speed"
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

    SettingsGroup {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_wave"
        searchKeywords: "wallpaper transition wave liquid fluid ripple duration speed"
        icon: "󰞌"
        title: section.tab.transitionName("wave")
        description: I18n.t("guide.theme.wallpaper.transition.wave.desc", "Sweep a curved liquid wave across the screen")

        DurationSelector { tab: section.tab; transitionId: "wave" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_wave_direction"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰆌"
                title: I18n.t("guide.theme.wallpaper.transition.direction.title", "Direction")
                description: I18n.t("guide.theme.wallpaper.transition.wave.direction_desc", "Edge or corner the wave sweeps from")
                searchKeywords: "wallpaper transition wave fluid direction edge corner left right top bottom"

                Dropdown {
                    id: waveDirectionDropdown
                    readonly property var values: ["random"].concat(Wallpaper.swipeDirections)
                    Layout.preferredWidth: section.rootObj.s(200)
                    Layout.preferredHeight: section.rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    options: values.map(v => I18n.t("guide.theme.wallpaper.transition.direction." + v))
                    currentIndex: Math.max(0, values.indexOf(section.tab.effect("wave").direction))
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
                        if (index >= 0 && index < values.length) section.tab.updateEffect("wave", "direction", values[index]);
                    }
                }
            }
        ]
    }

    SettingsGroup {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_blinds"
        searchKeywords: "wallpaper transition blinds venetian slats stripes duration speed"
        icon: "󰂬"
        title: section.tab.transitionName("blinds")
        description: I18n.t("guide.theme.wallpaper.transition.blinds.desc", "Open parallel slats across the screen in a staggered wave")

        DurationSelector { tab: section.tab; transitionId: "blinds" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_blinds_orientation"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰡎"
                title: I18n.t("guide.theme.wallpaper.transition.orientation.title", "Orientation")
                description: I18n.t("guide.theme.wallpaper.transition.blinds.orientation_desc", "Axis the blinds open along")
                searchKeywords: "wallpaper transition blinds venetian slats orientation horizontal vertical"

                OptionSwitch {
                    tab: section.tab
                    transitionId: "blinds"
                    key: "orientation"
                    values: Wallpaper.wipeOrientations
                }
            }
        ]
    }

    SettingsGroup {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_clock"
        searchKeywords: "wallpaper transition clock radar sweep rotate duration speed"
        icon: "󰅐"
        title: section.tab.transitionName("clock")
        description: I18n.t("guide.theme.wallpaper.transition.clock.desc", "Sweep clockwise around a point like a radar beam")

        DurationSelector { tab: section.tab; transitionId: "clock" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_clock_origin"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰓾"
                title: I18n.t("guide.theme.wallpaper.transition.origin.title", "Origin")
                description: I18n.t("guide.theme.wallpaper.transition.clock.origin_desc", "Where the sweep pivots from")
                searchKeywords: "wallpaper transition clock sweep radar origin center random point"

                OptionSwitch {
                    tab: section.tab
                    transitionId: "clock"
                    key: "origin"
                    values: Wallpaper.circleOrigins
                }
            }
        ]
    }

    SettingsGroup {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_hex"
        searchKeywords: "wallpaper transition hex hexagon honeycomb grid tiles duration speed"
        icon: "󰋙"
        title: section.tab.transitionName("hex")
        description: I18n.t("guide.theme.wallpaper.transition.hex.desc", "Reveal the new wallpaper through a rippling honeycomb of hexagons")

        DurationSelector { tab: section.tab; transitionId: "hex" }

        subSettings: [
            SettingsRow {
                rootObj: section.rootObj
                settingId: "wallpaper_transition_hex_size"
                baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                icon: "󰩨"
                title: I18n.t("guide.theme.wallpaper.transition.hex.size_title", "Hex size")
                description: I18n.t("guide.theme.wallpaper.transition.hex.size_desc", "Size of each hexagon tile in the grid")
                searchKeywords: "wallpaper transition hex grid hexagon honeycomb tile cell size scale"

                NumberSelector {
                    id: hexSizeSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: section.rootObj.s(130)
                    implicitHeight: section.rootObj.s(32)
                    from: 20
                    to: 240
                    stepSize: 10
                    decimals: 0
                    suffix: "px"
                    value: Number(section.tab.effect("hex").size) || 80
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: section.rootObj.s(11)
                    onValueChanged: {
                        let px = Math.round(hexSizeSelector.value);
                        if (!isNaN(px) && px >= 20 && px <= 240 && px !== Number(section.tab.effect("hex").size)) {
                            section.tab.updateEffect("hex", "size", px);
                        }
                    }
                }
            }
        ]
    }

    SettingsRow {
        rootObj: section.rootObj
        settingId: "wallpaper_transition_ink"
        icon: "󰖌"
        title: section.tab.transitionName("ink")
        description: I18n.t("guide.theme.wallpaper.transition.ink.desc", "Bloom organically across the screen like watercolor ink")
        searchKeywords: "wallpaper transition ink bleed watercolor organic bloom fluid duration speed"

        DurationSelector { tab: section.tab; transitionId: "ink" }
    }
}
