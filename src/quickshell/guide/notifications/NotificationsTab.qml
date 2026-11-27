import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"

GuideTab {
    id: notificationsTabRoot

    property alias screenSelector: positionRow.screenSelector
    property alias posDropdown: positionRow.posDropdown
    property alias soundDropdown: soundSection.soundDropdown
    property alias soundPickerPopup: soundPickerPopup

    property bool selectorOpen: false
    property bool gridEnabled: false
    property bool showBarBox: true

    readonly property int presetTopV: screenSelector ? screenSelector.safeTopPercent : 5
    readonly property int presetBottomV: screenSelector ? screenSelector.safeBottomPercent : 95
    readonly property int presetLeftH: screenSelector ? screenSelector.safeLeftPercent : 5
    readonly property int presetRightH: screenSelector ? screenSelector.safeRightPercent : 95
    readonly property int presetCenterH: 50

    onPresetTopVChanged: {
        if (position !== "custom" && position.indexOf("top") !== -1 && screenSelector) {
            screenSelector.verticalPosition = presetTopV;
        }
    }
    onPresetBottomVChanged: {
        if (position !== "custom" && position.indexOf("bottom") !== -1 && screenSelector) {
            screenSelector.verticalPosition = presetBottomV;
        }
    }
    onPresetLeftHChanged: {
        if (position !== "custom" && position.indexOf("left") !== -1 && screenSelector) {
            screenSelector.horizontalPosition = presetLeftH;
        }
    }
    onPresetRightHChanged: {
        if (position !== "custom" && position.indexOf("right") !== -1 && screenSelector) {
            screenSelector.horizontalPosition = presetRightH;
        }
    }

    ConfigSection {
        id: notifCfg
        section: "notifications"
        defaults: ({
            "dnd": false,
            "position": "top right",
            "horizontalPosition": notificationsTabRoot.presetRightH,
            "verticalPosition": notificationsTabRoot.presetTopV,
            "sound": true,
            "soundFile": "",
            "showEmptyGraphic": true,
            "rightClickClose": true,
            "timeoutLow": 5,
            "timeoutNormal": 5,
            "timeoutCritical": 15,
            "overrideAppTimeouts": false
        })
    }

    readonly property var notifSettings: notifCfg.values
    readonly property bool dnd: Boolean(notifSettings.dnd !== undefined ? notifSettings.dnd : false)
    readonly property string position: String(notifSettings.position !== undefined ? notifSettings.position : "top right")
    readonly property int horizontalPosition: {
        if (position !== "custom") {
            if (position.indexOf("left") !== -1) return presetLeftH;
            if (position.indexOf("center") !== -1) return presetCenterH;
            return presetRightH;
        }
        if (notifSettings.horizontalPosition !== undefined) return Number(notifSettings.horizontalPosition);
        return presetRightH;
    }
    readonly property int verticalPosition: {
        if (position !== "custom") {
            if (position.indexOf("bottom") !== -1) return presetBottomV;
            return presetTopV;
        }
        if (notifSettings.verticalPosition !== undefined) return Number(notifSettings.verticalPosition);
        return presetTopV;
    }
    readonly property bool soundEnabled: Boolean(notifSettings.sound !== undefined ? notifSettings.sound : true)
    readonly property string selectedSound: String(notifSettings.soundFile !== undefined ? notifSettings.soundFile : "")
    readonly property bool showEmptyGraphic: Boolean(notifSettings.showEmptyGraphic !== undefined ? notifSettings.showEmptyGraphic : true)
    readonly property bool rightClickClose: Boolean(notifSettings.rightClickClose !== undefined ? notifSettings.rightClickClose : true)
    readonly property int timeoutLow: Number(notifSettings.timeoutLow !== undefined ? notifSettings.timeoutLow : 5)
    readonly property int timeoutNormal: Number(notifSettings.timeoutNormal !== undefined ? notifSettings.timeoutNormal : 5)
    readonly property int timeoutCritical: Number(notifSettings.timeoutCritical !== undefined ? notifSettings.timeoutCritical : 15)
    readonly property bool overrideAppTimeouts: Boolean(notifSettings.overrideAppTimeouts !== undefined ? notifSettings.overrideAppTimeouts : false)

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
        if (screenSelector) {
            screenSelector.horizontalPosition = h;
            screenSelector.verticalPosition = v;
        }
        notifCfg.setDebounced("horizontalPosition", h, 100);
        notifCfg.setDebounced("verticalPosition", v, 100);
        notifCfg.setDebounced("position", posStr, 100);
    }

    function commitPosition(h, v, posStr) {
        notifCfg.setMany({
            "horizontalPosition": h,
            "verticalPosition": v,
            "position": posStr
        });
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
        notifCfg.set(key, val);
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
            let userPath = Caching.stateDir + "/sounds/notifications";
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
                                    notificationsTabRoot.updateNotifSetting("soundFile", list[i].path);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                if (list.length > 0) {
                                    notificationsTabRoot.updateNotifSetting("soundFile", list[0].path);
                                } else {
                                    notificationsTabRoot.updateNotifSetting("soundFile", "");
                                }
                            }
                        }
                    } else {
                        notificationsTabRoot.soundList = [];
                        notificationsTabRoot.updateNotifSetting("soundFile", "");
                    }
                } catch (e) {}
            }
        }
    }

    function installSound(filePath, fileName) {
        if (!filePath || filePath.trim() === "" || !fileName || fileName.trim() === "") return;
        let userSoundsPath = Caching.stateDir + "/sounds/notifications";
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

    Timer {
        id: reloadSoundsDebounceTimer
        interval: 220
        repeat: false
        onTriggered: reloadSounds()
    }

    Component.onCompleted: {
        if (visible) {
            reloadSoundsDebounceTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            reloadSoundsDebounceTimer.restart();
        } else {
            notifCfg.flush();
            reloadSoundsDebounceTimer.stop();
            selectorOpen = false;
            soundPickerPopup.close();
            if (posDropdown.isOpen) posDropdown.closePopup();
            if (soundDropdown.isOpen) soundDropdown.closePopup();
        }
    }

    GuideScrollView {
        rootObj: notificationsTabRoot.rootObj

        NotificationPositionRow { id: positionRow; tab: notificationsTabRoot }

        NotificationsBehaviorSection { tab: notificationsTabRoot }

        NotificationsTimeoutSection { tab: notificationsTabRoot }

        NotificationsSoundSection { id: soundSection; tab: notificationsTabRoot }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: rootObj.s(4)
            Layout.leftMargin: rootObj.s(4)
            Layout.rightMargin: rootObj.s(4)
            spacing: rootObj.s(12)

            Item { Layout.fillWidth: true }

            ClickButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitHeight: rootObj.s(36)
                horizontalPadding: rootObj.s(16)
                buttonText: I18n.t("guide.notifications.test", "Test notification")
                buttonIcon: "󰂚"
                iconFontSize: rootObj.s(16)
                textFontSize: rootObj.s(12)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                onClicked: {
                    Quickshell.execDetached([
                        "serpantinum-core", "notify",
                        "--urgency",
                        "critical",
                        "--",
                        I18n.t("guide.notifications.test", "Test notification"),
                        I18n.t("guide.notifications.test_desc", "This is a test notification")
                    ]);
                }
            }
        }
    }
}
