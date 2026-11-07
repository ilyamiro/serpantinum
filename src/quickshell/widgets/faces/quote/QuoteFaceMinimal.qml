import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 30
    property real maxWidth: 2000
    property real maxHeight: 800
    property real minAspect: 1.0
    property real maxAspect: 16.0
    property bool isRound: false

    property var quoteConfig: (typeof Config !== "undefined" && typeof Config.getSetting === "function") 
        ? Config.getSetting("quote", {}) 
        : ({})

    readonly property string defaultQuote: "The only way to do great work is to love what you do."

    property string quoteText: {
        let _lang = (typeof I18n !== "undefined") ? I18n.currentLang : "";
        let _ready = (typeof I18n !== "undefined") ? I18n.isReady : false;
        if (quoteConfig && quoteConfig.text !== undefined && String(quoteConfig.text).trim() !== "") {
            return String(quoteConfig.text).trim();
        }
        if (typeof I18n !== "undefined" && _ready) {
            let tr = I18n.t("quote.default_text");
            if (tr && tr !== "quote.default_text") return tr;
        }
        return defaultQuote;
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            root.quoteConfig = Config.getSetting("quote", {});
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.max(4, root.height * 0.08)
        spacing: Math.max(6, Math.min(12, root.height * 0.18))

        Text {
            id: quoteIcon
            Layout.alignment: Qt.AlignVCenter
            text: "󰝗"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: Math.max(16, Math.min(28, root.height * 0.46))
            color: (typeof ThemeBackend !== "undefined" && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
        }

        Text {
            id: quoteLabel
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.quoteText
            font.family: (typeof ThemeBackend !== "undefined" && ThemeBackend.fontFamily) ? ThemeBackend.fontFamily : "sans-serif"
            font.pixelSize: Math.max(13, Math.min(18, root.height * 0.30))
            font.weight: Font.Normal
            font.italic: true
            color: (typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.45)
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: root.height > 60 ? 3 : 2
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }
}
