import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../lock/redactor"

GuideTab {
    id: displayLockscreenRoot

    ConfigSection {
        id: lockCfg
        section: "lockscreen"
        defaults: ({
            "fingerprintEnabled": true,
            "attemptLimitEnabled": false,
            "passwordMaxAttempts": 5,
            "fingerprintMaxAttempts": 5,
            "backgroundMode": "follow",
            "customBackground": "",
            "promptBackdropMode": "desktop"
        })
    }

    readonly property var lockscreenSettings: lockCfg.values
    property bool fingerprintSupported: false
    readonly property string currentBackgroundMode: lockscreenSettings.backgroundMode === "custom" ? "custom" : "follow"
    readonly property string currentCustomBackground: lockscreenSettings.customBackground ? String(lockscreenSettings.customBackground) : ""
    readonly property string currentPromptBackdropMode: lockscreenSettings.promptBackdropMode === "wallpaper" ? "wallpaper" : "desktop"
    readonly property string currentWallpaperPath: {
        Wallpaper.screenWallpaperPaths;
        return Wallpaper.getWallpaperPath("");
    }
    readonly property bool customBackgroundActive: displayLockscreenRoot.currentBackgroundMode === "custom" && displayLockscreenRoot.currentCustomBackground !== ""
    readonly property string effectiveBackgroundPath: displayLockscreenRoot.customBackgroundActive ? displayLockscreenRoot.currentCustomBackground : displayLockscreenRoot.currentWallpaperPath
    readonly property bool effectiveBackgroundIsVideo: displayLockscreenRoot.isVideoPath(displayLockscreenRoot.effectiveBackgroundPath)
    readonly property bool currentFingerprintEnabled: lockscreenSettings.fingerprintEnabled !== false
    readonly property bool currentAttemptLimitEnabled: lockscreenSettings.attemptLimitEnabled === true
    readonly property int currentPasswordMaxAttempts: lockscreenSettings.passwordMaxAttempts !== undefined ? Number(lockscreenSettings.passwordMaxAttempts) : 5
    readonly property int currentFingerprintMaxAttempts: lockscreenSettings.fingerprintMaxAttempts !== undefined ? Number(lockscreenSettings.fingerprintMaxAttempts) : 5

    Process {
        id: fingerprintProbe
        command: ["serpantinum-core", "system", "fingerprint"]
        onExited: (exitCode) => displayLockscreenRoot.fingerprintSupported = exitCode === 0
    }

    Component.onCompleted: fingerprintProbe.running = true

    function isVideoPath(path) {
        let lp = String(path || "").toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
    }

    function setBackgroundMode(mode) {
        lockCfg.set("backgroundMode", mode);
    }

    function setPromptBackdropMode(mode) {
        lockCfg.set("promptBackdropMode", mode);
    }

    function setCustomBackground(path) {
        lockCfg.set("customBackground", path);
    }

    function openRedactor() {
        LockLayoutStore.openRedactor("");
        if (rootObj && typeof rootObj.closePopup === "function") {
            rootObj.closePopup();
        } else {
            ShellRouter.close();
        }
    }

    function updateLockscreenSetting(key, value) {
        lockCfg.set(key, value);
    }
}
