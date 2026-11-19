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
    property string appliedPath: "-"

    // blockAllReads makes text() wait for the read, so the first search after the
    // panel opens (or after a language change) already has the translations.
    property FileView translationsFile: FileView {
        path: root.lang !== "en" ? (root.emojiDir + "/" + root.lang + ".json") : ""
        blockAllReads: true
    }

    function ensureTranslations() {
        let p = translationsFile.path;
        if (p === root.appliedPath) return;
        root.appliedPath = p;
        if (!p) {
            EmojiData.setTranslations(null);
            return;
        }
        try {
            EmojiData.setTranslations(JSON.parse(translationsFile.text()));
        } catch (e) {
            console.warn("No emoji translations for", root.lang + ":", e);
            EmojiData.setTranslations(null);
        }
    }

    function search(query, limit) {
        ensureTranslations();
        return EmojiData.search(query, limit);
    }
}
