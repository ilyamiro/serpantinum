import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "general_mute_sfx"
        searchKeywords: "sound effects sfx audio mute silent ui clicks feedback"
        icon: "󰝟"
        title: I18n.t("guide.general.mutesfx.title") || "Mute SFX"
        description: I18n.t("guide.general.mutesfx.desc") || "Disable user interface sound effects"

        Toggle {
            checked: section.tab.muteSfx
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                if (typeof Sounds !== "undefined") {
                    Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "muteSfx": c });
                }
                section.tab.setGeneralSetting("muteSfx", c);
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "general_sfx_volume"
        searchKeywords: "sound effects sfx audio volume loudness level ui clicks"
        icon: "󰕾"
        title: I18n.t("guide.general.sfxvolume.title", "SFX volume")
        description: I18n.t("guide.general.sfxvolume.desc", "Volume level for user interface sound effects")

        Draggable {
            id: sfxVolumeSlider
            Layout.rightMargin: rootObj.s(8)
            implicitWidth: rootObj.s(180)
            implicitHeight: rootObj.s(18)
            from: 0
            to: 100
            stepSize: 1
            defaultValue: 100
            showValueBubble: true
            valueFormatter: function(v) { return Math.round(v) + "%" }
            value: section.tab.sfxVolume
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                let rounded = Math.round(val);
                if (section.tab.sfxVolume !== rounded) {
                    if (typeof Sounds !== "undefined") {
                        Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "sfxVolume": rounded });
                    }
                    section.tab.setGeneralSettingDebounced("sfxVolume", rounded);
                }
            }
            onDragFinished: {
                section.tab.flushGeneralSettings();
            }
        }
    }
}
