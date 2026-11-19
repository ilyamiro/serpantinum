import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "./EmojiData.js" as EmojiData

// Emoji search shared by the launcher and the clipboard. Loads the emoji
// names and keywords for the UI language from assets/emoji/<lang>.json;
// English, a missing file or invalid JSON leave the search in English.
QtObject {
    id: root

    readonly property string lang: (typeof I18n !== "undefined" && I18n.currentLang) ? I18n.currentLang : "en"
    readonly property string emojiDir: {
        if (typeof Caching !== "undefined" && Caching.serpantinumDir && Caching.serpantinumDir.length > 0) {
            return Caching.serpantinumDir + "/assets/emoji";
        }
        return Qt.resolvedUrl("../../assets/emoji").toString().replace(/^file:\/\//, "");
    }

    property FileView translationsFile: FileView {
        path: root.lang !== "en" ? (root.emojiDir + "/" + root.lang + ".json") : ""
        onLoaded: {
            let txt = typeof text === "function" ? text() : text;
            try {
                EmojiData.setTranslations(JSON.parse(txt));
            } catch (e) {
                console.warn("Invalid emoji translations for", root.lang + ":", e);
                EmojiData.setTranslations(null);
            }
        }
        onLoadFailed: EmojiData.setTranslations(null)
    }

    onLangChanged: {
        EmojiData.setTranslations(null);
        if (root.lang !== "en") translationsFile.reload();
    }

    function search(query, limit) {
        return EmojiData.search(query, limit);
    }
}
