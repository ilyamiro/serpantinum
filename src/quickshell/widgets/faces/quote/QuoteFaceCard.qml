import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 120
    property real minHeight: 36
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

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) ? ThemeBackend.surface0 : "#313244"
        radius: (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined)
            ? Math.max(8, Math.min(ThemeBackend.borderRadius * 1.5, root.height / 2))
            : Math.max(8, Math.min(12, root.height / 2))
        border.width: 1
        border.color: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface1)
            ? Qt.alpha(ThemeBackend.surface1, 0.8)
            : "#45475a"
        antialiasing: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.max(10, Math.min(18, root.height * 0.25))
            anchors.rightMargin: Math.max(10, Math.min(18, root.height * 0.25))
            anchors.topMargin: Math.max(4, root.height * 0.1)
            anchors.bottomMargin: Math.max(4, root.height * 0.1)
            spacing: Math.max(8, Math.min(14, root.height * 0.2))

            Text {
                id: quoteIcon
                Layout.alignment: Qt.AlignVCenter
                text: "󰝗"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: Math.max(16, Math.min(28, root.height * 0.44))
                color: (typeof ThemeBackend !== "undefined" && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7"
                opacity: 0.95
            }

            Text {
                id: quoteLabel
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.quoteText
                font.family: (typeof ThemeBackend !== "undefined" && ThemeBackend.fontFamily) ? ThemeBackend.fontFamily : "sans-serif"
                font.pixelSize: Math.max(13, Math.min(18, root.height * 0.28))
                font.weight: Font.Normal
                font.italic: true
                color: (typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4"
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: root.height > 60 ? 3 : 2
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
