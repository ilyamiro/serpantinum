pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string i18nDir: Caching.serpantinumDir + "/assets/languages"
    property string currentLang: systemLanguage()
    property var translations: ({})
    property bool isReady: false

    signal languageChanged()

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gen = Config.getSetting("general", {});
            let lang = (gen && gen.language) ? gen.language : root.systemLanguage();
            if (lang !== root.currentLang) {
                root.currentLang = lang;
                root.languageChanged();
            }
        }
    }

    Process {
        id: i18nLoader
        command: [
            "bash",
            "-c",
            `ls "${root.i18nDir}"/*.json >/dev/null 2>&1 && jq -n 'reduce inputs as $i ( {}; . + { ($i | input_filename | split("/") | last | rtrimstr(".json")): $i } )' "${root.i18nDir}"/*.json || echo "{}"`
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt && txt.length > 0) {
                        root.translations = JSON.parse(txt);
                    } else {
                        root.translations = {};
                    }
                } catch (e) {
                    root.translations = {};
                }
                root.isReady = true;
                root.languageChanged();
            }
        }
    }

    // Regional variants that ship as their own file (e.g. pt_PT.json).
    // Checked by name because systemLanguage() runs before the files are loaded.
    readonly property var regionalLanguages: ["pt_PT"]

    function systemLanguage() {
        let name = Qt.locale().name;
        if (root.regionalLanguages.indexOf(name) !== -1) return name;
        let lang = name.split("_")[0].toLowerCase();
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
        // pt_PT -> pt -> en
        let baseLang = root.currentLang.split("_")[0];
        if (text === null && baseLang !== root.currentLang) {
            text = resolveKey(baseLang, key);
        }
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
        let gen = Config.getSetting("general", {});
        if (gen && gen.language) {
            root.currentLang = gen.language;
        }
    }
}
