import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: presetsTabRoot
    subTabIndex: 1

    readonly property string presetsDir: Caching.stateDir + "/presets"

    function importPreset(filePath) {
        let path = String(filePath).replace(/^file:\/\//, "");
        Quickshell.execDetached(["bash", "-c", "jq -e . \"$1\" >/dev/null && mkdir -p \"$2\" && cp -f \"$1\" \"$2/\"", "_", path, presetsDir]);
    }

    FilePicker {
        id: importPicker
        rootObj: presetsTabRoot.rootObj
        titleText: I18n.t("guide.general.presets.import.picker", "Select preset file")
        nameFilters: ["*.json"]
        onFileSelected: function(filePath, fileName) {
            presetsTabRoot.importPreset(filePath);
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SettingsRow {
                rootObj: presetsTabRoot.rootObj
                settingId: "presets_import"
                icon: "󰋺"
                title: I18n.t("guide.general.presets.import.title", "Import preset")
                description: I18n.t("guide.general.presets.import.desc", "Add a preset from a JSON file")
                searchKeywords: "presets preset import file load json"

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(32)
                    buttonText: I18n.t("guide.general.presets.import.button", "Import")
                    buttonIcon: "󰋺"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: importPicker.openWithOptionalPath("")
                }
            }
        }
    }
}
