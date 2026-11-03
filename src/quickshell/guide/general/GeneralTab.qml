import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: generalTabRoot

    onVisibleChanged: {
        if (!visible) {
            if (langDropdown.isOpen) langDropdown.closePopup();
            if (avatarDropdown.isOpen) avatarDropdown.closePopup();
            if (weatherUnitDropdown.isOpen) weatherUnitDropdown.closePopup();
            locationPopup.close();
            isLocEditOpen = false;
        }
    }

    property var defaultGeneralSettings: {
        "language": "en",
        "openGuideAtStartup": false,
        "wallpaperDir": "",
        "workspaceCount": 8,
        "avatarPath": "",
        "muteSfx": false,
        "sfxVolume": 100,
        "weatherInterval": 15,
        "weatherUnit": "metric",
        "quickactions": true
    }

    property var generalSettings: Config.getSetting("general", defaultGeneralSettings)
    property string currentLanguage: generalSettings.language !== undefined ? generalSettings.language : I18n.currentLang
    property bool muteSfx: generalSettings.muteSfx !== undefined ? generalSettings.muteSfx : false
    property real sfxVolume: generalSettings.sfxVolume !== undefined ? generalSettings.sfxVolume : 100
    property bool quickactions: generalSettings.quickactions !== undefined ? generalSettings.quickactions : true
    property int weatherInterval: generalSettings.weatherInterval !== undefined ? generalSettings.weatherInterval : 15
    property string weatherUnit: generalSettings.weatherUnit !== undefined ? generalSettings.weatherUnit : "metric"
    property bool isLocEditOpen: false

    property alias langDropdown: profileSection.langDropdown
    property alias avatarDropdown: profileSection.avatarDropdown
    property alias weatherUnitDropdown: locationSection.weatherUnitDropdown
    property alias weatherIntervalSelector: locationSection.weatherIntervalSelector
    property alias latInput: locationSection.latInput
    property alias lonInput: locationSection.lonInput
    property alias imagePicker: imagePicker
    property alias locationPopup: locationPopup
    property alias sfxVolumeDebounceTimer: sfxVolumeDebounceTimer

    Timer {
        id: sfxVolumeDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            generalTabRoot.updateGeneralSettings();
        }
    }

    property string currentAvatarSourcePath: {
        let saved = (generalSettings && generalSettings.avatarPath !== undefined) ? generalSettings.avatarPath : "";
        let path = saved !== "" ? saved : (SystemInfo.avatarPath || "");
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        return path;
    }

    property var languageCodes: ["en", "fr", "ua", "ru", "de", "es", "it", "hy", "vi", "ko", "pt", "az", "ar", "ja", "zh", "zh_tw", "pl", "tr", "id", "nl", "fa", "hi", "bg"]
    property var languageNames: ["English", "Français", "Українська", "Русский", "Deutsch", "Español", "Italiano", "Հայերեն", "Tiếng Việt", "한국어", "Português", "Azərbaycanca", "العربية", "日本語", "简体中文", "繁體中文", "Polski", "Türkçe", "Bahasa Indonesia", "Nederlands", "فارسی", "हिन्दी", "Български"]

    property var weatherUnitCodes: ["metric", "imperial", "standard"]
    property var weatherUnitNames: ["Celsius", "Fahrenheit", "Kelvin"]

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gs = Config.getSetting("general", generalTabRoot.defaultGeneralSettings);
            generalTabRoot.currentLanguage = gs.language !== undefined ? gs.language : I18n.currentLang;
            generalTabRoot.muteSfx = gs.muteSfx !== undefined ? gs.muteSfx : false;
            generalTabRoot.sfxVolume = gs.sfxVolume !== undefined ? gs.sfxVolume : 100;
            generalTabRoot.quickactions = gs.quickactions !== undefined ? gs.quickactions : true;
            generalTabRoot.weatherInterval = gs.weatherInterval !== undefined ? gs.weatherInterval : 15;
            generalTabRoot.weatherUnit = gs.weatherUnit !== undefined ? gs.weatherUnit : "metric";
            generalTabRoot.generalSettings = gs;
            if (weatherIntervalSelector.value !== generalTabRoot.weatherInterval) {
                weatherIntervalSelector.value = generalTabRoot.weatherInterval;
            }
        }
    }

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

    function updateGeneralSettings() {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let current = Object.assign({}, Config.getSetting("general", generalTabRoot.defaultGeneralSettings));
        current.language = generalTabRoot.currentLanguage;
        current.avatarPath = generalTabRoot.currentAvatarSourcePath;
        current.muteSfx = generalTabRoot.muteSfx;
        current.sfxVolume = generalTabRoot.sfxVolume;
        current.quickactions = generalTabRoot.quickactions;
        current.weatherInterval = generalTabRoot.weatherInterval;
        current.weatherUnit = generalTabRoot.weatherUnit;
        Config.setSetting("general", current);
    }

    ImagePicker {
        id: imagePicker
        rootObj: generalTabRoot.rootObj
        onImageSelected: function(filePath, fileName) {
            let gs = Object.assign({}, generalTabRoot.generalSettings);
            gs.avatarPath = filePath;
            generalTabRoot.generalSettings = gs;
            generalTabRoot.updateGeneralSettings();
        }
    }

    LocationInfo {
        id: locationPopup
        rootObj: generalTabRoot.rootObj
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            GeneralProfileSection { id: profileSection; tab: generalTabRoot }

            GeneralAudioSection { tab: generalTabRoot }

            GeneralBehaviorSection { tab: generalTabRoot }

            GeneralLocationSection { id: locationSection; tab: generalTabRoot }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰆏"
                title: I18n.t("guide.general.copysettings.title") || "Copy settings"
                description: I18n.t("guide.general.copysettings.desc") || "Copy configuration JSON to clipboard"

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: I18n.t("guide.general.copysettings.title") || "Copy settings"
                    buttonIcon: "󰆏"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-c", "cat \"" + Config.settingsJsonPath + "\" | wl-copy"]);
                    }
                }
            }
        }
    }
}
