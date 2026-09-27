import QtQuick
import QtQuick.Layouts
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: generalTabRoot

    onVisibleChanged: {
        if (!visible) {
            generalCfg.flush();
            quoteCfg.flush();
            if (langDropdown.isOpen) langDropdown.closePopup();
            if (avatarDropdown.isOpen) avatarDropdown.closePopup();
            if (locationPopupLoader.item) locationPopupLoader.item.close();
            if (quotePosDropdown && quotePosDropdown.isOpen) quotePosDropdown.closePopup();
            isLocEditOpen = false;
        }
    }

    ConfigSection {
        id: generalCfg
        section: "general"
        defaults: ({
            "language": "en",
            "openGuideAtStartup": false,
            "wallpaperDir": "",
            "workspaceCount": 8,
            "avatarPath": "",
            "muteSfx": false,
            "sfxVolume": 100,
            "quickactions": true,
            "dailyPing": true
        })
    }

    ConfigSection {
        id: quoteCfg
        section: "quote"
        defaults: ({
            "enabled": true,
            "text": "The only way to do great work is to love what you do.",
            "lockScreenPosition": "both"
        })
    }

    readonly property var generalSettings: generalCfg.values
    readonly property string currentLanguage: generalSettings.language !== undefined ? String(generalSettings.language) : I18n.currentLang
    readonly property bool muteSfx: Boolean(generalSettings.muteSfx !== undefined ? generalSettings.muteSfx : false)
    readonly property real sfxVolume: Number(generalSettings.sfxVolume !== undefined ? generalSettings.sfxVolume : 100)
    readonly property bool quickactions: Boolean(generalSettings.quickactions !== undefined ? generalSettings.quickactions : true)
    readonly property bool dailyPing: Boolean(generalSettings.dailyPing !== undefined ? generalSettings.dailyPing : true)

    readonly property var quoteSettings: quoteCfg.values
    readonly property bool quoteEnabled: quoteSettings.enabled !== undefined ? Boolean(quoteSettings.enabled) : true
    readonly property string quoteText: quoteSettings.text !== undefined ? String(quoteSettings.text) : "The only way to do great work is to love what you do."
    readonly property string quoteLockPosition: quoteSettings.lockScreenPosition !== undefined ? String(quoteSettings.lockScreenPosition) : "both"

    onQuoteTextChanged: {
        if (quoteInput && !quoteInput.activeFocus && quoteInput.text !== generalTabRoot.quoteText) {
            quoteInput.text = generalTabRoot.quoteText;
        }
    }

    property var quoteLockPositionKeys: ["both", "clock", "dialog", "off"]
    property var quoteLockPositionLabels: [
        I18n.t("guide.general.quote.pos_both") || "Both (Clock & Avatar)",
        I18n.t("guide.general.quote.pos_clock") || "Under Clock only",
        I18n.t("guide.general.quote.pos_dialog") || "Under Avatar only",
        I18n.t("guide.general.quote.pos_off") || "Off"
    ]

    function updateQuoteSetting(key, val) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        quoteCfg.set(key, val);
    }

    function updateQuoteSettingDebounced(key, val) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        quoteCfg.setDebounced(key, val, 350);
    }

    property bool isLocEditOpen: false

    property alias langDropdown: profileSection.langDropdown
    property alias avatarDropdown: profileSection.avatarDropdown
    property alias latInput: locationSection.latInput
    property alias lonInput: locationSection.lonInput

    readonly property string currentAvatarSourcePath: {
        let saved = (generalSettings && generalSettings.avatarPath !== undefined) ? String(generalSettings.avatarPath) : "";
        let path = saved !== "" ? saved : (SystemInfo.avatarPath || "");
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        return path;
    }

    readonly property var languageCodes: I18n.languageCodes
    readonly property var languageNames: I18n.languageNames

    Connections {
        target: Location
        function onLocationUpdated() {
            if (Location.locationData && Location.locationData.latitude !== undefined) {
                latInput.text = Location.locationData.latitude.toString();
            }
            if (Location.locationData && Location.locationData.longitude !== undefined) {
                lonInput.text = Location.locationData.longitude.toString();
            }
        }
    }

    function setGeneralSetting(key, value) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        generalCfg.set(key, value);
    }

    function setGeneralSettingDebounced(key, value) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        generalCfg.setDebounced(key, value, 100);
    }

    function flushGeneralSettings() {
        generalCfg.flush();
    }

    function openImagePicker(initialPath) {
        imagePickerLoader.active = true;
        imagePickerLoader.item.openPicker(initialPath);
    }

    function openLocationPopup() {
        locationPopupLoader.active = true;
        locationPopupLoader.item.open();
    }

    Loader {
        id: imagePickerLoader
        active: false
        sourceComponent: ImagePicker {
            rootObj: generalTabRoot.rootObj
            onImageSelected: function(filePath, fileName) {
                generalTabRoot.setGeneralSetting("avatarPath", filePath);
            }
        }
    }

    Loader {
        id: locationPopupLoader
        active: false
        sourceComponent: LocationInfo {
            rootObj: generalTabRoot.rootObj
        }
    }

    GuideScrollView {
        rootObj: generalTabRoot.rootObj

        GeneralProfileSection { id: profileSection; tab: generalTabRoot }

        GeneralAudioSection { tab: generalTabRoot }

        GeneralBehaviorSection { tab: generalTabRoot }

        GeneralTimeSection { tab: generalTabRoot }

        GeneralLocationSection { id: locationSection; tab: generalTabRoot }

        GeneralTelemetrySection { tab: generalTabRoot }

        SettingsBlob {
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                settingId: "general_quote"
                searchKeywords: "quote motto lock screen widget text"
                icon: "󰝗"
                title: I18n.t("guide.general.quote.title") || "Motto & Quote"
                description: I18n.t("guide.general.quote.desc") || "Display a personal quote on lock screen and desktop widget"

                Toggle {
                    checked: generalTabRoot.quoteEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.updateQuoteSetting("enabled", c);
                    }
                }

                bottomContent: [
                    Input {
                        id: quoteInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(34)
                        enabled: generalTabRoot.quoteEnabled
                        opacity: generalTabRoot.quoteEnabled ? 1.0 : 0.5
                        placeholderText: I18n.t("guide.general.quote.placeholder") || "Enter your quote or motto..."
                        leadingIcon: "󰝗"
                        showClearButton: true
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(12)
                        Component.onCompleted: text = generalTabRoot.quoteText
                        onTextEdited: function(newText) {
                            generalTabRoot.updateQuoteSettingDebounced("text", newText);
                        }
                        onAccepted: function(finalText) {
                            generalTabRoot.updateQuoteSetting("text", finalText);
                        }
                        onCleared: {
                            generalTabRoot.updateQuoteSetting("text", "");
                        }
                    }
                ]
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                settingId: "general_quote_lock_position"
                searchKeywords: "quote motto lock screen position clock avatar dialog"
                icon: "󰌾"
                title: I18n.t("guide.general.quote.lock_position.title") || "Lock screen quote position"
                description: I18n.t("guide.general.quote.lock_position.desc") || "Select where the quote appears on the lock screen"

                Dropdown {
                    id: quotePosDropdown
                    implicitWidth: rootObj.s(210)
                    implicitHeight: rootObj.s(32)
                    options: generalTabRoot.quoteLockPositionLabels
                    currentIndex: Math.max(0, generalTabRoot.quoteLockPositionKeys.indexOf(generalTabRoot.quoteLockPosition))
                    fontFamily: ThemeBackend.fontFamily
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onSelected: function(index, value) {
                        if (index >= 0 && index < generalTabRoot.quoteLockPositionKeys.length) {
                            generalTabRoot.updateQuoteSetting("lockScreenPosition", generalTabRoot.quoteLockPositionKeys[index]);
                        }
                    }
                }
            }
        }
    }
}
