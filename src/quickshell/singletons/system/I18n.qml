pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string i18nDir: {
        if (typeof Caching !== "undefined" && Caching.serpantinumDir && Caching.serpantinumDir.length > 0) {
            return Caching.serpantinumDir + "/assets/languages";
        }
        return Qt.resolvedUrl("../../../assets/languages").toString().replace(/^file:\/\//, "");
    }
    property string currentLang: systemLanguage()
    readonly property var rtlLanguages: ["ar", "fa", "ur", "he", "iw", "ps", "ug", "ckb", "yi"]
    readonly property bool rtl: rtlLanguages.indexOf(currentLang) !== -1
    readonly property bool isRtl: rtl
    readonly property bool isRTL: rtl
    readonly property int layoutDirection: rtl ? Qt.RightToLeft : Qt.LeftToRight
    readonly property int textAlignment: rtl ? Text.AlignRight : Text.AlignLeft
    readonly property int horizontalAlignment: rtl ? Qt.AlignRight : Qt.AlignLeft
    property var translations: ({})
    property bool isReady: false
    property var fallbackData: null
    property var langData: null

    signal languageChanged()

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gen = Config.getSetting("general", {});
            let lang = (gen && gen.language) ? gen.language : root.systemLanguage();
            if (lang !== root.currentLang) {
                root.currentLang = lang;
            }
        }
    }

    FileView {
        id: fallbackFileView
        path: root.i18nDir + "/en.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = typeof text === "function" ? text() : text;
            if (txt && txt.trim().length > 0) {
                try {
                    root.fallbackData = JSON.parse(txt);
                    root.updateTranslations();
                } catch(e) {}
            }
        }
    }

    FileView {
        id: langFileView
        path: root.currentLang !== "en" ? (root.i18nDir + "/" + root.currentLang + ".json") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = typeof text === "function" ? text() : text;
            if (txt && txt.trim().length > 0) {
                try {
                    root.langData = JSON.parse(txt);
                    root.updateTranslations();
                } catch(e) {}
            }
        }
    }

    function updateTranslations() {
        if (!root.fallbackData && (root.currentLang === "en" || !root.langData)) {
            return;
        }

        let newTrans = Object.assign({}, root.translations);
        if (root.fallbackData) {
            newTrans["en"] = root.fallbackData;
        }
        if (root.currentLang !== "en" && root.langData) {
            newTrans[root.currentLang] = root.langData;
        }

        root.translations = newTrans;
        if (!root.isReady) {
            root.isReady = true;
        }
        root.languageChanged();
    }

    onCurrentLangChanged: {
        root.langData = null;
        if (root.currentLang !== "en") {
            langFileView.path = root.i18nDir + "/" + root.currentLang + ".json";
            langFileView.reload();
        } else {
            langFileView.path = "";
            root.updateTranslations();
        }
    }

    function systemLanguage() {
        let lang = Qt.locale().name.split("_")[0].toLowerCase();
        // Ukrainian ships as ua.json, not the ISO 639-1 "uk"
        return lang === "uk" ? "ua" : lang;
    }

    function resolveKey(lang, key) {
        if (!root.translations || !root.translations[lang]) return null;

        let parts = key.split('.');
        let current = root.translations[lang];

        for (let i = 0; i < parts.length; i++) {
            if (current === null || current === undefined || current[parts[i]] === undefined) {
                return null;
            }
            current = current[parts[i]];
        }

        return typeof current === "string" ? current : null;
    }

    function t(key, args) {
        if (!root.isReady) return key;

        let text = resolveKey(root.currentLang, key);
        if (text === null && root.currentLang !== "en") {
            text = resolveKey("en", key);
        }

        if (text === null) return key;

        if (args && typeof args === "object") {
            for (let k in args) {
                text = text.replace(new RegExp("\\{" + k + "\\}", "g"), args[k]);
            }
        }

        return text;
    }

    Component.onCompleted: {
        try {
            Object.defineProperty(root, "RTL", {
                get: () => root.rtl,
                configurable: true
            });
        } catch(e) {}
        let gen = Config.getSetting("general", {});
        if (gen && gen.language) {
            root.currentLang = gen.language;
        }
        fallbackFileView.reload();
        if (root.currentLang !== "en") {
            langFileView.reload();
        }
        let fb = typeof fallbackFileView.text === "function" ? fallbackFileView.text() : fallbackFileView.text;
        if (fb && fb.trim().length > 0) {
            try {
                root.fallbackData = JSON.parse(fb);
            } catch(e) {}
        }
        if (root.currentLang !== "en") {
            let lt = typeof langFileView.text === "function" ? langFileView.text() : langFileView.text;
            if (lt && lt.trim().length > 0) {
                try {
                    root.langData = JSON.parse(lt);
                } catch(e) {}
            }
        }
        root.updateTranslations();
    }
}
