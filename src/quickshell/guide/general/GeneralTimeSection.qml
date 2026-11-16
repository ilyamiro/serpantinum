import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    property string timeFormat: "HH:mm:ss"

    function load() {
        let bs = Config.getSetting("bar", {});
        section.timeFormat = bs && bs.time && bs.time.format !== undefined ? bs.time.format : "HH:mm:ss";
    }

    function save(fmt) {
        section.timeFormat = fmt;
        let current = Config.getSetting("bar", {});
        if (!current.time) current.time = {};
        current.time.format = fmt;
        Config.setSetting("bar", current);
    }

    Component.onCompleted: load()

    Connections {
        target: Config
        function onSettingsLoaded() { section.load(); }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰅐"
        title: I18n.t("guide.bar.time.title", "Time format")
        description: I18n.t("guide.bar.time.desc", "Format pattern (e.g. HH:mm:ss)")

        Input {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: rootObj.s(140)
            implicitHeight: rootObj.s(32)
            text: section.timeFormat
            placeholderText: "HH:mm:ss"
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onTextEdited: function(newText) { section.save(newText); }
            onAccepted: function(finalText) { section.save(finalText); }
        }
    }
}
