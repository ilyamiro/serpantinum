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
        icon: "󰝟"
        title: I18n.t("guide.general.mutesfx.title") || "Mute SFX"
        description: I18n.t("guide.general.mutesfx.desc") || "Disable user interface sound effects"

        Toggle {
            checked: section.tab.muteSfx
            accentColor: ThemeBackend.accent
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.muteSfx = c;
                if (typeof Sounds !== "undefined") {
                    Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "muteSfx": c });
                }
                section.tab.updateGeneralSettings();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰕾"
        title: I18n.t("guide.general.sfxvolume.title") || "SFX Volume"
        description: I18n.t("guide.general.sfxvolume.desc") || "Volume level for user interface sound effects"

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
            accentColor: ThemeBackend.accent
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                let rounded = Math.round(val);
                if (section.tab.sfxVolume !== rounded) {
                    section.tab.sfxVolume = rounded;
                    if (typeof Sounds !== "undefined") {
                        Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "sfxVolume": rounded });
                    }
                    section.tab.sfxVolumeDebounceTimer.restart();
                }
            }
            onDragFinished: {
                section.tab.sfxVolumeDebounceTimer.stop();
                section.tab.updateGeneralSettings();
            }
        }
    }
}
