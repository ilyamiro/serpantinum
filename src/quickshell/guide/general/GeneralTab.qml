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
            if (langDropdown.isOpen) langDropdown.closePopup();
            if (avatarDropdown.isOpen) avatarDropdown.closePopup();
            if (locationPopupLoader.item) locationPopupLoader.item.close();
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

    readonly property var generalSettings: generalCfg.values
    readonly property string currentLanguage: generalSettings.language !== undefined ? String(generalSettings.language) : I18n.currentLang
    readonly property bool muteSfx: Boolean(generalSettings.muteSfx !== undefined ? generalSettings.muteSfx : false)
    readonly property real sfxVolume: Number(generalSettings.sfxVolume !== undefined ? generalSettings.sfxVolume : 100)
    readonly property bool quickactions: Boolean(generalSettings.quickactions !== undefined ? generalSettings.quickactions : true)
    readonly property bool dailyPing: Boolean(generalSettings.dailyPing !== undefined ? generalSettings.dailyPing : true)
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
    }
}
