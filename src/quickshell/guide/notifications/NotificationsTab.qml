import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: notificationsTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property bool selectorOpen: false
    property bool gridEnabled: false
    property bool showBarBox: true

    readonly property int presetTopV: screenSelector ? screenSelector.safeTopPercent : 5
    readonly property int presetBottomV: screenSelector ? screenSelector.safeBottomPercent : 95
    readonly property int presetLeftH: screenSelector ? screenSelector.safeLeftPercent : 5
    readonly property int presetRightH: screenSelector ? screenSelector.safeRightPercent : 95
    readonly property int presetCenterH: 50

    onPresetTopVChanged: {
        if (position !== "custom" && position.indexOf("top") !== -1) {
            verticalPosition = presetTopV;
            if (screenSelector) screenSelector.verticalPosition = presetTopV;
        }
    }
    onPresetBottomVChanged: {
        if (position !== "custom" && position.indexOf("bottom") !== -1) {
            verticalPosition = presetBottomV;
            if (screenSelector) screenSelector.verticalPosition = presetBottomV;
        }
    }
    onPresetLeftHChanged: {
        if (position !== "custom" && position.indexOf("left") !== -1) {
            horizontalPosition = presetLeftH;
            if (screenSelector) screenSelector.horizontalPosition = presetLeftH;
        }
    }
    onPresetRightHChanged: {
        if (position !== "custom" && position.indexOf("right") !== -1) {
            horizontalPosition = presetRightH;
            if (screenSelector) screenSelector.horizontalPosition = presetRightH;
        }
    }

    property var defaultNotificationSettings: ({
        "dnd": false,
        "position": "top right",
        "horizontalPosition": presetRightH,
        "verticalPosition": presetTopV,
        "sound": true,
        "soundFile": "",
        "showEmptyGraphic": true
    })

    property var notifSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["notifications"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("notifications", notificationsTabRoot.defaultNotificationSettings);
        }
        return notificationsTabRoot.defaultNotificationSettings;
    }

    property bool dnd: notifSettings && notifSettings.dnd !== undefined ? notifSettings.dnd : false
    property string position: notifSettings && notifSettings.position !== undefined ? notifSettings.position : "top right"
    property int horizontalPosition: {
        if (position !== "custom") {
            if (position.indexOf("left") !== -1) return presetLeftH;
            if (position.indexOf("center") !== -1) return presetCenterH;
            return presetRightH;
        }
        if (notifSettings && notifSettings.horizontalPosition !== undefined) return notifSettings.horizontalPosition;
        return presetRightH;
    }
    property int verticalPosition: {
        if (position !== "custom") {
            if (position.indexOf("bottom") !== -1) return presetBottomV;
            return presetTopV;
        }
        if (notifSettings && notifSettings.verticalPosition !== undefined) return notifSettings.verticalPosition;
        return presetTopV;
    }
    property bool soundEnabled: notifSettings && notifSettings.sound !== undefined ? notifSettings.sound : true
    property string selectedSound: notifSettings && notifSettings.soundFile !== undefined ? notifSettings.soundFile : ""
    property bool showEmptyGraphic: notifSettings && notifSettings.showEmptyGraphic !== undefined ? notifSettings.showEmptyGraphic : true

    function getPresetIndex(h, v) {
        if (Math.abs(v - presetTopV) <= 2 && Math.abs(h - presetRightH) <= 2) return 0;
        if (Math.abs(v - presetTopV) <= 2 && Math.abs(h - presetCenterH) <= 2) return 1;
        if (Math.abs(v - presetTopV) <= 2 && Math.abs(h - presetLeftH) <= 2) return 2;
        if (Math.abs(v - presetBottomV) <= 2 && Math.abs(h - presetRightH) <= 2) return 3;
        if (Math.abs(v - presetBottomV) <= 2 && Math.abs(h - presetCenterH) <= 2) return 4;
        if (Math.abs(v - presetBottomV) <= 2 && Math.abs(h - presetLeftH) <= 2) return 5;
        return -1;
    }

    function getPosStringFromIndex(index) {
        if (index === 0) return "top right";
        if (index === 1) return "top center";
        if (index === 2) return "top left";
        if (index === 3) return "bottom right";
        if (index === 4) return "bottom center";
        if (index === 5) return "bottom left";
        return "custom";
    }

    readonly property bool isCustomPos: {
        if (position === "custom") return true;
        let validPresets = ["top right", "top center", "top left", "bottom right", "bottom center", "bottom left"];
        return validPresets.indexOf(position) === -1;
    }

    onIsCustomPosChanged: {
        if (isCustomPos) {
            posDropdown.currentIndex = -1;
        }
    }

    property var soundList: []
    property var availableSounds: {
        let names = [];
        for (let i = 0; i < soundList.length; i++) {
            names.push(soundList[i].name);
        }
        return names;
    }

    function applyPosition(h, v, posStr) {
        notificationsTabRoot.horizontalPosition = h;
        notificationsTabRoot.verticalPosition = v;
        notificationsTabRoot.position = posStr;
        if (screenSelector) {
            screenSelector.horizontalPosition = h;
            screenSelector.verticalPosition = v;
        }
        debounceTimer.restart();
    }

    function setPosFromIndex(index) {
        if (index === 0) applyPosition(presetRightH, presetTopV, "top right");
        else if (index === 1) applyPosition(presetCenterH, presetTopV, "top center");
        else if (index === 2) applyPosition(presetLeftH, presetTopV, "top left");
        else if (index === 3) applyPosition(presetRightH, presetBottomV, "bottom right");
        else if (index === 4) applyPosition(presetCenterH, presetBottomV, "bottom center");
        else if (index === 5) applyPosition(presetLeftH, presetBottomV, "bottom left");
    }

    function updateNotifSetting(key, val) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", defaultNotificationSettings) || defaultNotificationSettings));
        current[key] = val;
        Config.setSetting("notifications", current);
        notificationsTabRoot.notifSettings = current;
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("notifications", notificationsTabRoot.defaultNotificationSettings)
            : notificationsTabRoot.defaultNotificationSettings;
        notificationsTabRoot.dnd = s.dnd !== undefined ? s.dnd : false;
        notificationsTabRoot.position = s.position !== undefined ? s.position : "top right";
        if (notificationsTabRoot.position !== "custom") {
            notificationsTabRoot.horizontalPosition = notificationsTabRoot.position.indexOf("left") !== -1 ? presetLeftH : (notificationsTabRoot.position.indexOf("center") !== -1 ? presetCenterH : presetRightH);
            notificationsTabRoot.verticalPosition = notificationsTabRoot.position.indexOf("bottom") !== -1 ? presetBottomV : presetTopV;
        } else {
            notificationsTabRoot.horizontalPosition = s.horizontalPosition !== undefined ? s.horizontalPosition : presetRightH;
            notificationsTabRoot.verticalPosition = s.verticalPosition !== undefined ? s.verticalPosition : presetTopV;
        }
        if (screenSelector) {
            screenSelector.horizontalPosition = notificationsTabRoot.horizontalPosition;
            screenSelector.verticalPosition = notificationsTabRoot.verticalPosition;
        }
        notificationsTabRoot.soundEnabled = s.sound !== undefined ? s.sound : true;
        notificationsTabRoot.selectedSound = s.soundFile !== undefined ? s.soundFile : "";
        notificationsTabRoot.showEmptyGraphic = s.showEmptyGraphic !== undefined ? s.showEmptyGraphic : true;
        notificationsTabRoot.notifSettings = s;
    }

    Timer {
        id: debounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", defaultNotificationSettings) || defaultNotificationSettings));
            current.horizontalPosition = notificationsTabRoot.horizontalPosition;
            current.verticalPosition = notificationsTabRoot.verticalPosition;
            current.position = notificationsTabRoot.position;
            Config.setSetting("notifications", current);
            notificationsTabRoot.notifSettings = current;
        }
    }

    function reloadSounds() {
        soundsLoader.running = false;
        soundsLoader.running = true;
    }

    Process {
        id: soundsLoader
        running: false
        command: {
            let assetsPath = Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/sounds/notifications") : (Caching.qsDir ? (Caching.qsDir + "/../assets/sounds/notifications") : "");
            let userPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/serpantinum/sounds/notifications");
            let script =
                "mkdir -p \"" + userPath + "\"; " +
                "python3 -c '\n" +
                "import os, json, sys\n" +
                "assets = sys.argv[1]\n" +
                "user = sys.argv[2]\n" +
                "exts = (\".wav\", \".ogg\", \".mp3\", \".flac\", \".opus\", \".oga\", \".m4a\", \".aac\")\n" +
                "res = {}\n" +
                "for p in [assets, user]:\n" +
                "    if os.path.exists(p):\n" +
                "        for f in os.listdir(p):\n" +
                "            if f.lower().endswith(exts):\n" +
                "                name = os.path.splitext(f)[0]\n" +
                "                res[name] = os.path.join(p, f)\n" +
                "out = [{\"name\": k, \"path\": v} for k, v in sorted(res.items(), key=lambda x: x[0].lower())]\n" +
                "print(json.dumps(out))\n" +
                "' \"" + assetsPath + "\" \"" + userPath + "\"";
            return ["bash", "-c", script];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt !== "") {
                        let list = JSON.parse(txt);
                        if (Array.isArray(list)) {
                            notificationsTabRoot.soundList = list;
                            let found = false;
                            for (let i = 0; i < list.length; i++) {
                                if (list[i].path === notificationsTabRoot.selectedSound || list[i].name === notificationsTabRoot.selectedSound) {
                                    notificationsTabRoot.selectedSound = list[i].path;
                                    notificationsTabRoot.updateNotifSetting("soundFile", list[i].path);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                if (list.length > 0) {
                                    notificationsTabRoot.selectedSound = list[0].path;
                                    notificationsTabRoot.updateNotifSetting("soundFile", list[0].path);
                                } else {
                                    notificationsTabRoot.selectedSound = "";
                                    notificationsTabRoot.updateNotifSetting("soundFile", "");
                                }
                            }
                        }
                    } else {
                        notificationsTabRoot.soundList = [];
                        notificationsTabRoot.selectedSound = "";
                        notificationsTabRoot.updateNotifSetting("soundFile", "");
                    }
                } catch (e) {}
            }
        }
    }

    function installSound(filePath, fileName) {
        if (!filePath || filePath.trim() === "" || !fileName || fileName.trim() === "") return;
        let userSoundsPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/serpantinum/sounds/notifications");
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };

        let script =
            "D=\"" + escapeBash(userSoundsPath) + "\"; " +
            "B=\"" + escapeBash(fileName) + "\"; " +
            "S=\"" + escapeBash(filePath) + "\"; " +
            "mkdir -p \"$D\"; " +
            "if [ ! -f \"$D/$B\" ]; then cp \"$S\" \"$D/$B\"; fi; " +
            "NAME=$(basename \"$B\" | sed 's/\\.[^.]*$//'); " +
            "echo \"$NAME|$D/$B\";";

        soundInstallProcess.command = ["bash", "-c", script];
        soundInstallProcess.running = true;
    }

    Process {
        id: soundInstallProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "") {
                    let idx = out.indexOf('|');
                    let sPath = idx !== -1 ? out.substring(idx + 1).trim() : "";
                    if (sPath !== "") {
                        notificationsTabRoot.selectedSound = sPath;
                        notificationsTabRoot.updateNotifSetting("soundFile", sPath);
                        notificationsTabRoot.reloadSounds();
                        if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") {
                            Sounds.play(sPath);
                        }
                    }
                }
                soundPickerPopup.close();
            }
        }
    }

    SoundPicker {
        id: soundPickerPopup
        rootObj: notificationsTabRoot.rootObj
        onSoundSelected: function(filePath, fileName) {
            if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") {
                notificationsTabRoot.installSound(filePath, fileName);
            }
        }
    }

    Component.onCompleted: {
        syncSettings();
        reloadSounds();
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            reloadSounds();
        } else {
            selectorOpen = false;
            soundPickerPopup.close();
            if (posDropdown.isOpen) posDropdown.closePopup();
            if (soundDropdown.isOpen) soundDropdown.closePopup();
        }
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            notificationsTabRoot.syncSettings();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: posCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                ColumnLayout {
                    id: posCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰍹"
                            iconOffsetX: -2
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.notifications.position.title", "Screen position")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                font.bold: true
                                color: ThemeBackend.text
                            }

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.notifications.position.desc", "Select a preset position or drag on screen")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        RowLayout {
                            spacing: rootObj.s(8)
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                            ClickButton {
                                implicitHeight: rootObj.s(32)
                                horizontalPadding: rootObj.s(12)
                                buttonText: notificationsTabRoot.selectorOpen ? I18n.t("guide.notifications.position.close_selector", "Close the selector") : I18n.t("guide.notifications.position.select_on_screen", "Select on screen...")
                                buttonIcon: notificationsTabRoot.selectorOpen ? "󰅖" : "󰍹"
                                iconFontSize: rootObj.s(13)
                                textFontSize: rootObj.s(11)
                                accentColor: notificationsTabRoot.selectorOpen ? ThemeBackend.mauve : ThemeBackend.surface0
                                textColor: notificationsTabRoot.selectorOpen ? ThemeBackend.crust : ThemeBackend.text
                                cornerRadius: ThemeBackend.borderRadius
                                onClicked: {
                                    notificationsTabRoot.selectorOpen = !notificationsTabRoot.selectorOpen;
                                }
                            }

                            Rectangle {
                                id: notifCustomPosBox
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: rootObj.s(32)
                                implicitWidth: notificationsTabRoot.isCustomPos ? (notifCustomPosText.implicitWidth + rootObj.s(20)) : 0
                                radius: ThemeBackend.borderRadius
                                color: ThemeBackend.surface0
                                border.width: 1
                                border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                                clip: true
                                opacity: notificationsTabRoot.isCustomPos ? 1.0 : 0.0
                                visible: opacity > 0.001

                                Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                                Text {
                                    id: notifCustomPosText
                                    anchors.centerIn: parent
                                    text: I18n.t("guide.position.custom", "Custom") + " (" + notificationsTabRoot.horizontalPosition + "%, " + notificationsTabRoot.verticalPosition + "%)"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            Dropdown {
                                id: posDropdown
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: rootObj.s(180)
                                Layout.preferredHeight: rootObj.s(32)
                                options: [
                                    I18n.t("guide.notifications.position.top_right", "Top Right"),
                                    I18n.t("guide.notifications.position.top_center", "Top Center"),
                                    I18n.t("guide.notifications.position.top_left", "Top Left"),
                                    I18n.t("guide.notifications.position.bottom_right", "Bottom Right"),
                                    I18n.t("guide.notifications.position.bottom_center", "Bottom Center"),
                                    I18n.t("guide.notifications.position.bottom_left", "Bottom Left")
                                ]
                                currentIndex: {
                                    if (notificationsTabRoot.isCustomPos) return -1;
                                    if (notificationsTabRoot.position === "top right") return 0;
                                    if (notificationsTabRoot.position === "top center") return 1;
                                    if (notificationsTabRoot.position === "top left") return 2;
                                    if (notificationsTabRoot.position === "bottom right") return 3;
                                    if (notificationsTabRoot.position === "bottom center") return 4;
                                    if (notificationsTabRoot.position === "bottom left") return 5;
                                    return notificationsTabRoot.getPresetIndex(notificationsTabRoot.horizontalPosition, notificationsTabRoot.verticalPosition);
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
                                    notificationsTabRoot.setPosFromIndex(index);
                                }
                                onSelected: function(index, value) {
                                    notificationsTabRoot.setPosFromIndex(index);
                                }
                            }

                            Binding {
                                target: posDropdown
                                property: "currentIndex"
                                value: {
                                    if (notificationsTabRoot.isCustomPos) return -1;
                                    if (notificationsTabRoot.position === "top right") return 0;
                                    if (notificationsTabRoot.position === "top center") return 1;
                                    if (notificationsTabRoot.position === "top left") return 2;
                                    if (notificationsTabRoot.position === "bottom right") return 3;
                                    if (notificationsTabRoot.position === "bottom center") return 4;
                                    if (notificationsTabRoot.position === "bottom left") return 5;
                                    return notificationsTabRoot.getPresetIndex(notificationsTabRoot.horizontalPosition, notificationsTabRoot.verticalPosition);
                                }
                            }
                        }
                    }

                    Item {
                        id: selectorWrapper
                        Layout.fillWidth: true
                        property bool isOpen: notificationsTabRoot.selectorOpen
                        clip: true
                        visible: implicitHeight > 0
                        opacity: isOpen ? 1.0 : 0.0
                        implicitHeight: isOpen ? selectorInnerCol.implicitHeight : 0

                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: selectorInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: rootObj.s(10)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: rootObj.s(6)

                                ClickButton {
                                    enabled: false
                                    Layout.preferredWidth: rootObj.s(140)
                                    implicitHeight: rootObj.s(26)
                                    cornerRadius: rootObj.s(6)
                                    horizontalPadding: rootObj.s(6)
                                    textFontSize: rootObj.s(11)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                    buttonText: "X: " + notificationsTabRoot.horizontalPosition + "%  Y: " + notificationsTabRoot.verticalPosition + "%"
                                }

                                IconButton {
                                    size: rootObj.s(26)
                                    cornerRadius: rootObj.s(6)
                                    buttonIcon: "󰕰"
                                    iconFontSize: rootObj.s(13)
                                    accentColor: notificationsTabRoot.gridEnabled ? ThemeBackend.mauve : ThemeBackend.surface0
                                    textColor: notificationsTabRoot.gridEnabled ? ThemeBackend.crust : ThemeBackend.text
                                    onClicked: {
                                        notificationsTabRoot.gridEnabled = !notificationsTabRoot.gridEnabled;
                                    }
                                }

                                IconButton {
                                    size: rootObj.s(26)
                                    cornerRadius: rootObj.s(6)
                                    buttonIcon: "󰑐"
                                    iconFontSize: rootObj.s(13)
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.text
                                    onClicked: {
                                        notificationsTabRoot.applyPosition(notificationsTabRoot.presetRightH, notificationsTabRoot.presetTopV, "top right");
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: rootObj.s(8)
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                    Text {
                                        text: I18n.t("guide.common.show_bar", "Show bar")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }

                                    Toggle {
                                        checked: notificationsTabRoot.showBarBox
                                        accentColor: ThemeBackend.mauve
                                        baseColor: ThemeBackend.surface1
                                        handleColor: ThemeBackend.crust
                                        handleOffColor: ThemeBackend.text
                                        onToggled: function(c) {
                                            notificationsTabRoot.showBarBox = c;
                                        }
                                    }
                                }
                            }

                            ScreenPositionSelector {
                                id: screenSelector
                                Layout.fillWidth: true
                                horizontalPosition: notificationsTabRoot.horizontalPosition
                                verticalPosition: notificationsTabRoot.verticalPosition
                                gridEnabled: notificationsTabRoot.gridEnabled
                                showBar: notificationsTabRoot.showBarBox
                                marginV: rootObj.s(12)
                                marginH: rootObj.s(16)
                                dragWidth: rootObj.s(170)
                                dragHeight: rootObj.s(48)

                                onPositionChanged: (hPos, vPos) => {
                                    let h = Math.round(hPos);
                                    let v = Math.round(vPos);
                                    notificationsTabRoot.horizontalPosition = h;
                                    notificationsTabRoot.verticalPosition = v;
                                    let idx = notificationsTabRoot.getPresetIndex(h, v);
                                    notificationsTabRoot.position = idx !== -1 ? notificationsTabRoot.getPosStringFromIndex(idx) : "custom";
                                    debounceTimer.restart();
                                }

                                onDragFinished: {
                                    debounceTimer.stop();
                                    let idx = notificationsTabRoot.getPresetIndex(notificationsTabRoot.horizontalPosition, notificationsTabRoot.verticalPosition);
                                    let posStr = idx !== -1 ? notificationsTabRoot.getPosStringFromIndex(idx) : "custom";
                                    notificationsTabRoot.position = posStr;
                                    let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", defaultNotificationSettings) || defaultNotificationSettings));
                                    current.horizontalPosition = notificationsTabRoot.horizontalPosition;
                                    current.verticalPosition = notificationsTabRoot.verticalPosition;
                                    current.position = posStr;
                                    Config.setSetting("notifications", current);
                                    notificationsTabRoot.notifSettings = current;
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: rootObj.s(8)
                                    color: ThemeBackend.base
                                    border.width: 1
                                    border.color: ThemeBackend.surface0
                                    clip: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: rootObj.s(6)
                                        spacing: rootObj.s(8)

                                        Rectangle {
                                            Layout.preferredWidth: parent.height
                                            Layout.preferredHeight: parent.height
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: rootObj.s(6)
                                            color: ThemeBackend.surface1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰂚"
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: rootObj.s(16)
                                                color: ThemeBackend.mauve
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: rootObj.s(4)

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.maximumWidth: rootObj.s(80)
                                                height: rootObj.s(6)
                                                radius: rootObj.s(3)
                                                color: ThemeBackend.text
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.maximumWidth: rootObj.s(110)
                                                height: rootObj.s(5)
                                                radius: rootObj.s(2.5)
                                                color: ThemeBackend.subtext0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowDndLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                RowLayout {
                    id: rowDndLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰂛"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.notifications.dnd.title")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.notifications.dnd.desc")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: notificationsTabRoot.dnd
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            notificationsTabRoot.dnd = c;
                            notificationsTabRoot.updateNotifSetting("dnd", c);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: rowGraphicLayout.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                RowLayout {
                    id: rowGraphicLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    IconButton {
                        enabled: false
                        size: rootObj.s(32)
                        Layout.preferredWidth: rootObj.s(32)
                        Layout.preferredHeight: rootObj.s(32)
                        Layout.alignment: Qt.AlignVCenter
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰋑"
                        iconFontSize: rootObj.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: "#ffffff"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: rootObj.s(2)

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.notifications.empty_graphic.title")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("guide.notifications.empty_graphic.desc")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: notificationsTabRoot.showEmptyGraphic
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            notificationsTabRoot.showEmptyGraphic = c;
                            notificationsTabRoot.updateNotifSetting("showEmptyGraphic", c);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: soundCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                ColumnLayout {
                    id: soundCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: rootObj.s(14)
                    anchors.rightMargin: rootObj.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: rootObj.s(12)

                    RowLayout {
                        id: rowSoundToggleLayout
                        Layout.fillWidth: true
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰂚"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.notifications.sound.title")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.notifications.sound.desc")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }
                        }

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: notificationsTabRoot.soundEnabled
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                notificationsTabRoot.soundEnabled = c;
                                notificationsTabRoot.updateNotifSetting("sound", c);
                            }
                        }
                    }

                    Item {
                        id: soundSectionWrapper
                        Layout.fillWidth: true
                        property bool isOpen: notificationsTabRoot.soundEnabled
                        clip: true
                        visible: implicitHeight > 0
                        opacity: isOpen ? 1.0 : 0.0
                        implicitHeight: isOpen ? soundInnerCol.implicitHeight : 0

                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: soundInnerCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: parent.width
                            spacing: 0

                            RowLayout {
                                id: rowSoundSelectLayout
                                Layout.fillWidth: true
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰎆"
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.notifications.sound_file.title")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(13)
                                        color: ThemeBackend.text
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t("guide.notifications.sound_file.desc")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    spacing: rootObj.s(8)

                                    IconButton {
                                        Layout.preferredWidth: rootObj.s(32)
                                        Layout.preferredHeight: rootObj.s(32)
                                        Layout.alignment: Qt.AlignVCenter
                                        cornerRadius: rootObj.s(6)
                                        buttonIcon: "󰉋"
                                        iconOffsetX: -2
                                        iconFontSize: rootObj.s(14)
                                        accentColor: ThemeBackend.surface0
                                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                                        onClicked: {
                                            let userSoundsPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/serpantinum/sounds/notifications");
                                            let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                                            Quickshell.execDetached(["bash", "-c", "mkdir -p \"" + escapeBash(userSoundsPath) + "\" && xdg-open \"" + escapeBash(userSoundsPath) + "\""]);
                                        }
                                    }

                                    IconButton {
                                        Layout.preferredWidth: rootObj.s(32)
                                        Layout.preferredHeight: rootObj.s(32)
                                        Layout.alignment: Qt.AlignVCenter
                                        cornerRadius: rootObj.s(6)
                                        buttonIcon: "󰐕"
                                        iconFontSize: rootObj.s(14)
                                        accentColor: ThemeBackend.surface0
                                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                                        onClicked: soundPickerPopup.openPicker()
                                    }

                                    Dropdown {
                                        id: soundDropdown
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: rootObj.s(180)
                                        Layout.preferredHeight: rootObj.s(32)
                                        options: notificationsTabRoot.availableSounds
                                        currentIndex: {
                                            for (let i = 0; i < notificationsTabRoot.soundList.length; i++) {
                                                if (notificationsTabRoot.soundList[i].path === notificationsTabRoot.selectedSound) {
                                                    return i;
                                                }
                                            }
                                            return 0;
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
                                        onSelected: function(index, value) {
                                            if (index >= 0 && index < notificationsTabRoot.soundList.length) {
                                                let targetPath = notificationsTabRoot.soundList[index].path;
                                                notificationsTabRoot.selectedSound = targetPath;
                                                notificationsTabRoot.updateNotifSetting("soundFile", targetPath);
                                                if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") {
                                                    Sounds.play(targetPath);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
