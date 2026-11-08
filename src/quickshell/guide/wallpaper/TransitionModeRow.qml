import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsRow {
    id: row
    required property var tab

    readonly property string mode: row.tab.transition.mode

    rootObj: row.tab.rootObj
    settingId: "wallpaper_transition"
    icon: "󰒝"
    title: I18n.t("guide.theme.wallpaper.transition.mode.title", "Transition")
    description: I18n.t("guide.theme.wallpaper.transition.mode.desc_" + row.mode)
    searchKeywords: "wallpaper transition animation effect random custom set fade wipe circle swipe paint"

    Switch {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: rootObj.s(200)
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: rootObj.s(11)
        options: Wallpaper.transitionModes.map(m => I18n.t("guide.theme.wallpaper.transition.mode." + m))
        currentIndex: Math.max(0, Wallpaper.transitionModes.indexOf(row.mode))
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        textColor: ThemeBackend.text
        activeTextColor: ThemeBackend.crust
        onValueChanged: function(index, value) {
            row.tab.updateTransition("mode", Wallpaper.transitionModes[index]);
        }
    }

    bottomContent: GridLayout {
        id: tilesGrid
        Layout.fillWidth: true
        columns: Math.max(1, Math.min(3, Math.floor(width / rootObj.s(160))))
        columnSpacing: rootObj.s(10)
        rowSpacing: rootObj.s(10)

        Repeater {
            model: Wallpaper.transitionIds

            delegate: TransitionTile {
                required property string modelData
                tab: row.tab
                transitionId: modelData
                selected: row.mode !== "random" && row.tab.isInRotation(modelData)
                interactive: row.mode !== "random"
                onPicked: row.tab.pickTransition(modelData)
            }
        }

        Repeater {
            model: (tilesGrid.columns - Wallpaper.transitionIds.length % tilesGrid.columns) % tilesGrid.columns

            delegate: Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }
        }
    }
}
