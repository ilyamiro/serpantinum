import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"

Item {
    id: generalTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    onVisibleChanged: {
        if (!visible) {
            if (langDropdown.isOpen) langDropdown.closePopup();
            if (avatarDropdown.isOpen) avatarDropdown.closePopup();
            if (weatherUnitDropdown.isOpen) weatherUnitDropdown.closePopup();
            if (quotePosDropdown && quotePosDropdown.isOpen) quotePosDropdown.closePopup();
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
        "screenshotCaptureOnRelease": false,
        "weatherInterval": 15,
        "weatherUnit": "metric",
        "quickactions": true
    }

    property var defaultQuoteSettings: ({
        "enabled": true,
        "text": "The only way to do great work is to love what you do.",
        "lockScreenPosition": "both"
    })
    property var quoteSettings: Config.getSetting("quote", defaultQuoteSettings)
    property bool quoteEnabled: (quoteSettings && quoteSettings.enabled !== undefined) ? !!quoteSettings.enabled : true
    property string quoteText: (quoteSettings && quoteSettings.text !== undefined) ? String(quoteSettings.text) : "The only way to do great work is to love what you do."
    property string quoteLockPosition: (quoteSettings && quoteSettings.lockScreenPosition !== undefined) ? String(quoteSettings.lockScreenPosition) : "both"

    property var quoteLockPositionKeys: ["both", "clock", "dialog", "off"]
    property var quoteLockPositionLabels: [
        I18n.t("guide.general.quote.pos_both") || "Both (Clock & Avatar)",
        I18n.t("guide.general.quote.pos_clock") || "Under Clock only",
        I18n.t("guide.general.quote.pos_dialog") || "Under Avatar only",
        I18n.t("guide.general.quote.pos_off") || "Off"
    ]

    Timer {
        id: quoteDebounceTimer
        interval: 350
        repeat: false
        property string pendingText: ""
        onTriggered: {
            generalTabRoot.updateQuoteSetting("text", pendingText);
        }
    }

    function updateQuoteSetting(key, val) {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let current = Object.assign({}, Config.getSetting("quote", generalTabRoot.defaultQuoteSettings));
        current[key] = val;
        Config.setSetting("quote", current);
        generalTabRoot.quoteSettings = current;
        if (key === "enabled") generalTabRoot.quoteEnabled = val;
        if (key === "text") generalTabRoot.quoteText = val;
        if (key === "lockScreenPosition") generalTabRoot.quoteLockPosition = val;
    }

    property var generalSettings: Config.getSetting("general", defaultGeneralSettings)
    property string currentLanguage: generalSettings.language !== undefined ? generalSettings.language : I18n.currentLang
    property bool muteSfx: generalSettings.muteSfx !== undefined ? generalSettings.muteSfx : false
    property real sfxVolume: generalSettings.sfxVolume !== undefined ? generalSettings.sfxVolume : 100
    property bool screenshotCaptureOnRelease: generalSettings.screenshotCaptureOnRelease !== undefined ? generalSettings.screenshotCaptureOnRelease : false
    property bool quickactions: generalSettings.quickactions !== undefined ? generalSettings.quickactions : true
    property int weatherInterval: generalSettings.weatherInterval !== undefined ? generalSettings.weatherInterval : 15
    property string weatherUnit: generalSettings.weatherUnit !== undefined ? generalSettings.weatherUnit : "metric"
    property bool isLocEditOpen: false

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

    property var languageCodes: ["en", "ua", "ru", "de", "es", "it", "hy", "vi", "ko", "pt", "az", "ar"]
    property var languageNames: ["English","Українська", "Русский", "Deutsch", "Español", "Italiano", "Հայերեն", "Tiếng Việt", "한국어", "Português", "Azərbaycanca", "العربية"]

    property var weatherUnitCodes: ["metric", "imperial", "standard"]
    property var weatherUnitNames: ["Celsius", "Fahrenheit", "Kelvin"]

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gs = Config.getSetting("general", generalTabRoot.defaultGeneralSettings);
            generalTabRoot.currentLanguage = gs.language !== undefined ? gs.language : I18n.currentLang;
            generalTabRoot.muteSfx = gs.muteSfx !== undefined ? gs.muteSfx : false;
            generalTabRoot.sfxVolume = gs.sfxVolume !== undefined ? gs.sfxVolume : 100;
            generalTabRoot.screenshotCaptureOnRelease = gs.screenshotCaptureOnRelease !== undefined ? gs.screenshotCaptureOnRelease : false;
            generalTabRoot.quickactions = gs.quickactions !== undefined ? gs.quickactions : true;
            generalTabRoot.weatherInterval = gs.weatherInterval !== undefined ? gs.weatherInterval : 15;
            generalTabRoot.weatherUnit = gs.weatherUnit !== undefined ? gs.weatherUnit : "metric";
            generalTabRoot.generalSettings = gs;
            if (weatherIntervalSelector.value !== generalTabRoot.weatherInterval) {
                weatherIntervalSelector.value = generalTabRoot.weatherInterval;
            }

            let qs = Config.getSetting("quote", generalTabRoot.defaultQuoteSettings);
            generalTabRoot.quoteSettings = qs;
            generalTabRoot.quoteEnabled = (qs && qs.enabled !== undefined) ? !!qs.enabled : true;
            generalTabRoot.quoteText = (qs && qs.text !== undefined) ? String(qs.text) : "";
            generalTabRoot.quoteLockPosition = (qs && qs.lockScreenPosition !== undefined) ? String(qs.lockScreenPosition) : "both";
            if (quoteInput && quoteInput.text !== generalTabRoot.quoteText) {
                quoteInput.text = generalTabRoot.quoteText;
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
        current.screenshotCaptureOnRelease = generalTabRoot.screenshotCaptureOnRelease;
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

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰀄"
                title: I18n.t("guide.general.avatar.title") || "Profile picture"
                description: I18n.t("guide.general.avatar.desc") || "Choose profile picture"
                searchKeywords: "avatar profile picture photo image"

                RowLayout {
                    spacing: rootObj.s(12)

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(8)

                        ClickButton {
                            Layout.alignment: Qt.AlignRight
                            implicitHeight: rootObj.s(32)
                            buttonText: I18n.t("guide.general.avatar.select")
                            buttonIcon: "󰉋"
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(14)
                            iconFontSize: rootObj.s(15)
                            textFontSize: rootObj.s(11)
                            onTriggered: imagePicker.openPicker(generalTabRoot.currentAvatarSourcePath)
                        }

                        Dropdown {
                            id: avatarDropdown
                            Layout.alignment: Qt.AlignRight
                            implicitWidth: rootObj.s(280)
                            implicitHeight: rootObj.s(32)
                            options: generalTabRoot.currentAvatarSourcePath !== "" ? [generalTabRoot.currentAvatarSourcePath] : []
                            currentIndex: 0
                            isPathSelector: true
                            fuzzySearch: true
                            placeholderText: generalTabRoot.currentAvatarSourcePath !== "" ? generalTabRoot.currentAvatarSourcePath : "Select image path..."
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
                            onValueChanged: function(index, value) {
                                let gs = Object.assign({}, generalTabRoot.generalSettings);
                                gs.avatarPath = value;
                                generalTabRoot.generalSettings = gs;
                                generalTabRoot.updateGeneralSettings();
                            }
                            onSelected: function(index, value) {
                                let gs = Object.assign({}, generalTabRoot.generalSettings);
                                gs.avatarPath = value;
                                generalTabRoot.generalSettings = gs;
                                generalTabRoot.updateGeneralSettings();
                            }
                        }
                    }

                    Rectangle {
                        id: avatarPreviewRect
                        Layout.preferredWidth: rootObj.s(72)
                        Layout.preferredHeight: rootObj.s(72)
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.surface0
                        border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                        border.width: 1

                        Rectangle {
                            id: maskRect
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            color: "black"
                            visible: false
                            layer.enabled: true
                        }

                        Canvas {
                            id: personaCanvas
                            anchors.fill: parent
                            visible: generalTabRoot.currentAvatarSourcePath === ""
                            renderTarget: Canvas.FramebufferObject
                            renderStrategy: Canvas.Immediate

                            Connections {
                                target: ThemeBackend
                                function onSurface2Changed() { personaCanvas.requestPaint(); }
                                function onSubtext0Changed() { personaCanvas.requestPaint(); }
                                function onTextChanged() { personaCanvas.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var cx = width / 2;
                                var headRadius = width * 0.19;
                                var headCenterY = height * 0.36;

                                ctx.fillStyle = ThemeBackend.surface2;

                                ctx.beginPath();
                                ctx.arc(cx, headCenterY, headRadius, 0, Math.PI * 2);
                                ctx.fill();

                                ctx.beginPath();
                                ctx.moveTo(cx - width * 0.32, height * 0.88);
                                ctx.bezierCurveTo(cx - width * 0.28, height * 0.58, cx + width * 0.28, height * 0.58, cx + width * 0.32, height * 0.88);
                                ctx.bezierCurveTo(cx + width * 0.20, height * 0.94, cx - width * 0.20, height * 0.94, cx - width * 0.32, height * 0.88);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        Loader {
                            id: avatarLoader
                            anchors.fill: parent
                            visible: false
                            active: generalTabRoot.currentAvatarSourcePath !== ""
                            sourceComponent: Image {
                                source: generalTabRoot.currentAvatarSourcePath !== "" ? "file://" + generalTabRoot.currentAvatarSourcePath : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: avatarLoader.item
                            maskEnabled: true
                            maskSource: maskRect
                            visible: generalTabRoot.currentAvatarSourcePath !== ""
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
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
                        text: generalTabRoot.quoteText
                        leadingIcon: "󰝗"
                        showClearButton: true
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(12)
                        onTextEdited: function(newText) {
                            quoteDebounceTimer.pendingText = newText;
                            quoteDebounceTimer.restart();
                        }
                        onAccepted: function(finalText) {
                            quoteDebounceTimer.stop();
                            generalTabRoot.updateQuoteSetting("text", finalText);
                        }
                    }
                ]
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
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

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰗊"
                title: I18n.t("guide.general.language.title")
                description: I18n.t("guide.general.language.desc")

                Dropdown {
                    id: langDropdown
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    options: generalTabRoot.languageNames
                    currentIndex: {
                        let idx = generalTabRoot.languageCodes.indexOf(generalTabRoot.currentLanguage);
                        return idx !== -1 ? idx : 0;
                    }
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        generalTabRoot.currentLanguage = generalTabRoot.languageCodes[index];
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󱓞"
                title: I18n.t("guide.general.quickactions.title") || "Quickactions"
                description: I18n.t("guide.general.quickactions.desc") || "Enable floating quickactions overlay"

                Toggle {
                    checked: generalTabRoot.quickactions
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.quickactions = c;
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰝟"
                title: I18n.t("guide.general.mutesfx.title") || "Mute SFX"
                description: I18n.t("guide.general.mutesfx.desc") || "Disable user interface sound effects"

                Toggle {
                    checked: generalTabRoot.muteSfx
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.muteSfx = c;
                        if (typeof Sounds !== "undefined") {
                            Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "muteSfx": c });
                        }
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰕾"
                title: I18n.t("guide.general.sfxvolume.title") || "SFX Volume"
                description: I18n.t("guide.general.sfxvolume.desc") || "Volume level for user interface sound effects"

                Draggable {
                    id: sfxVolumeSlider
                    Layout.rightMargin: rootObj.s(8)
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(18)
                    from: 0
                    to: 100
                    stepSize: 1
                    defaultValue: 100
                    showValueBubble: true
                    valueFormatter: function(v) { return Math.round(v) + "%" }
                    value: generalTabRoot.sfxVolume
                    backgroundColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    handleColor: ThemeBackend.text
                    handleBorderColor: ThemeBackend.mantle
                    onMoved: function(val) {
                        let rounded = Math.round(val);
                        if (generalTabRoot.sfxVolume !== rounded) {
                            generalTabRoot.sfxVolume = rounded;
                            if (typeof Sounds !== "undefined") {
                                Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "sfxVolume": rounded });
                            }
                            sfxVolumeDebounceTimer.restart();
                        }
                    }
                    onDragFinished: {
                        sfxVolumeDebounceTimer.stop();
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰍎"
                title: I18n.t("guide.general.location.title")
                description: I18n.t("guide.general.location.desc")
                searchKeywords: "location coordinates city latitude longitude gps"
                showDivider: generalTabRoot.isLocEditOpen
                dividerColor: Qt.alpha(ThemeBackend.surface1, 0.2)
                innerSpacing: generalTabRoot.isLocEditOpen ? rootObj.s(12) : 0
                Behavior on innerSpacing { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                animateHeight: true
                animationDuration: 300

                LoaderIcon {
                    id: detectLoader
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    running: Location.isDetecting
                    visible: Location.isDetecting
                    accentColor: ThemeBackend.mauve
                }

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: "Auto-detect"
                    buttonIcon: "󰢹"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        generalTabRoot.isLocEditOpen = false;
                        Location.detectAuto();
                    }
                }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰏫"
                    iconFontSize: rootObj.s(16)
                    accentColor: generalTabRoot.isLocEditOpen ? ThemeBackend.surface1 : ThemeBackend.surface0
                    textColor: generalTabRoot.isLocEditOpen ? ThemeBackend.mauve : ThemeBackend.text
                    onClicked: generalTabRoot.isLocEditOpen = !generalTabRoot.isLocEditOpen
                }

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: Location.city
                    buttonIcon: "󰍎"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: locationPopup.open()
                }

                bottomContent: [
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(12)
                        visible: generalTabRoot.isLocEditOpen || opacity > 0.01
                        opacity: generalTabRoot.isLocEditOpen ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Input {
                            id: latInput
                            Layout.fillWidth: true
                            placeholderText: "Latitude"
                            text: Location.latitude !== 0.0 ? Location.latitude.toString() : (Location.locationData.latitude !== undefined ? Location.locationData.latitude.toString() : "")
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(12)
                            verticalPadding: rootObj.s(6)
                            fontPixelSize: rootObj.s(12)
                        }

                        Input {
                            id: lonInput
                            Layout.fillWidth: true
                            placeholderText: "Longitude"
                            text: Location.longitude !== 0.0 ? Location.longitude.toString() : (Location.locationData.longitude !== undefined ? Location.locationData.longitude.toString() : "")
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(12)
                            verticalPadding: rootObj.s(6)
                            fontPixelSize: rootObj.s(12)
                        }

                        ClickButton {
                            Layout.preferredHeight: rootObj.s(32)
                            buttonText: "Apply"
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(16)
                            textFontSize: rootObj.s(12)
                            onTriggered: {
                                Location.setManual(latInput.text, lonInput.text);
                            }
                        }
                    }
                ]
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰔛"
                title: I18n.t("guide.general.weatherinterval.title") || "Weather Polling Interval"
                description: I18n.t("guide.general.weatherinterval.desc") || "Polling frequency in minutes"

                NumberSelector {
                    id: weatherIntervalSelector
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    from: 1
                    to: 1440
                    stepSize: 1
                    decimals: 0
                    suffix: " min"
                    value: generalTabRoot.weatherInterval
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: {
                        let val = Math.round(value);
                        if (val !== generalTabRoot.weatherInterval && val >= 1) {
                            generalTabRoot.weatherInterval = val;
                            generalTabRoot.updateGeneralSettings();
                            if (typeof Weather !== "undefined") {
                                Weather.refreshInterval = generalTabRoot.weatherInterval * 60000;
                            }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰔏"
                title: I18n.t("guide.general.weatherunit.title") || "Weather Unit"
                description: I18n.t("guide.general.weatherunit.desc") || "Temperature scale for weather displays"

                Dropdown {
                    id: weatherUnitDropdown
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    options: generalTabRoot.weatherUnitNames
                    currentIndex: {
                        let idx = generalTabRoot.weatherUnitCodes.indexOf(generalTabRoot.weatherUnit);
                        return idx !== -1 ? idx : 0;
                    }
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        generalTabRoot.weatherUnit = generalTabRoot.weatherUnitCodes[index];
                        generalTabRoot.updateGeneralSettings();
                        if (typeof Weather !== "undefined") {
                            Weather.unit = generalTabRoot.weatherUnit;
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰹑"
                title: I18n.t("guide.general.screenshot_on_release.title") || "Capture region on mouse release"
                description: I18n.t("guide.general.screenshot_on_release.desc") || "Take the screenshot as soon as you finish dragging, without clicking the shutter"

                Toggle {
                    checked: generalTabRoot.screenshotCaptureOnRelease
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.screenshotCaptureOnRelease = c;
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰆏"
                title: I18n.t("guide.general.copysettings.title") || "Copy settings"
                description: I18n.t("guide.general.copysettings.desc") || "Copy configuration JSON to clipboard"

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: "Copy settings"
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
